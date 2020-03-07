module PushedDelta

  def pushed_delta(pr)

    q = <<-QUERY
      select prh.created_at
      from reduced_pull_requests pr, reduced_pull_request_history prh
      where pr.id = prh.pull_request_id
      and prh.action = 'opened'
      and pr.base_repo_id = ?
      and prh.created_at < ?
      order by prh.created_at desc
      limit 2
    QUERY
    result = db.fetch(q, pr[:project_id], pr[:created_at]).all.map{|x| x[:created_at]}
    if result.size == 2
      result[0] - result[1]
    else
      nil # before this pr, there are less than 2 prs
    end

    # prs_tmp = prs.sort {|a, b| b[:created_at] <=> a[:created_at]}
    #
    # merged_prs_before = prs_tmp.find_all do |b|
    #   close_reason[b[:github_id]] != :unknown and \
    #   b[:created_at] < pr[:created_at]
    # end
    #
    # merged_prs_before[0][:created_at] - merged_prs_before[1][:created_at]

  end

end