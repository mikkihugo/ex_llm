defmodule Singularity.CodeAnalyzer.DatabaseIntegrationTest do
  use Singularity.DataCase
  alias Singularity.{CodeAnalyzer, Repo}
  alias Singularity.Schemas.CodeFile

  describe "analyze_from_database/1" do
    test "analyzes code file from database" do
      # Insert test code file
      code_file = insert_code_file(%{
        codebase_id: "test-codebase",
        file_path: "lib/test.ex",
        language: "elixir",
        content: """
        defmodule Test do
          def hello, do: :world
        end
        """
      })

      # Analyze from database
      {:ok, result} = CodeAnalyzer.analyze_from_database(code_file.id)

      assert result.code_file.id == code_file.id
      assert result.analysis.language_id == "elixir"
      assert is_float(result.analysis.complexity_score)
    end

    test "returns error for non-existent file" do
      assert {:error, :not_found} = CodeAnalyzer.analyze_from_database(99999)
    end

    test "handles database read errors gracefully" do
      # Create file with invalid language
      code_file = insert_code_file(%{
        codebase_id: "test",
        file_path: "test.unknown",
        language: "invalid_language",
        content: "code"
      })

      # Should return error
      assert {:error, _reason} = CodeAnalyzer.analyze_from_database(code_file.id)
    end
  end

  describe "analyze_codebase_from_db/1" do
    test "analyzes all files in a codebase" do
      codebase_id = "multi-file-test"

      # Insert multiple files
      _file1 = insert_code_file(%{
        codebase_id: codebase_id,
        file_path: "lib/module1.ex",
        language: "elixir",
        content: "defmodule Module1, do: def test, do: :ok"
      })

      _file2 = insert_code_file(%{
        codebase_id: codebase_id,
        file_path: "lib/module2.ex",
        language: "elixir",
        content: "defmodule Module2, do: def test, do: :ok"
      })

      # Analyze entire codebase
      results = CodeAnalyzer.analyze_codebase_from_db(codebase_id)

      assert length(results) == 2
      assert Enum.all?(results, fn {_path, result} ->
        match?({:ok, _}, result)
      end)
    end

    test "handles mixed language codebase" do
      codebase_id = "polyglot-test"

      # Insert files in different languages
      _elixir = insert_code_file(%{
        codebase_id: codebase_id,
        file_path: "lib/app.ex",
        language: "elixir",
        content: "defmodule App, do: def start, do: :ok"
      })

      _rust = insert_code_file(%{
        codebase_id: codebase_id,
        file_path: "native/lib.rs",
        language: "rust",
        content: "fn main() { println!(\"Hello\"); }"
      })

      _python = insert_code_file(%{
        codebase_id: codebase_id,
        file_path: "scripts/deploy.py",
        language: "python",
        content: "def deploy():\n    pass"
      })

      # Analyze
      results = CodeAnalyzer.analyze_codebase_from_db(codebase_id)

      assert length(results) == 3

      # Check each language was analyzed
      languages = results
        |> Enum.map(fn {_path, {:ok, analysis}} -> analysis.language_id end)
        |> Enum.sort()

      assert "elixir" in languages
      assert "rust" in languages
      assert "python" in languages
    end

    test "returns empty list for non-existent codebase" do
      results = CodeAnalyzer.analyze_codebase_from_db("non-existent")
      assert results == []
    end

    test "handles analysis errors for individual files" do
      codebase_id = "error-test"

      # Valid file
      _valid = insert_code_file(%{
        codebase_id: codebase_id,
        file_path: "valid.ex",
        language: "elixir",
        content: "defmodule Valid, do: :ok"
      })

      # Invalid language
      _invalid = insert_code_file(%{
        codebase_id: codebase_id,
        file_path: "invalid.xyz",
        language: "unknown",
        content: "code"
      })

      results = CodeAnalyzer.analyze_codebase_from_db(codebase_id)

      # Should have both results
      assert length(results) == 2

      # Check one succeeded, one failed
      successes = Enum.count(results, fn {_, result} -> match?({:ok, _}, result) end)
      failures = Enum.count(results, fn {_, result} -> match?({:error, _}, result) end)

      assert successes == 1
      assert failures == 1
    end
  end

  describe "batch_rca_metrics_from_db/1" do
    test "analyzes only RCA-supported languages" do
      codebase_id = "rca-test"

      # RCA-supported language
      _rust = insert_code_file(%{
        codebase_id: codebase_id,
        file_path: "src/lib.rs",
        language: "rust",
        content: "fn main() {}"
      })

      # Non-RCA language
      _elixir = insert_code_file(%{
        codebase_id: codebase_id,
        file_path: "lib/app.ex",
        language: "elixir",
        content: "defmodule App, do: :ok"
      })

      results = CodeAnalyzer.batch_rca_metrics_from_db(codebase_id)

      # Should only analyze Rust file
      assert length(results) == 1

      {path, {:ok, metrics}} = List.first(results)
      assert path == "src/lib.rs"
      assert Map.has_key?(metrics, :cyclomatic_complexity)
    end

    test "handles all RCA-supported languages" do
      codebase_id = "all-rca-test"

      # Create files for each RCA-supported language
      rca_files = [
        {"test.rs", "rust", "fn main() {}"},
        {"test.c", "c", "int main() { return 0; }"},
        {"test.cpp", "cpp", "int main() { return 0; }"},
        {"test.cs", "csharp", "class Program { static void Main() {} }"},
        {"test.js", "javascript", "function test() {}"},
        {"test.ts", "typescript", "function test(): void {}"},
        {"test.py", "python", "def test():\n    pass"},
        {"test.java", "java", "class Test { public static void main(String[] args) {} }"},
        {"test.go", "go", "func main() {}"}
      ]

      Enum.each(rca_files, fn {path, lang, content} ->
        insert_code_file(%{
          codebase_id: codebase_id,
          file_path: path,
          language: lang,
          content: content
        })
      end)

      results = CodeAnalyzer.batch_rca_metrics_from_db(codebase_id)

      # Should analyze all 9 files
      assert length(results) == 9

      # All should have RCA metrics
      assert Enum.all?(results, fn {_path, result} ->
        match?({:ok, %{cyclomatic_complexity: _}}, result)
      end)
    end

    test "returns empty list for codebase with no RCA-supported files" do
      codebase_id = "no-rca-test"

      # Only non-RCA languages
      _elixir = insert_code_file(%{
        codebase_id: codebase_id,
        file_path: "lib/app.ex",
        language: "elixir",
        content: "defmodule App, do: :ok"
      })

      _json = insert_code_file(%{
        codebase_id: codebase_id,
        file_path: "config.json",
        language: "json",
        content: "{}"
      })

      results = CodeAnalyzer.batch_rca_metrics_from_db(codebase_id)
      assert results == []
    end
  end

  describe "performance with large codebases" do
    @tag :slow
    test "analyzes 100 files efficiently" do
      codebase_id = "large-codebase-test"

      # Insert 100 files
      Enum.each(1..100, fn i ->
        insert_code_file(%{
          codebase_id: codebase_id,
          file_path: "lib/module_#{i}.ex",
          language: "elixir",
          content: """
          defmodule Module#{i} do
            def function_a(x), do: x + 1
            def function_b(y), do: y * 2
          end
          """
        })
      end)

      # Time the analysis
      {time_microseconds, results} = :timer.tc(fn ->
        CodeAnalyzer.analyze_codebase_from_db(codebase_id)
      end)

      assert length(results) == 100

      # Should complete in reasonable time (< 10 seconds)
      time_seconds = time_microseconds / 1_000_000
      assert time_seconds < 10, "Analysis took #{time_seconds}s, expected < 10s"

      # Log performance
      IO.puts("\n100 files analyzed in #{Float.round(time_seconds, 2)}s")
      IO.puts("Average: #{Float.round(time_seconds * 1000 / 100, 2)}ms per file")
    end

    @tag :slow
    test "caching improves performance on repeated analysis" do
      codebase_id = "cache-perf-test"

      # Insert 10 files
      Enum.each(1..10, fn i ->
        insert_code_file(%{
          codebase_id: codebase_id,
          file_path: "lib/module_#{i}.ex",
          language: "elixir",
          content: "defmodule Module#{i}, do: def test, do: :ok"
        })
      end)

      # Clear cache
      if Process.whereis(Singularity.CodeAnalyzer.Cache) do
        Singularity.CodeAnalyzer.Cache.clear()
      end

      # First run (uncached)
      {time1_us, _} = :timer.tc(fn ->
        CodeAnalyzer.analyze_codebase_from_db(codebase_id)
      end)

      # Second run (cached)
      {time2_us, _} = :timer.tc(fn ->
        CodeAnalyzer.analyze_codebase_from_db(codebase_id)
      end)

      # Second run should be faster (if cache is enabled)
      if Process.whereis(Singularity.CodeAnalyzer.Cache) do
        speedup = time1_us / time2_us
        IO.puts("\nCache speedup: #{Float.round(speedup, 2)}x")
        assert speedup > 1.5, "Expected at least 1.5x speedup, got #{Float.round(speedup, 2)}x"
      end
    end
  end

  # Helper function
  defp insert_code_file(attrs) do
    defaults = %{
      file_size: byte_size(attrs.content),
      line_count: length(String.split(attrs.content, "\n")),
      hash: :crypto.hash(:sha256, attrs.content) |> Base.encode16(case: :lower),
      parsed_at: DateTime.utc_now()
    }

    %CodeFile{}
    |> CodeFile.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end
end
