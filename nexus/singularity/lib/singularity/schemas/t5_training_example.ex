defmodule Singularity.Schemas.T5TrainingExample do
  @moduledoc """
  T5 Training Example Schema

  Stores individual training examples for T5 fine-tuning.
  Links to code chunks and provides instruction-output pairs.

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.T5TrainingExample",
    "purpose": "Training examples for T5 fine-tuning (instruction-output pairs)",
    "role": "schema",
    "layer": "ml_training",
    "table": "t5_training_examples",
    "features": ["training_data", "instruction_tuning", "example_tracking"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - training_session_id: Reference to training session
    - code_chunk_id: Source code being trained on
    - instruction: Task/instruction for model
    - output: Expected model output
    - difficulty: Example difficulty level
    - source: Where example came from
  ```

  ### Anti-Patterns
  - ❌ DO NOT use for evaluation - use T5EvaluationResult
  - ❌ DO NOT duplicate examples across sessions
  - ✅ DO use for building high-quality training datasets
  - ✅ DO rely on difficulty for curriculum learning

  ### Search Keywords
  training_examples, training_data, instruction_tuning, t5_training, machine_learning,
  dataset, fine_tuning, training_pairs
  ```
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
