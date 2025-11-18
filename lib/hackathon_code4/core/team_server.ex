defmodule HackathonCode4.Core.TeamServer do
  use GenServer
  require Logger

  # Client API

  def start_link(team_id) do
    GenServer.start_link(__MODULE__, team_id, name: via_tuple(team_id))
  end

  def get_info(team_id) do
    case Registry.lookup(HackathonCode4.Registry, team_id) do
      [{pid, _}] -> GenServer.call(pid, :get_info)
      [] -> {:error, "Team process not found"}
    end
  end

  def broadcast_to_team(team_id, message) do
    Phoenix.PubSub.broadcast(
      HackathonCode4.PubSub,
      "team:#{team_id}",
      message
    )
  end

  # Server Callbacks

  @impl true
  def init(team_id) do
    alias HackathonCode4.Adapters.FileRepository

    case FileRepository.find_by_id(team_id, :teams) do
      {:ok, team} ->
        Logger.info("TeamServer started for team: #{team.name}")
        Phoenix.PubSub.subscribe(HackathonCode4.PubSub, "team:#{team_id}")
        {:ok, team}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:get_info, _from, team) do
    {:reply, {:ok, team}, team}
  end

  @impl true
  def handle_info({:member_added, participant_id}, team) do
    Logger.info("New member #{participant_id} added to team #{team.name}")
    {:noreply, team}
  end

  @impl true
  def handle_info(_msg, team) do
    {:noreply, team}
  end

  # Private

  defp via_tuple(team_id) do
    {:via, Registry, {HackathonCode4.Registry, team_id}}
  end
end
