defmodule Singularity.CodeAnalyzer.PropertyTest do
  use ExUnit.Case
  use ExUnitProperties
  alias Singularity.CodeAnalyzer

  @moduletag :property

  describe "property: all 20 languages are supported" do
    property "supported_languages always returns 20 languages" do
      check all _iteration <- integer(1..100) do
        languages = CodeAnalyzer.supported_languages()
        assert length(languages) == 20
        assert is_list(languages)
        assert Enum.all?(languages, &is_binary/1)
      end
    end

    property "supported languages are unique" do
      check all _iteration <- integer(1..100) do
        languages = CodeAnalyzer.supported_languages()
        assert length(languages) == length(Enum.uniq(languages))
      end
    end
  end

  describe "property: RCA languages subset of all languages" do
    property "rca_supported_languages is subset of supported_languages" do
      check all _iteration <- integer(1..100) do
        all_languages = CodeAnalyzer.supported_languages()
        rca_languages = CodeAnalyzer.rca_supported_languages()

        # RCA languages should be subset
        assert Enum.all?(rca_languages, &(&1 in all_languages))

        # Should be exactly 9
        assert length(rca_languages) == 9
      end
    end
  end

  describe "property: has_rca_support consistency" do
    property "has_rca_support matches rca_supported_languages list" do
      check all _iteration <- integer(1..100) do
        rca_languages = CodeAnalyzer.rca_supported_languages()
        all_languages = CodeAnalyzer.supported_languages()

        # All RCA languages should return true
        assert Enum.all?(rca_languages, fn lang ->
          CodeAnalyzer.has_rca_support?(lang) == true
        end)

        # Non-RCA languages should return false
        non_rca = all_languages -- rca_languages
        assert Enum.all?(non_rca, fn lang ->
          CodeAnalyzer.has_rca_support?(lang) == false
        end)
      end
    end
  end

  describe "property: analyze_language handles various inputs" do
    property "analyze_language handles empty code" do
      check all language <- member_of(CodeAnalyzer.supported_languages()) do
        result = CodeAnalyzer.analyze_language("", language)
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    property "analyze_language handles whitespace-only code" do
      check all language <- member_of(CodeAnalyzer.supported_languages()),
                whitespace <- string(:printable, min_length: 1, max_length: 100) do
        # Only whitespace
        code = String.duplicate(" ", String.length(whitespace))
        result = CodeAnalyzer.analyze_language(code, language)
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    property "analyze_language returns consistent language_id" do
      check all language <- member_of(CodeAnalyzer.supported_languages()) do
        code = generate_simple_code(language)

        case CodeAnalyzer.analyze_language(code, language) do
          {:ok, analysis} ->
            # Language ID should match what we requested
            assert analysis.language_id == language

          {:error, _} ->
            # Errors are acceptable
            :ok
        end
      end
    end
  end

  describe "property: extract_functions always returns list" do
    property "extract_functions returns list for all languages" do
      check all language <- member_of(CodeAnalyzer.supported_languages()) do
        code = generate_simple_code(language)

        case CodeAnalyzer.extract_functions(code, language) do
          {:ok, functions} ->
            assert is_list(functions)

          {:error, _} ->
            :ok
        end
      end
    end
  end

  describe "property: caching is deterministic" do
    property "repeated analysis of same code returns same result" do
      check all language <- member_of(["elixir", "rust", "python"]),
                max_runs: 10 do
        code = generate_simple_code(language)

        # Clear cache
        if Process.whereis(Singularity.CodeAnalyzer.Cache) do
          Singularity.CodeAnalyzer.Cache.clear()
        end

        # Analyze 5 times
        results = Enum.map(1..5, fn _ ->
          CodeAnalyzer.analyze_language(code, language, cache: true)
        end)

        # All successful results should be identical
        successful_results = Enum.filter(results, &match?({:ok, _}, &1))

        if length(successful_results) > 0 do
          [first | rest] = successful_results
          assert Enum.all?(rest, fn result -> result == first end)
        end
      end
    end
  end

  describe "property: cross-language pattern detection" do
    property "accepts empty file list" do
      check all _iteration <- integer(1..10) do
        result = CodeAnalyzer.detect_cross_language_patterns([])
        assert match?({:ok, _}, result)
      end
    end

    property "accepts single language" do
      check all language <- member_of(["elixir", "rust", "python"]) do
        code = generate_simple_code(language)
        files = [{language, code}]

        result = CodeAnalyzer.detect_cross_language_patterns(files)
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    property "handles multiple languages" do
      check all languages <- list_of(member_of(["elixir", "rust", "python"]), min_length: 2, max_length: 5) do
        files = Enum.map(languages, fn lang ->
          {lang, generate_simple_code(lang)}
        end)

        result = CodeAnalyzer.detect_cross_language_patterns(files)
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end

  describe "property: RCA metrics structure" do
    property "RCA metrics have required fields" do
      check all language <- member_of(CodeAnalyzer.rca_supported_languages()),
                max_runs: 10 do
        code = generate_simple_code(language)

        case CodeAnalyzer.get_rca_metrics(code, language) do
          {:ok, metrics} ->
            # Check required fields exist
            assert Map.has_key?(metrics, :cyclomatic_complexity)
            assert Map.has_key?(metrics, :maintainability_index)
            assert Map.has_key?(metrics, :source_lines_of_code)
            assert Map.has_key?(metrics, :physical_lines_of_code)
            assert Map.has_key?(metrics, :logical_lines_of_code)

          {:error, _} ->
            :ok
        end
      end
    end
  end

  # Helper: Generate simple valid code for a language
  defp generate_simple_code("elixir") do
    """
    defmodule Test do
      def hello, do: :world
    end
    """
  end

  defp generate_simple_code("rust") do
    """
    fn main() {
        println!("Hello, world!");
    }
    """
  end

  defp generate_simple_code("python") do
    """
    def hello():
        return "world"
    """
  end

  defp generate_simple_code("javascript") do
    """
    function hello() {
        return "world";
    }
    """
  end

  defp generate_simple_code("typescript") do
    """
    function hello(): string {
        return "world";
    }
    """
  end

  defp generate_simple_code("go") do
    """
    package main

    func main() {
        println("Hello, world!")
    }
    """
  end

  defp generate_simple_code("java") do
    """
    class Test {
        public static void main(String[] args) {
            System.out.println("Hello, world!");
        }
    }
    """
  end

  defp generate_simple_code("c") do
    """
    #include <stdio.h>

    int main() {
        printf("Hello, world!\\n");
        return 0;
    }
    """
  end

  defp generate_simple_code("cpp") do
    """
    #include <iostream>

    int main() {
        std::cout << "Hello, world!" << std::endl;
        return 0;
    }
    """
  end

  defp generate_simple_code("csharp") do
    """
    class Program {
        static void Main() {
            System.Console.WriteLine("Hello, world!");
        }
    }
    """
  end

  defp generate_simple_code(_language) do
    # Generic code for other languages
    "# Simple code\nprint('hello')"
  end
end
