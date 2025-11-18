defmodule HackathonCode4.Core.ChatServer do
  use GenServer
  require Logger

  def start_link(_) do
    case GenServer.start_link(__MODULE__, %{}, name: {:global, __MODULE__}) do
      {:ok, pid} ->
        Logger.info("ChatServer started as global")
        # Suscribirse a los mensajes del sistema para notificaciones
        Phoenix.PubSub.subscribe(HackathonCode4.PubSub, "system")
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        Logger.info("ChatServer already running globally")
        {:ok, pid}
    end
  end

  def subscribe(room) do
    # El SessionServer es el que debe suscribirse para que el usuario reciba los mensajes
    HackathonCode4.Core.SessionServer.subscribe_to_chat(room)
  end

  def unsubscribe(room) do
    HackathonCode4.Core.SessionServer.unsubscribe_from_chat(room)
  end

  def send_message(room, sender, content) do
    GenServer.call({:global, __MODULE__}, {:send_message, room, sender, content})
  end

  def get_messages(room, limit \\ 50) do
    GenServer.call({:global, __MODULE__}, {:get_messages, room, limit})
  end

  @impl true
  def init(state) do
    Logger.info("ChatServer initialized")
    {:ok, state}
  end

  @impl true
  def handle_info({:new_message, message}, state) do
    # Esto no debería ocurrir aquí, ya que el SessionServer es el que debe recibir
    # y notificar al usuario. El ChatServer solo gestiona el envío y la persistencia.
    Logger.warning("ChatServer received unexpected message: #{inspect(message)}")
    {:noreply, state}
  end

  @impl true
  def handle_call({:send_message, room, sender, content}, _from, state) do
    message = %{
      id: generate_id(),
      room: room,
      sender: sender,
      content: content,
      timestamp: DateTime.utc_now(),
      node: node()
    }

    case save_message(message) do
      {:ok, _} ->
        Phoenix.PubSub.broadcast(
          HackathonCode4.PubSub,
          "chat:#{room}",
          {:new_message, message}
        )

        Logger.info("Message sent to #{room} by #{sender}")
        {:reply, {:ok, message}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_messages, room, limit}, _from, state) do
    alias HackathonCode4.Adapters.FileRepository

    case FileRepository.find_by(%{room: room}, :messages) do
      {:ok, messages} ->
        sorted = messages
        |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
        |> Enum.take(limit)
        |> Enum.reverse()

        {:reply, {:ok, sorted}, state}

      error ->
        {:reply, error, state}
    end
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp save_message(message) do
    alias HackathonCode4.Adapters.FileRepository
    alias HackathonCode4.Domain.Message

    msg_struct = struct(Message, message)
    FileRepository.save(msg_struct, :messages)
  end
end
