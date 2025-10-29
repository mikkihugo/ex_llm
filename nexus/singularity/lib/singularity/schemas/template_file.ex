defmodule Singularity.Schemas.TemplateFile do
  @moduledoc """
  Template File Schema - Embedded schema for JSON template file validation.

  Represents the structure of template JSON files before they're loaded into the database.
  Used for schema validation when loading templates from templates_data/ directory.

  ## Purpose

  **What it does:** Defines the expected structure of template JSON files

  **Why it exists:** Provides automatic schema validation for template files using
  JSON Schema generation instead of manual validation logic

  **Difference from Template schema:**
  - **Template** (database schema): Stores templates in PostgreSQL with embeddings
  - **TemplateFile** (embedded schema): Validates JSON files before import

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Schemas.TemplateFile",
    "purpose": "Embedded schema for template JSON file validation",
    "role": "schema",
    "layer": "schemas",
    "criticality": "MEDIUM",
    "relationships": {
      "validates": ["Template JSON files from templates_data/"],
      "used_by": ["TemplateStore", "Mix.Tasks.Templates.Validate"],
      "complements": ["Singularity.Schemas.Template (database schema)"]
    }
  }
  ```

  ## Architecture Diagram (Mermaid)

  ```mermaid
  graph LR
    A[JSON Template File] -->|validate| B[TemplateFile Schema]
    B -->|generate| C[JSON Schema]
    C -->|validates| A
    A -->|after validation| D[Template Database Schema]
  ```

  ## Anti-Patterns

  - ❌ DO NOT use Template schema for file validation (different structure)
  - ❌ DO NOT manually validate template files - use schema generation
  - ✅ DO use this for all template file validation
  - ✅ DO extend schema as template format evolves

  ## Search Keywords

  `template validation`, `template file schema`, `json template`, `template file validation`
  """

  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field(:version, :string)
    field(:type, :string)
    field(:metadata, :map)
    field(:content, :map)
    field(:quality, :map, default: %{})
  end

  @doc """
  Get the JSON Schema for template files.

  Used by validation functions to validate template JSON files.
  """
  def json_schema do
    alias Singularity.Schemas.EctoSchemaToJsonSchemaGenerator

    EctoSchemaToJsonSchemaGenerator.generate([__MODULE__])
  end
end
