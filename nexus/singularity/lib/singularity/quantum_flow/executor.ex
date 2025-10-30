defmodule Singularity.QuantumFlow.Executor do
  @moduledoc false
  defdelegate execute(workflow_module, input, opts \\ []), to: Pgflow.Executor
  defdelegate execute_dynamic(flow_name, input, step_functions, opts \\ []), to: Pgflow.Executor
end
