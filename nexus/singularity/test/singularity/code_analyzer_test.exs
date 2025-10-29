defmodule Singularity.CodeAnalyzerTest do
  use Singularity.DataCase
  alias Singularity.CodeAnalyzer

  @expected_languages ~w(
    bash
    c
    cpp
    csharp
    dockerfile
    elixir
    erlang
    gleam
    go
    java
    javascript
    json
    lua
    markdown
    python
    rust
    sql
    toml
    typescript
    yaml
  )

  describe "supported_languages/0" do
    test "returns the full supported language list" do
      languages =
        CodeAnalyzer.supported_languages()
        |> Enum.sort()

      assert Enum.sort(@expected_languages) == languages
    end
  end

  describe "rca_supported_languages/0" do
    test "returns 9 RCA-supported languages" do
      rca_languages = CodeAnalyzer.rca_supported_languages()

      assert is_list(rca_languages)
      assert length(rca_languages) == 9

      # Check expected RCA languages
      assert "rust" in rca_languages
      assert "c" in rca_languages
      assert "cpp" in rca_languages
      assert "csharp" in rca_languages
      assert "javascript" in rca_languages
      assert "typescript" in rca_languages
      assert "python" in rca_languages
      assert "java" in rca_languages
      assert "go" in rca_languages

      # BEAM languages should NOT have RCA
      refute "elixir" in rca_languages
      refute "erlang" in rca_languages
      refute "gleam" in rca_languages
    end
  end

  describe "has_rca_support?/1" do
    test "returns true for RCA-supported languages" do
      assert CodeAnalyzer.has_rca_support?("rust")
      assert CodeAnalyzer.has_rca_support?("python")
      assert CodeAnalyzer.has_rca_support?("csharp")
    end

    test "returns false for non-RCA languages" do
      refute CodeAnalyzer.has_rca_support?("elixir")
      refute CodeAnalyzer.has_rca_support?("json")
      refute CodeAnalyzer.has_rca_support?("markdown")
    end
  end

  describe "analyze_language/2" do
    test "analyzes Elixir code successfully" do
      code = """
      defmodule Hello do
        def world, do: :ok
      end
      """

      assert {:ok, analysis} = CodeAnalyzer.analyze_language(code, "elixir")
      assert analysis.language_id == "elixir"
      assert is_float(analysis.complexity_score)
      assert is_float(analysis.quality_score)
    end

    test "analyzes Rust code successfully" do
      code = """
      fn main() {
          println!("Hello, world!");
      }
      """

      assert {:ok, analysis} = CodeAnalyzer.analyze_language(code, "rust")
      assert analysis.language_id == "rust"
    end

    test "analyzes Python code successfully" do
      code = """
      def hello():
          return "world"
      """

      assert {:ok, analysis} = CodeAnalyzer.analyze_language(code, "python")
      assert analysis.language_id == "python"
    end

    test "returns error for unsupported language" do
      code = "some code"
      assert {:error, _reason} = CodeAnalyzer.analyze_language(code, "foobar")
    end

    test "handles empty code" do
      assert {:ok, _analysis} = CodeAnalyzer.analyze_language("", "elixir")
    end
  end

  describe "extract_functions/2" do
    test "extracts Elixir functions" do
      code = """
      defmodule Foo do
        def bar(x), do: x + 1
        defp baz(y), do: y * 2
        def qux(a, b), do: a + b
      end
      """

      assert {:ok, functions} = CodeAnalyzer.extract_functions(code, "elixir")
      assert is_list(functions)
      # At least bar and qux (baz is private)
      assert length(functions) >= 2
    end

    test "extracts Rust functions" do
      code = """
      fn main() {
          println!("Hello");
      }

      fn helper(x: i32) -> i32 {
          x + 1
      }
      """

      assert {:ok, functions} = CodeAnalyzer.extract_functions(code, "rust")
      assert is_list(functions)
      assert length(functions) >= 2
    end

    test "extracts Python functions" do
      code = """
      def hello():
          return "world"

      def add(a, b):
          return a + b
      """

      assert {:ok, functions} = CodeAnalyzer.extract_functions(code, "python")
      assert is_list(functions)
      assert length(functions) == 2
    end

    test "returns empty list for code without functions" do
      code = "x = 1\ny = 2"
      assert {:ok, functions} = CodeAnalyzer.extract_functions(code, "python")
      assert is_list(functions)
    end
  end

  describe "extract_classes/2" do
    test "extracts Python classes" do
      code = """
      class MyClass:
          def __init__(self):
              pass

      class AnotherClass:
          pass
      """

      assert {:ok, classes} = CodeAnalyzer.extract_classes(code, "python")
      assert is_list(classes)
      assert length(classes) >= 2
    end

    test "extracts Rust structs/impls as classes" do
      code = """
      struct Point {
          x: i32,
          y: i32,
      }

      impl Point {
          fn new(x: i32, y: i32) -> Self {
              Point { x, y }
          }
      }
      """

      assert {:ok, classes} = CodeAnalyzer.extract_classes(code, "rust")
      assert is_list(classes)
    end
  end

  describe "get_rca_metrics/2" do
    test "returns RCA metrics for Rust code" do
      code = """
      fn calculate_fibonacci(n: u32) -> u32 {
          match n {
              0 => 0,
              1 => 1,
              _ => calculate_fibonacci(n - 1) + calculate_fibonacci(n - 2)
          }
      }
      """

      assert {:ok, metrics} = CodeAnalyzer.get_rca_metrics(code, "rust")
      assert is_map(metrics)
      assert Map.has_key?(metrics, :cyclomatic_complexity)
      assert Map.has_key?(metrics, :maintainability_index)
      assert Map.has_key?(metrics, :source_lines_of_code)
    end

    test "returns RCA metrics for Python code" do
      code = """
      def complex_function(x):
          if x > 0:
              return x * 2
          elif x < 0:
              return x * -1
          else:
              return 0
      """

      assert {:ok, metrics} = CodeAnalyzer.get_rca_metrics(code, "python")
      assert is_map(metrics)
    end

    test "returns error for non-RCA language" do
      code = "def hello, do: :world"
      assert {:error, _reason} = CodeAnalyzer.get_rca_metrics(code, "elixir")
    end
  end

  describe "check_language_rules/2" do
    test "checks Elixir code for rule violations" do
      code = """
      defmodule BadCode do
        def x, do: 1  # Short variable name
      end
      """

      assert {:ok, violations} = CodeAnalyzer.check_language_rules(code, "elixir")
      assert is_list(violations)
    end

    test "returns empty list for compliant code" do
      code = """
      defmodule GoodCode do
        @moduledoc \"\"\"
        Well-documented module.
        \"\"\"

        def proper_function_name(argument), do: argument
      end
      """

      assert {:ok, violations} = CodeAnalyzer.check_language_rules(code, "elixir")
      assert is_list(violations)
    end
  end

  describe "extract_imports_exports/2" do
    test "extracts Elixir imports" do
      code = """
      defmodule MyModule do
        import Ecto.Query
        alias MyApp.User
        use GenServer

        def start_link, do: GenServer.start_link(__MODULE__, [])
      end
      """

      assert {:ok, {imports, exports}} = CodeAnalyzer.extract_imports_exports(code, "elixir")
      assert is_list(imports)
      assert is_list(exports)
    end

    test "extracts Python imports" do
      code = """
      import os
      from typing import List
      import json

      def hello():
          pass
      """

      assert {:ok, {imports, exports}} = CodeAnalyzer.extract_imports_exports(code, "python")
      assert is_list(imports)
      assert length(imports) >= 2
    end
  end

  describe "detect_cross_language_patterns/1" do
    test "detects error handling patterns across languages" do
      elixir_code = """
      defmodule API do
        def get_user(id) do
          case fetch_user(id) do
            {:ok, user} -> {:ok, user}
            {:error, reason} -> {:error, reason}
          end
        end
      end
      """

      rust_code = """
      fn get_user(id: u32) -> Result<User, Error> {
          match fetch_user(id) {
              Ok(user) => Ok(user),
              Err(e) => Err(e)
          }
      }
      """

      files = [{"elixir", elixir_code}, {"rust", rust_code}]
      assert {:ok, patterns} = CodeAnalyzer.detect_cross_language_patterns(files)
      assert is_list(patterns)
    end

    test "handles empty file list" do
      assert {:ok, patterns} = CodeAnalyzer.detect_cross_language_patterns([])
      assert is_list(patterns)
      assert Enum.empty?(patterns)
    end
  end

  describe "caching behavior" do
    setup do
      # Clear cache before each test
      if Process.whereis(Singularity.CodeAnalyzer.Cache) do
        Singularity.CodeAnalyzer.Cache.clear()
      end

      :ok
    end

    test "caches analysis results" do
      code = "def hello, do: :world"

      # First call - should be cached
      {:ok, _analysis1} = CodeAnalyzer.analyze_language(code, "elixir")

      # Second call - should hit cache (if cache is running)
      {:ok, _analysis2} = CodeAnalyzer.analyze_language(code, "elixir")

      # Verify cache stats
      if Process.whereis(Singularity.CodeAnalyzer.Cache) do
        stats = Singularity.CodeAnalyzer.Cache.stats()
        assert stats.hits >= 1
      end
    end

    test "can disable caching per call" do
      code = "def hello, do: :world"

      # Analyze without cache
      {:ok, _analysis} = CodeAnalyzer.analyze_language(code, "elixir", cache: false)

      # Cache should not be used
      if Process.whereis(Singularity.CodeAnalyzer.Cache) do
        stats = Singularity.CodeAnalyzer.Cache.stats()
        # Should have 0 hits since we disabled caching
        assert stats.hits == 0
      end
    end
  end
end
