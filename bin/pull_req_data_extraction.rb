#!/usr/bin/env ruby

require 'yaml'
require 'sequel'
require 'trollop'
require 'rugged'
require 'parallel'
require 'thread'
require 'mongo'
require 'linguist'
require 'json'

require_relative 'factors/project/project_age'
require_relative 'factors/project/star_num'
require_relative 'factors/project/fork_num'
require_relative 'factors/project/team_size'
require_relative 'factors/project/open_issue_num'
require_relative 'factors/project/pr_succ_rate'
require_relative 'factors/project/open_pr_num'
require_relative 'factors/project/commits_on_files_touched'
require_relative 'factors/project/pushed_delta'
require_relative 'factors/project/first_response_time'
require_relative 'factors/pull_request/pr_stats'
require_relative 'factors/pull_request/issue_comment_num'
require_relative 'factors/pull_request/pr_comment_num'
require_relative 'factors/pull_request/commit_comment_num'
require_relative 'factors/pull_request/comment_conflict'
require_relative 'factors/pull_request/participant_num'
require_relative 'factors/pull_request/special_tags'
require_relative 'factors/pull_request/pr_description_complexity'
require_relative 'factors/pull_request/bug_fix'
require_relative 'factors/contributor/requester_succ_rate'
require_relative 'factors/contributor/account_creation_days'
require_relative 'factors/contributor/accepted_commit_num'
require_relative 'factors/contributor/follower_num'
require_relative 'factors/contributor/main_team_member'
require_relative 'factors/contributor/contributor_gender'
require_relative 'factors/contributor/contributor_country'
require_relative 'factors/contributor/first_response_time_contributor'
require_relative 'factors/contributor/repository_popularity'
require_relative 'factors/contributor/following_num'
require_relative 'factors/contributor/company_contributor'
require_relative 'factors/reviewer/reviewer_prior_review_num'
require_relative 'factors/reviewer/company_reviewer'
require_relative 'factors/social_relation/submitter_follow_integrator'
require_relative 'factors/social_relation/prior_interactions'
require_relative 'factors/social_relation/same_country'
require_relative 'factors/social_relation/same_company'
require_relative 'factors/social_relation/same_user'
require_relative 'utils/languages/ruby'
require_relative 'utils/languages/java'
require_relative 'utils/languages/python'
require_relative 'utils/languages/javascript'
require_relative 'utils/languages/go'
require_relative 'utils/languages/scala'
require_relative 'utils/semaphore'
require_relative 'utils/logger'
require_relative 'utils/commits'
require_relative 'utils/comments'
require_relative 'utils/pull_request'
require_relative 'utils/project'
require_relative 'utils/git'
require_relative 'utils/db'
require_relative 'utils/rugged_handler'
require_relative 'utils/files'
require_relative 'utils/lines'
require_relative 'utils/ci'
require_relative 'utils/user'
require_relative 'factors/pull_request/pr_merge_stats'
require_relative 'factors/pull_request/pr_close_stats'
require_relative 'utils/personality.rb'
require_relative 'utils/affiliation.rb'
require_relative 'utils/country.rb'
require_relative 'utils/gousios.rb'
require_relative 'utils/emotion.rb'
require_relative 'factors/project/commits_on_files_touched'

