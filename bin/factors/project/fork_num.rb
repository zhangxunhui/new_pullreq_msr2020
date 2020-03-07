module ForkNum

  # Number of project forks at the time the pull request was made
  # should we take the deleted projects into consideration?????
  def forks(pr)
    q = <<-QUERY
    select count(*) as num_forks 
    from projects p
    where p.created_at < ? 
      and p.forked_from = ?
    QUERY
    db.fetch(q, pr[:created_at], pr[:project_id]).first[:num_forks]
  end


end