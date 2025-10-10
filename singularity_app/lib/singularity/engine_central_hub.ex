defmodule Singularity.EngineCentralHub do
  @moduledoc """
  Central hub for engine-to-central_cloud communication via NATS.
  
  All 8 engines send their analysis results, intelligence, and data
  to central_cloud services via NATS for:
  - Package index intelligence
  - Intelligence hub aggregation
  - Knowledge cache synchronization
  - Central intelligence storage
  
  ## Architecture
  
  ```
  Engine (local) → NATS → central_cloud (PostgreSQL)
  ```
  
  ## Supported Engines
  
  1. ArchitectureEngine - Architecture patterns and naming
  2. CodeEngine - Code analysis results
  3. EmbeddingEngine - Vector embeddings
  4. GeneratorEngine - Generated code artifacts
  5. ParserEngine - AST and parsing results
  6. PromptEngine - Prompt templates and optimizations
  7. QualityEngine - Quality metrics and issues
  8. KnowledgeIntelligence - Knowledge artifacts
  
  ## NATS Subjects
  
  - `intelligence.hub.{engine}.analysis` - Analysis results
  - `intelligence.hub.{engine}.artifact` - Artifacts/outputs
  - `intelligence.hub.package.index` - Package indexing
  - `intelligence.hub.knowledge.cache` - Knowledge caching
  - `intelligence.hub.embeddings` - Vector embeddings
  """
  
  require Logger
  alias Singularity.NatsClient
  
  @type engine_name :: :architecture | :code | :embedding | :generator | :parser | :prompt | :quality | :knowledge
  @type analysis_result :: map()
  @type artifact :: map()
  
  ## Public API
  
  @doc """
  Send analysis results from an engine to central intelligence hub.
  
  ## Examples
  
      iex> EngineCentralHub.send_analysis(:architecture, %{
        type: "naming_analysis",
        project: "my-app",
        results: [...]
      })
      :ok
  """
  @spec send_analysis(engine_name(), analysis_result()) :: :ok | {:error, term()}
  def send_analysis(engine, analysis_data) when is_atom(engine) and is_map(analysis_data) do
    subject = "intelligence.hub.#{engine}.analysis"
    
    payload = Jason.encode!(%{
      engine: engine,
      type: "analysis",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      data: analysis_data
    })
    
    case NatsClient.publish(subject, payload) do
      :ok -> 
        Logger.debug("Sent #{engine} analysis to central hub")
        :ok
      {:error, reason} = error ->
        Logger.error("Failed to send #{engine} analysis: #{inspect(reason)}")
        error
    end
  end
  
  @doc """
  Send artifacts (code, patterns, templates) to central hub.
  
  ## Examples
  
      iex> EngineCentralHub.send_artifact(:generator, %{
        type: "generated_code",
        language: "elixir",
        code: "defmodule ...",
        context: %{...}
      })
      :ok
  """
  @spec send_artifact(engine_name(), artifact()) :: :ok | {:error, term()}
  def send_artifact(engine, artifact_data) when is_atom(engine) and is_map(artifact_data) do
    subject = "intelligence.hub.#{engine}.artifact"
    
    payload = Jason.encode!(%{
      engine: engine,
      type: "artifact",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      data: artifact_data
    })
    
    case NatsClient.publish(subject, payload) do
      :ok ->
        Logger.debug("Sent #{engine} artifact to central hub")
        :ok
      {:error, reason} = error ->
        Logger.error("Failed to send #{engine} artifact: #{inspect(reason)}")
        error
    end
  end
  
  @doc """
  Index a package in the central package intelligence system.
  
  ## Examples
  
      iex> EngineCentralHub.index_package(%{
        name: "phoenix",
        version: "1.7.0",
        language: "elixir",
        analysis: %{...}
      })
      :ok
  """
  @spec index_package(map()) :: :ok | {:error, term()}
  def index_package(package_data) when is_map(package_data) do
    subject = "intelligence.hub.package.index"
    
    payload = Jason.encode!(%{
      type: "package_index",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      package: package_data
    })
    
    case NatsClient.publish(subject, payload) do
      :ok ->
        Logger.info("Indexed package: #{package_data[:name]}")
        :ok
      {:error, reason} = error ->
        Logger.error("Failed to index package: #{inspect(reason)}")
        error
    end
  end
  
  @doc """
  Cache knowledge artifact in central knowledge cache.
  
  ## Examples
  
      iex> EngineCentralHub.cache_knowledge(%{
        id: "react-patterns-2024",
        type: "pattern",
        data: %{...},
        embedding: [0.1, 0.2, ...]
      })
      :ok
  """
  @spec cache_knowledge(map()) :: :ok | {:error, term()}
  def cache_knowledge(knowledge_data) when is_map(knowledge_data) do
    subject = "intelligence.hub.knowledge.cache"
    
    payload = Jason.encode!(%{
      type: "knowledge_cache",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      knowledge: knowledge_data
    })
    
    case NatsClient.publish(subject, payload) do
      :ok ->
        Logger.debug("Cached knowledge: #{knowledge_data[:id]}")
        :ok
      {:error, reason} = error ->
        Logger.error("Failed to cache knowledge: #{inspect(reason)}")
        error
    end
  end
  
  @doc """
  Send vector embeddings to central hub for similarity search.
  
  ## Examples
  
      iex> EngineCentralHub.send_embeddings(%{
        text: "async worker pattern",
        embedding: [0.1, 0.2, ...],
        model: "qodo_embed",
        dimensions: 1536
      })
      :ok
  """
  @spec send_embeddings(map()) :: :ok | {:error, term()}
  def send_embeddings(embedding_data) when is_map(embedding_data) do
    subject = "intelligence.hub.embeddings"
    
    payload = Jason.encode!(%{
      type: "embedding",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      data: embedding_data
    })
    
    case NatsClient.publish(subject, payload) do
      :ok ->
        Logger.debug("Sent embeddings to central hub")
        :ok
      {:error, reason} = error ->
        Logger.error("Failed to send embeddings: #{inspect(reason)}")
        error
    end
  end
  
  @doc """
  Request knowledge from central cache.
  
  ## Examples
  
      iex> EngineCentralHub.request_knowledge("react-patterns-2024")
      {:ok, %{id: "react-patterns-2024", data: %{...}}}
  """
  @spec request_knowledge(String.t()) :: {:ok, map()} | {:error, term()}
  def request_knowledge(knowledge_id) when is_binary(knowledge_id) do
    subject = "intelligence.hub.knowledge.request"
    
    payload = Jason.encode!(%{
      type: "knowledge_request",
      knowledge_id: knowledge_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
    
    case NatsClient.request(subject, payload, timeout: 5000) do
      {:ok, response} ->
        case Jason.decode(response.data) do
          {:ok, data} -> {:ok, data}
          {:error, _} = error -> error
        end
      {:error, reason} = error ->
        Logger.error("Failed to request knowledge: #{inspect(reason)}")
        error
    end
  end
  
  @doc """
  Query package intelligence index.
  
  ## Examples
  
      iex> EngineCentralHub.query_package("phoenix", "elixir")
      {:ok, %{name: "phoenix", version: "1.7.0", ...}}
  """
  @spec query_package(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def query_package(package_name, language) when is_binary(package_name) and is_binary(language) do
    subject = "intelligence.hub.package.query"
    
    payload = Jason.encode!(%{
      type: "package_query",
      package_name: package_name,
      language: language,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
    
    case NatsClient.request(subject, payload, timeout: 5000) do
      {:ok, response} ->
        case Jason.decode(response.data) do
          {:ok, data} -> {:ok, data}
          {:error, _} = error -> error
        end
      {:error, reason} = error ->
        Logger.error("Failed to query package: #{inspect(reason)}")
        error
    end
  end
end
