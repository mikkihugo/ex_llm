defmodule Singularity.Execution.SafeWorkPlanner do
  @moduledoc """
  SAFe 6.0 Essential Work Planner with intelligent vision chunk processing and WSJF prioritization.

  Provides comprehensive work planning using SAFe 6.0 methodology with autonomous
  vision chunk analysis, intelligent classification, and WSJF-based prioritization
  for strategic themes, epics, capabilities, and features.

  ## Quick Start

  ```elixir
  # Add vision chunk (auto-classifies level)
  {:ok, analysis} = SafeWorkPlanner.add_chunk("Build world-class observability platform (3 BLOC)")

  # Get next work item (WSJF prioritized)
  next_work = SafeWorkPlanner.get_next_work()
  # => %{id: "feat-abc123", name: "Distributed Tracing", wsjf_score: 8.5}

  # Get full hierarchy
  hierarchy = SafeWorkPlanner.get_hierarchy()
  ```

  ## Public API

  - `add_chunk(text, opts)` - Add vision chunk with auto-classification
  - `get_next_work/0` - Get highest WSJF priority work item
  - `get_hierarchy/0` - Get full SAFe hierarchy tree
  - `get_progress/0` - Get completion statistics
  - `complete_item(item_id, level)` - Mark item as done
  - `get_work_plan(opts)` - Get work plan for specified level and status
  - `prioritize_tasks(tasks, criteria)` - Prioritize tasks based on criteria
  - `analyze_dependencies(tasks, opts)` - Analyze dependencies between tasks

  ## SAFe Hierarchy

  Strategic Themes (3-5 year vision areas)
    └─ Epics (6-12 month initiatives - Business or Enabler)
        └─ Capabilities (3-6 month cross-team features)
            └─ Features (1-3 month team deliverables)
                └─ TaskGraph breakdown → Stories → Tasks

  ## Integration Points

  - `Singularity.CodeStore` - Vision persistence
  - `Singularity.Execution.Autonomy.RuleEngine` - Epic/feature validation
  - `Singularity.LLM.Service` - Vision chunk classification
  - `Singularity.EmbeddingEngine` - Semantic parent finding
  - `Singularity.Conversation.WebChat` - Notifications
  - PostgreSQL table: `safe_work_items`

  ## Error Handling

  Returns `{:ok, analysis} | {:needs_approval, result} | {:escalated, result}`:
  - `:ok` - High confidence, item added automatically
  - `:needs_approval` - Medium confidence, requires human approval
  - `:escalated` - Low confidence, human decision required

  ---

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Execution.Planning.SafeWorkPlanner",
    "purpose": "SAFe 6.0 work planning with autonomous vision chunk classification and WSJF prioritization",
    "role": "planner",
    "layer": "domain_services",
    "alternatives": {
      "Manual SAFe planning": "Spreadsheets and docs - use SafeWorkPlanner for automated planning",
      "Generic task manager": "Flat task lists - use SafeWorkPlanner for SAFe hierarchy",
      "Jira/VersionOne": "Enterprise tools - SafeWorkPlanner is internal AI-powered alternative"
    },
    "disambiguation": {
      "vs_task_graph": "SafeWorkPlanner handles SAFe strategic planning; TaskGraph executes individual features",
      "vs_methodology_executor": "SafeWorkPlanner creates work items; MethodologyExecutor runs workflows",
      "vs_jira": "SafeWorkPlanner is AI-powered with autonomous classification; Jira requires manual input"
    }
  }
  ```

  ### Architecture (Mermaid)

  ```mermaid
  graph TB
      Vision[Vision Chunk Text]
      Planner[SafeWorkPlanner<br/>GenServer]
      LLM[LLM.Service]
      Embedding[EmbeddingEngine]
      RuleEngine[RuleEngine]
      Store[CodeStore]

      Vision -->|1. add_chunk| Planner
      Planner -->|2. classify| LLM
      LLM -->|3. analysis| Planner
      Planner -->|4. find parent| Embedding
      Embedding -->|5. parent_id| Planner
      Planner -->|6. validate| RuleEngine
      RuleEngine -->|7. confidence| Decision{Confidence?}

      Decision -->|autonomous| Planner
      Decision -->|collaborative| Approval[Needs Approval]
      Decision -->|escalated| Human[Human Decision]

      Planner -->|8. persist| Store
      Store -->|9. save| DB[(CodeStore JSON)]

      Planner -->|10. return| Result[Analysis Result]

      style Planner fill:#90EE90
      style Decision fill:#FFD700
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Singularity.LLM.Service
      function: call/3
      purpose: Classify vision chunks and extract metadata
      critical: true

    - module: Singularity.EmbeddingEngine
      function: embed/1
      purpose: Generate embeddings for semantic parent finding
      critical: false

    - module: Singularity.Execution.Autonomy.RuleEngine
      function: "[validate_epic_wsjf|validate_feature_readiness]/1"
      purpose: Validate work items with confidence scoring
      critical: true

    - module: Singularity.CodeStore
      function: "[save_vision|load_vision]/0"
      purpose: Persist SAFe hierarchy to disk
      critical: true

    - module: Singularity.Conversation.WebChat
      function: notify/1
      purpose: Send notifications for approvals and escalations
      critical: false

  called_by:
    - module: Singularity.CLI.Vision
      purpose: CLI commands for vision management
      frequency: medium

    - module: Singularity.Jobs.PgmqClient.PlanningRouter
      purpose: pgmq-based vision chunk submission
      frequency: low

    - module: Singularity.Agents.PlanningAgent
      purpose: Autonomous vision chunk processing
      frequency: medium

  depends_on:
    - CodeStore (MUST exist for persistence)
    - RuleEngine (MUST be started for validation)
    - LLM.Service (MUST be available for classification)
    - EmbeddingEngine (optional - graceful degradation)

  supervision:
    supervised: true
    reason: "GenServer maintaining SAFe hierarchy state with persistence"
  ```

  ### Anti-Patterns

  #### ❌ DO NOT bypass RuleEngine validation
  **Why:** RuleEngine provides confidence-based routing for autonomous/collaborative/escalated decisions.
  **Use instead:**
  ```elixir
  # ❌ WRONG - skip validation
  add_epic_directly(epic)

  # ✅ CORRECT - use add_chunk with validation
  SafeWorkPlanner.add_chunk(epic_text)
  ```

  #### ❌ DO NOT hardcode WSJF calculations
  **Why:** SafeWorkPlanner calculates WSJF from stored business_value, time_criticality, risk_reduction, job_size.
  **Use instead:** Let SafeWorkPlanner manage WSJF scoring.

  #### ❌ DO NOT create separate SAFe planners
  **Why:** SafeWorkPlanner already provides complete SAFe 6.0 hierarchy!
  **Use instead:** Extend SafeWorkPlanner with new capabilities.

  ### Search Keywords

  safe work planner, safe 6.0, epic management, wsjf prioritization,
  strategic themes, capabilities, features, work hierarchy, autonomous planning,
  vision chunk processing, llm classification, rule engine validation
  """

  use GenServer
  require Logger

  # INTEGRATION: Vision persistence and notifications
  alias Singularity.{CodeStore, Conversation}

  # INTEGRATION: Rule validation (WSJF and feature readiness)
  alias Singularity.Execution.Autonomy.RuleEngine, as: RuleEngine

  defstruct [
    # %{id => theme}
    :strategic_themes,
    # %{id => epic}
    :epics,
    # %{id => capability}
    :capabilities,
    # %{id => feature}
    :features,
    # Graph of dependencies
    :relationships,
    :approved_by,
    :created_at,
    :last_updated
  ]

  @type strategic_theme :: %{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          target_bloc: float(),
          priority: integer(),
          epic_ids: [String.t()],
          created_at: DateTime.t()
        }

  @type epic :: %{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          type: :business | :enabler,
          theme_id: String.t(),
          wsjf_score: float(),
          business_value: integer(),
          time_criticality: integer(),
          risk_reduction: integer(),
          job_size: integer(),
          capability_ids: [String.t()],
          status: :ideation | :analysis | :implementation | :done,
          created_at: DateTime.t()
        }

  @type capability :: %{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          epic_id: String.t(),
          wsjf_score: float(),
          feature_ids: [String.t()],
          depends_on: [String.t()],
          status: :backlog | :analyzing | :implementing | :validating | :done,
          created_at: DateTime.t()
        }

  @type feature :: %{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          capability_id: String.t(),
          task_graph_id: String.t() | nil,
          acceptance_criteria: [String.t()],
          status: :backlog | :in_progress | :done,
          created_at: DateTime.t()
        }

  ## Public API

  def start_link(opts) do
    GenServer.start_link(
      __MODULE__,
      %__MODULE__{
        strategic_themes: %{},
        epics: %{},
        capabilities: %{},
        features: %{},
        relationships: %{},
        approved_by: nil,
        created_at: DateTime.utc_now(),
        last_updated: DateTime.utc_now()
      },
      name: __MODULE__
    )
  end

  @doc """
  Submit a vision chunk that updates any level of the hierarchy.

  The system will analyze the chunk and:
  1. Determine which level it belongs to (theme/epic/capability/feature)
  2. Find relationships to existing items
  3. Update or create items accordingly
  4. Recalculate WSJF priorities

  ## Examples

      # Add a new strategic theme
      add_chunk("Build world-class observability platform (3 BLOC)")

      # Add an epic under existing theme
      add_chunk("Implement distributed tracing across all microservices", relates_to: "observability")

      # Add capability
      add_chunk("Trace collection from Kubernetes pods", relates_to: "distributed-tracing")

      # Update existing epic
      add_chunk("Add OpenTelemetry support to distributed tracing", updates: "epic-dt-123")
  """
  def add_chunk(text, opts \\ []) do
    GenServer.call(__MODULE__, {:add_chunk, text, opts}, :infinity)
  end

  @doc "Get next work item based on WSJF prioritization"
  def get_next_work do
    GenServer.call(__MODULE__, :get_next_work)
  end

  @doc "Get full hierarchy view"
  def get_hierarchy do
    GenServer.call(__MODULE__, :get_hierarchy)
  end

  @doc "Get progress summary"
  def get_progress do
    GenServer.call(__MODULE__, :get_progress)
  end

  @doc "Mark item as complete"
  def complete_item(item_id, level) do
    GenServer.call(__MODULE__, {:complete_item, item_id, level})
  end

  @doc """
  Get work plan for specified level and status.

  ## Parameters
  - `opts` - Options map with :level and :status keys

  ## Returns
  - Work plan structure
  """
  def get_work_plan(opts) do
    level = Keyword.get(opts, :level, :all)
    status = Keyword.get(opts, :status, :all)

    try do
      hierarchy = get_hierarchy()

      work_plan = %{
        strategic_themes: filter_by_level_and_status(hierarchy.strategic_themes, level, status),
        epics: filter_by_level_and_status(hierarchy.epics, level, status),
        capabilities: filter_by_level_and_status(hierarchy.capabilities, level, status),
        features: filter_by_level_and_status(hierarchy.features, level, status)
      }

      {:ok, work_plan}
    rescue
      e ->
        Logger.error("Error getting work plan", error: inspect(e), opts: opts)
        {:error, :work_plan_retrieval_failed}
    end
  end

  @doc """
  Prioritize tasks based on criteria.

  ## Parameters
  - `tasks` - List of tasks to prioritize
  - `criteria` - Prioritization criteria

  ## Returns
  - Prioritized task list
  """
  def prioritize_tasks(tasks, criteria) when is_list(tasks) do
    try do
      # Apply WSJF scoring if not already present
      scored_tasks =
        Enum.map(tasks, fn task ->
          wsjf_score = calculate_wsjf_score(task, criteria)
          Map.put(task, :wsjf_score, wsjf_score)
        end)

      # Sort by WSJF score descending
      prioritized = Enum.sort_by(scored_tasks, & &1.wsjf_score, :desc)

      {:ok, prioritized}
    rescue
      e ->
        Logger.error("Error prioritizing tasks", error: inspect(e), task_count: length(tasks))
        {:error, :prioritization_failed}
    end
  end

  @doc """
  Analyze dependencies between tasks.

  ## Parameters
  - `tasks` - List of tasks to analyze
  - `opts` - Options including :include_external

  ## Returns
  - Dependency analysis
  """
  def analyze_dependencies(tasks, opts \\ []) when is_list(tasks) do
    include_external = Keyword.get(opts, :include_external, true)

    try do
      # Build dependency graph
      {dependencies, critical_path} = build_dependency_graph(tasks, include_external)

      # Identify risk factors
      risk_factors = identify_risk_factors(tasks, dependencies)

      # Generate recommendations
      recommendations = generate_dependency_recommendations(tasks, dependencies, critical_path)

      analysis = %{
        dependencies: dependencies,
        critical_path: critical_path,
        risk_factors: risk_factors,
        recommendations: recommendations
      }

      {:ok, analysis}
    rescue
      e ->
        Logger.error("Error analyzing dependencies", error: inspect(e), task_count: length(tasks))
        {:error, :dependency_analysis_failed}
    end
  end

  ## GenServer Callbacks

  @impl true
  def init(state) do
    # Load persisted SAFe vision if exists
    case CodeStore.load_vision() do
      nil ->
        {:ok, state}

      %{"safe_version" => "6.0"} = persisted ->
        {:ok, deserialize_state(persisted)}

      _old_format ->
        Logger.warning("Old vision format detected - starting fresh")
        {:ok, state}
    end
  end

  @impl true
  def handle_call({:add_chunk, text, opts}, _from, state) do
    approved_by = Keyword.get(opts, :approved_by, "system")
    updates_id = Keyword.get(opts, :updates)
    relates_to = Keyword.get(opts, :relates_to)

    # Analyze chunk using LLM
    analysis = analyze_chunk(state, text, relates_to, updates_id)

    Logger.info("Vision chunk analyzed",
      level: analysis.level,
      action: analysis.action,
      relates_to: analysis.relates_to
    )

    # Validate using RuleEngine if it's an epic or feature
    validation_result =
      case {analysis.action, analysis.level} do
        {:create, :epic} ->
          epic_stub = build_epic_stub(analysis)
          RuleEngine.validate_epic_wsjf(epic_stub)

        {:create, :feature} ->
          feature_stub = build_feature_stub(analysis)
          RuleEngine.validate_feature_readiness(feature_stub)

        _ ->
          {:autonomous, %{confidence: 1.0}}
      end

    # Check confidence threshold
    case validation_result do
      {:autonomous, _result} ->
        # High confidence - proceed
        Logger.info("RuleEngine approved autonomously",
          level: analysis.level,
          confidence: validation_result |> elem(1) |> Map.get(:confidence)
        )

        new_state = apply_chunk_changes(state, analysis, approved_by, updates_id)
        {:reply, {:ok, analysis}, new_state}

      {:collaborative, result} ->
        # Medium confidence - ask for approval
        Logger.warning("RuleEngine requires collaboration",
          level: analysis.level,
          confidence: result.confidence,
          reasoning: result.reasoning
        )

        notify_approval_needed(analysis, result)
        {:reply, {:needs_approval, result}, state}

      {:escalated, result} ->
        # Low confidence - escalate
        Logger.error("RuleEngine escalated decision",
          level: analysis.level,
          confidence: result.confidence,
          reasoning: result.reasoning
        )

        notify_escalation(analysis, result)
        {:reply, {:escalated, result}, state}
    end
  end

  @impl true
  def handle_call(:get_next_work, _from, state) do
    # Get highest WSJF feature that's ready to work on
    next_work =
      state.features
      |> Map.values()
      |> Enum.filter(&(&1.status == :backlog))
      |> Enum.filter(&dependencies_met?(state, &1))
      |> Enum.sort_by(&get_wsjf_score(state, &1), :desc)
      |> List.first()

    {:reply, next_work, state}
  end

  @impl true
  def handle_call(:get_hierarchy, _from, state) do
    hierarchy = build_hierarchy_tree(state)
    {:reply, hierarchy, state}
  end

  @impl true
  def handle_call(:get_progress, _from, state) do
    progress = %{
      themes: count_by_status(state.strategic_themes),
      epics: count_by_status(state.epics),
      capabilities: count_by_status(state.capabilities),
      features: count_by_status(state.features),
      total_bloc_target: calculate_total_bloc(state),
      completion_percentage: calculate_completion(state)
    }

    {:reply, progress, state}
  end

  @impl true
  def handle_call({:complete_item, item_id, level}, _from, state) do
    new_state = mark_complete(state, item_id, level)
    CodeStore.save_vision(serialize_state(new_state))
    {:reply, :ok, new_state}
  end

  ## Analysis & Intelligence

  defp analyze_chunk(state, text, relates_to, updates_id) do
    # Use LLM for intelligent work item classification
    existing_items = format_existing_items(state)

    prompt = """
    Analyze this vision chunk and determine how it fits into SAFe 6.0 Essential hierarchy.

    Vision chunk:
    #{text}

    #{if relates_to, do: "User says it relates to: #{relates_to}", else: ""}
    #{if updates_id, do: "User says it updates: #{updates_id}", else: ""}

    Existing hierarchy:
    #{existing_items}

    Determine:
    1. Level: strategic_theme | epic | capability | feature
    2. Action: create | update
    3. If epic, type: business | enabler
    4. Relationships: parent_id, depends_on (IDs)
    5. WSJF inputs: business_value (1-10), time_criticality (1-10), risk_reduction (1-10), job_size (1-20)
    6. Extracted metadata: name, description, acceptance_criteria (for features)

    Return JSON with this structure.
    """

    case Singularity.LLM.Service.call(:simple, [%{role: "user", content: prompt}],
           task_type: "classifier",
           capabilities: [:analysis, :reasoning]
         ) do
      {:ok, %{text: response}} ->
        case Jason.decode(response) do
          {:ok, %{"level" => level_str, "confidence" => confidence, "reasoning" => reasoning}} ->
            level = String.to_atom(level_str)
            Logger.info("Classified work item as #{level} (confidence: #{confidence})")
            {:ok, %{level: level, confidence: confidence, reasoning: reasoning}}

          {:error, _} ->
            Logger.warning("Failed to parse LLM classification response: #{response}")
            # Fallback to heuristic classification
            fallback_classification(text)
        end

      {:error, reason} ->
        Logger.error("LLM classification failed: #{inspect(reason)}")
        # Fallback to heuristic classification
        fallback_classification(text)
    end
  end

  defp fallback_classification(text) do
    # Heuristic based on keywords as fallback
    level =
      cond do
        String.contains?(text, ~r/(theme|strategic|BLOC)/i) -> :strategic_theme
        String.contains?(text, ~r/(epic|initiative|enabler)/i) -> :epic
        String.contains?(text, ~r/(capability|cross-team)/i) -> :capability
        true -> :feature
      end

    {:ok, %{level: level, confidence: 0.3, reasoning: "Heuristic fallback classification"}}
  end

  defp guess_epic_type(text) do
    if String.contains?(text, ~r/(infrastructure|platform|technical|enabler)/i) do
      :enabler
    else
      :business
    end
  end

  defp extract_name(text) do
    # Take first sentence or first 60 chars
    text
    |> String.split(".")
    |> List.first()
    |> String.slice(0..60)
    |> String.trim()
  end

  defp extract_criteria(text) do
    # Look for bullet points or numbered lists
    Regex.scan(~r/[-•*]\s*(.+)/, text)
    |> Enum.map(fn [_, criterion] -> String.trim(criterion) end)
  end

  defp find_semantic_parent(state, text, level) do
    try do
      # Use embeddings to find most related parent
      case Singularity.EmbeddingEngine.embed(text) do
        {:ok, embedding} ->
          # Find most similar existing items at the appropriate level
          parent_level = get_parent_level(level)

          candidates =
            state.work_items
            |> Enum.filter(fn {_id, item} -> item.level == parent_level end)
            |> Enum.map(fn {id, item} ->
              case Singularity.EmbeddingEngine.embed(item.description) do
                {:ok, item_embedding} ->
                  similarity = calculate_cosine_similarity(embedding, item_embedding)
                  {id, item, similarity}

                {:error, _} ->
                  nil
              end
            end)
            |> Enum.reject(&is_nil/1)
            |> Enum.sort_by(fn {_id, _item, similarity} -> similarity end, :desc)

          case List.first(candidates) do
            {id, _item, similarity} when similarity > 0.7 ->
              Logger.info("Found semantic parent #{id} with similarity #{similarity}")
              id

            _ ->
              Logger.info("No suitable semantic parent found")
              nil
          end

        {:error, reason} ->
          Logger.warning("Embedding generation failed: #{inspect(reason)}")
          nil
      end
    rescue
      error ->
        Logger.error("Semantic parent finding error: #{inspect(error)}")
        nil
    end
  end

  defp get_parent_level(level) do
    case level do
      :feature -> :capability
      :capability -> :epic
      :epic -> :strategic_theme
      _ -> nil
    end
  end

  defp calculate_cosine_similarity(vec1, vec2) when length(vec1) == length(vec2) do
    dot_product =
      Enum.zip(vec1, vec2)
      |> Enum.map(fn {a, b} -> a * b end)
      |> Enum.sum()

    magnitude1 = :math.sqrt(Enum.sum(Enum.map(vec1, &(&1 * &1))))
    magnitude2 = :math.sqrt(Enum.sum(Enum.map(vec2, &(&1 * &1))))

    if magnitude1 > 0 and magnitude2 > 0 do
      dot_product / (magnitude1 * magnitude2)
    else
      0.0
    end
  end

  defp calculate_cosine_similarity(_, _), do: 0.0

  defp format_existing_items(state) do
    """
    Themes: #{state.strategic_themes |> Map.values() |> Enum.map(& &1.name) |> Enum.join(", ")}
    Epics: #{state.epics |> Map.values() |> Enum.map(& &1.name) |> Enum.join(", ")}
    Capabilities: #{state.capabilities |> Map.values() |> Enum.map(& &1.name) |> Enum.join(", ")}
    """
  end

  ## Helper Functions

  defp filter_by_level_and_status(items, level, status) do
    Enum.filter(items, fn {_, item} ->
      level_match = level == :all || item.level == level
      status_match = status == :all || item.status == status
      level_match && status_match
    end)
    |> Enum.into(%{})
  end

  defp calculate_wsjf_score(task, criteria) do
    # WSJF = (Business Value + Time Criticality) / (Job Size + Risk Reduction)
    business_value = Map.get(task, :business_value, Map.get(criteria, :default_business_value, 5))

    time_criticality =
      Map.get(task, :time_criticality, Map.get(criteria, :default_time_criticality, 3))

    job_size = Map.get(task, :job_size, Map.get(criteria, :default_job_size, 5))
    risk_reduction = Map.get(task, :risk_reduction, Map.get(criteria, :default_risk_reduction, 2))

    numerator = business_value + time_criticality
    denominator = job_size + risk_reduction

    if denominator > 0 do
      numerator / denominator
    else
      0.0
    end
  end

  defp build_dependency_graph(tasks, include_external) do
    # Build a simple dependency graph
    dependencies =
      Enum.reduce(tasks, %{}, fn task, acc ->
        task_deps = Map.get(task, :dependencies, [])
        Map.put(acc, task.id, task_deps)
      end)

    # Calculate critical path (simplified)
    critical_path = calculate_critical_path(dependencies)

    {dependencies, critical_path}
  end

  defp calculate_critical_path(dependencies) do
    # Simplified critical path calculation
    # In a real implementation, this would use proper graph algorithms
    # For now, return the longest chain
    case Enum.max_by(dependencies, fn {_, deps} -> length(deps) end, fn -> nil end) do
      nil -> []
      {task_id, _} -> [task_id]
    end
  end

  defp identify_risk_factors(tasks, dependencies) do
    # Identify potential risk factors in the task dependencies
    risks = []

    # Check for circular dependencies
    if has_circular_dependencies?(dependencies) do
      risks = ["Circular dependencies detected" | risks]
    end

    # Check for tasks with too many dependencies
    high_dependency_tasks = Enum.filter(dependencies, fn {_, deps} -> length(deps) > 5 end)

    if Enum.any?(high_dependency_tasks) do
      risks = ["Tasks with high dependency count (>5)" | risks]
    end

    # Check for orphaned tasks
    all_task_ids = Map.keys(dependencies)
    referenced_tasks = dependencies |> Map.values() |> List.flatten() |> Enum.uniq()
    orphaned = all_task_ids -- referenced_tasks

    if Enum.any?(orphaned) do
      risks = ["Orphaned tasks detected" | risks]
    end

    risks
  end

  defp has_circular_dependencies?(dependencies) do
    # Simple cycle detection (not comprehensive)
    # In a real implementation, use topological sort
    # Placeholder
    false
  end

  defp generate_dependency_recommendations(tasks, dependencies, critical_path) do
    recommendations = []

    # Recommend parallelizing critical path tasks
    if length(critical_path) > 3 do
      recommendations = ["Consider parallelizing critical path tasks" | recommendations]
    end

    # Recommend breaking down high-dependency tasks
    high_dep_tasks = Enum.filter(dependencies, fn {_, deps} -> length(deps) > 3 end)

    if Enum.any?(high_dep_tasks) do
      recommendations = ["Break down tasks with many dependencies" | recommendations]
    end

    recommendations
  end

  ## Private Functions

  defp apply_chunk_changes(state, analysis, approved_by, updates_id) do
    # Update state based on analysis
    new_state =
      case {analysis.action, analysis.level} do
        {:create, :strategic_theme} ->
          add_strategic_theme(state, analysis, approved_by)

        {:create, :epic} ->
          add_epic(state, analysis, approved_by)

        {:create, :capability} ->
          add_capability(state, analysis, approved_by)

        {:create, :feature} ->
          add_feature(state, analysis, approved_by)

        {:update, level} ->
          update_item(state, level, updates_id, analysis, approved_by)
      end

    # Recalculate WSJF scores
    new_state = recalculate_wsjf(new_state)

    # Persist
    CodeStore.save_vision(serialize_state(new_state))

    # Notify
    notify_chunk_added(analysis, approved_by)

    new_state
  end

  defp add_strategic_theme(state, analysis, approved_by) do
    id = generate_id("theme")

    theme = %{
      id: id,
      name: analysis.name,
      description: analysis.description,
      target_bloc: extract_bloc(analysis.description),
      priority: map_size(state.strategic_themes) + 1,
      epic_ids: [],
      created_at: DateTime.utc_now(),
      approved_by: approved_by
    }

    %{
      state
      | strategic_themes: Map.put(state.strategic_themes, id, theme),
        last_updated: DateTime.utc_now()
    }
  end

  defp add_epic(state, analysis, approved_by) do
    id = generate_id("epic")

    epic = %{
      id: id,
      name: analysis.name,
      description: analysis.description,
      type: analysis.type,
      theme_id: analysis.relates_to,
      # Will be calculated
      wsjf_score: 0.0,
      business_value: analysis.business_value,
      time_criticality: analysis.time_criticality,
      risk_reduction: analysis.risk_reduction,
      job_size: analysis.job_size,
      capability_ids: [],
      status: :ideation,
      created_at: DateTime.utc_now(),
      approved_by: approved_by
    }

    # Add epic to parent theme
    state =
      if epic.theme_id do
        update_in(state.strategic_themes[epic.theme_id].epic_ids, &[id | &1])
      else
        state
      end

    %{state | epics: Map.put(state.epics, id, epic), last_updated: DateTime.utc_now()}
  end

  defp add_capability(state, analysis, approved_by) do
    id = generate_id("cap")

    capability = %{
      id: id,
      name: analysis.name,
      description: analysis.description,
      epic_id: analysis.relates_to,
      wsjf_score: 0.0,
      feature_ids: [],
      depends_on: analysis.depends_on || [],
      status: :backlog,
      created_at: DateTime.utc_now(),
      approved_by: approved_by
    }

    # Add to parent epic
    state =
      if capability.epic_id do
        update_in(state.epics[capability.epic_id].capability_ids, &[id | &1])
      else
        state
      end

    %{
      state
      | capabilities: Map.put(state.capabilities, id, capability),
        last_updated: DateTime.utc_now()
    }
  end

  defp add_feature(state, analysis, approved_by) do
    id = generate_id("feat")

    feature = %{
      id: id,
      name: analysis.name,
      description: analysis.description,
      capability_id: analysis.relates_to,
      # Will be created when work starts
      task_graph_id: nil,
      acceptance_criteria: analysis.acceptance_criteria,
      status: :backlog,
      created_at: DateTime.utc_now(),
      approved_by: approved_by
    }

    # Add to parent capability
    state =
      if feature.capability_id do
        update_in(state.capabilities[feature.capability_id].feature_ids, &[id | &1])
      else
        state
      end

    %{state | features: Map.put(state.features, id, feature), last_updated: DateTime.utc_now()}
  end

  defp update_item(state, level, id, analysis, _approved_by) do
    map_key =
      case level do
        :strategic_theme -> :strategic_themes
        :epic -> :epics
        :capability -> :capabilities
        :feature -> :features
      end

    update_in(state, [Access.key(map_key), id], fn item ->
      %{item | description: analysis.description, last_updated: DateTime.utc_now()}
    end)
  end

  defp mark_complete(state, item_id, level) do
    map_key =
      case level do
        :epic -> :epics
        :capability -> :capabilities
        :feature -> :features
      end

    update_in(state, [Access.key(map_key), item_id, :status], fn _ -> :done end)
  end

  ## WSJF Calculation

  defp recalculate_wsjf(state) do
    # WSJF = (Business Value + Time Criticality + Risk Reduction) / Job Size

    state =
      update_in(state.epics, fn epics ->
        Map.new(epics, fn {id, epic} ->
          wsjf =
            (epic.business_value + epic.time_criticality + epic.risk_reduction) /
              max(epic.job_size, 1)

          {id, %{epic | wsjf_score: wsjf}}
        end)
      end)

    # Capabilities inherit WSJF from their epic
    update_in(state.capabilities, fn capabilities ->
      Map.new(capabilities, fn {id, cap} ->
        parent_wsjf =
          if cap.epic_id && state.epics[cap.epic_id] do
            state.epics[cap.epic_id].wsjf_score
          else
            0.0
          end

        {id, %{cap | wsjf_score: parent_wsjf}}
      end)
    end)
  end

  defp get_wsjf_score(state, feature) do
    if feature.capability_id && state.capabilities[feature.capability_id] do
      state.capabilities[feature.capability_id].wsjf_score
    else
      0.0
    end
  end

  defp dependencies_met?(state, feature) do
    # Check if all dependency features are done
    cap = state.capabilities[feature.capability_id]

    if cap do
      Enum.all?(cap.depends_on, fn dep_id ->
        dep_cap = state.capabilities[dep_id]
        dep_cap && dep_cap.status == :done
      end)
    else
      true
    end
  end

  ## Helpers

  defp generate_id(prefix) do
    "#{prefix}-#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  defp extract_bloc(text) do
    case Regex.run(~r/(\d+\.?\d*)\s*BLOC/i, text) do
      [_, number] -> String.to_float(number)
      _ -> 0.0
    end
  end

  defp count_by_status(items) do
    items
    |> Map.values()
    |> Enum.group_by(& &1.status)
    |> Map.new(fn {status, list} -> {status, length(list)} end)
  end

  defp calculate_total_bloc(state) do
    state.strategic_themes
    |> Map.values()
    |> Enum.map(& &1.target_bloc)
    |> Enum.sum()
  end

  defp calculate_completion(state) do
    total = map_size(state.features)

    if total == 0 do
      0.0
    else
      done =
        state.features
        |> Map.values()
        |> Enum.count(&(&1.status == :done))

      done / total * 100
    end
  end

  defp build_hierarchy_tree(state) do
    Enum.map(state.strategic_themes, fn {_id, theme} ->
      %{
        theme: theme,
        epics:
          Enum.map(theme.epic_ids, fn epic_id ->
            epic = state.epics[epic_id]

            %{
              epic: epic,
              capabilities:
                Enum.map(epic.capability_ids, fn cap_id ->
                  cap = state.capabilities[cap_id]

                  %{
                    capability: cap,
                    features:
                      Enum.map(cap.feature_ids, fn feat_id ->
                        state.features[feat_id]
                      end)
                  }
                end)
            }
          end)
      }
    end)
  end

  defp notify_chunk_added(analysis, approved_by) do
    Conversation.WebChat.notify("""
    ✅ **Vision Chunk Added**

    Level: #{analysis.level}
    Name: #{analysis.name}

    #{if analysis.relates_to, do: "Parent: #{analysis.relates_to}", else: ""}

    Approved by: #{approved_by}
    """)
  end

  defp notify_approval_needed(analysis, result) do
    Conversation.WebChat.notify("""
    ⚠️ **Approval Needed**

    Level: #{analysis.level}
    Name: #{analysis.name}

    Confidence: #{Float.round(result.confidence * 100, 1)}%
    Reasoning: #{result.reasoning}

    Please review and approve.
    """)
  end

  defp notify_escalation(analysis, result) do
    Conversation.WebChat.notify("""
    🚨 **Decision Escalated**

    Level: #{analysis.level}
    Name: #{analysis.name}

    Confidence: #{Float.round(result.confidence * 100, 1)}%
    Reasoning: #{result.reasoning}

    Human decision required.
    """)
  end

  ## RuleEngine Helpers

  defp build_epic_stub(analysis) do
    %{
      id: "temp-epic-#{:erlang.unique_integer()}",
      wsjf_score:
        (analysis.business_value + analysis.time_criticality + analysis.risk_reduction) /
          max(analysis.job_size, 1),
      business_value: analysis.business_value,
      time_criticality: analysis.time_criticality,
      risk_reduction: analysis.risk_reduction,
      job_size: analysis.job_size
    }
  end

  defp build_feature_stub(analysis) do
    %{
      id: "temp-feature-#{:erlang.unique_integer()}",
      acceptance_criteria: analysis.acceptance_criteria || []
    }
  end

  ## Serialization

  defp serialize_state(state) do
    %{
      "safe_version" => "6.0",
      "strategic_themes" => state.strategic_themes,
      "epics" => state.epics,
      "capabilities" => state.capabilities,
      "features" => state.features,
      "relationships" => state.relationships,
      "approved_by" => state.approved_by,
      "created_at" => state.created_at,
      "last_updated" => state.last_updated
    }
  end

  defp deserialize_state(data) do
    %__MODULE__{
      strategic_themes: data["strategic_themes"] || %{},
      epics: data["epics"] || %{},
      capabilities: data["capabilities"] || %{},
      features: data["features"] || %{},
      relationships: data["relationships"] || %{},
      approved_by: data["approved_by"],
      created_at: data["created_at"],
      last_updated: data["last_updated"]
    }
  end

  # Missing helper functions
  defp filter_by_level_and_status(items, level, status) when is_map(items) do
    items
    |> Enum.filter(fn {_key, item} ->
      item_level = Map.get(item, :level, :medium)
      item_status = Map.get(item, :status, :pending)
      item_level == level and item_status == status
    end)
    |> Enum.into(%{})
  end

  defp filter_by_level_and_status(items, _level, _status) when is_list(items) do
    items
  end

  defp calculate_wsjf_score(task, criteria) do
    business_value = Map.get(criteria, :business_value, 1)
    time_criticality = Map.get(criteria, :time_criticality, 1)
    risk_reduction = Map.get(criteria, :risk_reduction, 1)
    job_size = Map.get(criteria, :job_size, 1)

    (business_value + time_criticality + risk_reduction) / job_size
  end

  defp build_dependency_graph(tasks, include_external) do
    dependencies = %{}
    critical_path = []

    # Simple dependency mapping
    task_deps =
      Enum.map(tasks, fn task ->
        {task.id, Map.get(task, :depends_on, [])}
      end)

    {Enum.into(task_deps, %{}), critical_path}
  end

  defp identify_risk_factors(tasks, dependencies) do
    # Simple risk identification
    Enum.map(tasks, fn task ->
      risk_level = if length(Map.get(dependencies, task.id, [])) > 3, do: :high, else: :low
      {task.id, risk_level}
    end)
    |> Enum.into(%{})
  end

  defp generate_dependency_recommendations(tasks, dependencies, critical_path) do
    # Simple recommendations based on dependencies
    Enum.map(tasks, fn task ->
      deps = Map.get(dependencies, task.id, [])

      recommendation =
        if length(deps) > 2 do
          "Consider breaking down this task due to high dependency count"
        else
          "Task has manageable dependencies"
        end

      {task.id, recommendation}
    end)
    |> Enum.into(%{})
  end
end
