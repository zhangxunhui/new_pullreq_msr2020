module Files

  # get the related src files for the commit
  def src_files(pr)
    files_at_commit(pr, src_file_filter)
  end

  # get the related test files for the commit
  def test_files(pr)
    files_at_commit(pr, test_file_filter)
  end


  # get the checkout sha related first level files and folders
  def first_level_fs(pr, filter = lambda { |x| true })
    sha = pr[:base_commit]
    begin
      fs = ls_tree(git.lookup(sha).tree)
    rescue StandardError => e
      log "Cannot find commit #{sha} in base repo, head_commit: #{pr[:head_commit]}, ownername: #{ARGV[0]}, reponame: #{ARGV[1]}" # some are in the other branches
      return nil # not to the default branch
    end

    if fs.size <= 0
      log "No files for commit #{sha}"
    end
    fs.select { |x| filter.call(x) }
  end

end