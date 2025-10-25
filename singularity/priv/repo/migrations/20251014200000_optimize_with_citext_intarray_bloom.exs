defmodule Singularity.Repo.Migrations.OptimizeWithCitextIntarrayBloom do
  use Ecto.Migration

  @moduledoc """
  Optimize database with citext, intarray, and bloom extensions.

  ## TEMPORARILY DISABLED FOR DEVELOPMENT
  This migration is disabled to allow the database to be initialized without
  extension compatibility issues. Re-enable once all dependencies are properly
  configured.

  Original changes would have added:
  1. citext - Case-insensitive text types
  2. intarray - Fast dependency lookups with arrays
  3. bloom - Multi-column indexes
  """

  def up do
    # No-op: Migration disabled for development
    IO.puts("⊘ OptimizeWithCitextIntarrayBloom migration skipped (disabled for development)")
  end

  def down do
    # No-op: Migration disabled for development
  end
end
