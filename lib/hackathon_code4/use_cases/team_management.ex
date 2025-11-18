defmodule HackathonCode4.UseCases.TeamManagement do
  alias HackathonCode4.Domain.{Team, Participant}
  alias HackathonCode4.Adapters.FileRepository

  def create_team(name, theme) do
    id = generate_id()
    team = Team.new(id, name, theme)
    FileRepository.save(team, :teams)
  end

  def list_teams do
    FileRepository.find_all(:teams)
  end

  def get_team(team_id) do
    FileRepository.find_by_id(team_id, :teams)
  end

  def join_team(participant_id, team_id) do
    with {:ok, team} <- FileRepository.find_by_id(team_id, :teams),
         {:ok, participant} <- FileRepository.find_by_id(participant_id, :participants),
         {:ok, updated_team} <- Team.add_member(team, participant_id),
         updated_participant = Participant.assign_team(participant, team_id),
         {:ok, _} <- FileRepository.save(updated_team, :teams),
         {:ok, _} <- FileRepository.save(updated_participant, :participants) do
      {:ok, updated_team}
    end
  end

  def register_participant(name, email) do
    id = generate_id()
    participant = Participant.new(id, name, email)
    FileRepository.save(participant, :participants)
  end

  def list_participants do
    FileRepository.find_all(:participants)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
