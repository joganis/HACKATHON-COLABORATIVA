defmodule HackathonCode4.IEx.Commands do
  alias HackathonCode4.Core.{SessionServer, ChatServer,ClusterManager}
  alias HackathonCode4.UseCases.{TeamManagement, ProjectManagement, MentorManagement}
  alias HackathonCode4.Adapters.ConsoleNotifier

  # ==================== AUTENTICACIÓN ====================

  def register(name, email) do
    case TeamManagement.register_participant(name, email) do
      {:ok, participant} ->
        ConsoleNotifier.notify_success("Participant registered!")
        ConsoleNotifier.notify("   Name: #{participant.name}")
        ConsoleNotifier.notify("   Email: #{participant.email}")
        ConsoleNotifier.notify("   ID: #{participant.id}")
        ConsoleNotifier.notify("\n  Use: login(\"#{participant.id}\")")
        {:ok, participant}

      {:error, reason} ->
        ConsoleNotifier.notify_error(reason)
        {:error, reason}
    end
  end

  def login(participant_id) do
    case SessionServer.login(participant_id) do
      {:ok, participant} ->
        ConsoleNotifier.notify_success("Welcome #{participant.name}!")
        ConsoleNotifier.notify("   Node: #{node()}")
        {:ok, participant}

      {:error, reason} ->
        ConsoleNotifier.notify_error("Login failed: #{reason}")
        {:error, reason}
    end
  end

  def logout do
    case SessionServer.current_user() do
      {:ok, participant} ->
        SessionServer.logout(participant.id)
        ConsoleNotifier.notify_success("Goodbye #{participant.name}!")
        :ok

      {:error, _} ->
        ConsoleNotifier.notify_error("Not logged in")
        :error
    end
  end

  def whoami do
    case SessionServer.current_user() do
      {:ok, participant} ->
        ConsoleNotifier.notify("Logged in as: #{participant.name}")
        ConsoleNotifier.notify("Email: #{participant.email}")
        ConsoleNotifier.notify("Node: #{node()}")
        {:ok, participant}

      {:error, reason} ->
        ConsoleNotifier.notify_error(reason)
        {:error, reason}
    end
  end

  # ==================== EQUIPOS ====================

  def create_team(name, theme) do
    case TeamManagement.create_team(name, theme) do
      {:ok, team} ->
        DynamicSupervisor.start_child(
          HackathonCode4.TeamSupervisor,
          {HackathonCode4.Core.TeamServer, team.id}
        )

        ConsoleNotifier.notify_success("Team created!")
        ConsoleNotifier.notify("   Name: #{team.name}")
        ConsoleNotifier.notify("   Theme: #{team.theme}")
        ConsoleNotifier.notify("   ID: #{team.id}")
        {:ok, team}

      {:error, reason} ->
        ConsoleNotifier.notify_error(reason)
        {:error, reason}
    end
  end

  def teams do
    case TeamManagement.list_teams() do
      {:ok, []} ->
        ConsoleNotifier.notify("No teams yet")
        {:ok, []}

      {:ok, teams} ->
        ConsoleNotifier.notify("\n=== TEAMS ===")
        Enum.each(teams, fn team ->
          ConsoleNotifier.notify("• #{team.name} (ID: #{team.id})")
          ConsoleNotifier.notify("  Theme: #{team.theme}")
          ConsoleNotifier.notify("  Members: #{length(team.members)}")
        end)
        {:ok, teams}

      error -> error
    end
  end

  def join(team_id) do
    with {:ok, participant} <- SessionServer.current_user(),
         {:ok, _team} <- TeamManagement.join_team(participant.id, team_id) do
      ConsoleNotifier.notify_success("Joined team successfully!")
      ChatServer.subscribe("team-#{team_id}")
      :ok
    else
      {:error, "Not logged in"} ->
        ConsoleNotifier.notify_error("Please login first")
        {:error, "Not logged in"}

      {:error, reason} ->
        ConsoleNotifier.notify_error(reason)
        {:error, reason}
    end
  end

  def participants do
    case TeamManagement.list_participants() do
      {:ok, []} ->
        ConsoleNotifier.notify("No participants yet")
        {:ok, []}

      {:ok, participants} ->
        ConsoleNotifier.notify("\n=== PARTICIPANTS ===")
        Enum.each(participants, fn p ->
          team_status = if p.team_id, do: "Team: #{p.team_id}", else: "No team"
          ConsoleNotifier.notify("• #{p.name} (#{p.email}) - #{team_status}")
        end)
        {:ok, participants}

      error -> error
    end
  end

  # ==================== PROYECTOS ====================

  def register_project(team_id, title, description, category) do
    case ProjectManagement.register_project(team_id, title, description, category) do
      {:ok, project} ->
        ConsoleNotifier.notify_success("Project registered!")
        ConsoleNotifier.notify("   Title: #{project.title}")
        ConsoleNotifier.notify("   Category: #{project.category}")
        ConsoleNotifier.notify("   ID: #{project.id}")
        {:ok, project}

      {:error, reason} ->
        ConsoleNotifier.notify_error(reason)
        {:error, reason}
    end
  end

  def project(team_name) do
    case ProjectManagement.get_project_by_team(team_name) do
      {:ok, project} ->
        ConsoleNotifier.notify("\n=== PROJECT: #{project.title} ===")
        ConsoleNotifier.notify("Category: #{project.category}")
        ConsoleNotifier.notify("Status: #{project.status}")
        ConsoleNotifier.notify("Description: #{project.description}")

        ConsoleNotifier.notify("\n--- Advances ---")
        if Enum.empty?(project.advances) do
          ConsoleNotifier.notify("No advances yet")
        else
          Enum.each(project.advances, fn adv ->
            ConsoleNotifier.notify("• #{adv.text}")
          end)
        end

        ConsoleNotifier.notify("\n--- Feedback ---")
        if Enum.empty?(project.feedback) do
          ConsoleNotifier.notify("No feedback yet")
        else
          Enum.each(project.feedback, fn fb ->
            ConsoleNotifier.notify("• [Mentor #{fb.mentor_id}]: #{fb.text}")
          end)
        end

        {:ok, project}

      {:error, reason} ->
        ConsoleNotifier.notify_error(reason)
        {:error, reason}
    end
  end

  def add_advance(project_id, advance_text) do
    case ProjectManagement.add_advance(project_id, advance_text) do
      {:ok, _} ->
        ConsoleNotifier.notify_success("Advance added!")
        :ok

      {:error, reason} ->
        ConsoleNotifier.notify_error(reason)
        {:error, reason}
    end
  end

  # ==================== CHAT ====================

  def send_msg(room, content) do
    case SessionServer.current_user() do
      {:ok, participant} ->
        case ChatServer.send_message(room, participant.name, content) do
          {:ok, _} ->
            ConsoleNotifier.notify_success("Message sent")
            :ok

          {:error, reason} ->
            ConsoleNotifier.notify_error(reason)
            {:error, reason}
        end

      {:error, _} ->
        ConsoleNotifier.notify_error("Please login first")
        {:error, "Not logged in"}
    end
  end

  def chat(room) do
    ChatServer.subscribe(room)

    case ChatServer.get_messages(room, 20) do
      {:ok, messages} ->
        ConsoleNotifier.notify("\n=== CHAT: #{room} ===")

        if Enum.empty?(messages) do
          ConsoleNotifier.notify("No messages yet")
        else
          Enum.each(messages, fn msg ->
            timestamp = Calendar.strftime(msg.timestamp, "%H:%M:%S")
            ConsoleNotifier.notify("[#{timestamp}] #{msg.sender}: #{msg.content}")
          end)
        end

        ConsoleNotifier.notify("\n✓ Subscribed to room '#{room}'")
        ConsoleNotifier.notify("Use: send(\"#{room}\", \"your message\")")
        :ok

      error -> error
    end
  end

  def leave(room) do
    ChatServer.unsubscribe(room)
    ConsoleNotifier.notify_success("Left room: #{room}")
    :ok
  end

  # ==================== MENTORES ====================

  def register_mentor(name, email, expertise) do
    case MentorManagement.register_mentor(name, email, expertise) do
      {:ok, mentor} ->
        ConsoleNotifier.notify_success("Mentor registered!")
        ConsoleNotifier.notify("   Name: #{mentor.name}")
        ConsoleNotifier.notify("   Expertise: #{mentor.expertise}")
        ConsoleNotifier.notify("   ID: #{mentor.id}")
        {:ok, mentor}

      {:error, reason} ->
        ConsoleNotifier.notify_error(reason)
        {:error, reason}
    end
  end

  def mentors do
    case MentorManagement.list_mentors() do
      {:ok, []} ->
        ConsoleNotifier.notify("No mentors yet")
        {:ok, []}

      {:ok, mentors} ->
        ConsoleNotifier.notify("\n=== MENTORS ===")
        Enum.each(mentors, fn mentor ->
          ConsoleNotifier.notify("• #{mentor.name} - #{mentor.expertise}")
          ConsoleNotifier.notify("  ID: #{mentor.id}")
        end)
        {:ok, mentors}

      error -> error
    end
  end

  def give_feedback(mentor_id, project_id, feedback) do
    case HackathonCode4.Core.MentorServer.give_feedback(mentor_id, project_id, feedback) do
      {:ok, _} ->
        ConsoleNotifier.notify_success("Feedback submitted!")
        :ok

      {:error, reason} ->
        ConsoleNotifier.notify_error(reason)
        {:error, reason}
    end
  end

  # ==================== SISTEMA ====================

  @spec online() :: {:ok, any()}
  def online do
    users = HackathonCode4.Core.ClusterManager.active_users()

    if Enum.empty?(users) do
      ConsoleNotifier.notify("No users online")
    else
      ConsoleNotifier.notify("\n=== ONLINE USERS ===")
      Enum.each(users, fn user ->
        ConsoleNotifier.notify("• #{user.name} @ #{user.node}")
      end)
    end

    {:ok, users}
  end

  def nodes do
    connected = Node.list()

    ConsoleNotifier.notify("\n=== CONNECTED NODES ===")
    ConsoleNotifier.notify("Current node: #{node()}")

    if Enum.empty?(connected) do
      ConsoleNotifier.notify("No other nodes connected")
    else
      ConsoleNotifier.notify("\nConnected:")
      Enum.each(connected, fn n ->
        ConsoleNotifier.notify("• #{n}")
      end)
    end

    {:ok, connected}
  end

  def connect(node_name) do
    case ClusterManager.safe_connect(node_name) do
      {:ok, message} ->
        ConsoleNotifier.notify_success(message)
        cluster_info()
        :ok

      {:error, reason} ->
        ConsoleNotifier.notify_error("Failed to connect: #{reason}")
        {:error, reason}
    end
  end

  def cluster_info do
    status = ClusterManager.cluster_status()

    ConsoleNotifier.notify("\n=== CLUSTER STATUS ===")
    ConsoleNotifier.notify("Current node: #{status.current_node}")
    ConsoleNotifier.notify("Connected nodes: #{inspect(status.connected_nodes)}")
    ConsoleNotifier.notify("\nGlobal Services:")

    Enum.each(status.global_services, fn {service, state} ->
      case state do
        :not_available ->
          ConsoleNotifier.notify("   #{service}: not available")
        {:available, node} ->
          ConsoleNotifier.notify("   #{service}: running on #{node}")
      end
    end)

    :ok
  end
  def help do
    ConsoleNotifier.notify("""

    ╔══════════════════════════════════════════════════════╗
    ║     HACKATHON CODE4 - DISTRIBUTED SYSTEM            ║
    ╚══════════════════════════════════════════════════════╝

      AUTHENTICATION
    register(name, email)         Register participant
    login(participant_id)         Login to system
    logout()                      Logout
    whoami()                      Show current user
    online()                      Show online users

      TEAMS
    create_team(name, theme)      Create new team
    teams()                       List all teams
    join(team_id)                 Join a team
    participants()                List all participants

      PROJECTS
    register_project(team_id, title, desc, category)
    project(team_name)            View project info
    add_advance(project_id, text) Add project advance

      CHAT (Real-time distributed)
    chat(room)                    Open & subscribe to room
    send_msg(room, message)           Send message
    leave(room)                   Leave room

      MENTORS
    register_mentor(name, email, expertise)
    mentors()                     List mentors
    give_feedback(mentor_id, project_id, text)

      DISTRIBUTED SYSTEM
    nodes()                       Show connected nodes
    connect(node_name)            Connect to another node
    cluster_info()                Show cluster and services status

       Example:
       register("John", "john@test.com")
       login("participant_id")
       create_team("Innovators", "AI")
       chat("general")
       send("general", "Hello!")

    """)
    :ok
  end
end
