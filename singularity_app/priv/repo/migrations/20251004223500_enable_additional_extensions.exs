defmodule Singularity.Repo.Migrations.EnableAdditionalExtensions do
  use Ecto.Migration

  @extensions [
    "pg_stat_statements",
    "pg_trgm",
    "btree_gin",
    "btree_gist",
    "hstore",
    "citext",
    "uuid-ossp",
    "pgcrypto",
    "postgis",
    "pgrouting",
    "pg_cron",
    "pgtap"
  ]

  def up do
    Enum.each(@extensions, fn ext ->
      execute("CREATE EXTENSION IF NOT EXISTS #{ext}")
    end)
  end

  def down do
    Enum.each(@extensions, fn ext ->
      execute("DROP EXTENSION IF EXISTS #{ext}")
    end)
  end
end
