defmodule Singularity.Metrics.EventAggregator do
  @moduledoc """
  Metrics Event Aggregator - Computes time-bucketed statistics.

  Processes raw events from metrics_events table and computes statistics
  (count, sum, avg, min, max, stddev) over hourly/daily periods.
  Results stored in metrics_aggregated for fast queries.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Metrics.EventAggregator",
    "purpose": "Compute time-series statistics from raw metrics events",
    "layer": "metrics",
    "status": "production",
    "integration": "EventCollector → EventAggregator → Query"
  }
  ```

  ## Self-Documenting API

  Main aggregation functions:
  - `aggregate_by_period/2` - Aggregate all events for a time period
  - `aggregate_events_by_name/3` - Aggregate specific event type
  - `aggregate_events_with_tags/3` - Aggregate with tag filtering

  Helper functions:
  - `calculate_statistics/1` - Calculate stats from measurements

  ## Examples

  ```elixir
  # Aggregate past hour (all events)
  now = DateTime.utc_now()
  hour_ago = DateTime.add(now, -3600, :second)
  EventAggregator.aggregate_by_period(:hour, {hour_ago, now})

  # Aggregate past day (specific event type)
  day_ago = DateTime.add(now, -86400, :second)
  EventAggregator.aggregate_events_by_name("llm.cost", :day, {day_ago, now})

  # Aggregate with tag filters
  EventAggregator.aggregate_events_with_tags(
    %{"model" => "claude-opus"},
    :hour,
    {hour_ago, now}
  )

  # Calculate statistics manually
  measurements = [0.01, 0.02, 0.025, 0.03, 0.05]
  stats = EventAggregator.calculate_statistics(measurements)
  # => %{count: 5, sum: 0.135, avg: 0.027, min: 0.01, max: 0.05, stddev: 0.016...}
  ```

  ## Idempotency

  All aggregation functions are idempotent. Re-running aggregation for same
  period won't create duplicates due to unique constraint:
  `(event_name, period, period_start, tags)`

  This enables safe re-aggregation if processing fails.

  ## Performance Notes

  - Queries raw metrics_events table (may be large)
  - Groups by (event_name, tags)
  - Upserts results into metrics_aggregated
  - Suitable for hourly background job aggregation
  """

  require Logger
  import Ecto.Query

  alias Singularity.Schemas.Monitoring.Event
  alias Singularity.Schemas.Monitoring.AggregatedData
  alias Singularity.Repo

  @doc """
  Aggregate all events within a time period.

  Groups all events by (event_name, tags) and computes statistics.

  ## Parameters

  - `period` - `:hour` or `:day` - granularity of aggregation
  - `time_range` - `{start_datetime, end_datetime}` - time window

  ## Returns

  `{:ok, [AggregatedData.t]}` - Successfully aggregated
  `{:error, term}` - Aggregation failed

  ## Examples

      iex> now = DateTime.utc_now()
      iex> hour_ago = DateTime.add(now, -3600, :second)
      iex> EventAggregator.aggregate_by_period(:hour, {hour_ago, now})
      {:ok, [%Singularity.Metrics.AggregatedData{...}, ...]}
  """
  def aggregate_by_period(period, {start_time, end_time})
      when period in [:hour, :day] and is_struct(start_time) and is_struct(end_time) do
    try do
      # Query all events in time range
      events = fetch_events_in_range(start_time, end_time)

      # Group by (event_name, tags) and compute statistics
      grouped = group_events_by_name_and_tags(events)

      # Compute aggregations and upsert
      aggregations = compute_aggregations(grouped, period, start_time)

      case upsert_aggregations(aggregations) do
        {count, _} ->
          Logger.info("Aggregated metrics for period",
            period: period,
            start: start_time,
            end: end_time,
            event_count: length(events),
            aggregation_count: count
          )

          {:ok, aggregations}

        {:error, reason} ->
          Logger.error("Failed to upsert aggregations",
            reason: inspect(reason)
          )

          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Exception in aggregate_by_period",
          error: inspect(e),
          stacktrace: inspect(__STACKTRACE__)
        )

        {:error, :aggregation_failed}
    end
  end

  @doc """
  Aggregate events of a specific type within a time period.

  Groups events by tags and computes statistics for one event_name.

  ## Parameters

  - `event_name` - Event identifier: "llm.cost", "agent.success", etc.
  - `period` - `:hour` or `:day` - aggregation granularity
  - `time_range` - `{start_datetime, end_datetime}` - time window

  ## Returns

  `{:ok, [AggregatedData.t]}` - Successfully aggregated for this event
  `{:error, term}` - Aggregation failed

  ## Examples

      iex> now = DateTime.utc_now()
      iex> hour_ago = DateTime.add(now, -3600, :second)
      iex> EventAggregator.aggregate_events_by_name(
      ...>   "llm.cost",
      ...>   :hour,
      ...>   {hour_ago, now}
      ...> )
      {:ok, [%Singularity.Metrics.AggregatedData{event_name: "llm.cost", ...}]}
  """
  def aggregate_events_by_name(event_name, period, {start_time, end_time})
      when is_binary(event_name) and period in [:hour, :day] do
    try do
      # Query events for specific event_name
      events = fetch_events_by_name(event_name, start_time, end_time)

      # Group by tags only (event_name is fixed)
      grouped = group_events_by_tags_only(events)

      # Compute aggregations
      aggregations = compute_aggregations(grouped, period, start_time)

      case upsert_aggregations(aggregations) do
        {count, _} ->
          Logger.info("Aggregated metrics for event_name",
            event_name: event_name,
            period: period,
            event_count: length(events),
            aggregation_count: count
          )

          {:ok, aggregations}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Exception in aggregate_events_by_name",
          event_name: event_name,
          error: inspect(e)
        )

        {:error, :aggregation_failed}
    end
  end

  @doc """
  Aggregate events matching tag filters within a time period.

  Aggregates events matching specific tag criteria.

  ## Parameters

  - `tag_filters` - Map of tag constraints: %{"model" => "claude", ...}
  - `period` - `:hour` or `:day` - aggregation granularity
  - `time_range` - `{start_datetime, end_datetime}` - time window

  ## Returns

  `{:ok, [AggregatedData.t]}` - Successfully aggregated
  `{:error, term}` - Aggregation failed

  ## Examples

      iex> now = DateTime.utc_now()
      iex> hour_ago = DateTime.add(now, -3600, :second)
      iex> EventAggregator.aggregate_events_with_tags(
      ...>   %{"model" => "claude-opus"},
      ...>   :hour,
      ...>   {hour_ago, now}
      ...> )
      {:ok, [%Singularity.Metrics.AggregatedData{tags: %{"model" => "claude-opus"}, ...}]}
  """
  def aggregate_events_with_tags(tag_filters, period, {start_time, end_time})
      when is_map(tag_filters) and period in [:hour, :day] do
    try do
      # Query events matching tag filters
      events = fetch_events_with_tags(tag_filters, start_time, end_time)

      # Group by event_name (tags are filtered)
      grouped = group_events_by_name_only(events)

      # Compute aggregations (include filters in tags)
      aggregations =
        grouped
        |> compute_aggregations(period, start_time)
        |> Enum.map(&Map.put(&1, :tags, tag_filters))

      case upsert_aggregations(aggregations) do
        {count, _} ->
          {:ok, aggregations}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Exception in aggregate_events_with_tags",
          error: inspect(e)
        )

        {:error, :aggregation_failed}
    end
  end

  @doc """
  Calculate statistics from a list of measurements.

  Computes: count, sum, avg, min, max, stddev

  ## Parameters

  - `measurements` - List of numeric values: [0.01, 0.02, 0.025, ...]

  ## Returns

  Map with statistics: `%{count: int, sum: float, avg: float, min: float, max: float, stddev: float}`

  ## Examples

      iex> EventAggregator.calculate_statistics([1, 2, 3, 4, 5])
      %{count: 5, sum: 15, avg: 3.0, min: 1, max: 5, stddev: 1.414...}

      iex> EventAggregator.calculate_statistics([])
      %{count: 0, sum: 0, avg: 0, min: nil, max: nil, stddev: nil}
  """
  def calculate_statistics(measurements) when is_list(measurements) do
    case measurements do
      [] ->
        %{count: 0, sum: 0, avg: 0, min: nil, max: nil, stddev: nil}

      values when is_list(values) ->
        count = length(values)
        sum = Enum.sum(values)
        avg = sum / count
        min = Enum.min(values)
        max = Enum.max(values)
        stddev = calculate_stddev(values, avg)

        %{
          count: count,
          sum: sum,
          avg: avg,
          min: min,
          max: max,
          stddev: stddev
        }
    end
  end

  # Private helpers - Querying

  defp fetch_events_in_range(start_time, end_time) do
    from(e in Event,
      where: e.recorded_at >= ^start_time and e.recorded_at < ^end_time,
      select: e
    )
    |> Repo.all()
  end

  defp fetch_events_by_name(event_name, start_time, end_time) do
    from(e in Event,
      where: e.event_name == ^event_name and e.recorded_at >= ^start_time and e.recorded_at < ^end_time,
      select: e
    )
    |> Repo.all()
  end

  defp fetch_events_with_tags(tag_filters, start_time, end_time) do
    # Build tag filter conditions
    query = from(e in Event,
      where: e.recorded_at >= ^start_time and e.recorded_at < ^end_time
    )

    # Add JSONB matching for each tag filter
    Enum.reduce(tag_filters, query, fn {key, value}, q ->
      where(q, [e], fragment("(? ->> ?) = ?", e.tags, ^key, ^value))
    end)
    |> Repo.all()
  end

  # Private helpers - Grouping

  defp group_events_by_name_and_tags(events) do
    Enum.group_by(events, fn e ->
      {e.event_name, e.tags}
    end)
  end

  defp group_events_by_tags_only(events) do
    Enum.group_by(events, fn e -> e.tags end)
    |> Enum.map(fn {tags, events} ->
      # Re-group to maintain structure compatible with compute_aggregations
      {List.first(events).event_name, events}
    end)
  end

  defp group_events_by_name_only(events) do
    Enum.group_by(events, fn e -> e.event_name end)
  end

  # Private helpers - Aggregation

  defp compute_aggregations(grouped, period, period_start) do
    period_str = Atom.to_string(period)

    grouped
    |> Enum.map(fn
      {{event_name, tags}, events} ->
        measurements = Enum.map(events, & &1.measurement)
        stats = calculate_statistics(measurements)

        %AggregatedData{
          event_name: event_name,
          period: period_str,
          period_start: period_start,
          count: stats.count,
          sum: stats.sum,
          avg: stats.avg,
          min: stats.min,
          max: stats.max,
          stddev: stats.stddev,
          tags: tags
        }

      {event_name, events} when is_binary(event_name) ->
        measurements = Enum.map(events, & &1.measurement)
        stats = calculate_statistics(measurements)

        %AggregatedData{
          event_name: event_name,
          period: period_str,
          period_start: period_start,
          count: stats.count,
          sum: stats.sum,
          avg: stats.avg,
          min: stats.min,
          max: stats.max,
          stddev: stats.stddev,
          tags: %{}
        }
    end)
  end

  defp upsert_aggregations(aggregations) do
    # Use Repo.insert_all with on_conflict: :replace_all
    # This makes aggregation idempotent
    Repo.insert_all(
      AggregatedData,
      Enum.map(aggregations, &Map.from_struct/1),
      on_conflict: [set: [
        count: {:excluded, :count},
        sum: {:excluded, :sum},
        avg: {:excluded, :avg},
        min: {:excluded, :min},
        max: {:excluded, :max},
        stddev: {:excluded, :stddev},
        updated_at: {:excluded, :updated_at}
      ]],
      conflict_target: [:event_name, :period, :period_start, :tags]
    )
  end

  # Private helpers - Statistics

  defp calculate_stddev(values, avg) do
    case values do
      [] ->
        nil

      [_single] ->
        0.0

      values when is_list(values) and length(values) > 1 ->
        variance =
          values
          |> Enum.map(fn v -> (v - avg) ** 2 end)
          |> Enum.sum()
          |> then(&(&1 / (length(values) - 1)))

        :math.sqrt(variance)
    end
  end
end
