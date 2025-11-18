defmodule HackathonCode4.UseCases.ProjectManagement do
  alias HackathonCode4.Domain.Project
  alias HackathonCode4.Adapters.FileRepository

  def register_project(team_id, title, description, category) do
    id = generate_id()
    project = Project.new(id, team_id, title, description, category)
    FileRepository.save(project, :projects)
  end

  def add_advance(project_id, advance_text) do
    with {:ok, project} <- FileRepository.find_by_id(project_id, :projects) do
      updated = Project.add_advance(project, advance_text)
      FileRepository.save(updated, :projects)
    end
  end

  def get_project_by_team(team_name) do
    with {:ok, teams} <- FileRepository.find_all(:teams),
         team when not is_nil(team) <- Enum.find(teams, fn t -> t.name == team_name end),
         {:ok, projects} <- FileRepository.find_by(%{team_id: team.id}, :projects) do
      case projects do
        [project | _] -> {:ok, project}
        [] -> {:error, "No project found for team"}
      end
    else
      _ -> {:error, "Team not found"}
    end
  end

  def add_feedback(project_id, mentor_id, feedback_text) do
    with {:ok, project} <- FileRepository.find_by_id(project_id, :projects) do
      updated = Project.add_feedback(project, mentor_id, feedback_text)
      FileRepository.save(updated, :projects)
    end
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
