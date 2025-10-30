defmodule Singularity.Knowledge.Requests do
  @moduledoc """
  Orchestrates the lifecycle of generic knowledge requests.

  - Enqueue new tickets when Singularity needs CentralCloud/QuantumFlow assistance.
  - Track status updates and publish NOTIFY events for real-time reactions.
  - Provide a polling API so supervisors can reconcile missed notifications.
  """

  require Logger
  import Ecto.Query

  alias Singularity.Repo
  alias Singularity.Schemas.KnowledgeRequest

  @notify_channel "knowledge_requests"
  @telemetry_prefix [:singularity, :knowledge_request]

  @type request_attrs :: %{
          required(:request_type) => KnowledgeRequest.request_type(),
          required(:external_key) => String.t(),
          required(:payload) => map(),
          required(:source) => String.t(),
          optional(:source_reference) => String.t(),
          optional(:retry_at) => DateTime.t(),
          optional(:metadata) => map()
        }

  @doc """
  Enqueue (or refresh) a knowledge request ticket.

  When a ticket with the same `external_key` already exists it is reset to `:pending`
  and its payload/metadata are updated.
  """
  @spec enqueue(request_attrs()) :: {:ok, KnowledgeRequest.t()} | {:error, Ecto.Changeset.t()}
  def enqueue(attrs) when is_map(attrs) do
    now = DateTime.utc_now()

    base_attrs =
      attrs
      |> Map.put_new(:retry_at, now)
      |> Map.put(:status, :pending)
      |> Map.put(:last_error, nil)
      |> Map.put_new(:metadata, %{})
      |> Map.put(:resolution_payload, nil)

    %KnowledgeRequest{}
    |> KnowledgeRequest.create_changeset(base_attrs)
    |> Repo.insert(
      conflict_target: :external_key,
      on_conflict: {:replace_all_except, [:id, :inserted_at]}
    )
    |> case do
      {:ok, request} ->
        Logger.info("Enqueued knowledge request #{request.external_key}",
          request_type: request.request_type,
          source: request.source
        )

        telemetry(:enqueued, %{count: 1}, request)
        notify_change(request)
        {:ok, request}

      {:error, changeset} ->
        Logger.error("Failed to enqueue knowledge request", errors: changeset.errors)
        {:error, changeset}
    end
  end

  @doc """
  Mark a request as `:in_progress`.
  """
  def mark_in_progress(request_or_id, opts \\ []) do
    update_status(request_or_id, :in_progress, opts)
  end

  @doc """
  Mark a request as `:resolved` and optionally store resolution metadata.
  """
  def mark_resolved(request_or_id, resolution_payload \\ %{}, opts \\ []) do
    attrs =
      opts
      |> Map.new()
      |> Map.put(:resolution_payload, resolution_payload)
      |> Map.put(:retry_at, nil)

    update_status(request_or_id, :resolved, attrs)
  end

  @doc """
  Mark a request as `:failed` and set next retry/backoff if provided.
  """
  def mark_failed(request_or_id, opts \\ []) do
    attrs =
      opts
      |> Map.new()
      |> Map.put_new(:retry_at, DateTime.add(DateTime.utc_now(), 60, :second))

    update_status(request_or_id, :failed, attrs)
  end

  @doc """
  Return pending requests that are due for processing (retry_at <= now).
  """
  @spec due_for_processing(non_neg_integer()) :: [KnowledgeRequest.t()]
  def due_for_processing(limit \\ 50) do
    now = DateTime.utc_now()

    KnowledgeRequest
    |> where_status_in([:pending, :failed])
    |> where([kr], is_nil(kr.retry_at) or kr.retry_at <= ^now)
    |> order_by([kr], asc: kr.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Return recently resolved requests (updated_at >= `since`).
  """
  @spec recently_resolved(DateTime.t()) :: [KnowledgeRequest.t()]
  def recently_resolved(since) do
    KnowledgeRequest
    |> where([kr], kr.status == :resolved and kr.updated_at >= ^since)
    |> Repo.all()
  end

  @doc """
  Convert a request struct into a NOTIFY event map.
  """
  @spec build_event(KnowledgeRequest.t()) :: map()
  def build_event(%KnowledgeRequest{} = request) do
    %{
      "id" => request.id,
      "status" => Atom.to_string(request.status),
      "request_type" => Atom.to_string(request.request_type),
      "external_key" => request.external_key,
      "source" => request.source,
      "source_reference" => request.source_reference,
      "payload" => request.payload,
      "resolution_payload" => request.resolution_payload,
      "updated_at" => request.updated_at
    }
  end

  @doc """
  Resolve pattern request that matches a given extension.
  """
  @spec resolve_pattern(atom() | String.t(), String.t(), map()) :: :ok
  def resolve_pattern(pattern_type, extension, resolution_payload \\ %{})

  def resolve_pattern(_pattern_type, nil, _payload), do: :ok

  def resolve_pattern(pattern_type, extension, resolution_payload) do
    pattern_type
    |> normalize_pattern_type()
    |> case do
      {:ok, type_atom} ->
        external_key = build_pattern_external_key(type_atom, extension)

        case Repo.get_by(KnowledgeRequest, external_key: external_key) do
          nil ->
            Logger.debug("No knowledge request found for external key #{external_key}")
            :ok

          request ->
            mark_resolved(request, resolution_payload)
            :ok
        end

      :error ->
        :ok
    end
  end

  @doc """
  Resolve pattern requests matching a given ecosystem.
  """
  @spec resolve_pattern_by_ecosystem(atom() | String.t(), String.t(), map()) :: :ok
  def resolve_pattern_by_ecosystem(pattern_type, ecosystem, resolution_payload \\ %{})

  def resolve_pattern_by_ecosystem(_pattern_type, nil, _payload), do: :ok

  def resolve_pattern_by_ecosystem(pattern_type, ecosystem, resolution_payload) do
    with {:ok, type_atom} <- normalize_pattern_type(pattern_type) do
      pattern_type_string = Atom.to_string(type_atom)

      KnowledgeRequest
      |> where([kr], kr.request_type == :pattern)
      |> where([kr], kr.status in [:pending, :in_progress])
      |> where([kr], fragment("?->>? = ?", kr.payload, "pattern_type", ^pattern_type_string))
      |> where([kr], fragment("COALESCE(?->>'ecosystem', '') = ?", kr.payload, ^ecosystem))
      |> Repo.all()
      |> Enum.each(fn request ->
        mark_resolved(request, Map.put(resolution_payload, "ecosystem", ecosystem))
      end)
    end

    :ok
  end

  @doc """
  Resolve requests by source reference (e.g., repo path).
  """
  @spec resolve_by_source(atom() | String.t(), String.t(), map()) :: :ok
  def resolve_by_source(request_type, source_reference, resolution_payload \\ %{})

  def resolve_by_source(_request_type, nil, _payload), do: :ok

  def resolve_by_source(request_type, source_reference, resolution_payload) do
    with {:ok, type_atom} <- normalize_request_type(request_type) do
      KnowledgeRequest
      |> where([kr], kr.request_type == ^type_atom)
      |> where([kr], kr.status in [:pending, :in_progress])
      |> where([kr], kr.source_reference == ^source_reference)
      |> Repo.all()
      |> Enum.each(fn request ->
        mark_resolved(request, Map.put(resolution_payload, "source_reference", source_reference))
      end)
    end

    :ok
  end

  @doc """
  Handle an incoming NOTIFY payload.
  """
  @spec handle_notification(String.t()) :: :ok
  def handle_notification(payload) when is_binary(payload) do
    with {:ok, decoded} <- Jason.decode(payload) do
      dispatch_event(decoded)
    else
      {:error, reason} ->
        Logger.error("Failed to decode knowledge request notification", reason: inspect(reason))
        :ok
    end
  end

  @doc """
  Dispatch an event map to the appropriate handler.
  """
  @spec dispatch_event(map()) :: :ok
  def dispatch_event(%{"status" => status} = event) do
    :telemetry.execute(
      [:singularity, :knowledge_request, :status_changed],
      %{status: status},
      event
    )

    case status do
      "resolved" ->
        maybe_schedule_retry(event)

      "failed" ->
        Logger.warning("Knowledge request failed",
          external_key: event["external_key"],
          source: event["source"],
          request_type: event["request_type"]
        )

      _ ->
        :ok
    end
  end

  def dispatch_event(_event), do: :ok

  defp maybe_schedule_retry(
         %{
           "request_type" => "pattern",
           "payload" => payload,
           "source_reference" => source_ref
         } = event
       ) do
    repo_path = Map.get(payload, "repo_path") || source_ref

    if repo_path do
      Logger.info("Scheduling follow-up detection after resolved pattern request",
        repo_path: repo_path,
        external_key: event["external_key"]
      )

      metadata = %{
        request_key: event["external_key"],
        payload: payload,
        source_reference: source_ref,
        request_type: "pattern"
      }

      case Singularity.Workflows.schedule_pattern_rescan(repo_path, metadata) do
        {:ok, summary} ->
          telemetry(
            :rescan_scheduled,
            %{count: 1},
            Map.merge(metadata, %{repo_path: repo_path, workflow_id: summary.workflow_id})
          )

        {:error, reason} ->
          Logger.error("Failed to schedule pattern rescan workflow",
            repo_path: repo_path,
            external_key: event["external_key"],
            reason: inspect(reason)
          )

          telemetry(
            :rescan_scheduled_error,
            %{count: 1},
            Map.merge(metadata, %{repo_path: repo_path, error: inspect(reason)})
          )
      end
    end

    :ok
  end

  defp maybe_schedule_retry(%{"request_type" => "anti_pattern"} = event) do
    Logger.info("Anti-pattern request logged for review",
      external_key: event["external_key"],
      source: event["source"]
    )

    telemetry(:anti_pattern_flagged, %{count: 1}, %{
      external_key: event["external_key"],
      source: event["source"],
      payload: event["payload"]
    })

    :ok
  end

  defp maybe_schedule_retry(_event), do: :ok

  defp update_status(request_or_id, status, attrs) when is_atom(status) do
    request_or_id
    |> fetch_request!()
    |> KnowledgeRequest.status_changeset(Map.put(attrs, :status, status))
    |> Repo.update()
    |> case do
      {:ok, request} ->
        Logger.info("Knowledge request status updated",
          id: request.id,
          status: request.status
        )

        telemetry(:status_changed, %{status: request.status}, request)
        notify_change(request)
        {:ok, request}

      {:error, changeset} ->
        Logger.error("Failed to update knowledge request status", errors: changeset.errors)
        {:error, changeset}
    end
  end

  defp fetch_request!(%KnowledgeRequest{} = request), do: request
  defp fetch_request!(id) when is_binary(id), do: Repo.get!(KnowledgeRequest, id)

  defp notify_change(request) do
    payload =
      request
      |> build_event()
      |> Jason.encode!()

    case Singularity.Infrastructure.PgFlow.Queue.notify_only(@notify_channel, payload, Repo) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to publish NOTIFY for knowledge request",
          request_id: request.id,
          reason: inspect(reason)
        )
    end
  end

  defp where_status_in(queryable, statuses) do
    from kr in queryable, where: kr.status in ^statuses
  end

  defp build_pattern_external_key(pattern_type, extension) do
    "pattern:#{Atom.to_string(pattern_type)}:#{extension}"
  end

  defp normalize_pattern_type(pattern_type) do
    cond do
      is_atom(pattern_type) and pattern_type in [:framework, :technology] ->
        {:ok, pattern_type}

      is_binary(pattern_type) ->
        case String.downcase(pattern_type) do
          "framework" -> {:ok, :framework}
          "technology" -> {:ok, :technology}
          _ -> :error
        end

      true ->
        :error
    end
  end

  defp normalize_request_type(request_type) do
    cond do
      is_atom(request_type) and
          request_type in [:pattern, :signature, :dataset, :model, :workflow, :anti_pattern] ->
        {:ok, request_type}

      is_binary(request_type) ->
        case String.downcase(request_type) do
          "pattern" -> {:ok, :pattern}
          "signature" -> {:ok, :signature}
          "dataset" -> {:ok, :dataset}
          "model" -> {:ok, :model}
          "workflow" -> {:ok, :workflow}
          "anti_pattern" -> {:ok, :anti_pattern}
          _ -> :error
        end

      true ->
        :error
    end
  end

  defp telemetry(event, measurements, %KnowledgeRequest{} = request) do
    metadata = %{
      request_type: request.request_type,
      status: request.status,
      external_key: request.external_key,
      source: request.source
    }

    :telemetry.execute(@telemetry_prefix ++ [event], measurements, metadata)
  end

  defp telemetry(event, measurements, metadata) do
    :telemetry.execute(@telemetry_prefix ++ [event], measurements, metadata)
  end
end
