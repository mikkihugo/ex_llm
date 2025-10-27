defmodule Singularity.Schemas.Core.LLMCall do
  @moduledoc """
  Ecto schema for LLM call history and cost tracking.

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.Core.LLMCall",
    "purpose": "Tracks all LLM API calls with cost, duration, embeddings for analysis",
    "role": "schema",
    "layer": "infrastructure",
    "table": "llm_calls",
    "relationships": {}
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - id: Primary key (binary_id)
    - provider: LLM provider (claude, gemini, openai, copilot)
    - model: Specific model used
    - prompt: User prompt text
    - system_prompt: System prompt text
    - response: LLM response text
    - tokens_used: Total tokens consumed
    - cost_usd: Cost in USD
    - duration_ms: Call duration in milliseconds
    - correlation_id: For tracking related calls
    - prompt_embedding: Vector embedding of prompt
    - response_embedding: Vector embedding of response
    - called_at: Timestamp of call

  indexes:
    - btree: called_at for time-based queries
    - btree: provider, model for cost analysis
    - ivfflat: prompt_embedding, response_embedding for similarity

  relationships:
    belongs_to: []
    has_many: []
  ```

  ### Anti-Patterns
  - ❌ DO NOT call LLM APIs directly - use Singularity.LLM.Service via pgmq
  - ❌ DO NOT skip LLMCall tracking - essential for cost optimization
  - ✅ DO use LLMCall for cost analysis and prompt optimization
  - ✅ DO query by correlation_id to track multi-step agent workflows

  ### Search Keywords
  llm call, cost tracking, token usage, prompt history, llm analytics,
  cost optimization, call duration, provider metrics, embedding search
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "llm_calls" do
    field :provider, :string
    field :model, :string
    field :prompt, :string
    field :system_prompt, :string
    field :response, :string
    field :tokens_used, :integer
    field :cost_usd, :float
    field :duration_ms, :integer
    field :correlation_id, :binary_id

    # For semantic search
    field :prompt_embedding, Pgvector.Ecto.Vector
    field :response_embedding, Pgvector.Ecto.Vector

    field :called_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(call, attrs) do
    call
    |> cast(attrs, [
      :provider,
      :model,
      :prompt,
      :system_prompt,
      :response,
      :tokens_used,
      :cost_usd,
      :duration_ms,
      :correlation_id,
      :called_at
    ])
    |> validate_required([
      :provider,
      :model,
      :prompt,
      :response,
      :tokens_used,
      :cost_usd,
      :duration_ms,
      :called_at
    ])
  end
end
