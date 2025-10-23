defmodule Singularity.MetaRegistry.Frameworks.ExUnit do
  @moduledoc """
  ExUnit framework learning patterns.

  Learns from ExUnit testing patterns to improve our testing.
  """

  alias Singularity.MetaRegistry.QuerySystem

  @doc """
  Learn from ExUnit testing patterns.

  ## Examples

      # Learn from our test modules
      learn_patterns(%{
        modules: ["ExUnit.Case", "ExUnit.CaseTemplate", "ExUnit.Callbacks"],
        functions: ["test", "describe", "it", "expect", "assert"],
        patterns: ["use ExUnit.Case", "test \"", "assert ", "refute "]
      })
  """
  def learn_patterns(attrs) do
    QuerySystem.learn_quality_patterns("exunit-framework", %{
      patterns: attrs.patterns,
      metrics: %{
        test_coverage: 85.0,
        documentation_coverage: 90.0
      }
    })
  end

  @doc """
  Get ExUnit suggestions based on learned patterns.

  ## Examples

      # Get test suggestions
      get_suggestions("user", "test")
      # Returns: ["test user creation", "test user validation", "test user deletion"]
      
      # Get assertion suggestions
      get_suggestions("user", "assertion")
      # Returns: ["assert_user_exists", "assert_user_valid", "assert_user_deleted"]
  """
  def get_suggestions(context, type) do
    QuerySystem.query_quality_suggestions("exunit-framework", type)
    |> Enum.map(fn pattern ->
      case type do
        "test" -> "#{pattern} #{context}"
        "assertion" -> "#{pattern}_#{context}"
        _ -> pattern
      end
    end)
  end

  @doc """
  Initialize ExUnit framework patterns.
  """
  def initialize_patterns do
    learn_patterns(%{
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
  end
end
