module PrStats

  # Various statistics for the pull request. Returned as Hash with the following
  # keys: :lines_added, :lines_deleted, :files_added, :files_removed,
  # :files_modified, :files_touched, :src_files, :doc_files, :other_files,
  # :code_chunk_num, :commit_num
  # :test_inclusion_num.
  def pr_stats(pr, at_open = false)
    pr_id = pr[:id]
    raw_commits = commit_entries(pr, at_open)
    result = Hash.new(0)

    def file_count(commits, status)
      commits.map do |c|
        unless c[:files].nil?
          JSON.parse(c[:files]).reduce(Array.new) do |acc, y|
            if y["status"] == status then acc << y["filename"] else acc end
          end
        else
          []
        end
      end.flatten.uniq.size
    end

    def files_touched(commits)
      commits.map do |c|
        unless c[:files].nil?
          JSON.parse(c[:files]).map do |y|
            y["filename"]
          end
        else
          []
        end
      end.flatten.uniq.size
    end

    def file_type(f)
      lang = Linguist::Language.find_by_filename(f)
      if lang.empty? then
        lang = Linguist::Language.find_by_extension(f) # add this function to ensure the correctness
        if lang.empty? then
          :data
        else
          lang[0].type
        end
      else
        lang[0].type
      end
    end

    def file_type_count(commits, type)
      commits.map do |c|
        unless c[:files].nil?
          JSON.parse(c[:files]).reduce(Array.new) do |acc, y|
            if file_type(y["filename"]) == type then acc << y["filename"] else acc end
          end
        else
          []
        end
      end.flatten.uniq.size
    end

    def lines(commit, type, action)
      return 0 if commit[:files].nil?
      JSON.parse(commit[:files]).select do |x|
        next unless file_type(x["filename"]) == :programming

        case type
        when :test
          true if test_file_filter.call(x["filename"])
        when :src
          true unless test_file_filter.call(x["filename"])
        else
          false
        end
      end.reduce(0) do |acc, y|
        # diff_start = case action
        #              when :added
        #                "+"
        #              when :deleted
        #                "-"
        #              end
        #
        # acc += unless y['patch'].nil?
        #          y['patch'].lines.select{|x| x.start_with?(diff_start)}.size
        #        else
        #          0
        #        end

        # change the above patch analysis to another way
        case action
        when :added
          acc += y["additions"]
        when :deleted
          acc += y["deletions"]
        end
        acc
      end
    end

    def chunks(commit)
      return 0 if commit[:files].nil?
      JSON.parse(commit[:files]).reduce(0) do |acc, y|
        acc += unless y["patch"].nil?
                 y["patch"].lines.select{|x| x.start_with?('@@')}.size
               else
                 0
               end
      end
    end

    # whether the commit add a test case
    def cases(commit, filter)
      if commit[:files].nil?
        return 0
      end
      JSON.parse(commit[:files]).reduce(0) do |acc, y|
        action_block = nil
        unless y["patch"].nil?
          acc_ele = 0
          y["patch"].lines.each do |x|
            if x.start_with?('+')
              action_block = :added
            elsif x.start_with?('-')
              action_block = :deleted
            end
            if action_block == :added and filter.call(x)
              acc_ele += 1 # find an added test case
            end
          end
          acc += acc_ele
        else
          acc
        end
      end
    end

    raw_commits.each{ |x|
      next if x.nil?
      result[:lines_added] += lines(x, :src, :added)
      result[:lines_deleted] += lines(x, :src, :deleted)
      result[:test_lines_added] += lines(x, :test, :added)
      result[:test_lines_deleted] += lines(x, :test, :deleted)

      # add code_chunk for the pull request
      result[:code_chunk_num] = chunks(x)

      # add test_inclusion_num for the pull request
      result[:test_inclusion_num] += cases(x, test_case_filter)
    }

    result[:files_added] += file_count(raw_commits, "added")
    result[:files_removed] += file_count(raw_commits, "removed")
    result[:files_modified] += file_count(raw_commits, "modified")
    result[:files_touched] += files_touched(raw_commits)

    result[:src_files] += file_type_count(raw_commits, :programming)
    result[:doc_files] += file_type_count(raw_commits, :markup)
    result[:other_files] += file_type_count(raw_commits, :data)

    # add commit_num for the pull request
    result[:commit_num] = raw_commits.size

    result
  end

end