defmodule Singularity.Repo.Migrations.MigrateTechnologyPatternsToKnowledgeArtifacts do
  use Ecto.Migration
  import Ecto.Query
  alias Singularity.Repo

  def up do
    # Migrate existing technology_patterns to knowledge_artifacts
    # Note: usage_count/success_rate stored in content JSONB, not as columns
    # Actual columns: technology_name, technology_type (not name/type/language)
    execute """
    INSERT INTO knowledge_artifacts
      (id, artifact_type, artifact_id, content_raw, content, inserted_at, updated_at)
    SELECT
      gen_random_uuid(),
      'technology_pattern' AS artifact_type,
      LOWER(REGEXP_REPLACE(technology_name, '[^a-zA-Z0-9]+', '_', 'g')) AS artifact_id,
      -- Build raw JSON from technology_pattern fields
      jsonb_build_object(
        'name', technology_name,
        'type', technology_type,
        'version_pattern', version_pattern,
        'file_patterns', file_patterns,
        'directory_patterns', directory_patterns,
        'config_files', config_files,
        'build_command', build_command,
        'dev_command', dev_command,
        'test_command', test_command,
        'install_command', install_command,
        'output_directory', output_directory,
        'file_extensions', file_extensions,
        'import_patterns', import_patterns,
        'package_managers', package_managers,
        'confidence_weight', confidence_weight,
        'detection_count', detection_count,
        'success_rate', COALESCE(success_rate, 0.0),
        'last_detected_at', last_detected_at,
        'extended_metadata', extended_metadata,
        'tags', ARRAY[]::text[]
      )::text AS content_raw,
      -- Same JSON as JSONB
      jsonb_build_object(
        'name', technology_name,
        'type', technology_type,
        'version_pattern', version_pattern,
        'file_patterns', file_patterns,
        'directory_patterns', directory_patterns,
        'config_files', config_files,
        'build_command', build_command,
        'dev_command', dev_command,
        'test_command', test_command,
        'install_command', install_command,
        'output_directory', output_directory,
        'file_extensions', file_extensions,
        'import_patterns', import_patterns,
        'package_managers', package_managers,
        'confidence_weight', confidence_weight,
        'detection_count', detection_count,
        'success_rate', COALESCE(success_rate, 0.0),
        'last_detected_at', last_detected_at,
        'extended_metadata', extended_metadata,
        'tags', ARRAY[]::text[]
      ) AS content,
      COALESCE(created_at, NOW()) AS inserted_at,
      COALESCE(updated_at, NOW()) AS updated_at
    FROM technology_patterns
    WHERE NOT EXISTS (
      SELECT 1 FROM knowledge_artifacts ka
      WHERE ka.artifact_type = 'technology_pattern'
        AND ka.content->>'name' = technology_patterns.technology_name
    );
    """

    # Migrate existing technology_templates to knowledge_artifacts
    # Note: Merge metadata into content JSONB
    # Actual columns: identifier, category, version, template, metadata (not name, language, template_content)
    execute """
    INSERT INTO knowledge_artifacts
      (id, artifact_type, artifact_id, content_raw, content, inserted_at, updated_at)
    SELECT
      gen_random_uuid(),
      'code_template_framework' AS artifact_type,
      identifier AS artifact_id,
      -- Build raw JSON merging template with metadata
      (template || jsonb_build_object(
        'migrated_from', 'technology_templates',
        'category', category,
        'version', version,
        'source', source,
        'checksum', checksum,
        'metadata', metadata,
        'tags', ARRAY[]::text[]
      ))::text AS content_raw,
      -- Same JSON as JSONB
      template || jsonb_build_object(
        'migrated_from', 'technology_templates',
        'category', category,
        'version', version,
        'source', source,
        'checksum', checksum,
        'metadata', metadata,
        'tags', ARRAY[]::text[]
      ) AS content,
      inserted_at,
      updated_at
    FROM technology_templates
    WHERE NOT EXISTS (
      SELECT 1 FROM knowledge_artifacts ka
      WHERE ka.artifact_type = 'code_template_framework'
        AND ka.artifact_id = technology_templates.identifier
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
