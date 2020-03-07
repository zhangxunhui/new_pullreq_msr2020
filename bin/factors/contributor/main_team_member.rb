module MainTeamMember

  # whether the pr contributor is the core member or not
  # default: do not take months_back into consideration
  def main_team_member?(pr, months_back = nil)
    core_team(pr, months_back).uniq.include? pr[:pr_creator_id]
  end

end