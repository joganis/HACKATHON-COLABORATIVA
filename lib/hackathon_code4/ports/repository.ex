defmodule HackathonCode4.Ports.Repository do
  @callback save(entity :: struct(), collection :: atom()) :: {:ok, struct()} | {:error, String.t()}
  @callback find_by_id(id :: String.t(), collection :: atom()) :: {:ok, struct()} | {:error, String.t()}
  @callback find_all(collection :: atom()) :: {:ok, list(struct())}
  @callback find_by(filters :: map(), collection :: atom()) :: {:ok, list(struct())}
  @callback delete(id :: String.t(), collection :: atom()) :: :ok | {:error, String.t()}
end
