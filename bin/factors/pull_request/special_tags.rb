module SpecialTags

  # Num of @uname mentions in the description(title doesn't take effect)
  # Modelling the results of: An Exploratory Study of @-mention in GitHub's Pull-requests
  # DOI: 10.1109/APSEC.2014.58
  def at_mentions_description(pr)
    pull_req = pull_req_entry(pr)
    unless pull_req[:body].nil?
      pull_req[:body].\
        gsub(/`.*?`/, '').\
        gsub(/[\w]*@[\w]+\.[\w]+/, '').\
        scan(/@(?!\-)([a-zA-Z0-9\-]+)(?<!\-)/).select{|x| x[0].scan(/\-(?=\-)/).size == 0}.size # -- is not allowed
=begin
        username may only contain alphanumeric characters or single hyphens, and cannot begin or end with a hyphen
=end
    else
      0
    end
  end


  # Num of @uname mentions in comments
  # actually for different kinds of comments (pr_comments, commit_comments, issue_comments), this mechanism works
  def at_mentions_comments(pr)
    ccs = commit_comments(pr)
    prcs = pr_comments(pr)
    ics = issue_comments(pr)
    (ccs + prcs + ics).map do |ic|
      # Remove stuff between backticks (they may be code)
      # e.g. see comments in https://github.com/ReactiveX/RxScala/pull/166
      unless ic[:body].nil? # for Hash only [:body] is allowed; for Bson object, both [:body] and ["body"] are ok
        ic[:body].\
            gsub(/`.*?`/, '').\
            gsub(/[\w]*@[\w]+\.[\w]+/, '')
      else
        0
      end
    end.map do |ic|
      ic.scan(/@(?!\-)([a-zA-Z0-9\-]+)(?<!\-)/).select{|x| x[0].scan(/\-(?=\-)/).size == 0}.size
    end.reduce(0) do |acc, x|
      acc + x
    end
  end

  # Num of #link mentions in descriptions
  def hash_tag_description(pr)
    pull_req = pull_req_entry(pr)
    unless pull_req[:body].nil?
      pull_req[:body].\
        gsub(/`.*?`/, '').\
        scan(/#([0-9]+)/).size
    else
      0
    end
  end


  # Num of #link mentions in comments
  def hash_tag_comments(pr)
    ccs = commit_comments(pr)
    prcs = pr_comments(pr)
    ics = issue_comments(pr)
    (ccs + prcs + ics).reduce(0) do |acc, ic|
      unless ic[:body].nil?
        acc + ic[:body].gsub(/`.*?`/, '').\
                  scan(/#([0-9]+)/).size
      else
        acc
      end
    end
  end


  # Num of #link mentions to other pull requests in description
  def hash_tag_description_pr(pr)
    pull_req = pull_req_entry(pr)
    unless pull_req[:body].nil?
      pull_req[:body].\
        gsub(/`.*?`/, '').\
        scan(/#([0-9]+)/).select do |x|
        pull_request?(pr, x[0].to_i)
      end.size
    else
      0
    end
  end


  # Num of #link mentions to other pull requests in comments
  def hash_tag_comments_pr(pr)
    ccs = commit_comments(pr)
    prcs = pr_comments(pr)
    ics = issue_comments(pr)
    (ccs + prcs + ics).reduce(0) do |acc, ic|
      unless ic[:body].nil?
        acc + ic[:body].gsub(/`.*?`/, '').\
                  scan(/#([0-9]+)/).\
                  select do |x|
          pull_request?(pr, x[0].to_i)
        end.size
      else
        acc
      end
    end
  end

  # Num of #link mentions to other issues in description
  def hash_tag_description_issue(pr)
    pull_req = pull_req_entry(pr)
    unless pull_req[:body].nil?
      pull_req[:body].\
        gsub(/`.*?`/, '').\
        scan(/#([0-9]+)/).select do |x|
        !pull_request?(pr, x[0].to_i)
      end.size
    else
      0
    end
  end


  # Num of #link mentions to other issues in comments
  def hash_tag_comments_issue(pr)
    ccs = commit_comments(pr)
    prcs = pr_comments(pr)
    ics = issue_comments(pr)
    (ccs + prcs + ics).reduce(0) do |acc, ic|
      unless ic[:body].nil?
        acc + ic[:body].gsub(/`.*?`/, '').\
                  scan(/#([0-9]+)/).\
                  select do |x|
          !pull_request?(pr, x[0].to_i)
        end.size
      else
        acc
      end
    end
  end

end