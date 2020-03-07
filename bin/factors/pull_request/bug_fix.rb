module BugFix

  # whether the pr is a bug fix or not
  # 'Where Is the Road for Issue Reports Classification Based on Text Mining?'
  # bug/defect/type:bug - bug
  # enhancement/feature/question/feature request/documentation/improvement/docs - non bug

  BUGLABELS = ["bug", "defect", "type:bug"]
  NONBUGLABELS = ["enhancement", "feature", "question", "feature request", "documentation", "improvement", "docs"]

  def label(pr)
    # find the label of the pr/issue
    q = <<-QUERY
      select rl.name as label
      from reduced_issue_labels il, reduced_issues i, reduced_repo_labels rl
      where i.id = il.issue_id
        and il.label_id = rl.id
        and i.issue_id = ?
        and i.repo_id = ?
    QUERY
    labels = db.fetch(q, pr[:github_id], pr[:project_id]).all.map{|x| x[:label]}
    bug_labels = labels.select do |x|
      BUGLABELS.include?(x)
    end
    if bug_labels.size > 0
      return :bug
    end

    nonbug_labels = labels.select do |x|
      NONBUGLABELS.include?(x)
    end
    if nonbug_labels.size > 0
      return :nonbug
    end

    return :unknown
  end

  def bug_fix?(pr)
    # whether there is a label related to this pr
    pr_label = label(pr)
    if pr_label == :bug
      return true
    elsif pr_label == :nonbug
      return false
    end

    # whether this pr fixes an issue
    q = <<-QUERY
      select c.sha
      from reduced_commits c, reduced_pull_request_commits prc
      where c.id = prc.commit_id
        and prc.pull_request_id = ?
    QUERY
    shas = db.fetch(q, pr[:id]).all.map {|x| x[:sha]}

    close_issue_github_ids = []
    if shas.size > 0
      closed_by_commit.each do |github_id, sha|
        if shas.include?(sha)
          close_issue_github_ids << github_id
        end
      end
      if close_issue_github_ids.size > 0
        close_issue_github_ids.each do |github_id|
          issue_label = label({:github_id => github_id, :project_id => pr[:project_id]})
          if issue_label == :bug
            return true
          elsif issue_label == :nonbug
            return false
          end
        end
        return nil # the closed issue/pr of this pr doesn't have any bug/non-bug labels
      else
        return nil # the pr doesn't close any issue or pr
      end
    else
      return nil # no related commits in the pr
    end

  end

end