module Semaphore

  def semaphore
    @semaphore ||= Mutex.new
    @semaphore
  end

end