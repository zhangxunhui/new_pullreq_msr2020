module Project


  # find the core teams in the project before pr creation time
  def core_team(pr, months_back = nil)
    q = <<-QUERY
      select user_id
      from reduced_project_core_members
      where project_id=?
      and created_at<?
    QUERY
    if !months_back.nil?
      oldest = Time.at(Time.at(pr[:created_at]).to_i - 3600 * 24 * 30 * months_back)
      q += " and created_at >= ?"
      result = db[q, pr[:project_id], pr[:created_at], oldest].map{|x| x[:user_id]}
    else
      result = db[q, pr[:project_id], pr[:created_at]].map{|x| x[:user_id]}
    end
    return result
  end

  # People that merged (not necessarily through pull requests) up to months_back
  # from the time the built PR was created.
  # if months_back is nil, don't take create time into consideration
  def merger_team(pr, months_back = nil)
    recently_merged = prs.find_all do |b|
      close_reason[b[:github_id]] != :unknown and
          (months_back.nil? ? true : b[:created_at].to_i > (pr[:created_at].to_i - months_back * 30 * 24 * 3600))
    end.map do |b|
      b[:github_id]
    end

    q = <<-QUERY
    select u1.login as merger
    from reduced_users u, reduced_projects p, reduced_pull_requests pr, reduced_pull_request_history prh, reduced_users u1
    where prh.action = 'closed'
      and prh.actor_id = u1.id
      and prh.pull_request_id = pr.id
      and pr.base_repo_id = p.id
      and p.owner_id = u.id
      and u.login = ?
      and p.name = ?
      and pr.pullreq_id = ?
    QUERY
    log q

    recently_merged.map do |pr_num|
      a = db.fetch(q, pr[:login], pr[:project_name], pr_num).first
      if not a.nil? then a[:merger] else nil end
    end.select {|x| not x.nil?}.uniq

  end

  # People that committed (not through pull requests) up to months_back
  # from the time the PR was created.
  # if months_back is nil, don't take create time into consideration
  def committer_team(pr, months_back = nil)
    q = <<-QUERY
    select distinct(u.login) as committer
    from reduced_commits c, reduced_project_commits pc, reduced_pull_requests pr, reduced_users u, reduced_pull_request_history prh
    where pr.base_repo_id = pc.project_id
      and not exists (select * from reduced_pull_request_commits where commit_id = c.id)
      and pc.commit_id = c.id
      and pr.id = ?
      and u.id = c.committer_id
      and u.fake is false
      and prh.pull_request_id = pr.id
      and prh.action = 'opened'
      and c.created_at < prh.created_at
    QUERY
    if !months_back.nil?
      q += " and c.created_at > DATE_SUB(prh.created_at, INTERVAL #{months_back} MONTH)"
    end
    log q
    db.fetch(q, pr[:id]).all.map{|x| x[:committer]}
  end

end