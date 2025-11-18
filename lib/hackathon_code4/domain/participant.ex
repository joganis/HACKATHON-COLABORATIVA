defmodule HackathonCode4.Domain.Participant do
   @enforce_keys [:id, :name, :email]
  defstruct [:id, :name, :email, team_id: nil]

  def new(id, name, email) do
    %__MODULE__{id: id, name: name, email: email}
  end

  def assign_team(participant, team_id) do
    %{participant | team_id: team_id}
  end
end
