defmodule Singularity.Repo.Migrations.CreateGitCoordinationTables do
  use Ecto.Migration

  @moduledoc """
  Creates git coordination tables for multi-agent git operations.

  Replaces git_sessions/git_commits with proper tables for agent coordination:
  - git_agent_sessions: Agent workspace tracking (replaces git_sessions)
  - git_pending_merges: Pending merge tracking
  - git_merge_history: Historical merge outcomes

  These tables enable multiple agents to coordinate git operations without conflicts,
  tracking workspaces, branches, and merge status.

  Related module:
  - Singularity.Git.GitStateStore (contains embedded schemas)
  """

  def up do
    # ===== GIT AGENT SESSIONS TABLE =====
    # Tracks agent workspaces and branches (replaces git_sessions)
    create table(:git_agent_sessions) do
      add :agent_id, :string, null: false
      add :branch, :string
      add :workspace_path, :string, null: false
      add :correlation_id, :string
      add :status, :string, null: false, default: "active"
      add :meta, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for git_agent_sessions
    create unique_index(:git_agent_sessions, [:agent_id])
    create index(:git_agent_sessions, [:branch])
    create index(:git_agent_sessions, [:status])
    create index(:git_agent_sessions, [:correlation_id])
    create index(:git_agent_sessions, [:meta], using: :gin)

    # ===== GIT PENDING MERGES TABLE =====
    # Tracks pending merges awaiting completion
    create table(:git_pending_merges) do
      add :branch, :string, null: false
      add :pr_number, :integer
      add :agent_id, :string, null: false
      add :task_id, :string
      add :correlation_id, :string
      add :meta, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for git_pending_merges
    create unique_index(:git_pending_merges, [:branch])
    create index(:git_pending_merges, [:agent_id])
    create index(:git_pending_merges, [:pr_number])
    create index(:git_pending_merges, [:task_id])
    create index(:git_pending_merges, [:correlation_id])
    create index(:git_pending_merges, [:meta], using: :gin)

    # ===== GIT MERGE HISTORY TABLE =====
    # Historical record of merge outcomes
    create table(:git_merge_history) do
      add :branch, :string, null: false
      add :agent_id, :string
      add :task_id, :string
      add :correlation_id, :string
      add :merge_commit, :string
      add :status, :string, null: false  # success, conflict, failure, etc.
      add :details, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for git_merge_history
    create index(:git_merge_history, [:branch])
    create index(:git_merge_history, [:agent_id])
    create index(:git_merge_history, [:status])
    create index(:git_merge_history, [:merge_commit])
    create index(:git_merge_history, [:inserted_at])
    create index(:git_merge_history, [:details], using: :gin)

    # Composite indexes for common queries
    create index(:git_merge_history, [:branch, :status])
    create index(:git_merge_history, [:agent_id, :inserted_at])

    # Drop old git_sessions and git_commits tables if they exist
    # Created in migration 20240101000005_create_git_and_cache_tables.exs
    execute """
    DROP TABLE IF EXISTS git_commits CASCADE
    """

    execute """
    DROP TABLE IF EXISTS git_sessions CASCADE
    """
  end

  def down do
    drop table(:git_merge_history)
    drop table(:git_pending_merges)
    drop table(:git_agent_sessions)

    # Recreate old git_sessions and git_commits tables from original migration
    create table(:git_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_type, :string, null: false
      add :branch_name, :string, null: false
      add :base_branch, :string
      add :status, :string, null: false
      add :metadata, :map, default: %{}
      timestamps()
    end

    create index(:git_sessions, [:session_type])
    create index(:git_sessions, [:status])

    create table(:git_commits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:git_sessions, type: :binary_id, on_delete: :delete_all)
      add :commit_hash, :string, null: false
      add :message, :text, null: false
      add :author, :string
      add :files_changed, {:array, :string}, default: []
      add :metadata, :map, default: %{}
      timestamps()
    end

    create index(:git_commits, [:session_id])
    create unique_index(:git_commits, [:commit_hash])
  end
end
