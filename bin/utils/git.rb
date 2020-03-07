module Git

  # Clone or update, if already cloned, a git repository
  def clone(user, repo, update = false)
    
    def spawn(cmd)
      proc = IO.popen(cmd, 'r')

      proc_out = Thread.new {
        while !proc.eof
          log "GIT: #{proc.gets}"
        end
      }
      git
      proc_out.join
    end

    checkout_dir = File.join('repos', user, repo)

    begin
      repo = Rugged::Repository.new(checkout_dir)
      if update
        spawn("cd #{checkout_dir} && git pull")
      end
      repo
    rescue Rugged::OSError => e
      cmd = "git clone git://github.com/#{user}/#{repo}.git #{checkout_dir}"
      log cmd
      pid = Process.spawn(cmd)
      Process.wait(pid)
      log "finish cloning repository #{user}/#{repo}"
      repo = Rugged::Repository.new(checkout_dir)
      repo
    end
  end

  # get the recently downloaded repository
  def git
    # log "Thread.current[:repo] nil? " + Thread.current[:repo].nil?.to_s
    Thread.current[:repo] ||= clone(ARGV[0], ARGV[1])
    Thread.current[:repo]
  end

  def git_params(owner, repo)
    # log "Thread.current[:repo] nil? " + Thread.current[:repo].nil?.to_s
    Thread.current[:repo] ||= clone(owner, repo)
    Thread.current[:repo]
  end


  def git_sonar(owner, repo)
    if Thread.current[:repo].nil?
      checkout_dir = File.join('../Python/repos', owner, repo)
      db = Rugged::Repository.new(checkout_dir)
      Thread.current[:repo] = db
    end
    Thread.current[:repo]
  end

end