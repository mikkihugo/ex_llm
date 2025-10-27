defmodule Singularity.Execution.Planning.StrategyLoader do
  @moduledoc """
  GenServer that loads and caches TaskGraph execution strategies in ETS.

  Provides fast strategy lookups by matching task descriptions against regex patterns.
  Strategies are sorted by priority (highest first) and cached in ETS for performance.

  ## Caching Strategy

  - Loads all active strategies into ETS on startup
  - Refreshes cache every 5 minutes
  - Manual refresh via `reload_strategies/0`
  - Pattern matching uses compiled regexes stored in ETS

  ## Usage

      # Get strategy for task
      {:ok, strategy} = StrategyLoader.get_strategy_for_task("Build user authentication")
      # => %TaskExecutionStrategy{name: "secure_feature_development", ...}

      # Hot-reload after database update
      StrategyLoader.reload_strategies()

      # List all active strategies
      strategies = StrategyLoader.list_all_strategies()
  """

  use GenServer
  require Logger

  alias Singularity.Repo
  alias Singularity.Execution.Planning.TaskExecutionStrategy
  import Ecto.Query

  @table :task_graph_strategy_cache
  @refresh_interval :timer.minutes(5)

  ## Client API

  @doc """
  Start the strategy loader GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get execution strategy for a task description.

  Matches task description against strategy patterns, returning the highest-priority match.

  ## Examples

      iex> get_strategy_for_task("Build user authentication system")
      {:ok, %TaskExecutionStrategy{name: "secure_feature_development", ...}}

      iex> get_strategy_for_task("Unknown task type")
      {:ok, %TaskExecutionStrategy{name: "default_strategy", ...}}
  """
  @spec get_strategy_for_task(String.t()) :: {:ok, TaskExecutionStrategy.t()} | {:error, term()}
  def get_strategy_for_task(task_description) do
    GenServer.call(__MODULE__, {:get_strategy, task_description})
  end

  @doc """
  Get strategy by name.
  """
  @spec get_strategy_by_name(String.t()) ::
          {:ok, TaskExecutionStrategy.t()} | {:error, :not_found}
  def get_strategy_by_name(name) do
    case :ets.lookup(@table, {:by_name, name}) do
      [{_key, strategy}] -> {:ok, strategy}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  List all active strategies, sorted by priority.
  """
  @spec list_all_strategies() :: [TaskExecutionStrategy.t()]
  def list_all_strategies do
    :ets.match_object(@table, {{:strategy, :_}, :"$1"})
    |> Enum.map(fn {_key, strategy} -> strategy end)
    |> Enum.sort_by(& &1.priority, :desc)
  end

  @doc """
  Reload all strategies from database (hot-reload).
  """
  @spec reload_strategies() :: :ok
  def reload_strategies do
    GenServer.cast(__MODULE__, :reload)
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    # Create ETS table for strategy cache
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])

    # Load all strategies
    load_all_strategies()

    # Schedule periodic refresh
    schedule_refresh()

    Logger.info("StrategyLoader started with #{count_strategies()} strategies")

    {:ok, %{last_refresh: DateTime.utc_now()}}
  end

  @impl true
  def handle_call({:get_strategy, task_description}, _from, state) do
    strategy = find_matching_strategy(task_description)
    {:reply, strategy, state}
  end

  @impl true
  def handle_cast(:reload, state) do
    Logger.info("Reloading TaskGraph execution strategies from database")
    load_all_strategies()
    {:noreply, %{state | last_refresh: DateTime.utc_now()}}
  end

  @impl true
  def handle_info(:refresh, state) do
    load_all_strategies()
    schedule_refresh()
    {:noreply, %{state | last_refresh: DateTime.utc_now()}}
  end

  ## Private Functions

  defp load_all_strategies do
    # Clear existing cache
    :ets.delete_all_objects(@table)

    # Load all active strategies from database, sorted by priority
    strategies =
      from(s in TaskExecutionStrategy,
        where: s.status == "active",
        order_by: [desc: s.priority, desc: s.inserted_at]
      )
      |> Repo.all()

    # Store in ETS with compiled regexes
    Enum.each(strategies, fn strategy ->
      # Store by priority index
      :ets.insert(@table, {{:strategy, strategy.id}, strategy})

      # Store by name for direct lookup
      :ets.insert(@table, {{:by_name, strategy.name}, strategy})

      # Compile and cache regex for faster matching
      case Regex.compile(strategy.task_pattern) do
        {:ok, regex} ->
          :ets.insert(@table, {{:regex, strategy.id}, regex})

        {:error, reason} ->
          Logger.warning("Invalid regex pattern for strategy #{strategy.name}",
            pattern: strategy.task_pattern,
            error: inspect(reason)
          )
      end
    end)

    Logger.debug("Loaded #{length(strategies)} TaskGraph execution strategies into ETS cache")
  end

  defp find_matching_strategy(task_description) do
    # Get all strategies sorted by priority
    strategies = list_all_strategies()

    # Find first matching strategy
    case Enum.find(strategies, &matches_pattern?(&1, task_description)) do
      nil ->
        # No match found, return default strategy or error
        get_default_strategy()

      strategy ->
        {:ok, strategy}
    end
  end

  defp matches_pattern?(strategy, task_description) do
    case :ets.lookup(@table, {:regex, strategy.id}) do
      [{_key, regex}] ->
        Regex.match?(regex, task_description)

      [] ->
        # Regex not cached (invalid pattern), skip this strategy
        false
    end
  end

  defp get_default_strategy do
    # Try to find a strategy named "default" or with pattern ".*"
    case get_strategy_by_name("default") do
      {:ok, strategy} ->
        {:ok, strategy}

      {:error, :not_found} ->
        # Look for catch-all pattern
        strategies = list_all_strategies()

        case Enum.find(strategies, fn s -> s.task_pattern == ".*" end) do
          nil ->
            {:error, :no_strategy_found}

          strategy ->
            {:ok, strategy}
        end
    end
  end

  defp count_strategies do
    :ets.select_count(@table, [{{:strategy, :_}, [], [true]}])
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end
end
