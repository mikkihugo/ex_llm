defmodule ExLLM.Routing.TaskRouter do
  @moduledoc """
  Task-Specialized Model Router - Routes to best model by task type.

  Instead of generic complexity levels (:simple/:medium/:complex), this router
  uses task-specific win rates learned from real usage data.

  Inspired by LMSYS RouteLLM - predicts which model will perform best for
  a specific task based on preference data from previous executions.

  ## Task Types

  Semantic task categories that map directly to model strengths:

  - `:architecture` → System design, microservices (4.5-5.0 score)
  - `:coding` → Code generation, implementation (3.5-5.0)
  - `:refactoring` → Code improvement, optimization (3.0-4.5)
  - `:analysis` → Code review, debugging (3.0-4.5)
  - `:research` → Deep exploration, novel solutions (4.0-5.0)
  - `:planning` → Strategy, decomposition (2.0-3.5)
  - `:chat` → General conversation (1.5-3.0)

  ## Win Rate Calculation

  For each (task_type, model) pair:

  ```
  win_rate = successful_outcomes / total_outcomes
  score = win_rate × 0.7 + response_quality × 0.3
  ```

  Returns model with highest predicted score.

  ## Example Usage

  ```elixir
  # Route based on task type
  {:ok, provider, model} = TaskRouter.route(messages, :architecture)
  # => {:ok, :anthropic, "claude-opus"}

  # Get all models ranked for a task
  {:ok, ranked} = TaskRouter.ranked_for_task(:coding)
  # => [
  #   %{model: "codex", provider: :codex, win_rate: 0.95},
  #   %{model: "claude-sonnet", provider: :anthropic, win_rate: 0.82},
  #   %{model: "gpt-4o", provider: :openrouter, win_rate: 0.78}
  # ]

  # Record outcome for learning
  TaskRouter.record_preference(%{
    task_type: :coding,
    prompt: "Write async function...",
    selected_model: "codex",
    selected_provider: :codex,
    quality_score: 0.95,
    success: true
  })
  ```

  ## Integration with CentralCloud

  Preference data is published to pgmq `task_preferences` queue for
  cross-instance aggregation and learning.

  ## Task Types vs Complexity

  | Old Approach | New Approach |
  |---|---|
  | task → :complex | task → :architecture |
  | :complex → 4.5 score | :architecture → win_rate per model |
  | Generic "best complex" | Model-specific "best for architecture" |
  | Codex: 4.5 for complex | Codex: 0.42 for architecture (weak) |
  | | Codex: 0.95 for coding (strong) |
  """

  require Logger

  alias ExLLM.Core.ModelCatalog

  alias Singularity.Workflow.Notifications

  alias Singularity.Repo

  @instance_id System.get_env("SINGULARITY_INSTANCE_ID", "singularity-1")
  @preference_queue "task_preferences"

  @doc """
  Route to best model for a task type and complexity level.

  Returns {provider_atom, model_name} with highest win rate for this task/complexity combo.
  Falls back to complexity-based routing if no preference data available.

  Options:
    - :complexity_level - Task complexity: :simple, :medium, :complex (default: :medium)
    - :prefer - Scoring preference: :win_rate, :cost, :speed (default: :win_rate)
  """
  @spec route(list(), atom(), Keyword.t()) :: {:ok, atom(), String.t()} | {:error, atom()}
  def route(_messages, task_type, opts \\ []) when is_atom(task_type) do
    complexity_level = Keyword.get(opts, :complexity_level, :medium)

    case ModelCatalog.list_models() do
      {:ok, models} ->
        # Score each model by win rate for this task/complexity combo
        scored =
          models
          |> Enum.map(fn model ->
            win_rate = get_win_rate(task_type, model.name, complexity_level)
            score = calculate_score(model, win_rate, opts)
            {model, score, win_rate}
          end)
          |> Enum.filter(fn {_model, score, _wr} -> score > 0.0 end)
          |> Enum.sort_by(fn {_model, score, _wr} -> score end, :desc)

        case scored do
          [] ->
            Logger.warning("No models available for task_type: #{task_type}")
            {:error, :no_models_available}

          [{best_model, _score, win_rate} | _] ->
            Logger.info(
              "Task routing: #{task_type} → #{best_model.name} (win_rate: #{Float.round(win_rate, 2)})"
            )

            {:ok, best_model.provider, best_model.name}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get models ranked by win rate for a task type.

  Returns list of models with win rates in descending order.
  """
  @spec ranked_for_task(atom()) :: {:ok, [map()]} | {:error, atom()}
  def ranked_for_task(task_type) when is_atom(task_type) do
    case ModelCatalog.list_models() do
      {:ok, models} ->
        ranked =
          models
          |> Enum.map(fn model ->
            win_rate = get_win_rate(task_type, model.name)

            Map.merge(model, %{
              win_rate: Float.round(win_rate, 4),
              rank: nil
            })
          end)
          |> Enum.sort_by(& &1.win_rate, :desc)
          |> Enum.with_index(fn model, idx ->
            %{model | rank: idx + 1}
          end)

        {:ok, ranked}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get win rate for a specific (task_type, complexity_level, model) triplet.

  Queries preference data to calculate: successful_outcomes / total_outcomes

  If no data available, returns 0.5 (neutral).
  """
  @spec get_win_rate(atom(), String.t(), atom()) :: float()
  def get_win_rate(task_type, model_name, complexity_level \\ :medium) do
    # Query CentralCloud's preference table for learned metrics
    query_win_rate_from_db(task_type, model_name, complexity_level) || 0.5
  end

  @doc """
  Route to best model VARIANT for a task type and complexity level.

  Unlike `route/3` which scores all available models, this function:
  1. Identifies preferred base models for the task type
  2. Filters to variants of those models across providers
  3. Applies hard filters (context window, capabilities)
  4. Scores and ranks by win rate + price
  5. Returns best variant that satisfies constraints

  Options:
    - :complexity_level - Task complexity: :simple, :medium, :complex (default: :medium)
    - :prefer - Scoring preference: :win_rate, :cost, :speed (default: :win_rate)
    - :min_context_tokens - Minimum required context window (optional)
    - :required_capabilities - List of required capabilities (optional)

  Returns the best model variant considering both task-specific strengths
  and resource constraints.

  ## Examples

      iex> TaskRouter.route_with_variants(:architecture, context_needed: 256_000)
      {:ok, :anthropic, "claude-opus"}

      iex> TaskRouter.route_with_variants(:coding, prefer: :cost, min_context_tokens: 128_000)
      {:ok, :openrouter, "codex"}

      iex> TaskRouter.route_with_variants(:customer_support, required_capabilities: [:vision])
      {:ok, :openrouter, "gpt-4-turbo"}
  """
  @spec route_with_variants(atom(), Keyword.t()) :: {:ok, atom(), String.t()} | {:error, atom()}
  def route_with_variants(task_type, opts \\ []) when is_atom(task_type) do
    complexity_level = Keyword.get(opts, :complexity_level, :medium)
    min_context = Keyword.get(opts, :min_context_tokens)
    required_caps = Keyword.get(opts, :required_capabilities, [])

    with {:ok, models} <- ModelCatalog.list_models(),
         # Step 1: Get preferred base models for this task type
         preferred_bases <- preferred_models_for_task(task_type),
         # Step 2: Filter to variants of preferred models
         preferred_variants <- filter_preferred_variants(models, preferred_bases),
         # Step 3: Apply hard filters
         suitable <- hard_filter_models(preferred_variants, min_context, required_caps),
         # Step 4: Score and rank
         scored <-
           suitable
           |> Enum.map(fn model ->
             win_rate = get_win_rate(task_type, model.name, complexity_level)
             score = calculate_score(model, win_rate, opts)
             {model, score, win_rate}
           end)
           |> Enum.filter(fn {_model, score, _wr} -> score > 0.0 end)
           |> Enum.sort_by(fn {_model, score, _wr} -> score end, :desc) do
      case scored do
        [] ->
          Logger.warning(
            "No suitable model variants for task_type: #{task_type}, preferred: #{inspect(preferred_bases)}"
          )

          {:error, :no_suitable_variants}

        [{best_model, _score, win_rate} | _] ->
          Logger.info(
            "Task variant routing: #{task_type} → #{best_model.name} (provider: #{best_model.provider}, win_rate: #{Float.round(win_rate, 2)})"
          )

          {:ok, best_model.provider, best_model.name}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get list of preferred base models for a task type.

  Returns models that excel at the given task based on empirical
  performance data and domain knowledge.

  ## Examples

      iex> TaskRouter.preferred_models_for_task(:architecture)
      ["claude-opus", "gpt-4o", "google-julius"]

      iex> TaskRouter.preferred_models_for_task(:coding)
      ["codex", "claude-sonnet", "gpt-4o"]
  """
  @spec preferred_models_for_task(atom()) :: [String.t()]
  def preferred_models_for_task(task_type) do
    preferences = task_type_preferences()
    Map.get(preferences, task_type, ["gpt-4o"])  # Default fallback
  end

  @doc """
  Get all available model variants for a given base model name.

  Returns all providers offering this model with their context windows and pricing.

  ## Examples

      iex> TaskRouter.model_variants("gpt-4o")
      [
        %{name: "gpt-4o", provider: :openrouter, context_window: 128_000, pricing: ...},
        %{name: "gpt-4o", provider: :github_models, context_window: 128_000, pricing: ...},
      ]
  """
  @spec model_variants(String.t()) :: [map()]
  def model_variants(base_model_name) do
    case ModelCatalog.list_models() do
      {:ok, models} ->
        models
        |> Enum.filter(fn model ->
          # Match base model name (exact match or normalize)
          String.contains?(model.name, base_model_name) or
            String.contains?(base_model_name, model.name)
        end)

      {:error, _} ->
        []
    end
  end

  # === Private Implementation ===

  defp task_type_preferences do
    %{
      # Architecture: System design, microservices, large-scale planning
      # Prefer: Deep reasoning, long context, strong analytical skills
      :architecture => [
        "claude-opus",       # Best at architecture design
        "gpt-4o",            # Strong architecture analysis
        "google-julius",     # Good at complex systems
      ],

      # Coding: Code generation, implementation, debugging
      # Prefer: Fast, code-focused, function calling support
      :coding => [
        "codex",             # Best at code generation
        "claude-sonnet",     # Strong balanced coding
        "gpt-4o",            # Good coding capability
      ],

      # Refactoring: Code improvement, optimization, style
      # Prefer: Detail-oriented, strong code understanding
      :refactoring => [
        "claude-opus",       # Best at detailed refactoring
        "claude-sonnet",     # Good balance of power/speed
        "gpt-4o",            # Reliable refactoring
      ],

      # Analysis: Code review, debugging, root cause analysis
      # Prefer: Analytical, detailed reasoning
      :analysis => [
        "claude-opus",       # Best at deep analysis
        "gpt-4o",            # Strong analysis capability
        "claude-sonnet",     # Fast analysis
      ],

      # Research: Novel solutions, deep exploration, experiments
      # Prefer: Creative, broad knowledge, reasoning
      :research => [
        "claude-opus",       # Best at research
        "gpt-4o",            # Strong research capability
        "gemini-2-5-pro",    # Good research breadth
      ],

      # Planning: Strategy, decomposition, scheduling
      # Prefer: Organized thinking, break-down capability
      :planning => [
        "claude-sonnet",     # Good planning ability
        "gpt-4o",            # Solid planner
        "claude-opus",       # Detailed planning
      ],

      # Chat: General conversation, support, user interaction
      # Prefer: Friendly, responsive, capable enough for questions
      :chat => [
        "claude-sonnet",     # Best balance for chat
        "gpt-4o-mini",       # Fast light chat
        "gemini-2-5-flash",  # Ultra-fast chat
      ],

      # Customer Support: User-facing interactions, help, guidance
      # Prefer: Friendly, accurate, fast response
      :customer_support => [
        "gpt-4o-mini",       # Fast and capable for support
        "claude-haiku",      # Quick support responses
        "gemini-2-5-flash",  # Ultra-responsive
      ],
    }
  end

  defp filter_preferred_variants(models, preferred_bases) when is_list(preferred_bases) do
    models
    |> Enum.filter(fn model ->
      # Include model if it matches any preferred base model
      Enum.any?(preferred_bases, fn preferred ->
        match_base_model?(model.name, preferred)
      end)
    end)
  end

  defp match_base_model?(model_name, base_model) when is_binary(model_name) and is_binary(base_model) do
    # Normalize names for comparison (handle variants like gpt-4o vs gpt-4.1)
    normalized_model = String.downcase(model_name)
    normalized_base = String.downcase(base_model)

    # Exact match
    normalized_model == normalized_base or
      # Contains match (e.g., "gpt-4o" in "gpt-4o-mini" or "openrouter/gpt-4o")
      String.contains?(normalized_model, normalized_base) or
      String.contains?(normalized_base, normalized_model)
  end

  defp hard_filter_models(models, min_context, required_caps) do
    models
    |> Enum.filter(fn model ->
      # Context window filter
      context_ok =
        case min_context do
          nil -> true
          min -> (model.context_window || 4096) >= min
        end

      # Capabilities filter (all required caps must be present)
      caps_ok =
        case required_caps do
          [] ->
            true

          caps ->
            has_all_capabilities?(model, caps)
        end

      context_ok and caps_ok
    end)
  end

  defp has_all_capabilities?(model, required_caps) do
    model_caps = get_capabilities(model)

    Enum.all?(required_caps, fn required ->
      Enum.member?(model_caps, required)
    end)
  end

  defp get_capabilities(model) do
    capabilities = model.capabilities || []

    # Also check individual capability fields if present
    base_caps =
      if is_list(capabilities) do
        capabilities
      else
        []
      end

    additional = []

    additional =
      if Map.get(model, :vision) == true or Map.get(model, :image_input) == true do
        [:vision | additional]
      else
        additional
      end

    additional =
      if Map.get(model, :function_calling) == true do
        [:function_calling | additional]
      else
        additional
      end

    additional =
      if Map.get(model, :streaming) == true do
        [:streaming | additional]
      else
        additional
      end

    additional =
      if Map.get(model, :json_mode) == true do
        [:json_mode | additional]
      else
        additional
      end

    additional =
      if Map.get(model, :reasoning) == true do
        [:reasoning | additional]
      else
        additional
      end

    (base_caps ++ additional) |> Enum.uniq()
  end

  @doc """
  Record a task execution outcome for learning.

  Preference data is published to pgmq for CentralCloud aggregation.

  Expected fields in data:
    - :task_type - Task semantic type (:coding, :architecture, etc.)
    - :complexity_level - Task complexity (:simple, :medium, :complex) - defaults to :medium
    - :model_name - Selected model
    - :quality_score - Response quality 0.0-1.0
    - :success - Boolean outcome
    - :response_time_ms - Optional latency
  """
  @spec record_preference(map()) :: :ok | {:error, atom()}
  def record_preference(data) do
    # Ensure complexity_level is present
    data_with_complexity = Map.put_new(data, :complexity_level, :medium)

    event = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      instance_id: @instance_id,
      task_preference: data_with_complexity
    }

    publish_preference_event(event)
  end

  # === Private Implementation ===

  defp calculate_score(model, win_rate, opts) do
    preference = opts[:prefer] || :win_rate

    case preference do
      :win_rate ->
        # Prioritize by win rate
        win_rate

      :cost ->
        # Prefer cheaper models
        avg_price = get_average_price(model)
        cost_factor = if avg_price == 0.0, do: 1.0, else: 1.0 / (1.0 + avg_price)
        win_rate * 0.7 + cost_factor * 0.3

      :speed ->
        # Prefer faster models (smaller output tokens = typically faster)
        speed_factor = 5000.0 / max(model.max_output_tokens, 1)
        win_rate * 0.7 + speed_factor * 0.3

      _ ->
        win_rate
    end
  end

  defp get_average_price(model) do
    case model.pricing do
      %{input: input, output: output} ->
        (input + output) / 2

      _ ->
        0.0
    end
  end

  defp query_win_rate_from_db(task_type, model_name, complexity_level) do
    # Query CentralCloud for learned task/complexity/model metrics
    # Falls back to hardcoded defaults if not available

    case query_centralcloud_win_rate(task_type, model_name, complexity_level) do
      win_rate when is_float(win_rate) and win_rate > 0.0 ->
        # Successfully queried from database
        win_rate

      _ ->
        # Fall back to hardcoded known scores from models.dev
        # Look up with complexity level factored in
        default_win_rates_for_complexity(complexity_level)
        |> Map.get({task_type, model_name}, 0.5)
    end
  end

  defp query_centralcloud_win_rate(task_type, model_name, complexity_level) do
    # Try to query metrics from CentralCloud database with complexity level
    case ExLLM.Routing.TaskMetrics.get_metrics(task_type, model_name, complexity_level) do
      %{win_rate: win_rate, confidence: confidence} when confidence > 0.2 ->
        # Use database metrics if confidence is reasonable
        win_rate

      _ ->
        # Fall back to defaults
        nil
    end
  rescue
    _e ->
      # If there's any error, fall back gracefully
      nil
  end

  defp default_win_rates_for_complexity(complexity_level) do
    # Base win rates adjusted by complexity level
    # Simple tasks: add 0.05 (easier, higher success rate)
    # Medium tasks: base rate (balanced)
    # Complex tasks: subtract 0.05-0.10 (harder, lower success rate)
    base_rates = %{
      # Architecture tasks (system design)
      {:architecture, "google-julius"} => 0.92,
      {:architecture, "claude-opus"} => 0.88,
      {:architecture, "gpt-4o"} => 0.85,
      {:architecture, "claude-sonnet"} => 0.78,
      {:architecture, "grok-3"} => 0.72,
      {:architecture, "codex"} => 0.42,

      # Coding tasks (code generation)
      {:coding, "codex"} => 0.95,
      {:coding, "claude-sonnet"} => 0.82,
      {:coding, "gpt-4o"} => 0.78,
      {:coding, "claude-opus"} => 0.80,
      {:coding, "google-julius"} => 0.65,

      # Refactoring tasks
      {:refactoring, "claude-sonnet"} => 0.85,
      {:refactoring, "gpt-4o"} => 0.82,
      {:refactoring, "claude-opus"} => 0.88,
      {:refactoring, "codex"} => 0.75,

      # Analysis tasks (code review, debugging)
      {:analysis, "claude-opus"} => 0.90,
      {:analysis, "gpt-4o"} => 0.85,
      {:analysis, "claude-sonnet"} => 0.82,
      {:analysis, "codex"} => 0.78,

      # Research tasks
      {:research, "claude-opus"} => 0.92,
      {:research, "gpt-4o"} => 0.88,
      {:research, "gemini-2-5-pro"} => 0.85,
      {:research, "claude-sonnet"} => 0.80,

      # Planning tasks
      {:planning, "claude-sonnet"} => 0.80,
      {:planning, "gpt-4o"} => 0.78,
      {:planning, "claude-opus"} => 0.82,
      {:planning, "google-julius"} => 0.70,

      # General chat
      {:chat, "claude-sonnet"} => 0.82,
      {:chat, "gpt-4o-mini"} => 0.75,
      {:chat, "gemini-2-5-flash"} => 0.72,
      {:chat, "grok-3-mini"} => 0.68
    }

    # Adjust by complexity level
    adjustment = case complexity_level do
      :simple -> 0.05     # Easier tasks - higher success rate
      :medium -> 0.0      # Balanced baseline
      :complex -> -0.08   # Harder tasks - lower success rate
      _ -> 0.0             # Default to medium
    end

    base_rates
    |> Enum.map(fn {key, rate} ->
      adjusted = max(0.1, min(0.99, rate + adjustment))
      {key, adjusted}
    end)
    |> Map.new()
  end

  defp publish_preference_event(event) do
    # Try to publish to pgmq queue
    case Application.get_application(__MODULE__) do
      :ex_llm ->
        # ex_llm standalone - no pgmq integration
        Logger.debug("Task preference recorded (no pgmq): #{inspect(event)}")
        :ok

      _ ->
        # Part of larger Singularity system with pgmq
        try do
          case Singularity.Notifications.send_with_notify(@preference_queue, event, Repo, expect_reply: false) do
            :ok ->
              Logger.debug("Task preference published to pgmq")
              :ok

            {:error, reason} ->
              Logger.error("Failed to publish task preference: #{inspect(reason)}")
              {:error, reason}
          end
        rescue
          e ->
            Logger.error("Error publishing task preference: #{inspect(e)}")
            {:error, :publish_failed}
        end
    end
  end
end
