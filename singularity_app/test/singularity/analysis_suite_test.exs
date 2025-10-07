defmodule Singularity.AnalysisSuiteTest do
  use ExUnit.Case, async: true
  alias Singularity.AnalysisSuite

  describe "unified_code_intelligence/3" do
    test "returns error when NIF not loaded" do
      # This will return an error until the NIF is properly implemented
      assert {:error, _} = AnalysisSuite.unified_code_intelligence(
        "Create async worker",
        "/path/to/codebase", 
        "elixir"
      )
    end
  end

  describe "analyze_code/2" do
    test "returns error when NIF not loaded" do
      assert {:error, _} = AnalysisSuite.analyze_code("/path/to/codebase", "elixir")
    end
  end

  describe "find_similar_code/2" do
    test "returns error when NIF not loaded" do
      assert {:error, _} = AnalysisSuite.find_similar_code("async worker", "elixir")
    end
  end

  describe "get_package_recommendations/2" do
    test "returns error when NIF not loaded" do
      assert {:error, _} = AnalysisSuite.get_package_recommendations("web scraping", "elixir")
    end
  end

  describe "generate_code/3" do
    test "returns error when NIF not loaded" do
      assert {:error, _} = AnalysisSuite.generate_code(
        "Create GenServer",
        "elixir",
        []
      )
    end
  end

  describe "calculate_quality_metrics/2" do
    test "returns error when NIF not loaded" do
      assert {:error, _} = AnalysisSuite.calculate_quality_metrics("def foo, do: :bar", "elixir")
    end
  end
end