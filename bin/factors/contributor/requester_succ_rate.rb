module RequesterSuccRate

  # in-project success rate
  def requester_succ_rate_in_project(pr)
    if prev_pull_requests(pr, 'opened') > 0 then
      prev_pull_requests(pr, 'merged').to_f / prev_pull_requests(pr, 'opened').to_f
    else
      0
    end
  end

  # overall success rate
  def requester_succ_rate(pr)
    if prev_pull_requests(pr, 'opened', false) > 0 then
      prev_pull_requests(pr, 'merged', false).to_f / prev_pull_requests(pr, 'opened', false).to_f
    else
      0
    end
  end

end