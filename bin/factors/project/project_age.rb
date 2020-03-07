module ProjectAge

  # The age of a project
  # (the time from project creation on GitHub to the pull-request creation in months)
  def project_age(pr)
    q = <<-QUERY
    select timestampdiff(month, p.created_at, prh.created_at) as project_age
    from reduced_projects p, reduced_pull_requests pr, reduced_pull_request_history prh
    where pr.id = prh.pull_request_id
      and prh.action = 'opened'
      and p.id = ?
      and pr.id = ?
    QUERY

    db.fetch(q, pr[:project_id], pr[:id]).first[:project_age]
  end

end