defmodule CentralCloud.FrameworkLearningOrchestrator do
  @moduledoc """
  Framework Learning Orchestrator - Config-driven orchestration of framework learning strategies.

  Automatically discovers and runs enabled learners (template-based, LLM-based, signature analysis, etc.)
  in priority order as a fallback chain. Replaces the hard-coded template → LLM fallback with
  a flexible, config-driven system.

  ## Module Identity (JSON)

  ```json
  {
    "module": "CentralCloud.FrameworkLearningOrchestrator",
    "purpose": "Config-driven orchestration of framework learning strategies",
    "layer": "framework_learning",
    "status": "production"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      Learn["learn(package_id, code_samples)"]
      LoadConfig["Load enabled learners by priority"]
      Try1["Try Learner 1 (priority 5)"]
      Try2["Try Learner 2 (priority 10)"]
      Try3["Try Learner 3 (priority 20)"]
      Success["Success: Framework found"]
      Next1["No match → Try next"]
      Next2["No match → Try next"]
      Error["Error: Stop and return error"]

      Learn --> LoadConfig
      LoadConfig --> Try1
      Try1 -->|success| Success
      Try1 -->|no_match| Next1
      Try1 -->|error| Error
      Next1 --> Try2
      Try2 -->|success| Success
      Try2 -->|no_match| Next2
      Try2 -->|error| Error
      Next2 --> Try3
      Try3 -->|success| Success
      Try3 -->|error| Error
  ```

  ## Usage Examples

  ```elixir
  # Discover framework using all enabled learners in priority order
  {:ok, framework, learner} = FrameworkLearningOrchestrator.learn("npm:react", code_samples)
  # framework: %{name: "React", type: "web_framework", version: "18.2.0"}
  # learner: :template_matcher  (which learner succeeded)

  # Only try specific learners
  {:ok, framework, learner} = FrameworkLearningOrchestrator.learn(
    "cargo:tokio",
    code_samples,
    learners: [:llm_discovery]  # Skip templates, go straight to LLM
  )

  # Handle no match or error
  case FrameworkLearningOrchestrator.learn("npm:package", ["sample.js"]) do
    {:ok, framework, learner} ->
      IO.puts("Discovered: " <> framework["name"] <> " via " <> to_string(learner))
    {:error, :no_framework_found} ->
      IO.puts("Could not determine framework")
    {:error, reason} ->
      IO.puts("Error: " <> inspect(reason))
  end
  ```

  ## How Learning Works

  1. **Load enabled learners from config** (sorted by priority, ascending)
  2. **Try each learner in sequence**:
     - If `{:ok, framework}` → Return immediately (first match wins)
     - If `:no_match` → Continue to next learner
     - If `{:error, reason}` → Return error (stop trying)
  3. **Record success** - Call the learner's `record_success/2` callback
  4. **Return `{:ok, framework, learner_type}`**

  If all learners return `:no_match`, return `{:error, :no_framework_found}`.

  ## Comparison: Old vs New

  ### Old (Hard-Coded)
  ```elixir
  def discover_framework(package_id, code_samples) do
    # Try templates first
    case try_templates(package_id) do
      {:ok, framework} -> {:ok, framework}
      :no_match ->
        # Fallback to LLM
        try_llm(package_id, code_samples)
      error -> error
    end
  end
  ```

  ### New (Config-Driven)
  ```elixir
  def learn(package_id, code_samples, opts \\ []) do
    # Learners from config, automatically tried in priority order
    learners = FrameworkLearner.load_enabled_learners()
    try_learners(learners, package_id, code_samples, opts)
  end
  ```

  **Benefits of new approach**:
  - ✅ Add new learning strategies via config only
  - ✅ Reorder strategies without code changes
  - ✅ Enable/disable strategies in production
  - ✅ Track which strategy worked best (analytics)
  - ✅ Easy to test each learner independently
  """

  require Logger
  alias CentralCloud.FrameworkLearner

  @doc """
  Learn framework from package and code samples using enabled learners.

  Tries each enabled learner in priority order (lowest priority number first).
  Returns immediately on first success or hard error.

  ## Parameters

  - `package_id`: Package identifier (e.g., "npm:react", "cargo:tokio")
  - `code_samples`: List of code snippets or file contents to analyze
  - `opts`: Optional keyword list:
    - `:learners` - Specific learner types to try (default: all enabled)
    - `:timeout` - Timeout per learner in milliseconds (default: no timeout)

  ## Returns

  - `{:ok, framework_map, learner_type}` - Successfully learned framework
  - `{:error, :no_framework_found}` - All learners returned :no_match
  - `{:error, reason}` - Hard error from learner (stops trying)

  The framework_map contains at minimum:
  - `:name` - Framework name (required)
  - `:type` - Type: web_framework, backend, build_tool, etc.
  - `:metadata` - Arbitrary additional info (optional)
  """
  def learn(package_id, code_samples, opts \\ []) when is_binary(package_id) and is_list(code_samples) do
    try do
      learners = load_learners_for_attempt(opts)

      case try_learners(learners, package_id, code_samples, opts) do
        {:ok, framework, learner_type} ->
          # Record success for analytics
          record_learner_success(learner_type, package_id, framework)
          {:ok, framework, learner_type}

        {:error, :no_match} ->
          Logger.warning("No framework found for #{package_id}",
            tried_learners: Enum.map(learners, fn {type, _priority, _config} -> type end)
          )
          {:error, :no_framework_found}

        error ->
          error
      end
    rescue
      e ->
        Logger.error("Framework learning failed",
          error: inspect(e),
          package_id: package_id,
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
    FrameworkLearner.load_enabled_learners()
    |> Enum.map(fn {type, priority, config} ->
      description = FrameworkLearner.get_description(type)

      %{
        name: type,
        enabled: true,
        priority: priority,
        description: description,
        module: config[:module],
        capabilities: get_capabilities(type)
      }
    end)
  end

  @doc """
  Get capabilities for a specific learner type.
  """
  def get_capabilities(learner_type) when is_atom(learner_type) do
    case FrameworkLearner.get_learner_module(learner_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) && function_exported?(module, :capabilities, 0) do
          module.capabilities()
        else
          []
        end

      {:error, _} ->
        []
    end
  end

  # Private helpers

  defp load_learners_for_attempt(opts) do
    case Keyword.get(opts, :learners) do
      nil ->
        # Use all enabled learners
        FrameworkLearner.load_enabled_learners()

      specific_learners when is_list(specific_learners) ->
        # Filter to only requested learners, maintaining priority order
        all_learners = FrameworkLearner.load_enabled_learners()

        Enum.filter(all_learners, fn {type, _priority, _config} ->
          type in specific_learners
        end)
    end
  end

  defp try_learners([], _package_id, _code_samples, _opts) do
    # All learners tried, none matched
    {:error, :no_match}
  end

  defp try_learners([{learner_type, _priority, config} | rest], package_id, code_samples, opts) do
    try do
      module = config[:module]

      if module && Code.ensure_loaded?(module) do
        Logger.debug("Trying #{learner_type} learner", package_id: package_id)

        # Execute learner
        case module.learn(package_id, code_samples) do
          {:ok, framework} ->
            Logger.info("Framework learning succeeded with #{learner_type}",
              package_id: package_id,
              framework_name: framework[:name]
            )

            {:ok, framework, learner_type}

          :no_match ->
            # This learner couldn't determine, try next
            Logger.debug("#{learner_type} learner returned no_match", package_id: package_id)
            try_learners(rest, package_id, code_samples, opts)

          {:error, reason} ->
            # Hard error, stop trying
            Logger.error("#{learner_type} learner returned error",
              reason: inspect(reason),
              package_id: package_id
            )

            {:error, reason}
        end
      else
        Logger.warning("Learner module not found for #{learner_type}")
        try_learners(rest, package_id, code_samples, opts)
      end
    rescue
      e ->
        Logger.error("Learner execution failed for #{learner_type}",
          error: inspect(e),
          package_id: package_id,
          stacktrace: inspect(__STACKTRACE__)
        )

        # Try next learner on execution error
        try_learners(rest, package_id, code_samples, opts)
    end
  end

  defp record_learner_success(learner_type, package_id, framework) do
    case FrameworkLearner.get_learner_module(learner_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) && function_exported?(module, :record_success, 2) do
          try do
            module.record_success(package_id, framework)
          rescue
            e ->
              Logger.warning("Failed to record learner success",
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
