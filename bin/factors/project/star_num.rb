module StarNum

  # Number of project watchers/stargazers at the time the pull request was made
  def stars(pr)
    q = <<-QUERY
    select count(w.user_id) as num_watchers
    from reduced_watchers w
    where w.created_at < ?
      and w.repo_id = ?
    QUERY
    db.fetch(q, pr[:created_at], pr[:project_id]).first[:num_watchers]
  end

end