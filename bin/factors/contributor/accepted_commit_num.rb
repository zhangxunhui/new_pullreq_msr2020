module AcceptedCommitNum

  def accepted_commit_num_in_project(pr)

    # find all the commits in the project before the pr creation time
    q = <<-QUERY
      select c.sha
      from reduced_commits c, reduced_project_commits pc
      where pc.project_id = ?
        and c.created_at < ?
        and c.id = pc.commit_id
        and c.author_id = ?
    QUERY
    db.fetch(q, pr[:project_id], pr[:created_at], pr[:pr_creator_id]).all.size
  end


  def accepted_commit_num(pr)
    q = <<-QUERY
      select c.sha
      from reduced_commits c, reduced_project_commits pc
      where c.id = pc.commit_id
      and c.created_at < ?
      and c.author_id = ?
    QUERY
    db.fetch(q, pr[:created_at], pr[:pr_creator_id]).all.size
  end

end