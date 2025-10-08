defmodule Singularity.MetaRegistry.MessageHandlers do
  @moduledoc """
  NATS message handlers for meta-registry system.
  
  Handles both app-facing requests and internal meta-registry queries.
  """

  alias Singularity.MetaRegistry.QuerySystem
  alias Singularity.MetaRegistry.NatsSubjects

  @doc """
  Handle app-facing naming suggestions request.
  
  ## Examples
  
      # App requests naming suggestions
      handle_naming_request(%{
        codebase_id: "my-laravel-app",
        context: "controller",
        description: "user management"
      })
      # Returns: ["UserController", "UserManagementController", ...]
  """
  def handle_naming_request(%{codebase_id: codebase_id, context: context, description: description}) do
    # Get learned patterns from meta-registry
    suggestions = QuerySystem.query_naming_suggestions(codebase_id, context)
    
    # If no learned patterns, use default suggestions
    suggestions = if Enum.empty?(suggestions) do
      generate_default_naming_suggestions(description, context)
    else
      suggestions
    end

    # Track the request for learning
    QuerySystem.track_usage(:naming, codebase_id, context, true)

    {:ok, %{
      suggestions: suggestions,
      source: "meta_registry",
      codebase_id: codebase_id,
      context: context
    }}
  end

  @doc """
  Handle app-facing architecture patterns request.
  
  ## Examples
  
      # App requests architecture patterns
      handle_architecture_request(%{
        codebase_id: "my-microservices-app",
        context: "service",
        description: "user management"
      })
      # Returns: ["user-service", "user-management-service", ...]
  """
  def handle_architecture_request(%{codebase_id: codebase_id, context: context, description: description}) do
    # Get learned patterns from meta-registry
    suggestions = QuerySystem.query_architecture_suggestions(codebase_id, context)
    
    # If no learned patterns, use default suggestions
    suggestions = if Enum.empty?(suggestions) do
      generate_default_architecture_suggestions(description, context)
    else
      suggestions
    end

    # Track the request for learning
    QuerySystem.track_usage(:architecture, codebase_id, context, true)

    {:ok, %{
      suggestions: suggestions,
      source: "meta_registry",
      codebase_id: codebase_id,
      context: context
    }}
  end

  @doc """
  Handle app-facing quality checks request.
  
  ## Examples
  
      # App requests quality suggestions
      handle_quality_request(%{
        codebase_id: "my-quality-app",
        context: "testing",
        description: "unit tests"
      })
      # Returns: ["test-driven", "type-safe", "documented", ...]
  """
  def handle_quality_request(%{codebase_id: codebase_id, context: context, description: description}) do
    # Get learned patterns from meta-registry
    suggestions = QuerySystem.query_quality_suggestions(codebase_id, context)
    
    # If no learned patterns, use default suggestions
    suggestions = if Enum.empty?(suggestions) do
      generate_default_quality_suggestions(description, context)
    else
      suggestions
    end

    # Track the request for learning
    QuerySystem.track_usage(:quality, codebase_id, context, true)

    {:ok, %{
      suggestions: suggestions,
      source: "meta_registry",
      codebase_id: codebase_id,
      context: context
    }}
  end

  @doc """
  Handle internal meta-registry learning requests.
  
  ## Examples
  
      # Learn naming patterns from PHP/Laravel app
      handle_meta_learning(:naming, %{
        codebase_id: "my-laravel-app",
        language: "php",
        framework: "laravel",
        patterns: ["UserController", "UserModel", "create_users_table"]
      })
  """
  def handle_meta_learning(:naming, attrs) do
    QuerySystem.learn_naming_patterns(attrs.codebase_id, attrs)
  end

  def handle_meta_learning(:architecture, attrs) do
    QuerySystem.learn_architecture_patterns(attrs.codebase_id, attrs)
  end

  def handle_meta_learning(:quality, attrs) do
    QuerySystem.learn_quality_patterns(attrs.codebase_id, attrs)
  end

  def handle_meta_learning(category, _attrs) do
    {:error, "Unknown learning category: #{category}"}
  end

  # Private functions for default suggestions

  defp generate_default_naming_suggestions(description, context) do
    base_name = extract_base_name(description)
    
    case context do
      "controller" -> ["#{base_name}Controller", "#{base_name}ManagementController"]
      "model" -> ["#{base_name}Model", "#{base_name}"]
      "service" -> ["#{base_name}Service", "#{base_name}Manager"]
      "repository" -> ["#{base_name}Repository", "#{base_name}Repo"]
      _ -> [base_name, "#{base_name}Handler"]
    end
  end

  defp generate_default_architecture_suggestions(description, context) do
    base_name = extract_base_name(description)
    
    case context do
      "service" -> ["#{base_name}-service", "#{base_name}-api"]
      "gateway" -> ["#{base_name}-gateway", "#{base_name}-proxy"]
      "worker" -> ["#{base_name}-worker", "#{base_name}-processor"]
      _ -> ["#{base_name}-component", "#{base_name}-module"]
    end
  end

  defp generate_default_quality_suggestions(description, context) do
    case context do
      "testing" -> ["test-driven", "unit-tests", "integration-tests"]
      "documentation" -> ["documented", "api-docs", "readme"]
      "type-safety" -> ["type-safe", "strict-types", "type-checking"]
      _ -> ["clean-code", "best-practices", "maintainable"]
    end
  end

  defp extract_base_name(description) do
    description
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/, "")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join("")
  end
end