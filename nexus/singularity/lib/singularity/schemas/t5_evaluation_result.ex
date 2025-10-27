defmodule Singularity.Schemas.T5EvaluationResult do
  @moduledoc """
  T5 Evaluation Result Schema

  Stores evaluation results for T5 model versions including BLEU scores,
  ROUGE scores, code quality metrics, and other evaluation data.

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.T5EvaluationResult",
    "purpose": "Evaluation metrics for T5 model versions (BLEU, ROUGE, quality)",
    "role": "schema",
    "layer": "ml_training",
    "table": "t5_evaluation_results",
    "features": ["model_evaluation", "metric_tracking", "quality_assessment"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - model_version_id: Reference to T5 model version
    - bleu_score: BLEU metric for translation quality
    - rouge_score: ROUGE metric for summarization
    - code_quality_score: Custom code quality metric
    - evaluation_date: When evaluation was run
  ```

  ### Anti-Patterns
  - ❌ DO NOT use for training data - use T5TrainingExample
  - ❌ DO NOT duplicate evaluation runs
  - ✅ DO use for tracking model performance over time
  - ✅ DO rely on scores for model selection

  ### Search Keywords
  evaluation, metrics, bleu_score, rouge_score, quality_assessment, model_evaluation,
  t5_model, machine_learning, evaluation_results
  ```
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "t5_evaluation_results" do
    field :model_version_id, :binary_id
    field :test_dataset_id, :binary_id
    field :bleu_score, :float
    field :rouge_score, :float
    field :exact_match, :float
    field :code_quality_score, :float
    field :syntax_correctness, :float
    field :semantic_similarity, :float
    field :evaluation_metrics, :map, default: %{}
    field :sample_predictions, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(evaluation_result, attrs) do
    evaluation_result
    |> cast(attrs, [
      :model_version_id,
      :test_dataset_id,
      :bleu_score,
      :rouge_score,
      :exact_match,
      :code_quality_score,
      :syntax_correctness,
      :semantic_similarity,
      :evaluation_metrics,
      :sample_predictions
    ])
    |> validate_required([:model_version_id])
    |> validate_number(:bleu_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
    |> validate_number(:rouge_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
    |> validate_number(:exact_match, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
    |> validate_number(:code_quality_score,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 100.0
    )
    |> validate_number(:syntax_correctness,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 100.0
    )
    |> validate_number(:semantic_similarity,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 100.0
    )
  end
end
