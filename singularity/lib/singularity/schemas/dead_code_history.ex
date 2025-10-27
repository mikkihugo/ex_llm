defmodule Singularity.Schemas.DeadCodeHistory do
  @moduledoc """
  Dead Code History - Track #[allow(dead_code)] annotations over time

  ## Purpose

  Stores historical data for dead code monitoring to enable:
  - Trend analysis (increasing/decreasing over time)
  - Alerting on significant changes
  - Historical comparison (what changed since last week/month)
  - Reporting for audits

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.DeadCodeHistory",
    "purpose": "Historical tracking of dead code annotations and removal",
    "role": "schema",
    "layer": "monitoring",
    "table": "dead_code_history",
    "features": ["dead_code_tracking", "trend_analysis", "historical_comparison"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - file_path: Code file with dead code
    - language: Programming language
    - dead_code_count: Number of dead code occurrences
    - total_lines: Total lines at measurement time
    - identified_date: When dead code was identified
    - removal_status: pending, in_progress, removed, ignored
  ```

  ### Anti-Patterns
  - ❌ DO NOT use to store current dead code - use analyzer output
  - ❌ DO NOT update constantly - aggregate and store snapshots
  - ✅ DO use for trend analysis over weeks/months
  - ✅ DO rely on snapshots for audit trails

  ### Search Keywords
  dead_code, code_cleanup, technical_debt, history, trending, code_quality,
  monitoring, audit, removal_tracking, code_maintenance
  ```
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "dead_code_history" do
    field :check_date, :utc_datetime_usec
    field :total_count, :integer
    field :change_from_baseline, :integer
    # ok, warn, alert, critical
    field :status, :string

    # Category breakdown
    field :struct_fields_count, :integer, default: 0
    field :future_features_count, :integer, default: 0
    field :cache_placeholders_count, :integer, default: 0
    field :helper_functions_count, :integer, default: 0
    field :other_count, :integer, default: 0

    # Metadata
    field :triggered_by, :string
    field :output, :string
    field :notes, :string

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(history, attrs) do
    history
    |> cast(attrs, [
      :check_date,
      :total_count,
      :change_from_baseline,
      :status,
      :struct_fields_count,
      :future_features_count,
      :cache_placeholders_count,
      :helper_functions_count,
      :other_count,
      :triggered_by,
      :output,
      :notes
    ])
    |> validate_required([:check_date, :total_count, :change_from_baseline, :status])
    |> validate_inclusion(:status, ["ok", "warn", "alert", "critical"])
  end

  ## Queries

  @doc """
  Get most recent check.

  ## Examples

      iex> DeadCodeHistory.latest()
      %DeadCodeHistory{total_count: 35, status: "ok"}
  """
  def latest(repo \\ Singularity.Repo) do
    from(h in __MODULE__,
      order_by: [desc: h.check_date],
      limit: 1
    )
    |> repo.one()
  end

  @doc """
  Get checks within date range.

  ## Examples

      iex> DeadCodeHistory.between(~U[2025-01-01 00:00:00Z], ~U[2025-07-01 00:00:00Z])
      [%DeadCodeHistory{}, ...]
  """
  def between(start_date, end_date, repo \\ Singularity.Repo) do
    from(h in __MODULE__,
      where: h.check_date >= ^start_date and h.check_date <= ^end_date,
      order_by: [asc: h.check_date]
    )
    |> repo.all()
  end

  @doc """
  Get trend data (count over time).

  Returns list of {date, count} tuples.

  ## Examples

      iex> DeadCodeHistory.trend(days: 30)
      [{~U[2025-01-23 09:00:00Z], 35}, {~U[2025-01-30 09:00:00Z], 37}, ...]
  """
  def trend(_opts \\ [], repo \\ Singularity.Repo) do
    # Default: 6 months
    days = Keyword.get(_opts, :days, 180)
    start_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 3600, :second)

    from(h in __MODULE__,
      where: h.check_date >= ^start_date,
      order_by: [asc: h.check_date],
      select: {h.check_date, h.total_count}
    )
    |> repo.all()
  end

  @doc """
  Calculate trend slope (linear regression).

  Returns:
  - Positive: increasing trend
  - Negative: decreasing trend
  - Near zero: stable

  ## Examples

      iex> DeadCodeHistory.trend_slope(days: 30)
      0.14  # Increasing by ~0.14 annotations per check
  """
  def trend_slope(_opts \\ [], repo \\ Singularity.Repo) do
    trend_data = trend(_opts, repo)

    case trend_data do
      [] ->
        0.0

      data ->
        # Simple linear regression
        n = length(data)
        indexed = Enum.with_index(data, 1)

        sum_x = Enum.sum(1..n)
        sum_y = Enum.sum(Enum.map(data, fn {_date, count} -> count end))
        sum_xy = Enum.sum(Enum.map(indexed, fn {{_date, count}, idx} -> idx * count end))
        sum_x2 = Enum.sum(Enum.map(1..n, fn x -> x * x end))

        # Slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x^2)
        numerator = n * sum_xy - sum_x * sum_y
        denominator = n * sum_x2 - sum_x * sum_x

        if denominator == 0 do
          0.0
        else
          numerator / denominator
        end
    end
  end

  @doc """
  Detect if trend is increasing significantly.

  ## Examples

      iex> DeadCodeHistory.trending_up?(threshold: 0.1)
      true  # Increasing by >0.1 per check
  """
  def trending_up?(_opts \\ [], repo \\ Singularity.Repo) do
    threshold = Keyword.get(_opts, :threshold, 0.1)
    slope = trend_slope(_opts, repo)
    slope > threshold
  end

  @doc """
  Get statistics summary.

  ## Examples

      iex> DeadCodeHistory.stats(days: 30)
      %{
        current: 35,
        min: 33,
        max: 37,
        avg: 35.2,
        trend: "stable",
        slope: 0.05
      }
  """
  def stats(_opts \\ [], repo \\ Singularity.Repo) do
    trend_data = trend(_opts, repo)

    case trend_data do
      [] ->
        %{current: 0, min: 0, max: 0, avg: 0.0, trend: "unknown", slope: 0.0}

      data ->
        counts = Enum.map(data, fn {_date, count} -> count end)
        current = List.last(counts)
        min = Enum.min(counts)
        max = Enum.max(counts)
        avg = Enum.sum(counts) / length(counts)
        slope = trend_slope(_opts, repo)

        trend =
          cond do
            slope > 0.1 -> "increasing"
            slope < -0.1 -> "decreasing"
            true -> "stable"
          end

        %{
          current: current,
          min: min,
          max: max,
          avg: Float.round(avg, 1),
          trend: trend,
          slope: Float.round(slope, 2)
        }
    end
  end
end
