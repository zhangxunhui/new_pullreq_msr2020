module Comments

  # find all the issue comments for a pull request
  # we only need the comments before the close time of this pr
  def issue_comments(pr)
    q = <<-QUERY
      select body, created_at
      from reduced_issue_comments_mongo
      where created_at <= ?
        and owner = ?
        and repo = ?
        and mongo_github_id = ?
      order by created_at asc
    QUERY
    db.fetch(q, pr[:closed], pr[:login], pr[:project_name], pr[:github_id].to_i).all.to_a
  end


  # find all the pr comments for a pull request
  def pr_comments(pr)
    q = <<-QUERY
      select body, created_at
      from reduced_pull_request_comments
      where pull_request_id = ?
        and created_at <= ?
      order by created_at asc
    QUERY
    db.fetch(q, pr[:id], pr[:closed_at]).all
  end


  # find all the commit comments for a pull request
  def commit_comments(pr)
    q = <<-QUERY
      select cc.body, cc.created_at
      from reduced_commit_comments cc, reduced_pull_request_commits prc
      where cc.commit_id = prc.commit_id
        and prc.pull_request_id = ?
        and cc.created_at <= ?
      order by cc.created_at asc
    QUERY
    db.fetch(q, pr[:id], pr[:closed_at]).all
  end


  # strip one line comments
  def strip_shell_style_comments(buff)
    in_comment = false
    out = []
    buff.each_byte do |b|
      case b
      when '#'.getbyte(0)
        in_comment = true
      when "\r".getbyte(0)
      when "\n".getbyte(0)
        in_comment = false
        unless in_comment
          out << b
        end
      else
        unless in_comment
          out << b
        end
      end
    end
    out.pack('c*')
  end


  # strip c type comments
  def strip_c_style_comments(buff)
    in_ml_comment = in_sl_comment = may_start_comment = may_end_comment = false
    out = []
    buff.each_byte do |b|
      case b
      when '/'.getbyte(0)
        if may_start_comment
          unless in_ml_comment
            in_sl_comment = true
          end
        elsif may_end_comment
          in_ml_comment = false
          may_end_comment = false
        else
          may_start_comment = true
        end
      when '*'.getbyte(0)
        if may_start_comment
          in_ml_comment = true
          may_start_comment = false
        else
          may_end_comment = true
        end
      when "\r".getbyte(0)
      when "\n".getbyte(0)
        in_sl_comment = false
        unless in_sl_comment or in_ml_comment
          out << b
        end
      else
        unless in_sl_comment or in_ml_comment
          out << b
        end
        may_end_comment = may_start_comment = false
      end
    end
    out.pack('c*')
  end

  # strip comments for the target file
  def stripped(f)
    @stripped ||= Hash.new
    unless @stripped.has_key? f
      semaphore.synchronize do
        unless @stripped.has_key? f
          @stripped[f] = strip_comments(git.read(f[:oid]).data)
        end
      end
    end
    @stripped[f]
  end


  # issue_comments participated by a user months_back the pr
  # return the github_id
  def commented_issues(pr, user_id, months_back)
    oldest = Time.at(Time.at(pr[:created_at]).to_i - 3600 * 24 * 30 * months_back)
    q = <<-QUERY
      select i.issue_id as github_id
      from reduced_issues i, reduced_issue_comments ic
      where ic.user_id = ?
        and i.repo_id = ?
        and i.id = ic.issue_id
        and ic.created_at > ?
        and ic.created_at < ?
    QUERY
    db.fetch(q, user_id, pr[:project_id], oldest, pr[:created_at]).all.map {|x| x[:github_id]}
  end

  # pull_request_comments participated by a user months_back the pr
  # return the github_id
  def commented_pull_requests(pr, user_id, months_back)
    oldest = Time.at(Time.at(pr[:created_at]).to_i - 3600 * 24 * 30 * months_back)
    q = <<-QUERY
      select pr.pullreq_id as github_id
      from reduced_pull_requests pr, reduced_pull_request_comments prc
      where prc.user_id = ?
        and pr.base_repo_id = ?
        and pr.id = prc.pull_request_id
        and prc.created_at > ?
        and prc.created_at < ?
    QUERY
    db.fetch(q, user_id, pr[:project_id], oldest, pr[:created_at]).all.map {|x| x[:github_id]}
  end

  # commit_comments participated by a user months_back the pr
  # return the commit_id
  def commented_commits(pr, user_id, months_back)
    oldest = Time.at(Time.at(pr[:created_at]).to_i - 3600 * 24 * 30 * months_back)
    q = <<-QUERY
      select pc.commit_id as commit_id
      from reduced_project_commits pc, reduced_commit_comments cc
      where cc.commit_id = pc.commit_id
        and cc.user_id = ?
        and pc.project_id = ?
        and cc.created_at > ?
        and cc.created_at < ?
    QUERY
    db.fetch(q, user_id, pr[:project_id], oldest, pr[:created_at]).all.map {|x| x[:commit_id]}
  end

end