module CommitsOnFilesTouched

  # Number of unique commits on the files changed by the pull request
  # between the time the PR was created and `months_back`
  # excluding those created by the PR
  def commits_on_files_touched(pr, months_back)
    commits_on_pr_files(pr, months_back).reduce([]) do |acc, commit_list|
      acc + commit_list[1]
    end.flatten.uniq.size
  end

end