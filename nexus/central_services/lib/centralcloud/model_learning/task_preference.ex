defmodule CentralCloud.ModelLearning.TaskPreference do
  @moduledoc """
  Task Preference Schema - Track task execution outcomes for learning.

  Records which model was selected for a task, what the outcome was,
  and quality metrics. Used to calculate win rates for task-specialized routing.

  ## Data Structure

  - `task_type` - Semantic task category (:architecture, :coding, :research, etc.)
  - `model_name` - Selected model identifier
  - `prompt` - Original user request (for semantic analysis)
  - `response_quality` - 0.0-1.0 quality score
  - `success` - Boolean: did this model succeed for this task?
  - `response_time_ms` - Latency in milliseconds
  - `instance_id` - Which Singularity instance made this decision
  - `timestamp` - When this decision was made

  ## Aggregation

  CentralCloud periodically aggregates preferences into task_metrics:
  - Count outcomes per (task, model) pair
  - Calculate win rates
  - Update confidence scores
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "task_preferences" do
    field :task_type, :string  # :architecture, :coding, :research, etc.
    field :complexity_level, :string, default: "medium"  # :simple, :medium, :complex
    field :model_name, :string
    field :provider, :string
    field :prompt, :string
    field :response_quality, :float  # 0.0-1.0
    field :success, :boolean, default: false
    field :response_time_ms, :integer
    field :instance_id, :string
    field :feedback_text, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(preference, attrs) do
    preference
    |> cast(attrs, [
      :task_type,
      :complexity_level,
      :model_name,
      :provider,
      :prompt,
      :response_quality,
      :success,
      :response_time_ms,
      :instance_id,
      :feedback_text
    ])
    |> validate_required([:task_type, :model_name, :instance_id])
    |> validate_inclusion(:complexity_level, ["simple", "medium", "complex"])
    |> validate_number(:response_quality, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
  end

  @doc """
  Create a preference record from routing event.
  """
  def from_routing_event(event) do
    %__MODULE__{}
    |> changeset(%{
      task_type: event.task_type,
      model_name: event.model_name,
      provider: event.provider,
      prompt: Map.get(event, :prompt),
      response_quality: Map.get(event, :quality_score, 0.5),
      success: Map.get(event, :success, true),
      response_time_ms: Map.get(event, :response_time_ms),
      instance_id: event.instance_id
    })
  end
end
