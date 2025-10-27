defmodule Singularity.Workflows.RuleImport do
  @moduledoc """
  Pgflow workflow for importing Genesis rules via pgmq.

  Ensures rule import runs through ex_pgflow so we get durable execution,
  retries, and consistent telemetry.
  """

  require Logger

  alias Singularity.Jobs.PgmqClient

  @default_namespace "validation_rules"
  @default_min_confidence 0.85
  @default_limit 20

  def __workflow_steps__ do
    [
      {:prepare_context, &__MODULE__.prepare_context/1},
      {:read_queue, &__MODULE__.read_queue/1},
      {:filter_rules, &__MODULE__.filter_rules/1},
      {:ack_messages, &__MODULE__.ack_messages/1},
      {:summarize, &__MODULE__.summarize/1}
    ]
  end

  @doc false
  def prepare_context(input) do
    options = Map.get(input, "options", %{})

    prepared = %{
      namespace: Map.get(options, "namespace", @default_namespace),
      min_confidence:
        options
        |> Map.get("min_confidence", @default_min_confidence)
        |> as_float(@default_min_confidence),
      limit:
        options
        |> Map.get("limit", @default_limit)
        |> as_integer(@default_limit),
      messages: []
    }

    Logger.debug("RuleImport workflow: Prepared context",
      namespace: prepared.namespace,
      min_confidence: prepared.min_confidence,
      limit: prepared.limit
    )

    {:ok, prepared}
  end

  @doc false
  def read_queue(%{namespace: namespace, limit: limit} = state) do
    Logger.debug("RuleImport workflow: Reading pgmq queue",
      namespace: namespace,
      limit: limit
    )

    try do
      PgmqClient.ensure_queue(queue_name(namespace))
      messages = PgmqClient.read_messages(queue_name(namespace), limit)
      {:ok, Map.put(state, :messages, messages)}
    rescue
      error ->
        Logger.error("RuleImport workflow: Failed to read queue", error: inspect(error))
        {:error, error}
    end
  end

  @doc false
  def filter_rules(%{messages: messages, min_confidence: min_confidence} = state) do
    rules =
      messages
      |> Enum.map(fn {msg_id, payload} -> {msg_id, normalize_payload(payload)} end)
      |> Enum.filter(fn {_id, rule} -> rule.confidence >= min_confidence end)

    Logger.info("RuleImport workflow: Filtered rules",
      total_messages: length(messages),
      accepted: length(rules),
      min_confidence: min_confidence
    )

    {:ok,
     state
     |> Map.put(:filtered_rules, rules)
     |> Map.put(:accepted_count, length(rules))}
  end

  @doc false
  def ack_messages(%{messages: messages, namespace: namespace} = state) do
    Enum.each(messages, fn {msg_id, _payload} ->
      PgmqClient.ack_message(queue_name(namespace), msg_id)
    end)

    Logger.debug("RuleImport workflow: Acknowledged #{length(messages)} messages")

    {:ok, state}
  end

  @doc false
  def summarize(%{filtered_rules: rules, namespace: namespace, accepted_count: count}) do
    imported =
      Enum.map(rules, fn {_msg_id, rule} ->
        Map.put(rule, :imported_at, DateTime.utc_now())
      end)

    summary = %{
      imported_count: count,
      namespace: namespace,
      rules: imported
    }

    Logger.info("RuleImport workflow: Completed",
      imported: count,
      namespace: namespace
    )

    {:ok, summary}
  end

  defp queue_name(_namespace), do: "genesis_rule_updates"

  defp normalize_payload(payload) do
    %{
      pattern: get_field(payload, [:pattern]),
      action: get_field(payload, [:action]),
      confidence: get_field(payload, [:confidence]) || 0.0,
      source_instance: get_field(payload, [:source_instance]) || "unknown",
      source_version:
        get_field(payload, [:metadata, :version]) || get_field(payload, ["metadata", "version"]),
      metadata: get_field(payload, [:metadata]) || %{}
    }
  end

  defp get_field(payload, [key | rest]) when is_map(payload) do
    value =
      case Map.fetch(payload, key) do
        {:ok, found} ->
          found

        :error ->
          cond do
            is_atom(key) and Map.has_key?(payload, Atom.to_string(key)) ->
              Map.get(payload, Atom.to_string(key))

            is_binary(key) and Map.has_key?(payload, key) ->
              Map.get(payload, key)

            is_binary(key) ->
              case safe_to_atom(key) do
                {:ok, atom_key} -> Map.get(payload, atom_key)
                :error -> nil
              end

            true ->
              nil
          end
      end

    get_field(value, rest)
  end

  defp get_field(payload, []) do
    payload
  end

  defp get_field(_payload, _path), do: nil

  defp safe_to_atom(key) when is_binary(key) do
    try do
      {:ok, String.to_existing_atom(key)}
    rescue
      ArgumentError ->
        :error
    end
  end

  defp safe_to_atom(_), do: :error

  defp as_float(value, _default) when is_float(value), do: value
  defp as_float(value, _default) when is_integer(value), do: value / 1
  defp as_float(_, default), do: default

  defp as_integer(value, _default) when is_integer(value), do: value
  defp as_integer(value, _default) when is_float(value), do: trunc(value)
  defp as_integer(_, default), do: default
end
