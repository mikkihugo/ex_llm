defmodule Singularity.Schemas.AgentMetric do
  @moduledoc """
  Agent Metrics Schema - Time-series metrics for agent performance.

  Stores aggregated performance metrics for each agent per time window,
  enabling tracking of improvement over time and feedback for evolution.

  ## Fields

  - `agent_id` - ID of the agent being tracked
  - `time_window` - TSRANGE (PostgreSQL range) representing the time period
  - `success_rate` - Percentage of successful tasks (0.0 - 1.0)
  - `avg_cost_cents` - Average cost per task in cents
  - `avg_latency_ms` - Average execution time in milliseconds
  - `patterns_used` - JSON map of patterns used during this period

  ## Indexing

  Should be queried by:
  - `agent_id` + `time_window` for historical tracking
  - `agent_id` + `inserted_at` DESC for recent metrics

  ## Example

      metric = %AgentMetric{
        agent_id: "elixir-specialist",
        time_window: {~U[2025-10-23 15:00:00Z], ~U[2025-10-23 16:00:00Z]},
        success_rate: 0.95,
        avg_cost_cents: 3.5,
        avg_latency_ms: 1200,
        patterns_used: %{"supervision" => 5, "nats" => 3}
      }
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "agent_metrics" do
    field :agent_id, :string
    field :time_window, :map  # Will be TSRANGE in PostgreSQL
    field :success_rate, :float
    field :avg_cost_cents, :float
    field :avg_latency_ms, :float
    field :patterns_used, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(agent_metric, attrs) do
    agent_metric
    |> cast(attrs, [
      :agent_id,
      :time_window,
      :success_rate,
      :avg_cost_cents,
      :avg_latency_ms,
      :patterns_used
    ])
    |> validate_required([:agent_id, :time_window, :success_rate, :avg_cost_cents, :avg_latency_ms])
    |> validate_number(:success_rate, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:avg_cost_cents, greater_than_or_equal_to: 0.0)
    |> validate_number(:avg_latency_ms, greater_than_or_equal_to: 0.0)
  end
end
