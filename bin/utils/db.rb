module DB

  require 'uri'

  def db
    # log "Thread.current[:sql_db] nil? " + Thread.current[:sql_db].nil?.to_s
    Thread.current[:sql_db] ||= Proc.new do
      Sequel.single_threaded = true
      #connect_url = "mysql2://#{ENV["MYSQL_USERNAME"]}:#{ENV["MYSQL_PASSWORD"]}@#{ENV["MYSQL_HOST"]}/#{ENV["MYSQL_DATABASE"]}"
      Sequel.connect(self.config['sql']['url'], :encoding => 'utf8', :sql_mode => 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION') # add the sql_mode to avoid mysql version problem (group by)
      #Sequel.connect(connect_url, :encoding => 'utf8', :sql_mode => 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION') # add the sql_mode to avoid mysql version problem (group by)
    end.call
    Thread.current[:sql_db]
  end

  def mongo
    Thread.current[:mongo_db] ||= Proc.new do
      uname  = self.config['mongo']['username']
      passwd = self.config['mongo']['password']
      host   = self.config['mongo']['host']
      port   = self.config['mongo']['port']
      db     = self.config['mongo']['db']

      #uname = ENV["MONGO_USERNAME"]
      #passwd = ENV["MONGO_PASSWORD"]
      #host = ENV["MONGO_HOST"]
      #port = ENV["MONGO_PORT"]
      #db = ENV["MONGO_DATABASE"]

      constring = if uname.nil?
                    "mongodb://#{host}:#{port}/#{db}"
                  else
                    URI.encode("mongodb://#{uname}:#{passwd}@#{host}:#{port}/#{db}")
                  end
      Mongo::Logger.logger.level = Logger::Severity::WARN
      Mongo::Client.new(constring)
    end.call
    Thread.current[:mongo_db]
  end

end