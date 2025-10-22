defmodule Singularity.MetaRegistry.Frameworks.Nats do
  @moduledoc """
  NATS framework learning patterns.
  
  Learns from NATS messaging patterns to improve our NATS usage.
  """

  alias Singularity.MetaRegistry.QuerySystem

  @doc """
  Learn from NATS messaging patterns.
  
  ## Examples
  
      # Learn from our NATS subjects
      learn_patterns(%{
        subjects: ["llm.provider.claude", "code.analysis.parse", "meta.registry.naming"],
        messaging: ["request/response", "pub/sub", "streaming"],
        patterns: ["subject.hierarchy", "wildcard.subjects", "message.routing"]
      })
  """
  def learn_patterns(attrs) do
    QuerySystem.learn_architecture_patterns("nats-framework", %{
      patterns: attrs.patterns,
      services: attrs.subjects
    })
  end

  @doc """
  Get NATS suggestions based on learned patterns.
  
  ## Examples
  
      # Get subject suggestions
      get_suggestions("search", "subject")
      # Returns: ["search.semantic", "search.hybrid", "search.vector"]
      
      # Get service suggestions
      get_suggestions("user", "service")
      # Returns: ["user-service", "user-api", "user-gateway"]
  """
  def get_suggestions(context, type) do
    QuerySystem.query_architecture_suggestions("nats-framework", type)
    |> Enum.map(fn pattern ->
      case type do
        "subject" -> "#{context}.#{pattern}"
        "service" -> "#{context}-#{pattern}"
        _ -> pattern
      end
    end)
  end

  @doc """
  Initialize NATS framework patterns.
  """
  def initialize_patterns do
    learn_patterns(%{
      subjects: [
        "llm.provider.claude", "llm.provider.gemini", "llm.provider.openai",
        "code.analysis.parse", "code.analysis.embed", "code.analysis.search",
        "meta.registry.naming", "meta.registry.architecture", "meta.registry.quality"
      ],
      messaging: ["request/response", "pub/sub", "streaming"],
      patterns: [
        "subject.hierarchy", "wildcard.subjects", "message.routing",
        "llm.provider.*", "code.analysis.*", "meta.registry.*"
      ]
    })
  end
end