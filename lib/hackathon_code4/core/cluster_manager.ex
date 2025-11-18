defmodule HackathonCode4.Core.ClusterManager do
  @moduledoc """
  Maneja la conexión y sincronización de nodos en el cluster.
  """

  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Conecta de forma segura a otro nodo.
  """
  def safe_connect(node_name) do
    GenServer.call(__MODULE__, {:connect, node_name})
  end

  @doc """
  Lista todos los nodos conectados con sus servicios.
  """
  def cluster_status do
    GenServer.call(__MODULE__, :cluster_status)
  end

  @impl true
  def init(state) do
    # Monitorear cambios en la topología del cluster
    :net_kernel.monitor_nodes(true, node_type: :all)
    {:ok, state}
  end

  @impl true
  def handle_call({:connect, node_name}, _from, state) do
    result = case Node.connect(node_name) do
      true ->
        Logger.info("Successfully connected to #{node_name}")

        # Dar tiempo para que se sincronicen los servicios globales
        Process.sleep(2000)

        # Verificar servicios disponibles
        services = check_global_services()
        {:ok, "Connected to #{node_name}. Available services: #{inspect(services)}"}

      false ->
        {:error, "Failed to connect to #{node_name}"}

      :ignored ->
        {:ok, "Already connected to #{node_name}"}
    end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:cluster_status, _from, state) do
    status = %{
      current_node: node(),
      connected_nodes: Node.list(),
      global_services: check_global_services(),
      registered_names: Process.registered()
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info({:nodeup, node, _info}, state) do
    Logger.info("Node #{node} joined the cluster")

    # Sincronizar información cuando un nodo se une
    spawn(fn -> sync_on_node_join(node) end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:nodedown, node, _info}, state) do
    Logger.warning("Node #{node} left the cluster")
    {:noreply, state}
  end

  # Private functions

  defp check_global_services do
    services = [
      {:file_repository, HackathonCode4.Adapters.FileRepository},

      {:chat_server, HackathonCode4.Core.ChatServer},
      {:mentor_server, HackathonCode4.Core.MentorServer}
    ]

    Enum.map(services, fn {name, module} ->
      case :global.whereis_name(module) do
        :undefined -> {name, :not_available}
        pid -> {name, {:available, node(pid)}}
      end
    end)
    |> Enum.into(%{})
  end

  def active_users do
    nodes = [node() | Node.list()]
    tasks = Enum.map(nodes, fn n ->
      Task.async(fn ->
        case :rpc.call(n, HackathonCode4.Core.SessionServer, :current_user, []) do
          {:ok, user} -> {n, user}
          _ -> {n, nil}
        end
      end)
    end)
    Task.await_many(tasks, 5000)
    |> Enum.filter(fn {_node, user} -> user != nil end)
    |> Enum.map(fn {node, user} -> %{name: user.name, email: user.email, node: node} end)
  end

  defp sync_on_node_join(_node) do
    # Dar tiempo para que los procesos globales se resuelvan
    Process.sleep(3000)

    # Notificar a todos los usuarios activos
    Phoenix.PubSub.broadcast(
      HackathonCode4.PubSub,
      "system",
      {:cluster_updated, Node.list()}
    )
  end
end

