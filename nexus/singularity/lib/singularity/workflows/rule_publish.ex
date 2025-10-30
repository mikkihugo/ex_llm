defmodule Singularity.Workflows.RulePublish do
  @moduledoc """
  QuantumFlow workflow for publishing confident rules to Genesis.

  Replaces the direct in-process publication path and ensures all rule
  publishing runs through the durable ex_quantum_flow executor.
  """

  require Logger

  alias Singularity.Evolution.{RuleEvolutionSystem, AdaptiveConfidenceGating}

  @default_limit 10
  @default_namespace "validation_rules"

  def __workflow_steps__ do
    [
      {:prepare_context, &__MODULE__.prepare_context/1},
      {:load_rules, &__MODULE__.load_rules/1},
      {:select_publishable, &__MODULE__.select_publishable/1},
      {:publish_rules, &__MODULE__.publish_rules/1},
      {:summarize, &__MODULE__.summarize/1}
    ]
  end

  @doc false
  def prepare_context(input) do
    options = normalize_options(Map.get(input, "options", %{}))
    criteria = normalize_criteria(Map.get(input, "criteria", %{}))

    adaptive_threshold = AdaptiveConfidenceGating.get_current_threshold()

    prepared =
      %{
        criteria: criteria,
        options: %{
          adaptive_threshold: adaptive_threshold,
          min_confidence: Map.get(options, :min_confidence, adaptive_threshold),
          limit: Map.get(options, :limit, @default_limit),
          namespace: Map.get(options, :namespace, @default_namespace)
        }
      }

    Logger.debug("RulePublish workflow: Context prepared",
      options: prepared.options,
      criteria: Map.keys(prepared.criteria)
    )

    {:ok, prepared}
  end

  @doc false
  def load_rules(%{criteria: criteria, options: options} = state) do
    case RuleEvolutionSystem.analyze_and_propose_rules(criteria,
           min_confidence: 0.0,
           limit: options.limit + 10
         ) do
      {:ok, rules} ->
        Logger.debug("RulePublish workflow: Loaded rules for publication",
          total_rules: length(rules)
        )

        {:ok, Map.put(state, :rules, rules)}

      {:error, reason} ->
        Logger.error("RulePublish workflow: Failed to load rules", error: inspect(reason))
        {:error, reason}
    end
  end

  @doc false
  def select_publishable(%{rules: rules, options: options} = state) do
    publishable =
      rules
      |> Enum.filter(&AdaptiveConfidenceGating.should_publish_rule?/1)
      |> Enum.take(options.limit)

    Logger.info("RulePublish workflow: Selected publishable rules",
      total_candidates: length(rules),
      publishable: length(publishable),
      adaptive_threshold: options.adaptive_threshold
    )

    {:ok,
     state
     |> Map.put(:publishable_rules, publishable)
     |> Map.put(:skipped_rules, length(rules) - length(publishable))}
  end

  @doc false
  def publish_rules(%{publishable_rules: rules, options: options} = state) do
    {results, published_count} =
      Enum.reduce(rules, {[], 0}, fn rule, {acc, count} ->
        case RuleEvolutionSystem.publish_rule_to_genesis(rule, options.namespace) do
          {:ok, message_id} ->
            result = %{
              pattern: rule.pattern,
              action: rule.action,
              confidence: rule.confidence,
              status: :published,
              message_id: message_id
            }

            {[result | acc], count + 1}

          :skip ->
            result = %{
              pattern: rule.pattern,
              action: rule.action,
              confidence: rule.confidence,
              status: :skipped
            }

            {[result | acc], count}

          {:error, reason} ->
            result = %{
              pattern: rule.pattern,
              action: rule.action,
              confidence: rule.confidence,
              status: :failed,
              error: inspect(reason)
            }

            {[result | acc], count}
        end
      end)

    Logger.info("RulePublish workflow: Publication step complete",
      attempted: length(rules),
      published: published_count,
      failures: Enum.count(results, &(&1.status == :failed))
    )

    {:ok,
     state
     |> Map.put(:published_count, published_count)
     |> Map.put(:publication_results, Enum.reverse(results))}
  end

  @doc false
  def summarize(%{
        options: options,
        published_count: published_count,
        publishable_rules: publishable,
        skipped_rules: skipped,
        publication_results: results
      }) do
    summary = %{
      published_count: published_count,
      attempted: length(publishable),
      skipped: skipped,
      results: results,
      namespace: options.namespace,
      adaptive_threshold: options.adaptive_threshold
    }

    Logger.info("RulePublish workflow: Finished",
      namespace: options.namespace,
      published_count: published_count,
      skipped: skipped
    )

    {:ok, summary}
  end

  defp normalize_options(map) when is_map(map) do
    allowed = [:min_confidence, :limit, :namespace]

    map
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      case normalize_key(key, allowed) do
        nil -> acc
        atom_key -> Map.put(acc, atom_key, value)
      end
    end)
  end

  defp normalize_options(_), do: %{}

  defp normalize_criteria(map) when is_map(map) do
    allowed = [:task_type, :complexity, :time_range]

    map
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      case normalize_key(key, allowed) do
        nil -> acc
        atom_key -> Map.put(acc, atom_key, value)
      end
    end)
  end

  defp normalize_criteria(_), do: %{}

  defp normalize_key(key, allowed) when is_atom(key) do
    if key in allowed, do: key, else: nil
  end

  defp normalize_key(key, allowed) when is_binary(key) do
    Enum.find(allowed, fn atom -> Atom.to_string(atom) == key end)
  end

  defp normalize_key(_, _), do: nil
end
