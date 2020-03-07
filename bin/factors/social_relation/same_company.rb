module SameCompany

  def same_company(pr)
    # whether creator and reviewer belongs to the same company
    q = <<-QUERY
    select name 
    from reduced_users_company
    where name is not null
      and type = 'company'
      and user_id = ?
    QUERY
    result_creator = db.fetch(q, pr[:pr_creator_id]).first
    if result_creator.nil?
      nil
    else
      result_reviewer = db.fetch(q, pr[:closed_reviewer_id]).first
      if result_reviewer.nil?
        nil
      else
        if result_creator == result_reviewer
          true
        else
          false
        end
      end
    end
  end

end