module LoggerUtil
  require 'logger'

  def log(msg, level = 0)
    semaphore.synchronize do
      #(0..level).each { STDERR.write ' ' }
      if level == 1
        STDOUT.print "\n"
        STDOUT.print msg
      else
        STDERR.puts msg
      end
    end
  end

end