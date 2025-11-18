defmodule HackathonCode4.Core.SessionServer do
  use GenServer
  require Logger

  # Client API

  def start_link(_) do
    # El SessionServer debe ser un proceso local para manejar la sesión del nodo actual
    GenServer.start_link(__MODULE__, %{
      current_user: nil,
      subscribed_rooms: []
    }, name: __MODULE__)
  end

  def login(participant_id) do
    GenServer.call(__MODULE__, {:login, participant_id})
  end

  def logout(participant_id) do
    GenServer.call(__MODULE__, {:logout, participant_id})
  end

  def current_user do
    GenServer.call(__MODULE__, :get_current_user)
  end

  def active_users do
    # La lista de usuarios activos debe ser gestionada por un proceso global
    # o por el ClusterManager. Por ahora, solo devolvemos el usuario local.
    case GenServer.call(__MODULE__, :get_current_user) do
      {:ok, user} -> [user]
      _ -> []
    end
  end

  def subscribe_to_chat(room) do
    GenServer.call(__MODULE__, {:subscribe_to_chat, room})
  end

  def unsubscribe_from_chat(room) do
    GenServer.call(__MODULE__, {:unsubscribe_from_chat, room})
  end



  # Server Callbacks (igual que antes)

  @impl true
  def init(state) do
    Logger.info("SessionServer started on #{node()}")
    {:ok, state}
  end

  @impl true
  def handle_call({:login, participant_id}, _from, %{current_user: nil} = state) do
    case validate_participant(participant_id) do
      {:ok, participant} ->
        new_state = Map.put(state, :current_user, %{
          participant_id: participant_id,
          participant: participant,
          logged_in_at: DateTime.utc_now()
        })

        Logger.info("User #{participant.name} logged in on #{node()}")

        # Notificar al cluster que un usuario ha iniciado sesión
        Phoenix.PubSub.broadcast(
          HackathonCode4.PubSub,
          "system",
          {:user_logged_in, participant.name, node()}
        )

        {:reply, {:ok, participant}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:login, _}, _from, %{current_user: %{participant: p}} = state) do
    {:reply, {:error, "User #{p.name} already logged in"}, state}
  end

  @impl true
  def handle_call({:logout, participant_id}, _from, %{current_user: %{participant_id: id, participant: p}} = state) when id == participant_id do
    new_state = Map.put(state, :current_user, nil)
    Logger.info("User #{p.name} logged out from #{node()}")

    # Desuscribir de todas las salas de chat
    Enum.each(state.subscribed_rooms, fn room ->
      Phoenix.PubSub.unsubscribe(HackathonCode4.PubSub, "chat:#{room}")
    end)

    # Notificar al cluster que un usuario ha cerrado sesión
    Phoenix.PubSub.broadcast(
      HackathonCode4.PubSub,
      "system",
      {:user_logged_out, p.name, node()}
    )

    {:reply, :ok, new_state}
  end

  def handle_call({:logout, _}, _from, state) do
    {:reply, {:error, "Not logged in or invalid participant ID"}, state}
  end

  @impl true
  def handle_call(:get_current_user, _from, %{current_user: nil} = state) do
    {:reply, {:error, "Not logged in"}, state}
  end

  def handle_call(:get_current_user, _from, %{current_user: session} = state) do
    {:reply, {:ok, session.participant}, state}
  end



  @impl true
  def handle_call({:subscribe_to_chat, room}, _from, %{current_user: %{participant: p}} = state) do
    Phoenix.PubSub.subscribe(HackathonCode4.PubSub, "chat:#{room}")
    new_state = update_in(state.subscribed_rooms, fn rooms -> [room | rooms] |> Enum.uniq() end)
    Logger.info("User #{p.name} subscribed to chat room #{room}")
    {:reply, :ok, new_state}
  end

  def handle_call({:subscribe_to_chat, _}, _from, state) do
    {:reply, {:error, "Not logged in"}, state}
  end

  @impl true
  def handle_call({:unsubscribe_from_chat, room}, _from, %{current_user: %{participant: p}} = state) do
    Phoenix.PubSub.unsubscribe(HackathonCode4.PubSub, "chat:#{room}")
    new_state = update_in(state.subscribed_rooms, fn rooms -> List.delete(rooms, room) end)
    Logger.info("User #{p.name} unsubscribed from chat room #{room}")
    {:reply, :ok, new_state}
  end

  def handle_call({:unsubscribe_from_chat, _}, _from, state) do
    {:reply, {:error, "Not logged in"}, state}
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    Logger.info("Node #{node} went down")
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    Logger.info("Node #{node} connected")
    {:noreply, state}
  end

  @impl true
  def handle_info({:new_message, message}, %{current_user: %{participant: _p}} = state) do
    # Mostrar el mensaje al usuario logueado
    timestamp = Calendar.strftime(message.timestamp, "%H:%M:%S")
    HackathonCode4.Adapters.ConsoleNotifier.notify("[#{timestamp}] #{message.sender} in #{message.room}: #{message.content}")
    {:noreply, state}
  end

  def handle_info({:new_message, _}, state) do
    # Ignorar si no hay usuario logueado
    {:noreply, state}
  end

  # Private

  defp validate_participant(participant_id) do
    alias HackathonCode4.Adapters.FileRepository
    FileRepository.find_by_id(participant_id, :participants)
  end
end
