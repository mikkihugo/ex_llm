defmodule Singularity.MetaRegistry.QuerySystem do
  @moduledoc """
  Meta-registry query system for learning application patterns.
  
  This system learns from the application's actual usage patterns and provides
  suggestions based on what the application actually uses, regardless of language/framework.
  
  ## Tech Stack Agnostic
  
  Works with any language/framework:
  - PHP/Laravel → Learns Laravel patterns
  - Node.js/Express → Learns Express patterns  
  - Python/Django → Learns Django patterns
  - Go/Gin → Learns Gin patterns
  - Rust/Actix → Learns Actix patterns
  
  ## Learning Flow
  
  1. **Analyze application code** → Detect its patterns
  2. **Store in meta-registry** → Learn the app's style
  3. **Use for suggestions** → Suggest names/patterns that match the app's style
  4. **Track usage** → See which suggestions the app accepts
  """

  alias Singularity.Schemas.TechnologyDetection
  alias Singularity.MetaRegistry.NatsSubjects

  @doc """
  Learn naming patterns from application code.
  
  ## Examples
  
      # Learn from PHP/Laravel app
      learn_naming_patterns("my-laravel-app", %{
        language: "php",
        framework: "laravel", 
        patterns: ["UserController", "UserModel", "create_users_table"]
      })
      
      # Learn from Node.js/Express app
      learn_naming_patterns("my-express-app", %{
        language: "javascript",
        framework: "express",
        patterns: ["usersRouter", "authMiddleware", "usersController"]
      })
  """
  def learn_naming_patterns(codebase_id, %{language: language, framework: framework, patterns: patterns}) do
    # Store learned patterns in meta-registry
    attrs = %{
      codebase_id: codebase_id,
      snapshot_id: generate_snapshot_id(),
      metadata: %{
        learning_type: "naming_patterns",
        language: language,
        framework: framework,
        learned_at: DateTime.utc_now()
      },
      summary: %{
        naming_patterns: patterns,
        language: language,
        framework: framework
      },
      detected_technologies: ["language:#{language}", "framework:#{framework}"],
      capabilities: %{
        naming_patterns_count: length(patterns),
        language: language,
        framework: framework
      },
      service_structure: %{}
    }

    TechnologyDetection.upsert(Singularity.Repo, attrs)
  end

  @doc """
  Learn architecture patterns from application code.
  
  ## Examples
  
      # Learn from microservices app
      learn_architecture_patterns("my-microservices-app", %{
        patterns: ["event-driven", "microservices", "api-gateway"],
        services: ["user-service", "auth-service", "notification-service"]
      })
      
      # Learn from monolith app
      learn_architecture_patterns("my-monolith-app", %{
        patterns: ["layered", "mvc", "repository"],
        services: []
      })
  """
  def learn_architecture_patterns(codebase_id, %{patterns: patterns, services: services}) do
    attrs = %{
      codebase_id: codebase_id,
      snapshot_id: generate_snapshot_id(),
      metadata: %{
        learning_type: "architecture_patterns",
        learned_at: DateTime.utc_now()
      },
      summary: %{
        architecture_patterns: patterns,
        services: services
      },
      detected_technologies: Enum.map(patterns, &"architecture:#{&1}"),
      capabilities: %{
        architecture_patterns_count: length(patterns),
        services_count: length(services)
      },
      service_structure: %{
        services: services,
        architecture_type: determine_architecture_type(patterns)
      }
    }

    TechnologyDetection.upsert(Singularity.Repo, attrs)
  end

  @doc """
  Learn quality patterns from application code.
  
  ## Examples
  
      # Learn from high-quality codebase
      learn_quality_patterns("my-quality-app", %{
        patterns: ["test-driven", "type-safe", "documented"],
        metrics: %{test_coverage: 95.0, documentation_coverage: 80.0}
      })
  """
  def learn_quality_patterns(codebase_id, %{patterns: patterns, metrics: metrics}) do
    attrs = %{
      codebase_id: codebase_id,
      snapshot_id: generate_snapshot_id(),
      metadata: %{
        learning_type: "quality_patterns",
        learned_at: DateTime.utc_now()
      },
      summary: %{
        quality_patterns: patterns,
        metrics: metrics
      },
      detected_technologies: Enum.map(patterns, &"quality:#{&1}"),
      capabilities: %{
        quality_patterns_count: length(patterns),
        test_coverage: Map.get(metrics, :test_coverage, 0.0),
        documentation_coverage: Map.get(metrics, :documentation_coverage, 0.0)
      },
      service_structure: %{}
    }

    TechnologyDetection.upsert(Singularity.Repo, attrs)
  end

  @doc """
  Query learned patterns for suggestions.
  
  ## Examples
  
      # Get naming suggestions based on learned patterns
      query_naming_suggestions("my-laravel-app", "controller")
      # Returns: ["UserController", "ProductController", "OrderController"]
      
      # Get architecture suggestions
      query_architecture_suggestions("my-microservices-app", "service")
      # Returns: ["user-service", "auth-service", "notification-service"]
  """
  def query_naming_suggestions(codebase_id, context) do
    case TechnologyDetection.latest(Singularity.Repo, codebase_id) do
      nil -> []
      detection ->
        patterns = Map.get(detection.summary, :naming_patterns, [])
        filter_patterns_by_context(patterns, context)
    end
  end

  def query_architecture_suggestions(codebase_id, context) do
    case TechnologyDetection.latest(Singularity.Repo, codebase_id) do
      nil -> []
      detection ->
        patterns = Map.get(detection.summary, :architecture_patterns, [])
        services = Map.get(detection.service_structure, :services, [])
        filter_patterns_by_context(patterns ++ services, context)
    end
  end

  def query_quality_suggestions(codebase_id, context) do
    case TechnologyDetection.latest(Singularity.Repo, codebase_id) do
      nil -> []
      detection ->
        patterns = Map.get(detection.summary, :quality_patterns, [])
        filter_patterns_by_context(patterns, context)
    end
  end

  @doc """
  Track usage of suggestions to improve learning.
  
  ## Examples
  
      # Track when a naming suggestion is used
      track_usage(:naming, "my-laravel-app", "UserController", true)
      
      # Track when an architecture suggestion is used
      track_usage(:architecture, "my-microservices-app", "user-service", true)
  """
  def track_usage(category, codebase_id, suggestion, accepted) do
    usage_event = %{
      category: category,
      codebase_id: codebase_id,
      suggestion: suggestion,
      accepted: accepted,
      timestamp: DateTime.utc_now()
    }

    # Publish to NATS for real-time learning
    subject = NatsSubjects.usage(category)
    # TODO: Publish to NATS
    # NatsClient.publish(subject, usage_event)
    
    # Store in database for persistence
    # TODO: Store usage event in database
    {:ok, usage_event}
  end

  # Private functions

  defp generate_snapshot_id do
    :os.system_time(:millisecond)
  end

  defp determine_architecture_type(patterns) do
    cond do
      "microservices" in patterns -> "microservices"
      "event-driven" in patterns -> "event-driven"
      "layered" in patterns -> "layered"
      "mvc" in patterns -> "mvc"
      true -> "unknown"
    end
  end

  defp filter_patterns_by_context(patterns, context) do
    context_lower = String.downcase(context)
    
    patterns
    |> Enum.filter(fn pattern ->
      pattern
      |> String.downcase()
      |> String.contains?(context_lower)
    end)
    |> Enum.take(5)  # Limit to top 5 suggestions
  end
end