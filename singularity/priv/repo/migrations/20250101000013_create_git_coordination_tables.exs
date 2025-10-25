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
    create_if_not_exists table(:git_agent_sessions) do
      add :agent_id, :string, null: false
      add :branch, :string
      add :workspace_path, :string, null: false
      add :correlation_id, :string
      add :status, :string, null: false, default: "active"
      add :meta, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for git_agent_sessions
    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS git_agent_sessions_agent_id_key
      ON git_agent_sessions (agent_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS git_agent_sessions_branch_index
      ON git_agent_sessions (branch)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS git_agent_sessions_status_index
      ON git_agent_sessions (status)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS git_agent_sessions_correlation_id_index
      ON git_agent_sessions (correlation_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS git_agent_sessions_meta_index
      ON git_agent_sessions (meta)
    """, "")

    # ===== GIT PENDING MERGES TABLE =====
    # Tracks pending merges awaiting completion
    create_if_not_exists table(:git_pending_merges) do
      add :branch, :string, null: false
      add :pr_number, :integer
      add :agent_id, :string, null: false
      add :task_id, :string
      add :correlation_id, :string
      add :meta, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for git_pending_merges
    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS git_pending_merges_branch_key
      ON git_pending_merges (branch)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS git_pending_merges_agent_id_index
      ON git_pending_merges (agent_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS git_pending_merges_pr_number_index
      ON git_pending_merges (pr_number)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS git_pending_merges_task_id_index
      ON git_pending_merges (task_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS git_pending_merges_correlation_id_index
      ON git_pending_merges (correlation_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS git_pending_merges_meta_index
      ON git_pending_merges (meta)
    """, "")

    # ===== GIT MERGE HISTORY TABLE =====
    # Historical record of merge outcomes
    create_if_not_exists table(:git_merge_history) do
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
    execute("""
      CREATE INDEX IF NOT EXISTS git_merge_history_branch_index
      ON git_merge_history (branch)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS git_merge_history_agent_id_index
      ON git_merge_history (agent_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS git_merge_history_status_index
      ON git_merge_history (status)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS git_merge_history_merge_commit_index
      ON git_merge_history (merge_commit)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS git_merge_history_inserted_at_index
      ON git_merge_history (inserted_at)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS git_merge_history_details_index
      ON git_merge_history (details)
    """, "")

    # Composite indexes for common queries
    execute("""
      CREATE INDEX IF NOT EXISTS git_merge_history_branch_status_index
      ON git_merge_history (branch, status)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS git_merge_history_agent_id_inserted_at_index
      ON git_merge_history (agent_id, inserted_at)
    """, "")

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
    create_if_not_exists table(:git_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_type, :string, null: false
      add :branch_name, :string, null: false
      add :base_branch, :string
      add :status, :string, null: false
      add :metadata, :map, default: %{}
      timestamps()
    end

    execute("""
      CREATE INDEX IF NOT EXISTS git_sessions_session_type_index
      ON git_sessions (session_type)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS git_sessions_status_index
      ON git_sessions (status)
    """, "")

    create_if_not_exists table(:git_commits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:git_sessions, type: :binary_id, on_delete: :delete_all)
      add :commit_hash, :string, null: false
      add :message, :text, null: false
      add :author, :string
      add :files_changed, {:array, :string}, default: []
      add :metadata, :map, default: %{}
      timestamps()
    end

    execute("""
      CREATE INDEX IF NOT EXISTS git_commits_session_id_index
      ON git_commits (session_id)
    """, "")
    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS git_commits_commit_hash_key
      ON git_commits (commit_hash)
    """, "")
  end
end
