defmodule Singularity.Workflow do
  @moduledoc """
  Workflow module - Re-exports DSL for convenience

  Use this module to create workflows:

      defmodule MyWorkflow do
        use Singularity.Workflow

        workflow do
          step :step1, &step1/1
          step :step2, &step2/1
        end

        def step1(input), do: {:ok, input}
        def step2(prev), do: {:ok, prev}
      end
  """

  defmacro __using__(_opts) do
    quote do
      use Singularity.Workflow.DSL
    end
  end
end
