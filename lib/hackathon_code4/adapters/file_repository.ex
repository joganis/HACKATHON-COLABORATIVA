defmodule HackathonCode4.Adapters.FileRepository do
  use GenServer
  @behaviour HackathonCode4.Ports.Repository

  def start_link(_opts) do
    case GenServer.start_link(__MODULE__, %{}, name: {:global, __MODULE__}) do
      {:ok, pid} ->
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        {:ok, pid}
    end
  end

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl HackathonCode4.Ports.Repository
  def save(entity, collection) do
    GenServer.call({:global, __MODULE__}, {:save, entity, collection})
  end

  @impl HackathonCode4.Ports.Repository
  def find_by_id(id, collection) do
    GenServer.call({:global, __MODULE__}, {:find_by_id, id, collection})
  end

  @impl HackathonCode4.Ports.Repository
  def find_all(collection) do
    GenServer.call({:global, __MODULE__}, {:find_all, collection})
  end

  @impl HackathonCode4.Ports.Repository
  def find_by(filters, collection) do
    GenServer.call({:global, __MODULE__}, {:find_by, filters, collection})
  end

  @impl HackathonCode4.Ports.Repository
  def delete(id, collection) do
    GenServer.call({:global, __MODULE__}, {:delete, id, collection})
  end

  # Server Callbacks

  @impl true
  def handle_call({:save, entity, collection}, _from, state) do
    filename = filename_for(collection)

    case do_find_all(collection) do
      {:ok, entities} ->
        updated = Enum.reject(entities, fn e -> e.id == entity.id end)
        all_entities = [entity | updated]

        encoded = Enum.map(all_entities, &:erlang.term_to_binary/1)
        content = Enum.join(encoded |> Enum.map(&Base.encode64/1), "\n")

        case File.write(filename, content) do
          :ok -> {:reply, {:ok, entity}, state}
          {:error, reason} -> {:reply, {:error, "Failed to save: #{reason}"}, state}
        end

      {:error, _} -> {:reply, {:error, "Could not read existing data"}, state}
    end
  end

  @impl true
  def handle_call({:find_by_id, id, collection}, _from, state) do
    case do_find_all(collection) do
      {:ok, entities} ->
        case Enum.find(entities, fn e -> e.id == id end) do
          nil -> {:reply, {:error, "Not found"}, state}
          entity -> {:reply, {:ok, entity}, state}
        end

      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:find_all, collection}, _from, state) do
    result = do_find_all(collection)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:find_by, filters, collection}, _from, state) do
    case do_find_all(collection) do
      {:ok, entities} ->
        filtered =
          Enum.filter(entities, fn entity ->
            Enum.all?(filters, fn {key, value} ->
              Map.get(entity, key) == value
            end)
          end)

        {:reply, {:ok, filtered}, state}

      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:delete, id, collection}, _from, state) do
    case do_find_all(collection) do
      {:ok, entities} ->
        updated = Enum.reject(entities, fn e -> e.id == id end)
        encoded = Enum.map(updated, &:erlang.term_to_binary/1)
        content = Enum.join(encoded |> Enum.map(&Base.encode64/1), "\n")
        result = File.write(filename_for(collection), content)
        {:reply, result, state}

      error -> {:reply, error, state}
    end
  end

  # Private

  defp do_find_all(collection) do
    filename = filename_for(collection)

    case File.read(filename) do
      {:ok, ""} -> {:ok, []}
      {:ok, content} ->
        entities =
          content
          |> String.split("\n", trim: true)
          |> Enum.map(&Base.decode64!/1)
          |> Enum.map(&:erlang.binary_to_term/1)

        {:ok, entities}

      {:error, :enoent} -> {:ok, []}
      {:error, reason} -> {:error, "Failed to read: #{reason}"}
    end
  end

  defp filename_for(:teams), do: "data/teams.txt"
  defp filename_for(:participants), do: "data/participants.txt"
  defp filename_for(:projects), do: "data/projects.txt"
  defp filename_for(:messages), do: "data/messages.txt"
  defp filename_for(:mentors), do: "data/mentors.txt"
end
