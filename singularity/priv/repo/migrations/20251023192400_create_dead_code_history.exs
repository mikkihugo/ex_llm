defmodule Singularity.Repo.Migrations.CreateDeadCodeHistory do
  use Ecto.Migration

  def change do
    create table(:dead_code_history, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :check_date, :utc_datetime_usec, null: false
      add :total_count, :integer, null: false
      add :change_from_baseline, :integer, null: false
      add :status, :string, null: false  # ok, warn, alert, critical

      # Category breakdown
      add :struct_fields_count, :integer, default: 0
      add :future_features_count, :integer, default: 0
      add :cache_placeholders_count, :integer, default: 0
      add :helper_functions_count, :integer, default: 0
      add :other_count, :integer, default: 0

      # Metadata
      add :triggered_by, :string  # "weekly_schedule", "manual", "release_check"
      add :output, :text  # Full script output
      add :notes, :text  # Manual notes about this check

      timestamps(type: :utc_datetime_usec)
    end

    # Index for querying by date range
    create index(:dead_code_history, [:check_date])

    # Index for trend analysis
    create index(:dead_code_history, [:total_count, :check_date])
  end
end
