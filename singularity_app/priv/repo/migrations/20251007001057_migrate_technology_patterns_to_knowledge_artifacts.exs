defmodule Singularity.Repo.Migrations.MigrateTechnologyPatternsToKnowledgeArtifacts do
  use Ecto.Migration
  import Ecto.Query
  alias Singularity.Repo

  def up do
    # Migrate existing technology_patterns to knowledge_artifacts
    # Note: usage_count/success_rate stored in content JSONB, not as columns
    execute """
    INSERT INTO knowledge_artifacts
      (id, artifact_type, artifact_id, content_raw, content, embedding, inserted_at, updated_at)
    SELECT
      gen_random_uuid(),
      'technology_pattern' AS artifact_type,
      LOWER(REGEXP_REPLACE(name, '[^a-zA-Z0-9]+', '_', 'g')) AS artifact_id,
      -- Build raw JSON from technology_pattern fields
      jsonb_build_object(
        'name', name,
        'type', type,
        'language', language,
        'detector_signatures', detector_signatures,
        'file_patterns', file_patterns,
        'config_files', config_files,
        'build_command', build_command,
        'dev_command', dev_command,
        'test_command', test_command,
        'install_command', install_command,
        'detection_count', detection_count,
        'last_detected_at', last_detected_at,
        'success_rate', COALESCE(success_rate, 0.0),
        'tags', ARRAY[]::text[]
      )::text AS content_raw,
      -- Same JSON as JSONB
      jsonb_build_object(
        'name', name,
        'type', type,
        'language', language,
        'detector_signatures', detector_signatures,
        'file_patterns', file_patterns,
        'config_files', config_files,
        'build_command', build_command,
        'dev_command', dev_command,
        'test_command', test_command,
        'install_command', install_command,
        'detection_count', detection_count,
        'last_detected_at', last_detected_at,
        'success_rate', COALESCE(success_rate, 0.0),
        'tags', ARRAY[]::text[]
      ) AS content,
      pattern_embedding AS embedding,
      COALESCE(inserted_at, NOW()) AS inserted_at,
      COALESCE(updated_at, NOW()) AS updated_at
    FROM technology_patterns
    WHERE NOT EXISTS (
      SELECT 1 FROM knowledge_artifacts ka
      WHERE ka.artifact_type = 'technology_pattern'
        AND ka.content->>'name' = technology_patterns.name
    );
    """

    # Migrate existing technology_templates to knowledge_artifacts
    # Note: Merge metadata into content JSONB
    execute """
    INSERT INTO knowledge_artifacts
      (id, artifact_type, artifact_id, content_raw, content, embedding, inserted_at, updated_at)
    SELECT
      gen_random_uuid(),
      'code_template_framework' AS artifact_type,
      LOWER(REGEXP_REPLACE(name, '[^a-zA-Z0-9]+', '_', 'g')) AS artifact_id,
      -- Build raw JSON merging template_content with metadata
      (template_content || jsonb_build_object(
        'migrated_from', 'technology_templates',
        'category', category,
        'version', version,
        'language', COALESCE(language, 'unknown'),
        'tags', ARRAY[]::text[]
      ))::text AS content_raw,
      -- Same JSON as JSONB
      template_content || jsonb_build_object(
        'migrated_from', 'technology_templates',
        'category', category,
        'version', version,
        'language', COALESCE(language, 'unknown'),
        'tags', ARRAY[]::text[]
      ) AS content,
      NULL AS embedding,
      COALESCE(inserted_at, NOW()) AS inserted_at,
      COALESCE(updated_at, NOW()) AS updated_at
    FROM technology_templates
    WHERE NOT EXISTS (
      SELECT 1 FROM knowledge_artifacts ka
      WHERE ka.artifact_type = 'code_template_framework'
        AND ka.content->>'name' = technology_templates.name
    );
    """
    
    # Don't drop tables yet - keep for reference during transition
    # execute "DROP TABLE IF EXISTS technology_patterns CASCADE;"
    # execute "DROP TABLE IF EXISTS technology_templates CASCADE;"
  end

  def down do
    # Remove migrated artifacts
    execute """
    DELETE FROM knowledge_artifacts 
    WHERE metadata->>'migrated_from' IN ('technology_patterns', 'technology_templates');
    """
  end
end
