module IssueCommentNum

  # before the last close of the pr, how many discussion comments are there
  # author_only means whether only consider the pr author's comment
  def issue_comment_num(pr, author_only = false)
    if !author_only
      q = <<-QUERY
      select count(*) as issue_comment_count
      from reduced_pull_requests pr, reduced_issue_comments ic, reduced_issues i
      where ic.issue_id=i.id
      and i.issue_id=pr.pullreq_id
      and pr.base_repo_id = i.repo_id
      and pr.id = ?
      and ic.created_at <= ?
      QUERY
      db.fetch(q, pr[:id], pr[:closed_at]).first[:issue_comment_count]
    else
      q = <<-QUERY
      select count(*) as issue_comment_count
      from reduced_pull_requests pr, reduced_issue_comments ic, reduced_issues i
      where ic.issue_id=i.id
      and i.issue_id=pr.pullreq_id
      and pr.base_repo_id = i.repo_id
      and pr.id = ?
      and ic.created_at <= ? 
      and ic.user_id = ?
      QUERY
      db.fetch(q, pr[:id], pr[:closed_at], pr[:pr_creator_id]).first[:issue_comment_count]
    end
  end
end