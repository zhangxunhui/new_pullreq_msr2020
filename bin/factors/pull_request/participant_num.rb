module ParticipantNum

  # the number of participants in pr discussion
  # why doesn't take commit_comment into consideration
  def participant_num(pr)
    result = {}

    # number of participants in issue_comments before the last close time of pr
    q = <<-QUERY
    select distinct(user_id) from 
    reduced_issue_comments ic, reduced_issues i 
    where ic.issue_id = i.id
      and i.pull_request_id = ?
      and ic.created_at <= ?
    QUERY
    participant_issue = db.fetch(q, pr[:id], pr[:closed_at]).all
    result[:participant_num_issue] = participant_issue.size

    # number of participants in pull_request_comments
    q = <<-QUERY
    select distinct(user_id)
    from reduced_pull_request_comments
    where pull_request_id = ?
    and created_at <= ?
    QUERY
    participant_pr = db.fetch(q, pr[:id], pr[:closed_at]).all
    result[:participant_num_pr] = participant_pr.size

    # number of participants in commit_comments
    q = <<-QUERY
    select distinct(user_id)
    from reduced_commit_comments cc, reduced_pull_request_commits prc
    where cc.commit_id = prc.commit_id
      and prc.pull_request_id = ?
      and cc.created_at <= ?
    QUERY
    participant_commit = db.fetch(q, pr[:id], pr[:closed_at]).all
    result[:participant_num_commit] = participant_commit.size

    # number of code related comments
    result[:participant_num_code] = (participant_pr.to_set + participant_commit.to_set).size

    # number of all the participants
    result[:participant_num] = (participant_pr.to_set + participant_commit.to_set + participant_issue.to_set).size

    result
  end

end