defmodule Singularity.CodeGeneration.Generators.CodeGeneratorImpl do
  @moduledoc """
  Code Generator Implementation - Wraps CodeGenerator into unified GeneratorType behavior.

  Provides high-level code generation orchestration with RAG + Quality + Execution Strategy.

  ## Features

  - ✅ RAG-powered pattern discovery from codebases
  - ✅ Quality template loading and enforcement
  - ✅ Adaptive method selection (T5-small local vs LLM API)
  - ✅ T5-small ONNX model support (when available)
  - ✅ LLM API fallback (Gemini/Claude)
  - ✅ Validation with retry logic
  - ✅ Complexity-based model selection

  ## Example

      iex> GenerationOrchestrator.generate(
      ...>   %{spec: "Create a GenServer for caching"},
      ...>   generators: [:code_generator]
      ...> )
      {:ok, %{code_generator: {:ok, "defmodule ..." }}}
  """

  @behaviour Singularity.CodeGeneration.Orchestrator.GeneratorType
  require Logger
  alias Singularity.CodeGeneration.Implementations.CodeGenerator

  @impl true
  def generator_type, do: :code_generator

  @impl true
  def description do
    "Generate code with RAG + Quality + Strategy selection (T5 local vs LLM API)"
  end

  @impl true
  def capabilities do
    [
      "rag_pattern_discovery",
      "quality_enforcement",
      "adaptive_method_selection",
      "t5_local_generation",
      "llm_api_fallback",
      "validation_with_retry",
      "complexity_based_selection"
    ]
  end

  @impl true
  def generate(spec, _opts \\ []) when is_map(spec) do
    try do
      # Unpack spec fields for CodeGenerator.generate/2
      task = spec[:spec] || spec[:task] || ""

      # Extract CodeGenerator-specific options
      code_opts =
        [
          language: spec[:language] || _opts[:language],
          method: _opts[:method],
          quality: _opts[:quality],
          use_rag: _opts[:use_rag],
          top_k: _opts[:top_k],
          repos: _opts[:repos],
          validate: _opts[:validate],
          max_retries: _opts[:max_retries],
          complexity: _opts[:complexity]
        ]
        |> Enum.filter(fn {_k, v} -> v != nil end)

      Logger.debug("CodeGeneratorImpl: generating for task", task: task, _opts: code_opts)
      CodeGenerator.generate(task, code_opts)
    rescue
      e ->
        Logger.error("Code generation failed", error: inspect(e))
        {:error, :generation_failed}
    end
  end

  @impl true
  def learn_from_generation(result) do
    case result do
      {:ok, code} when is_binary(code) ->
        Logger.info("Code generation was successful")
        :ok

      {:error, reason} ->
        Logger.warning("Code generation failed", reason: inspect(reason))
        :ok

      _ ->
        :ok
    end
  end
end
