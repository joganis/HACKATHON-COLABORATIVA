defmodule HackathonCode4.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Crear directorio de datos
    File.mkdir_p!("data")

    children = [
      # Starts a worker by calling: HackathonCode4.Worker.start_link(arg)
      # {HackathonCode4.Worker, arg}
       # PubSub para mensajería distribuida
      {Phoenix.PubSub, name: HackathonCode4.PubSub},

      # Registry para procesos nombrados
      {Registry, keys: :unique, name: HackathonCode4.Registry},

      # Repositorio de archivos
      {HackathonCode4.Adapters.FileRepository, []},

      # Supervisor dinámico para equipos
      {DynamicSupervisor, name: HackathonCode4.TeamSupervisor, strategy: :one_for_one},

      HackathonCode4.Core.ClusterManager,

      # Servidores del sistema
      HackathonCode4.Core.ChatServer,
      HackathonCode4.Core.MentorServer,
      HackathonCode4.Core.SessionServer

    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HackathonCode4.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
