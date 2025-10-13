-- Migration: Add technology detection fields
-- Generated from: 20250113000001_add_technology_detection_fields.exs

-- Add new columns to technology_patterns table
ALTER TABLE technology_patterns
  ADD COLUMN IF NOT EXISTS file_extensions TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS import_patterns TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS package_managers TEXT[] DEFAULT '{}';

-- Create GIN indexes for array fields
CREATE INDEX IF NOT EXISTS technology_patterns_file_extensions_index
  ON technology_patterns USING gin(file_extensions);

CREATE INDEX IF NOT EXISTS technology_patterns_import_patterns_index
  ON technology_patterns USING gin(import_patterns);

CREATE INDEX IF NOT EXISTS technology_patterns_package_managers_index
  ON technology_patterns USING gin(package_managers);

-- Populate existing patterns with new fields
UPDATE technology_patterns
SET
  file_extensions = CASE technology_name
    WHEN 'elixir' THEN ARRAY['.ex', '.exs']
    WHEN 'rust' THEN ARRAY['.rs']
    WHEN 'javascript' THEN ARRAY['.js', '.jsx', '.mjs']
    WHEN 'typescript' THEN ARRAY['.ts', '.tsx']
    WHEN 'python' THEN ARRAY['.py']
    WHEN 'go' THEN ARRAY['.go']
    WHEN 'java' THEN ARRAY['.java']
    WHEN 'ruby' THEN ARRAY['.rb']
    WHEN 'c' THEN ARRAY['.c', '.h']
    WHEN 'cpp' THEN ARRAY['.cpp', '.hpp', '.cc', '.cxx']
    ELSE file_extensions
  END,
  import_patterns = CASE technology_name
    WHEN 'elixir' THEN ARRAY['defmodule ', 'use ', 'alias ', 'import ']
    WHEN 'rust' THEN ARRAY['use ', 'mod ', 'extern crate ']
    WHEN 'javascript' THEN ARRAY['import ', 'export ', 'require(']
    WHEN 'typescript' THEN ARRAY['import ', 'export ', 'interface ', 'type ']
    WHEN 'python' THEN ARRAY['import ', 'from ', 'def ', 'class ']
    WHEN 'go' THEN ARRAY['package ', 'import ', 'func ']
    WHEN 'java' THEN ARRAY['import ', 'package ', 'class ', 'interface ']
    WHEN 'ruby' THEN ARRAY['require ', 'class ', 'module ', 'def ']
    ELSE import_patterns
  END,
  package_managers = CASE technology_name
    WHEN 'elixir' THEN ARRAY['mix']
    WHEN 'rust' THEN ARRAY['cargo']
    WHEN 'javascript' THEN ARRAY['npm', 'yarn', 'pnpm', 'bun']
    WHEN 'typescript' THEN ARRAY['npm', 'yarn', 'pnpm', 'bun']
    WHEN 'python' THEN ARRAY['pip', 'poetry', 'pipenv']
    WHEN 'go' THEN ARRAY['go']
    WHEN 'java' THEN ARRAY['maven', 'gradle']
    WHEN 'ruby' THEN ARRAY['gem', 'bundle']
    ELSE package_managers
  END
WHERE technology_type = 'language';

-- Insert migration version to schema_migrations table
INSERT INTO schema_migrations (version, inserted_at)
VALUES (20250113000001, NOW())
ON CONFLICT (version) DO NOTHING;

SELECT 'Migration completed successfully!' AS status;
