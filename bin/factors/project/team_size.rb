module TeamSize

  # Number of integrators active during x months prior to pull request
  # creation.
  def team_size(pr, months_back)
    core_team(pr, months_back).uniq.size
  end

end