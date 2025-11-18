defmodule HackathonCode4 do
  @moduledoc """
  Documentation for `HackathonCode4`. Sistema distribuido para gestión de hackathons.
  """


    @doc """
  Función principal (para compatibilidad con escript).
  """
  def main(_args) do
    IO.puts("Use IEx to interact with the system:")
    IO.puts("  iex --sname node1 --cookie hackathon_secret -S mix")
  end
end
