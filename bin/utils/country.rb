module Country


    def pr_country_stats_func(pr)
      
      contrib_country = nil

      inte_country = nil

      same_country = nil

      q = <<-QUERY
        select country
        from reduced_users_country
        where user_id=?
      QUERY
      creator = db.fetch(q, pr[:pr_creator_id]).first
      if !creator.nil?
        country = creator[:country]
        if !country.nil?
          contrib_country = country
        end
      end
  
      integrator = db.fetch(q, pr[:closed_reviewer_id]).first
      if !integrator.nil?
        country = integrator[:country]
        if !country.nil?
          inte_country = country
        end
      end
  
      if !contrib_country.nil? and !inte_country.nil?
        if contrib_country == inte_country
          same_country = true
        else
          same_country = false
        end
      end
  
      return {
        :contrib_country => contrib_country,
        :inte_country => inte_country,
        :same_country => same_country
      }
    end
  
  end