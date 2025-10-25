defmodule Singularity.Workflow.DSL do
  @moduledoc """
  Workflow Definition DSL - Define workflows in pure Elixir

  Similar to pgflow but native to Singularity with full Elixir integration.

  ## Usage

      defmodule MyWorkflow do
        use Singularity.Workflow

        workflow do
          step :receive_input, &receive_input/1
          step :process_data, &process_data/1
          step :send_output, &send_output/1
        end

        def receive_input(input), do: {:ok, input}
        def process_data(prev), do: {:ok, prev}
        def send_output(prev), do: {:ok, prev}
      end

  ## Step Function Contract

  Each step function receives the previous step's output (or initial input for first step).
  Must return either:
  - `{:ok, result}` - Step succeeded, pass result to next step
  - `{:error, reason}` - Step failed, halt workflow and retry

  ## Examples

  Simple transformation:
      step :validate, fn input ->
        if valid?(input), do: {:ok, input}, else: {:error, :invalid}
      end

  State accumulation:
      step :enrich, fn prev ->
        {:ok, Map.put(prev, :enriched, true)}
      end

  Call Elixir code:
      step :call_llm, fn prev ->
        LLM.Service.call(:complex, prev.messages)
      end
  """

  defmacro __using__(_opts) do
    quote do
      import Singularity.Workflow.DSL

      Module.register_attribute(__MODULE__, :workflow_steps, accumulate: true)

      @before_compile Singularity.Workflow.DSL
    end
  end

  defmacro __before_compile__(env) do
    steps = Module.get_attribute(env.module, :workflow_steps)

    quote do
      @doc false
      def __workflow_steps__, do: unquote(Enum.reverse(steps))

      @doc false
      def __workflow_name__ do
        unquote(env.module |> Atom.to_string() |> String.split(".") |> List.last() |> String.downcase())
      end
    end
  end

  @doc """
  Define a workflow with a series of steps.

  The workflow macro collects all steps defined within its block and makes them
  available for execution by WorkflowExecutor.

  ## Example

      workflow do
        step :step1, &handler1/1
        step :step2, &handler2/1
        step :step3, &handler3/1
      end
  """
  defmacro workflow(do: block) do
    quote do
      unquote(block)
    end
  end

  @doc """
  Define a single step in the workflow.

  A step is a named unit of work that receives the output of the previous step
  (or initial input for the first step) and returns {:ok, result} or {:error, reason}.

  ## Parameters

  - `name` - Atom identifying this step
  - `func` - Function/function reference that performs the work

  ## Examples

  Using a function reference:
      step :validate, &validate_input/1

  Using an anonymous function:
      step :transform, fn input ->
        {:ok, String.upcase(input)}
      end

  Using a captured function:
      step :process, &MyModule.process/1
  """
  defmacro step(name, func) do
    quote do
      Module.put_attribute(__MODULE__, :workflow_steps, {unquote(name), unquote(func)})
    end
  end
end
