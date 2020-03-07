module FollowingNum

  def following_num(pr)
    q = <<-QUERY
    select count(f.user_id) as num_followings
    from reduced_followers f
    where f.follower_id = ?
      and f.created_at < ?
    QUERY
    db.fetch(q, pr[:pr_creator_id], pr[:created_at]).first[:num_followings]
  end

end