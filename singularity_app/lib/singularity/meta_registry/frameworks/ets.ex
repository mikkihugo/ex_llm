defmodule Singularity.MetaRegistry.Frameworks.Ets do
  @moduledoc """
  ETS framework learning patterns.
  
  Learns from ETS caching patterns to improve our caching usage.
  """

  alias Singularity.MetaRegistry.QuerySystem

  @doc """
  Learn from ETS caching patterns.
  
  ## Examples
  
      # Learn from our ETS tables
      learn_patterns(%{
        tables: ["naming_patterns", "architecture_patterns", "quality_patterns"],
        operations: ["lookup", "insert", "delete", "select"],
        patterns: ["fast_cache", "in_memory", "key_value"]
      })
  """
  def learn_patterns(attrs) do
    QuerySystem.learn_architecture_patterns("ets-framework", %{
      patterns: attrs.patterns,
      services: attrs.tables
    })
  end

  @doc """
  Get ETS suggestions based on learned patterns.
  
  ## Examples
  
      # Get table suggestions
      get_suggestions("user", "table")
      # Returns: ["user_cache", "user_patterns", "user_learning"]
      
      # Get operation suggestions
      get_suggestions("user", "operation")
      # Returns: ["lookup_user", "insert_user", "delete_user"]
  """
  def get_suggestions(context, type) do
    QuerySystem.query_architecture_suggestions("ets-framework", type)
    |> Enum.map(fn pattern ->
      case type do
        "table" -> "#{context}_#{pattern}"
        "operation" -> "#{pattern}_#{context}"
        _ -> pattern
      end
    end)
  end

  @doc """
  Initialize ETS framework patterns.
  """
  def initialize_patterns do
    learn_patterns(%{
      tables: [
        "naming_patterns", "architecture_patterns", "quality_patterns",
        "template_cache", "learning_cache", "suggestion_cache"
      ],
      operations: ["lookup", "insert", "delete", "select"],
      patterns: ["fast_cache", "in_memory", "key_value", "ets_table"]
    })
  end
end