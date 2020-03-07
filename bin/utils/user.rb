module User

  def get_user_id(login)
    q = <<-QUERY
      select id
      from reduced_users
      where login = ?
    QUERY
    db.fetch(q, login).first[:id]
  end

end