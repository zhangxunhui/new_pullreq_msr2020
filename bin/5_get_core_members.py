# encoding=utf8
# get the core members of each project, including who at which time did what things

from utils import *
import threading
import Queue

THREADNUM = 1

f = open('config.yaml', 'r')
config = yaml.load(f.read(), Loader=yaml.BaseLoader)

conn = connectMysqlDB(config)
cur = conn.cursor()

# read all the project commits related users
committer_dict = {}
cur.execute("select id, committer_id from reduced_commits")
items = cur.fetchall()
for item in items:
    commit_id = item[0]
    committer_id = item[1]
    committer_dict[commit_id] = committer_id
print "finish reading committer_dict"

# read the creators of pull requests from the project
cur.execute("select rprh.actor_id, rprh.pull_request_id "
            "from reduced_pull_request_history rprh "
            "where rprh.action='opened'")
creator_dict = {}
items = cur.fetchall()
for item in items:
    actor_id = item[0]
    pull_request_id = item[1]
    creator_dict[pull_request_id] = actor_id
print "finish reading creators of pull requests"

cur.close()
conn.close()

# the thread for processing each project
class handleThread(threading.Thread):
    def __init__(self, q):
        threading.Thread.__init__(self)
        self.q = q
    def run(self):
        while True:
            try:

                project_id = self.q.get(timeout=0)

                print self.q.qsize()

                # record the time of user acts as a core member
                core_time = {}

                conn_mysql_thread = connectMysqlDB(config, autocommit=False)
                cur_mysql_thread = conn_mysql_thread.cursor()

                # get the core members of the project
                # 1. committer_team

                # read the commits of the project
                cur_mysql_thread.execute("select rc.id, rc.created_at "
                                         "from reduced_project_commits rpc, reduced_commits rc "
                                         "where rpc.commit_id = rc.id "
                                         "and rpc.project_id=%s", (project_id,))
                project_commits = cur_mysql_thread.fetchall()
                print "finish reading project_commits"

                # read the pull_request_commits of the project
                cur_mysql_thread.execute("select rprc.commit_id "
                                         "from reduced_pull_request_commits rprc, reduced_pull_requests rpr "
                                         "where rprc.pull_request_id=rpr.id "
                                         "and rpr.base_repo_id=%s", (project_id,))
                pr_commits = cur_mysql_thread.fetchall()
                pr_commits = [c[0] for c in pr_commits]
                print "finish reading pull_request_commits"

                for project_commit in project_commits:
                    commit_id = project_commit[0]
                    created_at = project_commit[1]
                    if commit_id in pr_commits:
                        continue
                    else:
                        user_id = committer_dict[commit_id]
                        if user_id is None:
                            continue
                        core_time.setdefault(user_id, [])
                        core_time[user_id].append({"type": "committer", "pull_request_id": None, "created_at": created_at})

                # 2. merger_team

                # the person who have right to close but not the creator himself
                cur_mysql_thread.execute("select rprh.created_at, rprh.actor_id, rpr.id, rprh.action "
                            "from reduced_pull_requests rpr, reduced_pull_request_history rprh "
                            "where rpr.id=rprh.pull_request_id "
                            "and rpr.base_repo_id=%s "
                            "and (rprh.action='closed' or rprh.action='merged')", (project_id,))
                items = cur_mysql_thread.fetchall()
                for item in items:
                    closed_at = item[0]
                    actor_id = item[1]
                    pull_request_id = item[2]
                    action = item[3]
                    if actor_id is None or creator_dict.has_key(pull_request_id) == False or actor_id == creator_dict[pull_request_id]:
                        continue
                    if action == "merged":
                        type = "merger"
                    else:
                        type = "closer"
                    core_time.setdefault(actor_id, [])
                    core_time[actor_id].append({"type": type, "pull_request_id": pull_request_id, "created_at": closed_at})

                # insert core_time into database
                for (user_id, items) in core_time.items():
                    for item in items:
                        cur_mysql_thread.execute("insert into reduced_project_core_members "
                                             "(project_id, user_id, type, pull_request_id, created_at) "
                                             "values (%s, %s, %s, %s, %s)", (project_id, user_id, item["type"], item["pull_request_id"], item["created_at"]))
                conn_mysql_thread.commit()
                cur_mysql_thread.close()
                conn_mysql_thread.close()
            except Queue.Empty:
                return
            self.q.task_done()

if __name__ == "__main__":

    # create database connection
    db = connectMysqlDB(config)
    cur = db.cursor()

    # create table for result
    create_table_sql = "CREATE TABLE `reduced_project_core_members` (" \
                       "`id` int(11) NOT NULL AUTO_INCREMENT, " \
                       "`project_id` int(11) NOT NULL, " \
                       "`user_id` int(11) NOT NULL, " \
                       "`type` varchar(255) DEFAULT NULL, " \
                       "`pull_request_id` int(11) DEFAULT NULL, " \
                       "`created_at` datetime DEFAULT NULL, "\
                       "PRIMARY KEY (`id`), " \
                       "KEY `project_id` (`project_id`), " \
                       "KEY `user_id` (`user_id`)" \
                       ") ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;"
    try:
        cur.execute(create_table_sql)
    except Exception as e:
        if e.args[0] == 1050:
            pass
        else:
            print e.message
            sys.exit(-1)

    tasks = Queue.Queue()

    # # read all the comment_id related owner, repo, github_id
    # comment_dict = {}
    cur.execute("select id from reduced_projects")
    all_tasks = cur.fetchall()
    all_tasks = [t[0] for t in all_tasks]

    # read all the handled tasks
    cur.execute("select project_id from reduced_project_core_members")
    handled_tasks = cur.fetchall()
    handled_tasks = [t[0] for t in handled_tasks]

    remained_tasks = list(set(all_tasks) - set(handled_tasks))

    cur.close()
    db.close()

    for t in remained_tasks:
        tasks.put(t)

    for _ in range(THREADNUM):
        t = handleThread(tasks)
        t.start()
    tasks.join()

    print "finish"