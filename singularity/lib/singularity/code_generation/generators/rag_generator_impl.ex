defmodule Singularity.CodeGeneration.Generators.RAGGeneratorImpl do
  @moduledoc """
  RAG Code Generator Implementation - Wraps RAGCodeGenerator into unified GeneratorType behavior.

  Provides Retrieval-Augmented Generation (RAG) for code using semantic search over your codebases.

  ## Features

  - ✅ Semantic search for similar code patterns (pgvector + embeddings)
  - ✅ Multi-codebase search across multiple repositories
  - ✅ Ranking by relevance and quality signals
  - ✅ Integration with LLM for final generation
  - ✅ Context window optimization (limits to top_k results)
  - ✅ Learning from successful patterns

  ## Example

      iex> GenerationOrchestrator.generate(
      ...>   %{spec: "Create a GenServer for caching"},
      ...>   generators: [:rag]
      ...> )
      {:ok, %{rag: {:ok, "defmodule ..." }}}
  """

  @behaviour Singularity.CodeGeneration.Orchestrator.GeneratorType
  require Logger
  alias Singularity.CodeGeneration.Implementations.RAGCodeGenerator

  @impl true
  def generator_type, do: :rag

  @impl true
  def description do
    "Generate code using Retrieval-Augmented Generation (RAG) from your codebase"
  end

  @impl true
  def capabilities do
    [
      "semantic_search",
      "multi_codebase_search",
      "relevance_ranking",
      "context_optimization",
      "llm_integration",
      "pattern_learning"
    ]
  end

  @impl true
  def generate(spec, opts \\ []) when is_map(spec) do
    try do
      # Unpack spec fields for RAGCodeGenerator.generate/2
      task = spec[:spec] || spec[:task] || ""

      # Extract RAG-specific options
      rag_opts =
        [
          language: spec[:language] || opts[:language],
          top_k: opts[:top_k] || 5,
          repos: opts[:repos],
          quality_level: opts[:quality],
          complexity: opts[:complexity]
        ]
        |> Enum.filter(fn {_k, v} -> v != nil end)

      Logger.debug("RAGGeneratorImpl: generating with RAG", task: task, _opts: rag_opts)
      RAGCodeGenerator.generate(task, rag_opts)
    rescue
      e ->
        Logger.error("RAG code generation failed", error: inspect(e))
        {:error, :generation_failed}
    end
  end

  @impl true
  def learn_from_generation(result) do
    case result do
      {:ok, code} when is_binary(code) ->
        Logger.info("RAG generation was successful")
        # Could track successful RAG retrievals for better future results
        :ok

      {:error, reason} ->
        Logger.warning("RAG generation failed", reason: inspect(reason))
        :ok

      _ ->
        :ok
    end
  end
end
