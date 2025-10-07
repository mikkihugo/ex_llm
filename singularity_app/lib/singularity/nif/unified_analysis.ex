defmodule Singularity.UnifiedAnalysis do
  @moduledoc """
  Unified Analysis Engine - Main analysis engine for Singularity
  
  Provides direct access to the unified Rust analysis engine for:
  - Codebase analysis
  - Technology detection
  - Dependency parsing
  - Quality analysis
  - Security analysis
  - Architecture analysis
  - Embedding generation
  """

  use Rustler, otp_app: :singularity_app, crate: :singularity_unified

  # Main analysis functions
  def analyze_codebase(_codebase_path, _options \\ []), do: :erlang.nif_error(:nif_not_loaded)
  def detect_technologies(_codebase_path), do: :erlang.nif_error(:nif_not_loaded)
  def parse_dependencies(_codebase_path), do: :erlang.nif_error(:nif_not_loaded)
  def generate_embeddings(_codebase_path, _model_name \\ nil), do: :erlang.nif_error(:nif_not_loaded)
  def analyze_quality(_codebase_path), do: :erlang.nif_error(:nif_not_loaded)
  def analyze_security(_codebase_path), do: :erlang.nif_error(:nif_not_loaded)
  def analyze_architecture(_codebase_path), do: :erlang.nif_error(:nif_not_loaded)
  def get_analysis_summary(_codebase_path), do: :erlang.nif_error(:nif_not_loaded)
  def write_to_database(_result, _database_url), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Analyze entire codebase with comprehensive analysis
  
  ## Examples
  
      iex> Singularity.UnifiedAnalysis.analyze_codebase("/path/to/project")
      %{
        success: true,
        technologies: [...],
        dependencies: [...],
        quality_metrics: %{...},
        security_issues: [...],
        architecture_patterns: [...],
        embeddings: [...],
        mode: "nif"
      }
  """
  def analyze_codebase(codebase_path, options \\ []) do
    analyze_codebase(codebase_path, options)
  end

  @doc """
  Detect technologies and frameworks in codebase
  
  ## Examples
  
      iex> Singularity.UnifiedAnalysis.detect_technologies("/path/to/project")
      [
        %{name: "react", version: "18.2.0", confidence: 0.95, category: "frontend"},
        %{name: "express", version: "4.18.0", confidence: 0.88, category: "backend"}
      ]
  """
  def detect_technologies(codebase_path) do
    detect_technologies(codebase_path)
  end

  @doc """
  Parse dependencies from package files
  
  ## Examples
  
      iex> Singularity.UnifiedAnalysis.parse_dependencies("/path/to/project")
      [
        %{name: "react", version: "^18.2.0", ecosystem: "npm"},
        %{name: "express", version: "~4.18.0", ecosystem: "npm"}
      ]
  """
  def parse_dependencies(codebase_path) do
    parse_dependencies(codebase_path)
  end

  @doc """
  Generate embeddings for semantic search
  
  ## Examples
  
      iex> Singularity.UnifiedAnalysis.generate_embeddings("/path/to/project", "text-embedding-004")
      [
        %{file_path: "src/app.js", embedding: [0.1, 0.2, ...], similarity_score: nil}
      ]
  """
  def generate_embeddings(codebase_path, model_name \\ nil) do
    generate_embeddings(codebase_path, model_name)
  end

  @doc """
  Analyze code quality metrics
  
  ## Examples
  
      iex> Singularity.UnifiedAnalysis.analyze_quality("/path/to/project")
      %{
        complexity_score: 0.75,
        maintainability_score: 0.85,
        test_coverage: 0.80,
        code_duplication: 0.15,
        technical_debt: 0.25
      }
  """
  def analyze_quality(codebase_path) do
    analyze_quality(codebase_path)
  end

  @doc """
  Analyze security vulnerabilities
  
  ## Examples
  
      iex> Singularity.UnifiedAnalysis.analyze_security("/path/to/project")
      [
        %{severity: "high", category: "sql_injection", description: "...", file: "src/db.js", line: 42}
      ]
  """
  def analyze_security(codebase_path) do
    analyze_security(codebase_path)
  end

  @doc """
  Analyze architecture patterns
  
  ## Examples
  
      iex> Singularity.UnifiedAnalysis.analyze_architecture("/path/to/project")
      [
        %{pattern_type: "MVC", confidence: 0.90, files: ["src/controllers/", "src/models/"], description: "..."}
      ]
  """
  def analyze_architecture(codebase_path) do
    analyze_architecture(codebase_path)
  end

  @doc """
  Get analysis summary with key metrics
  
  ## Examples
  
      iex> Singularity.UnifiedAnalysis.get_analysis_summary("/path/to/project")
      %{
        "total_files" => "150",
        "total_lines" => "12500",
        "technologies_detected" => "8",
        "dependencies_found" => "25",
        "quality_score" => "0.85"
      }
  """
  def get_analysis_summary(codebase_path) do
    get_analysis_summary(codebase_path)
  end

  @doc """
  Write analysis results to database
  
  ## Examples
  
      iex> result = %{success: true, technologies: [...], ...}
      iex> Singularity.UnifiedAnalysis.write_to_database(result, "postgresql://localhost/singularity")
      true
  """
  def write_to_database(result, database_url) do
    write_to_database(result, database_url)
  end
end
