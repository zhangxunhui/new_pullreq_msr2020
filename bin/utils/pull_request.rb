module PullRequest

  # read the details of pull request in mongodb
  # mainly for the title and body
  def pull_req_entry(pr)
    q = <<-QUERY
      select title, body
      from reduced_pull_requests_mongo
      where pull_request_id = ?
    QUERY
    db.fetch(q, pr[:id]).first
    #mongo['pull_requests'].find({:owner => pr[:login],
    #                             :repo => pr[:project_name],
    #                             :number => pr[:github_id]}).limit(1).first
  end


  # whether the github_id represents a pr
  def pull_request?(pr, github_id)
    q = <<-QUERY
      select * 
      from reduced_pull_requests
      where pullreq_id = ?
        and base_repo_id = ?
    QUERY
    db.fetch(q, github_id, pr[:project_id]).all.size > 0
  end


  # Checks how a merge occured (A Dataset for Pull Request Research)
  # how the pull_request is merged
  def merged_with(pr)
    #0. Merged with Github?
    q = <<-QUERY
	  select prh.id as merge_id
    from reduced_pull_request_history prh
	  where prh.action = 'merged'
      and prh.pull_request_id = ?
    QUERY
    r = db.fetch(q, pr[:id]).first
    unless r.nil?
      return :merge_button
    end

    #1. Commits from the pull request appear in the project's main branch
    q = <<-QUERY
	  select c.sha
    from reduced_pull_request_commits prc, reduced_commits c
	  where prc.commit_id = c.id
      and prc.pull_request_id = ?
    QUERY
    db.fetch(q, pr[:id]).all.each do |x|
      unless all_commits.select { |y| x[:sha].start_with? y }.empty?
        return :commits_in_master
      end
    end

    #2. The PR was closed by a commit (using the Fixes: convention).
    # Check whether the commit that closes the PR is in the project's
    # master branch (actually it's the default branch, not all the projects' default branch is master branch)
    sha = closed_by_commit[pr[:github_id]]
    unless sha.nil?
      if all_commits.include? sha
        return :fixes_in_commit
      end
    end

    # should take all kinds of comments into consideration (issue_comments/pull_request_comments/commit_comments)
    issue_comments = issue_comments(pr)

    # query pull_request_comments
    pull_request_comments = pr_comments(pr)

    # query commit_comments
    commit_comments = commit_comments(pr)

    comments = issue_comments.reverse.take(3)
                   .concat(pull_request_comments.reverse.take(3))
                   .concat(commit_comments.reverse.take(3))

    comments.map { |x| x[:body] }.uniq.each do |last|
      # 3. Last comment contains a commit number
      last.scan(/([0-9a-f]{6,40})/m).each do |x|
        # Commit is identified as merged
        if last.match(/merg(?:ing|ed)/i) or
            last.match(/appl(?:ying|ied)/i) or
            last.match(/pull[?:ing|ed]/i) or
            last.match(/push[?:ing|ed]/i) or
            last.match(/integrat[?:ing|ed]/i)
          return :commit_sha_in_comments
        else
          # Commit appears in master branch
          unless all_commits.select { |y| x[0].start_with? y }.empty?
            return :commit_sha_in_comments
          end
        end
      end

      # 4. Merg[ing|ed] or appl[ing|ed] as last comment of pull request
      if last.match(/merg(?:ing|ed)/i) or
          last.match(/appl(?:ying|ed)/i) or
          last.match(/pull[?:ing|ed]/i) or
          last.match(/push[?:ing|ed]/i) or
          last.match(/integrat[?:ing|ed]/i)
        return :merged_in_comments
      end
    end

    :unknown
  end


  # Number of previous pull requests for the pull requester (in the target project)
  # project_related represents whether the contribution is related to the target project or not
  # This is actually not suitable for closed prs, because closed prs may be reopened before the creation of this pr!!!!!!!!!!!
  def prev_pull_requests(pr, action, proj_related = true)

    if action == 'merged' and proj_related
      q = <<-QUERY
      select pr.pullreq_id, prh.pull_request_id as num_pull_reqs
      from reduced_pull_request_history prh, reduced_pull_requests pr
      where prh.action = 'opened'
        and prh.created_at < ?
        and prh.actor_id = ?
        and prh.pull_request_id = pr.id
        and pr.base_repo_id = ?;
      QUERY
      pull_reqs = db.fetch(q, pr[:created_at], pr[:pr_creator_id], pr[:project_id]).all
      pull_reqs.reduce(0) do |acc, pull_req|
        if not close_reason[pull_req[:pullreq_id]].nil? and close_reason[pull_req[:pullreq_id]][1] != :unknown # this means that the commits in pr are merged
          acc += 1
        end
        acc
      end
    elsif action == 'merged' and !proj_related
      q = <<-QUERY
      select pr.pullreq_id, prh.pull_request_id as num_pull_reqs
      from reduced_pull_request_history prh, reduced_pull_requests pr
      where prh.action = 'opened'
        and prh.created_at < ?
        and prh.actor_id = ?
        and prh.pull_request_id = pr.id
      QUERY
      pull_reqs = db.fetch(q, pr[:created_at], pr[:pr_creator_id]).all
      pull_reqs.reduce(0) do |acc, pull_req|
        if not close_reason[pull_req[:pullreq_id]].nil? and close_reason[pull_req[:pullreq_id]][1] != :unknown # this means that the commits in pr are merged
          acc += 1
        end
        acc
      end
    elsif action != 'merged' and proj_related
      q = <<-QUERY
      select pr.pullreq_id, prh.pull_request_id as num_pull_reqs
      from reduced_pull_request_history prh, reduced_pull_requests pr
      where prh.action = ?
        and prh.created_at < ?
        and prh.actor_id = ?
        and prh.pull_request_id = pr.id
        and pr.base_repo_id = ?
      QUERY
      db.fetch(q, action, pr[:created_at], pr[:pr_creator_id], pr[:project_id]).all.size
    else
      q = <<-QUERY
      select pr.pullreq_id, prh.pull_request_id as num_pull_reqs
      from reduced_pull_request_history prh, reduced_pull_requests pr
      where prh.action = ?
        and prh.created_at < ?
        and prh.actor_id = ?
        and prh.pull_request_id = pr.id
      QUERY
      db.fetch(q, action, pr[:created_at], pr[:pr_creator_id]).all.size
    end
  end


  # get all the issues in the target project before the pr's creation time
  def issues_before(pr)
    q = <<-QUERY
      select id
      from reduced_issues
      where repo_id = ?
        and created_at < ?
        and pull_request = 0
    QUERY
    db.fetch(q, pr[:project_id], pr[:created_at]).all.map {|a| a[:id]}
  end

  # get all the issues that are closed before the pr's creation time
  def issues_before_closed(pr)
    q = <<-QUERY
      select i.id, ie.action, ie.created_at
      from reduced_issue_events ie, reduced_issues i
      where ie.issue_id = i.id
        and (ie.action = 'closed' or ie.action = 'reopened')
        and i.repo_id = ?
        and ie.created_at < ?
        and i.pull_request = 0
    QUERY
    db.fetch(q, pr[:project_id], pr[:created_at]).all.reduce({}) do |acc, x|
      if !acc.key?(x[:id]) or acc[x[:id]][:created_at] < x[:created_at]
        acc.update(x[:id] => {:created_at => x[:created_at], :action => x[:action]})
      else
        acc
      end
    end.reduce([]) do |acc, (id, v)|
      if v[:action] == "closed"
        acc << id
      else
        acc
      end
    end
  end


  # pull requests in the target project before the pr's creation time
  def pr_before(pr)
    q = <<-QUERY
      select pr.id
      from reduced_pull_requests pr, reduced_pull_request_history prs
      where pr.id = prs.pull_request_id
        and base_repo_id = ?
        and prs.action = 'opened'
        and prs.created_at < ?
    QUERY
    db.fetch(q, pr[:project_id], pr[:created_at]).all.map {|x| x[:id]}
  end

  # pull requests merged in the target project before the pr's creation time
  def pr_before_merged(pr)
    q = <<-QUERY
      select pr.id, pr.pullreq_id, prh.pull_request_id as num_pull_reqs
      from reduced_pull_request_history prh, reduced_pull_requests pr
      where prh.action = 'opened'
        and prh.created_at < ?
        and prh.pull_request_id = pr.id
        and pr.base_repo_id = ?
    QUERY
    pull_reqs = db.fetch(q, pr[:created_at], pr[:project_id]).all
    pull_reqs.reduce([]) do |acc, pull_req|
      if not close_reason[pull_req[:pullreq_id]].nil? and close_reason[pull_req[:pullreq_id]][1] != :unknown # this means that the commits in pr are merged
        acc << pull_req[:id]
      end
      acc
    end
  end

  # pull requests closed in the target project before the pr's creation time, except for reopened
  def pr_before_closed(pr)
    q = <<-QUERY
      select pr.id, prh.action, prh.created_at
      from reduced_pull_requests pr, reduced_pull_request_history prh
      where pr.id = prh.pull_request_id
        and prh.created_at < ?
        and ( prh.action = 'closed' or prh.action = 'reopened' )
        and pr.base_repo_id = ?
    QUERY
    db.fetch(q, pr[:created_at], pr[:project_id]).all.reduce({}) do |acc, x|
      if !acc.key?(x[:id]) or acc[x[:id]][:created_at] < x[:created_at]
        acc.update(x[:id] => {:created_at => x[:created_at], :action => x[:action]})
      else
        acc
      end
    end.reduce([]) do |acc, (id, v)|
      if v[:action] == "closed"
        acc << id
      else
        acc
      end
    end
  end

end