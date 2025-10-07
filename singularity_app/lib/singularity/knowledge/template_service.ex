defmodule Singularity.Knowledge.TemplateService do
  @moduledoc """
  NATS service for template requests.

  Exposes templates via NATS subjects for consumption by:
  - Rust prompt engine
  - External agents
  - Other microservices

  ## NATS Subjects

  Request templates:
  - `template.get.framework.phoenix` → Get Phoenix framework template
  - `template.get.language.rust` → Get Rust language template
  - `template.get.quality.elixir-production` → Get quality template

  Search templates:
  - `template.search.{query}` → Semantic search

  Notifications:
  - `template.updated.{type}.{id}` → Template was updated (broadcast)

  ## Example: Rust Client

  ```rust
  use async_nats;

  let nc = async_nats::connect("nats://localhost:4222").await?;

  // Request template
  let response = nc
      .request("template.get.framework.phoenix", "".into())
      .await?;

  let template: serde_json::Value = serde_json::from_slice(&response.payload)?;
  ```

  ## Example: Elixir Client

  ```elixir
  {:ok, response} = Gnat.request(gnat, "template.get.framework.phoenix", "")
  {:ok, template} = Jason.decode(response.body)
  ```
  """

  use GenServer
  require Logger

  alias Singularity.Knowledge.TemplateCache

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Use the default Gnat connection
    gnat_name = :nats_client

    # Subscribe to template requests
    {:ok, _sub} = Gnat.sub(gnat_name, self(), "template.get.>")
    {:ok, _sub} = Gnat.sub(gnat_name, self(), "template.search.>")

    Logger.info("Template NATS service started")
    Logger.info("  Listening on: template.get.*, template.search.*")

    {:ok, %{gnat: gnat_name, requests_handled: 0}}
  end

  @impl true
  def handle_info(
        {:msg, %{subject: "template.get." <> rest, body: _body, reply_to: reply_to}},
        state
      ) do
    # Parse subject: template.get.framework.phoenix
    case String.split(rest, ".", parts: 2) do
      [artifact_type, artifact_id] ->
        handle_get_request(state.gnat, artifact_type, artifact_id, reply_to)

      _ ->
        send_error(state.gnat, reply_to, "Invalid subject format")
    end

    {:noreply, %{state | requests_handled: state.requests_handled + 1}}
  end

  @impl true
  def handle_info({:msg, %{subject: "template.search." <> query, reply_to: reply_to}}, state) do
    handle_search_request(state.gnat, query, reply_to)
    {:noreply, %{state | requests_handled: state.requests_handled + 1}}
  end

  @impl true
  def handle_info({:msg, _msg}, state) do
    # Ignore other messages
    {:noreply, state}
  end

  # Private Functions

  defp handle_get_request(gnat, artifact_type, artifact_id, reply_to) when is_binary(reply_to) do
    start_time = System.monotonic_time(:microsecond)

    case TemplateCache.get(artifact_type, artifact_id) do
      {:ok, template} ->
        # Encode as JSON
        case Jason.encode(template) do
          {:ok, json} ->
            Gnat.pub(gnat, reply_to, json)
            emit_telemetry(:success, artifact_type, start_time)

          {:error, reason} ->
            error_msg = Jason.encode!(%{error: "encoding_failed", reason: inspect(reason)})
            Gnat.pub(gnat, reply_to, error_msg)
            emit_telemetry(:error, artifact_type, start_time)
        end

      {:error, :not_found} ->
        error_msg = Jason.encode!(%{error: "not_found", type: artifact_type, id: artifact_id})
        Gnat.pub(gnat, reply_to, error_msg)
        emit_telemetry(:not_found, artifact_type, start_time)

      {:error, reason} ->
        error_msg = Jason.encode!(%{error: "internal_error", reason: inspect(reason)})
        Gnat.pub(gnat, reply_to, error_msg)
        emit_telemetry(:error, artifact_type, start_time)
    end
  end

  defp handle_get_request(_gnat, _artifact_type, _artifact_id, nil) do
    # No reply_to - can't respond
    Logger.warning("Received template.get request without reply_to")
  end

  defp handle_search_request(gnat, query, reply_to) do
    start_time = System.monotonic_time(:microsecond)

    # Implement semantic search using pgvector
    case Singularity.Knowledge.ArtifactStore.search(query, top_k: 10) do
      {:ok, results} ->
        formatted_results = Enum.map(results, fn artifact ->
          %{
            id: artifact.id,
            artifact_type: artifact.artifact_type,
            name: artifact.name,
            description: artifact.description,
            similarity: artifact.similarity,
            content_preview: String.slice(artifact.content_raw || "", 0, 200) <> "..."
          }
        end)

        response =
          Jason.encode!(%{
            query: query,
            results: formatted_results,
            count: length(formatted_results)
          })

        Gnat.pub(gnat, reply_to, response)

      {:error, reason} ->
        Logger.error("Semantic search failed: #{inspect(reason)}")
        send_error(gnat, reply_to, "Search failed: #{inspect(reason)}")
    end

    emit_telemetry(:search, "search", start_time)
  end

  defp handle_search_request(_gnat, _query, nil) do
    Logger.warning("Received template.search request without reply_to")
  end

  defp send_error(gnat, reply_to, message) when is_binary(reply_to) do
    error_msg = Jason.encode!(%{error: message})
    Gnat.pub(gnat, reply_to, error_msg)
  end

  defp send_error(_gnat, nil, _message), do: :ok

  defp emit_telemetry(status, artifact_type, start_time) do
    duration = System.monotonic_time(:microsecond) - start_time

    :telemetry.execute(
      [:singularity, :template_service, :request],
      %{duration_us: duration},
      %{status: status, artifact_type: artifact_type}
    )
  end
end
