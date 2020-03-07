module Lines

  # count the number of lines for the assigned files
  def count_lines(files, include_filter = lambda{|x| true})
    if files.nil?
      # this doesn't mean no files, but not the related branch
      return nil
    end
    begin
      a = files.map do |f|
        # sometimes the file oid cannot be found by rugged::repository,
        # then there will be an exception
        stripped(f).lines.select do |x|
          not x.strip.empty?
        end.select do |x|
          include_filter.call(x)
        end.size
      end
      a.reduce(0){|acc,x| acc + x}
    rescue => exception
      return nil
    end
  end

  # count the number of lines of source files that the commit related to
  def src_lines(pr)
    count_lines(src_files(pr))
  end


  # count the number of lines of test files that the commit related to
  def test_lines(pr)
    count_lines(test_files(pr))
  end

  def num_test_cases(pr)
    count_lines(test_files(pr), test_case_filter)
  end

  def num_assertions(pr)
    count_lines(test_files(pr), assertion_filter)
  end

  def num_test_cases_and_assertions(pr)
    tf = test_files(pr)
    test_cases = count_lines(tf, test_case_filter)
    assertions = count_lines(tf, assertion_filter)
    return test_cases, assertions
  end

end