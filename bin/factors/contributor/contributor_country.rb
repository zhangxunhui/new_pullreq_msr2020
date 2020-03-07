module ContributorCountry

  def contributor_country(pr)
    # which country does the contributor come from
    q = <<-QUERY
      select country
      from country_countryNameManager
      where user_id = ?
    QUERY
    db.fetch(q, pr[:pr_creator_id]).first[:country]
  end

end