defmodule Singularity.Repo.Migrations.CreateApprovedPatternsReplica do
  @moduledoc """
  Create approved_patterns table as read-only replica from CentralCloud.

  This table receives replicated data from CentralCloud.approved_patterns via
  PostgreSQL Logical Replication. Singularity subscribes to the
  approved_patterns_pub publication from CentralCloud.

  ## Replication Flow

  ```
  CentralCloud.approved_patterns (source)
    ↓ PUBLICATION: approved_patterns_pub
  Singularity.approved_patterns (replica, read-only)
    ↑ SUBSCRIPTION: patterns_sub
  ```

  ## Columns

  - id (UUID v7) - Unique pattern identifier
  - name - Pattern name
  - ecosystem - Technology ecosystem (elixir, rust, etc.)
  - frequency - How often this pattern is used
  - confidence - Approval confidence score (0.0-1.0)
  - description - What this pattern solves
  - examples - JSONB with code examples
  - best_practices - Array of best practices
  - approved_at - When pattern was approved
  - last_synced_at - Last replication timestamp
  - instances_count - Number of instances using pattern

  ## Unique Constraint

  Patterns are unique per ecosystem: (name, ecosystem)

  ## Indexes for Fast Access

  - ecosystem (filter by technology)
  - confidence (find high-confidence patterns)
  - last_synced_at (audit trails)
  """

  use Ecto.Migration

  def change do
    create table(:approved_patterns, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v7()")
      add :name, :string, null: false
      add :ecosystem, :string, null: false
      add :frequency, :integer, default: 0
      add :confidence, :float, null: false, default: 0.0
      add :description, :text
      add :examples, :jsonb
      add :best_practices, {:array, :string}
      add :approved_at, :utc_datetime_usec
      add :last_synced_at, :utc_datetime_usec
      add :instances_count, :integer, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    # Unique constraint on pattern identity
    create unique_index(:approved_patterns, [:name, :ecosystem],
      name: "approved_patterns_name_ecosystem_unique"
    )

    # Search indexes
    create index(:approved_patterns, [:ecosystem], name: "approved_patterns_ecosystem_idx")
    create index(:approved_patterns, [:confidence], name: "approved_patterns_confidence_idx")
    create index(:approved_patterns, [:last_synced_at], name: "approved_patterns_synced_idx")
  end

  def down do
    drop table(:approved_patterns)
  end
end
