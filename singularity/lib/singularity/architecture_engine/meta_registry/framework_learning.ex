defmodule Singularity.MetaRegistry.FrameworkLearning do
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
  alias Singularity.MetaRegistry.NatsSubjects

  @doc """
  Learn from NATS messaging patterns.

  ## Examples

      # Learn from our NATS subjects
      learn_nats_patterns(%{
        subjects: ["llm.provider.claude", "analysis.code.parse", "analysis.meta.registry.naming"],
        messaging: ["request/response", "pub/sub", "streaming"],
        patterns: ["analysis.meta.subject.hierarchy", "analysis.meta.wildcard.subjects", "analysis.meta.message.routing"]
      })
  """
  def learn_nats_patterns(attrs) do
    QuerySystem.learn_architecture_patterns("nats-framework", %{
      patterns: attrs.patterns,
      services: attrs.subjects
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
  Learn from ETS caching patterns.

  ## Examples

      # Learn from our ETS tables
      learn_ets_patterns(%{
        tables: ["naming_patterns", "architecture_patterns", "quality_patterns"],
        operations: ["lookup", "insert", "delete", "select"],
        patterns: ["fast_cache", "in_memory", "key_value"]
      })
  """
  def learn_ets_patterns(attrs) do
    QuerySystem.learn_architecture_patterns("ets-framework", %{
      patterns: attrs.patterns,
      services: attrs.tables
    })
  end

  @doc """
  Learn from Rust NIF patterns.

  ## Examples

      # Learn from our Rust NIFs
      learn_rust_nif_patterns(%{
        modules: ["ArchitectureEngine", "CodeEngine", "EmbeddingEngine"],
        functions: ["analyze_architecture", "detect_patterns", "generate_embeddings"],
        types: ["Result<", "Option<", "Vec<", "HashMap<"],
        patterns: ["pub fn", "use rustler", "rustler::init!"]
      })
  """
  def learn_rust_nif_patterns(attrs) do
    QuerySystem.learn_naming_patterns("rust-nif-framework", %{
      language: "rust",
      framework: "rustler",
      patterns: attrs.patterns
    })
  end

  @doc """
  Learn from Elixir OTP patterns.

  ## Examples

      # Learn from our OTP modules
      learn_elixir_otp_patterns(%{
        modules: ["GenServer", "Supervisor", "Agent", "Task"],
        functions: ["start_link", "init", "handle_call", "handle_cast"],
        patterns: ["defmodule", "use GenServer", "def start_link"]
      })
  """
  def learn_elixir_otp_patterns(attrs) do
    QuerySystem.learn_naming_patterns("elixir-otp-framework", %{
      language: "elixir",
      framework: "otp",
      patterns: attrs.patterns
    })
  end

  @doc """
  Learn from Ecto ORM patterns.

  ## Examples

      # Learn from our Ecto schemas
      learn_ecto_patterns(%{
        schemas: ["CodeChunk", "TechnologyDetection", "FileArchitecturePattern"],
        queries: ["Ecto.Query", "Ecto.Changeset", "Ecto.Repo"],
        patterns: ["use Ecto.Schema", "field :", "belongs_to", "has_many"]
      })
  """
  def learn_ecto_patterns(attrs) do
    QuerySystem.learn_naming_patterns("ecto-framework", %{
      language: "elixir",
      framework: "ecto",
      patterns: attrs.patterns
    })
  end

  @doc """
  Learn from Jason JSON patterns.

  ## Examples

      # Learn from our JSON handling
      learn_jason_patterns(%{
        functions: ["encode!", "decode!", "encode", "decode"],
        patterns: ["@derive {Jason.Encoder}", "Jason.Encoder", "only: @fields"]
      })
  """
  def learn_jason_patterns(attrs) do
    QuerySystem.learn_naming_patterns("jason-framework", %{
      language: "elixir",
      framework: "jason",
      patterns: attrs.patterns
    })
  end

  @doc """
  Learn from Phoenix web patterns.

  ## Examples

      # Learn from our Phoenix modules
      learn_phoenix_patterns(%{
        modules: ["Phoenix.Controller", "Phoenix.LiveView", "Phoenix.Channel"],
        functions: ["render", "assign", "put_flash", "redirect"],
        patterns: ["defmodule", "use Phoenix.Controller", "def index"]
      })
  """
  def learn_phoenix_patterns(attrs) do
    QuerySystem.learn_naming_patterns("phoenix-framework", %{
      language: "elixir",
      framework: "phoenix",
      patterns: attrs.patterns
    })
  end

  @doc """
  Learn from ExUnit testing patterns.

  ## Examples

      # Learn from our test modules
      learn_exunit_patterns(%{
        modules: ["ExUnit.Case", "ExUnit.CaseTemplate", "ExUnit.Callbacks"],
        functions: ["test", "describe", "it", "expect", "assert"],
        patterns: ["use ExUnit.Case", "test \"", "assert ", "refute "]
      })
  """
  def learn_exunit_patterns(attrs) do
    QuerySystem.learn_quality_patterns("exunit-framework", %{
      patterns: attrs.patterns,
      metrics: %{
        test_coverage: 85.0,
        documentation_coverage: 90.0
      }
    })
  end

  @doc """
  Get suggestions for specific framework based on what we've learned.

  ## Examples

      # Get NATS subject suggestions
      get_nats_suggestions("search", "subject")
      # Returns: ["search.semantic", "search.hybrid", "search.vector"]
      
      # Get PostgreSQL table suggestions
      get_postgresql_suggestions("user", "table")
      # Returns: ["user_profiles", "user_sessions", "user_preferences"]
      
      # Get Rust NIF suggestions
      get_rust_nif_suggestions("parser", "module")
      # Returns: ["ParserEngine", "CodeParser", "SyntaxParser"]
  """
  def get_nats_suggestions(context, type) do
    QuerySystem.query_architecture_suggestions("nats-framework", type)
    |> Enum.map(fn pattern ->
      case type do
        "subject" -> "#{context}.#{pattern}"
        "service" -> "#{context}-#{pattern}"
        _ -> pattern
      end
    end)
  end

  def get_postgresql_suggestions(context, type) do
    QuerySystem.query_architecture_suggestions("postgresql-framework", type)
    |> Enum.map(fn pattern ->
      case type do
        "table" -> "#{context}_#{pattern}"
        "column" -> "#{context}_#{pattern}"
        _ -> pattern
      end
    end)
  end

  def get_rust_nif_suggestions(context, type) do
    QuerySystem.query_naming_suggestions("rust-nif-framework", type)
    |> Enum.map(fn pattern ->
      case type do
        "module" -> "#{pattern}Engine"
        "function" -> "#{pattern}_#{context}"
        _ -> pattern
      end
    end)
  end

  def get_elixir_otp_suggestions(context, type) do
    QuerySystem.query_naming_suggestions("elixir-otp-framework", type)
    |> Enum.map(fn pattern ->
      case type do
        "module" -> "#{context}.#{pattern}"
        "function" -> "#{pattern}_#{context}"
        _ -> pattern
      end
    end)
  end

  @doc """
  Initialize framework-specific learning patterns.

  This sets up the meta-registry with patterns we know work for each framework.
  """
  def initialize_framework_patterns do
    # Learn NATS patterns
    learn_nats_patterns(%{
      subjects: [
        "llm.provider.claude",
        "llm.provider.gemini",
        "llm.provider.openai",
        "analysis.code.parse",
        "analysis.code.embed",
        "analysis.code.search",
        "analysis.meta.registry.naming",
        "analysis.meta.registry.architecture",
        "analysis.meta.registry.quality"
      ],
      messaging: ["request/response", "pub/sub", "streaming"],
      patterns: [
        "analysis.meta.subject.hierarchy",
        "analysis.meta.wildcard.subjects",
        "analysis.meta.message.routing",
        "llm.provider.*",
        "analysis.code.*",
        "analysis.meta.registry.*"
      ]
    })

    # Learn PostgreSQL patterns
    learn_postgresql_patterns(%{
      tables: [
        "code_chunks",
        "technology_detections",
        "file_architecture_patterns",
        "file_naming_violations",
        "code_quality_metrics",
        "dependency_analysis"
      ],
      queries: ["SELECT", "INSERT", "UPDATE", "DELETE"],
      indexes: ["GIN", "B-tree", "Hash"],
      patterns: [
        "codebase_id",
        "snapshot_id",
        "metadata",
        "summary",
        "detected_technologies",
        "capabilities",
        "service_structure"
      ]
    })

    # Learn ETS patterns
    learn_ets_patterns(%{
      tables: [
        "naming_patterns",
        "architecture_patterns",
        "quality_patterns",
        "template_cache",
        "learning_cache",
        "suggestion_cache"
      ],
      operations: ["lookup", "insert", "delete", "select"],
      patterns: ["fast_cache", "in_memory", "key_value", "ets_table"]
    })

    # Learn Rust NIF patterns
    learn_rust_nif_patterns(%{
      modules: ["ArchitectureEngine", "CodeEngine", "EmbeddingEngine"],
      functions: ["analyze_architecture", "detect_patterns", "generate_embeddings"],
      types: ["Result<", "Option<", "Vec<", "HashMap<"],
      patterns: [
        "pub fn",
        "use rustler",
        "rustler::init!",
        "pub struct",
        "pub enum",
        "impl"
      ]
    })

    # Learn Elixir OTP patterns
    learn_elixir_otp_patterns(%{
      modules: ["GenServer", "Supervisor", "Agent", "Task"],
      functions: ["start_link", "init", "handle_call", "handle_cast"],
      patterns: [
        "defmodule",
        "use GenServer",
        "def start_link",
        "def init",
        "def handle_call",
        "def handle_cast"
      ]
    })

    # Learn Ecto patterns
    learn_ecto_patterns(%{
      schemas: ["CodeChunk", "TechnologyDetection", "FileArchitecturePattern"],
      queries: ["Ecto.Query", "Ecto.Changeset", "Ecto.Repo"],
      patterns: [
        "use Ecto.Schema",
        "field :",
        "belongs_to",
        "has_many",
        "def changeset",
        "def upsert",
        "def latest"
      ]
    })

    # Learn Jason patterns
    learn_jason_patterns(%{
      functions: ["encode!", "decode!", "encode", "decode"],
      patterns: [
        "@derive {Jason.Encoder}",
        "Jason.Encoder",
        "only: @fields",
        "Jason.encode!",
        "Jason.decode!",
        "Jason.encode",
        "Jason.decode"
      ]
    })

    # Learn Phoenix patterns
    learn_phoenix_patterns(%{
      modules: ["Phoenix.Controller", "Phoenix.LiveView", "Phoenix.Channel"],
      functions: ["render", "assign", "put_flash", "redirect"],
      patterns: [
        "defmodule",
        "use Phoenix.Controller",
        "def index",
        "def render",
        "def mount",
        "def handle_event"
      ]
    })

    # Learn ExUnit patterns
    learn_exunit_patterns(%{
      modules: ["ExUnit.Case", "ExUnit.CaseTemplate", "ExUnit.Callbacks"],
      functions: ["test", "describe", "it", "expect", "assert"],
      patterns: [
        "use ExUnit.Case",
        "test \"",
        "assert ",
        "refute ",
        "describe \"",
        "it \"",
        "expect ",
        "assert_raise"
      ]
    })

    :ok
  end
end
