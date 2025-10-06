defmodule Singularity.Planning.SafeWorkPlanner do
  @moduledoc """
  SAFe 6.0 Essential Work Planner.

  Hierarchy:
    Strategic Themes (3-5 year vision areas)
      └─ Epics (6-12 month initiatives - Business or Enabler)
          └─ Capabilities (3-6 month cross-team features)
              └─ Features (1-3 month team deliverables)
                  └─ HTDAG breakdown → Stories → Tasks

  Supports incremental vision chunk submission that can update any level.
  Uses WSJF (Weighted Shortest Job First) for prioritization.
  """

  use GenServer
  require Logger

  alias Singularity.{CodeStore, Conversation}
  alias Singularity.Autonomy.RuleEngine, as: RuleEngine

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
          htdag_id: String.t() | nil,
          acceptance_criteria: [String.t()],
          status: :backlog | :in_progress | :done,
          created_at: DateTime.t()
        }

  ## Public API

  def start_link(_opts) do
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
        Logger.warninging("Old vision format detected - starting fresh")
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
        Logger.warninging("RuleEngine requires collaboration",
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
    # Use LLM to analyze the vision chunk

    existing_items = format_existing_items(state)

    _prompt = """
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

    # TODO: Call LLM here
    # For now, heuristic based on keywords
    level =
      cond do
        String.contains?(text, ~r/(theme|strategic|BLOC)/i) -> :strategic_theme
        String.contains?(text, ~r/(epic|initiative|enabler)/i) -> :epic
        String.contains?(text, ~r/(capability|cross-team)/i) -> :capability
        true -> :feature
      end

    action = if updates_id, do: :update, else: :create

    %{
      level: level,
      action: action,
      type: if(level == :epic, do: guess_epic_type(text), else: nil),
      name: extract_name(text),
      description: text,
      relates_to: relates_to || find_semantic_parent(state, text, level),
      depends_on: [],
      business_value: 5,
      time_criticality: 5,
      risk_reduction: 5,
      job_size: 8,
      acceptance_criteria: if(level == :feature, do: extract_criteria(text), else: [])
    }
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

  defp find_semantic_parent(_state, _text, _level) do
    # TODO: Use embeddings to find most related parent
    nil
  end

  defp format_existing_items(state) do
    """
    Themes: #{state.strategic_themes |> Map.values() |> Enum.map(& &1.name) |> Enum.join(", ")}
    Epics: #{state.epics |> Map.values() |> Enum.map(& &1.name) |> Enum.join(", ")}
    Capabilities: #{state.capabilities |> Map.values() |> Enum.map(& &1.name) |> Enum.join(", ")}
    """
  end

  ## State Mutations

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
      htdag_id: nil,
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
    Conversation.GoogleChat.notify("""
    ✅ **Vision Chunk Added**

    Level: #{analysis.level}
    Name: #{analysis.name}

    #{if analysis.relates_to, do: "Parent: #{analysis.relates_to}", else: ""}

    Approved by: #{approved_by}
    """)
  end

  defp notify_approval_needed(analysis, result) do
    Conversation.GoogleChat.notify("""
    ⚠️ **Approval Needed**

    Level: #{analysis.level}
    Name: #{analysis.name}

    Confidence: #{Float.round(result.confidence * 100, 1)}%
    Reasoning: #{result.reasoning}

    Please review and approve.
    """)
  end

  defp notify_escalation(analysis, result) do
    Conversation.GoogleChat.notify("""
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
end
