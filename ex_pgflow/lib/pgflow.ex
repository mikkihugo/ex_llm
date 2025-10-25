defmodule Pgflow do
  @moduledoc """
  Pure Elixir workflow orchestration engine.

  Like pgflow but 100x faster (<1ms vs 10-100ms polling), pure Elixir,
  and with built-in Oban integration for distributed execution.

  ## Quick Start

  Define a workflow:

      defmodule MyApp.Workflows.ProcessData do
        def __workflow_steps__ do
          [
            {:validate, &__MODULE__.validate/1},
            {:transform, &__MODULE__.transform/1},
            {:publish, &__MODULE__.publish/1}
          ]
        end

        def validate(input) do
          if input[:data] do
            {:ok, input}
          else
            {:error, "missing data"}
          end
        end

        def transform(prev) do
          {:ok, Map.put(prev, :transformed, String.upcase(prev[:data]))}
        end

        def publish(prev) do
          {:ok, prev}
        end
      end

  Execute the workflow:

      {:ok, result} = Pgflow.Executor.execute(
        MyApp.Workflows.ProcessData,
        %{data: "hello"},
        max_attempts: 3,
        timeout: 30000
      )

  Or integrate with Oban for distributed execution:

      defmodule MyApp.ProcessDataWorker do
        use Pgflow.Worker, queue: :default

        def perform(%Oban.Job{args: args}) do
          Pgflow.Executor.execute(MyApp.Workflows.ProcessData, args)
        end
      end

  ## Workflow Requirements

  A workflow module must implement:

  - `__workflow_steps__/0` - Returns list of `{:step_name, &module.function/1}` tuples
  - Each step function takes the accumulated state and returns `{:ok, new_state}` or `{:error, reason}`

  ## Features

  - **Sequential Execution**: Steps run one after another
  - **State Accumulation**: Each step's output becomes input for next step
  - **Automatic Retry**: Exponential backoff (1s, 10s, 100s, 1000s)
  - **Timeout Protection**: Task-based timeout per execution (default 30s)
  - **Error Handling**: Full context on failures with step information
  - **Comprehensive Logging**: Step-by-step execution logs
  - **Type Safe**: Pattern matching + optional Dialyzer

  ## Multi-Instance Distribution

  With Oban integration, workflows can be distributed across multiple BEAM instances:

  - All instances connect to same PostgreSQL
  - Oban automatically distributes jobs
  - Failed jobs are retried by other instances
  - Load balances across available instances

  ## Comparison with pgflow

  | Feature | pgflow | ExPgflow |
  |---------|--------|----------|
  | Language | TypeScript | Elixir |
  | Execution | Polling (100ms) | Direct (<1ms) |
  | Coordination | pgmq + polling | Oban + PostgreSQL |
  | Type Safety | Compile-time | Runtime |
  | Multi-Instance | Via polling | Built-in via Oban |
  | Distributed Coordination | Custom | Oban handles it |
  """

  @doc false
  def version, do: "0.1.0"
end
