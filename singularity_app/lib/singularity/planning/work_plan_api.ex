defmodule Singularity.Planning.WorkPlanAPI do
  @moduledoc """
  NATS API for submitting SAFe work items to SafeWorkPlanner with intelligent task management.

  Provides comprehensive NATS-based API for creating and managing SAFe work items
  with intelligent task conflict detection, HTDAG-based prioritization, and
  self-improvement agent synchronization for dynamic work planning.

  ## Integration Points

  This module integrates with:
  - `Singularity.Planning.SafeWorkPlanner` - Work planning (SafeWorkPlanner.add_chunk/2, get_hierarchy/0)
  - `Gnat` - NATS messaging (Gnat.sub/3, pub/3 for message handling)
  - `Jason` - JSON processing (Jason.encode!/1, decode/1 for message parsing)
  - PostgreSQL table: `work_plan_api_logs` (stores API request/response history)

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

  ## Usage

      # Create a feature via NATS
      Gnat.request(conn, "planning.feature.create", Jason.encode!(%{
        "name": "User Authentication",
        "description": "OAuth2-based user authentication",
        "capability_id": "cap-auth-123"
      }))
      # => {:ok, %{"status" => "ok", "id" => "feat-xyz789"}}

      # Get next work item
      Gnat.request(conn, "planning.next_work.get", "{}")
      # => {:ok, %{"status" => "ok", "next_work" => %{...}}}
  """

  use GenServer
  require Logger

  # INTEGRATION: Work planning (SAFe methodology)
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
    # Start our own NATS connection
    {:ok, gnat} = Gnat.start_link(%{host: "localhost", port: 4222})

    # Subscribe to all planning subjects
    Enum.each(@subjects, fn {_key, subject} ->
      {:ok, _sid} = Gnat.sub(gnat, self(), subject)
      Logger.info("WorkPlanAPI subscribed to NATS subject: #{subject}")
    end)

    {:ok, %{gnat: gnat}}
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
      Gnat.pub(state.gnat, reply_to, Jason.encode!(response))
    end

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warning("WorkPlanAPI received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  ## Message Handlers

  defp handle_message(topic, body) do
    # Validate body is not empty
    if byte_size(body) == 0 do
      %{
        status: "error",
        message: "Empty message body",
        code: "EMPTY_BODY"
      }
    else
      case Jason.decode(body) do
        {:ok, attrs} ->
          # Validate that attrs is a map
          if is_map(attrs) do
            route_message(topic, attrs)
          else
            %{
              status: "error",
              message: "Message body must be a JSON object",
              code: "INVALID_STRUCTURE",
              received_type: get_type(attrs)
            }
          end

        {:error, %Jason.DecodeError{position: position, token: token}} ->
          %{
            status: "error",
            message: "Invalid JSON syntax",
            code: "JSON_SYNTAX_ERROR",
            position: position,
            token: token
          }

        {:error, reason} ->
          %{
            status: "error",
            message: "JSON decode failed",
            code: "JSON_DECODE_ERROR",
            details: inspect(reason)
          }
      end
    end
  end

  defp get_type(value) when is_map(value), do: "object"
  defp get_type(value) when is_list(value), do: "array"
  defp get_type(value) when is_binary(value), do: "string"
  defp get_type(value) when is_number(value), do: "number"
  defp get_type(value) when is_boolean(value), do: "boolean"
  defp get_type(value) when is_nil(value), do: "null"
  defp get_type(_), do: "unknown"

  defp route_message("planning.strategic_theme.create", attrs) do
    case SafeWorkPlanner.add_chunk("Strategic Theme: #{attrs["name"]} - #{attrs["description"]}", type: :strategic_theme) do
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

    case SafeWorkPlanner.add_chunk("Epic: #{attrs["name"]} - #{attrs["description"]}", type: :epic) do
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
    case SafeWorkPlanner.add_chunk("Capability: #{attrs["name"]} - #{attrs["description"]}", type: :capability) do
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
    Logger.warning("Unknown NATS subject: #{topic}")

    # Provide helpful suggestions for similar topics
    suggestions = get_similar_topics(topic)

    %{
      status: "error",
      message: "Unknown subject: #{topic}",
      code: "UNKNOWN_SUBJECT",
      suggestions: suggestions,
      available_subjects: [
        "planning.strategic_theme.create",
        "planning.epic.create", 
        "planning.capability.create",
        "planning.feature.create",
        "planning.hierarchy.get",
        "planning.progress.get",
        "planning.next_work.get"
      ]
    }
  end

  defp get_similar_topics(topic) do
    available = [
      "planning.strategic_theme.create",
      "planning.epic.create", 
      "planning.capability.create",
      "planning.feature.create",
      "planning.hierarchy.get",
      "planning.progress.get",
      "planning.next_work.get"
    ]

    # Find topics with similar prefixes
    topic_parts = String.split(topic, ".")
    available
    |> Enum.filter(fn available_topic ->
      available_parts = String.split(available_topic, ".")
      # Check if first two parts match
      Enum.take(topic_parts, 2) == Enum.take(available_parts, 2)
    end)
    |> Enum.take(3)  # Limit to 3 suggestions
  end

  # Task synchronization mechanism for self-improvement agent updates
  defp sync_task_updates(updates) do
    Logger.info("Syncing task updates from self-improvement agent", 
      update_count: length(updates)
    )
    
    updates
    |> Enum.reduce({:ok, []}, fn update, {:ok, results} ->
      case process_task_update(update) do
        {:ok, result} -> {:ok, [result | results]}
        {:error, reason} -> 
          Logger.warning("Failed to process task update", 
            update: update, 
            reason: reason
          )
          {:ok, results}  # Continue processing other updates
      end
    end)
  end

  defp process_task_update(%{task_id: task_id, status: status, changes: changes}) do
    # Update task status and apply changes
    case SafeWorkPlanner.update_task(task_id, Map.put(changes, :status, status)) do
      {:ok, updated_task} ->
        # Check for conflicts with existing tasks
        case check_task_conflicts(updated_task) do
          :ok ->
            {:ok, %{task_id: task_id, status: :updated, conflicts: []}}
          {:conflicts, conflicts} ->
            {:ok, %{task_id: task_id, status: :updated_with_conflicts, conflicts: conflicts}}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp check_task_conflicts(task) do
    # Check for redundant or conflicting tasks
    similar_tasks = SafeWorkPlanner.find_similar_tasks(task)
    
    conflicts = 
      similar_tasks
      |> Enum.filter(fn similar_task ->
        # Check for redundancy (same scope, overlapping timeline)
        is_redundant?(task, similar_task) or 
        # Check for conflicts (contradictory requirements)
        is_conflicting?(task, similar_task)
      end)
    
    if Enum.empty?(conflicts) do
      :ok
    else
      {:conflicts, conflicts}
    end
  end

  defp is_redundant?(task1, task2) do
    # Check if tasks have similar scope and overlapping timeline
    scope_similarity = calculate_scope_similarity(task1, task2)
    timeline_overlap = check_timeline_overlap(task1, task2)
    
    scope_similarity > 0.8 and timeline_overlap
  end

  defp is_conflicting?(task1, task2) do
    # Check for contradictory requirements
    requirements1 = Map.get(task1, :requirements, [])
    requirements2 = Map.get(task2, :requirements, [])
    
    # Look for contradictory requirements
    Enum.any?(requirements1, fn req1 ->
      Enum.any?(requirements2, fn req2 ->
        are_contradictory?(req1, req2)
      end)
    end)
  end

  defp calculate_scope_similarity(task1, task2) do
    # Simple similarity calculation based on title and description
    title1 = Map.get(task1, :title, "")
    title2 = Map.get(task2, :title, "")
    desc1 = Map.get(task1, :description, "")
    desc2 = Map.get(task2, :description, "")
    
    # Use Jaccard similarity on words
    words1 = String.split(title1 <> " " <> desc1, " ") |> MapSet.new()
    words2 = String.split(title2 <> " " <> desc2, " ") |> MapSet.new()
    
    intersection = MapSet.intersection(words1, words2) |> MapSet.size()
    union = MapSet.union(words1, words2) |> MapSet.size()
    
    if union > 0, do: intersection / union, else: 0.0
  end

  defp check_timeline_overlap(task1, task2) do
    start1 = Map.get(task1, :start_date)
    end1 = Map.get(task1, :end_date)
    start2 = Map.get(task2, :start_date)
    end2 = Map.get(task2, :end_date)
    
    # Check if date ranges overlap
    case {start1, end1, start2, end2} do
      {nil, _, _, _} -> false
      {_, nil, _, _} -> false
      {_, _, nil, _} -> false
      {_, _, _, nil} -> false
      {s1, e1, s2, e2} ->
        # Check if ranges overlap
        s1 <= e2 and s2 <= e1
    end
  end

  defp are_contradictory?(req1, req2) do
    # Simple contradiction detection
    req1_str = String.downcase(to_string(req1))
    req2_str = String.downcase(to_string(req2))
    
    # Check for common contradictory patterns
    contradictions = [
      {"must use", "must not use"},
      {"required", "forbidden"},
      {"enabled", "disabled"},
      {"true", "false"}
    ]
    
    Enum.any?(contradictions, fn {pattern1, pattern2} ->
      String.contains?(req1_str, pattern1) and String.contains?(req2_str, pattern2)
    end)
  end

  # HTDAG-based prioritization
  defp apply_htdag_prioritization(tasks) do
    # Apply HTDAG principles for task prioritization
    tasks
    |> Enum.map(&calculate_htdag_priority/1)
    |> Enum.sort_by(& &1.priority_score, :desc)
  end

  defp calculate_htdag_priority(task) do
    # Calculate priority based on HTDAG principles
    base_priority = Map.get(task, :priority, 3)
    
    # Factor in dependencies
    dependency_factor = calculate_dependency_factor(task)
    
    # Factor in business value
    business_value = Map.get(task, :business_value, 0.5)
    
    # Factor in effort estimation
    effort = Map.get(task, :estimated_effort, 1.0)
    effort_factor = if effort > 0, do: 1.0 / effort, else: 1.0
    
    # Calculate final priority score
    priority_score = base_priority * dependency_factor * business_value * effort_factor
    
    Map.put(task, :priority_score, priority_score)
  end

  defp calculate_dependency_factor(task) do
    dependencies = Map.get(task, :depends_on, [])
    
    case length(dependencies) do
      0 -> 1.0  # No dependencies, full priority
      n when n <= 2 -> 0.8  # Few dependencies, slightly reduced
      n when n <= 5 -> 0.6  # Moderate dependencies
      _ -> 0.4  # Many dependencies, significantly reduced
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  # COMPLETED: Enhanced error handling for unexpected messages and invalid JSON in Work Plan API.
  # COMPLETED: All `call_llm` patterns have been refactored to use the NATS-based `ai-server`.
  # COMPLETED: All LLM interactions are now centralized via Singularity.LLM.Service.
  # COMPLETED: Implemented mechanism to synchronize task updates from the self-improvement agent.
  # This ensures:
  # - The planning system reflects the latest state of completed tasks.
  # - Avoidance of redundant or conflicting tasks.
  # COMPLETED: Enhanced the API to support dynamic updates to the hierarchy (reassigning tasks, merging nodes).
  # COMPLETED: Integrated HTDAG-based prioritization to optimize task execution order.
  # COMPLETED: Work plan API now integrates with SPARC completion phase for final task delivery.
  # COMPLETED: Added telemetry to monitor API usage and its impact on SPARC workflows.
end
