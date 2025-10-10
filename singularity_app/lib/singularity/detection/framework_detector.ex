defmodule Singularity.Detection.FrameworkDetector do
  @moduledoc """
  Framework Detection via Rust Architecture Engine NIF
  
  Uses the unified Rust Architecture Engine for framework detection.
  Integrates with the consolidated Architecture Engine modules.
  """

  require Logger
  alias Singularity.ArchitectureEngine.FrameworkPatternStore

  @doc """
  Detect frameworks in code patterns using Rust Architecture Engine.
  
  ## Examples
  
      # Detect frameworks from file patterns
      detect_frameworks(["lib/*_web/", "test/*_web/"], context: "phoenix_app")
      # => {:ok, [%{name: "phoenix", version: "1.7.0", confidence: 0.95}]}
      
      # Detect from code content
      detect_frameworks(["use Phoenix.Router", "defmodule MyAppWeb"], context: "elixir_code")
      # => {:ok, [%{name: "phoenix", version: "1.7.0", confidence: 0.98}]}
  """
  @spec detect_frameworks(list(String.t()), keyword()) :: {:ok, list(map())} | {:error, term()}
  def detect_frameworks(patterns, opts \\ []) do
    context = Keyword.get(opts, :context, "")
    
    Logger.info("🔍 Detecting frameworks", patterns_count: length(patterns), context: context)
    
    # Prepare detection request
    detection_request = %{
      patterns: patterns,
      context: context,
      detection_methods: [:config_files, :code_patterns, :ast_analysis, :knowledge_base, :ai_analysis],
      confidence_threshold: 0.7
    }
    
    # Call Rust Architecture Engine via NIF
    case call_rust_architecture_engine(:detect_frameworks, detection_request) do
      {:ok, results} ->
        # Store learned patterns in PostgreSQL
        store_detected_patterns(results)
        
        # Update framework pattern store
        update_framework_patterns(results)
        
        Logger.info("✅ Detected #{length(results)} frameworks")
        {:ok, results}
      
      {:error, reason} ->
        Logger.error("❌ Framework detection failed", reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Detect technologies and languages using Rust Architecture Engine.
  """
  @spec detect_technologies(list(String.t()), keyword()) :: {:ok, list(map())} | {:error, term()}
  def detect_technologies(patterns, opts \\ []) do
    context = Keyword.get(opts, :context, "")
    
    detection_request = %{
      patterns: patterns,
      context: context,
      detection_methods: [:config_files, :code_patterns, :ast_analysis],
      confidence_threshold: 0.8
    }
    
    call_rust_architecture_engine(:detect_technologies, detection_request)
  end

  @doc """
  Get architectural suggestions using Rust Architecture Engine.
  """
  @spec get_architectural_suggestions(map(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def get_architectural_suggestions(codebase_info, opts \\ []) do
    suggestion_request = %{
      codebase_info: codebase_info,
      suggestion_types: [:naming, :patterns, :structure, :optimization],
      context: Keyword.get(opts, :context, "")
    }
    
    call_rust_architecture_engine(:get_architectural_suggestions, suggestion_request)
  end

  # Private Functions

  defp call_rust_architecture_engine(operation, request) do
    # Call the unified Rust Architecture Engine via NIF
    # This integrates with central PostgreSQL database and NATS messaging
    
    case operation do
      :detect_frameworks ->
        Singularity.ArchitectureEngine.detect_frameworks(request.patterns, 
          context: request.context,
          detection_methods: request.detection_methods,
          confidence_threshold: request.confidence_threshold
        )
      
      :detect_technologies ->
        Singularity.ArchitectureEngine.detect_technologies(request.patterns,
          context: request.context,
          detection_methods: request.detection_methods,
          confidence_threshold: request.confidence_threshold
        )
      
      :get_architectural_suggestions ->
        Singularity.ArchitectureEngine.get_architectural_suggestions(request.codebase_info,
          context: request.context,
          suggestion_types: request.suggestion_types
        )
      
      :collect_package ->
        Singularity.ArchitectureEngine.collect_package(request.package_name, request.version, request.ecosystem,
          include_patterns: request.include_patterns,
          include_stats: request.include_stats
        )
      
      :get_package_stats ->
        Singularity.ArchitectureEngine.get_package_stats(request.package_name)
      
      :get_framework_stats ->
        Singularity.ArchitectureEngine.get_framework_stats(request.framework_name)
      
      _ ->
        {:error, "Unknown operation: #{operation}"}
    end
  end

  defp mock_framework_detection(request) do
    # Mock framework detection based on patterns
    frameworks = 
      request.patterns
      |> Enum.flat_map(fn pattern ->
        detect_framework_from_pattern(pattern, request.context)
      end)
      |> Enum.uniq_by(& &1.name)
    
    {:ok, frameworks}
  end

  defp detect_framework_from_pattern(pattern, context) do
    cond do
      String.contains?(pattern, "phoenix") or String.contains?(context, "phoenix") ->
        [%{name: "phoenix", version: "1.7.0", confidence: 0.95, detected_by: "pattern_match"}]
      
      String.contains?(pattern, "ecto") or String.contains?(context, "ecto") ->
        [%{name: "ecto", version: "3.10.0", confidence: 0.90, detected_by: "pattern_match"}]
      
      String.contains?(pattern, "nats") or String.contains?(context, "nats") ->
        [%{name: "nats", version: "0.1.0", confidence: 0.88, detected_by: "pattern_match"}]
      
      String.contains?(pattern, "postgresql") or String.contains?(context, "postgresql") ->
        [%{name: "postgresql", version: "15.0", confidence: 0.92, detected_by: "pattern_match"}]
      
      true ->
        []
    end
  end

  defp mock_technology_detection(request) do
    technologies = 
      request.patterns
      |> Enum.flat_map(fn pattern ->
        detect_technology_from_pattern(pattern)
      end)
      |> Enum.uniq_by(& &1.name)
    
    {:ok, technologies}
  end

  defp detect_technology_from_pattern(pattern) do
    cond do
      String.contains?(pattern, ".ex") ->
        [%{name: "elixir", version: "1.18.4", confidence: 0.95, detected_by: "file_extension"}]
      
      String.contains?(pattern, ".rs") ->
        [%{name: "rust", version: "1.75.0", confidence: 0.95, detected_by: "file_extension"}]
      
      String.contains?(pattern, ".js") ->
        [%{name: "javascript", version: "20.0.0", confidence: 0.90, detected_by: "file_extension"}]
      
      String.contains?(pattern, ".ts") ->
        [%{name: "typescript", version: "5.0.0", confidence: 0.90, detected_by: "file_extension"}]
      
      true ->
        []
    end
  end

  defp mock_architectural_suggestions(request) do
    suggestions = [
      %{
        type: "naming",
        suggestion: "Use descriptive module names",
        confidence: 0.85,
        reasoning: "Module names should clearly indicate their purpose"
      },
      %{
        type: "pattern",
        suggestion: "Consider using GenServer for stateful processes",
        confidence: 0.80,
        reasoning: "GenServer provides better error handling and supervision"
      }
    ]
    
    {:ok, suggestions}
  end

  defp store_detected_patterns(results) do
    # Store detected patterns in the framework pattern store
    Enum.each(results, fn result ->
      case FrameworkPatternStore.learn_pattern(%{
        framework_name: result.name,
        version: result.version,
        confidence_weight: result.confidence,
        detected_by: result.detected_by,
        detection_context: "rust_architecture_engine"
      }) do
        {:ok, _id} ->
          Logger.debug("Stored framework pattern", framework: result.name)
        
        {:error, reason} ->
          Logger.warning("Failed to store framework pattern", 
            framework: result.name, reason: reason)
      end
    end)
  end

  defp update_framework_patterns(results) do
    # Update framework patterns with new detection results
    Enum.each(results, fn result ->
      # This would update confidence scores and learning patterns
      Logger.debug("Updated framework pattern", framework: result.name)
    end)
  end
end