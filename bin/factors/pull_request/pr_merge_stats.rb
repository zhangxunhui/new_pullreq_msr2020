module PrMergeStats
    
    def pr_merge_stats_func(pr)
        # find the first merge_time, user, id
        # find the last merge_time, user, id
        
        first_merge_time = nil
        first_user_login = nil
        first_user_id = nil
        
        last_merge_time = nil
        last_user_login = nil
        last_user_id = nil

        merge_num = 0

        q = <<-QUERY
            select rprh.created_at as merge_time, ru.login as username, ru.id as user_id
            from reduced_pull_request_history rprh, reduced_users ru
            where rprh.actor_id=ru.id
              and rprh.action='merged'
              and rprh.pull_request_id=?
            order by rprh.created_at asc
        QUERY

        result = db.fetch(q, pr[:id]).all
        
        merge_num = result.size
        if result.size > 0
            first_merge = result[0]
            first_merge_time = first_merge[:merge_time]
            first_user_login = first_merge[:username]
            first_user_id = first_merge[:user_id]

            last_merge = result[-1]
            last_merge_time = last_merge[:merge_time]
            last_user_login = last_merge[:username]
            last_user_id = last_merge[:user_id]
        end
        return {
            :merge_num => merge_num,
            :first_merge_time => first_merge_time,
            :first_user_login => first_user_login,
            :first_user_id => first_user_id,
            :last_merge_time => last_merge_time,
            :last_user_login => last_user_login,
            :last_user_id => last_user_id
        }
    end
end