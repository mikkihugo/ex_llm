defmodule Singularity.Workflows.BaseWorkflow do
  @moduledoc """
  Base Workflow - Common patterns and behaviors for all workflows.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Workflows.BaseWorkflow",
    "type": "base_behavior",
    "purpose": "Common patterns and behaviors for workflow implementations",
    "layer": "base",
    "used_by": "all_workflows"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      A[Workflow Implementation] --> B[BaseWorkflow]
      B --> C[__workflow_steps__/0]
      B --> D[execute_workflow/1]
      B --> E[validate_input/2]
      B --> F[handle_error/2]
      B --> G[log_step/3]
  ```

  ## Call Graph (YAML)

  ```yaml
  provides:
    - execute_workflow/1 (main execution entry point)
    - validate_input/2 (input validation)
    - handle_error/2 (error handling)
    - log_step/3 (step logging)
  ```

  ## Anti-Patterns

  - ❌ DO NOT implement workflows without using this base pattern
  - ❌ DO NOT skip input validation in workflow steps
  - ❌ DO NOT handle errors inconsistently across workflows

  ## Workflow Pattern

  All workflows should follow this pattern:

  ```elixir
  defmodule MyWorkflow do
    use Singularity.Workflows.BaseWorkflow
    require Logger

    # Define workflow steps
    def __workflow_steps__ do
      [
        {:step1, &__MODULE__.step1/1},
        {:step2, &__MODULE__.step2/1},
        {:step3, &__MODULE__.step3/1}
      ]
    end

    # Implement each step
    def step1(input) do
      log_step("step1", input)
      # Step implementation
      {:ok, updated_input}
    end

    # Main entry point
    def execute(input) do
      execute_workflow(input)
    end
  end
  ```

  ## Common Workflow Steps

  Most workflows should include these standard steps:

  1. **receive_input** - Validate and prepare input
  2. **process_data** - Main processing logic
  3. **validate_output** - Ensure output quality
  4. **publish_result** - Send results to next stage

  ## Error Handling

  All workflows use consistent error handling:
  - Log errors with context
  - Return `{:error, reason}` tuples
  - Include step information in error messages
  """

  @doc """
  Execute a workflow with the given input.

  Runs through all defined workflow steps in sequence, handling errors
  and logging progress at each step.

  ## Parameters

  - `input` - Initial input data for the workflow

  ## Returns

  - `{:ok, result}` - Workflow completed successfully
  - `{:error, reason}` - Workflow failed with error details

  ## Examples

      {:ok, result} = MyWorkflow.execute(%{data: "test"})
  """
  @doc false
  def __workflow_steps__ do
    raise "workflow modules must implement __workflow_steps__/0"
  end

  defoverridable __workflow_steps__: 0

  def execute_workflow(input) do
    try do
      steps = __workflow_steps__()
      execute_steps(input, steps, [])
    rescue
      error ->
        handle_error("workflow_execution", error, input)
    end
  end

  # Execute workflow steps in sequence
  defp execute_steps(input, [], _completed_steps) do
    {:ok, input}
  end

  defp execute_steps(input, [{step_name, step_function} | remaining_steps], completed_steps) do
    log_step(step_name, input, "starting")

    case step_function.(input) do
      {:ok, updated_input} ->
        log_step(step_name, updated_input, "completed")
        execute_steps(updated_input, remaining_steps, [step_name | completed_steps])

      {:error, reason} ->
        handle_error(step_name, reason, input)
    end
  end

  @doc """
  Validate input data for a workflow step.

  Provides common validation patterns that workflows can use.

  ## Parameters

  - `step_name` - Name of the workflow step
  - `input` - Input data to validate
  - `required_fields` - List of required field names

  ## Returns

  - `:ok` - Input is valid
  - `{:error, reason}` - Input validation failed

  ## Examples

      :ok = validate_input("receive_query", input, ["query_id", "query"])
  """
  def validate_input(step_name, input, required_fields) when is_list(required_fields) do
    missing_fields =
      required_fields
      |> Enum.reject(fn field -> Map.has_key?(input, field) end)

    case missing_fields do
      [] ->
        :ok

      missing ->
        {:error, "Missing required fields in #{step_name}: #{Enum.join(missing, ", ")}"}
    end
  end

  def validate_input(step_name, input, required_fields) when is_atom(required_fields) do
    validate_input(step_name, input, [required_fields])
  end

  @doc """
  Handle errors consistently across workflows.

  Logs errors with context and returns standardized error format.

  ## Parameters

  - `step_name` - Name of the step that failed
  - `error` - Error reason or exception
  - `input` - Input data at time of error

  ## Returns

  - `{:error, reason}` - Standardized error tuple

  ## Examples

      {:error, reason} = handle_error("process_data", "Invalid format", input)
  """
  def handle_error(step_name, error, input) do
    error_message =
      case error do
        %{__struct__: _} = exception -> Exception.message(exception)
        reason when is_binary(reason) -> reason
        other -> inspect(other)
      end

    Logger.error("Workflow step failed",
      step: step_name,
      error: error_message,
      input_keys: Map.keys(input)
    )

    {:error, "#{step_name}: #{error_message}"}
  end

  @doc """
  Log workflow step execution.

  Provides consistent logging format for all workflow steps.

  ## Parameters

  - `step_name` - Name of the workflow step
  - `input` - Current input data
  - `status` - Step status ("starting", "completed", "failed")

  ## Examples

      log_step("process_data", input, "starting")
  """
  def log_step(step_name, input, status) do
    Logger.debug("Workflow step #{status}",
      step: step_name,
      status: status,
      input_keys: Map.keys(input)
    )
  end

  # Macro to make workflows easier to implement
  defmacro __using__(_opts) do
    quote do
      @behaviour Singularity.Workflows.BaseWorkflow

      # Default implementation of execute/1
      def execute(input) do
        execute_workflow(input)
      end

      # Default implementation of __workflow_steps__/0
      def __workflow_steps__, do: []

      # Import common functions
      import Singularity.Workflows.BaseWorkflow,
        only: [
          execute_workflow: 1,
          validate_input: 3,
          handle_error: 3,
          log_step: 3
        ]
    end
  end
end
