defmodule Singularity.MetaRegistry.Frameworks.Ecto do
  @moduledoc """
  Ecto framework learning patterns.
  
  Learns from Ecto ORM patterns to improve our database usage.
  """

  alias Singularity.MetaRegistry.QuerySystem

  @doc """
  Learn from Ecto ORM patterns.
  
  ## Examples
  
      # Learn from our Ecto schemas
      learn_patterns(%{
        schemas: ["CodeChunk", "TechnologyDetection", "FileArchitecturePattern"],
        queries: ["Ecto.Query", "Ecto.Changeset", "Ecto.Repo"],
        patterns: ["use Ecto.Schema", "field :", "belongs_to", "has_many"]
      })
  """
  def learn_patterns(attrs) do
    QuerySystem.learn_naming_patterns("ecto-framework", %{
      language: "elixir",
      framework: "ecto",
      patterns: attrs.patterns
    })
  end

  @doc """
  Get Ecto suggestions based on learned patterns.
  
  ## Examples
  
      # Get schema suggestions
      get_suggestions("user", "schema")
      # Returns: ["UserProfile", "UserSession", "UserPreference"]
      
      # Get function suggestions
      get_suggestions("user", "function")
      # Returns: ["changeset_user", "upsert_user", "latest_user"]
  """
  def get_suggestions(context, type) do
    QuerySystem.query_naming_suggestions("ecto-framework", type)
    |> Enum.map(fn pattern ->
      case type do
        "schema" -> "#{context}#{pattern}"
        "function" -> "#{pattern}_#{context}"
        _ -> pattern
      end
    end)
  end

  @doc """
  Initialize Ecto framework patterns.
  """
  def initialize_patterns do
    learn_patterns(%{
      schemas: ["CodeChunk", "TechnologyDetection", "FileArchitecturePattern"],
      queries: ["Ecto.Query", "Ecto.Changeset", "Ecto.Repo"],
      patterns: [
        "use Ecto.Schema", "field :", "belongs_to", "has_many",
        "def changeset", "def upsert", "def latest"
      ]
    })
  end
end