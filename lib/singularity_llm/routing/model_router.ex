defmodule SingularityLLM.Routing.ModelRouter do
  @moduledoc """
  Complexity-Based Model Router - Auto-route to best provider by task complexity.

  The ModelRouter enables complexity-aware model selection where you specify what
  you need to accomplish (simple calculation, medium-complexity code review, complex
  architecture design) and the system automatically routes to the best model.

  ## Architecture

  ```
  Application Code
      ↓
  ModelRouter.route(messages, complexity: :complex, filters: [...])
      ↓
  1. Query ModelCatalog for complexity requirements
  2. Apply optional capability filters (vision, function_calling, etc.)
  3. Score models by fit
      ↓
  ModelRouter routes to:
  - Best model by complexity score
  - First available model by price/speed trade-off
      ↓
  5. PUBLISH to pgmq → CentralCloud aggregates decisions
      ↓
  SingularityLLM.chat(provider, model, messages)
  ```

  ## CentralCloud Integration

  Routing decisions are published asynchronously to pgmq queue `model_routing_decisions`.
  CentralCloud consumes these events to:

  - Track which models are actually used across instances
  - Aggregate performance metrics per model/complexity
  - Learn optimal complexity scores from real outcomes
  - Detect provider availability issues
  - Build cross-instance routing intelligence

  Example event:
  ```json
  {
    "timestamp": "2025-10-27T06:55:00Z",
    "instance_id": "singularity-1",
    "routing_decision": {
      "complexity": "complex",
      "selected_model": "gpt-4o",
      "selected_provider": "github_models",
      "complexity_score": 4.8,
      "alternate_models": ["claude-opus", "gpt-4o"]
    }
  }
  ```

  ## Key Features

  - **Complexity-Aware**: Auto-select by :simple, :medium, :complex
  - **Capability Filtering**: Only models with required features
  - **Cost-Aware**: Prefer cheaper models for simple tasks
  - **Multi-Provider**: Routes across all configured providers
  - **Fallback**: Graceful degradation if preferred model unavailable

  ## Usage Examples

  ```elixir
  # Simple task - use fast, cheap model
  {:ok, response} = ModelRouter.route(messages, complexity: :simple)

  # Complex task - use most capable model
  {:ok, response} = ModelRouter.route(messages, complexity: :complex)

  # Specific requirements
  {:ok, response} = ModelRouter.route(messages,
    complexity: :medium,
    capabilities: [:vision, :function_calling],
    prefer: :speed  # or :cost
  )

  # Request specific model by name
  {:ok, response} = ModelRouter.route(messages, model: "gpt-4o")

  # Fallback chain: try models by score
  {:ok, response} = ModelRouter.route(messages,
    complexity: :complex,
    max_attempts: 3  # Try up to 3 providers
  )
  ```

  ## Anti-Patterns

  DO NOT:
  - Hard-code provider names in business logic
  - Assume model availability
  - Mix complexity levels in a single request

  DO:
  - Request by complexity and let router choose
  - Let system handle provider selection
  - Use capabilities filters for fine-grained control
  """

  require Logger
  alias SingularityLLM.Core.ModelCatalog
  alias Singularity.Workflow.Notifications
  alias Singularity.Repo

  # pgmq queue for routing events
  @routing_queue "model_routing_decisions"
  @instance_id System.get_env("INSTANCE_ID", "singularity-#{node()}")

  @type routing_opts :: [
    {:complexity, :simple | :medium | :complex}
    | {:model, String.t()}
    | {:capabilities, [String.t()]}
    | {:prefer, :speed | :cost}
    | {:max_attempts, non_neg_integer()}
    | {:fallback, boolean()}
  ]

  @type route_result ::
    {:ok, String.t(), String.t()}
    | {:error, atom(), String.t()}

  @doc """
  Route to best model based on complexity and optional filters.

  Returns `{:ok, provider, model_name}` for successful routing,
  or `{:error, reason, message}` if no suitable model found.

  ## Options

  - `:complexity` - Task complexity level: `:simple`, `:medium`, `:complex` (required if :model not specified)
  - `:model` - Specific model name to use (bypasses complexity selection)
  - `:capabilities` - Required capabilities: `[:vision, :function_calling, ...]`
  - `:prefer` - Selection preference: `:speed` (fastest model), `:cost` (cheapest model)
  - `:max_attempts` - Number of providers to try if routing fails
  - `:fallback` - Enable fallback to any available model if preferred unavailable (default: true)

  ## Examples

      iex> ModelRouter.route_model([%{role: "user", content: "Calculate 2+2"}], complexity: :simple)
      {:ok, :github_models, "gpt-4o-mini"}

      iex> ModelRouter.route_model(messages, complexity: :complex, capabilities: [:vision])
      {:ok, :github_models, "gpt-4o"}

      iex> ModelRouter.route_model(messages, model: "claude-opus")
      {:ok, :anthropic, "claude-opus"}
  """
  @spec route_model(list(), routing_opts()) :: route_result()
  def route_model(_messages, opts \\ []) do
    cond do
      # User specified exact model
      model_name = opts[:model] ->
        case ModelCatalog.get_provider(model_name) do
          {:ok, provider} ->
            # Publish routing event
            score = case ModelCatalog.get_complexity_score(model_name, opts[:complexity] || :medium) do
              {:ok, s} -> s
              _ -> 0.0
            end
            publish_routing_event(opts[:complexity] || :medium, model_name, provider, score, opts)
            {:ok, provider, model_name}

          {:error, reason} ->
            {:error, reason, "Model #{model_name} not found in catalog"}
        end

      # User specified complexity
      complexity = opts[:complexity] ->
        case select_by_complexity(complexity, opts) do
          {:ok, provider, model} ->
            # Publish routing event
            {:ok, score} = ModelCatalog.get_complexity_score(model, complexity)
            publish_routing_event(complexity, model, provider, score, opts)
            {:ok, provider, model}

          error ->
            error
        end

      # No complexity or model specified
      true ->
        {:error, :invalid_args, "Must specify either :complexity or :model"}
    end
  end

  @doc """
  Select best model for a given complexity level.

  Filters by required capabilities if specified, then selects the best model
  based on the preference (speed or cost).

  ## Examples

      iex> ModelRouter.select_by_complexity(:complex, capabilities: [:vision])
      {:ok, :github_models, "gpt-4o"}
  """
  @spec select_by_complexity(:simple | :medium | :complex, routing_opts()) :: route_result()
  def select_by_complexity(complexity, opts \\ []) when complexity in [:simple, :medium, :complex] do
    case ModelCatalog.find_models() do
      {:ok, all_models} ->
        # Filter by required capabilities
        required_caps = opts[:capabilities] || []
        filtered = filter_by_capabilities(all_models, required_caps)

        # Score and select
        case score_models(filtered, complexity, opts) do
          [] ->
            fallback_model(complexity, opts)

          scored ->
            best = Enum.max_by(scored, fn {_model, score} -> score end)
            {:ok, elem(best, 0).provider, elem(best, 0).name}
        end

      {:error, reason} ->
        {:error, reason, "Failed to load model catalog"}
    end
  end

  @doc """
  Get complexity score for a specific model.

  Returns the numeric score (0.0-5.0) indicating how well the model
  handles the specified complexity level.

  Higher scores = better fit for the complexity level.

  ## Examples

      iex> ModelRouter.get_score("gpt-4o", :complex)
      {:ok, 4.8}

      iex> ModelRouter.get_score("gpt-4o-mini", :complex)
      {:ok, 3.5}
  """
  @spec get_score(String.t(), :simple | :medium | :complex) :: {:ok, float()} | {:error, atom()}
  def get_score(model_name, complexity) do
    ModelCatalog.get_complexity_score(model_name, complexity)
  end

  @doc """
  List best models for a complexity level, ranked by score.

  Returns models sorted by complexity score in descending order.

  ## Examples

      iex> ModelRouter.ranked_models(:complex)
      {:ok, [
        %{provider: :anthropic, name: "claude-opus", score: 4.9},
        %{provider: :github_models, name: "gpt-4o", score: 4.8},
        %{provider: :mistral, name: "mistral-large", score: 4.0}
      ]}
  """
  @spec ranked_models(:simple | :medium | :complex) :: {:ok, [map()]} | {:error, atom()}
  def ranked_models(complexity) when complexity in [:simple, :medium, :complex] do
    case ModelCatalog.list_models() do
      {:ok, models} ->
        ranked =
          models
          |> Enum.map(fn model ->
            score = get_in(model, [:complexity_scores, complexity]) || 0.0
            {model, score}
          end)
          |> Enum.sort_by(fn {_model, score} -> score end, :desc)
          |> Enum.map(fn {model, score} ->
            Map.merge(model, %{score: score})
          end)

        {:ok, ranked}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Publish routing decision to CentralCloud via pgmq.

  Asynchronously publishes routing decisions for aggregation and learning.
  This is called automatically by route_model/2 but can be called manually
  to report outcomes (success/failure) for feedback.

  ## Examples

      iex> ModelRouter.publish_routing_event(:complex, "gpt-4o", :github_models, 4.8)
      :ok

      iex> ModelRouter.publish_routing_event(:complex, "gpt-4o", :github_models, 4.8,
      ...>   outcome: :success, response_time_ms: 1240)
      :ok
  """
  @spec publish_routing_event(
    :simple | :medium | :complex,
    String.t(),
    atom(),
    float(),
    Keyword.t()
  ) :: :ok | {:error, atom()}
  def publish_routing_event(complexity, model_name, provider, score, opts \\ []) do
    event = build_routing_event(complexity, model_name, provider, score, opts)

    # Publish asynchronously (non-blocking)
    Task.start_link(fn ->
      case publish_to_pgmq(event) do
        :ok ->
          Logger.debug("Published routing event for #{model_name} (#{complexity})")

        {:error, reason} ->
          Logger.warning("Failed to publish routing event: #{inspect(reason)}")
      end
    end)

    :ok
  end

  # Private implementation

  defp filter_by_capabilities(models, []) do
    models
  end

  defp filter_by_capabilities(models, required_caps) do
    Enum.filter(models, fn model ->
      Enum.all?(required_caps, fn cap ->
        cap_str = to_string(cap)
        Enum.member?(model.capabilities, cap_str)
      end)
    end)
  end

  defp score_models(models, complexity, opts) do
    preference = opts[:prefer] || :complexity

    models
    |> Enum.map(fn model ->
      score = calculate_score(model, complexity, preference)
      {model, score}
    end)
    |> Enum.filter(fn {_model, score} -> score > 0.0 end)
  end

  defp calculate_score(model, complexity, :complexity) do
    # Prioritize by complexity score
    get_in(model, [:complexity_scores, complexity]) || 0.0
  end

  defp calculate_score(model, complexity, :speed) do
    # Prefer smaller models for speed
    complexity_score = get_in(model, [:complexity_scores, complexity]) || 0.0
    # Boost score for models with lower max_output_tokens (usually faster)
    speed_factor = 5000.0 / max(model.max_output_tokens, 1)
    complexity_score * 0.7 + speed_factor * 0.3
  end

  defp calculate_score(model, complexity, :cost) do
    # Prefer cheaper models
    complexity_score = get_in(model, [:complexity_scores, complexity]) || 0.0
    input_price = get_in(model, [:pricing, :input]) || 0.0
    output_price = get_in(model, [:pricing, :output]) || 0.0
    avg_price = (input_price + output_price) / 2

    # Normalize price (free models score highest)
    cost_factor = if avg_price == 0.0, do: 1.0, else: 1.0 / (1.0 + avg_price)
    complexity_score * 0.6 + cost_factor * 0.4
  end

  defp fallback_model(complexity, opts) do
    # Try to find any model that matches complexity
    case select_by_complexity(complexity, Keyword.delete(opts, :capabilities)) do
      {:ok, provider, model} ->
        Logger.info("Fallback: Using #{model} from #{provider} for #{complexity} task")
        {:ok, provider, model}

      {:error, reason} ->
        if opts[:fallback] == false do
          {:error, reason, "No models available and fallback disabled"}
        else
          # Last resort: return cheapest model
          case ModelCatalog.get_by_complexity(:simple) do
            {:ok, fallback} ->
              Logger.warning("Final fallback: Using #{fallback.name} from #{fallback.provider}")
              {:ok, fallback.provider, fallback.name}

            {:error, _} ->
              {:error, :no_models_available, "No models available in catalog"}
          end
        end
    end
  end

  defp build_routing_event(complexity, model_name, provider, score, opts) do
    %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      instance_id: @instance_id,
      routing_decision: %{
        complexity: to_string(complexity),
        selected_model: model_name,
        selected_provider: to_string(provider),
        complexity_score: score,
        outcome: opts[:outcome] || :routed,
        response_time_ms: opts[:response_time_ms],
        capabilities_required: opts[:capabilities] || [],
        prefer: opts[:prefer],
        user_model_request: opts[:requested_model]
      }
    }
  end

  defp publish_to_pgmq(event) do
    # Try to publish to pgmq queue
    # If pgmq is not available (singularity_llm standalone), gracefully skip
    case Application.get_application(__MODULE__) do
      :singularity_llm ->
        # singularity_llm standalone - no pgmq integration
        :ok

      _ ->
        # Part of larger Singularity system with pgmq
        try do
          # Attempt to call the message queue
          # This will fail gracefully if pgmq is not available
          case Code.ensure_compiled(Singularity.Database.MessageQueue) do
            {:module, _} ->
              Singularity.Notifications.send_with_notify(@routing_queue, event, Repo, expect_reply: false)

            {:error, _} ->
              :ok
          end
        rescue
          _ -> :ok
        end
    end
  end
end
