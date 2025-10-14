defmodule Singularity.Execution.Todos.Todo do
  @moduledoc """
  Todo schema for task management with swarm-based execution.

  ## Status Flow

  pending → assigned → in_progress → completed
                                  → failed → (retry → in_progress)
                                  → blocked

  ## Priority Levels

  - 1: Critical (do immediately)
  - 2: High (do today)
  - 3: Medium (default, do this week)
  - 4: Low (do when possible)
  - 5: Backlog (someday/maybe)

  ## Complexity Levels

  - simple: < 5 minutes, single LLM call
  - medium: 5-30 minutes, multiple steps
  - complex: > 30 minutes, multi-agent coordination
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_statuses ~w(pending assigned in_progress completed failed blocked cancelled)
  @valid_complexities ~w(simple medium complex)

  schema "todos" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "pending"
    field :priority, :integer, default: 3
    field :complexity, :string, default: "medium"
    field :assigned_agent_id, :string
    field :parent_todo_id, :binary_id
    field :depends_on_ids, {:array, :binary_id}, default: []
    field :tags, {:array, :string}, default: []
    field :context, :map, default: %{}
    field :result, :map
    field :error_message, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :failed_at, :utc_datetime
    field :embedding, Pgvector.Ecto.Vector
    field :estimated_duration_seconds, :integer
    field :actual_duration_seconds, :integer
    field :retry_count, :integer, default: 0
    field :max_retries, :integer, default: 3

    timestamps()
  end

  @doc """
  Changeset for creating a new todo.
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :title,
      :description,
      :priority,
      :complexity,
      :parent_todo_id,
      :depends_on_ids,
      :tags,
      :context,
      :estimated_duration_seconds,
      :max_retries
    ])
    |> validate_required([:title])
    |> validate_inclusion(:priority, 1..5)
    |> validate_inclusion(:complexity, @valid_complexities)
    |> validate_length(:title, min: 1, max: 500)
    |> validate_length(:description, max: 5000)
  end

  @doc """
  Changeset for updating todo status.
  """
  def status_changeset(todo, attrs) do
    todo
    |> cast(attrs, [:status, :assigned_agent_id, :started_at, :completed_at, :failed_at, :error_message, :result])
    |> validate_required([:status])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_status_transition(todo.status)
  end

  @doc """
  Changeset for updating todo with result.
  """
  def complete_changeset(todo, attrs) do
    todo
    |> cast(attrs, [:status, :result, :completed_at, :actual_duration_seconds])
    |> put_change(:status, "completed")
    |> put_change(:completed_at, DateTime.utc_now())
    |> calculate_actual_duration(todo.started_at)
  end

  @doc """
  Changeset for marking todo as failed.
  """
  def fail_changeset(todo, attrs) do
    todo
    |> cast(attrs, [:error_message, :retry_count])
    |> put_change(:status, "failed")
    |> put_change(:failed_at, DateTime.utc_now())
    |> calculate_actual_duration(todo.started_at)
    |> increment_retry_count()
  end

  @doc """
  Changeset for retrying a failed todo.
  """
  def retry_changeset(todo) do
    todo
    |> change(%{
      status: "pending",
      assigned_agent_id: nil,
      started_at: nil,
      failed_at: nil,
      error_message: nil
    })
  end

  # Private helpers

  defp validate_status_transition(changeset, current_status) do
    new_status = get_field(changeset, :status)

    valid_transition? =
      case {current_status, new_status} do
        {_, nil} -> true
        {"pending", status} when status in ["assigned", "in_progress", "cancelled"] -> true
        {"assigned", status} when status in ["in_progress", "pending", "cancelled"] -> true
        {"in_progress", status} when status in ["completed", "failed", "blocked"] -> true
        {"failed", status} when status in ["pending", "cancelled"] -> true
        {"blocked", status} when status in ["pending", "in_progress"] -> true
        {same, same} -> true
        _ -> false
      end

    if valid_transition? do
      changeset
    else
      add_error(changeset, :status, "invalid status transition from #{current_status} to #{new_status}")
    end
  end

  defp calculate_actual_duration(changeset, nil), do: changeset

  defp calculate_actual_duration(changeset, started_at) do
    ended_at = get_field(changeset, :completed_at) || get_field(changeset, :failed_at) || DateTime.utc_now()
    duration = DateTime.diff(ended_at, started_at, :second)
    put_change(changeset, :actual_duration_seconds, duration)
  end

  defp increment_retry_count(changeset) do
    current_retry = get_field(changeset, :retry_count) || 0
    put_change(changeset, :retry_count, current_retry + 1)
  end
end
