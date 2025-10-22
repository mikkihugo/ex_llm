defmodule Singularity.MetaRegistry.SingularityLearning do
  @moduledoc """
  Meta-registry for learning from framework-specific patterns.
  
  This learns from each framework we use to improve our development:
  - NATS messaging patterns
  - PostgreSQL database patterns
  - ETS caching patterns
  - Rust NIF patterns
  - Elixir OTP patterns
  - Ecto ORM patterns
  - Jason JSON patterns
  - Phoenix web patterns
  - ExUnit testing patterns
  
  ## Framework-Specific Learning Loop
  
  1. **Analyze framework code** → Learn framework patterns
  2. **Store in meta-registry** → Remember what works for each framework
  3. **Use for suggestions** → Suggest names/patterns that match framework style
  4. **Track usage** → See which suggestions we accept
  5. **Improve** → Get better at suggesting framework-specific patterns
  """

  alias Singularity.MetaRegistry.QuerySystem

  @doc """
  Learn from NATS messaging patterns.
  
  ## Examples
  
      # Learn from our NATS subjects
      learn_nats_patterns(%{
        subjects: ["ai.provider.claude", "code.analysis.parse", "meta.registry.naming"],
        messaging: ["request/response", "pub/sub", "streaming"],
        patterns: ["subject.hierarchy", "wildcard.subjects", "message.routing"]
      })
  """
  def learn_nats_patterns(attrs) do
    codebase_id =
      Map.get(attrs, :codebase_id) ||
        Map.get(attrs, "codebase_id") ||
        "nats-framework"

    patterns =
      Map.get(attrs, :patterns) ||
        Map.get(attrs, "patterns") ||
        []

    subjects =
      Map.get(attrs, :subjects) ||
        Map.get(attrs, "subjects") ||
        []

    QuerySystem.learn_architecture_patterns(codebase_id, %{
      patterns: List.wrap(patterns),
      services: List.wrap(subjects)
    })
  end

  @doc """
  Learn from PostgreSQL database patterns.
  
  ## Examples
  
      # Learn from our database schemas
      learn_postgresql_patterns(%{
        tables: ["code_chunks", "technology_detections", "file_architecture_patterns"],
        queries: ["SELECT", "INSERT", "UPDATE", "DELETE"],
        indexes: ["GIN", "B-tree", "Hash"],
        patterns: ["codebase_id", "snapshot_id", "metadata", "summary"]
      })
  """
  def learn_postgresql_patterns(attrs) do
    QuerySystem.learn_architecture_patterns("postgresql-framework", %{
      patterns: attrs.patterns,
      services: attrs.tables
    })
  end

  @doc """
  Learn from Rust coding patterns used across Singularity NIFs.
  """
  def learn_rust_patterns(attrs) do
    QuerySystem.learn_naming_patterns("singularity-rust", %{
      language: Map.get(attrs, :language, "rust"),
      framework: Map.get(attrs, :framework, "rustler"),
      patterns: List.wrap(attrs.patterns)
    })
  end

  @doc """
  Learn from Elixir coding patterns used across Singularity modules.
  """
  def learn_elixir_patterns(attrs) do
    QuerySystem.learn_naming_patterns("singularity-elixir", %{
      language: Map.get(attrs, :language, "elixir"),
      framework: Map.get(attrs, :framework, "otp"),
      patterns: List.wrap(attrs.patterns)
    })
  end

  @doc """
  Learn from Singularity's own database patterns.
  
  ## Examples
  
      # Learn from our own schemas
      learn_database_patterns(%{
        tables: ["code_chunks", "technology_detections", "file_architecture_patterns"],
        patterns: ["codebase_id", "snapshot_id", "metadata", "summary"]
      })
  """
  def learn_database_patterns(attrs) do
    QuerySystem.learn_architecture_patterns("singularity-database", %{
      patterns: attrs.patterns,
      services: attrs.tables
    })
  end

  @doc """
  Learn from Singularity's own testing patterns.
  
  ## Examples
  
      # Learn from our own tests
      learn_testing_patterns(%{
        patterns: ["test", "describe", "it", "expect"],
        files: ["test/singularity/analysis_test.exs", "test/singularity/code_test.exs"]
      })
  """
  def learn_testing_patterns(attrs) do
    QuerySystem.learn_quality_patterns("singularity-testing", %{
      patterns: attrs.patterns,
      metrics: %{
        test_coverage: 85.0,
        documentation_coverage: 90.0
      }
    })
  end

  @doc """
  Learn from Singularity's own documentation patterns.
  
  ## Examples
  
      # Learn from our own docs
      learn_documentation_patterns(%{
        patterns: ["@moduledoc", "@doc", "## Examples", "## Usage"],
        files: ["lib/singularity/analysis/metadata.ex", "lib/singularity/code/store.ex"]
      })
  """
  def learn_documentation_patterns(attrs) do
    QuerySystem.learn_quality_patterns("singularity-documentation", %{
      patterns: attrs.patterns,
      metrics: %{
        documentation_coverage: 90.0,
        examples_coverage: 80.0
      }
    })
  end

  @doc """
  Get suggestions for Singularity development based on what we've learned.
  
  ## Examples
  
      # Get naming suggestions for new Elixir modules
      get_elixir_suggestions("analysis", "module")
      # Returns: ["Singularity.Analysis.NewFeature", "Singularity.Analysis.Processor"]
      
      # Get naming suggestions for new Rust NIFs
      get_rust_suggestions("parser", "module")
      # Returns: ["ParserEngine", "CodeParser", "SyntaxParser"]
      
      # Get naming suggestions for new NATS subjects
      get_nats_suggestions("search", "subject")
      # Returns: ["search.semantic", "search.hybrid", "search.vector"]
  """
  def get_elixir_suggestions(context, type) do
    QuerySystem.query_naming_suggestions("singularity-elixir", type)
    |> Enum.map(fn pattern ->
      case type do
        "module" -> "Singularity.#{context}.#{pattern}"
        "function" -> "#{pattern}_#{context}"
        _ -> pattern
      end
    end)
  end

  def get_rust_suggestions(context, type) do
    QuerySystem.query_naming_suggestions("singularity-rust", type)
    |> Enum.map(fn pattern ->
      case type do
        "module" -> "#{pattern}Engine"
        "function" -> "#{pattern}_#{context}"
        _ -> pattern
      end
    end)
  end

  def get_nats_suggestions(context, type) do
    QuerySystem.query_architecture_suggestions("singularity-nats", type)
    |> Enum.map(fn pattern ->
      case type do
        "subject" -> "#{context}.#{pattern}"
        "service" -> "#{context}-#{pattern}"
        _ -> pattern
      end
    end)
  end

  @doc """
  Initialize Singularity's own learning patterns.
  
  This sets up the meta-registry with patterns we know work for us.
  """
  def initialize_singularity_patterns do
    # Learn Elixir patterns
    learn_elixir_patterns(%{
      patterns: [
        "defmodule", "use Ecto.Schema", "alias Singularity",
        "defstruct", "defp", "def", "defimpl", "defprotocol",
        "GenServer", "Supervisor", "Agent", "Task",
        "Ecto.Query", "Ecto.Changeset", "Ecto.Repo"
      ]
    })

    # Learn Rust patterns
    learn_rust_patterns(%{
      patterns: [
        "pub fn", "use rustler", "rustler::init!",
        "pub struct", "pub enum", "impl",
        "Result<", "Option<", "Vec<", "HashMap<",
        "String", "&str", "u32", "f64", "bool"
      ]
    })

    # Learn NATS patterns
    learn_nats_patterns(%{
      subjects: [
        "ai.provider.claude", "ai.provider.gemini", "ai.provider.openai",
        "code.analysis.parse", "code.analysis.embed", "code.analysis.search",
        "meta.registry.naming", "meta.registry.architecture", "meta.registry.quality"
      ],
      patterns: [
        "ai.provider.*", "code.analysis.*", "meta.registry.*",
        "naming.suggestions", "architecture.patterns", "quality.checks"
      ]
    })

    # Learn database patterns
    learn_database_patterns(%{
      tables: [
        "code_chunks", "technology_detections", "file_architecture_patterns",
        "file_naming_violations", "code_quality_metrics", "dependency_analysis"
      ],
      patterns: [
        "codebase_id", "snapshot_id", "metadata", "summary",
        "detected_technologies", "capabilities", "service_structure"
      ]
    })

    # Learn testing patterns
    learn_testing_patterns(%{
      patterns: [
        "test", "describe", "it", "expect", "assert",
        "ExUnit.Case", "ExUnit.CaseTemplate", "ExUnit.Callbacks"
      ],
      files: [
        "test/singularity/analysis_test.exs",
        "test/singularity/code_test.exs",
        "test/singularity/architecture_test.exs"
      ]
    })

    # Learn documentation patterns
    learn_documentation_patterns(%{
      patterns: [
        "@moduledoc", "@doc", "## Examples", "## Usage",
        "## Key Differences", "## Schema Fields", "## Related modules"
      ],
      files: [
        "lib/singularity/analysis/metadata.ex",
        "lib/singularity/code/store.ex",
        "lib/singularity/architecture/patterns.ex"
      ]
    })

    :ok
  end
end
