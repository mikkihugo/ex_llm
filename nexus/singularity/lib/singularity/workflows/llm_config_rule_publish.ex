defmodule Singularity.Workflows.LlmConfigRulePublish do
  @moduledoc """
  Pgflow workflow for publishing LLM configuration rules to Genesis.

  Ensures all LLM configuration rule publishing runs through the durable ex_pgflow executor,
  enabling cross-instance sharing of optimal complexity/model mappings.
  """

  require Logger

  alias Singularity.Evolution.GenesisPublisher

  @default_limit 10
  @default_namespace "llm_configuration_rules"

  def __workflow_steps__ do
    [
      {:prepare_context, &__MODULE__.prepare_context/1},
      {:sync_settings, &__MODULE__.sync_settings/1},
      {:synthesize_rules, &__MODULE__.synthesize_rules/1},
      {:select_publishable, &__MODULE__.select_publishable/1},
      {:publish_rules, &__MODULE__.publish_rules/1},
      {:summarize, &__MODULE__.summarize/1}
    ]
  end

  @doc false
  def prepare_context(input) do
    options = normalize_options(Map.get(input, "options", %{}))

    prepared = %{
      options: %{
        min_confidence: Map.get(options, :min_confidence, 0.85),
        limit: Map.get(options, :limit, @default_limit),
        namespace: Map.get(options, :namespace, @default_namespace)
      }
    }

    Logger.debug("LlmConfigRulePublish workflow: Context prepared",
      options: prepared.options
    )

    {:ok, prepared}
  end

  @doc false
  def sync_settings(%{options: options} = state) do
    Logger.debug("LlmConfigRulePublish workflow: Syncing LLM config from Settings KV")

    case GenesisPublisher.sync_llm_config_from_settings() do
      {:ok, config} ->
        Logger.debug("LlmConfigRulePublish workflow: Settings synced",
          providers: Map.keys(config)
        )
        {:ok, Map.put(state, :settings_config, config)}

      {:error, reason} ->
        Logger.warning("LlmConfigRulePublish workflow: Settings sync failed, continuing",
          error: inspect(reason)
        )
        {:ok, Map.put(state, :settings_config, %{})}
    end
  end

  @doc false
  def synthesize_rules(%{options: options} = state) do
    Logger.debug("LlmConfigRulePublish workflow: Synthesizing LLM configuration rules")

    case GenesisPublisher.synthesize_llm_config_rules(
           min_confidence: 0.0,
           limit: options.limit + 10
         ) do
      {:ok, rules} ->
        Logger.debug("LlmConfigRulePublish workflow: Synthesized rules",
          total_rules: length(rules)
        )
        {:ok, Map.put(state, :rules, rules)}

      {:error, reason} ->
        Logger.error("LlmConfigRulePublish workflow: Failed to synthesize rules",
          error: inspect(reason)
        )
        {:error, reason}
    end
  end

  @doc false
  def select_publishable(%{rules: rules, options: options} = state) do
    min_confidence = options.min_confidence

    publishable =
      rules
      |> Enum.filter(&(&1.confidence >= min_confidence))
      |> Enum.take(options.limit)

    Logger.info("LlmConfigRulePublish workflow: Selected publishable rules",
      total_candidates: length(rules),
      publishable: length(publishable),
      min_confidence: min_confidence
    )

    {:ok,
     state
     |> Map.put(:publishable_rules, publishable)
     |> Map.put(:skipped_rules, length(rules) - length(publishable))}
  end

  @doc false
  def publish_rules(%{publishable_rules: rules, options: options} = state) do
    results =
      Enum.map(rules, fn rule ->
        case GenesisPublisher.publish_llm_config_rule(rule, options.namespace) do
          {:ok, message_id} ->
            %{
              pattern: rule.pattern,
              action: rule.action,
              confidence: rule.confidence,
              status: :published,
              message_id: message_id
            }

          {:error, reason} ->
            %{
              pattern: rule.pattern,
              action: rule.action,
              confidence: rule.confidence,
              status: :failed,
              error: inspect(reason)
            }
        end
      end)

    published_count = Enum.count(results, &(&1.status == :published))
    failed_count = Enum.count(results, &(&1.status == :failed))

    Logger.info("LlmConfigRulePublish workflow: Publication step complete",
      attempted: length(rules),
      published: published_count,
      failures: failed_count
    )

    {:ok,
     state
     |> Map.put(:published_count, published_count)
     |> Map.put(:publication_results, results)}
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
      namespace: options.namespace
    }

    Logger.info("LlmConfigRulePublish workflow: Finished",
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

  defp normalize_key(key, allowed) when is_atom(key) do
    if key in allowed, do: key, else: nil
  end

  defp normalize_key(key, allowed) when is_binary(key) do
    Enum.find(allowed, fn atom -> Atom.to_string(atom) == key end)
  end

  defp normalize_key(_, _), do: nil
end
