# transfer mongodb's data to mysql

from utils import *
import json
import Queue, threading

f = open('config.yaml', 'r')
config = yaml.load(f.read(), Loader=yaml.BaseLoader)


conn_mysql = connectMysqlDB(config)
cur_mysql = conn_mysql.cursor()

THREADNUM = 1


class commitThread(threading.Thread):
    def __init__(self, q):
        threading.Thread.__init__(self)
        self.q = q

        self.conn_mysql = connectMysqlDB(config)
        self.cur_mysql = self.conn_mysql.cursor()
        self.client_mongo, self.db_mongo = connectMongoDB(config)
    def run(self):
        while(True):
            try:

                task = self.q.get(timeout=0)

                sha = task[1]
                commit_id = task[0]
                print self.q.qsize()

                commit = self.db_mongo["commits"].find_one({"sha": sha})
                if commit is not None:
                    # need to crawl
                    commit_id_ = str(commit["_id"])
                    message = commit["commit"]["message"]
                    commit_parents = commit["parents"]
                    commit_parents = json.dumps(commit_parents)
                    if "stats" not in commit:
                        stats = None
                    else:
                        stats = commit["stats"]
                        stats = json.dumps(stats)

                    if "files" not in commit:
                        files = None
                    else:
                        files = commit["files"]  # an array of dict
                        files = json.dumps(files)

                    self.cur_mysql.execute(
                        "insert into reduced_commits_mongo (commit_id, _id, sha, message, parents, stats, files) values "
                        "(%s, %s, %s, %s, %s, %s, %s)",
                        (commit_id, commit_id_, sha, message, commit_parents, stats, files))

            except Queue.Empty:
                return
            self.q.task_done()


class issueCommentThread(threading.Thread):
    def __init__(self, q):
        threading.Thread.__init__(self)
        self.q = q

        self.conn_mysql = connectMysqlDB(config)
        self.cur_mysql = self.conn_mysql.cursor()
        self.client_mongo, self.db_mongo = connectMongoDB(config)

    def run(self):
        while(True):
            try:

                task = self.q.get(timeout=0)

                issue_id = task[0]
                owner = task[1]
                repo = task[2]
                github_id = task[3]
                try:
                    issue_comments = self.db_mongo["issue_comments"].find({"owner": owner, "repo": repo, "issue_id": int(github_id)})
                    for issue_comment in issue_comments:
                        created_at = issue_comment["created_at"]
                        updated_at = issue_comment["updated_at"]
                        body = issue_comment["body"]
                        comment_id = str(issue_comment["id"])
                        self.cur_mysql.execute(
                            "insert into reduced_issue_comments_mongo (issue_id, mongo_comment_id, created_at, updated_at, body, owner, repo, mongo_github_id) values "
                            "(%s, %s, %s, %s, %s, %s, %s, %s)",
                            (issue_id, comment_id, created_at, updated_at, body, owner, repo, github_id))
                except Exception as e:
                    print str(e)

            except Queue.Empty:
                return
            self.q.task_done()


class pullRequestThread(threading.Thread):
    def __init__(self, q):
        threading.Thread.__init__(self)
        self.q = q

        self.conn_mysql = connectMysqlDB(config)
        self.cur_mysql = self.conn_mysql.cursor()
        self.client_mongo, self.db_mongo = connectMongoDB(config)
    def run(self):
        while(True):
            try:

                task = self.q.get(timeout=0)

                owner = task[0]
                repo = task[1]
                github_id = task[2]
                pull_request_id = task[3]

                # print self.q.qsize()
                try:
                    pull_request = self.db_mongo["pull_requests"].find_one({"owner": owner, "repo": repo, "number": github_id})
                    title = pull_request["title"]
                    body = pull_request["body"]
                    self.cur_mysql.execute(
                        "insert into reduced_pull_requests_mongo (pull_request_id, title, body, owner, repo, mongo_github_id) values "
                        "(%s, %s, %s, %s, %s, %s)",
                        (pull_request_id, title, body, owner, repo, github_id))
                except Exception as e:
                    print str(e)

            except Queue.Empty:
                return
            self.q.task_done()


'''
1. handle commits table in mongo db
'''

create_table_sql = "CREATE TABLE `reduced_commits_mongo` (" \
              "`id` int(11) NOT NULL AUTO_INCREMENT, " \
              "`commit_id` int(11) NOT NULL, " \
              "`_id` varchar(255) DEFAULT NULL, " \
              "`sha` varchar(255) DEFAULT NULL, " \
              "`message` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL, " \
              "`parents` longtext DEFAULT NULL, " \
              "`stats` varchar(255) DEFAULT NULL, " \
              "`files` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL, " \
              "PRIMARY KEY (`id`), " \
              "KEY `commit_id` (`commit_id`), " \
              "KEY `sha` (`sha`)" \
              ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;"
try:
    cur_mysql.execute(create_table_sql)
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print e.message
        sys.exit(-1)

# read reduced_commits table
cur_mysql.execute("select id, sha from reduced_commits")
reduced_commit_shas = cur_mysql.fetchall()
# read handled items
cur_mysql.execute("select commit_id, sha from reduced_commits_mongo")
items = cur_mysql.fetchall()
handled_tasks = [(item[0], item[1]) for item in items]


tasks = Queue.Queue()
all_tasks = []
for reduced_commit_sha in reduced_commit_shas:
    commit_id = reduced_commit_sha[0]
    sha = reduced_commit_sha[1]
    all_tasks.append((commit_id, sha))

