
## Installation and configuration

1. Follow Georgios's instruction (https://github.com/gousiosg/pullreqs/blob/master/README.md) for the configuration of ruby environment. Part of it is shown as follows:
<pre>
apt-get install libicu-dev cmake libmysqlclient-dev parallel
rvm install 2.2.1
rvm use 2.2.1
gem install bundler -v 1.17.3
bundle install
gem install mysql2 bson_ext
</pre>
2. Download GHTorrent [MySQL dump](http://ghtorrent-downloads.ewi.tudelft.nl/mysql/mysql-2019-06-01.tar.gz) and [MongoDB dump](http://ghtorrent-downloads.ewi.tudelft.nl/mongo-daily/mongo-dump-2019-06-30.tar.gz). And install them on your local machine.
3. Create file config.yaml in folder according to the template. Change the database configuration.
4. Use command ```pip install -r requirements.txt``` to install the python requirements (Here we use python 2.7)
5. modify the bin/project_list.txt file, and add the projects that you want to analyze(in the format ```"owner repository"```). Here we take ```mozilla-services server-syncstorage``` as an example.
6. Use command ```cd bin; python 1_extract_related_data.py``` to extract project related data into new tables. You will get a set of tables with name beginning with ```reduced_```. These table are directly related to the tables in GHTorrent MySQL database.
7. Use command ```python 2_transfer_mongo_data.py``` to transfer MongoDB data to MySQL database. You will get three new tables, namely ```reduced_commits_mongo```, ```reduced_pull_requests_mongo```, ```reduced_issue_comments_mongo```. These tables contain some text information that is not exists in MySQL database.
8. Use command ```python 3_get_ci_usage.py``` to find whether pull requests use CI tools or not. You will get a new table called ```reduced_pull_request_cis```.
9. Use command ```python 4_get_user_affiliation.py``` to get the result of user related affiliation. You will get a new table called ```reduced_users_company```.
10. Use command ```python 5_get_core_members.py``` to get who, in what time, at which project, and through what kind of action can be detected as a core member of the target project. You will get a new table called ```reduced_project_core_members```. This table will be used to calculate core member related factors.
11. Use command ```ruby get_analyzable_prs.rb``` to find the pull requests that are targeting at the default branch.
12. Use command ```./pull_req_data_extraction.sh -pA -dB project_list.txt``` to run the data extraction program, where A represents the number of processes, B represents the folder for results.

For Step 6~11, we made a sql file for test project ```mozilla-services server-syncstorage(see file test_pullreq.sql)```. You can simply import the database, and run step 12 to see the results.

In the data folder, there are download url for both csv and sql files. By using our program, you can get as much data as you can.


## Other information
The id of pull request has been removed because of privacy problem.