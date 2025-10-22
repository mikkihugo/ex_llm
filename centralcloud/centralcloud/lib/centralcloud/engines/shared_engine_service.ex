defmodule Centralcloud.Engines.SharedEngineService do
  @moduledoc """
  Shared Engine Service - Unified engine access for Centralcloud, Singularity, and Genesis
  
  This service provides a unified interface to all Rust engines via NATS, allowing
  any system (Centralcloud, Singularity, Genesis) to use the same engines without
  duplication or NIF dependencies.
  
  ## Architecture
  
  ```
  Centralcloud/Genesis/Singularity
           ↓ NATS
    Shared Engine Service
           ↓
    Rust Engines (as services, not NIFs)
  ```
  
  ## Available Engines
  
  - **Architecture Engine**: Framework detection, pattern analysis, technology detection
  - **Code Engine**: Business domain analysis, code patterns, semantic analysis  
  - **Quality Engine**: Code quality metrics, linting, performance analysis
  - **Embedding Engine**: Semantic embeddings, similarity analysis
  - **Parser Engine**: Multi-language parsing, AST analysis
  - **Prompt Engine**: AI prompt generation and optimization
  
  ## Usage
  
  ```elixir
  # Any system can call engines via NATS
  {:ok, result} = SharedEngineService.call_architecture_engine("detect_frameworks", request)
  {:ok, result} = SharedEngineService.call_code_engine("analyze_business_domains", request)
  {:ok, result} = SharedEngineService.call_quality_engine("analyze_quality", request)
  ```
  """

  require Logger
  alias Centralcloud.NatsClient

  @doc """
  Call the Architecture Engine via NATS.
  
  Operations:
  - detect_frameworks
  - detect_technologies  
  - get_architectural_suggestions
  - analyze_patterns
  """
  def call_architecture_engine(operation, request, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    
    case NatsClient.request("engines.architecture.#{operation}", request, timeout: timeout) do
      {:ok, response} ->
        Logger.debug("Architecture engine call successful", operation: operation)
        {:ok, response}
      
      {:error, reason} ->
        Logger.error("Architecture engine call failed", operation: operation, reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Call the Code Engine via NATS.
  
  Operations:
  - analyze_codebase
  - detect_business_domains
  - analyze_patterns
  - generate_embeddings
  """
  def call_code_engine(operation, request, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    
    case NatsClient.request("engines.code.#{operation}", request, timeout: timeout) do
      {:ok, response} ->
        Logger.debug("Code engine call successful", operation: operation)
        {:ok, response}
      
      {:error, reason} ->
        Logger.error("Code engine call failed", operation: operation, reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Call the Quality Engine via NATS.
  
  Operations:
  - analyze_quality
  - run_linting
  - calculate_metrics
  - security_scan
  """
  def call_quality_engine(operation, request, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    
    case NatsClient.request("engines.quality.#{operation}", request, timeout: timeout) do
      {:ok, response} ->
        Logger.debug("Quality engine call successful", operation: operation)
        {:ok, response}
      
      {:error, reason} ->
        Logger.error("Quality engine call failed", operation: operation, reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Call the Embedding Engine via NATS.
  
  Operations:
  - generate_embeddings
  - calculate_similarity
  - analyze_semantics
  - cluster_embeddings
  """
  def call_embedding_engine(operation, request, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    
    case NatsClient.request("engines.embedding.#{operation}", request, timeout: timeout) do
      {:ok, response} ->
        Logger.debug("Embedding engine call successful", operation: operation)
        {:ok, response}
      
      {:error, reason} ->
        Logger.error("Embedding engine call failed", operation: operation, reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Call the Parser Engine via NATS.
  
  Operations:
  - parse_file
  - parse_codebase
  - extract_ast
  - analyze_syntax
  """
  def call_parser_engine(operation, request, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    
    case NatsClient.request("engines.parser.#{operation}", request, timeout: timeout) do
      {:ok, response} ->
        Logger.debug("Parser engine call successful", operation: operation)
        {:ok, response}
      
      {:error, reason} ->
        Logger.error("Parser engine call failed", operation: operation, reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Call the Prompt Engine via NATS.
  
  Operations:
  - generate_prompt
  - optimize_prompt
  - analyze_prompt_quality
  - suggest_improvements
  """
  def call_prompt_engine(operation, request, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    
    case NatsClient.request("engines.prompt.#{operation}", request, timeout: timeout) do
      {:ok, response} ->
        Logger.debug("Prompt engine call successful", operation: operation)
        {:ok, response}
      
      {:error, reason} ->
        Logger.error("Prompt engine call failed", operation: operation, reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Call multiple engines in parallel for comprehensive analysis.
  
  Returns a map with results from each engine.
  """
  def call_multiple_engines(engine_calls, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 60_000)
    
    # Execute all engine calls in parallel
    tasks = Enum.map(engine_calls, fn {engine, operation, request} ->
      Task.async(fn ->
        case engine do
          :architecture -> call_architecture_engine(operation, request, opts)
          :code -> call_code_engine(operation, request, opts)
          :quality -> call_quality_engine(operation, request, opts)
          :embedding -> call_embedding_engine(operation, request, opts)
          :parser -> call_parser_engine(operation, request, opts)
          :prompt -> call_prompt_engine(operation, request, opts)
        end
      end)
    end)
    
    # Wait for all tasks to complete
    results = Task.await_many(tasks, timeout)
    
    # Combine results
    combined_results = Enum.zip_with(engine_calls, results, fn {engine, operation, _}, result ->
      {engine, operation, result}
    end)
    
    {:ok, combined_results}
  end

  @doc """
  Get engine health status for all engines.
  """
  def get_engine_health do
    engines = [:architecture, :code, :quality, :embedding, :parser, :prompt]
    
    health_checks = Enum.map(engines, fn engine ->
      case NatsClient.request("engines.#{engine}.health", %{}, timeout: 5_000) do
        {:ok, response} -> {engine, :healthy, response}
        {:error, reason} -> {engine, :unhealthy, reason}
      end
    end)
    
    %{
      "engines" => health_checks,
      "overall_health" => if(Enum.all?(health_checks, fn {_, status, _} -> status == :healthy end), do: :healthy, else: :degraded),
      "checked_at" => DateTime.utc_now()
    }
  end
end
