defmodule Singularity.Schemas.PackageCodeExample do
  @moduledoc """
  Schema for dependency_catalog_examples table - code examples extracted from package documentation

  Stores real code examples from package sources (examples/ directories, official docs, tests)
  with embeddings for semantic search. These are curated examples, not user code.

  ## Naming Convention
  - Module: singular (`PackageCodeExample` - represents ONE example)
  - Table: plural (`dependency_catalog_examples` - collection of examples)
  - This is the Elixir/Ecto standard pattern

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.PackageCodeExample",
    "purpose": "Real code examples from package docs for learning and RAG",
    "role": "schema",
    "layer": "domain_services",
    "table": "dependency_catalog_examples",
    "features": ["code_examples", "semantic_search", "rag_source", "learning_material"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - package_name: Package this example uses
    - title: Example title/description
    - code: Actual code snippet
    - language: Programming language
    - explanation: Why/when to use this
    - embedding: Vector for semantic search
    - source: Where example came from (docs, examples/, tests)
  ```

  ### Anti-Patterns
  - ❌ DO NOT store user code here - only official package examples
  - ❌ DO NOT duplicate examples across packages
  - ✅ DO use for RAG (retrieval-augmented generation)
  - ✅ DO rely on semantic search for similar patterns

  ### Search Keywords
  code_examples, package_examples, learning_material, rag_source, documentation,
  code_snippets, api_usage, semantic_search, package_learning
  ```
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "dependency_catalog_examples" do
    field :title, :string
    field :code, :string
    field :language, :string
    field :explanation, :string
    field :tags, {:array, :string}
    field :code_embedding, Pgvector.Ecto.Vector
    field :example_order, :integer

    belongs_to :package, Singularity.Schemas.DependencyCatalog,
      foreign_key: :dependency_id,
      type: :binary_id

    timestamps(type: :utc_datetime)
  end

  def changeset(example, attrs) do
    example
    |> cast(attrs, [
      :dependency_id,
      :title,
      :code,
      :language,
      :explanation,
      :tags,
      :code_embedding,
      :example_order
    ])
    |> validate_required([:dependency_id, :title, :code])
    |> foreign_key_constraint(:dependency_id)
  end
end
