defmodule Singularity.Schemas.LanguageDetectionConfidence do
  @moduledoc """
  Schema for tracking language detection confidence values that learn and adapt over time.

  This table stores confidence scores for different language detection methods
  (extension, manifest, filename) and learns from detection accuracy to improve
  future detections.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "language_detection_confidence" do
    # Detection method: "extension", "manifest", "filename"
    field :detection_method, :string

    # Language identifier from the registry (e.g., "rust", "elixir")
    field :language_id, :string

    # Pattern used for detection (e.g., "*.rs", "Cargo.toml", "Dockerfile")
    field :pattern, :string

    # Learned confidence score (0.0 to 1.0)
    field :confidence_score, :float, default: 0.5

    # Statistics for learning
    field :detection_count, :integer, default: 0
    field :success_count, :integer, default: 0
    field :success_rate, :float, default: 0.0

    # Last time this confidence was updated
    field :last_updated_at, :utc_datetime_usec

    # Additional metadata (e.g., context about when confidence was learned)
    field :metadata, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(confidence, attrs) do
    confidence
    |> cast(attrs, [
      :detection_method,
      :language_id,
      :pattern,
      :confidence_score,
      :detection_count,
      :success_count,
      :success_rate,
      :last_updated_at,
      :metadata
    ])
    |> validate_required([
      :detection_method,
      :language_id,
      :pattern,
      :confidence_score,
      :last_updated_at
    ])
    |> validate_inclusion(:detection_method, ["extension", "manifest", "filename"])
    |> validate_number(:confidence_score,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> validate_number(:success_rate, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> unique_constraint([:detection_method, :pattern],
      name: :unique_detection_method_pattern
    )
  end

  @doc """
  Records a successful detection and updates confidence metrics.
  """
  def record_success(%__MODULE__{} = confidence) do
    new_detection_count = confidence.detection_count + 1
    new_success_count = confidence.success_count + 1
    new_success_rate = new_success_count / new_detection_count

    # Update confidence based on success rate with some smoothing
    # Weight recent performance more heavily
    smoothing_factor = 0.1

    new_confidence =
      confidence.confidence_score * (1 - smoothing_factor) +
        new_success_rate * smoothing_factor

    confidence
    |> change(%{
      detection_count: new_detection_count,
      success_count: new_success_count,
      success_rate: new_success_rate,
      confidence_score: new_confidence,
      last_updated_at: DateTime.utc_now()
    })
  end

  @doc """
  Records a failed detection and updates confidence metrics.
  """
  def record_failure(%__MODULE__{} = confidence) do
    new_detection_count = confidence.detection_count + 1
    new_success_rate = confidence.success_count / new_detection_count

    # Update confidence based on success rate with some smoothing
    smoothing_factor = 0.1

    new_confidence =
      confidence.confidence_score * (1 - smoothing_factor) +
        new_success_rate * smoothing_factor

    confidence
    |> change(%{
      detection_count: new_detection_count,
      success_rate: new_success_rate,
      confidence_score: new_confidence,
      last_updated_at: DateTime.utc_now()
    })
  end
end
