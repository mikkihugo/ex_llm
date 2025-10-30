defmodule Singularity.Repo.Migrations.CreateQuantumFlowBroadwayQueues do
  use Ecto.Migration

  @tables [
    :code_quality_training_jobs,
    :embedding_training_jobs,
    :architecture_learning_jobs
  ]

  def change do
    Enum.each(@tables, &create_queue_table/1)
  end

  defp create_queue_table(table) do
    create table(table) do
      add :data, :map, null: false
      add :metadata, :map, null: false, default: fragment("'{}'::jsonb")
      add :status, :string, null: false, default: "pending"
      add :failure_reason, :text
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("NOW()")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("NOW()")
    end

    create index(table, [:status, :inserted_at])
    create index(table, [:inserted_at])
  end
end
