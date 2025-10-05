defmodule Singularity.Repo.Migrations.CreateLlmCalls do
  use Ecto.Migration

  def up do
    create table(:llm_calls, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :provider, :string, null: false
      add :model, :string, null: false
      add :prompt, :text, null: false
      add :system_prompt, :text
      add :response, :text, null: false
      add :tokens_used, :integer, null: false
      add :cost_usd, :float, null: false
      add :duration_ms, :integer, null: false
      add :correlation_id, :uuid

      # Semantic search embeddings
      add :prompt_embedding, :vector, size: 1536
      add :response_embedding, :vector, size: 1536

      add :called_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for cost tracking and analytics
    create index(:llm_calls, [:called_at])
    create index(:llm_calls, [:provider, :model])
    create index(:llm_calls, [:correlation_id])

    # Index for daily budget queries
    create index(:llm_calls, [fragment("DATE(called_at)")])

    # Vector similarity search
    create index(:llm_calls, [:prompt_embedding], using: :ivfflat, options: "vector_cosine_ops")
  end

  def down do
    drop table(:llm_calls)
  end
end
