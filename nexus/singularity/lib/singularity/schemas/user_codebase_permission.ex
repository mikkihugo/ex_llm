defmodule Singularity.Schemas.UserCodebasePermission do
  @moduledoc """
  User Codebase Permission schema - Controls access to codebases

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Schemas.UserCodebasePermission",
    "purpose": "Enforce user-level access control to codebases",
    "layer": "schema",
    "status": "production"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      A[SecurityPolicy] -->|check_permissions/3| B[UserCodebasePermission]
      B -->|queries user access| C["user_codebase_permissions table"]
      C -->|returns permission level| D{action_allowed?}
      D -->|owner: all| E[✅ Allow]
      D -->|write: read/write| F[✅ Allow if action ≤ write]
      D -->|read: read only| G[✅ Allow if action = read]
      D -->|nil: not found| H[❌ Deny]
  ```

  ## Call Graph

  ```yaml
  UserCodebasePermission:
    schema:
      - changeset/2
      - validate_required: [user_id, codebase_id, permission]
    queries:
      - Singularity.Repo.get_by/2
      - Singularity.Repo.all/1
    external_callers:
      - SecurityPolicy.check_permissions/3
  ```

  ## Usage

  ```elixir
  alias Singularity.Schemas.UserCodebasePermission
  alias Singularity.Repo

  # Grant user read-only access
  Repo.insert!(%UserCodebasePermission{
    user_id: "user123",
    codebase_id: "codebase456",
    permission: :read
  })

  # Check if user has permission
  case Repo.get_by(UserCodebasePermission,
    user_id: user_id,
    codebase_id: codebase_id
  ) do
    %{permission: :owner} -> :ok  # Full access
    %{permission: :write} -> :ok  # Read/write access
    %{permission: :read} -> :ok   # Read-only access
    nil -> {:error, :unauthorized}
  end
  ```

  ## Permissions

  - `:owner` - Full access (read, write, delete, share)
  - `:write` - Read and write access
  - `:read` - Read-only access

  ## Anti-Patterns

  ❌ **DO NOT**:
  - Skip permission checks (always validate)
  - Use hardcoded user/codebase lists
  - Create permissions without schema
  - Modify permission directly without Repo
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_codebase_permissions" do
    field :user_id, :string
    field :codebase_id, :string
    field :permission, Ecto.Enum, values: [:owner, :write, :read]

    timestamps()
  end

  @doc false
  def changeset(permission, attrs) do
    permission
    |> cast(attrs, [:user_id, :codebase_id, :permission])
    |> validate_required([:user_id, :codebase_id, :permission])
    |> unique_constraint([:user_id, :codebase_id])
  end
end
