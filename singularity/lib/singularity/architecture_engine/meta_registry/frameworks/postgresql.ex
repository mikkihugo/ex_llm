defmodule Singularity.MetaRegistry.Frameworks.Postgresql do
  @moduledoc """
  PostgreSQL framework learning patterns.

  Learns from PostgreSQL database patterns to improve our database usage.
  """

  alias Singularity.MetaRegistry.QuerySystem

  @doc """
  Learn from PostgreSQL database patterns.

  ## Examples

      # Learn from our database schemas
      learn_patterns(%{
        tables: ["code_chunks", "technology_detections", "file_architecture_patterns"],
        queries: ["SELECT", "INSERT", "UPDATE", "DELETE"],
        indexes: ["GIN", "B-tree", "Hash"],
        patterns: ["codebase_id", "snapshot_id", "metadata", "summary"]
      })
  """
  def learn_patterns(attrs) do
    QuerySystem.learn_architecture_patterns("postgresql-framework", %{
      patterns: attrs.patterns,
      services: attrs.tables
    })
  end

  @doc """
  Get PostgreSQL suggestions based on learned patterns.

  ## Examples

      # Get table suggestions
      get_suggestions("user", "table")
      # Returns: ["user_profiles", "user_sessions", "user_preferences"]
      
      # Get column suggestions
      get_suggestions("user", "column")
      # Returns: ["user_id", "user_name", "user_email"]
  """
  def get_suggestions(context, type) do
    QuerySystem.query_architecture_suggestions("postgresql-framework", type)
    |> Enum.map(fn pattern ->
      case type do
        "table" -> "#{context}_#{pattern}"
        "column" -> "#{context}_#{pattern}"
        _ -> pattern
      end
    end)
  end

  @doc """
  Initialize PostgreSQL framework patterns.
  """
  def initialize_patterns do
    learn_patterns(%{
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
  end
end
