defmodule Singularity.Schemas.T5TrainingExample do
  @moduledoc """
  T5 Training Example Schema

  Stores individual training examples for T5 fine-tuning.
  Links to code chunks and provides instruction-output pairs.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "t5_training_examples" do
    field :training_session_id, :binary_id
    field :code_chunk_id, :binary_id
    field :instruction, :string
    field :input, :string
    field :output, :string
    field :language, :string
    field :file_path, :string
    field :repo, :string
    field :quality_score, :float
    field :is_validation, :boolean, default: false
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(training_example, attrs) do
    training_example
    |> cast(attrs, [
      :training_session_id,
      :code_chunk_id,
      :instruction,
      :input,
      :output,
      :language,
      :file_path,
      :repo,
      :quality_score,
      :is_validation,
      :metadata
    ])
    |> validate_required([:training_session_id, :instruction, :input, :output, :language])
    |> validate_length(:instruction, min: 10, max: 1000)
    |> validate_length(:output, min: 20, max: 10000)
  end
end
