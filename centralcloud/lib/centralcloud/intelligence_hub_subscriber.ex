defmodule Centralcloud.IntelligenceHubSubscriber do
  @moduledoc """
  NATS subscriber for receiving intelligence data from Singularity engines.
  
  Subscribes to all intelligence hub subjects and stores data in PostgreSQL:
  - Analysis results from all 8 engines
  - Artifacts and generated code
  - Package intelligence indexing
  - Knowledge cache synchronization
  - Vector embeddings
  
  ## Architecture
  
  ```
  Engine → NATS → This Subscriber → PostgreSQL (centralcloud)
  ```
  
  ## Subscriptions
  
  - `intelligence.hub.*.analysis` - All engine analysis results
  - `intelligence.hub.*.artifact` - All engine artifacts
  - `intelligence.hub.package.index` - Package indexing
  - `intelligence.hub.knowledge.cache` - Knowledge caching
  - `intelligence.hub.embeddings` - Vector embeddings
  """
  
  use GenServer
  require Logger
  
  alias Centralcloud.{Repo, NatsClient}
  alias Centralcloud.Schemas.{AnalysisResult, Package, PromptTemplate, CodeSnippet}
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    Logger.info("Starting Intelligence Hub Subscriber...")
    
    # Subscribe to all intelligence hub subjects
    subscriptions = [
      "intelligence.hub.*.analysis",
      "intelligence.hub.*.artifact",
      "intelligence.hub.package.index",
      "intelligence.hub.package.query",
      "intelligence.hub.knowledge.cache",
      "intelligence.hub.knowledge.request",
      "intelligence.hub.embeddings"
    ]
    
    Enum.each(subscriptions, fn subject ->
      case NatsClient.subscribe(subject, callback: {__MODULE__, :handle_message, []}) do
        {:ok, _sid} ->
          Logger.info("Subscribed to: #{subject}")
        {:error, reason} ->
          Logger.error("Failed to subscribe to #{subject}: #{inspect(reason)}")
      end
    end)
    
    {:ok, %{subscriptions: subscriptions}}
  end
  
  ## Message Handlers
  
  @doc """
  Handle incoming NATS messages from engines.
  """
  def handle_message(%{reply_to: reply_to} = msg) do
    Logger.debug("Received request on #{msg.subject}")

    response =
      case Jason.decode(msg.data) do
        {:ok, payload} -> handle_payload(msg.subject, payload)
        {:error, reason} ->
          Logger.error("Failed to decode request: #{inspect(reason)}")
          {:error, :bad_request}
      end

    NatsClient.publish(reply_to, Jason.encode!(response))
  end

  def handle_message(%{subject: subject, data: data}) do
    Logger.debug("Received message on #{subject}")
    
    case Jason.decode(data) do
      {:ok, payload} ->
        handle_payload(subject, payload)
      {:error, reason} ->
        Logger.error("Failed to decode message: #{inspect(reason)}")
    end
  end
  
  # Handle analysis results
  defp handle_payload("intelligence.hub." <> rest, %{"type" => "analysis"} = payload) do
    [engine | _] = String.split(rest, ".")
    
    Logger.info("Storing analysis from #{engine} engine")
    
    %AnalysisResult{}
    |> AnalysisResult.changeset(%{
      engine: engine,
      analysis_type: payload["data"]["type"],
      result_data: payload["data"],
      analyzed_at: parse_timestamp(payload["timestamp"])
    })
    |> Repo.insert()
    |> case do
      {:ok, _result} ->
        Logger.debug("Stored #{engine} analysis result")
        :ok
      {:error, changeset} ->
        Logger.error("Failed to store analysis: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end
  
  # Handle artifacts
  defp handle_payload("intelligence.hub." <> rest, %{"type" => "artifact"} = payload) do
    [engine | _] = String.split(rest, ".")
    
    Logger.info("Storing artifact from #{engine} engine")
    
    artifact_data = payload["data"]
    
    case artifact_data["type"] do
      "generated_code" ->
        store_code_snippet(engine, artifact_data)
      
      "prompt_template" ->
        store_prompt_template(engine, artifact_data)
      
      _ ->
        # Generic artifact storage as analysis result
        %AnalysisResult{}
        |> AnalysisResult.changeset(%{
          engine: engine,
          analysis_type: "artifact",
          result_data: artifact_data,
          analyzed_at: parse_timestamp(payload["timestamp"])
        })
        |> Repo.insert()
    end
  end
  
  # Handle package indexing
  defp handle_payload("intelligence.hub.package.index", %{"type" => "package_index"} = payload) do
    Logger.info("Indexing package: #{payload["package"]["name"]}")
    
    package_data = payload["package"]
    
    %Package{}
    |> Package.changeset(%{
      name: package_data["name"],
      version: package_data["version"],
      language: package_data["language"],
      description: package_data["description"],
      metadata: package_data["analysis"] || %{},
      indexed_at: parse_timestamp(payload["timestamp"])
    })
    |> Repo.insert(
      on_conflict: {:replace, [:version, :metadata, :indexed_at, :updated_at]},
      conflict_target: [:name, :language]
    )
    |> case do
      {:ok, _package} ->
        Logger.info("Indexed package: #{package_data["name"]}")
        :ok
      {:error, changeset} ->
        Logger.error("Failed to index package: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end
  
  # Handle package queries (request/reply)
  defp handle_payload("intelligence.hub.package.query", %{"type" => "package_query"} = payload) do
    Logger.debug("Package query: #{payload["package_name"]}")
    
    case Repo.get_by(Package, name: payload["package_name"], language: payload["language"]) do
      nil ->
        {:error, :not_found}
      package ->
        {:ok, Map.from_struct(package)}
    end
  end
  
  # Handle knowledge cache
  defp handle_payload("intelligence.hub.knowledge.cache", %{"type" => "knowledge_cache"} = payload) do
    Logger.info("Caching knowledge: #{payload["knowledge"]["id"]}")
    
    knowledge = payload["knowledge"]
    
    # Store as prompt template or code snippet based on type
    case knowledge["type"] do
      "pattern" ->
        store_pattern_knowledge(knowledge)
      
      "template" ->
        store_template_knowledge(knowledge)
      
      _ ->
        store_generic_knowledge(knowledge)
    end
  end
  
  # Handle knowledge requests (request/reply)
  defp handle_payload("intelligence.hub.knowledge.request", %{"type" => "knowledge_request"} = payload) do
    Logger.debug("Knowledge request: #{payload["knowledge_id"]}")
    
    # Query from various tables
    # This is a simplified version - could be expanded
    knowledge_id = payload["knowledge_id"]
    
    cond do
      template = Repo.get_by(PromptTemplate, template_id: knowledge_id) ->
        {:ok, Map.from_struct(template)}
      
      snippet = Repo.get_by(CodeSnippet, snippet_id: knowledge_id) ->
        {:ok, Map.from_struct(snippet)}
      
      true ->
        {:error, :not_found}
    end
  end
  
  # Handle embeddings
  defp handle_payload("intelligence.hub.embeddings", %{"type" => "embedding"} = payload) do
    Logger.debug("Storing embedding")
    
    embedding_data = payload["data"]
    
    # Store embedding as analysis result with vector
    %AnalysisResult{}
    |> AnalysisResult.changeset(%{
      engine: "embedding",
      analysis_type: "vector_embedding",
      result_data: %{
        text: embedding_data["text"],
        model: embedding_data["model"],
        dimensions: embedding_data["dimensions"]
      },
      analyzed_at: parse_timestamp(payload["timestamp"])
    })
    |> Repo.insert()
  end
  
  # Fallback
  defp handle_payload(subject, payload) do
    Logger.warn("Unhandled message on #{subject}: #{inspect(payload)}")
    :ok
  end
  
  ## Helper Functions
  
  defp parse_timestamp(iso8601_string) when is_binary(iso8601_string) do
    case DateTime.from_iso8601(iso8601_string) do
      {:ok, datetime, _} -> datetime
      _ -> DateTime.utc_now()
    end
  end
  
  defp parse_timestamp(_), do: DateTime.utc_now()
  
  defp store_code_snippet(engine, data) do
    %CodeSnippet{}
    |> CodeSnippet.changeset(%{
      snippet_id: data["id"] || generate_id(),
      language: data["language"],
      code: data["code"],
      description: data["context"]["description"],
      tags: data["tags"] || [],
      metadata: %{
        engine: engine,
        context: data["context"]
      }
    })
    |> Repo.insert()
  end
  
  defp store_prompt_template(engine, data) do
    %PromptTemplate{}
    |> PromptTemplate.changeset(%{
      template_id: data["id"] || generate_id(),
      name: data["name"],
      template: data["template"],
      variables: data["variables"] || [],
      description: data["description"],
      metadata: %{
        engine: engine,
        context: data["context"] || %{}
      }
    })
    |> Repo.insert()
  end
  
  defp store_pattern_knowledge(knowledge) do
    # Store patterns as code snippets
    %CodeSnippet{}
    |> CodeSnippet.changeset(%{
      snippet_id: knowledge["id"],
      language: knowledge["language"] || "pattern",
      code: knowledge["data"]["pattern"],
      description: knowledge["data"]["description"],
      tags: ["pattern" | (knowledge["tags"] || [])],
      metadata: knowledge["data"]
    })
    |> Repo.insert(
      on_conflict: {:replace, [:code, :description, :tags, :metadata, :updated_at]},
      conflict_target: :snippet_id
    )
  end
  
  defp store_template_knowledge(knowledge) do
    %PromptTemplate{}
    |> PromptTemplate.changeset(%{
      template_id: knowledge["id"],
      name: knowledge["data"]["name"],
      template: knowledge["data"]["template"],
      variables: knowledge["data"]["variables"] || [],
      description: knowledge["data"]["description"],
      metadata: knowledge
    })
    |> Repo.insert(
      on_conflict: {:replace, [:template, :variables, :description, :metadata, :updated_at]},
      conflict_target: :template_id
    )
  end
  
  defp store_generic_knowledge(knowledge) do
    # Store as analysis result
    %AnalysisResult{}
    |> AnalysisResult.changeset(%{
      engine: "knowledge",
      analysis_type: knowledge["type"],
      result_data: knowledge["data"],
      analyzed_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end
  
  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
