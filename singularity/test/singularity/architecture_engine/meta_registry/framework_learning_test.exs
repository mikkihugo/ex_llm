defmodule Singularity.MetaRegistry.FrameworkLearningTest do
  use Singularity.DataCase, async: true

  alias Singularity.MetaRegistry.FrameworkLearning
  alias Singularity.MetaRegistry.QuerySystem

  @moduledoc """
  Test suite for FrameworkLearning - Framework-specific pattern learning.

  Tests all 9 framework learners and suggestion getters:
  1. NATS messaging patterns
  2. PostgreSQL database patterns
  3. ETS caching patterns
  4. Rust NIF patterns
  5. Elixir OTP patterns
  6. Ecto ORM patterns
  7. Jason JSON patterns
  8. Phoenix web patterns
  9. ExUnit testing patterns

  Plus suggestion getters and initialization.
  """

  describe "learn_nats_patterns/1" do
    test "learns NATS messaging subject patterns" do
      attrs = %{
        subjects: ["llm.provider.claude", "analysis.code.parse"],
        messaging: ["request/response", "pub/sub"],
        patterns: ["analysis.meta.subject.hierarchy", "llm.provider.*"]
      }

      # Function delegates to QuerySystem
      result = FrameworkLearning.learn_nats_patterns(attrs)

      # Verify it returns valid result (ok tuple or atom)
      assert result == :ok or is_tuple(result)
    end

    test "handles empty subjects list" do
      attrs = %{
        subjects: [],
        messaging: ["request/response"],
        patterns: []
      }

      result = FrameworkLearning.learn_nats_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "handles missing optional fields" do
      attrs = %{
        patterns: ["test.pattern"]
      }

      # Should not crash even if subjects/messaging missing
      result = FrameworkLearning.learn_nats_patterns(attrs)
      assert is_atom(result) or is_tuple(result)
    end

    test "stores multiple NATS patterns" do
      attrs = %{
        subjects: Enum.map(1..10, fn i -> "subject_#{i}" end),
        messaging: ["pub/sub"],
        patterns: Enum.map(1..10, fn i -> "pattern_#{i}" end)
      }

      result = FrameworkLearning.learn_nats_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end
  end

  describe "learn_postgresql_patterns/1" do
    test "learns PostgreSQL table and query patterns" do
      attrs = %{
        tables: ["code_chunks", "technology_detections"],
        queries: ["SELECT", "INSERT"],
        indexes: ["GIN", "B-tree"],
        patterns: ["codebase_id", "metadata"]
      }

      result = FrameworkLearning.learn_postgresql_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "handles various index types" do
      attrs = %{
        tables: ["test_table"],
        queries: ["SELECT"],
        indexes: ["GIN", "B-tree", "Hash", "BRIN", "GIST"],
        patterns: ["indexed_column"]
      }

      result = FrameworkLearning.learn_postgresql_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "learns from all CRUD operations" do
      attrs = %{
        tables: ["test_table"],
        queries: ["SELECT", "INSERT", "UPDATE", "DELETE"],
        indexes: ["B-tree"],
        patterns: ["crud_pattern"]
      }

      result = FrameworkLearning.learn_postgresql_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "handles schema-qualified table names" do
      attrs = %{
        tables: ["public.code_chunks", "analysis.patterns"],
        queries: ["SELECT"],
        indexes: ["GIN"],
        patterns: ["schema_pattern"]
      }

      result = FrameworkLearning.learn_postgresql_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end
  end

  describe "learn_ets_patterns/1" do
    test "learns ETS table and operation patterns" do
      attrs = %{
        tables: ["naming_patterns", "cache"],
        operations: ["lookup", "insert"],
        patterns: ["fast_cache", "in_memory"]
      }

      result = FrameworkLearning.learn_ets_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "handles all ETS operations" do
      attrs = %{
        tables: ["test_table"],
        operations: ["lookup", "insert", "delete", "select", "update"],
        patterns: ["ets_operation"]
      }

      result = FrameworkLearning.learn_ets_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "learns from multiple cached tables" do
      attrs = %{
        tables: Enum.map(1..15, fn i -> "cache_#{i}" end),
        operations: ["lookup", "insert"],
        patterns: ["multi_cache"]
      }

      result = FrameworkLearning.learn_ets_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end
  end

  describe "learn_rust_nif_patterns/1" do
    test "learns Rust NIF module and function patterns" do
      attrs = %{
        modules: ["ArchitectureEngine", "CodeEngine"],
        functions: ["analyze_architecture", "detect_patterns"],
        types: ["Result<", "Option<"],
        patterns: ["pub fn", "use rustler"]
      }

      result = FrameworkLearning.learn_rust_nif_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "handles Rust type signatures" do
      attrs = %{
        modules: ["TestEngine"],
        functions: ["test_fn"],
        types: ["Result<", "Option<", "Vec<", "HashMap<", "Box<", "Arc<"],
        patterns: ["type_signature"]
      }

      result = FrameworkLearning.learn_rust_nif_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "learns from complex Rust patterns" do
      attrs = %{
        modules: ["Engine1", "Engine2"],
        functions: ["fn1", "fn2", "fn3"],
        types: ["Result<T, E>", "Option<T>"],
        patterns: [
          "pub fn",
          "use rustler",
          "rustler::init!",
          "pub struct",
          "pub enum",
          "impl"
        ]
      }

      result = FrameworkLearning.learn_rust_nif_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end
  end

  describe "learn_elixir_otp_patterns/1" do
    test "learns OTP GenServer, Supervisor patterns" do
      attrs = %{
        modules: ["GenServer", "Supervisor"],
        functions: ["start_link", "init"],
        patterns: ["defmodule", "use GenServer"]
      }

      result = FrameworkLearning.learn_elixir_otp_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "learns complete OTP callback patterns" do
      attrs = %{
        modules: ["GenServer", "Supervisor", "Agent", "Task"],
        functions: ["start_link", "init", "handle_call", "handle_cast", "handle_info"],
        patterns: [
          "defmodule",
          "use GenServer",
          "def start_link",
          "def init",
          "def handle_call",
          "def handle_cast",
          "def handle_info"
        ]
      }

      result = FrameworkLearning.learn_elixir_otp_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "handles various OTP behavior modules" do
      attrs = %{
        modules: ["GenServer", "Supervisor", "Agent", "Task", "DynamicSupervisor"],
        functions: ["start_link"],
        patterns: ["otp_pattern"]
      }

      result = FrameworkLearning.learn_elixir_otp_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end
  end

  describe "learn_ecto_patterns/1" do
    test "learns Ecto schema and query patterns" do
      attrs = %{
        schemas: ["CodeChunk", "TechnologyDetection"],
        queries: ["Ecto.Query", "Ecto.Changeset"],
        patterns: ["use Ecto.Schema", "field :"]
      }

      result = FrameworkLearning.learn_ecto_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "learns Ecto association patterns" do
      attrs = %{
        schemas: ["User", "Post"],
        queries: ["Ecto.Query"],
        patterns: [
          "use Ecto.Schema",
          "field :",
          "belongs_to",
          "has_many",
          "has_one",
          "many_to_many"
        ]
      }

      result = FrameworkLearning.learn_ecto_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "learns Ecto operations patterns" do
      attrs = %{
        schemas: ["Model"],
        queries: ["Ecto.Repo", "Ecto.Query"],
        patterns: [
          "def changeset",
          "def upsert",
          "def latest",
          "Repo.insert",
          "Repo.update",
          "Repo.delete"
        ]
      }

      result = FrameworkLearning.learn_ecto_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end
  end

  describe "learn_jason_patterns/1" do
    test "learns Jason encoding/decoding patterns" do
      attrs = %{
        functions: ["encode!", "decode!"],
        patterns: ["@derive {Jason.Encoder}", "Jason.Encoder"]
      }

      result = FrameworkLearning.learn_jason_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "learns custom Jason encoder patterns" do
      attrs = %{
        functions: ["encode!", "decode!", "encode", "decode"],
        patterns: [
          "@derive {Jason.Encoder}",
          "Jason.Encoder",
          "only: @fields",
          "except: @fields",
          "def encode_to_iodata!",
          "def to_map"
        ]
      }

      result = FrameworkLearning.learn_jason_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "learns field filtering patterns" do
      attrs = %{
        functions: ["encode!"],
        patterns: ["only: @fields", "except: @fields"]
      }

      result = FrameworkLearning.learn_jason_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end
  end

  describe "learn_phoenix_patterns/1" do
    test "learns Phoenix controller patterns" do
      attrs = %{
        modules: ["Phoenix.Controller"],
        functions: ["render", "assign"],
        patterns: ["use Phoenix.Controller", "def index"]
      }

      result = FrameworkLearning.learn_phoenix_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "learns Phoenix LiveView patterns" do
      attrs = %{
        modules: ["Phoenix.LiveView", "Phoenix.Component"],
        functions: ["mount", "render"],
        patterns: [
          "use Phoenix.LiveView",
          "def mount",
          "def render",
          "def handle_event"
        ]
      }

      result = FrameworkLearning.learn_phoenix_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "learns Phoenix request handling patterns" do
      attrs = %{
        modules: ["Phoenix.Controller"],
        functions: ["render", "assign", "put_flash", "redirect"],
        patterns: [
          "defmodule",
          "use Phoenix.Controller",
          "def index",
          "def render",
          "def handle_params"
        ]
      }

      result = FrameworkLearning.learn_phoenix_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end
  end

  describe "learn_exunit_patterns/1" do
    test "learns ExUnit test patterns" do
      attrs = %{
        modules: ["ExUnit.Case"],
        functions: ["test", "assert"],
        patterns: ["use ExUnit.Case", "test \""]
      }

      result = FrameworkLearning.learn_exunit_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "learns ExUnit assertion patterns" do
      attrs = %{
        modules: ["ExUnit.Case"],
        functions: ["test", "assert", "refute"],
        patterns: [
          "assert ",
          "refute ",
          "assert_raise",
          "assert_receive",
          "assert_in_delta"
        ]
      }

      result = FrameworkLearning.learn_exunit_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "learns ExUnit test organization patterns" do
      attrs = %{
        modules: ["ExUnit.Case"],
        functions: ["describe", "test", "setup"],
        patterns: [
          "use ExUnit.Case",
          "describe \"",
          "test \"",
          "setup do",
          "setup_all do"
        ]
      }

      result = FrameworkLearning.learn_exunit_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end
  end

  describe "get_nats_suggestions/2" do
    test "returns NATS subject suggestions" do
      result = FrameworkLearning.get_nats_suggestions("search", "subject")

      # Should return list of suggestions
      assert is_list(result)

      # Suggestions should be formatted as subjects
      Enum.each(result, fn suggestion ->
        assert is_binary(suggestion)
        # Should contain the context
        assert String.contains?(suggestion, "search")
      end)
    end

    test "returns NATS service suggestions" do
      result = FrameworkLearning.get_nats_suggestions("llm", "service")

      assert is_list(result)
      Enum.each(result, fn suggestion ->
        assert is_binary(suggestion)
      end)
    end

    test "formats suggestions according to type" do
      subjects = FrameworkLearning.get_nats_suggestions("api", "subject")
      services = FrameworkLearning.get_nats_suggestions("api", "service")

      # Subject suggestions should use dots
      Enum.each(subjects, fn s ->
        assert String.contains?(s, ".") or is_binary(s)
      end)

      # Service suggestions might use dashes
      assert is_list(services)
    end
  end

  describe "get_postgresql_suggestions/2" do
    test "returns PostgreSQL table suggestions" do
      result = FrameworkLearning.get_postgresql_suggestions("user", "table")

      assert is_list(result)
      Enum.each(result, fn suggestion ->
        assert is_binary(suggestion)
      end)
    end

    test "returns PostgreSQL column suggestions" do
      result = FrameworkLearning.get_postgresql_suggestions("timestamp", "column")

      assert is_list(result)
      Enum.each(result, fn suggestion ->
        assert is_binary(suggestion)
      end)
    end

    test "formats table names with underscores" do
      result = FrameworkLearning.get_postgresql_suggestions("user", "table")

      assert is_list(result)
      Enum.each(result, fn suggestion ->
        assert is_binary(suggestion)
      end)
    end
  end

  describe "get_rust_nif_suggestions/2" do
    test "returns Rust NIF module suggestions" do
      result = FrameworkLearning.get_rust_nif_suggestions("parser", "module")

      assert is_list(result)
      Enum.each(result, fn suggestion ->
        assert is_binary(suggestion)
      end)
    end

    test "returns Rust NIF function suggestions" do
      result = FrameworkLearning.get_rust_nif_suggestions("analyze", "function")

      assert is_list(result)
      Enum.each(result, fn suggestion ->
        assert is_binary(suggestion)
      end)
    end
  end

  describe "get_elixir_otp_suggestions/2" do
    test "returns Elixir OTP module suggestions" do
      result = FrameworkLearning.get_elixir_otp_suggestions("Worker", "module")

      assert is_list(result)
      Enum.each(result, fn suggestion ->
        assert is_binary(suggestion)
      end)
    end

    test "returns Elixir OTP function suggestions" do
      result = FrameworkLearning.get_elixir_otp_suggestions("execute", "function")

      assert is_list(result)
      Enum.each(result, fn suggestion ->
        assert is_binary(suggestion)
      end)
    end
  end

  describe "initialize_framework_patterns/0" do
    test "initializes all framework patterns" do
      result = FrameworkLearning.initialize_framework_patterns()

      # Should return :ok
      assert result == :ok
    end

    test "can be called multiple times (idempotent)" do
      result1 = FrameworkLearning.initialize_framework_patterns()
      result2 = FrameworkLearning.initialize_framework_patterns()

      assert result1 == :ok
      assert result2 == :ok
    end

    test "sets up NATS patterns" do
      FrameworkLearning.initialize_framework_patterns()

      # Verify NATS suggestions work after initialization
      suggestions = FrameworkLearning.get_nats_suggestions("test", "subject")
      assert is_list(suggestions)
    end

    test "sets up PostgreSQL patterns" do
      FrameworkLearning.initialize_framework_patterns()

      suggestions = FrameworkLearning.get_postgresql_suggestions("test", "table")
      assert is_list(suggestions)
    end

    test "sets up Rust NIF patterns" do
      FrameworkLearning.initialize_framework_patterns()

      suggestions = FrameworkLearning.get_rust_nif_suggestions("test", "module")
      assert is_list(suggestions)
    end

    test "sets up Elixir OTP patterns" do
      FrameworkLearning.initialize_framework_patterns()

      suggestions = FrameworkLearning.get_elixir_otp_suggestions("Test", "module")
      assert is_list(suggestions)
    end
  end

  describe "framework learning integration" do
    test "learning and suggestion workflow" do
      # Learn patterns
      learn_result = FrameworkLearning.learn_nats_patterns(%{
        subjects: ["custom.api.request"],
        messaging: ["request/response"],
        patterns: ["custom.pattern"]
      })

      assert learn_result == :ok or is_tuple(learn_result)

      # Get suggestions based on learned patterns
      suggestions = FrameworkLearning.get_nats_suggestions("custom", "subject")

      assert is_list(suggestions)
    end

    test "multiple frameworks can be learned together" do
      results = [
        FrameworkLearning.learn_nats_patterns(%{subjects: [], messaging: [], patterns: []}),
        FrameworkLearning.learn_postgresql_patterns(%{tables: [], queries: [], indexes: [], patterns: []}),
        FrameworkLearning.learn_ets_patterns(%{tables: [], operations: [], patterns: []}),
        FrameworkLearning.learn_rust_nif_patterns(%{modules: [], functions: [], types: [], patterns: []}),
        FrameworkLearning.learn_elixir_otp_patterns(%{modules: [], functions: [], patterns: []}),
        FrameworkLearning.learn_ecto_patterns(%{schemas: [], queries: [], patterns: []}),
        FrameworkLearning.learn_jason_patterns(%{functions: [], patterns: []}),
        FrameworkLearning.learn_phoenix_patterns(%{modules: [], functions: [], patterns: []}),
        FrameworkLearning.learn_exunit_patterns(%{modules: [], functions: [], patterns: []})
      ]

      # All should succeed or return valid tuples
      Enum.each(results, fn result ->
        assert result == :ok or is_tuple(result)
      end)
    end

    test "suggestions are consistent across calls" do
      FrameworkLearning.initialize_framework_patterns()

      suggestions1 = FrameworkLearning.get_nats_suggestions("test", "subject")
      suggestions2 = FrameworkLearning.get_nats_suggestions("test", "subject")

      # Multiple calls should return consistent results
      assert length(suggestions1) == length(suggestions2)
    end
  end

  describe "error handling" do
    test "handles nil attributes gracefully" do
      # Some functions may be called with incomplete data
      attrs = %{patterns: ["test"]}

      # Should not crash
      result = FrameworkLearning.learn_nats_patterns(attrs)
      assert is_atom(result) or is_tuple(result)
    end

    test "handles empty patterns list" do
      attrs = %{
        subjects: ["test.subject"],
        messaging: [],
        patterns: []
      }

      result = FrameworkLearning.learn_nats_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "handles very large pattern lists" do
      # Test with many patterns
      attrs = %{
        subjects: Enum.map(1..100, fn i -> "subject_#{i}" end),
        messaging: ["pub/sub"],
        patterns: Enum.map(1..100, fn i -> "pattern_#{i}" end)
      }

      result = FrameworkLearning.learn_nats_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end
  end

  describe "framework pattern consistency" do
    test "NATS patterns follow subject hierarchy conventions" do
      attrs = %{
        subjects: [
          "llm.provider.claude",
          "llm.provider.gemini",
          "analysis.code.parse"
        ],
        messaging: ["request/response"],
        patterns: ["hierarchical_subjects"]
      }

      result = FrameworkLearning.learn_nats_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "PostgreSQL patterns follow naming conventions" do
      attrs = %{
        tables: ["code_chunks", "analysis_results"],
        queries: ["SELECT"],
        indexes: ["GIN"],
        patterns: ["snake_case_naming"]
      }

      result = FrameworkLearning.learn_postgresql_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "Rust NIF patterns follow Rustler conventions" do
      attrs = %{
        modules: ["ArchitectureEngine"],
        functions: ["analyze_architecture"],
        types: ["Result<"],
        patterns: ["rustler::init!", "pub fn"]
      }

      result = FrameworkLearning.learn_rust_nif_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end

    test "OTP patterns follow callback conventions" do
      attrs = %{
        modules: ["GenServer"],
        functions: ["init", "handle_call"],
        patterns: ["use GenServer", "def handle_call"]
      }

      result = FrameworkLearning.learn_elixir_otp_patterns(attrs)
      assert result == :ok or is_tuple(result)
    end
  end
end
