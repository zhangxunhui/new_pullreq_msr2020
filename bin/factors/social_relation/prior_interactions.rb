module PriorInteractions

  # The number of events before a particular pull request that the user has
  # participated in for this project.
  def prior_interaction_issue_events(pr, months_back)
    oldest = Time.at(Time.at(pr[:created_at]).to_i - 3600 * 24 * 30 * months_back)
    q = <<-QUERY
      select count(distinct(i.id)) as num_issue_events
      from reduced_issue_events ie, reduced_issues i
      where ie.actor_id = ?
        and i.repo_id = ?
        and i.id = ie.issue_id
        and ie.created_at > ?
        and ie.created_at < ?
    QUERY
    db.fetch(q, pr[:pr_creator_id], pr[:project_id], oldest, pr[:created_at]).first[:num_issue_events]
  end

  def prior_interaction_issue_comments(pr, months_back)
    oldest = Time.at(Time.at(pr[:created_at]).to_i - 3600 * 24 * 30 * months_back)
    q = <<-QUERY
    select count(distinct(ic.comment_id)) as issue_comment_count
    from reduced_issues i, reduced_issue_comments ic
    where ic.user_id = ?
      and i.repo_id = ?
      and i.id = ic.issue_id
      and ic.created_at > ?
      and ic.created_at < ?
    QUERY
    db.fetch(q, pr[:pr_creator_id], pr[:project_id], oldest, pr[:created_at]).first[:issue_comment_count]
  end

  def prior_interaction_pr_events(pr, months_back)
    oldest = Time.at(Time.at(pr[:created_at]).to_i - 3600 * 24 * 30 * months_back)
    q = <<-QUERY
    select count(distinct(prh1.id)) as count_pr
    from  reduced_pull_request_history prh1
    where prh1.actor_id = ?
      and prh1.pull_request_id = ?
      and prh1.created_at > ?
      and prh1.created_at < ?
    QUERY
    db.fetch(q, pr[:pr_creator_id], pr[:id], oldest, pr[:created_at]).first[:count_pr]
  end

  def prior_interaction_pr_comments(pr, months_back)
    oldest = Time.at(Time.at(pr[:created_at]).to_i - 3600 * 24 * 30 * months_back)
    q = <<-QUERY
    select count(distinct(prc.comment_id)) as count_pr_comments
    from reduced_pull_request_comments prc
    where prc.user_id = ?
      and prc.pull_request_id = ?
      and prc.created_at > ?
      and prc.created_at < ?
    QUERY
    db.fetch(q, pr[:pr_creator_id], pr[:id], oldest, pr[:created_at]).first[:count_pr_comments]
  end

  def prior_interaction_commits(pr, months_back)
    oldest = Time.at(Time.at(pr[:created_at]).to_i - 3600 * 24 * 30 * months_back)
    q = <<-QUERY
    select count(distinct(c.id)) as count_commits
    from reduced_commits c, reduced_project_commits pc
    where (c.author_id = ? or c.committer_id = ?)
      and pc.project_id = ?
      and c.id = pc.commit_id
      and c.created_at > ?
      and c.created_at < ?
    QUERY
    db.fetch(q, pr[:pr_creator_id], pr[:pr_creator_id], pr[:project_id], oldest, pr[:created_at]).first[:count_commits]
  end

  def prior_interaction_commit_comments(pr, months_back)
    oldest = Time.at(Time.at(pr[:created_at]).to_i - 3600 * 24 * 30 * months_back)
    q = <<-QUERY
    select count(distinct(cc.id)) as count_commits
    from reduced_commits c, reduced_project_commits pc, reduced_commit_comments cc
    where cc.commit_id = c.id
      and cc.user_id = ?
      and pc.project_id = ?
      and c.id = pc.commit_id
      and cc.created_at > ?
      and cc.created_at < ?
    QUERY
    db.fetch(q, pr[:pr_creator_id], pr[:project_id], oldest, pr[:created_at]).first[:count_commits]
  end


  def social_strength(pr, months_back)

    linked_integrators = []
    core_team = core_team(pr).uniq

    # comments that the submitter participated in the last 'months_back' months
    issue_github_ids = commented_issues(pr, pr[:pr_creator_id], months_back)
    pr_github_ids = commented_pull_requests(pr, pr[:pr_creator_id], months_back)
    commit_ids = commented_commits(pr, pr[:pr_creator_id], months_back)

    github_ids = issue_github_ids.concat(pr_github_ids)
    commit_ids.each do |c|
      gid = commit_belongs_to_which_pr(c)
      if !gid.nil?
        github_ids << gid
      end
    end
    github_ids = github_ids.uniq

    if github_ids.size == 0 and commit_ids.size == 0
      return 0
    end


    # find all the github_ids, commit_ids that the core team members participated
    core_team.each do |uid|
      issue_g_ids = commented_issues(pr, uid, months_back)
      pr_g_ids = commented_pull_requests(pr, uid, months_back)
      c_ids = commented_commits(pr, uid, months_back)
      g_ids = issue_g_ids.concat(pr_g_ids)
      c_ids.each do |c|
        gid = commit_belongs_to_which_pr(c)
        if !gid.nil?
          g_ids << gid
        end
      end

      if (github_ids.to_set & g_ids.to_set).size > 0
        linked_integrators << uid
      end
      if (commit_ids.to_set & c_ids.to_set).size > 0
        linked_integrators << uid
      end
    end


    if core_team.size == 0
      0
    else
      linked_integrators.uniq.size.to_f / core_team.size
    end

  end

end