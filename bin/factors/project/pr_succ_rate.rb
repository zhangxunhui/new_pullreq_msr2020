module PrSuccRate

  def pr_succ_rate(pr, pr_before)
    # pr_before = pr_before(pr)
    pr_before_merged = pr_before_merged(pr)
    if pr_before.size > 0
      pr_before_merged.size.to_f / pr_before.size.to_f
    else
      nil # actually the beginning cannot be taken into consideration
    end
  end

end