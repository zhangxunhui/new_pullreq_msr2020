# extract information of projects

from utils import *


f = open('config.yaml', 'r')
config = yaml.load(f.read(), Loader=yaml.BaseLoader)
conn = connectMysqlDB(config)
cur = conn.cursor()


# read project list
reduced_projects = readFile("project_list.txt").strip().split('\n')
reduced_project_ids = []
for project in reduced_projects:
    ownername, reponame = project.split(" ")
    # read project_id
    cur.execute("select p.id from projects p, users u where u.id=p.owner_id and u.login=%s and p.name=%s", (ownername, reponame))
    item = cur.fetchone()
    if item is not None:
        reduced_project_ids.append(item[0])
    else:
        print "error with project: %s/%s" % (ownername, reponame)

'''
1. projects
'''
old_table = "projects"
new_table = "reduced_projects"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for project_id in reduced_project_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where id=%s", (project_id, ))
    print "finish projects table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)

'''
2. project_languages
'''
old_table = "project_languages"
new_table = "reduced_project_languages"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for project_id in reduced_project_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where project_id=%s", (project_id, ))
    print "finish project_languages table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)

'''
3. project_members
'''
old_table = "project_members"
new_table = "reduced_project_members"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for project_id in reduced_project_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where repo_id=%s", (project_id, ))
    print "finish project_members table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)

'''
4. project_topics
'''
old_table = "project_topics"
new_table = "reduced_project_topics"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for project_id in reduced_project_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where project_id=%s", (project_id,))
    print "finish project_topics table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)

'''
5. repo_labels
'''
old_table = "repo_labels"
new_table = "reduced_repo_labels"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for project_id in reduced_project_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where repo_id=%s", (project_id, ))
    print "finish repo_labels table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)

'''
6. repo_milestones
'''
old_table = "repo_milestones"
new_table = "reduced_repo_milestones"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for project_id in reduced_project_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where repo_id=%s", (project_id, ))
    print "finish repo_milestones table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)

'''
7. watchers
'''
old_table = "watchers"
new_table = "reduced_watchers"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for project_id in reduced_project_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where repo_id=%s", (project_id, ))
    print "finish watchers table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)

'''
8. project_commits
'''
old_table = "project_commits"
new_table = "reduced_project_commits"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for project_id in reduced_project_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where project_id=%s", (project_id, ))
    print "finish project_commits table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)

'''
9. pull_requests
'''
old_table = "pull_requests"
new_table = "reduced_pull_requests"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for project_id in reduced_project_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where base_repo_id=%s", (project_id, ))
    print "finish pull_requests table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)


'''
0.2 read all the pull_requests in reduced_pull_requests table
'''
cur.execute("select id from reduced_pull_requests")
reduced_pull_request_ids = cur.fetchall()
reduced_pull_request_ids = [pull_request_id[0] for pull_request_id in reduced_pull_request_ids]
print "finish reading reduced_pull_requests"


'''
10. pull_request_commits
'''
old_table = "pull_request_commits"
new_table = "reduced_pull_request_commits"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for pull_request_id in reduced_pull_request_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where pull_request_id=%s", (pull_request_id, ))
    print "finish pull_request_commits table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)

'''
11. pull_request_comments
'''
old_table = "pull_request_comments"
new_table = "reduced_pull_request_comments"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for pull_request_id in reduced_pull_request_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where pull_request_id=%s", (pull_request_id, ))
    print "finish pull_request_comments table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)

'''
12. pull_request_history
'''
old_table = "pull_request_history"
new_table = "reduced_pull_request_history"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for pull_request_id in reduced_pull_request_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where pull_request_id=%s", (pull_request_id, ))
    print "finish pull_request_history table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)

'''
13. issues
'''
old_table = "issues"
new_table = "reduced_issues"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for project_id in reduced_project_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where repo_id=%s", (project_id, ))
    print "finish issues table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)


'''
0.3 read all the issues in reduced_issues table
'''
cur.execute("select id from reduced_issues")
reduced_issue_ids = cur.fetchall()
reduced_issue_ids = [issue_id[0] for issue_id in reduced_issue_ids]
print "finish reading reduced_issue_ids"


'''
14. issue_comments
'''
old_table = "issue_comments"
new_table = "reduced_issue_comments"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for issue_id in reduced_issue_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where issue_id=%s", (issue_id, ))
    print "finish issue_comments table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)

