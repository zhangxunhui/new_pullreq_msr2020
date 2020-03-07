module PrCommentNum
  # Number of pull request code review comments in pull request
  # author_only means whether only consider the pr author's comment
  def pr_comment_num(pr, author_only = false)
    if !author_only
      q = <<-QUERY
      select count(*) as comment_count
      from reduced_pull_request_comments prc
      where prc.pull_request_id = ?
      and prc.created_at <= ?
      QUERY
      db.fetch(q, pr[:id], pr[:closed_at]).first[:comment_count]
    else
      q = <<-QUERY
      select count(*) as comment_count
      from reduced_pull_request_comments prc
      where prc.pull_request_id = ?
      and prc.created_at <= ?
      and prc.user_id = ?
      QUERY
      db.fetch(q, pr[:id], pr[:closed_at], pr[:pr_creator_id]).first[:comment_count]
    end
  end
end