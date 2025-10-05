defmodule Singularity.Repo.Migrations.CreateCodeFiles do
  use Ecto.Migration

  def up do
    create table(:code_files) do
      add :file_path, :text, null: false
      add :content, :text
      add :language, :text
      add :metadata, :jsonb, default: "{}"
      add :repo_name, :text, null: false
      add :hash, :text
      add :size_bytes, :integer

      timestamps(type: :utc_datetime)
    end

    # Indexes for common queries
    create index(:code_files, [:repo_name])
    create index(:code_files, [:language])
    create index(:code_files, [:file_path])

    # Unique constraint: one file per repo
    create unique_index(:code_files, [:file_path, :repo_name])

    # GIN index for metadata JSONB queries
    execute "CREATE INDEX code_files_metadata_idx ON code_files USING GIN (metadata)"
  end

  def down do
    drop table(:code_files)
  end
end
