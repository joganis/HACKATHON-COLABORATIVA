defmodule HackathonCode4.UseCases.MentorManagement do
  alias HackathonCode4.Domain.Mentor
  alias HackathonCode4.Adapters.FileRepository

  def register_mentor(name, email, expertise) do
    id = generate_id()
    mentor = Mentor.new(id, name, email, expertise)
    FileRepository.save(mentor, :mentors)
  end

  def list_mentors do
    FileRepository.find_all(:mentors)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
