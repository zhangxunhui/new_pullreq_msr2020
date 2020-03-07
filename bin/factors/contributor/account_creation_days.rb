module AccountCreationDays

  def account_creation_days(pr)
    q = <<-QUERY
      select timestampdiff(day, u.created_at, prh.created_at) as account_creation_days
      from reduced_users u, reduced_pull_request_history prh
      where u.id = prh.actor_id
        and u.id = ?
        and prh.action = 'opened'
        and prh.pull_request_id = ?
    QUERY
    db.fetch(q, pr[:pr_creator_id], pr[:id]).first[:account_creation_days]
  end

end