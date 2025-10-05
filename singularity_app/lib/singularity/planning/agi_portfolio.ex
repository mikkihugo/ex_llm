defmodule Singularity.Planning.AgiPortfolio do
  @moduledoc """
  Full SAFe 6.0 Portfolio Layer for AGI Enterprise.

  Manages:
  - Value Streams (business domains like Finance, Sales, R&D)
  - Resource Pools (compute, tokens, API quotas)
  - Agent Registry (millions of AI agents)
  - Solution Trains (large cross-value-stream initiatives)
  - Portfolio Kanban (epic flow states)
  - Lean Portfolio Management (resource allocation)

  Adapted for fully autonomous AI enterprise (no human workforce).
  """

  use GenServer
  require Logger

  alias Singularity.{CodeStore, Conversation}
  alias Singularity.Planning.SafeWorkPlanner

  defstruct [
    # Enterprise-level vision
    :portfolio_vision,
    # %{id => value_stream}
    :value_streams,
    # %{id => solution_train}
    :solution_trains,
    # %{id => agent}
    :agent_registry,
    # %{type => pool}
    :resource_pools,
    # How resources are distributed
    :allocation_rules,
    :created_at,
    :last_updated
  ]

  @type portfolio_vision :: %{
          statement: String.t(),
          target_year: integer(),
          success_metrics: [%{metric: String.t(), target: float()}],
          approved_at: DateTime.t()
        }

  @type value_stream :: %{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          type: :revenue_generating | :cost_center | :innovation | :operational,
          agent_team_ids: [String.t()],
          strategic_theme_ids: [String.t()],
          compute_allocation: float(),
          token_allocation: integer(),
          kpis: [
            %{
              metric: String.t(),
              target: float(),
              current: float(),
              trend: :improving | :stable | :declining
            }
          ],
          dependencies: [String.t()],
          created_at: DateTime.t()
        }

  @type solution_train :: %{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          value_stream_ids: [String.t()],
          agent_team_ids: [String.t()],
          epic_ids: [String.t()],
          status: :forming | :active | :sustaining | :done,
          created_at: DateTime.t()
        }

  @type agent_team :: %{
          id: String.t(),
          name: String.t(),
          role: String.t(),
          value_stream_id: String.t(),
          agent_ids: [String.t()],
          capabilities: [String.t()],
          feature_ids: [String.t()],
          created_at: DateTime.t()
        }

  @type agent :: %{
          id: String.t(),
          name: String.t(),
          role: String.t(),
          agent_team_id: String.t(),
          capabilities: [String.t()],
          resource_limits: %{
            max_tokens_per_day: integer(),
            max_compute_hours: float(),
            priority: :critical | :high | :medium | :low
          },
          current_feature_ids: [String.t()],
          status: :idle | :working | :blocked | :offline,
          created_at: DateTime.t()
        }

  @type resource_pool :: %{
          type: :compute | :tokens | :api_quota | :data_access,
          total_capacity: float(),
          allocated: float(),
          reserved: float(),
          available: float(),
          allocation_by_value_stream: %{String.t() => float()}
        }

  ## Public API

  def start_link(_opts) do
    GenServer.start_link(
      __MODULE__,
      %__MODULE__{
        portfolio_vision: nil,
        value_streams: %{},
        solution_trains: %{},
        agent_registry: %{},
        resource_pools: initialize_resource_pools(),
        allocation_rules: default_allocation_rules(),
        created_at: DateTime.utc_now(),
        last_updated: DateTime.utc_now()
      },
      name: __MODULE__
    )
  end

  @doc "Set enterprise-level portfolio vision"
  def set_portfolio_vision(statement, opts \\ []) do
    GenServer.call(__MODULE__, {:set_portfolio_vision, statement, opts})
  end

  @doc "Add a value stream (business domain)"
  def add_value_stream(name, opts \\ []) do
    GenServer.call(__MODULE__, {:add_value_stream, name, opts})
  end

  @doc "Add a solution train (large cross-value-stream initiative)"
  def add_solution_train(name, opts \\ []) do
    GenServer.call(__MODULE__, {:add_solution_train, name, opts})
  end

  @doc "Register an AI agent in the enterprise"
  def register_agent(name, role, opts \\ []) do
    GenServer.call(__MODULE__, {:register_agent, name, role, opts})
  end

  @doc "Get resource allocation summary"
  def get_resource_allocation do
    GenServer.call(__MODULE__, :get_resource_allocation)
  end

  @doc "Rebalance resources based on KPIs"
  def rebalance_resources do
    GenServer.call(__MODULE__, :rebalance_resources)
  end

  @doc "Get portfolio health dashboard"
  def get_portfolio_health do
    GenServer.call(__MODULE__, :get_portfolio_health)
  end

  ## GenServer Callbacks

  @impl true
  def init(state) do
    # Load persisted portfolio if exists
    case CodeStore.load_vision() do
      %{"agi_portfolio" => portfolio_data} ->
        {:ok, deserialize_portfolio(portfolio_data)}

      _ ->
        {:ok, state}
    end
  end

  @impl true
  def handle_call({:set_portfolio_vision, statement, opts}, _from, state) do
    target_year = Keyword.get(opts, :target_year, DateTime.utc_now().year + 5)
    success_metrics = Keyword.get(opts, :success_metrics, [])

    vision = %{
      statement: statement,
      target_year: target_year,
      success_metrics: success_metrics,
      approved_at: DateTime.utc_now()
    }

    new_state = %{state | portfolio_vision: vision, last_updated: DateTime.utc_now()}

    persist_portfolio(new_state)
    notify_portfolio_update("Portfolio Vision Set", statement)

    {:reply, {:ok, vision}, new_state}
  end

  @impl true
  def handle_call({:add_value_stream, name, opts}, _from, state) do
    id = generate_id("vs")

    value_stream = %{
      id: id,
      name: name,
      description: Keyword.get(opts, :description, ""),
      type: Keyword.get(opts, :type, :operational),
      agent_team_ids: [],
      strategic_theme_ids: Keyword.get(opts, :strategic_theme_ids, []),
      compute_allocation: 0.0,
      token_allocation: 0,
      kpis: Keyword.get(opts, :kpis, []),
      dependencies: Keyword.get(opts, :dependencies, []),
      created_at: DateTime.utc_now()
    }

    new_state = %{
      state
      | value_streams: Map.put(state.value_streams, id, value_stream),
        last_updated: DateTime.utc_now()
    }

    # Allocate resources to this value stream
    new_state = allocate_resources_to_value_stream(new_state, id)

    persist_portfolio(new_state)
    notify_portfolio_update("Value Stream Added", name)

    {:reply, {:ok, value_stream}, new_state}
  end

  @impl true
  def handle_call({:add_solution_train, name, opts}, _from, state) do
    id = generate_id("st")

    solution_train = %{
      id: id,
      name: name,
      description: Keyword.get(opts, :description, ""),
      value_stream_ids: Keyword.get(opts, :value_stream_ids, []),
      agent_team_ids: [],
      epic_ids: Keyword.get(opts, :epic_ids, []),
      status: :forming,
      created_at: DateTime.utc_now()
    }

    new_state = %{
      state
      | solution_trains: Map.put(state.solution_trains, id, solution_train),
        last_updated: DateTime.utc_now()
    }

    persist_portfolio(new_state)
    notify_portfolio_update("Solution Train Added", name)

    {:reply, {:ok, solution_train}, new_state}
  end

  @impl true
  def handle_call({:register_agent, name, role, opts}, _from, state) do
    id = generate_id("agent")

    agent = %{
      id: id,
      name: name,
      role: role,
      agent_team_id: Keyword.get(opts, :agent_team_id),
      capabilities: Keyword.get(opts, :capabilities, []),
      resource_limits: Keyword.get(opts, :resource_limits, default_resource_limits()),
      current_feature_ids: [],
      status: :idle,
      created_at: DateTime.utc_now()
    }

    new_state = %{
      state
      | agent_registry: Map.put(state.agent_registry, id, agent),
        last_updated: DateTime.utc_now()
    }

    persist_portfolio(new_state)

    Logger.info("Agent registered", agent_id: id, name: name, role: role)

    {:reply, {:ok, agent}, new_state}
  end

  @impl true
  def handle_call(:get_resource_allocation, _from, state) do
    allocation = %{
      compute: state.resource_pools[:compute],
      tokens: state.resource_pools[:tokens],
      by_value_stream: calculate_value_stream_allocations(state)
    }

    {:reply, allocation, state}
  end

  @impl true
  def handle_call(:rebalance_resources, _from, state) do
    Logger.info("Rebalancing resources based on KPIs")

    # Analyze KPIs and adjust allocations
    new_state = dynamic_rebalance(state)

    persist_portfolio(new_state)
    notify_portfolio_update("Resources Rebalanced", "Dynamic reallocation based on KPIs")

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_portfolio_health, _from, state) do
    health = %{
      vision: state.portfolio_vision,
      value_streams: count_by_status(state.value_streams, &value_stream_health/1),
      solution_trains: count_by_status(state.solution_trains, & &1.status),
      agents: %{
        total: map_size(state.agent_registry),
        idle: count_agents_by_status(state, :idle),
        working: count_agents_by_status(state, :working),
        blocked: count_agents_by_status(state, :blocked)
      },
      resource_utilization: calculate_resource_utilization(state),
      kpi_health: aggregate_kpi_health(state)
    }

    {:reply, health, state}
  end

  ## Resource Management

  defp initialize_resource_pools do
    %{
      compute: %{
        type: :compute,
        # 10k GPU hours/day
        total_capacity: 10_000.0,
        allocated: 0.0,
        reserved: 0.0,
        available: 10_000.0,
        allocation_by_value_stream: %{}
      },
      tokens: %{
        type: :tokens,
        # 100M tokens/day
        total_capacity: 100_000_000,
        allocated: 0,
        reserved: 0,
        available: 100_000_000,
        allocation_by_value_stream: %{}
      }
    }
  end

  defp default_allocation_rules do
    %{
      revenue_generating: 0.50,
      cost_center: 0.25,
      innovation: 0.20,
      operational: 0.05
    }
  end

  defp default_resource_limits do
    %{
      max_tokens_per_day: 100_000,
      max_compute_hours: 1.0,
      priority: :medium
    }
  end

  defp allocate_resources_to_value_stream(state, vs_id) do
    value_stream = state.value_streams[vs_id]
    allocation_pct = state.allocation_rules[value_stream.type] || 0.0

    # Allocate compute
    compute_hours = state.resource_pools[:compute].total_capacity * allocation_pct
    tokens = trunc(state.resource_pools[:tokens].total_capacity * allocation_pct)

    # Update value stream
    value_stream = %{
      value_stream
      | compute_allocation: compute_hours,
        token_allocation: tokens
    }

    # Update resource pools
    compute_pool = state.resource_pools[:compute]

    compute_pool = %{
      compute_pool
      | allocated: compute_pool.allocated + compute_hours,
        available: compute_pool.available - compute_hours,
        allocation_by_value_stream:
          Map.put(
            compute_pool.allocation_by_value_stream,
            vs_id,
            compute_hours
          )
    }

    token_pool = state.resource_pools[:tokens]

    token_pool = %{
      token_pool
      | allocated: token_pool.allocated + tokens,
        available: token_pool.available - tokens,
        allocation_by_value_stream:
          Map.put(
            token_pool.allocation_by_value_stream,
            vs_id,
            tokens
          )
    }

    %{
      state
      | value_streams: Map.put(state.value_streams, vs_id, value_stream),
        resource_pools: %{
          state.resource_pools
          | compute: compute_pool,
            tokens: token_pool
        }
    }
  end

  defp dynamic_rebalance(state) do
    # Analyze KPIs and shift resources to underperforming value streams
    value_streams_by_health =
      state.value_streams
      |> Map.values()
      |> Enum.sort_by(&value_stream_health/1)

    # If revenue-generating streams are declining, shift more resources
    needs_boost =
      Enum.any?(value_streams_by_health, fn vs ->
        vs.type == :revenue_generating && has_declining_kpis?(vs)
      end)

    if needs_boost do
      # Shift 10% from innovation to revenue-generating
      new_rules = %{
        state.allocation_rules
        | revenue_generating: state.allocation_rules.revenue_generating + 0.10,
          innovation: state.allocation_rules.innovation - 0.10
      }

      %{state | allocation_rules: new_rules}
      |> reallocate_all_value_streams()
    else
      state
    end
  end

  defp reallocate_all_value_streams(state) do
    # Recalculate allocations for all value streams
    Enum.reduce(state.value_streams, state, fn {vs_id, _vs}, acc_state ->
      allocate_resources_to_value_stream(acc_state, vs_id)
    end)
  end

  ## Health Calculations

  defp value_stream_health(value_stream) do
    # Calculate health score (0.0 - 1.0) based on KPIs
    if Enum.empty?(value_stream.kpis) do
      0.5
    else
      avg_achievement =
        value_stream.kpis
        |> Enum.map(fn kpi ->
          if kpi.target > 0, do: kpi.current / kpi.target, else: 0.0
        end)
        |> Enum.sum()
        |> Kernel./(length(value_stream.kpis))

      min(avg_achievement, 1.0)
    end
  end

  defp has_declining_kpis?(value_stream) do
    Enum.any?(value_stream.kpis, &(&1.trend == :declining))
  end

  defp calculate_value_stream_allocations(state) do
    Enum.map(state.value_streams, fn {_id, vs} ->
      %{
        name: vs.name,
        compute: vs.compute_allocation,
        tokens: vs.token_allocation,
        health: value_stream_health(vs)
      }
    end)
  end

  defp calculate_resource_utilization(state) do
    %{
      compute: %{
        total: state.resource_pools[:compute].total_capacity,
        allocated: state.resource_pools[:compute].allocated,
        utilization_pct:
          state.resource_pools[:compute].allocated /
            state.resource_pools[:compute].total_capacity * 100
      },
      tokens: %{
        total: state.resource_pools[:tokens].total_capacity,
        allocated: state.resource_pools[:tokens].allocated,
        utilization_pct:
          state.resource_pools[:tokens].allocated /
            state.resource_pools[:tokens].total_capacity * 100
      }
    }
  end

  defp aggregate_kpi_health(state) do
    all_kpis =
      state.value_streams
      |> Map.values()
      |> Enum.flat_map(& &1.kpis)

    if Enum.empty?(all_kpis) do
      %{overall: :unknown, improving: 0, stable: 0, declining: 0}
    else
      %{
        overall: determine_overall_trend(all_kpis),
        improving: Enum.count(all_kpis, &(&1.trend == :improving)),
        stable: Enum.count(all_kpis, &(&1.trend == :stable)),
        declining: Enum.count(all_kpis, &(&1.trend == :declining))
      }
    end
  end

  defp determine_overall_trend(kpis) do
    improving = Enum.count(kpis, &(&1.trend == :improving))
    declining = Enum.count(kpis, &(&1.trend == :declining))

    cond do
      improving > declining -> :improving
      declining > improving -> :declining
      true -> :stable
    end
  end

  defp count_agents_by_status(state, status) do
    state.agent_registry
    |> Map.values()
    |> Enum.count(&(&1.status == status))
  end

  defp count_by_status(items, status_fn) do
    items
    |> Map.values()
    |> Enum.group_by(status_fn)
    |> Map.new(fn {status, list} -> {status, length(list)} end)
  end

  ## Helpers

  defp generate_id(prefix) do
    "#{prefix}-#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  defp persist_portfolio(state) do
    data = serialize_portfolio(state)
    CodeStore.save_vision(%{"agi_portfolio" => data})
  end

  defp notify_portfolio_update(title, description) do
    Conversation.GoogleChat.notify("""
    🏢 **Portfolio Update**

    #{title}

    #{description}
    """)
  end

  defp serialize_portfolio(state) do
    %{
      "portfolio_vision" => state.portfolio_vision,
      "value_streams" => state.value_streams,
      "solution_trains" => state.solution_trains,
      "agent_registry" => state.agent_registry,
      "resource_pools" => state.resource_pools,
      "allocation_rules" => state.allocation_rules,
      "created_at" => state.created_at,
      "last_updated" => state.last_updated
    }
  end

  defp deserialize_portfolio(data) do
    %__MODULE__{
      portfolio_vision: data["portfolio_vision"],
      value_streams: data["value_streams"] || %{},
      solution_trains: data["solution_trains"] || %{},
      agent_registry: data["agent_registry"] || %{},
      resource_pools: data["resource_pools"] || initialize_resource_pools(),
      allocation_rules: data["allocation_rules"] || default_allocation_rules(),
      created_at: data["created_at"],
      last_updated: data["last_updated"]
    }
  end
end
