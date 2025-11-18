defmodule HackathonCode4.Domain.Team do
  @enforce_keys [:id, :name]
  defstruct [:id, :name, :theme, members: [], created_at: nil]

  def new(id, name, theme) do
    %__MODULE__{
      id: id,
      name: name,
      theme: theme,
      members: [],
      created_at: DateTime.utc_now()
    }
  end

  def add_member(team, participant_id) do
    if participant_id in team.members do
      {:error, "Participant already in team"}
    else
      {:ok, %{team | members: [participant_id | team.members]}}
    end
  end
end
