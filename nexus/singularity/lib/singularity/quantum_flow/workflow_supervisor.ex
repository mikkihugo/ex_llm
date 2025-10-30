defmodule Singularity.QuantumFlow.WorkflowSupervisor do
  @moduledoc false
  defdelegate start_workflow(workflow_module, opts \\ []), to: QuantumFlow.WorkflowSupervisor
end
