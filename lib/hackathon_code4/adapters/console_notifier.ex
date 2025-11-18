defmodule HackathonCode4.Adapters.ConsoleNotifier do
  @behaviour HackathonCode4.Ports.Notifier

  @impl true
  def notify(message) do
    IO.puts(message)
    :ok
  end

  @impl true
  def notify_error(message) do
    IO.puts(IO.ANSI.red() <> "❌ ERROR: #{message}" <> IO.ANSI.reset())
    :ok
  end

  @impl true
  def notify_success(message) do
    IO.puts(IO.ANSI.green() <> "✓ #{message}" <> IO.ANSI.reset())
    :ok
  end
end
