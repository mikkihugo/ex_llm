defmodule Singularity.Planning.WorkPlanAPI do
  @moduledoc """
  NATS API for submitting SAFe work items to SafeWorkPlanner

  ## NATS Subjects

  - `planning.strategic_theme.create` - Create a new strategic theme
  - `planning.epic.create` - Create a new epic
  - `planning.capability.create` - Create a new capability
  - `planning.feature.create` - Create a new feature
  - `planning.hierarchy.get` - Get full hierarchy view
  - `planning.progress.get` - Get progress summary
  - `planning.next_work.get` - Get next work item (highest WSJF)

  ## Message Format

  All messages should be JSON with the following structure:

  ```json
  {
    "name": "Feature Name",
    "description": "Feature description",
    "capability_id": "cap-abc123",  // Parent ID (varies by level)
    "acceptance_criteria": ["Criterion 1", "Criterion 2"]  // Optional
  }
  ```

  ## Response Format

  Success:
  ```json
  {
    "status": "ok",
    "id": "feat-xyz789",
    "message": "Feature created successfully"
  }
  ```

  Error:
  ```json
  {
    "status": "error",
    "errors": {"name": ["can't be blank"]}
  }
  ```
  """

  use GenServer
  require Logger

  alias Singularity.Planning.SafeWorkPlanner

  @subjects %{
    strategic_theme_create: "planning.strategic_theme.create",
    epic_create: "planning.epic.create",
    capability_create: "planning.capability.create",
    feature_create: "planning.feature.create",
    hierarchy_get: "planning.hierarchy.get",
    progress_get: "planning.progress.get",
    next_work_get: "planning.next_work.get"
  }

  ## Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ## GenServer Callbacks

  @impl true
  def init(:ok) do
    case Gnat.ConnectionSupervisor.connection_pid(:gnat) do
      pid when is_pid(pid) ->
        # Subscribe to all planning subjects
        Enum.each(@subjects, fn {_key, subject} ->
          :ok = Gnat.sub(pid, self(), subject)
          Logger.info("WorkPlanAPI subscribed to NATS subject: #{subject}")
        end)

        {:ok, %{conn: pid}}

      {:error, reason} ->
        Logger.error("Failed to get NATS connection: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_info({:msg, %{topic: topic, body: body, reply_to: reply_to}}, state) do
    Logger.debug("WorkPlanAPI received message",
      topic: topic,
      body_size: byte_size(body),
      has_reply: reply_to != nil
    )

    response = handle_message(topic, body)

    # Send reply if reply_to is present
    if reply_to do
      Gnat.pub(state.conn, reply_to, Jason.encode!(response))
    end

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warninging("WorkPlanAPI received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  ## Message Handlers

  defp handle_message(topic, body) do
    case Jason.decode(body) do
      {:ok, attrs} ->
        route_message(topic, attrs)

      {:error, reason} ->
        %{
          status: "error",
          message: "Invalid JSON",
          details: inspect(reason)
        }
    end
  end

  defp route_message("planning.strategic_theme.create", attrs) do
    case SafeWorkPlanner.add_strategic_theme(attrs) do
      {:ok, id} ->
        %{
          status: "ok",
          id: id,
          message: "Strategic theme created successfully"
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        %{
          status: "error",
          errors: format_changeset_errors(changeset)
        }

      {:error, reason} ->
        %{
          status: "error",
          message: inspect(reason)
        }
    end
  end

  defp route_message("planning.epic.create", attrs) do
    # Convert string type to atom if present
    attrs =
      if attrs["type"] do
        Map.update!(attrs, "type", &String.to_existing_atom/1)
      else
        attrs
      end

    case SafeWorkPlanner.add_epic(attrs) do
      {:ok, id} ->
        %{
          status: "ok",
          id: id,
          message: "Epic created successfully"
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        %{
          status: "error",
          errors: format_changeset_errors(changeset)
        }

      {:error, reason} ->
        %{
          status: "error",
          message: inspect(reason)
        }
    end
  end

  defp route_message("planning.capability.create", attrs) do
    case SafeWorkPlanner.add_capability(attrs) do
      {:ok, id} ->
        %{
          status: "ok",
          id: id,
          message: "Capability created successfully"
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        %{
          status: "error",
          errors: format_changeset_errors(changeset)
        }

      {:error, reason} ->
        %{
          status: "error",
          message: inspect(reason)
        }
    end
  end

  defp route_message("planning.feature.create", attrs) do
    case SafeWorkPlanner.add_feature(attrs) do
      {:ok, id} ->
        %{
          status: "ok",
          id: id,
          message: "Feature created successfully"
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        %{
          status: "error",
          errors: format_changeset_errors(changeset)
        }

      {:error, reason} ->
        %{
          status: "error",
          message: inspect(reason)
        }
    end
  end

  defp route_message("planning.hierarchy.get", _attrs) do
    hierarchy = SafeWorkPlanner.get_hierarchy()

    %{
      status: "ok",
      hierarchy: hierarchy
    }
  end

  defp route_message("planning.progress.get", _attrs) do
    progress = SafeWorkPlanner.get_progress()

    %{
      status: "ok",
      progress: progress
    }
  end

  defp route_message("planning.next_work.get", _attrs) do
    next_work = SafeWorkPlanner.get_next_work()

    %{
      status: "ok",
      next_work: next_work
    }
  end

  defp route_message(topic, _attrs) do
    Logger.warninging("Unknown NATS subject: #{topic}")

    %{
      status: "error",
      message: "Unknown subject: #{topic}"
    }
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
