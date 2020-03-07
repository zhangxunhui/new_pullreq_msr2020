module OpenIssueNum

  # Num of opened issues before the creation of this pr
  def open_issue_num(pr)
    issues = issues_before(pr)
    closed_issues = issues_before_closed(pr)
    (issues.to_set - closed_issues.to_set).size
  end

end