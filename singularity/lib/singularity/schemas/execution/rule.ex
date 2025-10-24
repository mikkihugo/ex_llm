defmodule Singularity.Execution.Autonomy.Rule do
  @moduledoc """
  Ecto schema for evolvable rules stored in Postgres.

  Rules are data, not code. Agents can evolve rules through consensus.

  ---

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Execution.Autonomy.Rule",
    "purpose": "Ecto schema for evolvable agent behavior rules with pgvector embeddings and Lua support",
    "role": "schema",
    "layer": "domain_services",
    "alternatives": {
      "Singularity.Execution.Autonomy.RuleLoader": "Use Rule for schema definition; RuleLoader for querying/caching",
      "Singularity.Execution.Autonomy.RuleEngine": "Rule is data; RuleEngine executes rule logic",
      "Hardcoded Rules": "Rules-as-data enables hot-reload, consensus evolution, and A/B testing"
    },
    "disambiguation": {
      "vs_rule_loader": "Rule is Ecto schema; RuleLoader is the cache service",
      "vs_rule_engine": "Rule defines structure; RuleEngine evaluates conditions/actions",
      "vs_hardcoded": "Rules stored in DB can evolve via agent consensus without recompiling"
    }
  }
  ```

  ### Architecture (Mermaid)

  ```mermaid
  graph TB
      Agent[Agent Consensus] -->|1. propose evolution| Evolution[RuleEvolutionProposal]
      Evolution -->|2. vote & approve| Rule[Rule Schema]
      Rule -->|3. store| DB[PostgreSQL agent_behavior_confidence_rules]
      DB -->|4. with embedding| Vector[pgvector Semantic Search]

      RuleLoader[RuleLoader] -->|5. load| DB
      RuleEngine[RuleEngine] -->|6. execute| Rule

      Rule -->|Lua scripts| LuaVM[Lua VM Hot-Reload]
      Rule -->|Elixir patterns| Patterns[Pattern Matching]

      style Rule fill:#90EE90
      style DB fill:#FFD700
      style Vector fill:#87CEEB
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Ecto.Schema
      function: schema/2
      purpose: Define database table structure and fields
      critical: true

    - module: Ecto.Changeset
      function: cast/3, validate_*/2
      purpose: Validate rule creation and evolution changes
      critical: true

    - module: Pgvector.Ecto.Vector
      function: type definition
      purpose: Store embeddings for semantic rule search
      critical: true

  called_by:
    - module: Singularity.Execution.Autonomy.RuleLoader
      purpose: Load and cache rules from database
      frequency: high

    - module: Singularity.Execution.Autonomy.RuleEngine
      purpose: Read rule definitions for execution
      frequency: high

    - module: Agent Consensus System
      purpose: Create/update rules via evolution proposals
      frequency: low

  depends_on:
    - PostgreSQL agent_behavior_confidence_rules table (MUST exist)
    - Pgvector extension (for embedding field)
    - Ecto.Repo (for database operations)

  supervision:
    supervised: false
    reason: "Pure Ecto schema - not a process, no supervision needed"
  ```

  ### Anti-Patterns

  #### ❌ DO NOT hardcode rule logic in Elixir modules
  **Why:** Rules-as-data enables hot-reload, evolution, and A/B testing without recompilation.
  ```elixir
  # ❌ WRONG - Hardcoded rule
  defmodule MyRule do
    def evaluate(code) do
      code.complexity > 10
    end
  end

  # ✅ CORRECT - Data-driven rule
  %Rule{
    name: "complexity-check",
    condition: %{type: "metric", metric: "complexity", threshold: 10},
    confidence_threshold: 0.8
  }
  ```

  #### ❌ DO NOT bypass changesets for rule creation
  ```elixir
  # ❌ WRONG - Direct struct creation
  %Rule{name: "test", category: "quality"} |> Repo.insert!()

  # ✅ CORRECT - Use changeset for validation
  %Rule{}
  |> Rule.changeset(%{name: "test", category: "quality"})
  |> Repo.insert()
  ```

  #### ❌ DO NOT modify rules without evolution tracking
  **Why:** Evolution proposals track consensus voting and rule history.
  ```elixir
  # ❌ WRONG - Direct update
  rule |> Ecto.Changeset.change(%{confidence_threshold: 0.9}) |> Repo.update!()

  # ✅ CORRECT - Use evolution_changeset with proposal
  rule
  |> Rule.evolution_changeset(%{confidence_threshold: 0.9})
  |> Repo.update()
  # (Creates RuleEvolutionProposal record automatically)
  ```

  #### ❌ DO NOT use :elixir_patterns without defining patterns
  ```elixir
  # ❌ WRONG - No patterns defined
  %Rule{execution_type: :elixir_patterns, condition: %{}}

  # ✅ CORRECT - Define patterns in condition
  %Rule{
    execution_type: :elixir_patterns,
    condition: %{
      patterns: [
        %{type: "regex", expression: "TODO:", weight: 0.5},
        %{type: "llm", prompt: "Is this tech debt?", weight: 0.5}
      ]
    }
  }
  ```

  ### Search Keywords

  rule schema, evolvable rules, agent behavior, confidence rules, ecto schema,
  pgvector embeddings, lua scripts, hot reload, consensus evolution, rule governance,
  data not code, semantic rule search, autonomous agents, rule versioning, rule proposals
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "agent_behavior_confidence_rules" do
    field :name, :string
    field :description, :string
    field :category, :string

    # Rule definition (stored as JSON in DB)
    field :condition, :map
    field :action, :map
    field :metadata, :map

    # Configuration
    field :confidence_threshold, :float
    field :priority, :integer

    # Semantic search
    field :embedding, Pgvector.Ecto.Vector

    # Lua script support (hot-reload business logic!)
    field :execution_type, Ecto.Enum,
      values: [:elixir_patterns, :lua_script],
      default: :elixir_patterns

    field :lua_script, :string

    # Evolution & Governance
    field :version, :integer
    belongs_to :parent_rule, __MODULE__, foreign_key: :parent_id
    field :active, :boolean, default: true

    timestamps(type: :utc_datetime_usec)

    has_many :executions, Singularity.Execution.Autonomy.RuleExecution
    has_many :evolution_proposals, Singularity.Execution.Autonomy.RuleEvolutionProposal
  end

  @doc "Changeset for creating a new rule"
  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [
      :name,
      :description,
      :category,
      :confidence_threshold,
      :condition,
      :action,
      :metadata,
      :priority,
      :embedding,
      :execution_type,
      :lua_script,
      :active
    ])
    |> validate_required([:name, :category])
    |> validate_execution_type()
    |> validate_number(:confidence_threshold,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> unique_constraint(:name)
  end

  @doc "Changeset for evolving a rule"
  def evolution_changeset(rule, attrs) do
    rule
    |> cast(attrs, [:condition, :action, :metadata, :confidence_threshold, :embedding])
    |> validate_required([:condition])
    |> increment_evolution_count()
  end

  # Validate execution type and required fields
  defp validate_execution_type(changeset) do
    case get_field(changeset, :execution_type) do
      :elixir_patterns ->
        changeset

      :lua_script ->
        validate_lua_script(changeset)

      nil ->
        # Default to elixir_patterns
        put_change(changeset, :execution_type, :elixir_patterns)
    end
  end

  defp validate_lua_script(changeset) do
    case get_field(changeset, :lua_script) do
      nil ->
        add_error(changeset, :lua_script, "cannot be nil for lua_script execution type")

      "" ->
        add_error(changeset, :lua_script, "cannot be empty for lua_script execution type")

      script when is_binary(script) ->
        # Optionally validate Lua syntax here
        changeset

      _ ->
        add_error(changeset, :lua_script, "must be a string")
    end
  end

  defp valid_pattern?(%{"type" => type, "weight" => weight})
       when type in ["regex", "llm", "metric", "dependency", "semantic"] and
              is_number(weight) do
    true
  end

  defp valid_pattern?(_), do: false

  defp increment_evolution_count(changeset) do
    current = get_field(changeset, :evolution_count) || 0
    put_change(changeset, :evolution_count, current + 1)
  end
end
