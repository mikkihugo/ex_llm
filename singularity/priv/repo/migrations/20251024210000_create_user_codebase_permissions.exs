defmodule Singularity.Repo.Migrations.CreateUserCodebasePermissions do
  use Ecto.Migration

  def change do
    create table(:user_codebase_permissions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :string, null: false
      add :codebase_id, :string, null: false
      add :permission, :string, null: false

      timestamps()
    end

    create unique_index(
      :user_codebase_permissions,
      [:user_id, :codebase_id],
      name: :user_codebase_permissions_unique_index
    )
  end
end
