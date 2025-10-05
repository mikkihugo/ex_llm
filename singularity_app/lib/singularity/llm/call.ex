defmodule Singularity.LLM.Call do
  @moduledoc """
  Ecto schema for LLM call history and cost tracking.
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
