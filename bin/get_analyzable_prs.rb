require 'yaml'
require 'sequel'
require 'trollop'
require 'rugged'
require 'parallel'
require 'thread'
require 'linguist'

require_relative 'utils/semaphore'
require_relative 'utils/logger'
require_relative 'utils/git'
require_relative 'utils/db'
require_relative 'utils/rugged_handler'

class GetAnalyzablePrs

  include Semaphore
  include LoggerUtil
  include Git
  include DB
  include RuggedHandler

  THREADS = 1

  attr_accessor :config, :projects

  def create_table(tablename)
    q = <<-QUERY
       CREATE TABLE `#{tablename}` (
         `id` int(11) NOT NULL AUTO_INCREMENT,
         `project_id` int(11) DEFAULT NULL,
         `ownername` varchar(255) DEFAULT NULL,
         `reponame` varchar(255) DEFAULT NULL,
         `github_id` int(11) DEFAULT NULL,
         PRIMARY KEY (`id`),
         KEY `project_id` (`project_id`) USING BTREE
       ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    QUERY
    begin
      db.execute(q)
    rescue StandardError => e
    end
  end

  def run()
    self.config = YAML.load_file("config.yaml")
    # record the result into database
    create_table("analyzable_prs")
    go
    log "finish"
  end

  # main command code
  def go

    # read all the projects
    self.projects = File.read("project_list.txt").split("\n")

    interrupted = false

    # Process pull request list
    # the function to start handling a pr
    do_p = Proc.new do |project|
      ownername, reponame = project.split(" ")
      begin
        final_prs = [] # store the analyzable prs for this project
        # clone or update repository
        q = <<-QUERY
          select p.id
          from reduced_projects p, reduced_users u
          where p.owner_id=u.id
            and u.login=?
            and p.name=?
        QUERY
        project = db.fetch(q, ownername, reponame).first
        project_id = project[:id]

        q = <<-QUERY
          select u.login as login, p.name as project_name, pr.id, pr.pullreq_id as github_id,
                 a.created_at as created_at, 
                 ( select max(created_at) 
                   from reduced_pull_request_history 
                   where pull_request_id = pr.id and action='closed') as closed_at, 
                 ( select actor_id 
                   from reduced_pull_request_history 
                   where pull_request_id = pr.id 
                     and action='closed'
                   order by created_at desc
                   limit 1) as closed_reviewer_id,
                 c.sha as base_commit,
                 c1.sha as head_commit, p.id as project_id, u.id as project_owner_id, u2.id as pr_creator_id, u2.login as pr_creator_login,
                 ( select max(created_at)
                   from reduced_pull_request_history prh1
                   where prh1.pull_request_id = pr.id
                   and prh1.action='merged' limit 1) as merged_at,
                 timestampdiff(minute, a.created_at, (select max(created_at) 
                                                 from reduced_pull_request_history
                                                 where pull_request_id = pr.id and action='closed')) as lifetime_minutes,
                 timestampdiff(minute, a.created_at, (select max(created_at)
                                                 from reduced_pull_request_history prh1
                                                 where prh1.pull_request_id = pr.id and prh1.action='merged' limit 1)) as mergetime_minutes
          from reduced_pull_requests pr, reduced_projects p, reduced_users u,
               reduced_pull_request_history a, reduced_pull_request_history b, reduced_commits c, reduced_commits c1, reduced_users u2
          where p.id = pr.base_repo_id
            and a.pull_request_id = pr.id
            and a.pull_request_id = b.pull_request_id
            and a.action='opened' and b.action='closed'
            and a.created_at < b.created_at
            and p.owner_id = u.id
            and c1.id = pr.head_commit_id
            and c.id = pr.base_commit_id
            and a.actor_id = u2.id
            and p.id = ?
            group by pr.id order by pr.pullreq_id desc;
        QUERY
        prs = db.fetch(q, project_id).all

        repo = clone(ownername, reponame, true)

        prs.each do |pr|
          begin
            ls_tree(repo.lookup(pr[:base_commit]).tree)
            final_prs << pr[:github_id]
          rescue StandardError => e
            log "Cannot find commit #{pr[:base_commit]} in base repo, head_commit: #{pr[:head_commit]}, ownername: #{ownername}, reponame: #{reponame}" # some are in the other branches
          end
        end

        final_prs.each do |github_id|
          conn = Sequel.connect(self.config['sql']['url'],
                                :encoding => 'utf8',
                                :sql_mode => 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION')
          conn[:analyzable_prs].insert(
              :project_id => project_id,
              :ownername => ownername,
              :reponame => reponame,
              :github_id => github_id
          )
          conn.disconnect
        end

      rescue StandardError => e
        log "Error processing analyzable pr number extractor #{project_id.to_s}: #{e.message}"
        log e.backtrace
      end
    end

    Parallel.map(projects, :in_threads => THREADS) do |project|
      if interrupted
        raise Parallel::Kill
      end
      do_p.call(project)
    end
  end
end

pr = GetAnalyzablePrs.new
pr.run