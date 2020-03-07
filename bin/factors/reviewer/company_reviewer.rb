module CompanyReviewer
  def company_reviewer(pr)
    # which company does the reviewer belongs to
    q = <<-QUERY
    select name 
    from reduced_users_company
    where name is not null
      and type = 'company'
      and user_id = ?
    QUERY
    result = db.fetch(q, pr[:closed_reviewer_id]).first
    if result.nil?
      nil
    else
      result[:name]
    end
  end
end