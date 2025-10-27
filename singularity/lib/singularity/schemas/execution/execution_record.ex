defmodule Singularity.Runner.ExecutionRecord do
  @moduledoc """
  Ecto schema for runner execution records.

  Persists execution history to PostgreSQL for:
  - Execution tracking and monitoring
  - Performance analytics
  - Failure analysis
  - Audit trails

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Runner.ExecutionRecord",
    "purpose": "Records runner execution history with performance tracking and failure analysis",
    "role": "schema",
    "layer": "infrastructure",
    "table": "runner_executions",
    "relationships": {}
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - id: Primary key (binary_id)
    - execution_id: Unique execution identifier (string)
    - task_type: Type of task executed
    - task_args: JSONB with task arguments
    - status: Execution status (pending, running, completed, failed)
    - started_at: Execution start timestamp
    - completed_at: Execution end timestamp
    - result: JSONB with execution result
    - error: Error message if failed
    - execution_time_ms: Duration in milliseconds
    - metadata: JSONB for additional metadata

  indexes:
    - unique: execution_id
    - btree: started_at for time-based queries
    - btree: status for filtering

  relationships:
    belongs_to: []
    has_many: []
  ```

  ### Anti-Patterns
  - ❌ DO NOT use ExecutionRecord for agent tasks - use execution/task.ex instead
  - ❌ DO NOT bypass upsert for duplicate execution_id - it handles updates
  - ✅ DO use ExecutionRecord for Runner-specific execution tracking
  - ✅ DO use query helpers (get_history, get_stats, get_recent_by_status)

  ### Search Keywords
  execution record, runner execution, task tracking, performance analytics,
  failure analysis, audit trail, execution history, monitoring
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Singularity.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "runner_executions" do
    field :execution_id, :string
    field :task_type, :string
    field :task_args, :map, default: %{}
    field :status, :string
    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec
    field :result, :map
    field :error, :string
    field :execution_time_ms, :integer
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields [:execution_id, :task_type, :status, :started_at]
  @optional_fields [:task_args, :completed_at, :result, :error, :execution_time_ms, :metadata]

  @doc """
  Creates a changeset for execution record.
  """
  def changeset(record, attrs) do
    record
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:execution_id)
  end

  @doc """
  Inserts or updates an execution record.
  """
  def upsert(attrs) do
    case Repo.get_by(__MODULE__, execution_id: attrs.execution_id) do
      nil ->
        %__MODULE__{}
        |> changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Gets execution history with pagination.
  """
  def get_history(_opts \\ []) do
    limit = Keyword.get(_opts, :limit, 100)
    offset = Keyword.get(_opts, :offset, 0)
    status = Keyword.get(_opts, :status)
    task_type = Keyword.get(_opts, :task_type)

    query =
      from e in __MODULE__,
        order_by: [desc: e.started_at],
        limit: ^limit,
        offset: ^offset

    query = if status, do: where(query, [e], e.status == ^status), else: query
    query = if task_type, do: where(query, [e], e.task_type == ^task_type), else: query

    Repo.all(query)
  end

  @doc """
  Gets execution statistics.
  """
  def get_stats do
    total = Repo.aggregate(__MODULE__, :count, :id)

    successful =
      Repo.aggregate(
        from(e in __MODULE__, where: e.status == "completed"),
        :count,
        :id
      )

    failed =
      Repo.aggregate(
        from(e in __MODULE__, where: e.status == "failed"),
        :count,
        :id
      )

    running =
      Repo.aggregate(
        from(e in __MODULE__, where: e.status == "running"),
        :count,
        :id
      )

    avg_time =
      Repo.aggregate(
        from(e in __MODULE__, where: not is_nil(e.execution_time_ms)),
        :avg,
        :execution_time_ms
      )

    %{
      total: total,
      successful: successful,
      failed: failed,
      running: running,
      success_rate: if(total > 0, do: successful / total, else: 0),
      avg_execution_time_ms: avg_time || 0
    }
  end

  @doc """
  Gets recent executions by status.
  """
  def get_recent_by_status(status, limit \\ 10) do
    from(e in __MODULE__,
      where: e.status == ^status,
      order_by: [desc: e.started_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Gets execution by ID.
  """
  def get_by_execution_id(execution_id) do
    Repo.get_by(__MODULE__, execution_id: execution_id)
  end

  @doc """
  Updates execution status and result.
  """
  def update_status(execution_id, status, attrs \\ %{}) do
    case get_by_execution_id(execution_id) do
      nil ->
        {:error, :not_found}

      record ->
        update_attrs =
          Map.merge(attrs, %{
            status: status,
            completed_at: DateTime.utc_now()
          })

        record
        |> changeset(update_attrs)
        |> Repo.update()
    end
  end

  @doc """
  Calculates execution time and updates record.
  """
  def finalize_execution(execution_id, result) do
    case get_by_execution_id(execution_id) do
      nil ->
        {:error, :not_found}

      record ->
        execution_time = DateTime.diff(DateTime.utc_now(), record.started_at, :millisecond)

        record
        |> changeset(%{
          status: "completed",
          completed_at: DateTime.utc_now(),
          result: result,
          execution_time_ms: execution_time
        })
        |> Repo.update()
    end
  end

  @doc """
  Records execution failure.
  """
  def record_failure(execution_id, error) do
    case get_by_execution_id(execution_id) do
      nil ->
        {:error, :not_found}

      record ->
        execution_time = DateTime.diff(DateTime.utc_now(), record.started_at, :millisecond)

        record
        |> changeset(%{
          status: "failed",
          completed_at: DateTime.utc_now(),
          error: inspect(error),
          execution_time_ms: execution_time
        })
        |> Repo.update()
    end
  end
end
