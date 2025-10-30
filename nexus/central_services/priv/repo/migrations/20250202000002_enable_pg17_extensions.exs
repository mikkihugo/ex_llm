defmodule CentralCloud.Repo.Migrations.EnablePg17Extensions do
  use Ecto.Migration

  def up do
    create_extension_if_available("pgsodium")
    create_extension_if_available("pgx_ulid")
    create_extension_if_available("pgmq")
    create_extension_if_available("wal2json")
    create_extension_if_available("pg_net")
    create_extension_if_available("lantern")
    create_extension_if_available("h3")
    create_extension_if_available("timescaledb_toolkit")
  end

  def down do
    drop_extension_if_exists("timescaledb_toolkit")
    drop_extension_if_exists("h3")
    drop_extension_if_exists("lantern")
    drop_extension_if_exists("pg_net")
    drop_extension_if_exists("wal2json")
    drop_extension_if_exists("pgmq")
    drop_extension_if_exists("pgx_ulid")
    drop_extension_if_exists("pgsodium")
  end

  defp create_extension_if_available(extension) do
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = '#{extension}') THEN
        EXECUTE 'CREATE EXTENSION IF NOT EXISTS #{extension} CASCADE';
      ELSE
        RAISE NOTICE '#{extension} extension not available - skipping';
      END IF;
    END $$;
    """
  end

  defp drop_extension_if_exists(extension) do
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = '#{extension}') THEN
        EXECUTE 'DROP EXTENSION IF EXISTS #{extension} CASCADE';
      END IF;
    END $$;
    """
  end
end
