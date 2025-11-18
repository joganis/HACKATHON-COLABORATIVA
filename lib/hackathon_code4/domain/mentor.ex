defmodule HackathonCode4.Domain.Mentor do
  @enforce_keys [:id, :name, :expertise]
  defstruct [:id, :name, :email, :expertise]

  def new(id, name, email, expertise) do
    %__MODULE__{id: id, name: name, email: email, expertise: expertise}
  end
end
