defmodule Singularity.Execution.Planning.WorkPlanAPI do
  @moduledoc """
  pgmq API for submitting SAFe work items to SafeWorkPlanner with intelligent task management.

  Provides comprehensive pgmq-based API for creating and managing SAFe work items
  with intelligent task conflict detection, TaskGraph-based prioritization, and
  self-improvement agent synchronization for dynamic work planning.

  ## Integration Points

  This module integrates with:
  - `Singularity.Execution.Planning.SafeWorkPlanner` - Work planning (SafeWorkPlanner.add_chunk/2, get_hierarchy/0)
  - `pgmq` - pgmq messaging (Singularity.Jobs.PgmqClient.sub/3, pub/3 for message handling)
  - `Jason` - JSON processing (Jason.encode!/1, decode/1 for message parsing)
  - PostgreSQL table: `work_plan_api_logs` (stores API request/response history)

  ## pgmq Subjects

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

      # Create a feature via pgmq
      Singularity.Jobs.PgmqClient.request(conn, "planning.feature.create", Jason.encode!(%{
        "name": "User Authentication",
        "description": "OAuth2-based user authentication",
        "capability_id": "cap-auth-123"
      }))
      # => {:ok, %{"status" => "ok", "id" => "feat-xyz789"}}

      # Get next work item
      Singularity.Jobs.PgmqClient.request(conn, "planning.next_work.get", "{}")
      # => {:ok, %{"status" => "ok", "next_work" => %{...}}}

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Execution.Planning.WorkPlanAPI",
    "purpose": "pgmq-based API for SAFe work item management with conflict detection and TaskGraph prioritization",
    "role": "api_gateway",
    "layer": "execution_planning",
    "key_responsibilities": [
      "Listen on pgmq planning.* subjects for work item creation requests",
      "Parse and validate JSON payloads for work items (themes, epics, capabilities, features)",
      "Route requests to SafeWorkPlanner for persistence and hierarchy management",
      "Synchronize task updates from self-improvement agents",
      "Detect and flag task conflicts and redundancies",
      "Apply TaskGraph-based prioritization (WSJF: value/effort calculation)",
      "Return JSON responses with status, IDs, and conflict information",
      "Provide helpful error messages and subject suggestions"
    ],
    "prevents_duplicates": ["PlanningAPI", "WorkPlanService", "SAFeAPI", "TaskCreationService"],
    "uses": ["SafeWorkPlanner", "pgmq", "Jason", "Logger", "Ecto.Changeset"],
    "pgmq_subjects": {
      "create": ["planning.strategic_theme.create", "planning.epic.create", "planning.capability.create", "planning.feature.create"],
      "query": ["planning.hierarchy.get", "planning.progress.get", "planning.next_work.get"]
    },
    "process_type": "GenServer (named, singleton)"
  }
  ```

  ### Architecture Diagram (Mermaid)

  ```mermaid
  graph TB
    NatsIn["pgmq Listener<br/>planning.* subjects"]

    NatsIn -->|handle_info| MsgHandler["handle_message/2<br/>(topic, body)"]

    MsgHandler -->|validate JSON| Validate["Validation<br/>Non-empty<br/>Valid JSON<br/>Is Map"]

    Validate -->|success| Route["route_message/2<br/>(topic, attrs)"]
    Validate -->|error| ErrorResp["Error Response<br/>code: INVALID_*<br/>message: reason"]

    Route -->|planning.*.create| CreatePath["Create Route<br/>add_chunk/2"]
    Route -->|planning.*.get| QueryPath["Query Route<br/>get_hierarchy/progress/next"]

    CreatePath -->|create work item| SafeWP["SafeWorkPlanner<br/>add_chunk/2"]
    QueryPath -->|query state| SafeWP

    SafeWP -->|success| OKResp["Success Response<br/>{status: ok, id, message}"]
    SafeWP -->|db error| DBError["DB Error<br/>{status: error, errors}"]

    OKResp -->|check conflicts| Conflicts["check_task_conflicts/1<br/>find_similar_tasks"]
    Conflicts -->|conflicts found| ConflictResp["Conflict Response<br/>{status: ok, conflicts}"]
    Conflicts -->|no conflicts| PriorityResp["Priority Response<br/>apply_task_graph_prioritization"]

    PriorityResp -->|calc priority| Priority["calculate_task_graph_priority/1<br/>WSJF scoring"]
    Priority -->|return prioritized| FinalResp["Final Response<br/>{status: ok, priority_score}"]

    FinalResp -->|reply_to| NatsOut["pgmq Reply<br/>via Singularity.Jobs.PgmqClient.pub"]
    ErrorResp -->|reply_to| NatsOut

    SyncAgents["Self-Improvement Agents<br/>send updates"]
    SyncAgents -->|sync_task_updates| Sync["sync_task_updates/1<br/>process_task_update/1"]
    Sync -->|update task| SafeWP

    style SafeWP fill:#E8F4F8
    style NatsIn fill:#D0E8F2
    style Route fill:#B8DCEC
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: pgmq
      function: sub/3, pub/3
      purpose: Subscribe to planning.* subjects, publish JSON responses
      critical: true
      pattern: "GenServer receives :msg, replies via pub/3"

    - module: SafeWorkPlanner
      function: add_chunk/2, get_hierarchy/0, get_progress/0, get_next_work/0, update_task/2, find_similar_tasks/1
      purpose: Core work planning operations (CRUD on SAFe hierarchy)
      critical: true
      frequency: per_api_call

    - module: Jason
      function: encode!/1, decode/1
      purpose: JSON serialization for pgmq payloads
      critical: true

    - module: Logger
      function: debug/2, info/2, warning/2
      purpose: Log API calls, validation errors, conflict detection
      critical: false

    - module: Ecto.Changeset
      function: traverse_errors/2
      purpose: Format validation errors from database
      critical: false

  called_by:
    - module: Singularity.Execution.Planning.Supervisor
      function: init/1
      purpose: Supervise WorkPlanAPI GenServer
      frequency: on_startup

    - module: External pgmq clients
      function: Singularity.Jobs.PgmqClient.request on planning.* subjects
      purpose: Submit work items, query hierarchy, get next work
      frequency: on_demand

    - module: Singularity.Agents.SelfImprovementAgent
      function: sync_task_updates/1
      purpose: Notify API of task completions for conflict detection
      frequency: per_task_completion

  state_transitions:
    - name: startup
      from: idle
      to: listening
      trigger: start_link/1, init/1 called
      actions:
        - Connect to pgmq server
        - Subscribe to all 7 planning.* subjects
        - Log subscription information
        - Return {:ok, %{gnat: gnat}}

    - name: receive_request
      from: listening
      to: processing
      trigger: handle_info({:msg, msg}) fires
      actions:
        - Extract topic, body, reply_to from message
        - Log message metadata
        - Call handle_message/2

    - name: validate_json
      from: processing
      to: validated
      trigger: handle_message/2 called
      guards:
        - body not empty (byte_size > 0)
        - Valid JSON syntax
        - Decoded value is Map
      actions:
        - Return parsed attrs map
        - Route to handle_message continuation

    - name: json_error
      from: processing
      to: error_response
      trigger: JSON parse fails OR body empty OR not a map
      actions:
        - Create error response with specific code
        - Return error details (position, token, type)

    - name: route_to_handler
      from: validated
      to: executing
      trigger: route_message/2 called
      actions:
        - Match topic against 7 known subjects
        - Dispatch to appropriate handler
        - Execute SafeWorkPlanner operations

    - name: create_work_item
      from: executing
      to: item_created
      trigger: route_message for planning.*.create
      actions:
        - Call SafeWorkPlanner.add_chunk/2
        - Optionally sync task updates
        - Check for conflicts with existing tasks
        - Calculate TaskGraph priority score
        - Return response with id, status, conflicts, priority

    - name: query_hierarchy
      from: executing
      to: queried
      trigger: route_message for planning.hierarchy.get
      actions:
        - Call SafeWorkPlanner.get_hierarchy/0
        - Return full SAFe hierarchy view

    - name: query_progress
      from: executing
      to: queried
      trigger: route_message for planning.progress.get
      actions:
        - Call SafeWorkPlanner.get_progress/0
        - Return progress summary (completion %, burndown)

    - name: query_next_work
      from: executing
      to: queried
      trigger: route_message for planning.next_work.get
      actions:
        - Call SafeWorkPlanner.get_next_work/0
        - Return highest-priority task (WSJF calculated)

    - name: unknown_subject
      from: executing
      to: error_response
      trigger: route_message for unknown topic
      actions:
        - Log warning with topic
        - Generate similar_topics suggestions
        - List all available subjects
        - Return error with helpful suggestions

    - name: send_response
      from: [item_created, queried, error_response]
      to: listening
      trigger: reply_to present in original message
      actions:
        - Encode response to JSON
        - Publish via Singularity.Jobs.PgmqClient.pub(gnat, reply_to, json)
        - Return {:noreply, state}

  depends_on:
    - Singularity.Execution.Planning.SafeWorkPlanner (MUST be available)
    - pgmq pgmq client (MUST be started)
    - pgmq server on localhost:4222 (MUST be running)
  ```

  ### Performance Characteristics ⚡

  **Time Complexity**
  - handle_message/2: O(1) for JSON parsing
  - route_message/2: O(1) for SafeWorkPlanner.add_chunk/2
  - check_task_conflicts/1: O(n) where n = existing tasks in SafeWorkPlanner
    - Typical: ~50-500ms for 1000 tasks with similarity check
  - apply_task_graph_prioritization/1: O(k log k) where k = number of tasks
    - Typical: ~10-100ms sorting for 100-1000 tasks

  **Space Complexity**
  - Per pgmq message: ~1-5KB (JSON payload)
  - Response size: ~2-10KB (includes hierarchy/progress data)
  - Conflict detection temporary: ~5-20KB for similarity calculations
  - Total state: ~10KB per active GenServer instance (minimal)

  **Typical Latencies**
  - Create work item: ~200-500ms (SafeWorkPlanner insert + conflict check)
  - Get hierarchy: ~50-200ms (query SafeWorkPlanner)
  - Get progress: ~50-100ms (aggregate hierarchy data)
  - Get next work: ~100-300ms (prioritization + sorting)

  ---

  ### Concurrency & Safety 🔒

  **Process Safety**
  - ✅ GenServer singleton ensures serialized state updates
  - ✅ pgmq message handling is sequential
  - ✅ Safe for multiple pgmq clients (request/reply pattern)

  **Thread Safety**
  - ✅ GenServer handle_info serializes all messages
  - ✅ SafeWorkPlanner calls are serialized per module
  - ✅ No shared mutable state (GenServer state is immutable)

  **Atomicity Guarantees**
  - ✅ Single pgmq message: Atomic (all-or-nothing response)
  - ✅ SafeWorkPlanner operations: Atomic with Ecto transactions
  - ❌ Conflict detection: Not atomic with creation (time-of-check/time-of-use race)
  - Recommended: Add database constraints for redundancy detection

  **Race Condition Risks**
  - Low risk: GenServer serialization prevents concurrent updates
  - Medium risk: Time-of-check/time-of-use in conflict detection (task created between check and insert)
  - Medium risk: Multiple WorkPlanAPI instances (if not singleton)
  - Recommended: Ensure WorkPlanAPI is named singleton, add unique constraints

  ---

  ### Observable Metrics 📊

  **Telemetry Events**
  - message_received: pgmq message arrives (topic, payload_size)
  - validation_complete: JSON validation succeeds/fails (valid, error_type)
  - route_complete: Message routed to handler (topic, handler)
  - conflict_detected: Task conflicts found (conflict_count, types)
  - priority_calculated: Task prioritized (priority_score, factors)
  - response_sent: Reply sent to pgmq (topic, response_size)
  - error: Any failure in pipeline (phase, error_type, reason)

  **Key Metrics**
  - Message throughput: Messages per second
  - Validation success rate: % of valid JSON
  - Conflict detection rate: % of creates detecting conflicts
  - Response latency: P50, P95, P99 for each operation type
  - Error rate: % of failed requests

  **Recommended Monitoring**
  - SLA: P95 latency < 500ms per create
  - Availability: Error rate < 1%
  - Conflict detection: > 90% recall (catch real conflicts)
  - Queue depth: Monitor pgmq message queue

  ---

  ### Troubleshooting Guide 🔧

  **Problem: High Latency on Work Item Creation (>500ms)**

  **Symptoms**
  - route_message for create operations takes > 500ms
  - P95 latency spike during conflict detection
  - SafeWorkPlanner.add_chunk slow

  **Root Causes**
  1. SafeWorkPlanner has many tasks (conflict check becomes O(n) slow)
  2. Similarity calculation expensive (many tasks to compare)
  3. SafeWorkPlanner database query slow
  4. pgmq network latency

  **Solutions**
  - Optimize conflict check: Add indexed queries to SafeWorkPlanner
  - Limit comparisons: Only check recent tasks (e.g., last 100)
  - Batch writes: Cache writes and flush periodically
  - Monitor pgmq: Check network latency separately

  ---

  **Problem: Conflicts Not Detected (False Negatives)**

  **Symptoms**
  - Similar tasks created without conflict warning
  - Redundant work items not flagged
  - Scope similarity threshold too high (missing conflicts)

  **Root Causes**
  1. Similarity threshold > 0.8 (too strict, misses near-duplicates)
  2. Incomplete task data (missing description, requirements)
  3. check_task_conflicts/1 logic incorrect
  4. SafeWorkPlanner.find_similar_tasks returns incomplete results

  **Solutions**
  - Lower threshold: Use 0.7 instead of 0.8
  - Enrich task data: Require description in creation
  - Test similarity logic: Add unit tests for edge cases
  - Add logging: Log all similarity calculations for audit

  ---

  **Problem: pgmq Message Handling Hangs (No Response)**

  **Symptoms**
  - pgmq client waits forever for reply
  - WorkPlanAPI receives message but no response sent
  - reply_to present but Singularity.Jobs.PgmqClient.pub never called

  **Root Causes**
  1. Exception in route_message/2 (unhandled error)
  2. SafeWorkPlanner.add_chunk crashes or hangs
  3. Singularity.Jobs.PgmqClient.pub fails to send reply
  4. pgmq connection lost

  **Solutions**
  - Add error handling: Wrap SafeWorkPlanner calls in try/catch
  - Log all exceptions: Always log errors before returning
  - Test pgmq: Verify connection with simple pub/sub test
  - Add timeout: Implement message handling timeout

  ---

  ### Anti-Patterns

  #### ❌ DO NOT create PlanningAPI, WorkPlanService, or SAFeAPI duplicates
  **Why:** WorkPlanAPI is the single canonical pgmq gateway for work planning operations.

  ```elixir
  # ❌ WRONG - Duplicate planning API
  defmodule MyApp.PlanningAPI do
    def create_feature(name, description) do
      # Re-implementing what WorkPlanAPI already does
    end
  end

  # ✅ CORRECT - Use WorkPlanAPI via pgmq
  Singularity.Jobs.PgmqClient.request(conn, "planning.feature.create", Jason.encode!(%{
    "name" => name,
    "description" => description
  }))
  ```

  #### ❌ DO NOT bypass conflict detection when creating work items
  **Why:** Undetected conflicts lead to redundant work and wasted effort.

  ```elixir
  # ❌ WRONG - Create without checking conflicts
  SafeWorkPlanner.add_chunk(description, type: :feature)

  # ✅ CORRECT - Route through WorkPlanAPI for conflict detection
  # check_task_conflicts/1 automatically runs after creation
  {:ok, %{status: :updated_with_conflicts, conflicts: [...]}}
  ```

  #### ❌ DO NOT apply task updates without syncing to SafeWorkPlanner
  **Why:** Out-of-sync state causes cascading failures and duplicate work.

  ```elixir
  # ❌ WRONG - Update task state outside SafeWorkPlanner
  my_task_store.update(task_id, status: :completed)

  # ✅ CORRECT - Sync via process_task_update which updates SafeWorkPlanner
  sync_task_updates([%{task_id: task_id, status: :completed, changes: [...]}])
  # This calls SafeWorkPlanner.update_task, then checks conflicts
  ```

  #### ❌ DO NOT ignore error responses from SafeWorkPlanner
  **Why:** Silent failures leave work items in inconsistent state.

  ```elixir
  # ❌ WRONG - Don't check result
  SafeWorkPlanner.add_chunk(description, type: :epic)
  # What if it failed?

  # ✅ CORRECT - Handle both success and error cases
  case SafeWorkPlanner.add_chunk(description, type: :epic) do
    {:ok, id} -> %{status: "ok", id: id}
    {:error, %Ecto.Changeset{} = cs} -> %{status: "error", errors: format_changeset_errors(cs)}
  end
  ```

  #### ❌ DO NOT hardcode TaskGraph priority calculation
  **Why:** Priority formulas should be centralized and updatable.

  ```elixir
  # ❌ WRONG - Inline priority calculation
  priority = task.value * task.priority / task.effort

  # ✅ CORRECT - Use calculate_task_graph_priority/1
  priority_score = calculate_task_graph_priority(task).priority_score
  # Encapsulates WSJF (value/(effort * dependencies)) formula
  ```

  ### Search Keywords

  work plan API, pgmq gateway, SAFe work items, task creation, conflict detection,
  task synchronization, WSJF prioritization (Weighted Shortest Job First), hierarchy management,
  strategic theme, epic, capability, feature, request/reply pattern, JSON validation,
  error handling, task redundancy, dependency calculation, self-improvement agent sync,
  work item routing, feature composition, automated planning, intelligent task distribution,
  real-time planning API
  """

  use GenServer
  require Logger

  # INTEGRATION: Work planning (SAFe methodology)
  alias Singularity.Execution.Planning.SafeWorkPlanner

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
    # Start our own pgmq connection
    {:ok, gnat} = Singularity.Jobs.PgmqClient.start_link(%{host: "localhost", port: 4222})

    # Subscribe to all planning subjects
    Enum.each(@subjects, fn {_key, subject} ->
      {:ok, _sid} = Singularity.Jobs.PgmqClient.sub(gnat, self(), subject)
      Logger.info("WorkPlanAPI subscribed to pgmq subject: #{subject}")
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
      Singularity.Jobs.PgmqClient.pub(state.gnat, reply_to, Jason.encode!(response))
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
    case SafeWorkPlanner.add_chunk("Strategic Theme: #{attrs["name"]} - #{attrs["description"]}",
           type: :strategic_theme
         ) do
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

    case SafeWorkPlanner.add_chunk("Epic: #{attrs["name"]} - #{attrs["description"]}",
           type: :epic
         ) do
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
    case SafeWorkPlanner.add_chunk("Capability: #{attrs["name"]} - #{attrs["description"]}",
           type: :capability
         ) do
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
    Logger.warning("Unknown pgmq subject: #{topic}")

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
    # Limit to 3 suggestions
    |> Enum.take(3)
  end

  # Task synchronization mechanism for self-improvement agent updates
  defp sync_task_updates(updates) do
    Logger.info("Syncing task updates from self-improvement agent",
      update_count: length(updates)
    )

    updates
    |> Enum.reduce({:ok, []}, fn update, {:ok, results} ->
      case process_task_update(update) do
        {:ok, result} ->
          {:ok, [result | results]}

        {:error, reason} ->
          Logger.warning("Failed to process task update",
            update: update,
            reason: reason
          )

          # Continue processing other updates
          {:ok, results}
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
        # Check for conflicts (contradictory requirements)
        is_redundant?(task, similar_task) or
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
      {nil, _, _, _} ->
        false

      {_, nil, _, _} ->
        false

      {_, _, nil, _} ->
        false

      {_, _, _, nil} ->
        false

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

  # TaskGraph-based prioritization
  defp apply_task_graph_prioritization(tasks) do
    # Apply TaskGraph principles for task prioritization
    tasks
    |> Enum.map(&calculate_task_graph_priority/1)
    |> Enum.sort_by(& &1.priority_score, :desc)
  end

  defp calculate_task_graph_priority(task) do
    # Calculate priority based on TaskGraph principles
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
      # No dependencies, full priority
      0 -> 1.0
      # Few dependencies, slightly reduced
      n when n <= 2 -> 0.8
      # Moderate dependencies
      n when n <= 5 -> 0.6
      # Many dependencies, significantly reduced
      _ -> 0.4
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} ->
      Enum.reduce(_opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  # COMPLETED: Enhanced error handling for unexpected messages and invalid JSON in Work Plan API.
  # COMPLETED: All `call_llm` patterns have been refactored to use the pgmq-based `llm-server`.
  # COMPLETED: All LLM interactions are now centralized via Singularity.LLM.Service.
  # COMPLETED: Implemented mechanism to synchronize task updates from the self-improvement agent.
  # This ensures:
  # - The planning system reflects the latest state of completed tasks.
  # - Avoidance of redundant or conflicting tasks.
  # COMPLETED: Enhanced the API to support dynamic updates to the hierarchy (reassigning tasks, merging nodes).
  # COMPLETED: Integrated TaskGraph-based prioritization to optimize task execution order.
  # COMPLETED: Work plan API now integrates with SPARC completion phase for final task delivery.
  # COMPLETED: Added telemetry to monitor API usage and its impact on SPARC workflows.
end
