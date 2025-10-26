defmodule Nexus.Repo.Migrations.CreateOauthTokens do
  use Ecto.Migration

  def change do
    create table(:oauth_tokens) do
      add :provider, :string, null: false
      add :user_identifier, :string
      add :access_token, :text, null: false
      add :refresh_token, :text
      add :expires_at, :utc_datetime, null: false
      add :scopes, {:array, :string}, default: []
      add :token_type, :string, default: "Bearer"
      add :metadata, :map, default: %{}

      timestamps()
    end

    create unique_index(:oauth_tokens, [:provider, :user_identifier])
    create index(:oauth_tokens, [:provider])
    create index(:oauth_tokens, [:expires_at])
  end
end
