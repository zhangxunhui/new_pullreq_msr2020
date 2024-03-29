#
# (c) 2012 -- onwards Georgios Gousios <gousiosg@gmail.com>
#
module JavaData

  def src_file_filter
    lambda { |f|
      path = if f.class == Hash then f[:path] else f end
      path.end_with?('.java')and not test_file_filter.call(f)
    }
  end

  def test_file_filter
    lambda { |f|
      path = if f.class == Hash then f[:path] else f end
      path.end_with?('.java') and
          (not path.match(/tests?\//).nil? or not path.match(/[tT]est.java/).nil?)
    }
  end

  def test_case_filter
    lambda do |l|
      not l.match(/@Test/).nil? or
          not l.match(/([tT]est[a-zA-Z0-9_]+)\s*\([^\)]*\)\s*\{/).nil?
    end
  end

  def assertion_filter
    lambda{|l| not l.match(/assert/).nil?}
  end

  def strip_comments(buff)
    strip_c_style_comments(buff)
  end

end
