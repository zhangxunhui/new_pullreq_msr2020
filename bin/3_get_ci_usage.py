# encoding=utf8
# generate whether the pull request uses ci tools or not

import yaml
from utils import *
import threading
import Queue
import sys

f = open('config.yaml', 'r')
config = yaml.load(f.read(), Loader=yaml.BaseLoader)

result_table_name = "reduced_pull_request_cis"
THREAD_NUM = 1

'''
    the key words and tool names
'''

common_key_words = ["continuous", "integration", "-ci", "ci/", "ci.", "ci-"]
ends_with_key_words = ["CI"]

nouns = ["job", "patch"]
verbs = ["succeed", "success", "fail", "failure", "finish", "trigger", "pending"]
for noun in nouns:
    for verb in verbs:
        key_word = noun + " " + verb
        common_key_words.append(key_word)
common_key_words = set(common_key_words)

manual_tool_names = ["travis", "circle", "jenkins", "appveyor", "codeship", "drone", "semaphore", "buildkite", "wercker", "teamcity", "buddy", "solano", "assertible", "shippable", "bamboo", "gocd", "phpci", "continua", "hudson", "buildbot", "buddybuild", "xebialab", "bitrise", "evergreen", "azure", "shippable"]
manual_tool_names = set(manual_tool_names)

# read all the tool names from market_ci_tools.csv file
original_names = readCSV("market_ci_tools.csv")
market_tool_names = []
for tool in original_names:
    tool = tool[0].lower()
    tool = tool.strip()
    market_tool_names.append(tool)
market_tool_names = set(market_tool_names)

tool_names = common_key_words | market_tool_names | manual_tool_names

special_key_words = ["test", "build"] # special key words for context/description


def create_table(cur, tableName):
    # whether the table exists
    try:
        cur.execute("select max(id) from {}".format(tableName))
        cur.fetchone()
        exists = True
    except Exception as e:
        exists = False
    if exists == False:
        sql = "CREATE TABLE `"+ tableName + "` (" \
              "`id` int(11) NOT NULL AUTO_INCREMENT, " \
              "`project_id` int(11) DEFAULT NULL, " \
              "`github_id` int(11) DEFAULT NULL, " \
              "`ci_or_not` int(1) DEFAULT NULL, " \
              "PRIMARY KEY (`id`)," \
              "KEY `project_github_id` (`project_id`, `github_id`)" \
              ") ENGINE=InnoDB DEFAULT CHARSET=utf8;"
        cur.execute(sql)

class handleThread(threading.Thread):
    def __init__(self, q):
        threading.Thread.__init__(self)
        self.q = q
        self.conn = connectMysqlDB(config)
        self.cur = self.conn.cursor()

    def run(self):
        while True:
            try:
                work = self.q.get(timeout=0)
                print self.q.qsize()

                project_id = work[0]
                github_id = work[1]

                self.cur.execute("select context, description, target_url from reduced_pr_statuses where project_id=%s and github_id=%s", (project_id, github_id))

                items = self.cur.fetchall()

                result = False
                for item in items:
                    context = item[0]
                    description = item[1]
                    target_url = item[2]

                    if self.ci_or_not(context, "context") == True or self.ci_or_not(description, "description") == True or self.ci_or_not(target_url, "target_url") == True:
                        result = True
                        break

                # insert result
                self.cur.execute("insert into reduced_pull_request_cis (project_id, github_id, ci_or_not) values (%s, %s, %s)", (project_id, github_id, result))
            except Queue.Empty:
                return
            self.q.task_done()

    # judge from the text of whether it's a ci tool or not
    def ci_or_not(self, text, type):

        if text is None:
            return False

        for key_word in ends_with_key_words: # uppercase is important
            if text.endswith(key_word):
                return True

        text = text.lower()

        for tool_name in tool_names:
            if tool_name in text:
                return True

        if type == "context" or type == "description":
            for key_word in special_key_words:
                if key_word in text:
                    return True

        return False

if __name__ == "__main__":

    workQueue = Queue.Queue()

    conn = connectMysqlDB(config)
    cur = conn.cursor()

    # create the result table
    create_table(cur, result_table_name)

    # read all the unhandled tasks
    sql = "select project_id, github_id from " + result_table_name
    cur.execute(sql)
    handled_tasks = cur.fetchall()
    print "finish reading handled tasks"


    cur.execute("select distinct sps.project_id, sps.github_id from reduced_pr_statuses sps")
    all_tasks = cur.fetchall()

    unhandled_tasks = list(set(all_tasks) - set(handled_tasks))

    print "unhandled_tasks num: %d" % (len(unhandled_tasks))

    print "finish reading unhandled tasks"

    cur.close()
    conn.close()

    for params in unhandled_tasks:
        workQueue.put_nowait(params)

    for _ in range(THREAD_NUM):
        handleThread(workQueue).start()
    workQueue.join()
    print "finish"