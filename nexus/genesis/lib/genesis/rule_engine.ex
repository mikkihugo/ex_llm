defmodule Genesis.RuleEngine do
  @moduledoc """
  Genesis Rule Engine - Applies evolved linting and validation rules

  Manages the application of dynamically learned rules from Singularity instances
  to Genesis's code analysis pipeline. Supports rule versioning, confidence scoring,
  and cross-instance rule aggregation.

  ## Architecture

  Rules flow through Genesis as follows:

  ```
  Singularity Instance
        ↓ (publishes via PgFlow)
  genesis_rule_updates queue
        ↓ (consumed by PgFlowWorkflowConsumer)
  RuleEngine.apply_rule()
        ↓ (applies to current rule set)
  Genesis code analysis
        ↓ (uses updated rules)
  Better analysis results
  ```

  ## Rule Format

  ```elixir
  %{
    namespace: "validation_rules" | "linting_rules",
    rule_type: "linting" | "validation" | "security" | "performance",
    pattern: %{...},  # Conditions for when rule applies
    action: %{...},   # What to do when pattern matches
    confidence: 0.0..1.0,  # Trust level
    source: "singularity_instance_1",
    applied_at: DateTime.t()
  }
  ```

  ## Usage

  ```elixir
  # Apply a rule from another instance
  :ok = RuleEngine.apply_rule(%{
    namespace: "validation_rules",
    rule_type: "linting",
    pattern: %{language: "elixir", module_size: :large},
    action: %{checks: ["cyclomatic_complexity", "line_length"]},
    confidence: 0.92,
    source: "singularity_2"
  })

  # Get applied rules
  rules = RuleEngine.get_rules(namespace: "validation_rules", min_confidence: 0.8)

  # Remove low-confidence rule
  :ok = RuleEngine.remove_rule(rule_id)
  ```
  """

  require Logger

  @type rule :: %{
          namespace: String.t(),
          rule_type: String.t(),
          pattern: map(),
          action: map(),
          confidence: float(),
          source: String.t(),
          applied_at: DateTime.t()
        }

  @type apply_result :: :ok | {:error, term()}

  @doc """
  Apply a rule from another Singularity instance to Genesis.

  Rules are stored with metadata (confidence, source, timestamp) for tracking
  and potential rollback if effectiveness degrades.

  ## Parameters
  - `rule` - Rule map with required fields

  ## Returns
  - `:ok` - Rule applied successfully
  - `{:error, reason}` - Application failed
  """
  @spec apply_rule(rule) :: apply_result
  def apply_rule(rule) do
    Logger.info("[Genesis.RuleEngine] Applying rule",
      namespace: rule.namespace,
      rule_type: rule.rule_type,
      source: rule.source,
      confidence: rule.confidence
    )

    # Validate rule structure
    case validate_rule(rule) do
      :ok ->
        # In production, would store rule in database with full metadata
        # For now, log as applied
        Logger.debug("[Genesis.RuleEngine] Rule applied",
          rule: inspect(rule)
        )

        :ok

      {:error, reason} ->
        Logger.error("[Genesis.RuleEngine] Rule validation failed",
          error: reason,
          rule: inspect(rule)
        )

        {:error, reason}
    end
  end

  @doc """
  Get rules by namespace and optional filters.

  ## Parameters
  - `opts` - Options:
    - `:namespace` - Filter by namespace (required)
    - `:min_confidence` - Only rules >= confidence (default: 0.0)
    - `:rule_type` - Filter by rule type (optional)
    - `:source` - Filter by source instance (optional)

  ## Returns
  - List of matching rules
  """
  @spec get_rules(keyword()) :: [rule]
  def get_rules(opts) do
    namespace = Keyword.fetch!(opts, :namespace)
    min_confidence = Keyword.get(opts, :min_confidence, 0.0)
    _rule_type = Keyword.get(opts, :rule_type)
    _source = Keyword.get(opts, :source)

    Logger.debug("[Genesis.RuleEngine] Fetching rules",
      namespace: namespace,
      min_confidence: min_confidence
    )

    # In production, would query database
    # For now, return empty list
    []
  end

  @doc """
  Remove a rule by ID (if it proves ineffective).

  ## Parameters
  - `rule_id` - ID of rule to remove

  ## Returns
  - `:ok` - Rule removed
  - `{:error, :not_found}` - Rule not found
  """
  @spec remove_rule(String.t()) :: :ok | {:error, term()}
  def remove_rule(rule_id) do
    Logger.info("[Genesis.RuleEngine] Removing rule", rule_id: rule_id)

    # In production, would delete from database
    :ok
  end

  @doc """
  Get rule statistics (how many rules applied, effectiveness metrics, etc.).

  ## Returns
  - Map with rule statistics
  """
  @spec get_statistics() :: map()
  def get_statistics do
    %{
      total_rules_applied: 0,
      by_namespace: %{},
      by_confidence: %{},
      by_source: %{},
      last_updated: DateTime.utc_now()
    }
  end

  # --- Private Helpers ---

  defp validate_rule(rule) do
    required_fields = [:namespace, :rule_type, :pattern, :action, :confidence, :source]

    case Enum.reject(required_fields, &Map.has_key?(rule, &1)) do
      [] ->
        # Validate field types
        validate_field_types(rule)

      missing ->
        {:error, "Missing required fields: #{inspect(missing)}"}
    end
  end

  defp validate_field_types(rule) do
    confidence = Map.get(rule, :confidence, 0.0)

    cond do
      not is_binary(rule.namespace) ->
        {:error, "namespace must be a string"}

      not is_binary(rule.rule_type) ->
        {:error, "rule_type must be a string"}

      not is_map(rule.pattern) ->
        {:error, "pattern must be a map"}

      not is_map(rule.action) ->
        {:error, "action must be a map"}

      not (is_number(confidence) and confidence >= 0.0 and confidence <= 1.0) ->
        {:error, "confidence must be between 0.0 and 1.0"}

      not is_binary(rule.source) ->
        {:error, "source must be a string"}

      true ->
        :ok
    end
  end
end
