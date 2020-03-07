module SubmitterFollowIntegrator

  # before close time
  def submitter_follow_integrator?(pr)
    q = <<-QUERY
      select * 
      from reduced_followers
      where user_id = ?
      and follower_id = ?
      and created_at < ?
    QUERY
    queryResult = db.fetch(q, pr[:closed_reviewer_id], pr[:pr_creator_id], pr[:closed_at]).all
    if queryResult.size > 0
      true
    else
      false
    end
  end

end