defmodule Singularity.HTDAG.Executor do
  @moduledoc """
  Backward-compatibility wrapper that delegates to Singularity.Workflows.
  
  This module is deprecated. Use Singularity.Workflows directly instead.
  """

  defdelegate execute_workflow_token(token, opts), to: Singularity.Workflows, as: :execute_workflow
  defdelegate execute_workflow_map(workflow, opts), to: Singularity.Workflows
end
