module Gousios

  def perc_external_contribs_func_new(pr, months_back=nil)
    # The ratio of commits from external members over core team members in the last 3 months prior to creation
    core_members = core_team(pr)
    # find author_ids of project_commits in the last months_back months
    q = <<-QUERY
      select rc.author_id
      from reduced_project_commits rpc, reduced_commits rc
      where rpc.commit_id=rc.id
        and rpc.project_id=?
        and rc.created_at<?
    QUERY
    if !months_back.nil?
      oldest = Time.at(Time.at(pr[:created_at]).to_i - 3600 * 24 * 30 * months_back)
      q += " and created_at >= ?"
      author_ids = db[q, pr[:project_id], pr[:created_at], oldest].map{|x| x[:author_id]}
    else
      author_ids = db[q, pr[:project_id], pr[:created_at]].map{|x| x[:author_id]}
    end
    all_commit_num = author_ids.size
    external_commit_num = 0
    author_ids.each do |author_id|
      if !core_members.include?(author_id)
        external_commit_num += 1
      end
    end
    if all_commit_num == 0
      nil
    else
      external_commit_num.to_f / all_commit_num
    end
  end



  def commits_last_x_months(pr, exclude_pull_req, months_back)
    oldest = Time.at(Time.at(pr[:created_at]).to_i - 3600 * 24 * 30 * months_back)

    if exclude_pull_req == false
      # project commits
      q = <<-QUERY
      select c.id as commit_id
      from reduced_commits c, reduced_project_commits pc
      where pc.project_id = ?
        and pc.commit_id = c.id
        and c.created_at < ?
        and c.created_at > ?
      QUERY
      db.fetch(q, pr[:project_id], pr[:created_at], oldest).all.map{|x| x[:commit_id]}
    else
      # pull request related commits
      q = <<-QUERY
      select c.id as commit_id
      from reduced_commits c, reduced_pull_request_commits prc
      where prc.pull_request_id = ?
        and prc.commit_id = c.id
        and c.created_at < ?
        and c.created_at > ?
      QUERY
      db.fetch(q, pr[:id], pr[:created_at], oldest).all.map{|x| x[:commit_id]}
    end
  end


end