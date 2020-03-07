module CommitCommentNum

  # Number of commit comments on commits composing the pull request
  # author_only means whether only consider the pr author's comment
  def commit_comment_num(pr, at_open = false, author_only = false)
    if at_open && !author_only
      q = <<-QUERY
      select count(*) as commit_comment_count
      from reduced_pull_request_commits prc, reduced_commit_comments cc
      where prc.commit_id = cc.commit_id
        and cc.created_at <= ?
        and prc.pull_request_id = ?
      QUERY
      db.fetch(q, pr[:created_at], pr[:id]).first[:commit_comment_count]
    elsif at_open && author_only
      q = <<-QUERY
      select count(*) as commit_comment_count
      from reduced_pull_request_commits prc, reduced_commit_comments cc
      where prc.commit_id = cc.commit_id
        and cc.created_at <= ?
        and prc.pull_request_id = ?
        and cc.user_id = ?
      QUERY
      db.fetch(q, pr[:created_at], pr[:id], pr[:pr_creator_id]).first[:commit_comment_count]
    elsif !at_open && author_only
      # cc.created_at <= closed_at is needed!!!!!!
      q = <<-QUERY
      select count(*) as commit_comment_count
      from reduced_pull_request_commits prc, reduced_commit_comments cc
      where prc.commit_id = cc.commit_id
        and prc.pull_request_id = ?
        and cc.user_id = ?
        and cc.created_at <= ?
      QUERY
      db.fetch(q, pr[:id], pr[:pr_creator_id], pr[:closed_at]).first[:commit_comment_count]
    else
      q = <<-QUERY
      select count(*) as commit_comment_count
      from reduced_pull_request_commits prc, reduced_commit_comments cc
      where prc.commit_id = cc.commit_id
        and prc.pull_request_id = ?
        and cc.created_at <= ?
      QUERY
      db.fetch(q, pr[:id], pr[:closed_at]).first[:commit_comment_count]
    end
  end

end