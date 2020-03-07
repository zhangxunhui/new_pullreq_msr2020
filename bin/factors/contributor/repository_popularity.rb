module RepositoryPopularity

  # at the time of pr creation
  # the most popular 6 projects
  # get the sum of star number
  def repository_popularity(pr)
    q = <<-QUERY
      select id
      from reduced_projects
      where created_at <= ?
        and owner_id = ?
    QUERY
    projs = db.fetch(q, pr[:created_at], pr[:pr_creator_id]).all.map{|x| x[:id]}
    stars = []
    projs.each do |p|
      q = <<-QUERY
      select count(*) as star_num
      from reduced_watchers w
      where w.created_at <= ?
        and w.repo_id = ?
      QUERY
      star_num = db.fetch(q, pr[:created_at], p).first[:star_num]
      stars << star_num
    end

    # order the star num
    pop_num = stars.size >= 6 ? 6 : stars.size
    if pop_num == 0
      pop_num = 1
    end
    stars.sort.reverse[0,pop_num - 1].inject(0){|sum, x| sum + x}
  end

end