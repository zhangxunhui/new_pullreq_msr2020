module FollowerNum
  def follower_num(pr)
    q = <<-QUERY
    select count(f.follower_id) as num_followers
    from reduced_followers f
    where f.user_id = ?
      and f.created_at < ?
    QUERY
    db.fetch(q, pr[:pr_creator_id], pr[:created_at]).first[:num_followers]
  end
end