class PullReqDataExtraction

  include ProjectAge
  include StarNum
  include ForkNum
  include TeamSize
  include OpenIssueNum
  include PrSuccRate
  include OpenPrNum
  include CommitsOnFilesTouched
  include PushedDelta
  include FirstResponseTime
  include PrStats
  include IssueCommentNum
  include PrCommentNum
  include CommitCommentNum
  include CommentConflict
  include ParticipantNum
  include SpecialTags
  include PrDescriptionComplexity
  include BugFix
  include RequesterSuccRate
  include AccountCreationDays
  include AcceptedCommitNum
  include FollowerNum
  include MainTeamMember
  include ContributorGender
  include ContributorCountry
  include FirstResponseTimeContributor
  include RepositoryPopularity
  include FollowingNum
  include CompanyContributor
  include ReviewerPriorReviewNum
  include CompanyReviewer
  include SubmitterFollowIntegrator
  include PriorInteractions
  include SameCountry
  include SameCompany
  include SameUser
  include PrMergeStats
  include PrCloseStats
  include Personality
  include Affiliation
  include Country
  include Gousios
  include Semaphore
  include LoggerUtil
  include Commits
  include Comments
  include PullRequest
  include Project
  include Git
  include DB
  include RuggedHandler
  include Files
  include Lines
  include CI
  include User
  include Emotion
  include CommitsOnFilesTouched

  THREADS = 1

  attr_accessor :prs, :owner, :repo, :all_commits,
                :closed_by_commit, :close_reason, :token,
                :config, :result_file, :handled_prs, :analyzable_prs,
                :affiliation_list

  def run(argv = ARGV)
    process_options
    go
    log "finish"
  end

  # main command code
  def go

    interrupted = false

    self.owner = ARGV[0]
    self.repo = ARGV[1]
    self.result_file = ARGV[2]

    self.config = YAML.load_file("config.yaml")
    # find the repo owner
    user_entry = db[:reduced_users].first(:login => self.owner)
    if user_entry.nil?
      Trollop::die "Cannot find user #{self.owner}"
    end

    # find the repo
    q = <<-QUERY
    SELECT p.id, p.language 
    FROM reduced_projects p, reduced_users u
    WHERE u.id = p.owner_id
      AND u.login = ? 
      AND p.name = ?
    QUERY
    repo_entry = db.fetch(q, owner, repo).first

    if repo_entry.nil?
      Trollop::die "Cannot find repository #{owner}/#{repo}"
    end

    # the language used by the repository
    language = repo_entry[:language]

    case language
    # c language is not supported till now
    when /ruby/i then self.extend(RubyData)
    when /javascript/i then self.extend(JavascriptData)
    when /java/i then self.extend(JavaData)
    when /scala/i then self.extend(ScalaData)
    when /python/i then self.extend(PythonData)
    when /go/i then self.extend(GoData)
    else Trollop::die "Language #{lang} not supported"
    end

    # # Update the repo
    clone(ARGV[0], ARGV[1], true)


    # read analyzable pr ids
    q = <<-QUERY
      select rpr.id
      from reduced_pull_requests rpr, analyzable_prs ap
      where ap.project_id = rpr.base_repo_id
        and ap.github_id = rpr.pullreq_id
        and ap.project_id = ?
    QUERY
    self.analyzable_prs = db.fetch(q, repo_entry[:id]).all.map{|x| x[:id]}
    log "analyzable pr num for project: " + repo_entry[:id].to_s + " is: " + self.analyzable_prs.size.to_s


    # read handled pr ids
    self.handled_prs = []
    if File.exist?(self.result_file)
      text = File.open(self.result_file, "r").read
      text.each_line do |line|
        if line.strip == ""
          next
        end
        begin
          self.handled_prs << eval(line)[:pull_request_id].to_i
        rescue StandardError => e
        end
      end
    end
    log "handled pr num: " + self.handled_prs.size.to_s


    self.affiliation_list = get_affiliation_list()

    # get the project related pull requests
    self.prs = pull_reqs(repo_entry)

    log "#{prs.size} prs in the projects to be processed"

    if prs.size == 0
      return nil
    end

    begin
      walker = Rugged::Walker.new(git)
      walker.sorting(Rugged::SORT_DATE)
      walker.push(git.head.target)
      self.all_commits = walker.map do |commit|
        commit.oid[0..10]
      end
      log "#{all_commits.size} commits in the default branch"


      q = <<-QUERY
      select c.sha
      from reduced_commits c, reduced_project_commits pc
      where pc.project_id = ?
      and pc.commit_id = c.id
      QUERY

      fixre = /(?:fixe[sd]?|close[sd]?|resolve[sd]?|fix)(?::?)(?:[\t ]+)#([0-9]+)(?:[\t ]*|$)/i

      log 'Calculating PRs closed by commits'
      commits_in_prs = db.fetch(q, repo_entry[:id]).all
      self.closed_by_commit =
        Parallel.map(commits_in_prs, :in_threads => THREADS) do |x|
          sha = x[:sha]
          result = {}
          q = <<-QUERY
            select message
            from reduced_commits_mongo
            where sha = ?
          QUERY
          a = db.fetch(q, sha).first
          if !a.nil?
            msg = a[:message]
            msg.scan(fixre) do |m|
              result[m[0].to_i] = sha
            end
          end
          result
        end.select { |x| !x.empty? }.reduce({}) { |acc, x| acc.merge(x) }
      log "#{closed_by_commit.size} PRs closed by commits"


      log "Calculating PR close reasons"
      self.close_reason = prs.reduce({}) do |acc, pr|
        mw = merged_with(pr)
        log "PR #{pr[:github_id]}, #{mw}"

        acc[pr[:github_id]] = mw
        acc
      end
      log "Close reasons: #{close_reason.group_by { |_, v| v }.reduce({}) { |acc, x| acc.merge({x[0] => x[1].size}) }}"
    end


    # Process pull request list
    # the function to start handling a pr
    do_pr = Proc.new do |pr|
      begin
        r = process_pull_request(pr, language)
        if r.nil?
        else
          log r, 1
          r
        end
      rescue StandardError => e
        log "Error processing pull_request #{pr[:github_id]}: #{e.message}"
        log e.backtrace
        #raise e
      end
    end

    results = Parallel.map(prs, :in_threads => THREADS) do |pr|
      if interrupted
        raise Parallel::Kill
      end
      do_pr.call(pr)
    end

  end



  # process a single pull request
  def process_pull_request(pr, lang)

    if self.handled_prs.include?(pr[:id]) or !self.analyzable_prs.include?(pr[:id])
      return nil
    end

    months_back = 3

    # cal all factors
    proj_pr_before = pr_before(pr)
    r_test_lines = test_lines(pr)
    r_src_lines = src_lines(pr)
    if r_test_lines.nil? or r_src_lines.nil?
      r_test_lines_per_kloc = nil
    elsif r_test_lines + r_src_lines == 0
      r_test_lines_per_kloc = 0
    else
      r_test_lines_per_kloc = r_test_lines.to_f / (r_test_lines + r_src_lines).to_f * 1000
    end
    r_num_test_cases, r_num_assertions = num_test_cases_and_assertions(pr)
    if r_test_lines.nil? || r_src_lines.nil? || r_num_test_cases.nil? || r_num_assertions.nil?
      r_test_cases_per_kloc = nil
      r_asserts_per_kloc = nil
    else
      if r_src_lines + r_test_lines == 0
        r_test_cases_per_kloc = 0
        r_asserts_per_kloc = 0
      else
        r_test_cases_per_kloc = r_num_test_cases * 1.0 / (r_src_lines + r_test_lines) * 1000
        r_asserts_per_kloc = r_num_assertions * 1.0 / (r_src_lines + r_test_lines) * 1000
      end
    end

    stats = pr_stats(pr)
    pr_emotion_stats = pr_emotion_stats_func(pr)
    pr_ci_stats = pr_ci_stats_func(pr)

    status_list = ["passed", "failed", "success", "fixed", "failure", "errored", "infrastructure_fail", "error"]
    fail_list = ["failed", "failure", "errored", "error", "infrastructure_fail"]

    if fail_list.include?(pr_ci_stats[:ci_first_build_status])
      pr_ci_stats[:ci_first_build_status] = "failure"
    elsif status_list.include?(pr_ci_stats[:ci_first_build_status])
      pr_ci_stats[:ci_first_build_status] = "success"
    end

    if fail_list.include?(pr_ci_stats[:ci_last_build_status])
      pr_ci_stats[:ci_last_build_status] = "failure"
    elsif status_list.include?(pr_ci_stats[:ci_last_build_status])
      pr_ci_stats[:ci_last_build_status] = "success"
    end

    pr_personality_stats = pr_personality_stats_func(pr)
    pr_affiliation_stats = pr_affiliation_stats_func(pr)
    pr_country_stats = pr_country_stats_func(pr)
    participant_result = participant_num(pr)
    r_at_mention_description = at_mentions_description(pr) > 0 ? true : false
    r_at_mention_comments = at_mentions_comments(pr) > 0 ? true : false
    r_hash_tag_description = hash_tag_description(pr) > 0 ? true : false
    r_hash_tag_comments = hash_tag_comments(pr) > 0 ? true : false
    r_prior_interaction_issue_events = prior_interaction_issue_events(pr, months_back)
    r_prior_interaction_issue_comments = prior_interaction_issue_comments(pr, months_back)
    r_prior_interaction_pr_events = prior_interaction_pr_events(pr, months_back)
    r_prior_interaction_pr_comments = prior_interaction_pr_comments(pr, months_back)
    r_prior_interaction_commits = prior_interaction_commits(pr, months_back)
    r_prior_interaction_commit_comments = prior_interaction_commit_comments(pr, months_back)


    # Create line for a pull request
    {
      :project_id => pr[:project_id],
      :github_id => pr[:github_id],
      :pull_request_id => pr[:id],
      :ownername => pr[:login],
      :reponame => pr[:project_name],
      :merged_or_not => pr[:mergetime_minutes].nil? ? 0 : 1,
      :lifetime_minutes => pr[:lifetime_minutes],
      :mergetime_minutes => pr[:mergetime_minutes],
      :num_commits => stats[:commit_num],
      :src_churn => stats[:lines_added] + stats[:lines_deleted],
      :test_churn => stats[:test_lines_added] + stats[:test_lines_deleted],
      :files_added => stats[:files_added],
      :files_deleted => stats[:files_removed],
      :files_modified => stats[:files_modified],
      :files_changed => stats[:files_added] + stats[:files_modified] + stats[:files_removed],
      :src_files => stats[:src_files],
      :doc_files => stats[:doc_files],
      :other_files => stats[:other_files],
      :num_commit_comments => commit_comment_num(pr),
      :num_issue_comments => issue_comment_num(pr),
      :num_comments => commit_comment_num(pr) + issue_comment_num(pr) + pr_comment_num(pr),
      :num_participants => participant_result[:participant_num],
      :sloc => r_src_lines,
      :team_size => team_size(pr, months_back),
      :perc_external_contribs => perc_external_contribs_func_new(pr, months_back),
      :commits_on_files_touched => commits_on_files_touched(pr, months_back),
      :test_lines_per_kloc => r_test_lines_per_kloc,
      :test_cases_per_kloc => r_test_cases_per_kloc,
      :asserts_per_kloc => r_asserts_per_kloc,
      :watchers => stars(pr),
      :prev_pullreqs => prev_pull_requests(pr, 'opened'),
      :requester_succ_rate => requester_succ_rate_in_project(pr),
      :followers => follower_num(pr),
      :churn_addition => stats[:lines_added] + stats[:test_lines_added],
      :churn_deletion => stats[:lines_deleted] + stats[:test_lines_deleted],
      :pr_comment_num => pr_comment_num(pr),
      :comment_num => issue_comment_num(pr) + pr_comment_num(pr) + commit_comment_num(pr),
      :perc_neg_emotion => pr_emotion_stats[:perc_pr_neg_emo],
      :perc_pos_emotion => pr_emotion_stats[:perc_pr_pos_emo],
      :perc_neu_emotion => pr_emotion_stats[:perc_pr_neu_emo],
      :part_num_issue => participant_result[:participant_num_issue],
      :part_num_commit => participant_result[:participant_num_commit],
      :part_num_pr => participant_result[:participant_num_pr],
      :part_num_code => participant_result[:participant_num_code],
      :comment_conflict => conflict?(pr),
      :hash_tag => r_hash_tag_description || r_hash_tag_comments,
      :at_tag => r_at_mention_description || r_at_mention_comments,
      :test_inclusion => stats[:test_inclusion_num] > 0 ? true : false,
      :description_length => pr_description_complexity(pr),
      :bug_fix => bug_fix?(pr),
      :ci_exists => ci_2?(pr),
      :ci_latency => pr_ci_stats[:ci_latency],
      :ci_build_num => pr_ci_stats[:ci_build_num],
      :ci_test_passed => pr_ci_stats[:ci_test_passed],
      :ci_failed_perc => pr_ci_stats[:ci_failed_percentage],
      :ci_first_build_status => pr_ci_stats[:ci_first_build_status],
      :ci_last_build_status => pr_ci_stats[:ci_last_build_status],
      :language => lang,
      :fork_num => forks(pr),
      :project_age => project_age(pr),
      :open_issue_num => open_issue_num(pr),
      :pr_succ_rate => pr_succ_rate(pr, proj_pr_before),
      :open_pr_num => open_pr_num(pr, proj_pr_before),
      :first_response_time => first_response_time(pr),
      :pushed_delta => pushed_delta(pr),
      :acc_commit_num => accepted_commit_num_in_project(pr),
      :first_pr => prev_pull_requests(pr, 'opened') > 0 ? false : true,
      :account_creation_days => account_creation_days(pr),
      :core_member => main_team_member?(pr),
      :contrib_gender => contributor_gender(pr),
      :contrib_country => pr_country_stats[:contrib_country],
      :contrib_affiliation => pr_affiliation_stats[:contrib_affiliation],
      :contrib_open => pr_personality_stats[:contrib_open],
      :contrib_cons => pr_personality_stats[:contrib_cons],
      :contrib_extra => pr_personality_stats[:contrib_extra],
      :contrib_agree => pr_personality_stats[:contrib_agree],
      :contrib_neur => pr_personality_stats[:contrib_neur],
      :perc_contrib_neg_emo => pr_emotion_stats[:perc_contrib_neg_emo],
      :perc_contrib_pos_emo => pr_emotion_stats[:perc_contrib_pos_emo],
      :perc_contrib_neu_emo => pr_emotion_stats[:perc_contrib_neu_emo],
      :contrib_first_emo => pr_emotion_stats[:contrib_first_emo],
      :prior_review_num => reviewer_prior_review_num(pr),
      :inte_country => pr_country_stats[:inte_country],
      :inte_affiliation => pr_affiliation_stats[:inte_affiliation],
      :inte_open => pr_personality_stats[:inte_open],
      :inte_cons => pr_personality_stats[:inte_cons],
      :inte_extra => pr_personality_stats[:inte_extra],
      :inte_agree => pr_personality_stats[:inte_agree],
      :inte_neur => pr_personality_stats[:inte_neur],
      :perc_inte_neg_emo => pr_emotion_stats[:perc_inte_neg_emo],
      :perc_inte_pos_emo => pr_emotion_stats[:perc_inte_pos_emo],
      :perc_inte_neu_emo => pr_emotion_stats[:perc_inte_neu_emo],
      :inte_first_emo => pr_emotion_stats[:inte_first_emo],
      :contrib_follow_integrator => submitter_follow_integrator?(pr),
      :prior_interaction => r_prior_interaction_issue_events + r_prior_interaction_issue_comments +
                                r_prior_interaction_pr_events + r_prior_interaction_pr_comments +
                                r_prior_interaction_commits + r_prior_interaction_commit_comments,
      :social_strength => social_strength(pr, months_back),
      :same_country => pr_country_stats[:same_country],
      :same_affiliation => pr_affiliation_stats[:same_affiliation],
      :open_diff => pr_personality_stats[:open_diff],
      :cons_diff => pr_personality_stats[:cons_diff],
      :extra_diff => pr_personality_stats[:extra_diff],
      :agree_diff => pr_personality_stats[:agree_diff],
      :neur_diff => pr_personality_stats[:neur_diff]
    }

  end



  def process_options
    @options = Trollop::options do
      banner <<-BANNER
Extract data for pull requests for a given repository

#{File.basename($0)} owner repo token

      BANNER
      opt :config, 'config.yaml file location', :short => 'c',
          :default => 'config.yaml'
    end
  end

  def pull_reqs(project, github_id = -1)
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
    QUERY

    if github_id != -1
      q += " and pr.pullreq_id = #{github_id} "
    end
    q += 'group by pr.id order by pr.pullreq_id desc;'

    db.fetch(q, project[:id]).all
  end

end

pr = PullReqDataExtraction.new
pr.run