module Commits


  # JSON objects for the commits included in the pull request
  def commit_entries(pr, at_open = false)
    # at and before the opening time of the target pr, what commits are there in the pr
    # some prs have recommits after opening
    if at_open
      q = <<-QUERY
        select rcm.id, rcm.commit_id, rcm._id, rcm.sha, rcm.message, rcm.parents, rcm.stats, rcm.files
        from reduced_pull_requests pr, reduced_pull_request_commits prc, reduced_commits c, reduced_commits_mongo rcm
        where pr.id = prc.pull_request_id
        and prc.commit_id = c.id
        and c.id = rcm.commit_id
        and c.created_at <= ?
        and pr.id = ?
      QUERY
      commits = db.fetch(q, pr[:created_at], pr[:id]).all
    else
      q = <<-QUERY
        select rcm.id, rcm.commit_id, rcm._id, rcm.sha, rcm.message, rcm.parents, rcm.stats, rcm.files
        from reduced_pull_requests pr, reduced_pull_request_commits prc, reduced_commits_mongo as rcm
        where pr.id = prc.pull_request_id
        and prc.commit_id = rcm.commit_id
        and pr.id = ?
      QUERY
      commits = db.fetch(q, pr[:id]).all
    end
    commits.select do |c|
      c.key?(:parents) && !c[:parents].nil? && JSON.parse(c[:parents]).size <= 1
    end # ignore those merge commits # ignore those merge commits
  end


  # Load a commit from Github. Will return an empty hash if the commit does not exist.
  def github_commit(owner, repo, sha)
    parent_dir = File.join('commits', "#{owner}@#{repo}")
    commit_json = File.join(parent_dir, "#{sha}.json")
    FileUtils::mkdir_p(parent_dir)

    r = nil
    if File.exists? commit_json
      r = begin
        JSON.parse File.open(commit_json).read
      rescue
        # This means that the retrieval operation resulted in no commit being retrieved
        {}
      end
      return r
    end

    url = "https://api.github.com/repos/#{owner}/#{repo}/commits/#{sha}"
    log("Requesting #{url} (#{@remaining} remaining)")

    contents = nil
    begin
      r = open(url, 'User-Agent' => 'ghtorrent', 'Authorization' => "token #{token}")
      @remaining = r.meta['x-ratelimit-remaining'].to_i
      @reset = r.meta['x-ratelimit-reset'].to_i
      contents = r.read
      JSON.parse contents
    rescue OpenURI::HTTPError => e
      @remaining = e.io.meta['x-ratelimit-remaining'].to_i
      @reset = e.io.meta['x-ratelimit-reset'].to_i
      log "Cannot get #{url}. Error #{e.io.status[0].to_i}"
      {}
    rescue StandardError => e
      log "Cannot get #{url}. General error: #{e.message}"
      {}
    ensure
      File.open(commit_json, 'w') do |f|
        f.write contents unless r.nil?
        f.write '' if r.nil?
      end

      if 5000 - @remaining >= REQ_LIMIT
        to_sleep = @reset - Time.now.to_i + 2
        log "Request limit reached, sleeping for #{to_sleep} secs"
        sleep(to_sleep)
      end
    end
  end


  # Return a hash of file names and commits on those files in the
  # period between pull request open and months_back. The returned
  # results do not include the commits coming from the PR.
  def commits_on_pr_files(pr, months_back)

    oldest = Time.at(Time.at(pr[:created_at]).to_i - 3600 * 24 * 30 * months_back)
    commits = commit_entries(pr, at_open = true)

    commits_per_file = commits.flat_map { |c|
      unless c[:files].nil?
        JSON.parse(c[:files]).map { |f|
          [c[:sha], f["filename"]]
        }
      else
        []
      end
    }.select{|x| x.size > 1}.group_by {|c|
      c[1]
    }

    commits_per_file.keys.reduce({}) do |acc, filename|
      commits_in_pr = commits_per_file[filename].map{|x| x[0]} # get the shas of pr related commits

      walker = Rugged::Walker.new(git)
      walker.sorting(Rugged::SORT_DATE)
      walker.push(pr[:base_commit])

      commit_list = walker.select do |c|
        c.time > oldest
      end.reduce([]) do |acc1, c|
        if c.diff(paths: [filename.to_s]).size > 0 and
            not commits_in_pr.include? c.oid # (oid is the object id - c.oid gets the commit sha). this commit is not part of pr's commits
          acc1 << c.oid
        end
        acc1
      end
      acc.merge({filename => commit_list})
    end
  end

  # List of files in a project checkout. Filter is an optional binary function
  # that takes a file entry and decides whether to include it in the result.
  def files_at_commit(pr, filter = lambda { |x| true })
    sha = pr[:base_commit]
    begin
      files = lslr(git.lookup(sha).tree)
    rescue StandardError => e
      log pr[:id]
      log "Cannot find commit #{sha} in base repo" # some are in the other branches
      return nil # not to the default branch
    end

    # # find the eariler than and closest to the creation time of commit
    # sha = commit_closest_earlier_pr(pr)
    # begin
    #   files = sha.nil? ? [] : lslr(git.lookup(sha).tree)
    # rescue StandardError => e
    #   log "Cannot find commit #{sha} in base repo" # some are in the other branches
    #   files = [] # no files found before the pr
    # end


    if files.size <= 0
      log "No files for commit #{sha}"
    end
    files.select { |x| filter.call(x) }

  end


  # find the eariler than and closest to the creation time of commit
  # accepted by the base repo
  # if there is no commit before the pr, just return nil
  def commit_closest_earlier_pr(pr)
    walker = Rugged::Walker.new(git)
    walker.sorting(Rugged::SORT_DATE)
    walker.push(git.head.target)
    result = walker.reduce([]) do |acc, commit|
      if commit.time < pr[:created_at]
        acc << commit.oid
      else
        acc
      end
    end
    result.size > 0 ? result[0] : nil
  end

  # whether a commit belongs to a pull request
  def commit_belongs_to_which_pr(commit_id)
    q = <<-QUERY
      select prc.pull_request_id
      from reduced_pull_request_commits prc
      where prc.commit_id = ?
    QUERY
    result = db.fetch(q, commit_id).first
    if result.nil?
      nil
    else
      result[:pull_request_id]
    end
  end


end