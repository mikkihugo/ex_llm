defmodule Singularity.Repo.Migrations.CreateTemplateUsageEvents do
  @moduledoc """
  Creates template_usage_events table for tracking template rendering success/failure.

  Previously tracked via NATS events, now persisted in PostgreSQL for:
  - Audit trail of template usage
  - Learning loop data collection
  - Performance tracking across instances
  - Cross-instance knowledge aggregation (via CentralCloud)

  Table structure:
  - template_id: VARCHAR - Template identifier
  - status: VARCHAR - 'success' or 'failure'
  - instance_id: VARCHAR - Node identifier for multi-instance tracking
  - timestamp: TIMESTAMPTZ - Event timestamp
  - metadata: JSONB - Optional event metadata
  - timestamps: created_at, updated_at for audit

  Indexes optimize:
  - Learning loop queries by template_id and created_at
  - Cleanup/archival operations by age
  - Performance analytics by time window
  """

  use Ecto.Migration

  def up do
    # Create audit table for template usage events
    create table(:template_usage_events, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :template_id, :string, null: false
      add :status, :string, null: false  # 'success' or 'failure'
      add :instance_id, :string, null: false  # Node identifier for multi-instance
      add :timestamp, :utc_datetime, null: false, default: fragment("NOW()")
      add :metadata, :jsonb  # Optional: additional event data

      timestamps()  # created_at, updated_at
    end

    # Create indexes
    create index(:template_usage_events, [:template_id])
    create index(:template_usage_events, [:instance_id])
    create index(:template_usage_events, [:status])
  end

  def down do
    drop table(:template_usage_events)
  end
end
