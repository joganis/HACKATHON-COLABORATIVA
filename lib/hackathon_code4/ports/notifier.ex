defmodule HackathonCode4.Ports.Notifier do
  @callback notify(message :: String.t()) :: :ok
  @callback notify_error(message :: String.t()) :: :ok
  @callback notify_success(message :: String.t()) :: :ok
end
