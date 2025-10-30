defmodule Singularity.Storage.FailurePatternStore do
  @moduledoc """
  Persistence and query helpers for the failure pattern knowledge base.

  This store backs Phase 3/4/5 of the self-evolving pipeline by recording
  execution failures together with enriched metadata and by exposing query
  helpers that surface recurring issues, common root causes, and successful
  remediation strategies.
  """

  require Logger

  import Ecto.Query, warn: false

  alias Singularity.Repo
  alias Singularity.Schemas.FailurePattern

  @type filteropts ::
          %{
            optional(:story_type) => String.t(),
            optional(:failure_mode) => String.t(),
            optional(:story_signature) => String.t(),
            optional(:since) => DateTime.t(),
            optional(:min_frequency) => pos_integer(),
            optional(:validation_state) => String.t(),
            optional(:limit) => pos_integer()
          }
          | Keyword.t()

  @doc """
  Inserts or updates a failure pattern entry.

  On conflict (`story_signature` + `failure_mode`) the existing record is
  incremented and enriched with additional metadata.
  """
  @spec insert(map(), Keyword.t()) :: {:ok, FailurePattern.t()} | {:error, Ecto.Changeset.t()}
  def insert(attrs, opts \\ []) when is_map(attrs) or is_list(attrs) do
    attrs
    |> normalize_attrs()
    |> upsert(opts)
  end

  @doc """
  Convenience wrapper around `insert/2` for readability when recording failures.
  """
  @spec record_failure(map(), Keyword.t()) ::
          {:ok, FailurePattern.t()} | {:error, Ecto.Changeset.t()}
  def record_failure(attrs, opts \\ []), do: insert(attrs, opts)

  @doc """
  Returns stored failure patterns that match the provided filters.
  """
  @spec query(filteropts) :: [FailurePattern.t()]
  def query(filters \\ %{}) do
    filters = Map.new(filters)

    FailurePattern
    |> apply_filters(filters)
    |> order_by([fp], desc: fp.last_seen_at)
    |> maybe_limit(filters)
    |> Repo.all()
  end

  @doc """
  Returns aggregated failure modes ordered by total frequency.
  """
  @spec find_patterns(Keyword.t()) :: [map()]
  def find_patterns(opts \\ []) do
    filters = Map.new(opts)
    limit = Map.get(filters, :limit, 20)

    FailurePattern
    |> apply_filters(filters)
    |> group_by([fp], fp.failure_mode)
    |> select([fp], %{
      failure_mode: fp.failure_mode,
      total_frequency: sum(fp.frequency),
      story_types: fragment("array_remove(array_agg(DISTINCT ?), NULL)", fp.story_type),
      last_seen_at: max(fp.last_seen_at)
    })
    |> order_by([fp], fragment("sum(?) DESC", fp.frequency))
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Finds failure patterns similar to the supplied story signature or plan.

  Similarity is estimated using `String.jaro_distance/2` between story
  signatures. Returns entries scored above the supplied threshold (default 0.80)
  sorted by descending similarity.
  """
  @spec find_similar(map(), Keyword.t()) :: [map()]
  def find_similar(criteria, opts \\ []) do
    signature = extract_signature(criteria)
    threshold = Keyword.get(opts, :threshold, 0.80)
    limit = Keyword.get(opts, :limit, 10)

    if is_binary(signature) and signature != "" do
      filters =
        opts
        |> Keyword.drop([:threshold, :limit])
        |> Map.new()

      query(filters)
      |> Enum.map(fn pattern ->
        score = similarity(pattern.story_signature, signature)
        %{pattern: pattern, similarity: score}
      end)
      |> Enum.filter(&(&1.similarity >= threshold))
      |> Enum.sort_by(& &1.similarity, :desc)
      |> Enum.take(limit)
    else
      []
    end
  end

  @doc """
  Collects successful fixes from matching failure patterns.
  """
  @spec get_successful_fixes(filteropts) :: [map()]
  def get_successful_fixes(filters \\ %{}) do
    query(filters)
    |> Enum.flat_map(&List.wrap(&1.successful_fixes))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(&:erlang.term_to_binary/1)
  end

  @doc """
  Publishes failure patterns to CentralCloud if the integration is available.

  Returns `{:ok, patterns}` when syncing locally, or `{:error, reason}` when the
  integration is not configured.
  """
  @spec sync_with_centralcloud(filteropts) :: {:ok, [FailurePattern.t()]} | {:error, term()}
  def sync_with_centralcloud(filters \\ %{}) do
    patterns = query(filters)

    # Publish failure patterns to CentralCloud via PgFlow
    # Queue: patterns_learned_published (consumed by CentralCloud.Consumers.PatternLearningConsumer)
    message = %{
      "type" => "patterns_learned",
      "instance_id" => System.get_env("SINGULARITY_INSTANCE_ID", "singularity_#{node()}"),
      "artifacts" => Enum.map(patterns, &format_pattern_for_centralcloud/1),
      "usage_count" => Enum.reduce(patterns, 0, fn p, acc -> acc + (p.frequency || 0) end),
      "success_rate" => calculate_success_rate(patterns),
      "timestamp" => DateTime.utc_now()
    }

    case Singularity.Infrastructure.PgFlow.Queue.send_with_notify("patterns_learned_published", message) do
      {:ok, _} ->
        Logger.debug("Failure patterns published to CentralCloud",
          pattern_count: length(patterns)
        )

        {:ok, patterns}

      {:error, reason} ->
        Logger.warning("Failed to publish failure patterns to CentralCloud", reason: reason)
        {:error, reason}
    end
  end

  defp format_pattern_for_centralcloud(%FailurePattern{} = pattern) do
    %{
      "name" => pattern.failure_mode || "unknown",
      "type" => "failure_pattern",
      "story_type" => pattern.story_type,
      "failure_mode" => pattern.failure_mode,
      "story_signature" => pattern.story_signature,
      "frequency" => pattern.frequency || 0,
      "successful_fixes" => pattern.successful_fixes || [],
      "last_seen_at" => pattern.last_seen_at
    }
  end

  defp calculate_success_rate(patterns) when is_list(patterns) do
    if length(patterns) > 0 do
      total = Enum.reduce(patterns, 0, fn p, acc -> acc + (p.frequency || 0) end)

      successful =
        Enum.reduce(patterns, 0, fn p, acc -> acc + length(p.successful_fixes || []) end)

      if total > 0, do: successful / total, else: 0.0
    else
      0.0
    end
  end

  defp upsert(attrs, opts) do
    replace_existing? = Keyword.get(opts, :replace_existing, false)

    case find_existing(attrs) do
      nil ->
        %FailurePattern{}
        |> FailurePattern.changeset(attrs)
        |> Repo.insert()

      %FailurePattern{} = pattern when replace_existing? ->
        pattern
        |> FailurePattern.changeset(
          attrs
          |> Map.put(:frequency, attrs[:frequency] || pattern.frequency)
        )
        |> Repo.update()

      %FailurePattern{} = pattern ->
        pattern
        |> FailurePattern.increment_changeset(attrs)
        |> Repo.update()
    end
  end

  defp find_existing(%{story_signature: signature, failure_mode: mode})
       when is_binary(signature) and is_binary(mode) do
    Repo.one(
      from fp in FailurePattern,
        where:
          fp.story_signature == ^signature and
            fp.failure_mode == ^mode,
        limit: 1
    )
  end

  defp find_existing(_), do: nil

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:story_type, value}, acc when is_binary(value) ->
        where(acc, [fp], fp.story_type == ^value)

      {:failure_mode, value}, acc when is_binary(value) ->
        where(acc, [fp], fp.failure_mode == ^value)

      {:story_signature, value}, acc when is_binary(value) ->
        where(acc, [fp], fp.story_signature == ^value)

      {:since, %DateTime{} = value}, acc ->
        where(acc, [fp], fp.last_seen_at >= ^value)

      {:min_frequency, value}, acc when is_integer(value) ->
        where(acc, [fp], fp.frequency >= ^value)

      {:validation_state, value}, acc when is_binary(value) ->
        where(acc, [fp], fp.validation_state == ^String.trim(String.downcase(value)))

      _other, acc ->
        acc
    end)
  end

  defp maybe_limit(query, filters) do
    case Map.get(filters, :limit) do
      nil -> query
      limit when is_integer(limit) and limit > 0 -> limit(query, ^limit)
      _ -> query
    end
  end

  defp similarity(nil, _), do: 0.0
  defp similarity(_, nil), do: 0.0
  defp similarity(sig1, sig2), do: String.jaro_distance(sig1, sig2)

  defp extract_signature(%{story_signature: signature}) when is_binary(signature), do: signature

  defp extract_signature(%{plan: plan}) when is_map(plan) do
    cond do
      is_binary(plan[:story_signature]) -> plan[:story_signature]
      is_binary(plan["story_signature"]) -> plan["story_signature"]
      true -> nil
    end
  end

  defp extract_signature(_), do: nil

  defp normalize_attrs(attrs) when is_map(attrs) do
    attrs
    |> Enum.reduce(%{}, fn
      {key, value}, acc when is_atom(key) ->
        Map.put(acc, key, value)

      {key, value}, acc when is_binary(key) ->
        case key do
          "run_id" -> Map.put(acc, :run_id, value)
          "story_type" -> Map.put(acc, :story_type, value)
          "story_signature" -> Map.put(acc, :story_signature, value)
          "failure_mode" -> Map.put(acc, :failure_mode, value)
          "root_cause" -> Map.put(acc, :root_cause, value)
          "plan_characteristics" -> Map.put(acc, :plan_characteristics, value)
          "validation_state" -> Map.put(acc, :validation_state, value)
          "validation_errors" -> Map.put(acc, :validation_errors, value)
          "execution_error" -> Map.put(acc, :execution_error, value)
          "frequency" -> Map.put(acc, :frequency, value)
          "successful_fixes" -> Map.put(acc, :successful_fixes, value)
          "last_seen_at" -> Map.put(acc, :last_seen_at, value)
          "frequency_increment" -> Map.put(acc, :frequency_increment, value)
          _ -> acc
        end

      _other, acc ->
        acc
    end)
    |> normalize_collections()
  end

  defp normalize_attrs(attrs) when is_list(attrs) do
    attrs |> Enum.into(%{}) |> normalize_attrs()
  end

  defp normalize_collections(attrs) do
    attrs
    |> Map.update(:plan_characteristics, %{}, fn
      value when is_map(value) -> value
      _ -> %{}
    end)
    |> Map.update(:validation_errors, [], fn
      value when is_list(value) -> Enum.reject(value, &is_nil/1)
      value when is_map(value) -> [value]
      _ -> []
    end)
    |> Map.update(:successful_fixes, [], fn
      value when is_list(value) -> Enum.reject(value, &is_nil/1)
      value when is_map(value) -> [value]
      _ -> []
    end)
    |> Map.update(:frequency_increment, 1, fn
      value when is_integer(value) and value > 0 -> value
      _ -> 1
    end)
    |> Map.update(:frequency, nil, fn
      value when is_integer(value) and value > 0 -> value
      _ -> nil
    end)
  end
end
