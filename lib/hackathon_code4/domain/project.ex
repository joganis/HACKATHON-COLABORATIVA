defmodule HackathonCode4.Domain.Project do
  @enforce_keys [:id, :team_id, :title, :category]
  defstruct [:id, :team_id, :title, :description, :category, :status, advances: [], feedback: []]

  def new(id, team_id, title, description, category) do
    %__MODULE__{
      id: id,
      team_id: team_id,
      title: title,
      description: description,
      category: category,
      status: :in_progress,
      advances: [],
      feedback: []
    }
  end

  def add_advance(project, advance_text) do
    advance = %{text: advance_text, timestamp: DateTime.utc_now()}
    %{project | advances: [advance | project.advances]}
  end

  def add_feedback(project, mentor_id, feedback_text) do
    feedback = %{mentor_id: mentor_id, text: feedback_text, timestamp: DateTime.utc_now()}
    %{project | feedback: [feedback | project.feedback]}
  end
end
