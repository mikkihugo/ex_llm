defmodule Singularity.Execution.Autonomy.RuleLoader do
  @moduledoc """
  Rule Loader - Loads evolvable rules from PostgreSQL with ETS caching.

  OTP GenServer that:
  - Loads rules from `agent_behavior_confidence_rules` table in PostgreSQL
  - Caches active rules in ETS for fast, lock-free access
  - Periodically refreshes rules (every 5 minutes)
  - Supports semantic similarity search via pgvector embeddings
  - Handles rule reloading after evolution

  ## Architecture

  Rules are stored as **data, not code** in PostgreSQL. This enables:
  - Agents to evolve rules through consensus voting
  - Hot-reload of rule updates without recompiling Elixir
  - Semantic search for similar rules via embeddings
  - Full audit trail of rule changes and evolution

  ## Usage

  Rules are cached in ETS for O(1) lookup:

      {:ok, rule} = RuleLoader.get_rule("quality-check")
      # Looks up in ETS cache, falls back to DB if not cached

  Get all rules by category:

      rules = RuleLoader.get_rules_by_category(:code_quality)
      # Returns all active rules for the category

  Find similar rules by semantic embedding:

      RuleLoader.find_similar_rules(embedding, limit: 5)
      # Returns rules similar to the embedding vector

  Reload rules after agent evolution:

      RuleLoader.reload_rules()
      # Refreshes cache from database (called after rule consensus)
  """

  use GenServer
  require Logger

  alias Singularity.{Repo}
  alias Singularity.Execution.Autonomy.Rule
  import Ecto.Query

  @table :rule_cache
  @refresh_interval :timer.minutes(5)

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Get rule by ID (from cache or DB)"
  def get_rule(rule_id) do
    case :ets.lookup(@table, rule_id) do
      [{^rule_id, gleam_rule}] ->
        {:ok, gleam_rule}

      [] ->
        load_rule_from_db(rule_id)
    end
  end

  @doc "Get all active rules for a category"
  def get_rules_by_category(category) do
    GenServer.call(__MODULE__, {:get_by_category, category})
  end

  @doc "Find rules by semantic similarity (pgvector)"
  def find_similar_rules(embedding, limit \\ 5) do
    GenServer.call(__MODULE__, {:find_similar, embedding, limit})
  end

  @doc "Reload all rules from DB (after evolution)"
  def reload_rules do
    GenServer.cast(__MODULE__, :reload)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table for rule cache
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])

    # Load all active rules
    load_all_rules()

    # Schedule periodic refresh
    schedule_refresh()

    {:ok, %{last_refresh: DateTime.utc_now()}}
  end

  @impl true
  def handle_call({:get_by_category, category}, _from, state) do
    rules =
      @table
      |> :ets.tab2list()
      |> Enum.filter(fn {_id, rule} ->
        rule_category(rule) == category
      end)
      |> Enum.map(fn {_id, rule} -> rule end)

    {:reply, rules, state}
  end

  @impl true
  def handle_call({:find_similar, embedding, limit}, _from, state) do
    # Use pgvector for semantic similarity search
    similar_rules =
      from(r in Rule,
        where: r.status == "active",
        order_by: fragment("embedding <-> ?", ^embedding),
        limit: ^limit
      )
      |> Repo.all()
      |> Enum.map(&to_gleam_rule/1)

    {:reply, similar_rules, state}
  end

  @impl true
  def handle_cast(:reload, state) do
    Logger.info("Reloading rules from database")
    load_all_rules()
    {:noreply, %{state | last_refresh: DateTime.utc_now()}}
  end

  @impl true
  def handle_info(:refresh, state) do
    load_all_rules()
    schedule_refresh()
    {:noreply, %{state | last_refresh: DateTime.utc_now()}}
  end

  ## Private Functions

  defp load_all_rules do
    from(r in Rule, where: r.status == "active")
    |> Repo.all()
    |> Enum.each(fn rule ->
      gleam_rule = to_gleam_rule(rule)
      :ets.insert(@table, {rule.id, gleam_rule})
    end)
  end

  defp load_rule_from_db(rule_id) do
    case Repo.get(Rule, rule_id) do
      nil ->
        {:error, :not_found}

      rule ->
        gleam_rule = to_gleam_rule(rule)
        :ets.insert(@table, {rule.id, gleam_rule})
        {:ok, gleam_rule}
    end
  end

  defp to_gleam_rule(rule) do
    # Convert Ecto struct to execution-compatible map
    base = %{
      id: rule.id,
      name: rule.name,
      description: rule.description || "",
      category: category_to_gleam(rule.category),
      confidence_threshold: rule.confidence_threshold,
      execution_type: rule.execution_type || :elixir_patterns
    }

    # Add type-specific fields
    case rule.execution_type do
      :lua_script ->
        Map.put(base, :lua_script, rule.lua_script)

      _ ->
        Map.put(base, :patterns, Enum.map(rule.patterns || [], &pattern_to_gleam/1))
    end
  end

  defp category_to_gleam(category) do
    case category do
      :code_quality -> {:CodeQuality}
      :performance -> {:Performance}
      :security -> {:Security}
      :refactoring -> {:Refactoring}
      :vision -> {:Vision}
      :epic -> {:Epic}
      :feature -> {:Feature}
      :capability -> {:Capability}
      :story -> {:Story}
    end
  end

  defp pattern_to_gleam(%{"type" => "regex", "expression" => expr, "weight" => weight}) do
    {:RegexPattern, expr, weight}
  end

  defp pattern_to_gleam(%{"type" => "llm", "prompt" => prompt, "weight" => weight}) do
    {:LLMPattern, prompt, weight}
  end

  defp pattern_to_gleam(%{
         "type" => "metric",
         "metric" => metric,
         "threshold" => threshold,
         "weight" => weight
       }) do
    {:MetricPattern, metric, threshold, weight}
  end

  defp rule_category(gleam_rule) do
    # Extract category from Gleam tuple
    case gleam_rule.category do
      {:CodeQuality} -> :code_quality
      {:Performance} -> :performance
      {:Security} -> :security
      {:Refactoring} -> :refactoring
      {:Vision} -> :vision
      {:Epic} -> :epic
      {:Feature} -> :feature
      {:Capability} -> :capability
      {:Story} -> :story
    end
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end
end