remained_tasks = list(set(all_tasks) - set(handled_tasks))

for t in remained_tasks:
    tasks.put(t)

for _ in range(THREADNUM):
    t = commitThread(tasks)
    t.start()
tasks.join()
print "finish reduced_commits_mongo table"

'''
2. handle issue_comments table in mongo db
'''

create_table_sql = "CREATE TABLE `reduced_issue_comments_mongo` (" \
              "`id` int(11) NOT NULL AUTO_INCREMENT, " \
              "`issue_id` int(11) NOT NULL, " \
              "`mongo_comment_id` varchar(255) DEFAULT NULL, " \
              "`created_at` varchar(255) DEFAULT NULL, " \
              "`updated_at` varchar(255) DEFAULT NULL, " \
              "`body` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL, " \
              "`owner` varchar(255) DEFAULT NULL, " \
              "`repo` varchar(255) DEFAULT NULL, " \
              "`mongo_github_id` int(11) DEFAULT NULL, " \
              "PRIMARY KEY (`id`), " \
              "KEY `issue_id` (`issue_id`), " \
              "KEY `mongo_comment_id` (`mongo_comment_id`), " \
              "KEY `orm`(`owner`, `repo`, `mongo_github_id`) " \
              ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;"
try:
    cur_mysql.execute(create_table_sql)
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print e.message
        sys.exit(-1)

# read reduced_projects, reduced_users table
cur_mysql.execute("select u.login, p.name, p.id "
                  "from reduced_users u, reduced_projects p "
                  "where u.id = p.owner_id")
items = cur_mysql.fetchall()
project_name_dict = {}
for item in items:
    owner = item[0]
    repo = item[1]
    id = item[2]
    project_name_dict[id] = (owner, repo)
print "finish reading reduced_projects table and reduced_users table"


# read handled items
cur_mysql.execute("select issue_id, owner, repo, mongo_github_id from reduced_issue_comments_mongo")
items = cur_mysql.fetchall()
handled_tasks = [(item[0], item[1], item[2], item[3]) for item in items]

# read reduced_commits table
cur_mysql.execute("select ric.issue_id, ri.repo_id, ri.issue_id "
                  "from reduced_issue_comments ric, reduced_issues ri "
                  "where ric.issue_id = ri.id")
reduced_issue_comments = cur_mysql.fetchall()


tasks = Queue.Queue()
all_tasks = []
for reduced_issue_comment in reduced_issue_comments:
    issue_id = reduced_issue_comment[0]
    repo_id = reduced_issue_comment[1]
    github_id = int(reduced_issue_comment[2])
    owner, repo = project_name_dict[repo_id]
    all_tasks.append((issue_id, owner, repo, github_id))

remained_tasks = list(set(all_tasks) - set(handled_tasks))

for t in remained_tasks:
    tasks.put(t)

for _ in range(THREADNUM):
    t = issueCommentThread(tasks)
    t.start()
tasks.join()

print "finish reduced_issue_comments table"


'''
3. handle pull_requests mongo db
'''

create_table_sql = "CREATE TABLE `reduced_pull_requests_mongo` (" \
              "`id` int(11) NOT NULL AUTO_INCREMENT, " \
              "`pull_request_id` int(11) NOT NULL, " \
              "`title` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL, " \
              "`body` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL, " \
              "`owner` varchar(255) DEFAULT NULL, " \
              "`repo` varchar(255) DEFAULT NULL, " \
              "`mongo_github_id` int(11) DEFAULT NULL, " \
              "PRIMARY KEY (`id`), " \
              "KEY `pull_request_id` (`pull_request_id`), " \
              "KEY `orm`(`owner`, `repo`, `mongo_github_id`) " \
              ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;"
try:
    cur_mysql.execute(create_table_sql)
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print e.message
        sys.exit(-1)

# read reduced_projects, reduced_users table
cur_mysql.execute("select u.login, p.name, p.id "
                  "from reduced_users u, reduced_projects p "
                  "where u.id = p.owner_id")
items = cur_mysql.fetchall()
project_name_dict = {}
for item in items:
    owner = item[0]
    repo = item[1]
    id = item[2]
    project_name_dict[id] = (owner, repo)
print "finish reading reduced_projects table and reduced_users table"

# read reduced_pull_requests table
cur_mysql.execute("select id, base_repo_id, pullreq_id from reduced_pull_requests")
reduced_pull_requests = cur_mysql.fetchall()
# read handled items
cur_mysql.execute("select owner, repo, mongo_github_id, pull_request_id from reduced_pull_requests_mongo")
items = cur_mysql.fetchall()
handled_tasks = [(item[0], item[1], item[2], item[3]) for item in items]


tasks = Queue.Queue()
all_tasks = []
for reduced_pull_request in reduced_pull_requests:
    pull_request_id = reduced_pull_request[0]
    project_id = reduced_pull_request[1]
    github_id = reduced_pull_request[2]
    owner, repo = project_name_dict[project_id]
    all_tasks.append((owner, repo, github_id, pull_request_id))

remained_tasks = list(set(all_tasks) - set(handled_tasks))

for t in remained_tasks:
    tasks.put(t)

for _ in range(THREADNUM):
    t = pullRequestThread(tasks)
    t.start()
tasks.join()
print "finish reduced_pull_requests table"