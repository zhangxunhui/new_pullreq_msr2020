module PrDescriptionComplexity

  def pr_description_complexity(pr)
    # total number of words in the pull-request title and description
    q = <<-QUERY
      select title, body
      from reduced_pull_requests_mongo
      where pull_request_id = ?
    QUERY
    pullreq = db.fetch(q, pr[:id]).first
    #pullreq = mongo["pull_requests"].find(
    #  {
    #      "repo" => pr[:project_name],
    #      "owner" => pr[:login],
    #      "number" => pr[:github_id].to_i
    #  }
    #).limit(1).first

    # should take English language and other languages into consideration!!!!!!
    if !pullreq[:title].nil? and !pullreq[:body].nil?
      pullreq[:title].split(/[^[:word:]]+/).size + pullreq[:body].split(/[^[:word:]]+/).size
    elsif !pullreq[:title].nil?
      pullreq[:title].split(/[^[:word:]]+/).size
    elsif !pullreq[:body].nil?
      pullreq[:body].split(/[^[:word:]]+/).size
    else
      0
    end
  end

end