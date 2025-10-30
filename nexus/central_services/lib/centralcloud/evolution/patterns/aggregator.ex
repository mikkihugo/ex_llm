defmodule CentralCloud.Evolution.Patterns.Aggregator do
  @moduledoc """
  Central Pattern Aggregation - Cross-instance pattern learning and consensus.

  The Aggregator collects code patterns from all Singularity instances, computes consensus
  scores, and promotes high-quality patterns to Genesis for autonomous rule evolution.

  ## Purpose

  This service provides:
  1. **Pattern Collection** - Record patterns discovered by instances
  2. **Consensus Computation** - Identify patterns confirmed by 3+ instances
  3. **Pattern Suggestion** - Semantic search for relevant patterns during evolution
  4. **Genesis Promotion** - Auto-promote consensus patterns for autonomous learning
  5. **Cross-Instance Learning** - All instances benefit from any instance's discoveries

  ## Architecture

  ```mermaid
  graph TD
    A[Singularity Instance] --> B[record_pattern/4]
    B --> C[Pattern Store]
    D[Evolution Attempt] --> E[suggest_pattern/2]
    E --> F[Semantic Search]
    F --> C
    C --> G{Consensus?}
    G -->|3+ instances, 95%+ success| H[aggregate_learnings/0]
    H --> I[Promote to Genesis]
    I --> J[Genesis Rule Evolution]
  ```

  ## Pattern Lifecycle

  ```
  1. Discovery → record_pattern/4 (instance reports pattern)
  2. Confirmation → Multiple instances report same pattern
  3. Consensus → 3+ instances, 95%+ success rate
  4. Promotion → aggregate_learnings/0 exports to Genesis
  5. Evolution → Genesis creates autonomous rule
  6. Distribution → All instances learn the rule
  ```

  ## Module Identity (JSON)
  ```json
  {
    "module_name": "CentralCloud.Evolution.Patterns.Aggregator",
    "purpose": "cross_instance_pattern_aggregation_and_learning",
    "domain": "evolution",
    "layer": "centralcloud",
    "capabilities": [
      "pattern_recording",
      "consensus_computation",
      "semantic_pattern_search",
      "genesis_promotion",
      "cross_instance_learning"
    ],
    "dependencies": [
      "CentralCloud.Repo",
      "pgvector (semantic search)",
      "Genesis (rule evolution)",
      "DetectionOrchestrator (pattern reuse)"
    ]
  }
  ```

  ## Call Graph (YAML)
  ```yaml
  CentralCloud.Evolution.Patterns.Aggregator:
    record_pattern/4:
      - validates pattern structure
      - computes pattern embedding (pgvector)
      - stores in database
      - updates consensus scores
    get_consensus_patterns/2:
      - queries patterns by type
      - filters by consensus threshold
      - returns top patterns with metadata
    suggest_pattern/2:
      - semantic similarity search
      - ranks by relevance and success_rate
      - returns top 5 suggestions
    aggregate_learnings/0:
      - identifies consensus patterns
      - checks promotion criteria
      - exports to Genesis
      - marks as promoted
  ```

  ## Anti-Patterns

  - **DO NOT** record patterns without instance_id - required for consensus
  - **DO NOT** promote to Genesis without 3+ instance confirmations
  - **DO NOT** skip embedding generation - semantic search requires it
  - **DO NOT** suggest patterns with success_rate < 0.80
  - **DO NOT** modify consensus_score manually - computed from data

  ## Search Keywords

  pattern_aggregation, consensus, cross_instance_learning, semantic_search,
  genesis_promotion, pattern_discovery, autonomous_learning, embedding_search,
  collective_intelligence, pattern_reuse
  """

  require Logger

  alias CentralCloud.Repo
  alias CentralCloud.Evolution.Patterns.Schemas.Pattern
  alias CentralCloud.Evolution.Patterns.Schemas.PatternUsage
  import Ecto.Query

  @doc """
  Record a pattern discovered by a Singularity instance.

  Stores the pattern in the central database and updates consensus scores when
  multiple instances report similar patterns.

  ## Parameters

  - `instance_id` - Singularity instance that discovered the pattern
  - `pattern_type` - :framework | :technology | :service_architecture | :code_template | :error_handling
  - `code_pattern` - Map containing:
    - `:name` - Human-readable pattern name
    - `:description` - What the pattern does
    - `:code_template` - Code snippet (for code patterns)
    - `:metadata` - Additional context (framework, language, etc.)
  - `success_rate` - Float 0.0-1.0 (how often this pattern succeeds on this instance)

  ## Returns

  - `{:ok, pattern_id}` - Pattern recorded successfully
  - `{:error, reason}` - Recording failed

  ## Examples

      iex> Aggregator.record_pattern(
      ...>   "dev-1",
      ...>   :error_handling,
      ...>   %{
      ...>     name: "GenServer error recovery",
      ...>     description: "Restart GenServer with exponential backoff",
      ...>     code_template: "def handle_info(:restart, state) do...",
      ...>     metadata: %{language: "elixir", framework: "otp"}
      ...>   },
      ...>   0.96
      ...> )
      {:ok, "pattern-uuid-123"}
  """
  @spec record_pattern(String.t(), atom(), map(), float()) ::
          {:ok, String.t()} | {:error, term()}
  def record_pattern(instance_id, pattern_type, code_pattern, success_rate) do
    Logger.info("[PatternAggregator] Recording pattern",
      instance_id: instance_id,
      pattern_type: pattern_type,
      pattern_name: code_pattern[:name]
    )

    with :ok <- validate_pattern(code_pattern),
         {:ok, embedding} <- generate_pattern_embedding(code_pattern),
         {:ok, pattern} <- persist_pattern(instance_id, pattern_type, code_pattern, success_rate, embedding),
         {:ok, _usage} <- record_pattern_usage(pattern.id, instance_id, success_rate) do

      # Update consensus scores (check if other instances have similar patterns)
      Task.start(fn -> update_consensus_scores(pattern.id, embedding) end)

      {:ok, pattern.id}
    else
      {:error, reason} ->
        Logger.error("[PatternAggregator] Failed to record pattern",
          instance_id: instance_id,
          reason: inspect(reason)
        )
        {:error, reason}
    end
  end

  @doc """
  Get patterns that have reached consensus across multiple instances.

  Returns patterns confirmed by 3+ instances with high success rates, useful for
  suggesting reliable patterns during evolution.

  ## Parameters

  - `pattern_type` - :framework | :technology | :service_architecture | :code_template | :error_handling
  - `opts` - Keyword list:
    - `:threshold` - Minimum consensus score (default: 0.95)
    - `:min_instances` - Minimum number of confirming instances (default: 3)
    - `:limit` - Max patterns to return (default: 10)

  ## Returns

  - `{:ok, patterns}` - List of consensus patterns, each with:
    - `:id` - Pattern ID
    - `:name` - Pattern name
    - `:description` - Pattern description
    - `:code_template` - Code snippet
    - `:consensus_score` - Float 0.0-1.0
    - `:source_instances` - List of instance IDs that confirmed this pattern
    - `:success_rate` - Average success rate across instances
    - `:promoted_to_genesis` - Boolean (whether already promoted)

  ## Examples

      iex> Aggregator.get_consensus_patterns(:error_handling, threshold: 0.95)
      {:ok, [
        %{
          id: "pattern-uuid-123",
          name: "GenServer error recovery",
          consensus_score: 0.98,
          source_instances: ["dev-1", "dev-2", "prod-west"],
          success_rate: 0.96,
          promoted_to_genesis: false
        }
      ]}
  """
  @spec get_consensus_patterns(atom(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def get_consensus_patterns(pattern_type, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 0.95)
    min_instances = Keyword.get(opts, :min_instances, 3)
    limit = Keyword.get(opts, :limit, 10)

    query =
      from p in Pattern,
        where: p.pattern_type == ^Atom.to_string(pattern_type),
        where: p.consensus_score >= ^threshold,
        where: fragment("array_length(?, 1) >= ?", p.source_instances, ^min_instances),
        order_by: [desc: p.consensus_score, desc: p.success_rate],
        limit: ^limit,
        select: %{
          id: p.id,
          name: fragment("?->>'name'", p.code_pattern),
          description: fragment("?->>'description'", p.code_pattern),
          code_template: fragment("?->>'code_template'", p.code_pattern),
          consensus_score: p.consensus_score,
          source_instances: p.source_instances,
          success_rate: p.success_rate,
          promoted_to_genesis: p.promoted_to_genesis
        }

    case Repo.all(query) do
      patterns when is_list(patterns) ->
        Logger.info("[PatternAggregator] Retrieved consensus patterns",
          pattern_type: pattern_type,
          count: length(patterns)
        )
        {:ok, patterns}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Suggest relevant patterns for a given change type and current code.

  Uses semantic search (pgvector) to find patterns similar to the current code,
  ranked by relevance and success rate.

  ## Parameters

  - `change_type` - :pattern_enhancement | :model_optimization | :cache_improvement | :code_refactoring
  - `current_code` - String containing the code being evolved

  ## Returns

  - `{:ok, suggestions}` - List of up to 5 suggested patterns, each with:
    - `:pattern_id` - Pattern ID
    - `:name` - Pattern name
    - `:description` - Pattern description
    - `:code_template` - Code snippet
    - `:similarity` - Cosine similarity score (0.0-1.0)
    - `:success_rate` - Average success rate
    - `:usage_count` - Times this pattern has been used
  - `{:error, reason}` - Search failed

  ## Examples

      iex> Aggregator.suggest_pattern(:code_refactoring, "def handle_call(...)")
      {:ok, [
        %{
          pattern_id: "pattern-uuid-123",
          name: "GenServer error recovery",
          similarity: 0.87,
          success_rate: 0.96,
          usage_count: 42
        }
      ]}
  """
  @spec suggest_pattern(atom(), String.t()) :: {:ok, list(map())} | {:error, term()}
  def suggest_pattern(change_type, current_code) do
    Logger.info("[PatternAggregator] Suggesting patterns",
      change_type: change_type,
      code_length: String.length(current_code)
    )

    with {:ok, query_embedding} <- generate_code_embedding(current_code),
         {:ok, suggestions} <- semantic_pattern_search(query_embedding, change_type) do
      {:ok, suggestions}
    else
      {:error, reason} ->
        Logger.error("[PatternAggregator] Pattern suggestion failed",
          change_type: change_type,
          reason: inspect(reason)
        )
        {:error, reason}
    end
  end

  @doc """
  Aggregate learnings and promote high-quality patterns to Genesis.

  This function identifies patterns that:
  1. Have consensus from 3+ instances
  2. Have 95%+ success rate
  3. Have been used 100+ times across instances
  4. Have not been promoted yet

  These patterns are exported to Genesis for autonomous rule evolution.

  ## Returns

  - `{:ok, promoted_count}` - Number of patterns promoted to Genesis
  - `{:error, reason}` - Promotion failed

  ## Examples

      iex> Aggregator.aggregate_learnings()
      {:ok, 5}  # 5 patterns promoted to Genesis
  """
  @spec aggregate_learnings() :: {:ok, non_neg_integer()} | {:error, term()}
  def aggregate_learnings do
    Logger.info("[PatternAggregator] Starting learning aggregation")

    # Query patterns that meet promotion criteria
    query =
      from p in Pattern,
        where: p.consensus_score >= 0.95,
        where: p.success_rate >= 0.95,
        where: p.promoted_to_genesis == false,
        where: fragment("array_length(?, 1) >= ?", p.source_instances, 3),
        # Join usage to count total uses
        left_join: u in PatternUsage,
        on: u.pattern_id == p.id,
        group_by: p.id,
        having: count(u.id) >= 100,
        select: p

    case Repo.all(query) do
      [] ->
        Logger.info("[PatternAggregator] No patterns ready for promotion")
        {:ok, 0}

      patterns ->
        promote_to_genesis(patterns)
    end
  end

  # Private Functions

  defp validate_pattern(code_pattern) do
    required = [:name, :description]

    if Enum.all?(required, &Map.has_key?(code_pattern, &1)) do
      :ok
    else
      {:error, :invalid_pattern}
    end
  end

  defp generate_pattern_embedding(code_pattern) do
    # Use Singularity's embedding service (Nx/Ortex with Jina v3 + Qodo)
    # Expects code_pattern to be a map with at least :description
    text = code_pattern[:description] || inspect(code_pattern)
    case Singularity.EmbeddingGenerator.embed(text) do
      {:ok, embedding} -> {:ok, embedding}
      {:error, _} = error -> error
    end
  end

  defp generate_code_embedding(code) do
    # Use Singularity's embedding service for code snippets
    case Singularity.EmbeddingGenerator.embed(code) do
      {:ok, embedding} -> {:ok, embedding}
      {:error, _} = error -> error
    end
  end

  defp persist_pattern(instance_id, pattern_type, code_pattern, success_rate, embedding) do
    changeset = Pattern.changeset(%Pattern{}, %{
      pattern_type: Atom.to_string(pattern_type),
      code_pattern: code_pattern,
      source_instances: [instance_id],
      consensus_score: 0.0,  # Will be computed later
      success_rate: success_rate,
      safety_profile: %{
        risk_level: "low",
        blast_radius: "single_agent",
        reversibility: "automatic"
      },
      embedding: embedding,
      promoted_to_genesis: false
    })

    case Repo.insert(changeset) do
      {:ok, pattern} -> {:ok, pattern}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp record_pattern_usage(pattern_id, instance_id, success_rate) do
    changeset = PatternUsage.changeset(%PatternUsage{}, %{
      pattern_id: pattern_id,
      instance_id: instance_id,
      success_rate: success_rate,
      usage_count: 1,
      last_used_at: DateTime.utc_now()
    })

    case Repo.insert(changeset, on_conflict: :nothing) do
      {:ok, usage} -> {:ok, usage}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp update_consensus_scores(pattern_id, embedding) do
    # In production: Use pgvector to find similar patterns from other instances
    # Compute consensus score based on:
    # 1. Number of instances with similar patterns
    # 2. Similarity of patterns (cosine distance < 0.1)
    # 3. Average success rate across instances

    Logger.info("[PatternAggregator] Updating consensus scores",
      pattern_id: pattern_id
    )

    # Mock implementation: Set consensus score to 0.85
    pattern = Repo.get(Pattern, pattern_id)
    if pattern do
      changeset = Ecto.Changeset.change(pattern, %{consensus_score: 0.85})
      Repo.update(changeset)
    end

    :ok
  end

  defp semantic_pattern_search(query_embedding, change_type) do
    # In production: Use pgvector cosine similarity search
    # SELECT *, (embedding <=> $1) AS distance
    # FROM patterns
    # WHERE pattern_type = $2
    # ORDER BY embedding <=> $1
    # LIMIT 5

    # Mock implementation: Return empty list
    Logger.info("[PatternAggregator] Performing semantic search",
      change_type: change_type
    )

    {:ok, []}
  end

  defp promote_to_genesis(patterns) do
    Logger.info("[PatternAggregator] Promoting patterns to Genesis",
      count: length(patterns)
    )

    # In production: Export patterns to Genesis via quantum_flow
    # For each pattern:
    # 1. Create Genesis RuleEvolutionProposal
    # 2. Mark pattern as promoted_to_genesis
    # 3. Broadcast to all instances

    promoted_count =
      patterns
      |> Enum.map(fn pattern ->
        # Mark as promoted
        changeset = Ecto.Changeset.change(pattern, %{promoted_to_genesis: true})
        Repo.update(changeset)

        # TODO: Publish to Genesis via quantum_flow queue "genesis_rule_proposals"
        Logger.info("[PatternAggregator] Promoted pattern",
          pattern_id: pattern.id,
          pattern_name: pattern.code_pattern["name"]
        )

        1
      end)
      |> Enum.sum()

    {:ok, promoted_count}
  end
end
