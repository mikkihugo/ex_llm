defmodule Singularity.Bootstrap.StageManager do
  @moduledoc """
  Manages Singularity's evolution stages from minimal self-discovery to full autonomy.

  ## Bootstrap Stages

  Singularity evolves in 4 stages, each building on the previous:

  ### Stage 1: Embryonic (Self-Discovery)
  - **Focus**: Learn about Singularity's own codebase
  - **Target**: `/home/mhugo/code/singularity` (meta-system only)
  - **Mode**: Read-only (no modifications)
  - **Duration**: 7 days minimum
  - **Goal**: Complete self-knowledge (90%+ coverage)

  ### Stage 2: Larval (Supervised Self-Improvement)
  - **Focus**: Fix Singularity's own bugs with human approval
  - **Target**: Singularity source (supervised modifications)
  - **Mode**: Supervised (human approves each fix)
  - **Duration**: 14 days minimum
  - **Goal**: 50+ bugs fixed, 80%+ approval rate

  ### Stage 3: Juvenile (Autonomous Self-Development)
  - **Focus**: Autonomous self-improvement with guardrails
  - **Target**: Singularity agents (autonomous modifications)
  - **Mode**: Autonomous (with validation + rollback)
  - **Duration**: 30 days minimum
  - **Goal**: 100+ improvements, <5% regression rate

  ### Stage 4: Adult (Multi-Project Development)
  - **Focus**: Help develop user projects
  - **Target**: Both Singularity (maintenance) and user projects (primary)
  - **Mode**: Autonomous dual-mode
  - **Duration**: 60+ days minimum
  - **Goal**: Pattern transfer success 85%+

  ## Configuration

      # config/config.exs
      config :singularity, :bootstrap,
        current_stage: 1,
        auto_advance: false,  # Require manual approval to advance stages

        # Stage-specific settings
        stage_1: %{
          target_codebase: :self,
          mode: :read_only,
          enabled_features: [:self_discovery, :htdag_scan]
        },

        stage_2: %{
          target_codebase: :self,
          mode: :supervised,
          require_approval: true,
          enabled_features: [:self_discovery, :htdag_fix, :agent_improvement]
        }

  ## Usage

      # Check current stage
      StageManager.get_current_stage()
      # => 1

      # Check if can advance
      StageManager.can_advance?()
      # => {:ok, "All requirements met"}
      # => {:error, "Need 5 more days in stage"}

      # Advance stage (requires human confirmation)
      StageManager.advance_stage!()

  ## Integration Points

  - `Singularity.Code.StartupCodeIngestion` - Respects stage boundaries
  - `Singularity.Agent` - Scope limited by current stage
  - `Singularity.CodeStore` - Enforces codebase type restrictions
  """

  use GenServer
  require Logger

  import Ecto.Query
  alias Singularity.Repo

  @stage_requirements %{
    1 => %{
      min_duration_days: 7,
      required_metrics: %{
        codebase_ingestion_complete: true,
        self_knowledge_score: 0.9,
        zero_crashes: true
      },
      description: "Embryonic - Self-Discovery"
    },
    2 => %{
      min_duration_days: 14,
      required_metrics: %{
        bugs_fixed: 50,
        agent_improvements: 10,
        approval_rate: 0.8,
        zero_regressions: true
      },
      description: "Larval - Supervised Self-Improvement"
    },
    3 => %{
      min_duration_days: 30,
      required_metrics: %{
        autonomous_improvements: 100,
        patterns_learned: 50,
        regression_rate_below: 0.05,
        circuit_breaker_trips: 0
      },
      description: "Juvenile - Autonomous Self-Development"
    },
    4 => %{
      min_duration_days: 60,
      required_metrics: %{
        codebase_health_score: 0.95,
        pattern_transfer_success: 0.85,
        user_projects_ingested: 1
      },
      description: "Adult - Multi-Project Development"
    }
  }

  defstruct [
    :current_stage,
    :started_at,
    :stage_started_at,
    :metrics,
    :can_advance,
    :config
  ]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get current bootstrap stage (1-4).
  """
  def get_current_stage do
    GenServer.call(__MODULE__, :get_current_stage)
  end

  @doc """
  Get stage configuration for current stage.
  """
  def get_stage_config do
    GenServer.call(__MODULE__, :get_stage_config)
  end

  @doc """
  Check if system can advance to next stage.

  Returns {:ok, message} if ready, {:error, reason} otherwise.
  """
  def can_advance? do
    GenServer.call(__MODULE__, :can_advance)
  end

  @doc """
  Advance to next stage (requires human confirmation).
  """
  def advance_stage! do
    GenServer.call(__MODULE__, :advance_stage, :infinity)
  end

  @doc """
  Update metrics for current stage.
  """
  def update_metrics(metrics) when is_map(metrics) do
    GenServer.cast(__MODULE__, {:update_metrics, metrics})
  end

  @doc """
  Get detailed status including metrics and requirements.
  """
  def status do
    GenServer.call(__MODULE__, :status)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    config = Application.get_env(:singularity, :bootstrap, [])

    # Load from database (survives hot reloads + restarts)
    {current_stage, stage_started_at, metrics} = load_from_db()

    state = %__MODULE__{
      current_stage: current_stage,
      started_at: DateTime.utc_now(),
      stage_started_at: stage_started_at,
      metrics: metrics,
      can_advance: false,
      config: config
    }

    Logger.info(
      "Bootstrap Stage Manager: Starting at Stage #{current_stage} (#{get_stage_description(current_stage)})"
    )

    {:ok, state}
  end

  @impl true
  def handle_call(:get_current_stage, _from, state) do
    {:reply, state.current_stage, state}
  end

  @impl true
  def handle_call(:get_stage_config, _from, state) do
    config = get_config_for_stage(state.current_stage, state.config)
    {:reply, config, state}
  end

  @impl true
  def handle_call(:can_advance, _from, state) do
    result = check_advancement_requirements(state)
    {:reply, result, %{state | can_advance: match?({:ok, _}, result)}}
  end

  @impl true
  def handle_call(:advance_stage, _from, state) do
    case check_advancement_requirements(state) do
      {:ok, _} ->
        # Require human confirmation
        if confirm_advancement(state.current_stage) do
          new_stage = state.current_stage + 1

          # Update application env
          update_stage_config(new_stage)

          new_state = %{
            state
            | current_stage: new_stage,
              stage_started_at: DateTime.utc_now(),
              metrics: %{},
              can_advance: false
          }

          Logger.info(
            "🎉 Advanced to Bootstrap Stage #{new_stage} (#{get_stage_description(new_stage)})"
          )

          # Emit telemetry
          :telemetry.execute(
            [:singularity, :bootstrap, :stage_advanced],
            %{new_stage: new_stage},
            %{timestamp: DateTime.utc_now()}
          )

          {:reply, {:ok, new_stage}, new_state}
        else
          {:reply, {:error, :not_confirmed}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    requirements = @stage_requirements[state.current_stage]
    days_in_stage = days_since(state.stage_started_at)

    status = %{
      current_stage: state.current_stage,
      stage_description: get_stage_description(state.current_stage),
      days_in_stage: days_in_stage,
      days_required: requirements.min_duration_days,
      metrics: state.metrics,
      required_metrics: requirements.required_metrics,
      can_advance: state.can_advance,
      advancement_check: check_advancement_requirements(state)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast({:update_metrics, metrics}, state) do
    updated_metrics = Map.merge(state.metrics, metrics)

    # Persist metrics to database
    save_metrics_to_db(updated_metrics)

    {:noreply, %{state | metrics: updated_metrics}}
  end

  ## Private Functions

  defp check_advancement_requirements(state) do
    next_stage = state.current_stage + 1

    if next_stage > 4 do
      {:error, "Already at maximum stage (4)"}
    else
      requirements = @stage_requirements[state.current_stage]

      # Check duration
      days_in_stage = days_since(state.stage_started_at)
      duration_ok? = days_in_stage >= requirements.min_duration_days

      # Check metrics
      metrics_result = check_metrics(state.metrics, requirements.required_metrics)

      cond do
        not duration_ok? ->
          days_needed = requirements.min_duration_days - days_in_stage
          {:error, "Need #{days_needed} more days in Stage #{state.current_stage}"}

        not match?({:ok, _}, metrics_result) ->
          metrics_result

        true ->
          {:ok, "All requirements met for Stage #{next_stage}"}
      end
    end
  end

  defp check_metrics(actual_metrics, required_metrics) do
    unmet =
      Enum.reduce(required_metrics, [], fn {key, required_value}, acc ->
        actual_value = Map.get(actual_metrics, key)

        met? =
          case required_value do
            true -> actual_value == true
            false -> actual_value == false
            num when is_number(num) -> is_number(actual_value) and actual_value >= num
            {:less_than, max} -> is_number(actual_value) and actual_value < max
            _ -> actual_value == required_value
          end

        if met?, do: acc, else: [{key, required_value, actual_value} | acc]
      end)

    if Enum.empty?(unmet) do
      {:ok, "All metrics met"}
    else
      unmet_descriptions =
        Enum.map(unmet, fn {key, required, actual} ->
          "#{key}: required #{inspect(required)}, got #{inspect(actual)}"
        end)

      {:error, "Unmet metrics: #{Enum.join(unmet_descriptions, ", ")}"}
    end
  end

  defp days_since(datetime) do
    (DateTime.diff(DateTime.utc_now(), datetime, :second) / 86400)
    |> Float.floor()
    |> trunc()
  end

  defp get_stage_description(stage) do
    @stage_requirements[stage][:description] || "Unknown"
  end

  defp get_config_for_stage(stage, global_config) do
    stage_key = String.to_atom("stage_#{stage}")
    Keyword.get(global_config, stage_key, %{})
  end

  defp update_stage_config(new_stage) do
    current_config = Application.get_env(:singularity, :bootstrap, [])
    updated_config = Keyword.put(current_config, :current_stage, new_stage)
    Application.put_env(:singularity, :bootstrap, updated_config)

    # Also persist to database
    save_to_db(new_stage, DateTime.utc_now(), %{})
  end

  defp confirm_advancement(current_stage) do
    next_stage = current_stage + 1
    next_description = get_stage_description(next_stage)

    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("BOOTSTRAP STAGE ADVANCEMENT")
    IO.puts(String.duplicate("=", 70))
    IO.puts("")
    IO.puts("Current Stage: #{current_stage} (#{get_stage_description(current_stage)})")
    IO.puts("Next Stage:    #{next_stage} (#{next_description})")
    IO.puts("")
    IO.puts("This will:")

    case next_stage do
      2 ->
        IO.puts("  - Enable supervised self-improvement")
        IO.puts("  - Allow bug fixes (with human approval)")
        IO.puts("  - Start agent self-improvement loop")

      3 ->
        IO.puts("  - Enable AUTONOMOUS self-improvement")
        IO.puts("  - Remove approval requirement (with guardrails)")
        IO.puts("  - Allow agents to evolve themselves")

      4 ->
        IO.puts("  - Enable multi-project development")
        IO.puts("  - Ingest user projects into knowledge base")
        IO.puts("  - Apply learned patterns to user code")

      _ ->
        IO.puts("  - Unknown stage")
    end

    IO.puts("")
    IO.write("Proceed with stage advancement? [yes/no]: ")

    case IO.gets("") |> String.trim() |> String.downcase() do
      "yes" -> true
      "y" -> true
      _ -> false
    end
  end

  ## Database Persistence

  defp load_from_db do
    case Repo.one(
           from b in "bootstrap_stages",
             select: {b.current_stage, b.stage_started_at, b.metrics},
             limit: 1
         ) do
      {stage, started_at, metrics} ->
        {stage, started_at, Jason.decode!(metrics || "{}")}

      nil ->
        # First run - initialize database
        Logger.warning("Bootstrap stages table not initialized, using defaults")
        {1, DateTime.utc_now(), %{}}
    end
  rescue
    e ->
      Logger.error("Failed to load bootstrap stage from database: #{inspect(e)}")
      {1, DateTime.utc_now(), %{}}
  end

  defp save_to_db(stage, stage_started_at, metrics) do
    # Update the singleton row
    query = """
    UPDATE bootstrap_stages
    SET current_stage = $1,
        stage_started_at = $2,
        metrics = $3,
        stage_history = jsonb_insert(
          stage_history,
          '{0}',
          jsonb_build_object(
            'stage', $1,
            'started_at', $2::text,
            'reason', 'manual_advancement'
          ),
          true
        ),
        updated_at = NOW()
    """

    Repo.query(query, [stage, stage_started_at, Jason.encode!(metrics)])
  rescue
    e ->
      Logger.error("Failed to save bootstrap stage to database: #{inspect(e)}")
      :error
  end

  defp save_metrics_to_db(metrics) do
    query = "UPDATE bootstrap_stages SET metrics = $1, updated_at = NOW()"
    Repo.query(query, [Jason.encode!(metrics)])
  rescue
    e ->
      Logger.error("Failed to save metrics to database: #{inspect(e)}")
      :error
  end
end
