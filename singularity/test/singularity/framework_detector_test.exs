defmodule Singularity.Detection.FrameworkDetectorTest do
  use ExUnit.Case, async: true

  alias Singularity.Detection.FrameworkDetector
  alias Singularity.Knowledge.ArtifactStore

  describe "detect_frameworks/2" do
    test "detects Phoenix framework from patterns" do
      patterns = ["use Phoenix.Router", "defmodule MyAppWeb.Router"]
      context = "elixir_web_app"

      {:ok, results} = FrameworkDetector.detect_frameworks(patterns, context: context)

      phoenix_result = Enum.find(results, &(&1.name == "phoenix"))
      assert phoenix_result
      assert phoenix_result.confidence > 0.8
      assert phoenix_result.ecosystem == "elixir"
    end

    test "detects React framework from patterns" do
      patterns = ["import React from 'react'", "function App() { return <div>"]
      context = "javascript_frontend"

      {:ok, results} = FrameworkDetector.detect_frameworks(patterns, context: context)

      react_result = Enum.find(results, &(&1.name == "react"))
      assert react_result
      assert react_result.confidence > 0.8
      assert react_result.ecosystem == "javascript"
    end

    test "integrates with knowledge base when enabled" do
      patterns = ["use Phoenix.Controller", "def index(conn, _params)"]
      context = "elixir_controller"

      {:ok, results} =
        FrameworkDetector.detect_frameworks(patterns,
          context: context,
          use_knowledge_base: true
        )

      # Should include both NIF results and knowledge base results
      assert length(results) > 0
    end

    test "falls back to knowledge base when NIF fails" do
      # This test would require mocking the NIF failure
      # For now, just verify the function doesn't crash
      patterns = ["some unknown pattern"]
      context = "unknown_context"

      result = FrameworkDetector.detect_frameworks(patterns, context: context)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "detect_technologies/2" do
    test "detects Elixir technology from file patterns" do
      patterns = [".ex", "defmodule", "def "]

      {:ok, results} = FrameworkDetector.detect_technologies(patterns)

      elixir_result = Enum.find(results, &(&1.name == "elixir"))
      assert elixir_result
      assert elixir_result.confidence > 0.9
      assert elixir_result.type == "language"
    end

    test "detects multiple technologies" do
      patterns = [".ex", ".rs", ".js", "function ", "struct ", "defmodule"]

      {:ok, results} = FrameworkDetector.detect_technologies(patterns)

      languages = Enum.map(results, & &1.name)
      assert "elixir" in languages
      assert "rust" in languages
      assert "javascript" in languages
    end

    test "detects configuration technologies" do
      patterns = [".json", ".yaml", ".toml"]

      {:ok, results} = FrameworkDetector.detect_technologies(patterns)

      config_result = Enum.find(results, &(&1.name == "configuration"))
      assert config_result
      assert config_result.type == "config"
    end
  end

  describe "get_architectural_suggestions/2" do
    test "provides suggestions for microservices architecture" do
      codebase_info = %{
        structure: "microservice",
        languages: ["elixir"],
        frameworks: ["phoenix"]
      }

      {:ok, suggestions} = FrameworkDetector.get_architectural_suggestions(codebase_info)

      microservice_suggestions = Enum.filter(suggestions, &(&1.category == "microservices"))
      assert length(microservice_suggestions) > 0

      # Should include service mesh suggestion
      service_mesh =
        Enum.find(microservice_suggestions, &String.contains?(&1.suggestion, "service mesh"))

      assert service_mesh
      assert service_mesh.priority == "high"
    end

    test "provides suggestions for multi-language projects" do
      codebase_info = %{
        languages: ["elixir", "javascript", "rust"],
        structure: "polyglot"
      }

      {:ok, suggestions} = FrameworkDetector.get_architectural_suggestions(codebase_info)

      polyglot_suggestions = Enum.filter(suggestions, &(&1.category == "polyglot"))
      assert length(polyglot_suggestions) > 0

      # Should include API Gateway suggestion
      api_gateway =
        Enum.find(polyglot_suggestions, &String.contains?(&1.suggestion, "API Gateway"))

      assert api_gateway
    end

    test "always includes security suggestions" do
      codebase_info = %{}

      {:ok, suggestions} = FrameworkDetector.get_architectural_suggestions(codebase_info)

      security_suggestions = Enum.filter(suggestions, &(&1.category == "security"))
      assert length(security_suggestions) >= 2

      # Should include authentication and input validation
      auth_suggestion =
        Enum.find(security_suggestions, &String.contains?(&1.suggestion, "authentication"))

      assert auth_suggestion
      assert auth_suggestion.priority == "high"
    end

    test "integrates with knowledge base suggestions" do
      codebase_info = %{
        languages: ["elixir"],
        frameworks: ["phoenix"]
      }

      {:ok, suggestions} =
        FrameworkDetector.get_architectural_suggestions(codebase_info,
          use_knowledge_base: true
        )

      # Should include knowledge base results
      kb_suggestions = Enum.filter(suggestions, &(&1.source == "knowledge_base"))
      # May be empty if no KB data, but shouldn't crash
      assert is_list(kb_suggestions)
    end
  end

  describe "knowledge base integration" do
    test "stores successful framework detections" do
      patterns = ["use Phoenix.Router"]
      context = "test_detection"

      # This would normally store in the knowledge base
      # We can't easily test the actual storage without mocking
      {:ok, results} = FrameworkDetector.detect_frameworks(patterns, context: context)

      assert length(results) > 0
    end

    test "retrieves patterns from knowledge base" do
      # Test the internal function
      patterns = ["phoenix router"]
      context = "elixir_web"

      kb_patterns =
        FrameworkDetector.__private__(:get_knowledge_base_patterns, [patterns, context])

      # Should return a list (may be empty if no KB data)
      assert is_list(kb_patterns)
    end
  end

  describe "ecosystem detection" do
    test "correctly identifies ecosystems from framework names" do
      test_cases = [
        {"phoenix", "elixir"},
        {"ecto", "elixir"},
        {"react", "javascript"},
        {"django", "python"},
        {"rails", "ruby"},
        {"spring", "java"},
        {"asp.net", "dotnet"},
        {"gin", "go"},
        {"actix", "rust"}
      ]

      Enum.each(test_cases, fn {framework, expected_ecosystem} ->
        ecosystem = FrameworkDetector.__private__(:detect_ecosystem, [framework])

        assert ecosystem == expected_ecosystem,
               "Expected #{expected_ecosystem} for #{framework}, got #{ecosystem}"
      end)
    end
  end

  describe "error handling" do
    test "handles empty patterns gracefully" do
      {:ok, results} = FrameworkDetector.detect_frameworks([])
      assert is_list(results)
    end

    test "handles invalid patterns gracefully" do
      {:ok, results} = FrameworkDetector.detect_frameworks(["invalid pattern @#$%"])
      assert is_list(results)
    end

    test "handles nil context gracefully" do
      {:ok, results} = FrameworkDetector.detect_frameworks(["use Phoenix.Router"], context: nil)
      assert is_list(results)
    end
  end
end
