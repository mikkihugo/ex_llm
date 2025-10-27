defmodule Singularity.PgFlowAdapter do
  @moduledoc """
  Backward-compatibility adapter that delegates to the unified Singularity.Workflows system.
  
  This module is deprecated. Use Singularity.Workflows directly instead.
  """

  defdelegate persist_workflow(workflow), to: Singularity.Workflows, as: :create_workflow
  defdelegate fetch_workflow(id), to: Singularity.Workflows
end
