defmodule Singularity.AnalysisSuite do
  @moduledoc """
  Analysis Suite Integration - Connects Rust analysis-suite to Elixir unified system

  This module provides NIF-based integration between the Rust analysis-suite and the existing
  Elixir unified system, avoiding redundancy by leveraging existing infrastructure.

  ## Communication Pattern: NIF Bindings (like EmbeddingEngine)

  - **Direct function calls** from Elixir to Rust (no NATS overhead)
  - **Synchronous execution** for immediate results  
  - **Shared memory** for efficient data transfer
  - **Same pattern** as existing `EmbeddingEngine` NIF

  ## Integration Points:

  - Uses existing `EmbeddingEngine` (Qodo-Embed + Jina v3) via NIF
  - Uses existing `TemplateStore` (Jinja2 templates) via Elixir calls
  - Uses existing `LLM.Provider` (Claude/Gemini/etc) via Elixir calls
  - Uses existing `SemanticCodeSearch` (pgvector) via Elixir calls
  - Uses existing `PackageAndCodebaseSearch` (unified search) via Elixir calls

  ## Usage:

      # Unified code intelligence - analyze and generate
      {:ok, result} = AnalysisSuite.unified_code_intelligence(
        "Create async worker with error handling",
        "/path/to/codebase",
        "elixir"
      )

      # Just analysis
      {:ok, analysis} = AnalysisSuite.analyze_code("/path/to/codebase", "elixir")

      # Find similar code
      {:ok, similar} = AnalysisSuite.find_similar_code("async worker", "elixir")

      # Get package recommendations
      {:ok, packages} = AnalysisSuite.get_package_recommendations("web scraping", "elixir")

      # Generate code
      {:ok, {code, template}} = AnalysisSuite.generate_code(
        "Create GenServer for cache",
        "elixir",
        similar_code
      )
  """

  require Logger

  # NIF module - will be loaded from Rust
  use Rustler, otp_app: :singularity, crate: :analysis_suite

  @doc """
  Unified code intelligence - analyze and generate using existing systems

  This is the main entry point that combines all existing systems:
  - Analysis using existing analysis-suite
  - Code generation using existing template + LLM system
  - Similar code search using existing semantic search
  - Package recommendations using existing unified search
  """
  @spec unified_code_intelligence(String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, String.t()}
  def unified_code_intelligence(request, codebase_path, language) do
    # Orchestrate calls to existing Elixir systems and Rust NIFs
    with {:ok, analysis} <- analyze_code(codebase_path, language),
         {:ok, similar_code} <- find_similar_code(request, language),
         {:ok, package_recommendations} <- get_package_recommendations(request, language),
         {:ok, {generated_code, template_used}} <- generate_code(request, language, similar_code),
         {:ok, quality_metrics} <- calculate_quality_metrics(generated_code, language) do
      
      # Combine all results into unified response
      result = %{
        analysis: analysis,
        generated_code: generated_code,
        similar_code: similar_code,
        package_recommendations: package_recommendations,
        template_used: template_used,
        quality_metrics: quality_metrics
      }
      
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Analyze code using existing analysis-suite
  """
  @spec analyze_code(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def analyze_code(codebase_path, language) do
    # Call Rust NIF for analysis computation
    case analyze_code_nif(codebase_path, language) do
      {:ok, analysis} -> {:ok, analysis}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Find similar code using existing semantic search
  """
  @spec find_similar_code(String.t(), String.t()) :: {:ok, list(map())} | {:error, String.t()}
  def find_similar_code(query, language) do
    # Use existing SemanticCodeSearch for actual semantic search
    case Singularity.SemanticCodeSearch.search(query, language: language, limit: 5) do
      {:ok, results} -> 
        similar_code = Enum.map(results, fn result ->
          %{
            file_path: result.file_path,
            content: result.content,
            similarity_score: result.similarity,
            language: language
          }
        end)
        {:ok, similar_code}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get package recommendations using existing unified search
  """
  @spec get_package_recommendations(String.t(), String.t()) ::
          {:ok, list(map())} | {:error, String.t()}
  def get_package_recommendations(query, language) do
    # Use existing PackageAndCodebaseSearch for actual package recommendations
    case Singularity.PackageAndCodebaseSearch.hybrid_search(query, codebase_id: "current") do
      {:ok, %{packages: packages}} ->
        package_recommendations = Enum.map(packages, fn package ->
          %{
            package_name: package.package_name,
            ecosystem: package.ecosystem,
            version: package.version,
            quality_score: package.quality_score || 0.8,
            reason: "Recommended based on query analysis"
          }
        end)
        {:ok, package_recommendations}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generate code using existing template + LLM system
  """
  @spec generate_code(String.t(), String.t(), list(map())) ::
          {:ok, {String.t() | nil, String.t() | nil}} | {:error, String.t()}
  def generate_code(request, language, similar_code) do
    # Use existing RAGCodeGenerator for actual code generation
    case Singularity.RAGCodeGenerator.generate(
      task: request,
      language: language,
      top_k: 3
    ) do
      {:ok, code} -> 
        # Get template used (if available)
        template_used = case Singularity.TemplateStore.get_best_for_task(request, language, top_k: 1) do
          {:ok, [template | _]} -> template.id
          _ -> nil
        end
        {:ok, {code, template_used}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculate quality metrics using existing analysis
  """
  @spec calculate_quality_metrics(String.t() | nil, String.t()) ::
          {:ok, map()} | {:error, String.t()}
  def calculate_quality_metrics(code, language) do
    # Call Rust NIF for quality metrics computation
    case calculate_quality_metrics_nif(code, language) do
      {:ok, metrics} -> {:ok, metrics}
      {:error, reason} -> {:error, reason}
    end
  end

  # NIF function stubs - will be implemented in Rust
  defp analyze_code_nif(_codebase_path, _language), do: :erlang.nif_error(:nif_not_loaded)
  defp calculate_quality_metrics_nif(_code, _language), do: :erlang.nif_error(:nif_not_loaded)
end