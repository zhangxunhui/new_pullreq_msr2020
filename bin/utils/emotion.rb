module Emotion

  def pr_emotion_stats_func(pr)
    contrib_first_emo = nil
    inte_first_emo = nil

    perc_contrib_neg_emo = nil
    perc_contrib_pos_emo = nil
    perc_contrib_neu_emo = nil

    perc_inte_neg_emo = nil
    perc_inte_pos_emo = nil
    perc_inte_neu_emo = nil

    perc_pr_neg_emo = nil
    perc_pr_pos_emo = nil
    perc_pr_neu_emo = nil

    # tmp
    sum_contrib_neg_emo = 0
    sum_contrib_pos_emo = 0
    sum_contrib_neu_emo = 0
    sum_contrib_all_emo = 0

    sum_inte_neg_emo = 0
    sum_inte_pos_emo = 0
    sum_inte_neu_emo = 0
    sum_inte_all_emo = 0

    sum_pr_neg_emo = 0
    sum_pr_pos_emo = 0
    sum_pr_neu_emo = 0
    sum_pr_all_emo = 0

    all_exists_contrib = true # all the comments emotion of contributor are not nil
    all_exists_inte = true
    all_exists_pr = true

    contrib_first = true # whether this is the first of contrib, false means not
    inte_first = true

    # get all the comments of the pr(order by created_at asc)
    q = <<-QUERY
      select comment_id, commenter_id, created_at, emotion from 
      (select ric.comment_id as comment_id, ric.user_id as commenter_id, ric.created_at as created_at, rce.emotion as emotion
      from reduced_issue_comments ric, reduced_issues ri, reduced_comments_emotion rce
      where ric.issue_id=ri.id
        and rce.comment_id=ric.comment_id
        and ri.pull_request_id=?
        and ric.created_at<?
      union
      select rprc.comment_id as comment_id, rprc.user_id as commenter_id, rprc.created_at as created_at, rce.emotion as emotion
      from reduced_pull_request_comments rprc, reduced_comments_emotion rce
      where rce.comment_id=rprc.comment_id
        and rprc.pull_request_id=?
        and rprc.created_at<?
      union
      select rcc.comment_id as comment_id, rcc.user_id as commenter_id, rcc.created_at as created_at, rce.emotion as emotion
      from reduced_commit_comments rcc, reduced_pull_request_commits rprci, reduced_comments_emotion rce
      where rcc.commit_id=rprci.commit_id
        and rce.comment_id=rcc.comment_id
        and rprci.pull_request_id=?
        and rcc.created_at<?) as tmp
      order by created_at asc
    QUERY
    result = db.fetch(q, pr[:id], pr[:closed_at], pr[:id], pr[:closed_at], pr[:id], pr[:closed_at]).all
    
    # contrib_first_emo
    result.each do |comment|
      emotion = comment[:emotion]
      commenter_id = comment[:commenter_id]

      if commenter_id == pr[:pr_creator_id]
        if contrib_first == true
          contrib_first_emo = emotion
          contrib_first = false
        end

        if emotion.nil?
          all_exists_contrib = false
          all_exists_pr = false
        else
          if emotion == "negative"
            sum_contrib_neg_emo += 1
            sum_pr_neg_emo += 1
          elsif emotion == "positive"
            sum_contrib_pos_emo += 1
            sum_pr_pos_emo += 1
          else # neutral
            sum_contrib_neu_emo += 1
            sum_pr_neu_emo += 1
          end
          sum_contrib_all_emo += 1
          sum_pr_all_emo += 1
        end
      elsif commenter_id == pr[:closed_reviewer_id]
        if inte_first == true
          inte_first_emo = comment[:emotion]
          inte_first = false
        end

        if emotion.nil?
          all_exists_inte = false
          all_exists_pr = false
        else
          if emotion == "negative"
            sum_inte_neg_emo += 1
            sum_pr_neg_emo += 1
          elsif emotion == "positive"
            sum_inte_pos_emo += 1
            sum_pr_pos_emo += 1
          else
            sum_inte_neu_emo += 1
            sum_pr_neu_emo += 1
          end
          sum_inte_all_emo += 1
          sum_pr_all_emo += 1
        end
      else
        # not contributor, not closer
        if emotion.nil?
          all_exists_pr = false
        else
          if emotion == "negative"
            sum_pr_neg_emo += 1
          elsif emotion == "positive"
            sum_pr_pos_emo += 1
          else
            sum_pr_neu_emo += 1
          end
          sum_pr_all_emo += 1
        end
      end

    end

    # perc_contrib
    if all_exists_contrib == true and sum_contrib_all_emo > 0
      perc_contrib_pos_emo = sum_contrib_pos_emo * 1.0 / sum_contrib_all_emo
      perc_contrib_neg_emo = sum_contrib_neg_emo * 1.0 / sum_contrib_all_emo
      perc_contrib_neu_emo = sum_contrib_neu_emo * 1.0 / sum_contrib_all_emo
    elsif sum_contrib_all_emo == 0 # no response
      perc_contrib_pos_emo = 0.0
      perc_contrib_neg_emo = 0.0
      perc_contrib_neu_emo = 0.0
    else
      # lack of emotion of comments, should be nil
    end

    # perc_inte
    if all_exists_inte == true and sum_inte_all_emo > 0
      perc_inte_pos_emo = sum_inte_pos_emo * 1.0 / sum_inte_all_emo
      perc_inte_neg_emo = sum_inte_neg_emo * 1.0 / sum_inte_all_emo
      perc_inte_neu_emo = sum_inte_neu_emo * 1.0 / sum_inte_all_emo
    elsif sum_inte_all_emo == 0 # no response
      perc_inte_pos_emo = 0.0
      perc_inte_neg_emo = 0.0
      perc_inte_neu_emo = 0.0
    else
      # lack of emotion
    end

    # perc_pr
    if all_exists_pr == true and sum_pr_all_emo > 0
      perc_pr_pos_emo = sum_pr_pos_emo * 1.0 / sum_pr_all_emo
      perc_pr_neg_emo = sum_pr_neg_emo * 1.0 / sum_pr_all_emo
      perc_pr_neu_emo = sum_pr_neu_emo * 1.0 / sum_pr_all_emo
    elsif sum_pr_all_emo == 0 # no comment
      perc_pr_pos_emo = 0.0
      perc_pr_neg_emo = 0.0
      perc_pr_neu_emo = 0.0
    end

    return {
      :contrib_first_emo => contrib_first_emo,
      :inte_first_emo => inte_first_emo,

      :perc_contrib_neg_emo => perc_contrib_neg_emo,
      :perc_contrib_pos_emo => perc_contrib_pos_emo,
      :perc_contrib_neu_emo => perc_contrib_neu_emo,

      :perc_inte_neg_emo => perc_inte_neg_emo,
      :perc_inte_pos_emo => perc_inte_pos_emo,
      :perc_inte_neu_emo => perc_inte_neu_emo,

      :perc_pr_neg_emo => perc_pr_neg_emo,
      :perc_pr_pos_emo => perc_pr_pos_emo,
      :perc_pr_neu_emo => perc_pr_neu_emo
    }
  end

end