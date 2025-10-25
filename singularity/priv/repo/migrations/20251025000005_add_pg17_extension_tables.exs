defmodule Singularity.Repo.Migrations.AddPg17ExtensionTables do
  use Ecto.Migration

  def up do
    # =========================================================================
    # pg_net: Package registry caching for external package data
    # =========================================================================
    create_if_not_exists table(:package_registry) do
      add :ecosystem, :string, null: false, comment: "npm, cargo, hex, pypi"
      add :package_name, :string, null: false
      add :metadata, :jsonb, null: false, comment: "Full package metadata from registry"
      add :cached_at, :utc_datetime, null: false, comment: "When fetched from registry"
      add :refresh_needed, :boolean, default: false, comment: "Mark stale entries for refresh"

      timestamps(type: :utc_datetime)
    end

    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS package_registry_ecosystem_package_name_key
      ON package_registry (ecosystem, package_name)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS package_registry_refresh_needed_index
      ON package_registry (refresh_needed)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS package_registry_cached_at_index
      ON package_registry (cached_at)
    """, "")

    # =========================================================================
    # timescaledb_toolkit: Time-series metrics aggregation
    # =========================================================================
    create_if_not_exists table(:metrics_events) do
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

    execute("""
      CREATE INDEX IF NOT EXISTS metrics_events_metric_name_recorded_at_index
      ON metrics_events (metric_name, recorded_at)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS metrics_events_recorded_at_index
      ON metrics_events (recorded_at)
    """, "")

    # =========================================================================
    # lantern: Vector embeddings for pattern similarity search
    # =========================================================================
    create_if_not_exists table(:code_embeddings) do
      add :source_text, :text, null: false, comment: "Original code snippet or query"
      add :embedding, {:array, :float}, null: false, comment: "1536-dim Qodo-Embed vector"
      add :embedding_model, :string, default: "qodo-embed", comment: "Model used for embedding"
      add :cached_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS code_embeddings_source_text_key
      ON code_embeddings (source_text)
    """, "")

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

    execute("""
      CREATE INDEX IF NOT EXISTS agents_h3_cell_index
      ON agents (h3_cell)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agents_latitude_longitude_index
      ON agents (latitude, longitude)
    """, "")

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

    execute("""
      CREATE INDEX IF NOT EXISTS metrics_5min_time_index
      ON metrics_5min (time)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS metrics_1h_time_index
      ON metrics_1h (time)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS metrics_1d_time_index
      ON metrics_1d (time)
    """, "")
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
