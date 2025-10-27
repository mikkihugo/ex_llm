defmodule Singularity.Repo.Migrations.CreateApprovalQueue do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:approval_queue, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # File/code change details
      add :file_path, :text, null: false
      add :diff, :text, null: false
      add :description, :text  # Optional: what the change does
      add :agent_id, :string    # Which agent requested this

      # Approval workflow
      add :status, :string, null: false, default: "pending"  # pending/approved/rejected
      add :priority, :integer, default: 0  # For future prioritization

      # Google Chat integration
      add :chat_space_id, :string   # Google Chat space ID
      add :chat_message_id, :string  # Message ID for updating buttons
      add :chat_thread_key, :string  # Thread key for grouping related changes

      # Audit trail
      add :requested_by, :string  # User who initiated the agent task
      add :approved_by, :string   # User who clicked approve/reject
      add :approved_at, :utc_datetime_usec
      add :rejection_reason, :text

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for performance
    execute("""
      CREATE INDEX IF NOT EXISTS approval_queue_status_index
      ON approval_queue (status)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS approval_queue_agent_id_index
      ON approval_queue (agent_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS approval_queue_chat_message_id_index
      ON approval_queue (chat_message_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS approval_queue_inserted_at_index
      ON approval_queue (inserted_at)
    """, "")

    # Composite index for queue queries
    execute("""
      CREATE INDEX IF NOT EXISTS approval_queue_status_inserted_at_index
      ON approval_queue (status, inserted_at)
    """, "")
  end
end
