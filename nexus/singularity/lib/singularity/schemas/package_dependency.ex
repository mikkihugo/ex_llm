defmodule Singularity.Schemas.PackageDependency do
  @moduledoc """
  Schema for dependency_catalog_deps table - dependencies of packages from registries

  Tracks what other packages a package depends on, with version constraints and dependency types
  (runtime, dev, peer, optional).

  ## Naming Convention
  - Module: singular (`PackageDependency` - represents ONE dependency)
  - Table: plural (`dependency_catalog_deps` - collection of dependencies)
  - This is the Elixir/Ecto standard pattern

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.PackageDependency",
    "purpose": "Dependency relationships between packages from registries",
    "role": "schema",
    "layer": "domain_services",
    "table": "dependency_catalog_deps",
    "features": ["dependency_tracking", "version_constraints", "dependency_resolution"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - package_name: Package with the dependency
    - dependency_name: The required package
    - dependency_version: Version constraint (e.g., ^1.0.0)
    - dependency_type: runtime, dev, peer, optional
    - is_optional: Whether this is optional
    - registry: npm, cargo, hex, pypi
  ```

  ### Anti-Patterns
  - ❌ DO NOT use for project dependencies - use codebase dependency catalog
  - ❌ DO NOT duplicate across registries
  - ✅ DO use for package resolution and compatibility analysis
  - ✅ DO rely on version constraints for version selection

  ### Search Keywords
  package_dependencies, dependency_resolution, version_constraints, packages,
  registry_dependencies, compatibility, dependency_tracking, package_registry
  ```
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "dependency_catalog_deps" do
    field :dependency_name, :string
    field :dependency_version, :string
    field :dependency_type, :string
    field :is_optional, :boolean

    belongs_to :package, Singularity.Schemas.DependencyCatalog,
      foreign_key: :dependency_id,
      type: :binary_id

    timestamps(type: :utc_datetime)
  end

  def changeset(dependency, attrs) do
    dependency
    |> cast(attrs, [
      :dependency_id,
      :dependency_name,
      :dependency_version,
      :dependency_type,
      :is_optional
    ])
    |> validate_required([:dependency_id, :dependency_name])
    |> validate_inclusion(:dependency_type, ["runtime", "dev", "peer", "optional"])
    |> foreign_key_constraint(:dependency_id)
  end
end
