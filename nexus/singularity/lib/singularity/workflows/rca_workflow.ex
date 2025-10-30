defmodule Singularity.Workflows.RcaWorkflow do
  @moduledoc """
  RCA-Enhanced Workflow Base - Pgflow workflows with automatic RCA tracking

  Extends BaseWorkflow to automatically track workflow execution via RCA system.
  Every workflow step is recorded as a RefinementStep for learning.

  ## Features

  - ✅ Automatic RCA session creation
  - ✅ Per-step metric recording (tokens, metrics)
  - ✅ Failure tracking and root cause recording
  - ✅ Automatic workflow completion with metrics
  - ✅ Support for nested workflows (parent_session_id)
  - ✅ Zero impact on existing workflows (optional mixin)

  ## Usage Pattern

  ```elixir
  defmodule Singularity.Workflows.CodeQualityImprovement do
    use Singularity.Workflows.RcaWorkflow
    require Logger

    @impl Singularity.Workflows.RcaWorkflow
    def rca_config do
      %{
        agent_id: "quality-improvement-agent",
        template_id: "quality-improvement-template"
      }
    end

    def __workflow_steps__ do
      [
        {:analyze_metrics, &__MODULE__.analyze_metrics/1},
        {:generate_fixes, &__MODULE__.generate_fixes/1},
        {:validate_fixes, &__MODULE__.validate_fixes/1}
      ]
    end

    def analyze_metrics(input) do
      with_rca_step("analyze_metrics", input, fn ->
        # Analyze code metrics
        {:ok, %{metrics: metrics}}
      end)
    end

    def generate_fixes(input) do
      with_rca_step("generate_fixes", input, fn ->
        # Generate fixes based on metrics
        {:ok, %{fixes: fixes, tokens_used: 1200}}
      end)
    end

    def validate_fixes(input) do
      with_rca_step("validate_fixes", input, fn ->
        # Validate that fixes work
        {:ok, %{passed: true, improvements: count}}
      end)
    end

    def execute(input) do
      execute_with_rca(input)
    end
  end
  ```

  ## Automatic RCA Tracking

  When a workflow uses RcaWorkflow:

  1. **Session Created**: GenerationSession created at workflow start
  2. **Step Tracking**: Each workflow step becomes a RefinementStep
  3. **Metrics Recorded**: Step metrics (tokens, results) stored automatically
  4. **Completion**: Session finalized with outcome and metrics
  5. **Learning**: RCA system learns which workflows/steps work best

  ## Integration with Agents

  Agents can now:
  - Select best workflows via `PgflowIntegration.compare_workflows()`
  - Optimize step order via `PgflowIntegration.analyze_workflow_steps()`
  - Track improvement results over time
  - Automatically improve workflow decisions

  ## Call Graph

  ```
  execute_with_rca/1
    ├─ SessionManager.start_session/1
    ├─ PgflowIntegration.track_workflow_start/2
    ├─ execute_workflow_steps/2
    │  └─ for each step:
    │     ├─ with_rca_step/3
    │     └─ PgflowIntegration.record_workflow_step/4
    └─ PgflowIntegration.record_workflow_completion/3
  ```
  """

  require Logger
  alias Singularity.RCA.{SessionManager, PgflowIntegration}

  @doc """
  Configure RCA tracking for this workflow.

  Must be implemented by workflows that use RcaWorkflow.

  ## Returns
  Map with:
  - :agent_id - Agent executing this workflow
  - :template_id - Template being used (optional)
  - :parent_session_id - Parent session for nested workflows (optional)
  """
  @callback rca_config() :: map()

  @doc """
  Define workflow steps.

  Each step is a tuple of {step_name, step_function}.
  Step function receives input and returns {:ok, updated_input} or {:error, reason}.
  """
  @callback __workflow_steps__() :: [{atom(), function()}]

  @doc """
  Execute main workflow.

  Called by pgflow executor.
  """
  @callback execute(map()) :: {:ok, map()} | {:error, term()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Singularity.Workflows.RcaWorkflow
      require Logger

      @doc false
      def rca_config do
        %{agent_id: "workflow_agent"}
      end

      defoverridable rca_config: 0

      @doc false
      def execute_with_rca(input) do
        with_rca_session(fn session_id ->
          execute_workflow_steps(input, session_id)
        end)
      end

      @doc false
      def with_rca_session(fun) do
        config = rca_config()
        workflow_module = __MODULE__ |> to_string()

        # Create RCA session
        {:ok, session} =
          SessionManager.start_session(%{
            initial_prompt: "Executing #{workflow_module}",
            agent_id: Map.get(config, :agent_id, "workflow_agent"),
            template_id: Map.get(config, :template_id),
            agent_version: Map.get(config, :agent_version, "v1.0.0")
          })

        session_id = session.id

        # Track workflow start
        :ok = track_workflow_start(session_id, workflow_module)

        Logger.info("RCA Workflow started", %{
          session_id: session_id,
          workflow: workflow_module,
          agent_id: Map.get(config, :agent_id)
        })

        try do
          # Execute workflow with RCA tracking
          result = fun.(session_id)

          # Record completion
          PgflowIntegration.record_workflow_completion(
            session_id,
            "success",
            extract_metrics(result)
          )

          Logger.info("RCA Workflow completed successfully", %{
            session_id: session_id,
            workflow: workflow_module
          })

          result
        rescue
          error ->
            # Record failure
            PgflowIntegration.record_workflow_completion(
              session_id,
              "failure_execution",
              %{"error" => inspect(error)}
            )

            Logger.error("RCA Workflow failed", %{
              session_id: session_id,
              workflow: workflow_module,
              error: inspect(error)
            })

            {:error, error}
        end
      end

      @doc false
      def execute_workflow_steps(input, session_id) do
        steps = __workflow_steps__()
        execute_steps(input, session_id, steps, 1)
      end

      @doc false
      def execute_steps(input, _session_id, [], _step_num) do
        {:ok, input}
      end

      @doc false
      def execute_steps(input, session_id, [{step_name, step_func} | rest], step_num) do
        with_rca_step(session_id, step_num, step_name, fn ->
          step_func.(input)
        end)
        |> case do
          {:ok, output} -> execute_steps(output, session_id, rest, step_num + 1)
          {:error, reason} -> {:error, reason}
        end
      end

      @doc false
      def with_rca_step(session_id, step_num, step_name, fun) do
        start_time = System.monotonic_time(:millisecond)

        Logger.info("Workflow step starting", %{
          step: step_num,
          name: step_name,
          session_id: session_id
        })

        try do
          result = fun.()

          duration = System.monotonic_time(:millisecond) - start_time
          metrics = extract_step_metrics(result)

          # Record step in RCA
          {:ok, _step} =
            PgflowIntegration.record_workflow_step(
              session_id,
              step_num,
              step_name,
              "Completed #{step_name}",
              tokens_used: Map.get(metrics, :tokens_used, 0),
              metrics: Map.get(metrics, :metrics, %{})
            )

          Logger.info("Workflow step completed", %{
            step: step_num,
            name: step_name,
            duration_ms: duration,
            session_id: session_id
          })

          result
        rescue
          error ->
            duration = System.monotonic_time(:millisecond) - start_time

            # Record failure step
            {:ok, _step} =
              PgflowIntegration.record_workflow_step(
                session_id,
                step_num,
                step_name,
                "Failed: #{inspect(error)}",
                result: "error"
              )

            Logger.error("Workflow step failed", %{
              step: step_num,
              name: step_name,
              duration_ms: duration,
              error: inspect(error),
              session_id: session_id
            })

            {:error, error}
        end
      end

      @doc false
      defp track_workflow_start(session_id, workflow_module) do
        case PgflowIntegration.track_workflow_start(session_id, workflow_module) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Logger.warn("Failed to track workflow start", %{
              reason: inspect(reason)
            })

            # Don't fail workflow on RCA error
            :ok
        end
      end

      @doc false
      defp extract_metrics({:ok, output}) when is_map(output) do
        Map.take(output, [
          "improvements",
          "complexity_reduction",
          "coverage_improvement",
          "fixes_applied",
          "tests_passing"
        ])
      end

      @doc false
      defp extract_metrics(_), do: %{}

      @doc false
      defp extract_step_metrics({:ok, output}) when is_map(output) do
        %{
          tokens_used: Map.get(output, "tokens_used", 0),
          metrics:
            Map.take(output, [
              "improvements",
              "fixes",
              "passed",
              "failures",
              "complexity"
            ])
        }
      end

      @doc false
      defp extract_step_metrics(_), do: %{tokens_used: 0, metrics: %{}}
    end
  end
end
