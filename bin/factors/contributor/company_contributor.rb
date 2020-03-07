module CompanyContributor
  def company_contributor(pr)
    # which company does the creator belongs to
    q = <<-QUERY
      select name 
      from reduced_users_company
      where name is not null
        and type = 'company'
        and user_id = ?
    QUERY
    result = db.fetch(q, pr[:pr_creator_id]).first
    if result.nil?
      nil
      else
      result[:name]
    end
  end
end