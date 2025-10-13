defmodule Singularity.Repo.Migrations.AddTechnologyDetectionFields do
  use Ecto.Migration

  @moduledoc """
  Adds additional fields to technology_patterns table for enhanced detection.

  This migration extends the existing technology_patterns table with:
  - file_extensions: Array of file extensions ([".ex", ".exs"])
  - import_patterns: Array of import/use statements (["defmodule ", "use "])
  - package_managers: Array of package manager commands (["mix", "cargo"])

  These fields enable more granular technology detection with better confidence scoring.

  ## Background

  The original technology_patterns table (migration 20250101000019) had generic
  `file_patterns` for glob matching. This migration adds code-level patterns for
  stronger detection signals:

  - File extensions: Strongest signal for language detection
  - Import patterns: Code-level detection (AST not required)
  - Package managers: Ecosystem/tooling detection

  ## Example Usage

  ```elixir
  # Elixir technology pattern
  %{
    technology_name: "elixir",
    technology_type: "language",
    file_extensions: [".ex", ".exs"],
    import_patterns: ["defmodule ", "use ", "alias "],
    package_managers: ["mix"],
    file_patterns: ["lib/**/*.ex", "test/**/*.exs"],  # Existing field
    config_files: ["mix.exs", ".formatter.exs"]  # Existing field
  }
  ```

  ## Related Code

  - Rust NIF: rust/architecture_engine/src/technology_detection/mod.rs
  - Elixir wrapper: singularity_app/lib/singularity/architecture_engine.ex
  - Pattern matcher: rust/architecture_engine/src/nif.rs (detect_technologies_with_central_integration)
  """

  def up do
    # Add new fields to technology_patterns table
    alter table(:technology_patterns) do
      # File extensions for language detection (strongest signal)
      # Examples: [".ex", ".exs"], [".rs"], [".py"]
      add_if_not_exists :file_extensions, {:array, :string}, default: []

      # Import/use patterns for code-level detection (strong signal)
      # Examples: ["defmodule ", "use "], ["use ", "mod "], ["import ", "from "]
      add_if_not_exists :import_patterns, {:array, :string}, default: []

      # Package manager commands for ecosystem detection
      # Examples: ["mix"], ["cargo"], ["npm", "yarn", "pnpm"]
      add_if_not_exists :package_managers, {:array, :string}, default: []
    end

    # Add GIN indexes for array fields (enables fast ARRAY contains queries)
    create_if_not_exists index(:technology_patterns, [:file_extensions], using: :gin)
    create_if_not_exists index(:technology_patterns, [:import_patterns], using: :gin)
    create_if_not_exists index(:technology_patterns, [:package_managers], using: :gin)

    # Populate existing patterns with new fields (if any exist)
    execute """
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
    WHERE technology_type = 'language'
    """
  end

  def down do
    # Remove GIN indexes
    drop_if_exists index(:technology_patterns, [:file_extensions])
    drop_if_exists index(:technology_patterns, [:import_patterns])
    drop_if_exists index(:technology_patterns, [:package_managers])

    # Remove new fields
    alter table(:technology_patterns) do
      remove_if_exists :file_extensions, {:array, :string}
      remove_if_exists :import_patterns, {:array, :string}
      remove_if_exists :package_managers, {:array, :string}
    end
  end
end
