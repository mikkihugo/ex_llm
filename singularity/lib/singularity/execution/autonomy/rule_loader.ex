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

  ---

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Execution.Autonomy.RuleLoader",
    "purpose": "PostgreSQL-backed rule caching system with ETS for O(1) access and hot-reload capability",
    "role": "cache_service",
    "layer": "infrastructure",
    "alternatives": {
      "Singularity.Execution.Autonomy.Rule": "Use RuleLoader for querying rules; Rule is the Ecto schema",
      "Singularity.Execution.Autonomy.RuleEngine": "RuleEngine evaluates rules; RuleLoader provides the rules",
      "Direct DB Access": "RuleLoader provides caching, semantic search, and refresh mechanism"
    },
    "disambiguation": {
      "vs_rule_schema": "RuleLoader is the SERVICE that loads/caches Rules (Ecto schema)",
      "vs_rule_engine": "RuleLoader provides data; RuleEngine executes logic",
      "vs_direct_db": "Adds ETS caching layer + pgvector semantic search + auto-refresh"
    }
  }
  ```

  ### Architecture (Mermaid)

  ```mermaid
  graph TB
      Agent[Agent / RuleEngine] -->|1. get_rule/1| Loader[RuleLoader]
      Loader -->|2. check| ETS[ETS Cache :rule_cache]
      ETS -->|3a. hit| Loader
      ETS -->|3b. miss| DB[PostgreSQL]
      DB -->|4. fetch + embed| Loader
      Loader -->|5. insert| ETS
      Loader -->|6. return rule| Agent

      Timer[5min Timer] -->|refresh| Loader
      Evolution[Rule Evolution] -->|reload_rules/0| Loader
      Loader -->|query| DB

      style Loader fill:#90EE90
      style ETS fill:#FFD700
      style DB fill:#87CEEB
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Singularity.Repo
      function: all/1
      purpose: Load rules from PostgreSQL on startup and refresh
      critical: true

    - module: Singularity.Execution.Autonomy.Rule
      function: Ecto queries
      purpose: Query rules by ID, category, semantic similarity
      critical: true

    - module: :ets
      function: lookup/2, insert/2, tab2list/1
      purpose: Fast O(1) cache access with read concurrency
      critical: true

  called_by:
    - module: Singularity.Execution.Autonomy.RuleEngine
      purpose: Fetch rules for confidence-based evaluation
      frequency: high

    - module: Singularity.Agents.*
      purpose: Get rules for autonomous decision making
      frequency: high

    - module: Evolution Consensus
      purpose: Reload rules after agent voting updates
      frequency: low

  depends_on:
    - Singularity.Repo (MUST start first - database access)
    - PostgreSQL agent_behavior_confidence_rules table (MUST exist)
    - ETS (built-in, always available)

  supervision:
    supervised: true
    reason: "GenServer managing ETS cache lifecycle, must restart on crash to rebuild cache"
  ```

  ### Data Flow (Mermaid Sequence)

  ```mermaid
  sequenceDiagram
      participant Agent
      participant RuleLoader
      participant ETS
      participant DB as PostgreSQL

      Note over RuleLoader: Startup
      RuleLoader->>DB: load_all_rules()
      DB-->>RuleLoader: [active rules]
      RuleLoader->>ETS: insert all rules
      RuleLoader->>RuleLoader: schedule_refresh()

      Note over Agent: Runtime - Cache Hit
      Agent->>RuleLoader: get_rule("quality-check")
      RuleLoader->>ETS: lookup("quality-check")
      ETS-->>RuleLoader: {:ok, cached_rule}
      RuleLoader-->>Agent: {:ok, rule}

      Note over Agent: Runtime - Cache Miss
      Agent->>RuleLoader: get_rule("new-rule")
      RuleLoader->>ETS: lookup("new-rule")
      ETS-->>RuleLoader: []
      RuleLoader->>DB: Repo.get(Rule, "new-rule")
      DB-->>RuleLoader: rule struct
      RuleLoader->>ETS: insert("new-rule", rule)
      RuleLoader-->>Agent: {:ok, rule}

      Note over Agent: After Evolution
      Agent->>RuleLoader: reload_rules()
      RuleLoader->>DB: query active rules
      DB-->>RuleLoader: [updated rules]
      RuleLoader->>ETS: update cache
      RuleLoader-->>Agent: :ok
  ```

  ### Anti-Patterns

  #### ❌ DO NOT create "RuleCache" or "RuleFetcher" modules
  **Why:** RuleLoader already provides caching AND fetching with ETS + PostgreSQL.
  **Use instead:** Call RuleLoader.get_rule/1 directly.

  #### ❌ DO NOT bypass cache and query database directly
  ```elixir
  # ❌ WRONG - Bypassing cache
  rule = Repo.get(Rule, rule_id)

  # ✅ CORRECT - Use cached access
  {:ok, rule} = RuleLoader.get_rule(rule_id)
  ```

  #### ❌ DO NOT access ETS table directly
  ```elixir
  # ❌ WRONG - Direct ETS access
  :ets.lookup(:rule_cache, rule_id)

  # ✅ CORRECT - Use public API
  RuleLoader.get_rule(rule_id)
  ```

  #### ❌ DO NOT forget to reload rules after evolution
  ```elixir
  # ❌ WRONG - Update DB but cache is stale
  Repo.update!(rule_changeset)

  # ✅ CORRECT - Update DB and reload cache
  Repo.update!(rule_changeset)
  RuleLoader.reload_rules()
  ```

  ### Search Keywords

  rule loader, rule cache, ets cache, hot reload, evolvable rules,
  agent autonomy, confidence rules, postgresql cache, semantic search,
  pgvector, rule evolution, consensus voting, data not code, o1 access
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

    # Try to load rules, but gracefully degrade if database is unavailable
    case load_all_rules_safely() do
      :ok ->
        Logger.info("Rules loaded successfully")
        schedule_refresh()
        {:ok, %{last_refresh: DateTime.utc_now()}}

      {:error, reason} ->
        Logger.warning("Could not load rules from database (will retry): #{inspect(reason)}")
        # Start with empty cache and schedule refresh to try again
        schedule_refresh()
        {:ok, %{last_refresh: DateTime.utc_now(), db_error: reason}}
    end
  end

  defp load_all_rules_safely do
    try do
      load_all_rules()
      :ok
    rescue
      e ->
        {:error, "Failed to load rules: #{inspect(e.__struct__)}: #{Exception.message(e)}"}
    end
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
    from(r in Rule, where: r.active == true)
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
