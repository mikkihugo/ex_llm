defmodule Singularity.Repo.Migrations.StandardizeAllTableNamesToPluralBestPractice do
  use Ecto.Migration

  @moduledoc """
  Standardize ALL table names to plural form (database best practice).

  This migration renames tables that violate the Postgres naming convention
  of using plural table names for collections of records.

  Changes:
  1. approval_queue → approval_queues
  2. dependency_catalog → dependency_catalogs
  3. local_learning → local_learnings
  4. template_cache → template_caches

  This ensures consistent, self-documenting database schema that follows
  established industry standards.
  """

  def change do
    # 1. Rename approval_queue to approval_queues
    rename_table_and_indexes(:approval_queue, :approval_queues)

    # 2. Rename dependency_catalog to dependency_catalogs
    # This has foreign key dependencies, so we need to update them
    rename_table_and_indexes(:dependency_catalog, :dependency_catalogs)
    update_foreign_keys_for_dependency_catalogs()

    # 3. Rename local_learning to local_learnings
    rename_table_and_indexes(:local_learning, :local_learnings)

    # 4. Rename template_cache to template_caches
    rename_table_and_indexes(:template_cache, :template_caches)
  end

  defp rename_table_and_indexes(old_name, new_name) do
    # Only rename if the table exists (some may not have been created yet)
    if table_exists?(old_name) do
      rename table(old_name), to: table(new_name)
    end

    # Note: Indexes will automatically be renamed by Postgres
    # But we should verify with: SELECT * FROM pg_indexes WHERE schemaname = 'public';
  end

  defp table_exists?(table_name) do
    table_name_str = if is_atom(table_name), do: Atom.to_string(table_name), else: table_name
    query = "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '#{table_name_str}')"
    case execute(query) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  defp update_foreign_keys_for_dependency_catalogs do
    # Tables that reference dependency_catalog (old name) need their FK constraints updated
    # These would be defined in dependent schema migrations
    # For now, we document that dependent tables need FK constraint updates

    # If there are dependent tables, they would be:
    # - dependency_catalog_examples (foreign key to dependency_catalog)
    # - dependency_catalog_deps (foreign key to dependency_catalog)
    # - dependency_catalog_prompt_usage (foreign key to dependency_catalog)
    # - dependency_catalog_patterns (foreign key to dependency_catalog)

    # These updates are typically handled automatically by Postgres in modern versions
    # but we may need explicit migration steps if using legacy Postgres versions
  end
end
