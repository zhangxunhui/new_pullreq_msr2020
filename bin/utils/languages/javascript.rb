#
# (c) 2012 -- onwards Georgios Gousios <gousiosg@gmail.com>
#
module JavascriptData

  def src_file_filter
    lambda do |f|
      path = if f.class == Hash then f[:path] else f end
      path.end_with?('.js') and
            path.match('min.js').nil? and
            not test_file_filter.call(f)
    end
  end

  def test_file_filter
    # https://docs.silverstripe.org/en/4/contributing/javascript_coding_conventions/
    # https://medium.com/@me_37286/yoni-goldberg-javascript-nodejs-testing-best-practices-2b98924c9347
    # https://stackoverflow.com/questions/32228055/javascript-unit-testing-best-practices
    lambda do |f|
      path = if f.class == Hash then f[:path] else f end
      path.end_with?('.js') and
          (
            path.include?('spec/') or
            path.include?('test/') or
            path.include?('tests/') or
            path.include?('testing/') or
            path.include?('__tests__') or
            not path.match(/.+\.spec\.js/i).nil? or
            not path.match(/.+\.test\.js/i).nil? or
            not path.match(/.+-test/i).nil? or
            not path.match(/.+_test/i).nil?)
    end
  end

  def assertion_filter
    # https://javascript.ruanyifeng.com/tool/testing.html
    lambda { |l|
      (not l.match(/assert\./).nil? or            #chai, node.js # https://www.chaijs.com/api/assert/ # https://nodejs.org/api/assert.html#assert_assert
          not l.match(/\.?[e|E]xpect\s*\(/).nil? or  # Jasmine # https://jasmine.github.io/tutorials/your_first_suite
          not l.match(/\.?[s|S]hould\./).nil?)  # Mocha
          #not l.match(/([e|E]qual\s*\(|ok\s*\()/).nil?) #qunit qunit is also assert # https://sapui5.hana.ondemand.com/1.30.10/docs/guide/e1ce1de315994a02bf162f4b3b5a9f09.html
    }
  end

  def test_case_filter
    # https://howtodoinjava.com/javascript/jasmine-unit-testing-tutorial/
    # https://alisdair.mcdiarmid.org/simple-nodejs-tests-with-assert-and-mocha/
    lambda { |l|
      not l.match(/it\s*\(.*,/).nil?               # Jasmine, Mocha, chai
      #not l.match(/".*"\s*:\s*function\(/).nil?      # d3.js and friends
    }
  end

  def strip_comments(buff)
    strip_c_style_comments(buff)
  end

end
