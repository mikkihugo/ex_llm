defmodule Singularity.Schemas.T5EvaluationResult do
  @moduledoc """
  T5 Evaluation Result Schema

  Stores evaluation results for T5 model versions including BLEU scores,
  ROUGE scores, code quality metrics, and other evaluation data.
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
