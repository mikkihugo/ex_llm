defmodule Singularity.Repo.Migrations.CreateGitCoordinationTables do
  use Ecto.Migration

  def change do
    create table(:git_agent_sessions) do
      add :agent_id, :text, null: false
      add :branch, :text
      add :workspace_path, :text, null: false
      add :correlation_id, :text
      add :status, :text, null: false, default: "active"
      add :meta, :map, default: %{}
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:git_agent_sessions, [:agent_id])
    create index(:git_agent_sessions, [:branch])

    create table(:git_pending_merges) do
      add :branch, :text, null: false
      add :pr_number, :integer
      add :agent_id, :text, null: false
      add :task_id, :text
      add :correlation_id, :text
      add :meta, :map, default: %{}
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:git_pending_merges, [:branch])

    create table(:git_merge_history) do
      add :branch, :text, null: false
      add :agent_id, :text
      add :task_id, :text
      add :correlation_id, :text
      add :merge_commit, :text
      add :status, :text, null: false
      add :details, :map, default: %{}
      timestamps(type: :utc_datetime_usec)
    end

    create index(:git_merge_history, [:branch])
    create index(:git_merge_history, [:correlation_id])
  end
end
