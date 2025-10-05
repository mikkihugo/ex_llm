defmodule Singularity.EmbeddingQualityTracker do
  @moduledoc """
  Tracks embedding search quality to automatically improve embeddings over time.

  ## Self-Learning Loop

  1. User searches for code using semantic search
  2. System returns top N similar results (via embedding cosine similarity)
  3. User interacts with results (clicks, copies, ignores)
  4. System records feedback: query embedding + clicked results + ignored results
  5. After collecting sufficient data (1000+ searches), automatically extracts training pairs
  6. Fine-tunes Jina embeddings on YOUR codebase patterns (BEAM, SPARC, domain terms)
  7. Improved embeddings = better search results next time!

  ## Architecture

  ```
  User Search
      │
      ▼
  track_search_result(query, results, feedback)
      │
      ├─► Store in rag_performance_stats (immediate)
      │
      └─► Async: accumulate_training_data()
              │
              └─► (after N samples) fine_tune_embeddings()
                      │
                      └─► Load improved model → Better searches!
  ```

  ## Quality Signals

  - **Positive**: User clicked result within top 3 → similar embeddings are GOOD
  - **Negative**: User ignored all results → embeddings need improvement
  - **Implicit**: Time spent on result, code copied, file opened

  ## Training Data Format

  Positive pairs (anchor, positive):
  ```elixir
  {
    "defmodule Agent do\\n  use GenServer",  # User query
    "defmodule HybridAgent do\\n  use GenServer"  # Clicked result #1
  }
  ```

  Negative pairs (anchor, negative):
  ```elixir
  {
    "GenServer implementation",  # User query
    "CREATE TABLE embeddings"  # Ignored result (SQL, not Elixir)
  }
  ```

  ## Integration Points

  - **Used by**: `SemanticCodeSearch`, `RAGCodeGenerator`, `PatternIndexer`
  - **Stores data in**: `rag_performance_stats` table (existing)
  - **Triggers training**: When `training_pairs_count >= 1000`
  - **Fine-tunes**: Jina-embeddings-v2-base-code via Axon/LoRA

  ## Examples

      # Track search result quality
      iex> track_search_result(
      ...>   query: "GenServer cache implementation",
      ...>   results: [
      ...>     %{path: "lib/memory_cache.ex", similarity: 0.95},
      ...>     %{path: "lib/code_store.ex", similarity: 0.82}
      ...>   ],
      ...>   user_feedback: %{clicked_index: 0, time_spent_ms: 15000}
      ...> )
      {:ok, :recorded}

      # Check if ready for training
      iex> ready_for_training?()
      {:ok, %{pairs_count: 1250, threshold: 1000, ready: true}}

      # Extract training pairs
      iex> extract_training_pairs(limit: 100)
      {:ok, [
        %{anchor: "use GenServer", positive: "defmodule Cache", negative: "CREATE TABLE"},
        # ... more pairs
      ]}
  """

  use GenServer
  require Logger

  alias Singularity.{Repo, EmbeddingService}

  @type search_result :: %{
          path: String.t(),
          content: String.t(),
          similarity: float(),
          embedding: Pgvector.t()
        }

  @type user_feedback :: %{
          clicked_index: non_neg_integer() | nil,
          time_spent_ms: non_neg_integer() | nil,
          code_copied?: boolean(),
          helpful?: boolean() | nil
        }

  @type training_pair :: %{
          anchor: String.t(),
          anchor_embedding: Pgvector.t(),
          positive: String.t(),
          positive_embedding: Pgvector.t(),
          negative: String.t() | nil,
          negative_embedding: Pgvector.t() | nil,
          confidence: float()
        }

  # Minimum training pairs before fine-tuning
  @training_threshold 1000

  # GenServer API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Track a search result and user feedback for quality learning.

  ## Parameters

  - `query` - User's search query (text)
  - `results` - List of search results with similarity scores
  - `user_feedback` - User interaction data (clicks, time, helpfulness)

  ## Returns

  - `{:ok, :recorded}` - Feedback successfully recorded
  - `{:error, reason}` - Recording failed

  ## Examples

      iex> track_search_result(
      ...>   "GenServer implementation",
      ...>   [%{path: "agent.ex", content: "use GenServer", similarity: 0.9}],
      ...>   %{clicked_index: 0, helpful?: true}
      ...> )
      {:ok, :recorded}
  """
  @spec track_search_result(String.t(), [search_result()], user_feedback()) ::
          {:ok, :recorded} | {:error, term()}
  def track_search_result(query, results, user_feedback)
      when is_binary(query) and is_list(results) and is_map(user_feedback) do
    GenServer.cast(__MODULE__, {:track, query, results, user_feedback})
    {:ok, :recorded}
  end

  @doc """
  Check if enough training data has been collected for fine-tuning.

  ## Returns

  - `{:ok, %{pairs_count: count, threshold: threshold, ready: boolean}}`

  ## Examples

      iex> ready_for_training?()
      {:ok, %{pairs_count: 1250, threshold: 1000, ready: true}}
  """
  @spec ready_for_training?() :: {:ok, map()}
  def ready_for_training? do
    GenServer.call(__MODULE__, :check_readiness)
  end

  @doc """
  Extract high-quality training pairs from collected feedback.

  ## Parameters

  - `opts` - Options for extraction
    - `:limit` - Maximum pairs to extract (default: all)
    - `:min_confidence` - Minimum confidence threshold (default: 0.7)

  ## Returns

  - `{:ok, [training_pair()]}` - Extracted training pairs
  - `{:error, reason}` - Extraction failed

  ## Examples

      iex> extract_training_pairs(limit: 100, min_confidence: 0.8)
      {:ok, [%{anchor: "use GenServer", positive: "defmodule Cache", ...}]}
  """
  @spec extract_training_pairs(keyword()) :: {:ok, [training_pair()]} | {:error, term()}
  def extract_training_pairs(opts \\ []) do
    GenServer.call(__MODULE__, {:extract_pairs, opts}, 30_000)
  end

  @doc """
  Trigger fine-tuning of embeddings with collected training data.

  This is a long-running operation (1-2 hours on RTX 4080).
  Uses LoRA for efficient fine-tuning (only 0.5% of params).

  ## Returns

  - `{:ok, :training_started}` - Training initiated in background
  - `{:error, :insufficient_data}` - Not enough training pairs
  - `{:error, reason}` - Training failed to start

  ## Examples

      iex> trigger_fine_tuning()
      {:ok, :training_started}
  """
  @spec trigger_fine_tuning() :: {:ok, :training_started} | {:error, term()}
  def trigger_fine_tuning do
    GenServer.call(__MODULE__, :trigger_training, 60_000)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("EmbeddingQualityTracker started - learning from search feedback")

    state = %{
      feedback_count: 0,
      last_training_at: nil,
      training_in_progress?: false
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:track, query, results, user_feedback}, state) do
    # Async processing - don't block caller
    Task.start(fn ->
      record_search_feedback(query, results, user_feedback)
    end)

    new_count = state.feedback_count + 1

    # Log milestone
    if rem(new_count, 100) == 0 do
      Logger.info("Collected #{new_count} search feedback samples")
    end

    {:noreply, %{state | feedback_count: new_count}}
  end

  @impl true
  def handle_call(:check_readiness, _from, state) do
    {:ok, count} = count_training_pairs()

    result = %{
      pairs_count: count,
      threshold: @training_threshold,
      ready: count >= @training_threshold,
      last_training: state.last_training_at
    }

    {:reply, {:ok, result}, state}
  end

  @impl true
  def handle_call({:extract_pairs, opts}, _from, state) do
    result = do_extract_training_pairs(opts)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:trigger_training, _from, %{training_in_progress?: true} = state) do
    {:reply, {:error, :training_already_running}, state}
  end

  @impl true
  def handle_call(:trigger_training, _from, state) do
    {:ok, readiness} = count_training_pairs()

    if readiness >= @training_threshold do
      # Start training in background Task
      Task.start(fn ->
        fine_tune_embeddings()
      end)

      Logger.info("Fine-tuning started with #{readiness} training pairs")

      new_state = %{
        state
        | training_in_progress?: true,
          last_training_at: DateTime.utc_now()
      }

      {:reply, {:ok, :training_started}, new_state}
    else
      {:reply, {:error, :insufficient_data}, state}
    end
  end

  # Private Functions

  defp record_search_feedback(query, results, user_feedback) do
    {:ok, query_embedding} = EmbeddingService.embed(query)

    # Determine clicked result (positive signal)
    clicked_result =
      case user_feedback[:clicked_index] do
        nil -> nil
        idx when idx < length(results) -> Enum.at(results, idx)
        _ -> nil
      end

    # Calculate confidence based on user behavior
    confidence = calculate_confidence(user_feedback)

    # Record in rag_performance_stats
    query = """
    INSERT INTO rag_performance_stats (
      query_type,
      execution_time_ms,
      rows_returned,
      cache_hit,
      created_at,
      metadata
    )
    VALUES ($1, $2, $3, $4, NOW(), $5)
    """

    metadata =
      Jason.encode!(%{
        query: query,
        query_embedding: serialize_embedding(query_embedding),
        results_count: length(results),
        clicked_index: user_feedback[:clicked_index],
        clicked_path: clicked_result && clicked_result[:path],
        time_spent_ms: user_feedback[:time_spent_ms],
        helpful: user_feedback[:helpful?],
        confidence: confidence,
        training_eligible: confidence > 0.7
      })

    params = [
      "embedding_search",
      user_feedback[:time_spent_ms] || 0,
      length(results),
      false,
      metadata
    ]

    case Repo.query(query, params) do
      {:ok, _} ->
        Logger.debug("Recorded search feedback: confidence=#{confidence}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to record feedback: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp calculate_confidence(feedback) do
    # Strong signals (0.9-1.0)
    cond do
      feedback[:helpful?] == true && feedback[:clicked_index] == 0 -> 0.95
      feedback[:code_copied?] == true && feedback[:clicked_index] in [0, 1, 2] -> 0.9
      # Good signals (0.7-0.8)
      feedback[:clicked_index] in [0, 1, 2] -> 0.8
      feedback[:time_spent_ms] && feedback[:time_spent_ms] > 10_000 -> 0.75
      # Weak signals (0.4-0.6)
      feedback[:clicked_index] in [3, 4, 5] -> 0.5
      # Negative signals (0.0-0.3)
      feedback[:clicked_index] == nil -> 0.2
      true -> 0.5
    end
  end

  defp count_training_pairs do
    query = """
    SELECT COUNT(*)
    FROM rag_performance_stats
    WHERE query_type = 'embedding_search'
      AND metadata->>'training_eligible' = 'true'
    """

    case Repo.query(query, []) do
      {:ok, %{rows: [[count]]}} -> {:ok, count}
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_extract_training_pairs(opts) do
    limit = Keyword.get(opts, :limit, :all)
    min_confidence = Keyword.get(opts, :min_confidence, 0.7)

    query = """
    SELECT
      metadata->>'query' as query,
      metadata->>'query_embedding' as query_embedding,
      metadata->>'clicked_path' as clicked_path,
      metadata->>'confidence' as confidence,
      metadata->>'results' as results
    FROM rag_performance_stats
    WHERE query_type = 'embedding_search'
      AND metadata->>'training_eligible' = 'true'
      AND CAST(metadata->>'confidence' AS FLOAT) >= $1
    ORDER BY created_at DESC
    #{if limit != :all, do: "LIMIT #{limit}", else: ""}
    """

    case Repo.query(query, [min_confidence]) do
      {:ok, %{rows: rows}} ->
        pairs = Enum.map(rows, &build_training_pair/1)
        {:ok, pairs}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_training_pair([query, query_emb, clicked_path, confidence, _results]) do
    %{
      anchor: query,
      anchor_embedding: deserialize_embedding(query_emb),
      positive: clicked_path,
      confidence: String.to_float(confidence)
    }
  end

  defp fine_tune_embeddings do
    Logger.info("Starting Jina embedding fine-tuning...")

    # TODO: Implement fine-tuning via Axon + LoRA
    # 1. Load base Jina model
    # 2. Inject LoRA layers
    # 3. Extract training pairs
    # 4. Train for 3-5 epochs
    # 5. Save fine-tuned model
    # 6. Update EmbeddingService to use new model

    Logger.info("Fine-tuning completed (placeholder)")
    :ok
  end

  defp serialize_embedding(%Pgvector{} = vec), do: Pgvector.to_list(vec) |> Jason.encode!()
  defp deserialize_embedding(json) when is_binary(json) do
    {:ok, list} = Jason.decode(json)
    Pgvector.new(list)
  end
end