'''
15. issue_events
'''
old_table = "issue_events"
new_table = "reduced_issue_events"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for issue_id in reduced_issue_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where issue_id=%s", (issue_id,))
    print "finish issue_events table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)

'''
16. issue_labels
'''
old_table = "issue_labels"
new_table = "reduced_issue_labels"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for issue_id in reduced_issue_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where issue_id=%s", (issue_id,))
    print "finish issue_labels table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)

'''
0.4 read all the reduced_project_commits and reduced_pull_request_commits and the head commits and base commits
'''
cur.execute("select commit_id from reduced_project_commits")
reduced_project_commit_ids = cur.fetchall()
reduced_project_commit_ids = [commit_id[0] for commit_id in reduced_project_commit_ids]

cur.execute("select commit_id from reduced_pull_request_commits")
reduced_pull_request_commit_ids = cur.fetchall()
reduced_pull_request_commit_ids = [commit_id[0] for commit_id in reduced_pull_request_commit_ids]

cur.execute("select head_commit_id from reduced_pull_requests")
reduced_head_commit_ids = cur.fetchall()
reduced_head_commit_ids = [commit_id[0] for commit_id in reduced_head_commit_ids]

cur.execute("select base_commit_id from reduced_pull_requests")
reduced_base_commit_ids = cur.fetchall()
reduced_base_commit_ids = [commit_id[0] for commit_id in reduced_base_commit_ids]

reduced_commit_ids = list(set(reduced_project_commit_ids) | set(reduced_pull_request_commit_ids) | set(reduced_head_commit_ids) | set(reduced_base_commit_ids))
print "finish reading reduced_commits"

'''
17. commits
'''
old_table = "commits"
new_table = "reduced_commits"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for commit_id in reduced_commit_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where id=%s", (commit_id,))
    print "finish commits table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)

'''
18. commit_comments
'''
old_table = "commit_comments"
new_table = "reduced_commit_comments"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for commit_id in reduced_commit_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where commit_id=%s", (commit_id,))
    print "finish commit_comments table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)

'''
19. commit_parents
'''
old_table = "commit_parents"
new_table = "reduced_commit_parents"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for commit_id in reduced_commit_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where commit_id=%s", (commit_id,))
    print "finish commit_parents table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)

'''
0.5 get reduced_users
reduced_commit_comments.user_id
reduced_commits.author_id
reduced_commits.committer_id
reduced_issue_comments.user_id
reduced_issue_events.actor_id
reduced_issues.reporter_id
reduced_issues.assignee_id
reduced_project_members.user_id
reduced_projects.owner_id
reduced_pull_request_comments.user_id
reduced_pull_request_history.actor_id
reduces_watchers.user_id
'''
reduced_user_ids_table_column_list = [
    "reduced_commit_comments.user_id",
    "reduced_commits.author_id",
    "reduced_commits.committer_id",
    "reduced_issue_comments.user_id",
    "reduced_issue_events.actor_id",
    "reduced_issues.reporter_id",
    "reduced_issues.assignee_id",
    "reduced_project_members.user_id",
    "reduced_projects.owner_id",
    "reduced_pull_request_comments.user_id",
    "reduced_pull_request_history.actor_id",
    "reduced_watchers.user_id"
]
reduced_user_ids = set()
for table_column in reduced_user_ids_table_column_list:
    table, column = table_column.split(".")
    cur.execute("select " + column + " from " + table)
    user_ids = cur.fetchall()
    for user_id in user_ids:
        reduced_user_ids.add(user_id[0])
    print "finish reading reduced_user_ids in " + table
reduced_user_ids = list(reduced_user_ids)

'''
20. users
'''
old_table = "users"
new_table = "reduced_users"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for user_id in reduced_user_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where id=%s", (user_id,))
    print "finish users table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)

'''
21. followers
'''
old_table = "followers"
new_table = "reduced_followers"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for user_id in reduced_user_ids:
        cur.execute("insert ignore into " + new_table + " select * from " + old_table + " where follower_id=%s or user_id=%s", (user_id, user_id))
    print "finish followers table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)

'''
22. organization_members
'''
old_table = "organization_members"
new_table = "reduced_organization_members"
try:
    cur.execute("create table " + new_table + " like " + old_table)
    for user_id in reduced_user_ids:
        cur.execute("insert into " + new_table + " select * from " + old_table + " where user_id=%s", (user_id, ))
    print "finish organization_members table"
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print str(e)
        sys.exit(-1)
print "finish"