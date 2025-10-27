defmodule Singularity.Knowledge.TemplateUsageEvent do
  @moduledoc """
  Tracks template rendering success/failure for learning and analytics.

  Previously published to NATS for event streaming, now persisted in PostgreSQL
  to provide:

  1. **Audit Trail** - Complete history of template usage
  2. **Learning Loop** - TemplatePerformanceTracker analyzes success rates
  3. **Cross-Instance Learning** - CentralCloud aggregates across nodes
  4. **Performance Analytics** - Query by time window, template, status

  ## Event Lifecycle

  1. Template renders → success or failure
  2. TemplateUsagePublisher.publish_success/2 or publish_failure/2
  3. Event inserted into template_usage_events table
  4. Learning loop reads and analyzes for insights
  5. CentralCloud (optional) aggregates across instances

  ## Fields

  - `template_id` - Template identifier
  - `status` - :success or :failure
  - `instance_id` - Node identifier for multi-instance tracking
  - `timestamp` - When event occurred
  - `metadata` - Optional additional context (error details, duration, etc)

  ## Constraints

  - `status` must be :success or :failure
  - `template_id` and `instance_id` required
  - `timestamp` defaults to NOW()

  ## Querying Examples

  ```elixir
  # Recent events for template
  Repo.all(
    from e in TemplateUsageEvent,
    where: e.template_id == "my_template",
    where: e.created_at > ago(1, :day),
    order_by: [desc: :created_at]
  )

  # Success rate analysis
  Repo.all(
    from e in TemplateUsageEvent,
    where: e.template_id == "my_template",
    select: {e.status, count(e.id)},
    group_by: e.status
  )
  ```

  ## Performance

  Indexes on:
  - (template_id, created_at) - Learning loop queries
  - (created_at) - Time-based queries
  - (instance_id) - Cross-instance aggregation
  - (template_id, status) - Success rate analysis
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  schema "template_usage_events" do
    field :template_id, :string
    field :status, Ecto.Enum, values: [:success, :failure]
    field :instance_id, :string
    field :timestamp, :utc_datetime
    field :metadata, :map

    timestamps()
  end

  @doc """
  Changeset for creating a new template usage event.

  ## Examples

      iex> TemplateUsageEvent.changeset(%TemplateUsageEvent{}, %{
      ...>   template_id: "my_template",
      ...>   status: :success,
      ...>   instance_id: "node-1"
      ...> })
      #Ecto.Changeset<...>
  """
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:template_id, :status, :instance_id, :timestamp, :metadata])
    |> validate_required([:template_id, :status, :instance_id])
    |> validate_inclusion(:status, [:success, :failure])
  end

  @doc """
  Create a new event struct with defaults.

  Sets timestamp to now() if not provided.
  """
  def new(attrs) when is_map(attrs) do
    timestamp = Map.get(attrs, :timestamp, DateTime.utc_now())

    attrs
    |> Map.put(:timestamp, timestamp)
    |> then(&struct!(__MODULE__, &1))
  end
end
