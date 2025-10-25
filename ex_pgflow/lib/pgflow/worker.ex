defmodule Pgflow.Worker do
  @moduledoc """
  Oban.Worker integration for distributed workflow execution.

  Pgflow.Worker wraps Oban.Worker to provide:
  - Job persistence via PostgreSQL
  - Automatic distribution across BEAM instances
  - Automatic retry on failure
  - Load balancing
  - Instance-aware execution

  ## Usage

  Create a worker module:

      defmodule MyApp.MyWorkflowWorker do
        use Pgflow.Worker, queue: :default

        def perform(%Oban.Job{args: args}) do
          Pgflow.Executor.execute(MyApp.Workflows.MyWorkflow, args)
        end
      end

  Enqueue a job:

      {:ok, job} = MyApp.MyWorkflowWorker.new(%{data: "hello"})
        |> Oban.insert()

      # Or with options
      {:ok, job} = MyApp.MyWorkflowWorker.new(
        %{data: "hello"},
        priority: 10,
        max_attempts: 5
      ) |> Oban.insert()

  ## How It Works

  1. Worker.new/2 creates an Oban.Job with the args
  2. Oban.insert/1 persists job to PostgreSQL oban_jobs table
  3. Oban scheduler picks up available jobs
  4. Any available BEAM instance claims the job (via reserved_by column)
  5. Worker.perform/1 executes the job on that instance
  6. Result is persisted (success or failure)
  7. On failure, Oban retries according to max_attempts

  ## Multi-Instance Distribution

  When multiple instances are running:

      Instance A ─┐
      Instance B ──> PostgreSQL (oban_jobs)
      Instance C ─┘

  Oban automatically:
  - Distributes jobs across instances
  - Balances load (round-robin)
  - Reassigns jobs if instance crashes (stale timeout)
  - Retries on failure

  ## Configuration

  In your config/config.exs:

      config :my_app, Oban,
        engine: Oban.Engines.Basic,
        queues: [
          default: [limit: 10, paused: false],    # 10 concurrent jobs per instance
          priority: [limit: 5, paused: false],
          background: [limit: 3, paused: false]
        ],
        repo: MyApp.Repo,
        plugins: [
          Oban.Plugins.Repeater,     # Re-enqueue on timeout
          Oban.Plugins.Cron          # Schedule periodic jobs
        ]

  ## Retry Strategy

  Pgflow.Executor handles retry within a single job:
  - Attempt 1 (immediate)
  - Attempt 2 (after 10 seconds)
  - Attempt 3 (after 100 seconds)

  Then Oban retries the entire job (from Attempt 1):
  - Retry 1 (Oban backoff)
  - Retry 2 (Oban backoff)
  - etc (up to max_attempts)

  Combined effect: Multiple layers of retry protection

  ## Example with Multi-Instance Setup

  Worker definition:

      defmodule MyApp.LlmRequestWorker do
        use Pgflow.Worker, queue: :default, max_attempts: 3

        def perform(%Oban.Job{args: args}) do
          Pgflow.Executor.execute(MyApp.Workflows.LlmRequest, args, max_attempts: 3)
        end
      end

  Enqueue:

      {:ok, _} = MyApp.LlmRequestWorker.new(%{
        request_id: "550e8400-e29b-41d4-a716-446655440000",
        task_type: "architect",
        messages: [%{"role" => "user", "content" => "Design..."}]
      }) |> Oban.insert()

  Execution:

      Instance A: Claims job → Pgflow.Executor.execute/3 (Attempt 1)
                  │
                  ├─ Step 1 → ✓
                  ├─ Step 2 → ✓
                  ├─ Step 3 → ✓
                  └─ Success!

      Or if Instance A crashes:

      Instance A: Crashes while running job
      (PostgreSQL marks as stale after 5 min)
      Instance B: Claims job → Pgflow.Executor.execute/3 (Attempt 1)
                  │
                  ├─ Step 1 → ✓
                  ├─ Step 2 → ✓
                  ├─ Step 3 → ✓
                  └─ Success! (may be duplicate work, but guaranteed completion)
  """

  defmacro __using__(opts) do
    quote do
      use Oban.Worker,
        queue: unquote(Keyword.get(opts, :queue, :default)),
        max_attempts: unquote(Keyword.get(opts, :max_attempts, 3))

      @doc """
      Create a new workflow job.

      Usage:

          {:ok, job} = MyWorker.new(%{data: "input"}) |> Oban.insert()

      With options:

          {:ok, job} = MyWorker.new(
            %{data: "input"},
            priority: 10,
            max_attempts: 5,
            schedule_in: 60  # Schedule for 60 seconds from now
          ) |> Oban.insert()
      """
      def new(args, opts \\ []) do
        __MODULE__.new(args, opts)
      end
    end
  end
end
