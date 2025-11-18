defmodule HackathonCode4.Core.MentorServer do
  use GenServer
  require Logger

  def start_link(_) do
    case GenServer.start_link(__MODULE__, %{}, name: {:global, __MODULE__}) do
      {:ok, pid} ->
        Logger.info("MentorServer started as global")
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        Logger.info("MentorServer already running globally")
        {:ok, pid}
    end
  end

  def give_feedback(mentor_id, project_id, feedback) do
    GenServer.call({:global, __MODULE__}, {:give_feedback, mentor_id, project_id, feedback})
  end

  @impl true
  def init(state) do
    Logger.info("MentorServer initialized")
    {:ok, state}
  end

  @impl true
  def handle_call({:give_feedback, mentor_id, project_id, feedback}, _from, state) do
    alias HackathonCode4.UseCases.ProjectManagement

    case ProjectManagement.add_feedback(project_id, mentor_id, feedback) do
      {:ok, project} ->
        Phoenix.PubSub.broadcast(
          HackathonCode4.PubSub,
          "project:#{project_id}",
          {:feedback_received, mentor_id, feedback}
        )

        Logger.info("Feedback added to project #{project_id}")
        {:reply, {:ok, project}, state}

      error ->
        {:reply, error, state}
    end
  end
end
