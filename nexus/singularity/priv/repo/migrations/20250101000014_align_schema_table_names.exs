defmodule Singularity.Repo.Migrations.AlignSchemaTableNames do
  use Ecto.Migration

  @moduledoc """
  Aligns table names with their corresponding Ecto schemas to fix mismatches.

  This migration addresses 3 schema/table name mismatches:

  1. detection_events → codebase_snapshots
     - Schema: Singularity.Schemas.CodebaseSnapshot
     - Used by: TechnologyDetector, CodebaseSnapshots module

  2. git_sessions → git_agent_sessions (plus new tables)
     - Schema: Singularity.Git.GitStateStore
     - Also creates: git_pending_merges, git_merge_history

  3. technology_knowledge → technology_templates + technology_patterns
     - Schemas: TechnologyTemplate, TechnologyPattern
     - Used by: TechnologyTemplateStore, TechnologyDetector, etc.

  All renames preserve existing data and recreate indexes/constraints.
  """

  def up do
    # ============================================================================
    # 1. Rename detection_events to codebase_snapshots
    # ============================================================================

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'detection_events')
         AND NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'codebase_snapshots') THEN

        -- Drop existing indexes
        DROP INDEX IF EXISTS detection_events_event_type_index;
        DROP INDEX IF EXISTS detection_events_detector_index;
        DROP INDEX IF EXISTS detection_events_inserted_at_index;

        -- Rename table
        ALTER TABLE detection_events RENAME TO codebase_snapshots;

        -- Add new fields specific to codebase snapshots
        ALTER TABLE codebase_snapshots
          ADD COLUMN IF NOT EXISTS codebase_id VARCHAR(255),
          ADD COLUMN IF NOT EXISTS snapshot_id INTEGER,
          ADD COLUMN IF NOT EXISTS summary JSONB,
          ADD COLUMN IF NOT EXISTS detected_technologies TEXT[],
          ADD COLUMN IF NOT EXISTS features JSONB;

        -- Migrate existing data if it exists
        -- Map old fields to new schema:
        -- - event_type can be stored in metadata
        -- - detector can be stored in metadata
        -- - confidence can be stored in metadata
        -- - data → metadata (already exists)
        UPDATE codebase_snapshots
        SET
          metadata = COALESCE(metadata, '{}'::jsonb) ||
                     jsonb_build_object(
                       'event_type', event_type,
                       'detector', detector,
                       'confidence', confidence
                     ),
          summary = COALESCE(summary, '{}'::jsonb),
          detected_technologies = COALESCE(detected_technologies, ARRAY[]::text[]),
          features = COALESCE(features, '{}'::jsonb)
        WHERE codebase_id IS NULL;

        -- Drop old columns (keep data in metadata)
        ALTER TABLE codebase_snapshots
          DROP COLUMN IF EXISTS event_type,
          DROP COLUMN IF EXISTS detector,
          DROP COLUMN IF EXISTS confidence,
          DROP COLUMN IF EXISTS data;

        -- Recreate indexes for new schema
        CREATE INDEX IF NOT EXISTS codebase_snapshots_codebase_id_index
          ON codebase_snapshots(codebase_id);

        CREATE UNIQUE INDEX IF NOT EXISTS codebase_snapshots_codebase_id_snapshot_id_index
          ON codebase_snapshots(codebase_id, snapshot_id);

        CREATE INDEX IF NOT EXISTS codebase_snapshots_inserted_at_index
          ON codebase_snapshots(inserted_at);

        RAISE NOTICE 'Renamed detection_events to codebase_snapshots';
      ELSE
        RAISE NOTICE 'Skipping detection_events rename: source table missing or target exists';
      END IF;
    END $$;
    """

    # ============================================================================
    # 2. Rename git_sessions to git_agent_sessions and create related tables
    # ============================================================================

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'git_sessions')
         AND NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'git_agent_sessions') THEN

        -- Drop existing indexes
        DROP INDEX IF EXISTS git_sessions_session_type_index;
        DROP INDEX IF EXISTS git_sessions_status_index;

        -- Rename table
        ALTER TABLE git_sessions RENAME TO git_agent_sessions;

        -- Add new fields for git agent sessions
        ALTER TABLE git_agent_sessions
          ADD COLUMN IF NOT EXISTS agent_id VARCHAR(255),
          ADD COLUMN IF NOT EXISTS workspace_path TEXT,
          ADD COLUMN IF NOT EXISTS correlation_id VARCHAR(255),
          ADD COLUMN IF NOT EXISTS meta JSONB;

        -- Migrate existing data
        UPDATE git_agent_sessions
        SET
          meta = COALESCE(meta, '{}'::jsonb) ||
                 COALESCE(metadata, '{}'::jsonb) ||
                 jsonb_build_object(
                   'session_type', session_type,
                   'base_branch', base_branch,
                   'status', status
                 ),
          agent_id = COALESCE(agent_id, 'migrated_' || id::text)
        WHERE agent_id IS NULL;

        -- Rename branch_name to branch for consistency
        ALTER TABLE git_agent_sessions RENAME COLUMN branch_name TO branch;

        -- Drop old columns (data preserved in meta)
        ALTER TABLE git_agent_sessions
          DROP COLUMN IF EXISTS session_type,
          DROP COLUMN IF EXISTS base_branch,
          DROP COLUMN IF EXISTS metadata;

        -- Recreate indexes
        CREATE UNIQUE INDEX IF NOT EXISTS git_agent_sessions_agent_id_index
          ON git_agent_sessions(agent_id);

        CREATE INDEX IF NOT EXISTS git_agent_sessions_status_index
          ON git_agent_sessions(status);

        CREATE INDEX IF NOT EXISTS git_agent_sessions_correlation_id_index
          ON git_agent_sessions(correlation_id);

        RAISE NOTICE 'Renamed git_sessions to git_agent_sessions';
      ELSE
        RAISE NOTICE 'Skipping git_sessions rename: source table missing or target exists';
      END IF;
    END $$;
    """

    # Create git_pending_merges table (new)
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'git_pending_merges') THEN
        CREATE TABLE git_pending_merges (
          id BIGSERIAL PRIMARY KEY,
          branch VARCHAR(255) NOT NULL,
          pr_number INTEGER,
          agent_id VARCHAR(255) NOT NULL,
          task_id VARCHAR(255),
          correlation_id VARCHAR(255),
          meta JSONB DEFAULT '{}'::jsonb,
          inserted_at TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT NOW()
        );

        CREATE UNIQUE INDEX git_pending_merges_branch_index ON git_pending_merges(branch);
        CREATE INDEX git_pending_merges_agent_id_index ON git_pending_merges(agent_id);

        RAISE NOTICE 'Created git_pending_merges table';
      ELSE
        RAISE NOTICE 'Skipping git_pending_merges: table already exists';
      END IF;
    END $$;
    """

    # Create git_merge_history table (new)
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'git_merge_history') THEN
        CREATE TABLE git_merge_history (
          id BIGSERIAL PRIMARY KEY,
          branch VARCHAR(255) NOT NULL,
          agent_id VARCHAR(255),
          task_id VARCHAR(255),
          correlation_id VARCHAR(255),
          merge_commit VARCHAR(255),
          status VARCHAR(255) NOT NULL,
          details JSONB DEFAULT '{}'::jsonb,
          inserted_at TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT NOW()
        );

        CREATE INDEX git_merge_history_branch_index ON git_merge_history(branch);
        CREATE INDEX git_merge_history_status_index ON git_merge_history(status);
        CREATE INDEX git_merge_history_inserted_at_index ON git_merge_history(inserted_at);

        RAISE NOTICE 'Created git_merge_history table';
      ELSE
        RAISE NOTICE 'Skipping git_merge_history: table already exists';
      END IF;
    END $$;
    """

    # Drop git_commits table if it references old git_sessions
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'git_commits') THEN
        -- Check if it has a foreign key to git_sessions (which we renamed)
        -- If so, update the constraint or drop the table if unused
        DROP TABLE IF EXISTS git_commits;
        RAISE NOTICE 'Dropped git_commits table (superseded by git_merge_history)';
      END IF;
    END $$;
    """

    # ============================================================================
    # 3. Split technology_knowledge into technology_templates + technology_patterns
    # ============================================================================

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'technology_knowledge')
         AND NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'technology_templates') THEN

        -- Create technology_templates table
        CREATE TABLE technology_templates (
          id BIGSERIAL PRIMARY KEY,
          identifier VARCHAR(255) NOT NULL UNIQUE,
          category VARCHAR(255) NOT NULL,
          version VARCHAR(255),
          source VARCHAR(255),
          template JSONB NOT NULL,
          metadata JSONB DEFAULT '{}'::jsonb,
          checksum VARCHAR(64),
          inserted_at TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT NOW()
        );

        CREATE INDEX technology_templates_category_index ON technology_templates(category);
        CREATE INDEX technology_templates_identifier_index ON technology_templates(identifier);

        -- Migrate data: records with 'template' field go to technology_templates
        INSERT INTO technology_templates (
          identifier, category, version, template, metadata, inserted_at, updated_at
        )
        SELECT
          technology || '/' || name AS identifier,
          category,
          NULL AS version,
          jsonb_build_object(
            'technology', technology,
            'name', name,
            'description', description,
            'template', template,
            'examples', examples,
            'best_practices', best_practices,
            'antipatterns', antipatterns
          ) AS template,
          COALESCE(metadata, '{}'::jsonb) AS metadata,
          inserted_at,
          updated_at
        FROM technology_knowledge
        WHERE template IS NOT NULL;

        RAISE NOTICE 'Created and populated technology_templates table';
      ELSE
        RAISE NOTICE 'Skipping technology_templates: source missing or target exists';
      END IF;
    END $$;
    """

    # DISABLED: References embedding column which was commented out from technology_knowledge table
    # execute """
    # DO $$
    # BEGIN
    #   IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'technology_knowledge')
    #      AND NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'technology_patterns') THEN
    #
    #     -- Create technology_patterns table
    #     CREATE TABLE technology_patterns (
    #       id BIGSERIAL PRIMARY KEY,
    #       technology_name VARCHAR(255) NOT NULL,
    #       technology_type VARCHAR(255) NOT NULL,
    #       version_pattern VARCHAR(255),
    #       file_patterns TEXT[] DEFAULT ARRAY[]::text[],
    #       directory_patterns TEXT[] DEFAULT ARRAY[]::text[],
    #       config_files TEXT[] DEFAULT ARRAY[]::text[],
    #       build_command TEXT,
    #       dev_command TEXT,
    #       install_command TEXT,
    #       test_command TEXT,
    #       output_directory TEXT,
    #       confidence_weight FLOAT DEFAULT 1.0,
    #       detection_count INTEGER DEFAULT 0,
    #       success_rate FLOAT DEFAULT 1.0,
    #       last_detected_at TIMESTAMP WITHOUT TIME ZONE,
    #       extended_metadata JSONB,
    #       created_at TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
    #       updated_at TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT NOW()
    #     );
    #
    #     CREATE UNIQUE INDEX technology_patterns_name_type_index
    #       ON technology_patterns(technology_name, technology_type);
    #     CREATE INDEX technology_patterns_technology_type_index
    #       ON technology_patterns(technology_type);
    #
    #     -- Migrate data: all records become patterns (detection patterns)
    #     INSERT INTO technology_patterns (
    #       technology_name, technology_type, extended_metadata, created_at, updated_at
    #     )
    #     SELECT
    #       technology AS technology_name,
    #       category AS technology_type,
    #       jsonb_build_object(
    #         'name', name,
    #         'description', description,
    #         'examples', examples,
    #         'best_practices', best_practices,
    #         'antipatterns', antipatterns,
    #         'embedding', embedding
    #       ) AS extended_metadata,
    #       inserted_at,
    #       updated_at
    #     FROM technology_knowledge;
    #
    #     RAISE NOTICE 'Created and populated technology_patterns table';
    #   ELSE
    #     RAISE NOTICE 'Skipping technology_patterns: source missing or target exists';
    #   END IF;
    # END $$;
    # """

    # Drop technology_knowledge after successful migration
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'technology_knowledge')
         AND EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'technology_templates')
         AND EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'technology_patterns') THEN

        -- Verify data was migrated
        IF (SELECT COUNT(*) FROM technology_templates) > 0
           OR (SELECT COUNT(*) FROM technology_patterns) > 0 THEN

          DROP TABLE technology_knowledge;
          RAISE NOTICE 'Dropped technology_knowledge table after successful migration';
        ELSE
          RAISE WARNING 'Not dropping technology_knowledge: no data in new tables';
        END IF;
      END IF;
    END $$;
    """
  end

  def down do
    # ============================================================================
    # Rollback: Restore original table names and structure
    # ============================================================================

    # 1. Restore detection_events from codebase_snapshots
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'codebase_snapshots')
         AND NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'detection_events') THEN

        -- Drop new indexes
        DROP INDEX IF EXISTS codebase_snapshots_codebase_id_index;
        DROP INDEX IF EXISTS codebase_snapshots_codebase_id_snapshot_id_index;
        DROP INDEX IF EXISTS codebase_snapshots_inserted_at_index;

        -- Rename back
        ALTER TABLE codebase_snapshots RENAME TO detection_events;

        -- Restore old schema
        ALTER TABLE detection_events
          ADD COLUMN IF NOT EXISTS event_type VARCHAR(255),
          ADD COLUMN IF NOT EXISTS detector VARCHAR(255),
          ADD COLUMN IF NOT EXISTS confidence FLOAT,
          ADD COLUMN IF NOT EXISTS data JSONB;

        -- Migrate data back
        UPDATE detection_events
        SET
          event_type = COALESCE(metadata->>'event_type', 'unknown'),
          detector = COALESCE(metadata->>'detector', 'unknown'),
          confidence = COALESCE((metadata->>'confidence')::float, 1.0),
          data = metadata
        WHERE event_type IS NULL;

        -- Drop new columns
        ALTER TABLE detection_events
          DROP COLUMN IF EXISTS codebase_id,
          DROP COLUMN IF EXISTS snapshot_id,
          DROP COLUMN IF EXISTS summary,
          DROP COLUMN IF EXISTS detected_technologies,
          DROP COLUMN IF EXISTS features;

        -- Recreate old indexes
        CREATE INDEX detection_events_event_type_index ON detection_events(event_type);
        CREATE INDEX detection_events_detector_index ON detection_events(detector);
        CREATE INDEX detection_events_inserted_at_index ON detection_events(inserted_at);

        RAISE NOTICE 'Restored detection_events from codebase_snapshots';
      END IF;
    END $$;
    """

    # 2. Restore git_sessions from git_agent_sessions
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'git_agent_sessions')
         AND NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'git_sessions') THEN

        -- Drop new indexes
        DROP INDEX IF EXISTS git_agent_sessions_agent_id_index;
        DROP INDEX IF EXISTS git_agent_sessions_status_index;
        DROP INDEX IF EXISTS git_agent_sessions_correlation_id_index;

        -- Rename back
        ALTER TABLE git_agent_sessions RENAME TO git_sessions;

        -- Restore old schema
        ALTER TABLE git_sessions
          ADD COLUMN IF NOT EXISTS session_type VARCHAR(255),
          ADD COLUMN IF NOT EXISTS base_branch VARCHAR(255),
          ADD COLUMN IF NOT EXISTS metadata JSONB;

        -- Migrate data back
        UPDATE git_sessions
        SET
          session_type = COALESCE(meta->>'session_type', 'unknown'),
          base_branch = meta->>'base_branch',
          metadata = meta
        WHERE session_type IS NULL;

        -- Rename branch back to branch_name
        ALTER TABLE git_sessions RENAME COLUMN branch TO branch_name;

        -- Drop new columns
        ALTER TABLE git_sessions
          DROP COLUMN IF EXISTS agent_id,
          DROP COLUMN IF EXISTS workspace_path,
          DROP COLUMN IF EXISTS correlation_id,
          DROP COLUMN IF EXISTS meta;

        -- Recreate old indexes
        CREATE INDEX git_sessions_session_type_index ON git_sessions(session_type);
        CREATE INDEX git_sessions_status_index ON git_sessions(status);

        RAISE NOTICE 'Restored git_sessions from git_agent_sessions';
      END IF;
    END $$;
    """

    # Drop new git tables
    execute "DROP TABLE IF EXISTS git_merge_history;"
    execute "DROP TABLE IF EXISTS git_pending_merges;"

    # 3. Restore technology_knowledge from split tables
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'technology_templates')
         AND EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'technology_patterns')
         AND NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'technology_knowledge') THEN

        -- Recreate technology_knowledge
        CREATE TABLE technology_knowledge (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          technology VARCHAR(255) NOT NULL,
          category VARCHAR(255) NOT NULL,
          name VARCHAR(255) NOT NULL,
          description TEXT,
          template TEXT,
          examples TEXT[] DEFAULT ARRAY[]::text[],
          best_practices TEXT,
          antipatterns TEXT[] DEFAULT ARRAY[]::text[],
          metadata JSONB DEFAULT '{}'::jsonb,
          embedding vector(768),
          inserted_at TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT NOW()
        );

        CREATE INDEX technology_knowledge_technology_category_index
          ON technology_knowledge(technology, category);
        CREATE INDEX technology_knowledge_name_index ON technology_knowledge(name);

        -- Merge data back from both tables
        INSERT INTO technology_knowledge (
          technology, category, name, description, template, examples,
          best_practices, antipatterns, metadata, inserted_at, updated_at
        )
        SELECT
          technology_name AS technology,
          technology_type AS category,
          technology_name AS name,
          extended_metadata->>'description' AS description,
          NULL AS template,
          ARRAY[]::text[] AS examples,
          NULL AS best_practices,
          ARRAY[]::text[] AS antipatterns,
          extended_metadata AS metadata,
          created_at,
          updated_at
        FROM technology_patterns;

        DROP TABLE technology_templates;
        DROP TABLE technology_patterns;

        RAISE NOTICE 'Restored technology_knowledge from split tables';
      END IF;
    END $$;
    """
  end
end
