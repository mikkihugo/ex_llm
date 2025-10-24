defmodule Singularity.Schemas.CodeFile do
  @moduledoc """
  Code File schema for storing parsed code with AST data

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.CodeFile",
    "purpose": "Stores parsed code files with metadata and module import relationships",
    "role": "schema",
    "layer": "infrastructure",
    "table": "code_files",
    "relationships": {
      "parent": "CodebaseRegistry - belongs via project_name field",
      "related": "CodeChunk - code chunks reference code_files"
    }
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - id: Primary key (binary_id)
    - project_name: Codebase identifier (maps to codebase_id conceptually)
    - file_path: Relative file path within project
    - language: Programming language detected
    - content: Full file content text
    - size_bytes: File size for indexing (DB column differs from field name)
    - line_count: Total lines of code
        - hash: Content hash for deduplication
    - metadata: JSONB storing functions, imports, exports, AST metadata
    - imported_module_ids: Integer array for fast GIN index queries
    - importing_module_ids: Integer array for reverse lookups

  indexes:
    - unique: [project_name, file_path]
    - gin: [imported_module_ids, importing_module_ids] for fast module lookups

  relationships:
    belongs_to: []
    has_many: []
  ```

  ### Anti-Patterns
  - ❌ DO NOT use CodeFile for code chunks - use CodeChunk schema instead
  - ❌ DO NOT store embeddings here - CodeChunk handles semantic search
  - ✅ DO use CodeFile for full file storage with module relationships
  - ✅ DO use intarray fields (imported_module_ids, importing_module_ids) for fast import graph queries

  ### Search Keywords
  code file, parsed code, ast metadata, module imports, code storage,
  project files, language detection, import graph, code indexing
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "code_files" do
    # Database column name (not codebase_id)
    field :project_name, :string
    field :file_path, :string
    field :language, :string
    field :content, :string
    # Database column name (not file_size)
    field :size_bytes, :integer
    field :line_count, :integer
    field :hash, :string

    # Metadata (stores functions, imports, exports, etc.)
    field :metadata, :map, default: %{}

    # intarray fields for fast module import lookups with GIN indexes
    field :imported_module_ids, {:array, :integer}, default: []
    field :importing_module_ids, {:array, :integer}, default: []

    timestamps()
  end

  @doc false
  def changeset(code_file, attrs) do
    code_file
    |> cast(attrs, [
      :project_name,
      :file_path,
      :language,
      :content,
      :size_bytes,
      :line_count,
      :hash,
      :metadata,
      :imported_module_ids,
      :importing_module_ids
    ])
    |> validate_required([:project_name, :file_path])
    |> unique_constraint([:project_name, :file_path])
  end
end
