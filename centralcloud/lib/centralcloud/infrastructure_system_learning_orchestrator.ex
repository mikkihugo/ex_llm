defmodule CentralCloud.InfrastructureSystemLearningOrchestrator do
  @moduledoc """
  Infrastructure System Learning Orchestrator - Config-driven orchestration of infrastructure system discovery strategies.

  Automatically discovers and runs enabled learners (manual registry, LLM-based, etc.)
  in priority order as a fallback chain. Replaces hard-coded learner selection with
  a flexible, config-driven system.

  ## Usage Examples

  ```elixir
  # Discover infrastructure systems using all enabled learners in priority order
  request = %{
    "query_type" => "infrastructure_registry",
    "include" => ["message_brokers", "databases"],
    "min_confidence" => 0.7
  }

  {:ok, systems, learner} = InfrastructureSystemLearningOrchestrator.learn(request)
  # systems: %{message_brokers: [...], databases: [...]}
  # learner: :manual_registry  (which learner succeeded)

  # Only try specific learners
  {:ok, systems, learner} = InfrastructureSystemLearningOrchestrator.learn(
    request,
    learners: [:llm_discovery]  # Skip manual registry, go straight to LLM
  )
  ```

  ## How Learning Works

  1. **Load enabled learners from config** (sorted by priority, ascending)
  2. **Try each learner in sequence**:
     - If `{:ok, systems}` → Return immediately (first match wins)
     - If `:no_match` → Continue to next learner
     - If `{:error, reason}` → Return error (stop trying)
  3. **Record success** - Call the learner's `record_success/2` callback
  4. **Return `{:ok, systems, learner_type}`**

  If all learners return `:no_match`, return `{:error, :no_systems_found}`.
  """

  require Logger
  alias CentralCloud.InfrastructureSystemLearner

  @doc """
  Learn infrastructure systems from request using enabled learners.

  Tries each enabled learner in priority order (lowest priority number first).
  Returns immediately on first success or hard error.

  ## Parameters

  - `request`: Map with query parameters (query_type, include, min_confidence, etc.)
  - `opts`: Optional keyword list:
    - `:learners` - Specific learner types to try (default: all enabled)
    - `:timeout` - Timeout per learner in milliseconds (default: no timeout)

  ## Returns

  - `{:ok, systems_map, learner_type}` - Successfully learned systems
  - `{:error, :no_systems_found}` - All learners returned :no_match
  - `{:error, reason}` - Hard error from learner (stops trying)

  The systems_map is a map of system categories to system lists.
  """
  def learn(request, opts \\ []) when is_map(request) do
    try do
      learners = load_learners_for_attempt(opts)

      case try_learners(learners, request, opts) do
        {:ok, systems, learner_type} ->
          # Record success for analytics
          record_learner_success(learner_type, request, systems)
          {:ok, systems, learner_type}

        {:error, :no_match} ->
          Logger.warn("No infrastructure systems found for request",
            query_type: request["query_type"],
            tried_learners: Enum.map(learners, fn {type, _priority, _config} -> type end)
          )
          {:error, :no_systems_found}

        error ->
          error
      end
    rescue
      e ->
        Logger.error("Infrastructure system learning failed",
          error: inspect(e),
          request: inspect(request),
          stacktrace: inspect(__STACKTRACE__)
        )

        {:error, :learning_failed}
    end
  end

  @doc """
  Get information about all configured learners and their status.

  Returns list of learner info maps with name, enabled status, priority, description, module.
  """
  def get_learners_info do
    InfrastructureSystemLearner.load_enabled_learners()
    |> Enum.map(fn {type, priority, config} ->
      description = InfrastructureSystemLearner.get_description(type)

      %{
        name: type,
        enabled: true,
        priority: priority,
        description: description,
        module: config[:module]
      }
    end)
  end

  # Private helpers

  defp load_learners_for_attempt(opts) do
    case Keyword.get(opts, :learners) do
      nil ->
        # Use all enabled learners
        InfrastructureSystemLearner.load_enabled_learners()

      specific_learners when is_list(specific_learners) ->
        # Filter to only requested learners, maintaining priority order
        all_learners = InfrastructureSystemLearner.load_enabled_learners()

        Enum.filter(all_learners, fn {type, _priority, _config} ->
          type in specific_learners
        end)
    end
  end

  defp try_learners([], _request, _opts) do
    # All learners tried, none matched
    {:error, :no_match}
  end

  defp try_learners([{learner_type, _priority, config} | rest], request, opts) do
    try do
      module = config[:module]

      if module && Code.ensure_loaded?(module) do
        Logger.debug("Trying #{learner_type} learner",
          query_type: request["query_type"]
        )

        # Execute learner
        case module.learn(request) do
          {:ok, systems} ->
            Logger.info("Infrastructure system learning succeeded with #{learner_type}",
              query_type: request["query_type"],
              categories_count: map_size(systems)
            )

            {:ok, systems, learner_type}

          :no_match ->
            # This learner couldn't determine, try next
            Logger.debug("#{learner_type} learner returned no_match",
              query_type: request["query_type"]
            )
            try_learners(rest, request, opts)

          {:error, reason} ->
            # Hard error, stop trying
            Logger.error("#{learner_type} learner returned error",
              reason: inspect(reason),
              query_type: request["query_type"]
            )

            {:error, reason}
        end
      else
        Logger.warn("Learner module not found for #{learner_type}")
        try_learners(rest, request, opts)
      end
    rescue
      e ->
        Logger.error("Learner execution failed for #{learner_type}",
          error: inspect(e),
          query_type: request["query_type"],
          stacktrace: inspect(__STACKTRACE__)
        )

        # Try next learner on execution error
        try_learners(rest, request, opts)
    end
  end

  defp record_learner_success(learner_type, request, systems) do
    case InfrastructureSystemLearner.get_learner_module(learner_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) && function_exported?(module, :record_success, 2) do
          try do
            module.record_success(request, systems)
          rescue
            e ->
              Logger.warn("Failed to record learner success",
                learner: learner_type,
                error: inspect(e)
              )
          end
        end

      {:error, _} ->
        :ok
    end
  end
end
