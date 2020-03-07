module OpenPrNum
  def open_pr_num(pr, pr_before)
    (pr_before.to_set - pr_before_closed(pr).to_set).size
  end

end