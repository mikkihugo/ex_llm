defmodule Singularity.Schemas.Execution.JobResult do
  @moduledoc """
  JobResult Schema - Stores workflow execution results for tracking and analysis.

  ## Purpose

  Tracks all workflow executions via Pgflow.Executor, enabling:
  - Result persistence and historical querying
  - Cost tracking (tokens, cents)
  - Result aggregation for CentralCloud learning
  - Performance monitoring and debugging
  - Result retrieval for agents and other components

  ## Usage

  Record a successful workflow result:

      {:ok, result} = Pgflow.Executor.execute(MyWorkflow, input)

      Singularity.Schemas.Execution.JobResult.record_success(
        workflow: "Singularity.Workflows.LlmRequest",
        instance_id: Pgflow.Instance.Registry.instance_id(),
        job_id: job.id,
        input: input,
        output: result,
        tokens_used: result["tokens_used"],
        cost_cents: result["cost_cents"],
        duration_ms: elapsed_ms
      )

  Record a failed workflow:

      Singularity.Schemas.Execution.JobResult.record_failure(
        workflow: "Singularity.Workflows.LlmRequest",
        instance_id: instance_id,
        job_id: job.id,
        input: input,
        error: inspect(reason),
        duration_ms: elapsed_ms
      )

  Query results:

      # Get all LLM request results from today
      Singularity.Repo.all(
        from jr in Singularity.Schemas.Execution.JobResult,
        where: jr.workflow == "Singularity.Workflows.LlmRequest",
        where: jr.status == "success",
        where: jr.inserted_at > ago(1, "day"),
        select: jr
      )

      # Calculate total cost
      total_cost = Singularity.Repo.one(
        from jr in Singularity.Schemas.Execution.JobResult,
        where: jr.workflow == "Singularity.Workflows.LlmRequest",
        select: sum(jr.cost_cents)
      ) || 0
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Singularity.Repo

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          workflow: String.t() | nil,
          instance_id: Ecto.UUID.t() | nil,
          job_id: integer() | nil,
          status: String.t() | nil,
          input: map() | nil,
          output: map() | nil,
          error: String.t() | nil,
          tokens_used: integer() | nil,
          cost_cents: integer() | nil,
          duration_ms: integer() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_keys_type :binary_id

  schema "job_results" do
    field :workflow, :string
    field :instance_id, :binary_id
    field :job_id, :integer

    field :status, :string, default: "pending"
    field :input, :map, default: %{}
    field :output, :map, default: %{}
    field :error, :string

    field :tokens_used, :integer, default: 0
    field :cost_cents, :integer, default: 0
    field :duration_ms, :integer

    timestamps(type: :utc_datetime_usec)
    field :completed_at, :utc_datetime_usec
  end

  @doc """
  Record successful workflow execution.

  ## Options

    - `:workflow` (required) - Workflow module name
    - `:instance_id` - Instance ID that executed the job
    - `:job_id` - Oban job ID for reference
    - `:input` - Input parameters (map)
    - `:output` - Execution result (map)
    - `:tokens_used` - LLM tokens if applicable
    - `:cost_cents` - Execution cost in cents
    - `:duration_ms` - Execution time in milliseconds
  """
  @spec record_success(keyword()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def record_success(opts) do
    workflow = Keyword.fetch!(opts, :workflow)
    instance_id = Keyword.get(opts, :instance_id)
    job_id = Keyword.get(opts, :job_id)
    input = Keyword.get(opts, :input, %{})
    output = Keyword.get(opts, :output, %{})
    tokens_used = Keyword.get(opts, :tokens_used, 0)
    cost_cents = Keyword.get(opts, :cost_cents, 0)
    duration_ms = Keyword.get(opts, :duration_ms)

    now = DateTime.utc_now()

    %__MODULE__{}
    |> changeset(%{
      workflow: workflow,
      instance_id: instance_id,
      job_id: job_id,
      status: "success",
      input: input,
      output: output,
      tokens_used: tokens_used,
      cost_cents: cost_cents,
      duration_ms: duration_ms,
      completed_at: now
    })
    |> Repo.insert()
  rescue
    KeyError -> {:error, "Missing required option: :workflow"}
  end

  @doc """
  Record failed workflow execution.

  ## Options

    - `:workflow` (required) - Workflow module name
    - `:instance_id` - Instance ID that executed the job
    - `:job_id` - Oban job ID for reference
    - `:input` - Input parameters (map)
    - `:error` - Error message or reason
    - `:duration_ms` - Execution time before failure
  """
  @spec record_failure(keyword()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def record_failure(opts) do
    workflow = Keyword.fetch!(opts, :workflow)
    instance_id = Keyword.get(opts, :instance_id)
    job_id = Keyword.get(opts, :job_id)
    input = Keyword.get(opts, :input, %{})
    error = Keyword.get(opts, :error, "Unknown error")
    duration_ms = Keyword.get(opts, :duration_ms)

    now = DateTime.utc_now()

    %__MODULE__{}
    |> changeset(%{
      workflow: workflow,
      instance_id: instance_id,
      job_id: job_id,
      status: "failed",
      input: input,
      error: error,
      duration_ms: duration_ms,
      completed_at: now
    })
    |> Repo.insert()
  rescue
    KeyError -> {:error, "Missing required option: :workflow"}
  end

  @doc """
  Record workflow timeout.

  ## Options

    - `:workflow` (required) - Workflow module name
    - `:instance_id` - Instance ID that executed the job
    - `:job_id` - Oban job ID for reference
    - `:input` - Input parameters (map)
    - `:duration_ms` - Timeout duration
  """
  @spec record_timeout(keyword()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def record_timeout(opts) do
    record_failure(
      _opts
      |> Keyword.put(:error, "Workflow execution timeout")
    )
  end

  defp changeset(job_result, attrs) do
    job_result
    |> cast(attrs, [
      :workflow,
      :instance_id,
      :job_id,
      :status,
      :input,
      :output,
      :error,
      :tokens_used,
      :cost_cents,
      :duration_ms,
      :completed_at
    ])
    |> validate_required([:workflow, :status])
    |> validate_inclusion(:status, ["success", "failed", "timeout"])
  end
end
