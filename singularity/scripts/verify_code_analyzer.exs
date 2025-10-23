#!/usr/bin/env elixir

# Production Verification Script for CodeAnalyzer
#
# Usage:
#   mix run scripts/verify_code_analyzer.exs
#
# This script verifies that all CodeAnalyzer NIFs are properly loaded
# and functional in a production environment.

defmodule CodeAnalyzerVerification do
  @moduledoc """
  Production verification for CodeAnalyzer multi-language support.
  """

  alias Singularity.CodeAnalyzer

  def run do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("CODE ANALYZER PRODUCTION VERIFICATION")
    IO.puts(String.duplicate("=", 70) <> "\n")

    results = [
      verify_nif_loading(),
      verify_language_support(),
      verify_rca_support(),
      verify_basic_analysis(),
      verify_function_extraction(),
      verify_rca_metrics(),
      verify_cross_language_patterns(),
      verify_cache_functionality(),
      verify_database_integration()
    ]

    print_summary(results)

    # Exit with appropriate code
    if Enum.all?(results, fn {status, _, _} -> status == :ok end) do
      IO.puts("\n✅ All verifications passed!")
      System.halt(0)
    else
      IO.puts("\n❌ Some verifications failed!")
      System.halt(1)
    end
  end

  defp verify_nif_loading do
    IO.puts("1. Verifying NIFs are loaded...")

    try do
      # Try calling a simple NIF function
      languages = CodeAnalyzer.supported_languages()

      if is_list(languages) and length(languages) > 0 do
        {:ok, "NIFs loaded successfully", "#{length(languages)} languages available"}
      else
        {:error, "NIFs returned invalid data", ""}
      end
    rescue
      e ->
        {:error, "NIF loading failed", Exception.message(e)}
    end
  end

  defp verify_language_support do
    IO.puts("2. Verifying language support...")

    expected_languages = [
      "elixir",
      "erlang",
      "gleam",
      "rust",
      "c",
      "cpp",
      "csharp",
      "go",
      "javascript",
      "typescript",
      "python",
      "java",
      "lua",
      "bash",
      "json",
      "yaml",
      "toml",
      "markdown",
      "dockerfile",
      "sql"
    ]

    languages = CodeAnalyzer.supported_languages()

    missing = expected_languages -- languages
    extra = languages -- expected_languages

    cond do
      length(missing) > 0 ->
        {:error, "Missing languages", Enum.join(missing, ", ")}

      length(extra) > 0 ->
        {:warning, "Unexpected languages", Enum.join(extra, ", ")}

      true ->
        {:ok, "All 20 languages supported", ""}
    end
  end

  defp verify_rca_support do
    IO.puts("3. Verifying RCA metrics support...")

    expected_rca = [
      "rust",
      "c",
      "cpp",
      "csharp",
      "javascript",
      "typescript",
      "python",
      "java",
      "go"
    ]

    rca_languages = CodeAnalyzer.rca_supported_languages()

    missing = expected_rca -- rca_languages

    if length(missing) == 0 and length(rca_languages) == 9 do
      {:ok, "RCA metrics available for 9 languages", ""}
    else
      {:error, "RCA metrics incomplete", "Missing: #{Enum.join(missing, ", ")}"}
    end
  end

  defp verify_basic_analysis do
    IO.puts("4. Verifying basic analysis...")

    test_cases = [
      {"elixir", "defmodule Test, do: def hello, do: :world"},
      {"rust", "fn main() { println!(\"Hello\"); }"},
      {"python", "def hello():\n    return 'world'"}
    ]

    results =
      Enum.map(test_cases, fn {lang, code} ->
        case CodeAnalyzer.analyze_language(code, lang) do
          {:ok, analysis} ->
            analysis.language_id == lang

          {:error, _} ->
            false
        end
      end)

    if Enum.all?(results) do
      {:ok, "Basic analysis working", "Tested #{length(test_cases)} languages"}
    else
      {:error, "Basic analysis failed", ""}
    end
  end

  defp verify_function_extraction do
    IO.puts("5. Verifying function extraction...")

    code = """
    defmodule Test do
      def func1(x), do: x + 1
      def func2(y), do: y * 2
    end
    """

    case CodeAnalyzer.extract_functions(code, "elixir") do
      {:ok, functions} when is_list(functions) ->
        {:ok, "Function extraction working", "Found #{length(functions)} functions"}

      {:error, reason} ->
        {:error, "Function extraction failed", reason}
    end
  end

  defp verify_rca_metrics do
    IO.puts("6. Verifying RCA metrics...")

    code = """
    fn fibonacci(n: u32) -> u32 {
        match n {
            0 => 0,
            1 => 1,
            _ => fibonacci(n - 1) + fibonacci(n - 2)
        }
    }
    """

    case CodeAnalyzer.get_rca_metrics(code, "rust") do
      {:ok, metrics} ->
        required_fields = [
          :cyclomatic_complexity,
          :maintainability_index,
          :source_lines_of_code
        ]

        if Enum.all?(required_fields, &Map.has_key?(metrics, &1)) do
          {:ok, "RCA metrics working", "CC: #{metrics.cyclomatic_complexity}"}
        else
          {:error, "RCA metrics incomplete", "Missing fields"}
        end

      {:error, reason} ->
        {:error, "RCA metrics failed", reason}
    end
  end

  defp verify_cross_language_patterns do
    IO.puts("7. Verifying cross-language pattern detection...")

    elixir_code = """
    defmodule API do
      def get_user(id) do
        case fetch(id) do
          {:ok, user} -> {:ok, user}
          {:error, reason} -> {:error, reason}
        end
      end
    end
    """

    rust_code = """
    fn get_user(id: u32) -> Result<User, Error> {
        match fetch(id) {
            Ok(user) => Ok(user),
            Err(e) => Err(e)
        }
    }
    """

    files = [{"elixir", elixir_code}, {"rust", rust_code}]

    case CodeAnalyzer.detect_cross_language_patterns(files) do
      {:ok, patterns} when is_list(patterns) ->
        {:ok, "Cross-language detection working", "Found #{length(patterns)} patterns"}

      {:error, reason} ->
        {:error, "Cross-language detection failed", reason}
    end
  end

  defp verify_cache_functionality do
    IO.puts("8. Verifying cache functionality...")

    if Process.whereis(Singularity.CodeAnalyzer.Cache) do
      # Clear cache
      Singularity.CodeAnalyzer.Cache.clear()

      # Perform analysis twice
      code = "def test, do: :ok"
      CodeAnalyzer.analyze_language(code, "elixir", cache: true)
      CodeAnalyzer.analyze_language(code, "elixir", cache: true)

      # Check stats
      stats = Singularity.CodeAnalyzer.Cache.stats()

      if stats.hits >= 1 do
        {:ok, "Cache working", "Hit rate: #{Float.round(stats.hit_rate * 100, 1)}%"}
      else
        {:warning, "Cache not hitting", "Misses: #{stats.misses}"}
      end
    else
      {:warning, "Cache not running", "Cache process not found"}
    end
  end

  defp verify_database_integration do
    IO.puts("9. Verifying database integration...")

    # Check if we can access the database
    try do
      import Ecto.Query
      alias Singularity.{Repo, Schemas.CodeFile}

      # Try to query code files
      count = Repo.aggregate(CodeFile, :count)

      if count >= 0 do
        {:ok, "Database integration working", "#{count} code files in database"}
      else
        {:warning, "Database empty", "No files to analyze"}
      end
    rescue
      e ->
        {:error, "Database integration failed", Exception.message(e)}
    end
  end

  defp print_summary(results) do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("VERIFICATION SUMMARY")
    IO.puts(String.duplicate("=", 70) <> "\n")

    Enum.with_index(results, 1)
    |> Enum.each(fn {{status, message, details}, index} ->
      status_icon =
        case status do
          :ok -> "✅"
          :warning -> "⚠️ "
          :error -> "❌"
        end

      IO.puts("#{status_icon} #{index}. #{message}")

      if details != "" do
        IO.puts("   #{details}")
      end
    end)

    IO.puts("")

    # Count results
    ok_count = Enum.count(results, fn {status, _, _} -> status == :ok end)
    warning_count = Enum.count(results, fn {status, _, _} -> status == :warning end)
    error_count = Enum.count(results, fn {status, _, _} -> status == :error end)

    IO.puts("Results: #{ok_count} passed, #{warning_count} warnings, #{error_count} failed")
  end
end

# Run verification
CodeAnalyzerVerification.run()
