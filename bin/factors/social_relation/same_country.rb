module SameCountry

  def same_country(pr)
    # whether the contributor and integrator are from the same country
    q = <<-QUERY
      select country
      from country_countryNameManager
      where user_id = ?
    QUERY
    contributor_country = db.fetch(q, pr[:pr_creator_id]).first
    contributor_country = contributor_country.nil? ? nil : contributor_country[:country]

    q = <<-QUERY
      select country
      from country_countryNameManager
      where user_id = ?
    QUERY
    integrator_country = db.fetch(q, pr[:closed_reviewer_id]).first
    integrator_country = integrator_country.nil? ? nil : integrator_country[:country]

    if !contributor_country.nil? and
        !integrator_country.nil? and
        contributor_country == integrator_country
      true
    elsif !contributor_country.nil? and
        !integrator_country.nil? and
        contributor_country != integrator_country
      false
    else
      nil
    end
  end

end