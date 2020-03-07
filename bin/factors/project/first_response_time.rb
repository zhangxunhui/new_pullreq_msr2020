module FirstResponseTime

  # are there other new robots except for travis-ci and cloudbees?????????
  # these robots cannot be removed

  # the average time interval in minutes from pull-request creation to the first response by reviewers
  # before the pr and months_back
  def first_response_project(pr, months_back = nil)
    # get the prs taken into consideration before the target pr
    q = <<-QUERY
      select pr.id as id, pr.pullreq_id as github_id, prh.created_at as created_at
      from reduced_pull_requests pr, reduced_pull_request_history prh
      where pr.id = prh.pull_request_id
        and prh.created_at < ?
        and prh.action = 'opened'
        and pr.base_repo_id = ?
    QUERY
    if !months_back.nil?
      oldest = Time.at(Time.at(pr[:created_at]).to_i - 3600 * 24 * 30 * months_back)
      q += " and prh.created_at >= ?"
      query_result = db.fetch(q, pr[:created_at], pr[:project_id], oldest).all
    else
      query_result = db.fetch(q, pr[:created_at], pr[:project_id]).all
    end
    resultArray = query_result.map do |p|

      # close time
      close_time = prs.select do |x|
        x[:id] == p[:id]
      end.map {|x| x[:closed_at]}

      # first comment time
      q = <<-QUERY
        select min(created) as first_resp from (
          select min(ic.created_at) as created
          from reduced_issue_comments ic, reduced_issues i, reduced_users u
          where ic.issue_id = i.id
            and u.id = ic.user_id
            and i.pull_request_id = ?
            and u.id != ?
          union
          select min(prc.created_at) as created
            from reduced_pull_request_comments prc, reduced_users u
            where prc.pull_request_id = ?
              and u.id = prc.user_id
              and u.id != ?
          union
          select min(cc.created_at) as created
            from reduced_commit_comments cc, reduced_pull_request_commits prc, reduced_users u
            where prc.commit_id = cc.commit_id
              and prc.pull_request_id = ? 
              and u.id = cc.user_id
              and u.id != ?
        ) as a
      QUERY
      resp = db.fetch(q, p[:id], pr[:pr_creator_id], p[:id], pr[:pr_creator_id], p[:id], pr[:pr_creator_id]).first[:first_resp]
      unless resp.nil?
        if close_time.size > 0 and resp > close_time[0]
          nil
        else
          (resp - p[:created_at]).to_i / 60
        end
      else
        nil
      end
    end
    result_sum = resultArray.reduce(0.0) do |acc, x|
      if x.nil?
        acc
      else
        acc += x
      end
    end
    if resultArray.select{|x| !x.nil?}.size == 0
      nil
    else
      result_sum / resultArray.select{|x| !x.nil?}.size
    end
  end


  # first response time of the target pr
  # should not take the comments after the last close time of the pr
  # should not take robots' comments into consideration
  # should not take the contributor's response into consideration
  def first_response_time(pr)
    q = <<-QUERY
      select min(created) as first_resp from (
        select min(prc.created_at) as created
        from reduced_pull_request_comments prc, reduced_users u
        where prc.pull_request_id = ?
          and u.id = prc.user_id
          and u.id != ?
          and prc.created_at < ?
        union
        select min(ic.created_at) as created
        from reduced_issues i, reduced_issue_comments ic, reduced_users u
        where i.pull_request_id = ?
          and i.id = ic.issue_id
          and u.id = ic.user_id
          and u.id != ?
          and ic.created_at < ?
        union
        select min(cc.created_at) as created
          from reduced_commit_comments cc, reduced_pull_request_commits prc, reduced_users u
          where prc.commit_id = cc.commit_id
            and u.id = cc.user_id
            and prc.pull_request_id = ?
            and u.id != ?
            and cc.created_at < ?
      ) as a
    QUERY
    resp = db.fetch(q, pr[:id], pr[:pr_creator_id], pr[:closed_at],
                    pr[:id], pr[:pr_creator_id], pr[:closed_at],
                    pr[:id], pr[:pr_creator_id], pr[:closed_at]).first[:first_resp]
    unless resp.nil?
      (resp - pr[:created_at]).to_i / 60
    else
      nil
    end
  end
end