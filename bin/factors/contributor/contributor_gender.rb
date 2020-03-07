module ContributorGender

  def contributor_gender(pr)
    q = <<-QUERY
      select gender
      from reduced_users_gender
      where user_id = ?
    QUERY
    genderComputer_result = db.fetch(q, pr[:pr_creator_id]).first
    genderComputer_result = genderComputer_result.nil? ? nil : genderComputer_result[:gender]


    if !genderComputer_result.nil? and genderComputer_result.downcase != 'unisex'
      genderComputer_result.downcase
    else
      nil
    end
  end

end