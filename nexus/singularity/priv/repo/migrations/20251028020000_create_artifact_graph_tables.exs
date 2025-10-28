defmodule Singularity.Repo.Migrations.CreateArtifactGraphTables do
  use Ecto.Migration

  def change do
    # Artifact nodes (vertices)
    create_if_not_exists table(:artifact_graph_nodes, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :artifact_type, :string, null: false
      add :artifact_id, :string, null: false
      add :version, :string, default: "1.0.0"
      add :node_label, :string, null: false, comment: "Mermaid node label"

      timestamps()
    end

    create index(:artifact_graph_nodes, [:artifact_type, :artifact_id], unique: true, name: "artifact_graph_nodes_unique")

    # Artifact relationships (edges)
    create_if_not_exists table(:artifact_graph_edges, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :source_id, references(:artifact_graph_nodes, type: :uuid, on_delete: :cascade), null: false
      add :target_id, references(:artifact_graph_nodes, type: :uuid, on_delete: :cascade), null: false
      add :relationship_type, :string, null: false, comment: "implements, governs, mentions, uses, related_to, etc."
      add :confidence, :float, default: 0.5, comment: "0.0 to 1.0 confidence score"
      add :bidirectional, :boolean, default: false
      add :metadata, :jsonb, default: "{}", comment: "Additional relationship metadata"

      timestamps()
    end

    create index(:artifact_graph_edges, [:source_id, :target_id, :relationship_type], unique: true, name: "artifact_graph_edges_unique")
    create index(:artifact_graph_edges, [:source_id], name: "artifact_graph_edges_source")
    create index(:artifact_graph_edges, [:target_id], name: "artifact_graph_edges_target")
    create index(:artifact_graph_edges, [:relationship_type], name: "artifact_graph_edges_type")

    # Graph view for relationship queries (materialized)
    execute("""
    CREATE OR REPLACE FUNCTION refresh_artifact_graph_nodes() RETURNS void AS $$
    BEGIN
      DELETE FROM artifact_graph_nodes;

      INSERT INTO artifact_graph_nodes (artifact_type, artifact_id, version, node_label)
      SELECT DISTINCT
        artifact_type,
        artifact_id,
        version,
        format('%s_%s', artifact_type, artifact_id)
      FROM curated_knowledge_artifacts;
    END
    $$ LANGUAGE plpgsql;
    """)
  end

  def down do
    drop_if_exists table(:artifact_graph_edges)
    drop_if_exists table(:artifact_graph_nodes)
    execute("DROP FUNCTION IF EXISTS refresh_artifact_graph_nodes()")
  end
end
