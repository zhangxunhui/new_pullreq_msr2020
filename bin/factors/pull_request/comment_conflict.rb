module CommentConflict

  # whether there exists word "conflict" in issue comments
  # why doesn't take pull_request_comment and commit_comment into consideration
  def conflict?(pr)
    ccs = commit_comments(pr)
    prcs = pr_comments(pr)
    ics = issue_comments(pr)
    comments = ccs + prcs + ics
    if comments.size <= 0
      false
    else
      comments.reduce(false) do |acc, x|
        acc || (not x[:body].match(/conflict/i).nil?)
      end
    end
  end

end