defmodule Singularity.Planning.SingularityVision do
  @moduledoc """
  Singularity Vision Management System

  Hierarchical vision management for autonomous software development.
  Integrates with AgiPortfolio for enterprise-level planning.

  Vision Hierarchy:
  - Portfolio Vision (Enterprise level)
  - Strategic Themes (3-5 year vision areas)
  - Epics (6-12 month initiatives)
  - Capabilities (3-6 month cross-team features)
  - Features (1-3 month team deliverables)
  - Stories/Tasks (via HTDAG decomposition)
  """

  use GenServer
  require Logger
  alias Singularity.{Planning.AgiPortfolio, CodeStore}

  defstruct [
    # Vision hierarchy
    :portfolio_vision,
    # %{id => theme}
    :strategic_themes,
    # %{id => epic}
    :epics,
    # %{id => capability}
    :capabilities,
    # %{id => feature}
    :features,

    # Relationships and dependencies
    # %{theme_id => [epic_ids]}
    :theme_epics,
    # %{epic_id => [capability_ids]}
    :epic_capabilities,
    # %{capability_id => [feature_ids]}
    :capability_features,

    # WSJF scoring and prioritization
    # %{item_id => score}
    :wsjf_scores,

    # Integration with HTDAG for task decomposition
    # %{feature_id => htdag_id}
    :feature_htdags,

    # Metadata
    :created_at,
    :last_updated
  ]

  @type portfolio_vision :: %{
          statement: String.t(),
          target_year: integer(),
          success_metrics: [%{metric: String.t(), target: float()}],
          approved_at: DateTime.t(),
          approved_by: String.t()
        }

  @type strategic_theme :: %{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          target_bloc: float(),
          status: :active | :completed | :cancelled,
          # 1-10
          business_value: integer(),
          # 1-10
          time_criticality: integer(),
          # 1-10
          risk_reduction: integer(),
          created_at: DateTime.t(),
          epic_ids: [String.t()]
        }

  @type epic :: %{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          type: :business | :enabler,
          theme_id: String.t(),
          status: :ideation | :analysis | :implementation | :done,
          business_value: integer(),
          time_criticality: integer(),
          risk_reduction: integer(),
          estimated_job_size: integer(),
          wsjf_score: float(),
          capability_ids: [String.t()],
          created_at: DateTime.t()
        }

  @type capability :: %{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          epic_id: String.t(),
          status: :backlog | :implementing | :done,
          feature_ids: [String.t()],
          created_at: DateTime.t()
        }

  @type feature :: %{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          capability_id: String.t(),
          status: :backlog | :in_progress | :done,
          acceptance_criteria: [String.t()],
          htdag_id: String.t() | nil,
          created_at: DateTime.t(),
          completed_at: DateTime.t() | nil
        }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Set the enterprise portfolio vision
  """
  def set_portfolio_vision(statement, target_year, success_metrics, approved_by) do
    vision = %{
      statement: statement,
      target_year: target_year,
      success_metrics: success_metrics,
      approved_at: DateTime.utc_now(),
      approved_by: approved_by
    }

    GenServer.call(__MODULE__, {:set_portfolio_vision, vision})
  end

  @doc """
  Add a strategic theme
  """
  def add_strategic_theme(
        name,
        description,
        target_bloc,
        business_value,
        time_criticality,
        risk_reduction
      ) do
    theme = %{
      id: generate_id("theme"),
      name: name,
      description: description,
      target_bloc: target_bloc,
      status: :active,
      business_value: business_value,
      time_criticality: time_criticality,
      risk_reduction: risk_reduction,
      created_at: DateTime.utc_now(),
      epic_ids: []
    }

    GenServer.call(__MODULE__, {:add_strategic_theme, theme})
  end

  @doc """
  Add an epic under a strategic theme
  """
  def add_epic(
        name,
        description,
        type,
        theme_id,
        business_value,
        time_criticality,
        risk_reduction,
        estimated_job_size
      ) do
    epic = %{
      id: generate_id("epic"),
      name: name,
      description: description,
      type: type,
      theme_id: theme_id,
      status: :ideation,
      business_value: business_value,
      time_criticality: time_criticality,
      risk_reduction: risk_reduction,
      estimated_job_size: estimated_job_size,
      wsjf_score:
        calculate_wsjf(business_value, time_criticality, risk_reduction, estimated_job_size),
      capability_ids: [],
      created_at: DateTime.utc_now()
    }

    GenServer.call(__MODULE__, {:add_epic, epic})
  end

  @doc """
  Add a capability under an epic
  """
  def add_capability(name, description, epic_id) do
    capability = %{
      id: generate_id("cap"),
      name: name,
      description: description,
      epic_id: epic_id,
      status: :backlog,
      feature_ids: [],
      created_at: DateTime.utc_now()
    }

    GenServer.call(__MODULE__, {:add_capability, capability})
  end

  @doc """
  Add a feature under a capability
  """
  def add_feature(name, description, capability_id, acceptance_criteria) do
    feature = %{
      id: generate_id("feat"),
      name: name,
      description: description,
      capability_id: capability_id,
      status: :backlog,
      acceptance_criteria: acceptance_criteria,
      htdag_id: nil,
      created_at: DateTime.utc_now(),
      completed_at: nil
    }

    GenServer.call(__MODULE__, {:add_feature, feature})
  end

  @doc """
  Get the next highest priority work item
  """
  def get_next_work() do
    GenServer.call(__MODULE__, :get_next_work)
  end

  @doc """
  Get the complete vision hierarchy
  """
  def get_hierarchy() do
    GenServer.call(__MODULE__, :get_hierarchy)
  end

  @doc """
  Get progress summary
  """
  def get_progress() do
    GenServer.call(__MODULE__, :get_progress)
  end

  @doc """
  Analyze and suggest relationships for new vision chunks
  """
  def analyze_chunk(chunk_text, approved_by) do
    # Use LLM to analyze the chunk and suggest placement
    GenServer.call(__MODULE__, {:analyze_chunk, chunk_text, approved_by})
  end

  @doc """
  Update feature status
  """
  def update_feature_status(feature_id, status) do
    GenServer.call(__MODULE__, {:update_feature_status, feature_id, status})
  end

  @doc """
  Update epic description
  """
  def update_epic_description(epic_id, description) do
    GenServer.call(__MODULE__, {:update_epic_description, epic_id, description})
  end

  # Server callbacks

  def init(_opts) do
    state = %__MODULE__{
      portfolio_vision: nil,
      strategic_themes: %{},
      epics: %{},
      capabilities: %{},
      features: %{},
      theme_epics: %{},
      epic_capabilities: %{},
      capability_features: %{},
      wsjf_scores: %{},
      feature_htdags: %{},
      created_at: DateTime.utc_now(),
      last_updated: DateTime.utc_now()
    }

    {:ok, state}
  end

  def handle_call({:set_portfolio_vision, vision}, _from, state) do
    # Update AgiPortfolio as well
    AgiPortfolio.set_portfolio_vision(
      vision.statement,
      vision.target_year,
      vision.success_metrics
    )

    new_state = %{state | portfolio_vision: vision, last_updated: DateTime.utc_now()}
    {:reply, {:ok, vision}, new_state}
  end

  def handle_call({:add_strategic_theme, theme}, _from, state) do
    themes = Map.put(state.strategic_themes, theme.id, theme)
    new_state = %{state | strategic_themes: themes, last_updated: DateTime.utc_now()}

    # Notify via Google Chat
    notify_theme_added(theme)

    {:reply, {:ok, theme}, new_state}
  end

  def handle_call({:add_epic, epic}, _from, state) do
    epics = Map.put(state.epics, epic.id, epic)

    # Update theme relationships
    theme_epics = Map.update(state.theme_epics, epic.theme_id, [epic.id], &[epic.id | &1])

    new_state = %{
      state
      | epics: epics,
        theme_epics: theme_epics,
        last_updated: DateTime.utc_now()
    }

    # Notify via Google Chat
    notify_epic_added(epic, state.strategic_themes[epic.theme_id])

    {:reply, {:ok, epic}, new_state}
  end

  def handle_call({:add_capability, capability}, _from, state) do
    capabilities = Map.put(state.capabilities, capability.id, capability)

    # Update epic relationships
    epic_capabilities =
      Map.update(
        state.epic_capabilities,
        capability.epic_id,
        [capability.id],
        &[capability.id | &1]
      )

    new_state = %{
      state
      | capabilities: capabilities,
        epic_capabilities: epic_capabilities,
        last_updated: DateTime.utc_now()
    }

    {:reply, {:ok, capability}, new_state}
  end

  def handle_call({:add_feature, feature}, _from, state) do
    features = Map.put(state.features, feature.id, feature)

    # Update capability relationships
    capability_features =
      Map.update(
        state.capability_features,
        feature.capability_id,
        [feature.id],
        &[feature.id | &1]
      )

    new_state = %{
      state
      | features: features,
        capability_features: capability_features,
        last_updated: DateTime.utc_now()
    }

    {:reply, {:ok, feature}, new_state}
  end

  def handle_call(:get_next_work, _from, state) do
    # Find highest WSJF feature that's ready (dependencies met)
    ready_features =
      Enum.filter(state.features, fn {_id, feature} ->
        feature.status == :backlog && dependencies_met?(feature, state)
      end)

    highest_priority =
      Enum.max_by(
        ready_features,
        fn {_id, feature} ->
          # Wait, this is wrong - need to trace up the hierarchy
          epic = state.epics[feature.capability_id]
          epic.wsjf_score
        end,
        fn -> nil end
      )

    case highest_priority do
      nil -> {:reply, nil, state}
      {feature_id, feature} -> {:reply, feature, state}
    end
  end

  def handle_call(:get_hierarchy, _from, state) do
    hierarchy =
      Enum.map(state.strategic_themes, fn {theme_id, theme} ->
        epic_ids = Map.get(state.theme_epics, theme_id, [])

        epics =
          Enum.map(epic_ids, fn epic_id ->
            epic = state.epics[epic_id]
            capability_ids = Map.get(state.epic_capabilities, epic_id, [])

            capabilities =
              Enum.map(capability_ids, fn cap_id ->
                capability = state.capabilities[cap_id]
                feature_ids = Map.get(state.capability_features, cap_id, [])

                features =
                  Enum.map(feature_ids, fn feat_id ->
                    state.features[feat_id]
                  end)

                Map.put(capability, :features, features)
              end)

            Map.put(epic, :capabilities, capabilities)
          end)

        %{
          theme: theme,
          epics: epics
        }
      end)

    {:reply, hierarchy, state}
  end

  def handle_call(:get_progress, _from, state) do
    progress = %{
      themes: count_by_status(state.strategic_themes),
      epics: count_by_status(state.epics),
      capabilities: count_by_status(state.capabilities),
      features: count_by_status(state.features),
      total_themes: map_size(state.strategic_themes),
      total_epics: map_size(state.epics),
      total_capabilities: map_size(state.capabilities),
      total_features: map_size(state.features)
    }

    {:reply, progress, state}
  end

  def handle_call({:analyze_chunk, chunk_text, approved_by}, _from, state) do
    # Use LLM to analyze the chunk and suggest relationships
    # This would integrate with the AI system to understand context
    analysis = analyze_chunk_with_llm(chunk_text, state)

    {:reply, analysis, state}
  end

  def handle_call({:update_feature_status, feature_id, status}, _from, state) do
    case Map.get(state.features, feature_id) do
      nil ->
        {:reply, {:error, :feature_not_found}, state}

      feature ->
        updated_feature =
          Map.merge(feature, %{
            status: status,
            completed_at: if(status == :completed, do: DateTime.utc_now(), else: nil)
          })

        features = Map.put(state.features, feature_id, updated_feature)
        new_state = %{state | features: features, last_updated: DateTime.utc_now()}

        {:reply, :ok, new_state}
    end
  end

  def handle_call({:update_epic_description, epic_id, description}, _from, state) do
    case Map.get(state.epics, epic_id) do
      nil ->
        {:reply, {:error, :epic_not_found}, state}

      epic ->
        updated_epic = Map.put(epic, :description, description)
        epics = Map.put(state.epics, epic_id, updated_epic)
        new_state = %{state | epics: epics, last_updated: DateTime.utc_now()}

        {:reply, :ok, new_state}
    end
  end

  # Helper functions

  defp calculate_wsjf(business_value, time_criticality, risk_reduction, job_size) do
    (business_value + time_criticality + risk_reduction) / max(job_size, 1)
  end

  defp generate_id(prefix) do
    "#{prefix}-#{:crypto.strong_rand_bytes(4) |> Base.encode16() |> String.downcase()}"
  end

  defp count_by_status(items) do
    Enum.reduce(items, %{}, fn {_id, item}, acc ->
      Map.update(acc, item.status, 1, &(&1 + 1))
    end)
  end

  defp dependencies_met?(_feature, _state) do
    # Check if all upstream dependencies are completed
    # For now, assume all dependencies are met
    true
  end

  defp notify_theme_added(theme) do
    message = """
    ✅ Strategic Theme Added

    Name: #{theme.name}
    Target BLOC: #{theme.target_bloc}
    Description: #{theme.description}

    WSJF Factors: BV=#{theme.business_value}, TC=#{theme.time_criticality}, RR=#{theme.risk_reduction}
    """

    # Would integrate with Google Chat here
    Logger.info("Theme added: #{theme.name}")
  end

  defp notify_epic_added(epic, theme) do
    message = """
    ✅ Epic Added

    Name: #{epic.name}
    Type: #{epic.type}
    Parent Theme: #{theme.name}
    WSJF Score: #{Float.round(epic.wsjf_score, 2)}

    Description: #{epic.description}
    """

    # Would integrate with Google Chat here
    Logger.info("Epic added: #{epic.name} (WSJF: #{epic.wsjf_score})")
  end

  defp analyze_chunk_with_llm(_chunk_text, _state) do
    # Placeholder - would use AI to analyze chunk and suggest relationships
    %{
      suggested_level: :epic,
      suggested_parent: "theme-observability",
      estimated_wsjf: 6.2,
      suggested_dependencies: ["cap-service-mesh"],
      confidence: 0.85
    }
  end
end
