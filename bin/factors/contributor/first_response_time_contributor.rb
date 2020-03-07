module FirstResponseTimeContributor

  # the minutes that take for contributor to response after the first response of a real reviewer
  def first_response_time_contributor(pr)
    # first pull request comment (reviewer/author)
    first_response_time_reviewer = first_response_time(pr) # minutes
    if first_response_time_reviewer.nil?
      return nil
    end

    first_response_time_reviewer = Time.at(Time.at(pr[:created_at] + first_response_time_reviewer * 60))

    # the author's first response after the first review
    q = <<-QUERY
      select min(created) as first_resp from (
        select min(prc.created_at) as created
        from reduced_pull_request_comments prc, reduced_users u
        where prc.pull_request_id = ?
          and u.id = prc.user_id
          and u.id = ?
          and prc.created_at < ?
          and prc.created_at > ?
        union
        select min(ic.created_at) as created
        from reduced_issues i, reduced_issue_comments ic, reduced_users u
        where i.pull_request_id = ?
          and i.id = ic.issue_id
          and u.id = ic.user_id
          and u.id = ?
          and ic.created_at < ?
          and ic.created_at > ?
        union
        select min(cc.created_at) as created
          from reduced_commit_comments cc, reduced_pull_request_commits prc, reduced_users u
          where prc.commit_id = cc.commit_id
            and u.id = cc.user_id
            and prc.pull_request_id = ?
            and u.id = ?
            and cc.created_at < ?
            and cc.created_at > ?
      ) as a
    QUERY
    resp = db.fetch(q, pr[:id], pr[:pr_creator_id], pr[:closed_at], first_response_time_reviewer,
                    pr[:id], pr[:pr_creator_id], pr[:closed_at], first_response_time_reviewer,
                    pr[:id], pr[:pr_creator_id], pr[:closed_at], first_response_time_reviewer).first[:first_resp]
    unless resp.nil?
      (resp - first_response_time_reviewer).to_i / 60
    else
      nil
    end
  end

end