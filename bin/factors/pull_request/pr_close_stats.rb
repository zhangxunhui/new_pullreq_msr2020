module PrCloseStats
    
    def pr_close_stats_func(pr)
        # find the first close_time, user, id
        # find the last close_time, user, id
        
        first_close_time = nil
        first_user_login = nil
        first_user_id = nil
        
        last_close_time = nil
        last_user_login = nil
        last_user_id = nil

        close_num = 0

        q = <<-QUERY
            select rprh.created_at as close_time, ru.login as username, ru.id as user_id
            from reduced_pull_request_history rprh, reduced_users ru
            where rprh.actor_id=ru.id
              and rprh.action='closed'
              and rprh.pull_request_id=?
            order by rprh.created_at asc
        QUERY

        result = db.fetch(q, pr[:id]).all
        
        close_num = result.size
        if result.size > 0
            first_close = result[0]
            first_close_time = first_close[:close_time]
            first_user_login = first_close[:username]
            first_user_id = first_close[:user_id]

            last_close = result[-1]
            last_close_time = last_close[:close_time]
            last_user_login = last_close[:username]
            last_user_id = last_close[:user_id]
        end
        return {
            :close_num => close_num,
            :first_close_time => first_close_time,
            :first_user_login => first_user_login,
            :first_user_id => first_user_id,
            :last_close_time => last_close_time,
            :last_user_login => last_user_login,
            :last_user_id => last_user_id
        }
    end
end