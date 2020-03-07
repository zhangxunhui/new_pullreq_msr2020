module Personality

  def pr_personality_stats_func(pr)
    
    contrib_openness = nil
    contrib_conscientious = nil
    contrib_extraversion = nil
    contrib_agreeableness = nil
    contrib_neuroticism = nil

    inte_openness = nil
    inte_conscientious = nil
    inte_extraversion = nil
    inte_agreeableness = nil
    inte_neuroticism = nil

    open_diff = nil
    cons_diff = nil
    extra_diff = nil
    agree_diff = nil
    neur_diff = nil

    q = <<-QUERY
      select pi_openness_raw as open, pi_conscientiousness_raw as cons, pi_extraversion_raw as extra, pi_agreeableness_raw as agree, pi_neuroticism_raw as neur
      from reduced_users_personality
      where id=?
    QUERY
    creator = db.fetch(q, pr[:pr_creator_id]).first
    if !creator.nil?
      contrib_openness = creator[:open].to_f
      contrib_conscientious = creator[:cons].to_f
      contrib_extraversion = creator[:extra].to_f
      contrib_agreeableness = creator[:agree].to_f
      contrib_neuroticism = creator[:neur].to_f
    end

    integrator = db.fetch(q, pr[:closed_reviewer_id]).first
    if !integrator.nil?
      inte_openness = integrator[:open].to_f
      inte_conscientious = integrator[:cons].to_f
      inte_extraversion = integrator[:extra].to_f
      inte_agreeableness = integrator[:agree].to_f
      inte_neuroticism = integrator[:neur].to_f
    end

    if !contrib_openness.nil? and !inte_openness.nil?
      open_diff = (contrib_openness - inte_openness).abs.to_f
    end

    if !contrib_conscientious.nil? and !inte_conscientious.nil?
      cons_diff = (contrib_conscientious - inte_conscientious).abs.to_f
    end
    
    if !contrib_extraversion.nil? and !inte_extraversion.nil?
      extra_diff = (contrib_extraversion - inte_extraversion).abs.to_f
    end

    if !contrib_agreeableness.nil? and !inte_agreeableness.nil?
      agree_diff = (contrib_agreeableness - inte_agreeableness).abs.to_f
    end

    if !contrib_neuroticism.nil? and !inte_neuroticism.nil?
      neur_diff = (contrib_neuroticism - inte_neuroticism).abs.to_f
    end

    return {
      :contrib_open => contrib_openness,
      :contrib_cons => contrib_conscientious,
      :contrib_extra => contrib_extraversion,
      :contrib_agree => contrib_agreeableness,
      :contrib_neur => contrib_neuroticism,

      :inte_open => inte_openness,
      :inte_cons => inte_conscientious,
      :inte_extra => inte_extraversion,
      :inte_agree => inte_agreeableness,
      :inte_neur => inte_neuroticism,

      :open_diff => open_diff,
      :cons_diff => cons_diff,
      :extra_diff => extra_diff,
      :agree_diff => agree_diff,
      :neur_diff => neur_diff
    }
  end

end