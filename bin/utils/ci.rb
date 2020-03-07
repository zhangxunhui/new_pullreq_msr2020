module CI

  def ci_2?(pr)
    q = <<-QUERY
      select ci_or_not as ci
      from reduced_pull_request_cis
      where project_id=?
        and github_id=?
    QUERY
    result = db.fetch(q, pr[:project_id], pr[:github_id]).first
    if result.nil?
      nil
    else
      result[:ci] == 0 ? false : true
    end
  end


  def pr_ci_stats_func(pr)

    status_list = ["passed", "failed", "success", "fixed", "failure", "errored", "infrastructure_fail", "error"]

    fail_list = ["failed", "failure", "errored", "error", "infrastructure_fail"]

    ci_build_num = nil
    ci_first_build_status = nil
    ci_last_build_status = nil
    ci_failed_percentage = nil
    ci_failed_num = 0 # tmp
    ci_test_passed = nil # whether passed all ci tests
    ci_build_types = [] # type is to record what kind of ci tools does this pr use

    ci_finish_time_first = nil
    ci_latency = nil

    q = <<-QUERY
      select rcbr.started_at as start, rcbr.finished_at as finish, rcbr.duration as duration, rcbr.status as status, rcbr.ci_tool as type
      from reduced_ci_build_results rcbr
      where rcbr.project_id=?
        and rcbr.github_id=?
      order by finished_at asc
    QUERY
    result = db.fetch(q, pr[:project_id], pr[:github_id]).all
    result.each do |r|
      start = r[:start]
      finish = r[:finish]
      duration = r[:duration]
      status = r[:status]
      type = r[:type]
      if status_list.include?(status)
        
        if !ci_build_types.include?(type)
          ci_build_types << type
        end

        if start.nil? or finish.nil?
          next
        end

        if finish > pr[:closed_at]
          break # we only need ci before close time
        end
        
        if ci_first_build_status.nil?
          ci_first_build_status = status
        end

        ci_last_build_status = status
        if ci_finish_time_first.nil?
          ci_finish_time_first = finish
        end

        if ci_build_num.nil?
          ci_build_num = 1
        else
          ci_build_num += 1
        end
        
        if fail_list.include?(status)
          ci_failed_num += 1
        end
      end
    end
    if !ci_build_num.nil?
      ci_failed_percentage = ci_failed_num.to_f / ci_build_num

      if ci_failed_num == 0
        ci_test_passed = true # passed all the tests
      else
        ci_test_passed = false
      end
    end

    if !ci_finish_time_first.nil?
      ci_latency = ci_finish_time_first - pr[:created_at]
    end

    return {
      :ci_build_num => ci_build_num,
      :ci_first_build_status => ci_first_build_status,
      :ci_last_build_status => ci_last_build_status,
      :ci_failed_percentage => ci_failed_percentage,
      # :ci_avg_build_time => ci_avg_build_time,
      :ci_latency => ci_latency,
      :ci_build_types => ci_build_types,
      :ci_test_passed => ci_test_passed
    }
  end
  
end