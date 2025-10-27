defmodule Singularity.Schemas.CodebaseMetadata do
  @moduledoc """
  CodebaseMetadata schema - Comprehensive code metrics and analysis results.

  Stores detailed analysis results for code files including:
  - File identification (path, language, type)
  - Complexity metrics (cyclomatic, cognitive, maintainability)
  - Code structure counts (functions, classes, structs, enums, traits, interfaces)
  - Line metrics (code, comments, blank lines)
  - Halstead metrics (vocabulary, length, volume, difficulty, effort)
  - Graph metrics (PageRank, centrality, dependencies)
  - Performance metrics (technical debt, code smells, duplication)
  - Security metrics (security score, vulnerabilities)
  - Quality metrics (quality score, test coverage, documentation)
  - Semantic features (domains, patterns, features, business context)
  - Dependencies and relationships (imports, exports, related files)
  - Vector embeddings for semantic search

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.CodebaseMetadata",
    "purpose": "Comprehensive metrics, analysis results, and quality scores for files",
    "role": "schema",
    "layer": "infrastructure",
    "table": "codebase_metadata",
    "features": ["code_metrics", "complexity_analysis", "quality_scoring", "semantic_features"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  metrics:
    - cyclomatic_complexity: Decision path complexity
    - cognitive_complexity: Mental burden to understand code
    - halstead_volume: Size of implementation
    - technical_debt: Maintenance cost indicator
    - test_coverage: Line/branch coverage percentage
    - quality_score: Overall code quality (0-100)
  semantic:
    - domains: Business domains touched
    - patterns: Design patterns detected
    - features: Implementation features
    - embedding: Vector for semantic search
  ```

  ### Anti-Patterns
  - ❌ DO NOT store raw code here - use CodeFile schema
  - ❌ DO NOT use for code location - use CodeLocationIndex
  - ✅ DO use for metrics aggregation across large codebases
  - ✅ DO rely on this for quality dashboards

  ### Search Keywords
  metrics, complexity, quality, analysis, code_quality, technical_debt, coverage,
  halstead, cyclomatic, performance, maintainability, code_metrics
  ```
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "codebase_metadata" do
    # === CODEBASE IDENTIFICATION ===
    field :codebase_id, :string
    field :codebase_path, :string

    # === BASIC FILE INFO ===
    field :path, :string
    field :size, :integer, default: 0
    field :lines, :integer, default: 0
    field :language, :string, default: "unknown"
    field :last_modified, :integer, default: 0
    field :file_type, :string, default: "source"

    # === COMPLEXITY METRICS ===
    field :cyclomatic_complexity, :float, default: 0.0
    field :cognitive_complexity, :float, default: 0.0
    field :maintainability_index, :float, default: 0.0
    field :nesting_depth, :integer, default: 0

    # === CODE METRICS ===
    field :function_count, :integer, default: 0
    field :class_count, :integer, default: 0
    field :struct_count, :integer, default: 0
    field :enum_count, :integer, default: 0
    field :trait_count, :integer, default: 0
    field :interface_count, :integer, default: 0

    # === LINE METRICS ===
    field :total_lines, :integer, default: 0
    field :code_lines, :integer, default: 0
    field :comment_lines, :integer, default: 0
    field :blank_lines, :integer, default: 0

    # === HALSTEAD METRICS ===
    field :halstead_vocabulary, :integer, default: 0
    field :halstead_length, :integer, default: 0
    field :halstead_volume, :float, default: 0.0
    field :halstead_difficulty, :float, default: 0.0
    field :halstead_effort, :float, default: 0.0

    # === PAGERANK & GRAPH METRICS ===
    field :pagerank_score, :float, default: 0.0
    field :centrality_score, :float, default: 0.0
    field :dependency_count, :integer, default: 0
    field :dependent_count, :integer, default: 0

    # === PERFORMANCE METRICS ===
    field :technical_debt_ratio, :float, default: 0.0
    field :code_smells_count, :integer, default: 0
    field :duplication_percentage, :float, default: 0.0

    # === SECURITY METRICS ===
    field :security_score, :float, default: 0.0
    field :vulnerability_count, :integer, default: 0

    # === QUALITY METRICS ===
    field :quality_score, :float, default: 0.0
    field :test_coverage, :float, default: 0.0
    field :documentation_coverage, :float, default: 0.0

    # === SEMANTIC FEATURES (JSONB) ===
    field :domains, :map, default: %{}
    field :patterns, :map, default: %{}
    field :features, :map, default: %{}
    field :business_context, :map, default: %{}
    field :performance_characteristics, :map, default: %{}
    field :security_characteristics, :map, default: %{}

    # === DEPENDENCIES & RELATIONSHIPS (JSONB) ===
    field :dependencies, :map, default: %{}
    field :related_files, :map, default: %{}
    field :imports, :map, default: %{}
    field :exports, :map, default: %{}

    # === SYMBOLS (JSONB) ===
    field :functions, :map, default: %{}
    field :classes, :map, default: %{}
    field :structs, :map, default: %{}
    field :enums, :map, default: %{}
    field :traits, :map, default: %{}

    # === VECTOR EMBEDDING (1536-dim for now, migrate to 2560 later) ===
    field :vector_embedding, Pgvector.Ecto.Vector

    # === TIMESTAMPS ===
    timestamps()
  end

  @doc false
  def changeset(metadata, attrs) do
    metadata
    |> cast(attrs, [
      :codebase_id,
      :codebase_path,
      :path,
      :size,
      :lines,
      :language,
      :last_modified,
      :file_type,
      :cyclomatic_complexity,
      :cognitive_complexity,
      :maintainability_index,
      :nesting_depth,
      :function_count,
      :class_count,
      :struct_count,
      :enum_count,
      :trait_count,
      :interface_count,
      :total_lines,
      :code_lines,
      :comment_lines,
      :blank_lines,
      :halstead_vocabulary,
      :halstead_length,
      :halstead_volume,
      :halstead_difficulty,
      :halstead_effort,
      :pagerank_score,
      :centrality_score,
      :dependency_count,
      :dependent_count,
      :technical_debt_ratio,
      :code_smells_count,
      :duplication_percentage,
      :security_score,
      :vulnerability_count,
      :quality_score,
      :test_coverage,
      :documentation_coverage,
      :domains,
      :patterns,
      :features,
      :business_context,
      :performance_characteristics,
      :security_characteristics,
      :dependencies,
      :related_files,
      :imports,
      :exports,
      :functions,
      :classes,
      :structs,
      :enums,
      :traits,
      :vector_embedding
    ])
    |> validate_required([:codebase_id, :codebase_path, :path, :language])
    |> unique_constraint([:codebase_id, :path])
  end
end
