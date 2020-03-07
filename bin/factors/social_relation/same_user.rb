module SameUser
  def same_user(pr)
    # whether the contributor and reviewer are the same user
    contributor = pr[:pr_creator_id]
    reviewer = pr[:closed_reviewer_id]
    if contributor == reviewer
      true
    else
      false
    end
  end
end