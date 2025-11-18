defmodule HackathonCode4.Domain.Message do
  @enforce_keys [:id, :room, :sender, :content]
  defstruct [:id, :room, :sender, :content, :timestamp, :node]

  def new(id, room, sender, content) do
    %__MODULE__{
      id: id,
      room: room,
      sender: sender,
      content: content,
      timestamp: DateTime.utc_now(),
      node: node()
    }
  end
end
