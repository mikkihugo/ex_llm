defmodule Singularity.Repo.Migrations.AddPg17ExtensionTables do
  use Ecto.Migration

  def up do
    # =========================================================================
    # pg_net: Package registry caching for external package data
    # =========================================================================
    create table(:package_registry) do
      add :ecosystem, :string, null: false, comment: "npm, cargo, hex, pypi"
      add :package_name, :string, null: false
      add :metadata, :jsonb, null: false, comment: "Full package metadata from registry"
      add :cached_at, :utc_datetime, null: false, comment: "When fetched from registry"
      add :refresh_needed, :boolean, default: false, comment: "Mark stale entries for refresh"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:package_registry, [:ecosystem, :package_name])
    create index(:package_registry, [:refresh_needed])
    create index(:package_registry, [:cached_at])

    # =========================================================================
    # timescaledb_toolkit: Time-series metrics aggregation
    # =========================================================================
    create table(:metrics_events) do
      add :metric_name, :string, null: false, comment: "agent_cpu, pattern_learned, etc"
      add :value, :float, null: false, comment: "Metric value"
      add :labels, :jsonb, null: false, comment: "agent_id, pattern_type, etc"
      add :recorded_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    # Create hypertable for time-series (automatic time partitioning)
    execute("""
      SELECT create_hypertable('metrics_events', 'recorded_at', if_not_exists => true)
    """)

    create index(:metrics_events, [:metric_name, :recorded_at])
    create index(:metrics_events, [:recorded_at])

    # =========================================================================
    # lantern: Vector embeddings for pattern similarity search
    # =========================================================================
    create table(:code_embeddings) do
      add :source_text, :text, null: false, comment: "Original code snippet or query"
      add :embedding, {:array, :float}, null: false, comment: "1536-dim Qodo-Embed vector"
      add :embedding_model, :string, default: "qodo-embed", comment: "Model used for embedding"
      add :cached_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:code_embeddings, [:source_text])

    # Create Lantern index on embeddings
    execute("""
      CREATE INDEX idx_code_embeddings_lantern
      ON code_embeddings USING lantern (embedding)
      WITH (dim = 1536, metric_kind = 'l2')
    """)

    # =========================================================================
    # h3: Geospatial indexing for agent clustering
    # =========================================================================
    alter table(:agents) do
      add :latitude, :float, comment: "Agent location latitude"
      add :longitude, :float, comment: "Agent location longitude"
      add :h3_cell, :string, comment: "H3 hexagonal cell ID (resolution 6)"
      add :location_updated_at, :utc_datetime, comment: "When location was last set"
    end

    create index(:agents, [:h3_cell])
    create index(:agents, [:latitude, :longitude])

    # =========================================================================
    # wal2json: Change Data Capture schema
    # =========================================================================
    # Note: Logical replication slot and WAL decoding configured at extension load time
    # No additional schema needed - uses existing tables with CDC trigger

    # =========================================================================
    # Continuous aggregates (timescaledb_toolkit)
    # =========================================================================
    # 5-minute aggregates of key metrics
    execute("""
      CREATE MATERIALIZED VIEW metrics_5min AS
      SELECT
        time_bucket('5 minutes', recorded_at) as time,
        metric_name,
        labels->>'agent_id' as agent_id,
        avg(value) as avg_value,
        min(value) as min_value,
        max(value) as max_value,
        count(*) as sample_count
      FROM metrics_events
      GROUP BY time, metric_name, labels->>'agent_id'
      WITH DATA
    """)

    # Hourly aggregates
    execute("""
      CREATE MATERIALIZED VIEW metrics_1h AS
      SELECT
        time_bucket('1 hour', recorded_at) as time,
        metric_name,
        labels->>'agent_id' as agent_id,
        avg(value) as avg_value,
        min(value) as min_value,
        max(value) as max_value,
        count(*) as sample_count
      FROM metrics_events
      GROUP BY time, metric_name, labels->>'agent_id'
      WITH DATA
    """)

    # Daily aggregates
    execute("""
      CREATE MATERIALIZED VIEW metrics_1d AS
      SELECT
        time_bucket('1 day', recorded_at) as time,
        metric_name,
        labels->>'agent_id' as agent_id,
        avg(value) as avg_value,
        min(value) as min_value,
        max(value) as max_value,
        count(*) as sample_count
      FROM metrics_events
      GROUP BY time, metric_name, labels->>'agent_id'
      WITH DATA
    """)

    create index(:metrics_5min, [:time])
    create index(:metrics_1h, [:time])
    create index(:metrics_1d, [:time])
  end

  def down do
    # Drop continuous aggregates
    drop_if_exists("""
      DROP MATERIALIZED VIEW IF EXISTS metrics_1d CASCADE
    """)

    drop_if_exists("""
      DROP MATERIALIZED VIEW IF EXISTS metrics_1h CASCADE
    """)

    drop_if_exists("""
      DROP MATERIALIZED VIEW IF EXISTS metrics_5min CASCADE
    """)

    # Drop h3 columns from agents
    alter table(:agents) do
      remove :location_updated_at
      remove :h3_cell
      remove :longitude
      remove :latitude
    end

    # Drop code_embeddings table (with Lantern index)
    drop table(:code_embeddings)

    # Drop metrics_events hypertable
    drop table(:metrics_events)

    # Drop package_registry table
    drop table(:package_registry)
  end
end
