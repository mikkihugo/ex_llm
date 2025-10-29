defmodule CentralCloud.Workflows.LLMTeamWorkflow do
  @moduledoc """
  PGFlow workflow that orchestrates the CentralCloud multi-agent LLM review.

  The workflow runs three logical stages:
    1. Prepare context and choose the execution mode.
    2. Execute the specialist crew (analyst, validator, critic, researcher).
    3. Build a consensus report with confidence and recommendations.

  While the workflow currently uses deterministic heuristics for specialist
  outputs, it preserves the structure required to plug in real LLM calls. Each
  specialist returns structured data that downstream consumers can persist and
  analyse.
  """

  use Pgflow.Workflow
  require Logger

  @type mode :: :fast | :default | :thorough

  @crew_modes %{
    fast: [:analyst_review, :consensus_builder],
    default: [:analyst_review, :validator_review, :consensus_builder],
    thorough: [:analyst_review, :validator_review, :critic_review, :researcher_review, :consensus_builder]
  }

  @default_thresholds %{
    validator: 0.65,
    critic: 0.6,
    researcher: 0.55
  }

  @known_keys ~w(
    mode heuristics input code_samples pattern_type initial_confidence sample_count
    targets target_count specialists role confidence cost_seconds tokens_used notes
    insights targets_considered metadata skipped reason baseline final_confidence
    decision_trace recommendations status request_id
  )

  @spec __workflow_steps__() :: list()
  def __workflow_steps__ do
    [
      {:prepare_context, &__MODULE__.prepare_context/1},
      {:specialist_review, &__MODULE__.specialist_review/1, depends_on: [:prepare_context]},
      {:consensus_builder, &__MODULE__.consensus_builder/1, depends_on: [:specialist_review]}
    ]
  end

  # ────────────────────────────────────────────────────────────────
  # Step Implementations
  # ────────────────────────────────────────────────────────────────

  def prepare_context(input) when is_map(input) do
    data = sanitise_input(input)

    mode =
      data.mode ||
        cond do
          data.initial_confidence >= 0.85 -> :fast
          length(data.code_samples) > 5 -> :thorough
          length(data.code_samples) > 0 -> :default
          true -> :fast
        end

    heuristics = %{
      initial_confidence: clamp(data.initial_confidence),
      sample_count: length(data.code_samples),
      pattern_type: data.pattern_type
    }

    Logger.debug("[LLMTeamWorkflow] Prepared context", mode: mode, heuristics: heuristics)

    {:ok, %{mode: mode, heuristics: heuristics, input: data}}
  end

  def specialist_review(state) do
    plan = fetch_plan(state)
    targets = build_targets(plan.input.code_samples)
    target_metrics = compute_target_metrics(targets)

    analyst = run_specialist(:analyst, targets, plan, target_metrics)

    validator =
      maybe_run_optional(:validator, plan, targets, target_metrics, analyst.confidence)

    critic =
      maybe_run_optional(
        :critic,
        plan,
        targets,
        target_metrics,
        average_confidence([analyst, validator])
      )

    researcher =
      maybe_run_optional(
        :researcher,
        plan,
        targets,
        target_metrics,
        average_confidence([analyst, validator, critic])
      )

    specialists =
      [analyst, validator, critic, researcher]
      |> Enum.reject(&is_nil/1)

    {:ok,
     %{
       mode: plan.mode,
       heuristics: plan.heuristics,
       specialists: specialists,
       targets: Enum.map(targets, &Map.take(&1, [:id, :complexity_hint, :size])),
       target_metrics: target_metrics
     }}
  end

  def consensus_builder(state) do
    plan = fetch_plan(state)
    review = fetch_step(state, :specialist_review)
    specialists = review.specialists || []

    confidences =
      specialists
      |> Enum.map(& &1.confidence)
      |> Enum.reject(&is_nil/1)

    final_confidence =
      case confidences do
        [] -> plan.heuristics.initial_confidence
        list -> Enum.sum(list) / length(list)
      end
      |> clamp()

    summary = build_summary(specialists, plan.mode)

    {:ok,
     %{
       status: :completed,
       mode: plan.mode,
       final_confidence: final_confidence,
       specialists: specialists,
       decision_trace: summary.decision_trace,
       recommendations: summary.recommendations,
       insights: summary.insights,
       baseline: plan.heuristics,
       targets: review.targets,
       target_metrics: review.target_metrics
     }}
  end

  # ────────────────────────────────────────────────────────────────
  # Helper functions
  # ────────────────────────────────────────────────────────────────

  defp sanitise_input(map) do
    %{
      mode: get_value(map, :mode),
      initial_confidence: get_value(map, :initial_confidence, 0.5),
      code_samples: List.wrap(get_value(map, :code_samples, [])),
      pattern_type: get_value(map, :pattern_type, "architecture"),
      metadata: get_value(map, :metadata, %{}),
      request_id: get_value(map, :request_id)
    }
  end

  defp get_value(map, key, default \\ nil) do
    case Map.fetch(map, key) do
      {:ok, value} ->
        value

      :error ->
        Map.get(map, Atom.to_string(key), default)
    end
  end

  defp fetch_plan(state) do
    state
    |> fetch_step(:prepare_context)
    |> normalise_keys()
  end

  defp fetch_step(state, key) do
    value =
      Map.get(state, key) ||
        Map.get(state, Atom.to_string(key)) ||
        %{}

    if is_map(value), do: normalise_keys(value), else: value
  end

  defp normalise_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {k, v}, acc ->
      key = maybe_atom_key(k)
      value = if is_map(v), do: normalise_keys(v), else: v
      Map.put(acc, key, value)
    end)
  end

  defp normalise_keys(value), do: value

  defp maybe_atom_key(key) when is_atom(key), do: key

  defp maybe_atom_key(key) when is_binary(key) do
    if key in @known_keys do
      String.to_atom(key)
    else
      key
    end
  end

  defp maybe_atom_key(other), do: other

  defp build_targets(samples) do
    samples
    |> Enum.with_index(1)
    |> Enum.map(fn {sample, idx} ->
      content = sample_content(sample)
      %{
        id: "target_#{idx}",
        snippet: truncate(content, 400),
        size: byte_size(content),
        complexity_hint: calculate_complexity_hint(content)
      }
    end)
  end

  defp sample_content(%{"content" => content}), do: content
  defp sample_content(%{content: content}), do: content
  defp sample_content(sample) when is_binary(sample), do: sample
  defp sample_content(_), do: ""

  defp maybe_run_optional(role, plan, targets, metrics, base_confidence) do
    enabled_steps = Map.get(@crew_modes, plan.mode, [])
    step_atom = step_name_for(role)
    threshold = Map.fetch!(@default_thresholds, role)

    cond do
      step_atom in enabled_steps ->
        run_specialist(role, targets, plan, metrics)

      base_confidence < threshold ->
        run_specialist(role, targets, plan, metrics)

      base_confidence >= 0.95 and role != :researcher ->
        skipped_specialist(role, :high_confidence, base_confidence)

      true ->
        skipped_specialist(role, :mode_skip, base_confidence)
    end
  end

  defp skipped_specialist(role, reason, confidence) do
    %{
      role: role,
      skipped: true,
      reason: reason,
      confidence: clamp(confidence),
      notes:
        case reason do
          :high_confidence -> "Skipped #{role} because confidence already high"
          :mode_skip -> "Mode does not require #{role}"
        end
    }
  end

  defp run_specialist(role, targets, plan, metrics) do
    adjustment = specialist_adjustment(role, metrics)
    base = plan.heuristics.initial_confidence
    confidence = clamp(base + adjustment)
    discussion = build_discussion(role, targets, metrics)

    %{
      role: role,
      confidence: confidence,
      cost_seconds: estimated_cost(role, metrics),
      tokens_used: estimated_tokens(role, targets),
      notes: discussion.summary,
      insights: discussion.insights,
      targets_considered: Enum.map(targets, & &1.id),
      mode: plan.mode,
      metadata: %{
        pattern_type: plan.heuristics.pattern_type,
        sample_count: plan.heuristics.sample_count,
        heuristics: plan.heuristics,
        request_id: plan.input.request_id
      }
    }
  end

  defp average_confidence(specialists) do
    specialists
    |> Enum.reject(&(&1 == nil))
    |> Enum.map(& &1.confidence)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> 0.0
      list -> Enum.sum(list) / length(list)
    end
    |> clamp()
  end

  defp build_summary(specialists, mode) do
    narratives =
      specialists
      |> Enum.map(fn specialist ->
        "#{specialist.role}: confidence #{format_conf(specialist.confidence)}"
      end)

    insights =
      specialists
      |> Enum.flat_map(&(&1[:insights] || []))

    recommendations =
      insights
      |> Enum.filter(&String.contains?(&1, "Recommendation"))

    %{
      decision_trace: ["mode=#{mode}" | narratives],
      insights: insights,
      recommendations: recommendations
    }
  end

  defp compute_target_metrics(targets) do
    count = max(Enum.count(targets), 1)
    sizes = Enum.map(targets, & &1.size)
    average_size = Enum.sum(sizes) / count
    average_complexity = clamp(average_size / 2000)

    variance =
      sizes
      |> Enum.map(fn size -> :math.pow(size - average_size, 2) end)
      |> Enum.sum()
      |> Kernel./(count)
      |> (&(min(&1 / 4_000_000, 1.0))).()

    unknown_ratio = Enum.count(Enum.filter(targets, &(&1.size < 200))) / count

    %{
      average_size: average_size,
      average_complexity: average_complexity,
      variance: variance,
      unknown_ratio: unknown_ratio
    }
  end

  defp specialist_adjustment(:analyst, metrics), do: 0.1 + metrics.average_complexity * 0.1
  defp specialist_adjustment(:validator, metrics), do: 0.05 + metrics.average_complexity * 0.05
  defp specialist_adjustment(:critic, metrics), do: -0.05 + metrics.variance * 0.1
  defp specialist_adjustment(:researcher, metrics), do: 0.03 + metrics.unknown_ratio * 0.15

  defp estimated_cost(role, metrics) do
    base = %{analyst: 12, validator: 8, critic: 10, researcher: 15}[role] || 5
    Float.round(base + metrics.average_size / 2000, 2)
  end

  defp estimated_tokens(role, targets) do
    multiplier = %{analyst: 1.2, validator: 0.9, critic: 1.0, researcher: 1.5}[role] || 1.0
    base_tokens = Enum.reduce(targets, 0, fn t, acc -> acc + div(t.size, 4) end)
    trunc(base_tokens * multiplier)
  end

  defp build_discussion(role, targets, metrics) do
    coverage = targets |> Enum.map(& &1.id) |> Enum.join(", ")

    summary =
      "#{role} assessed #{length(targets)} target(s); avg complexity #{format_conf(metrics.average_complexity)}; coverage: #{coverage}"

    insights =
      case role do
        :analyst ->
          [
            "Key finding: #{highest_complexity_target(targets)}",
            "Recommendation: focus refactoring on high-complexity targets"
          ]

        :validator ->
          ["Recommendation: add automated tests for modules with low confidence"]

        :critic ->
          ["Risk: potential regressions due to inconsistent patterns detected"]

        :researcher ->
          ["External evidence: pattern aligns with industry references"]
      end

    %{summary: summary, insights: insights}
  end

  defp highest_complexity_target([]), do: "no targets"

  defp highest_complexity_target(targets) do
    targets
    |> Enum.max_by(& &1.size, fn -> hd(targets) end)
    |> Map.get(:id)
  end

  defp truncate(nil, _), do: ""

  defp truncate(value, max) when is_binary(value) do
    if String.length(value) <= max do
      value
    else
      String.slice(value, 0, max) <> "…"
    end
  end

  defp truncate(_, _), do: ""

  defp calculate_complexity_hint(sample) when is_binary(sample) do
    lines = sample |> String.split("\n") |> Enum.count()
    clamp(lines / 200)
  end

  defp calculate_complexity_hint(_), do: 0.0

  defp clamp(value) when is_number(value) do
    value
    |> max(0.0)
    |> min(1.0)
  end

  defp clamp(value), do: value

  defp format_conf(nil), do: "n/a"

  defp format_conf(value), do: :io_lib.format("~.2f", [value]) |> IO.iodata_to_binary()

  defp step_name_for(:validator), do: :validator_review
  defp step_name_for(:critic), do: :critic_review
  defp step_name_for(:researcher), do: :researcher_review
  defp step_name_for(_), do: :analyst_review
end
