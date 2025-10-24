defmodule CentralCloud.TemplateIntelligence do
  @moduledoc """
  Template Intelligence Hub - Cross-instance learning and pattern aggregation.

  Aggregates template generation data from all Singularity instances to learn:
  - What questions are asked most?
  - What answers lead to success?
  - What answer combinations work best?
  - How do templates evolve over time?

  ## Phase 3: CentralCloud Intelligence

  Enables collective learning across all Singularity instances:

  ```
  Singularity Instance 1 → Publishes answers → CentralCloud
  Singularity Instance 2 → Publishes answers → CentralCloud
  Singularity Instance N → Publishes answers → CentralCloud
                                                    ↓
                                             Aggregates patterns
                                                    ↓
                                      Learns: "72% use ETS with GenServer"
                                      Learns: "ETS + one_for_one = 98% success"
                                                    ↓
                                          Publishes insights back
                                                    ↓
  Singularity instances → Get smart defaults based on global data
  ```

  ## NATS Subjects

  **Subscribes to:**
  - `centralcloud.template.generation` - Template generation events from instances

  **Publishes to:**
  - `singularity.template.insights` - Aggregated intelligence back to instances

  **Request/Response:**
  - `centralcloud.template.intelligence` - Query for smart defaults

  ## Examples

      # Query answer patterns
      {:ok, patterns} = TemplateIntelligence.query_answer_patterns(
        template_id: "quality_template:elixir-production"
      )

      # Get best answer combinations
      best = TemplateIntelligence.get_best_answer_combinations(
        "quality_template:elixir-production"
      )

      # Suggest defaults based on global data
      {:ok, defaults} = TemplateIntelligence.suggest_defaults(
        "quality_template:elixir-production"
      )
  """

  use GenServer
  require Logger

  alias Centralcloud.Repo
  alias CentralCloud.TemplateGenerationGlobal

  @nats_subject "centralcloud.template.generation"
  @request_subject "centralcloud.template.intelligence"

  ## Client API

  @doc """
  Start the TemplateIntelligence GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Query answer patterns across all instances.

  Returns aggregated statistics about what answers are commonly used.
  """
  def query_answer_patterns(opts) do
    GenServer.call(__MODULE__, {:query_patterns, opts})
  end

  @doc """
  Get best answer combinations (highest success rate).

  Returns answer combinations sorted by success rate and usage count.
  """
  def get_best_answer_combinations(template_id) do
    GenServer.call(__MODULE__, {:best_combinations, template_id})
  end

  @doc """
  Suggest default answers based on global intelligence.

  Returns suggested defaults with confidence scores based on:
  - Usage frequency across instances
  - Success rates for different combinations
  - Sample size (more data = higher confidence)
  """
  def suggest_defaults(template_id) do
    GenServer.call(__MODULE__, {:suggest_defaults, template_id})
  end

  @doc """
  Get failure patterns for a template (Phase 4: Self-Improvement).

  Returns common failure patterns and worst answer combinations to help
  Self-Improving Agent improve failing templates.
  """
  def get_failure_patterns(template_id) do
    GenServer.call(__MODULE__, {:get_failure_patterns, template_id})
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting CentralCloud TemplateIntelligence...")

    # Subscribe to NATS for template generation events
    {:ok, subscription} = subscribe_to_nats()

    # Subscribe to NATS for request/response queries
    {:ok, request_subscription} = subscribe_to_requests()

    state = %{
      subscription: subscription,
      request_subscription: request_subscription,
      stats: %{},
      last_aggregation: DateTime.utc_now()
    }

    # Schedule periodic aggregation
    schedule_aggregation()

    {:ok, state}
  end

  @impl true
  def handle_info({:nats_msg, %{body: body}}, state) do
    # Handle incoming template generation from Singularity instance
    case Jason.decode(body) do
      {:ok, generation} ->
        Logger.debug("Received generation from instance #{generation["instance_id"]}")

        # Store in global database
        store_generation(generation)

        # Update in-memory stats
        new_stats = update_stats(state.stats, generation)

        {:noreply, %{state | stats: new_stats}}

      {:error, reason} ->
        Logger.warning("Failed to decode NATS message: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:aggregate_stats, state) do
    Logger.info("Aggregating template statistics...")

    # Aggregate patterns from database
    aggregate_patterns()

    # Publish insights back to instances
    publish_insights()

    # Schedule next aggregation
    schedule_aggregation()

    {:noreply, %{state | last_aggregation: DateTime.utc_now()}}
  end

  @impl true
  def handle_call({:query_patterns, opts}, _from, state) do
    template_id = Keyword.fetch!(opts, :template_id)

    # Query aggregated patterns from database
    patterns = query_patterns_from_db(template_id)

    {:reply, {:ok, patterns}, state}
  end

  @impl true
  def handle_call({:best_combinations, template_id}, _from, state) do
    # Get best answer combinations from database
    combinations = query_best_combinations(template_id)

    {:reply, {:ok, combinations}, state}
  end

  @impl true
  def handle_call({:suggest_defaults, template_id}, _from, state) do
    # Suggest defaults based on global data
    defaults = calculate_smart_defaults(template_id)

    {:reply, {:ok, defaults}, state}
  end

  @impl true
  def handle_call({:get_failure_patterns, template_id}, _from, state) do
    # Get failure patterns for template improvement (Phase 4)
    patterns = query_failure_patterns(template_id)

    {:reply, {:ok, patterns}, state}
  end

  @impl true
  def handle_info({:nats_request, subject, reply_to, body}, state) do
    # Handle NATS request/response for remote queries
    case Jason.decode(body) do
      {:ok, %{"action" => "suggest_defaults", "template_id" => template_id}} ->
        {:ok, defaults} = calculate_smart_defaults(template_id)
        response = Jason.encode!(defaults)
        Centralcloud.NatsClient.publish(reply_to, response)
        {:noreply, state}

      {:ok, %{"action" => "get_failure_patterns", "template_id" => template_id}} ->
        {:ok, patterns} = query_failure_patterns(template_id)
        response = Jason.encode!(patterns)
        Centralcloud.NatsClient.publish(reply_to, response)
        {:noreply, state}

      {:ok, request} ->
        Logger.warning("Unknown NATS request action", action: Map.get(request, "action"))
        error_response = Jason.encode!(%{error: "Unknown action"})
        Centralcloud.NatsClient.publish(reply_to, error_response)
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Failed to decode NATS request", reason: inspect(reason))
        {:noreply, state}
    end
  end

  ## Private Functions

  defp subscribe_to_nats do
    # Subscribe to template generation events
    case Centralcloud.NatsClient.subscribe(@nats_subject, self()) do
      {:ok, subscription} ->
        Logger.info("Subscribed to #{@nats_subject}")
        {:ok, subscription}

      {:error, reason} ->
        Logger.error("Failed to subscribe to NATS: #{inspect(reason)}")
        {:ok, nil}  # Continue without NATS (degraded mode)
    end
  rescue
    e ->
      Logger.error("Exception subscribing to NATS: #{inspect(e)}")
      {:ok, nil}
  end

  defp subscribe_to_requests do
    # Subscribe to request/response subject for queries
    case Centralcloud.NatsClient.subscribe(@request_subject, self()) do
      {:ok, subscription} ->
        Logger.info("Subscribed to request subject #{@request_subject}")
        {:ok, subscription}

      {:error, reason} ->
        Logger.error("Failed to subscribe to request subject: #{inspect(reason)}")
        {:ok, nil}  # Continue without request handling (degraded mode)
    end
  rescue
    e ->
      Logger.error("Exception subscribing to request subject: #{inspect(e)}")
      {:ok, nil}
  end

  defp store_generation(generation) do
    attrs = %{
      template_id: generation["template_id"],
      template_version: generation["template_version"],
      answers: generation["answers"],
      success: generation["success"],
      quality_score: generation["quality_score"],
      generated_at: parse_datetime(generation["generated_at"]),
      instance_id: generation["instance_id"],
      file_path: generation["file_path"]
    }

    case %TemplateGenerationGlobal{}
         |> TemplateGenerationGlobal.changeset(attrs)
         |> Repo.insert() do
      {:ok, _generation} ->
        :ok

      {:error, changeset} ->
        Logger.warning("Failed to store generation: #{inspect(changeset.errors)}")
        :error
    end
  end

  defp parse_datetime(nil), do: DateTime.utc_now()
  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _offset} -> datetime
      _ -> DateTime.utc_now()
    end
  end
  defp parse_datetime(_), do: DateTime.utc_now()

  defp update_stats(stats, generation) do
    template_id = generation["template_id"]

    current = Map.get(stats, template_id, %{count: 0, success: 0})

    updated = %{
      count: current.count + 1,
      success: current.success + if(generation["success"], do: 1, else: 0)
    }

    Map.put(stats, template_id, updated)
  end

  defp schedule_aggregation do
    # Aggregate every 5 minutes
    Process.send_after(self(), :aggregate_stats, :timer.minutes(5))
  end

  defp aggregate_patterns do
    # Run aggregation queries on database
    # This would calculate statistics like:
    # - Most common answer values
    # - Success rates by answer combination
    # - Trending patterns
    Logger.debug("Aggregating patterns from global database...")
  end

  defp publish_insights do
    # Publish aggregated insights back to instances
    # This would send smart defaults and patterns
    Logger.debug("Publishing insights to instances...")
  end

  defp query_patterns_from_db(template_id) do
    # Query database for answer patterns
    import Ecto.Query

    query =
      from g in TemplateGenerationGlobal,
        where: g.template_id == ^template_id,
        select: %{
          answers: g.answers,
          success: g.success,
          quality_score: g.quality_score,
          instance_id: g.instance_id
        }

    results = Repo.all(query)

    # Aggregate patterns
    %{
      total_instances: results |> Enum.map(& &1.instance_id) |> Enum.uniq() |> length(),
      total_generations: length(results),
      success_rate: calculate_success_rate(results),
      common_answers: aggregate_common_answers(results)
    }
  end

  defp query_best_combinations(template_id) do
    # Query for answer combinations with highest success rates
    import Ecto.Query

    query =
      from g in TemplateGenerationGlobal,
        where: g.template_id == ^template_id,
        group_by: g.answers,
        select: %{
          answers: g.answers,
          count: count(g.id),
          success_rate: fragment("AVG(CASE WHEN ? THEN 1.0 ELSE 0.0 END)", g.success),
          avg_quality: avg(g.quality_score)
        },
        having: count(g.id) >= 10,
        order_by: [desc: fragment("AVG(CASE WHEN ? THEN 1.0 ELSE 0.0 END)", g.success)],
        limit: 10

    Repo.all(query)
  end

  defp calculate_smart_defaults(template_id) do
    # Calculate smart defaults based on global usage
    patterns = query_patterns_from_db(template_id)

    %{
      suggested_answers: patterns.common_answers,
      confidence: min(patterns.total_generations / 100.0, 1.0),
      sample_size: patterns.total_generations,
      instances: patterns.total_instances
    }
  end

  defp calculate_success_rate([]), do: 0.0
  defp calculate_success_rate(results) do
    successful = Enum.count(results, & &1.success)
    successful / length(results)
  end

  defp aggregate_common_answers(results) do
    # Aggregate common answer values across all generations
    # Returns map of question_name => %{value => count}

    results
    |> Enum.flat_map(fn r -> Map.to_list(r.answers) end)
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      current = Map.get(acc, key, %{})
      value_count = Map.get(current, value, 0)
      updated = Map.put(current, value, value_count + 1)
      Map.put(acc, key, updated)
    end)
  end

  defp query_failure_patterns(template_id) do
    # Query for failure patterns (Phase 4: Self-Improvement)
    # Returns common failures and worst answer combinations
    import Ecto.Query

    # Get all failed generations
    failed_query =
      from g in TemplateGenerationGlobal,
        where: g.template_id == ^template_id and g.success == false,
        select: %{
          answers: g.answers,
          quality_score: g.quality_score,
          instance_id: g.instance_id,
          generated_at: g.generated_at
        }

    failed_results = Repo.all(failed_query)

    # Get worst answer combinations (lowest success rate)
    worst_combinations_query =
      from g in TemplateGenerationGlobal,
        where: g.template_id == ^template_id,
        group_by: g.answers,
        select: %{
          answers: g.answers,
          count: count(g.id),
          success_rate: fragment("AVG(CASE WHEN ? THEN 1.0 ELSE 0.0 END)", g.success),
          avg_quality: avg(g.quality_score)
        },
        having: count(g.id) >= 5,
        order_by: [asc: fragment("AVG(CASE WHEN ? THEN 1.0 ELSE 0.0 END)", g.success)],
        limit: 10

    worst_combinations = Repo.all(worst_combinations_query)

    # Analyze common failure patterns
    common_failures = analyze_common_failures(failed_results)

    %{
      common_failures: common_failures,
      worst_combinations: worst_combinations,
      total_failures: length(failed_results),
      failure_rate:
        if length(failed_results) > 0 do
          length(failed_results) / (length(failed_results) + count_successes(template_id))
        else
          0.0
        end
    }
  end

  defp analyze_common_failures(failed_results) do
    # Analyze which answer combinations appear most in failures
    if Enum.empty?(failed_results) do
      []
    else
      failed_results
      |> Enum.flat_map(fn r -> Map.to_list(r.answers) end)
      |> Enum.reduce(%{}, fn {key, value}, acc ->
        current = Map.get(acc, {key, value}, 0)
        Map.put(acc, {key, value}, current + 1)
      end)
      |> Enum.sort_by(fn {_combo, count} -> count end, :desc)
      |> Enum.take(10)
      |> Enum.map(fn {{key, value}, count} ->
        %{
          question: key,
          answer: value,
          failure_count: count,
          percentage: Float.round(count / length(failed_results) * 100, 1)
        }
      end)
    end
  end

  defp count_successes(template_id) do
    import Ecto.Query

    query =
      from g in TemplateGenerationGlobal,
        where: g.template_id == ^template_id and g.success == true,
        select: count(g.id)

    Repo.one(query) || 0
  end
end
