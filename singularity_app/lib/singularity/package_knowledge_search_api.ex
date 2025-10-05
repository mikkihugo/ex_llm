defmodule Singularity.PackageKnowledgeSearchAPI do
  @moduledoc """
  NATS API for Package Knowledge and Codebase Search

  Handles all NATS subjects related to:
  - Tool search (packages, examples, patterns)
  - Integrated search (Tool Knowledge + RAG)
  - Package collection operations
  """

  use GenServer
  require Logger
  alias Singularity.{PackageRegistryKnowledge, PackageAndCodebaseSearch, PackageRegistryCollector}

  @nats_subjects %{
    # Tool Knowledge
    tool_search: "tools.search",
    example_search: "tools.examples.search",
    pattern_search: "tools.patterns.search",
    recommend_package: "tools.recommend",
    find_equivalents: "tools.equivalents",

    # Integrated Search
    hybrid_search: "search.hybrid",
    implementation_search: "search.implementation",

    # Collection
    collect_package: "tools.collect.package",
    collect_popular: "tools.collect.popular",
    collect_manifest: "tools.collect.manifest",

    # Events
    package_collected: "events.tools.package_collected",
    collection_failed: "events.tools.collection_failed"
  }

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    # Connect to NATS
    nats_url = System.get_env("NATS_URL", "nats://localhost:4222")
    {:ok, conn} = Gnat.start_link(%{url: nats_url})

    # Subscribe to all subjects
    Enum.each(@nats_subjects, fn {_key, subject} ->
      {:ok, _sub} = Gnat.sub(conn, self(), subject)
      Logger.info("Subscribed to NATS subject: #{subject}")
    end)

    {:ok, %{conn: conn}}
  end

  @impl true
  def handle_info({:msg, %{topic: topic, body: body, reply_to: reply_to}}, state) do
    # Parse request
    case Jason.decode(body) do
      {:ok, request} ->
        # Route to appropriate handler
        response = handle_request(topic, request)

        # Send response
        if reply_to do
          response_json = Jason.encode!(response)
          Gnat.pub(state.conn, reply_to, response_json)
        end

      {:error, reason} ->
        Logger.error("Failed to decode NATS message: #{inspect(reason)}")

        if reply_to do
          error_response = Jason.encode!(%{error: "Invalid JSON: #{inspect(reason)}"})
          Gnat.pub(state.conn, reply_to, error_response)
        end
    end

    {:noreply, state}
  end

  ## Request Handlers

  defp handle_request("tools.search", request) do
    query = Map.get(request, "query")
    ecosystem = Map.get(request, "ecosystem")
    limit = Map.get(request, "limit", 10)
    filters = Map.get(request, "filters", %{})

    opts = [
      ecosystem: ecosystem && String.to_existing_atom(ecosystem),
      limit: limit,
      min_stars: Map.get(filters, "min_stars", 0),
      min_downloads: Map.get(filters, "min_downloads", 0),
      recency_months: Map.get(filters, "recency_months")
    ]
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    results = PackageRegistryKnowledge.search(query, opts)

    %{results: results}
  rescue
    error ->
      %{error: "Search failed: #{inspect(error)}"}
  end

  defp handle_request("tools.examples.search", request) do
    query = Map.get(request, "query")
    ecosystem = Map.get(request, "ecosystem")
    language = Map.get(request, "language")
    limit = Map.get(request, "limit", 5)

    opts = [
      ecosystem: ecosystem && String.to_existing_atom(ecosystem),
      language: language,
      limit: limit
    ]
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    examples = PackageRegistryKnowledge.search_examples(query, opts)

    %{examples: examples}
  rescue
    error ->
      %{error: "Example search failed: #{inspect(error)}"}
  end

  defp handle_request("tools.patterns.search", request) do
    query = Map.get(request, "query")
    ecosystem = Map.get(request, "ecosystem")
    pattern_type = Map.get(request, "pattern_type")
    limit = Map.get(request, "limit", 5)

    opts = [
      ecosystem: ecosystem && String.to_existing_atom(ecosystem),
      pattern_type: pattern_type,
      limit: limit
    ]
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    patterns = PackageRegistryKnowledge.search_patterns(query, opts)

    %{patterns: patterns}
  rescue
    error ->
      %{error: "Pattern search failed: #{inspect(error)}"}
  end

  defp handle_request("tools.recommend", request) do
    task_description = Map.get(request, "task_description")
    ecosystem = Map.get(request, "ecosystem")
    codebase_id = Map.get(request, "codebase_id")

    opts = [
      ecosystem: ecosystem && String.to_existing_atom(ecosystem),
      codebase_id: codebase_id
    ]
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    recommendation = PackageAndCodebaseSearch.recommend_package(task_description, opts)
    recommendation
  rescue
    error ->
      %{error: "Recommendation failed: #{inspect(error)}"}
  end

  defp handle_request("tools.equivalents", request) do
    package_name = Map.get(request, "package_name")
    from_ecosystem = Map.get(request, "from_ecosystem")
    to_ecosystem = Map.get(request, "to_ecosystem")

    opts = [
      from: from_ecosystem && String.to_existing_atom(from_ecosystem),
      to: to_ecosystem && String.to_existing_atom(to_ecosystem)
    ]
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    equivalents = PackageRegistryKnowledge.find_equivalents(package_name, opts)

    %{equivalents: equivalents}
  rescue
    error ->
      %{error: "Equivalents search failed: #{inspect(error)}"}
  end

  defp handle_request("search.hybrid", request) do
    query = Map.get(request, "query")
    codebase_id = Map.get(request, "codebase_id")
    ecosystem = Map.get(request, "ecosystem")
    limit = Map.get(request, "limit", 5)

    opts = [
      codebase_id: codebase_id,
      ecosystem: ecosystem && String.to_existing_atom(ecosystem),
      limit: limit
    ]
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    results = PackageAndCodebaseSearch.hybrid_search(query, opts)
    results
  rescue
    error ->
      %{error: "Hybrid search failed: #{inspect(error)}"}
  end

  defp handle_request("search.implementation", request) do
    task_description = Map.get(request, "task_description")
    codebase_id = Map.get(request, "codebase_id")
    ecosystem = Map.get(request, "ecosystem")
    limit = Map.get(request, "limit", 5)

    opts = [
      codebase_id: codebase_id,
      ecosystem: ecosystem && String.to_existing_atom(ecosystem),
      limit: limit
    ]
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    results = PackageAndCodebaseSearch.search_implementation(task_description, opts)
    results
  rescue
    error ->
      %{error: "Implementation search failed: #{inspect(error)}"}
  end

  defp handle_request("tools.collect.package", request) do
    package_name = Map.get(request, "package_name")
    version = Map.get(request, "version")
    ecosystem = Map.get(request, "ecosystem")

    opts = [
      ecosystem: String.to_existing_atom(ecosystem)
    ]

    case PackageRegistryCollector.collect_package(package_name, version, opts) do
      {:ok, tool} ->
        # Publish success event
        publish_event("events.tools.package_collected", %{
          package_name: package_name,
          version: version,
          ecosystem: ecosystem,
          tool_id: tool.id,
          collected_at: DateTime.utc_now() |> DateTime.to_iso8601()
        })

        %{
          status: "success",
          tool_id: tool.id,
          package_name: package_name,
          version: version
        }

      {:error, reason} ->
        # Publish failure event
        publish_event("events.tools.collection_failed", %{
          package_name: package_name,
          version: version,
          ecosystem: ecosystem,
          error: inspect(reason)
        })

        %{
          status: "error",
          error: inspect(reason)
        }
    end
  rescue
    error ->
      %{error: "Collection failed: #{inspect(error)}"}
  end

  defp handle_request("tools.collect.popular", request) do
    ecosystem = Map.get(request, "ecosystem") |> String.to_existing_atom()
    limit = Map.get(request, "limit", 100)

    # Run collection in background task
    Task.start(fn ->
      PackageRegistryCollector.collect_popular(ecosystem, limit: limit)
    end)

    %{
      status: "started",
      message: "Collecting top #{limit} packages from #{ecosystem}",
      ecosystem: ecosystem,
      limit: limit
    }
  rescue
    error ->
      %{error: "Collection failed: #{inspect(error)}"}
  end

  defp handle_request("tools.collect.manifest", request) do
    manifest_path = Map.get(request, "manifest_path")

    # Run collection in background task
    Task.start(fn ->
      PackageRegistryCollector.collect_from_manifest(manifest_path)
    end)

    %{
      status: "started",
      message: "Collecting dependencies from #{manifest_path}",
      manifest_path: manifest_path
    }
  rescue
    error ->
      %{error: "Collection failed: #{inspect(error)}"}
  end

  defp handle_request(topic, _request) do
    Logger.warning("Unknown NATS topic: #{topic}")
    %{error: "Unknown topic: #{topic}"}
  end

  ## Helper Functions

  defp publish_event(subject, payload) do
    case Gnat.pub(Gnat, subject, Jason.encode!(payload)) do
      :ok ->
        Logger.debug("Published event to #{subject}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to publish event to #{subject}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
