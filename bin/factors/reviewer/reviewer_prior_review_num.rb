module ReviewerPriorReviewNum

  def reviewer_prior_review_num(pr)
    # the number of review activities of the pr's reviewer (before the close time of the pr)
    # the number of closes of the reviewer
    q = <<-QUERY
      select pr.id
      from reduced_pull_requests pr, reduced_pull_request_history prh
      where ( prh.action = 'closed' or prh.action = 'merged' )
        and prh.created_at < ?
        and prh.actor_id = ?
        and pr.id = prh.pull_request_id
        and pr.base_repo_id = ?
    QUERY
    db.fetch(q, pr[:closed_at], pr[:closed_reviewer_id], pr[:project_id]).all.map{|x| x[:id]}.uniq.size
  end

end
