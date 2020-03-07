module Affiliation

    def get_affiliation_list()
      q = <<-QUERY
        select name
        from reduced_users_company
        group by name
        having count(*)>=30
      QUERY
      db.fetch(q).all.map{|x| x[:name]}
    end

    def pr_affiliation_stats_func(pr)
      
      contrib_affiliation = nil
      contrib_affiliation_type = nil

      inte_affiliation = nil
      inte_affiliation_type = nil

      same_affiliation = nil

      q = <<-QUERY
        select name as affiliation, type
        from reduced_users_company
        where user_id=?
      QUERY
      creator = db.fetch(q, pr[:pr_creator_id]).first
      if !creator.nil?
        affiliation = creator[:affiliation]
        type = creator[:type]
        if self.affiliation_list.include?(affiliation)
          contrib_affiliation = affiliation
          contrib_affiliation_type = type
        end
      end
  
      integrator = db.fetch(q, pr[:closed_reviewer_id]).first
      if !integrator.nil?
        affiliation = integrator[:affiliation]
        type = integrator[:type]
        if self.affiliation_list.include?(affiliation)
          inte_affiliation = affiliation
          inte_affiliation_type = type
        end
      end
  
      if !contrib_affiliation.nil? and !inte_affiliation.nil?
        if contrib_affiliation == inte_affiliation
          same_affiliation = true
        else
          same_affiliation = false
        end
      end
  
      return {
        :contrib_affiliation => contrib_affiliation,
        :contrib_affiliation_type => contrib_affiliation_type,
        :inte_affiliation => inte_affiliation,
        :inte_affiliation_type => inte_affiliation_type,
        :same_affiliation => same_affiliation
      }
    end
  
  end