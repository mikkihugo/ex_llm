defmodule Singularity.Execution.ExecutionOrchestrator do
  @moduledoc """
  DEPRECATED: Use `Singularity.Execution.Orchestrator.ExecutionOrchestrator` instead.

  This module delegates all calls to the new location for backward compatibility.

  Migration path:
  ```elixir
  # Old (deprecated)
  alias Singularity.Execution.ExecutionOrchestrator

  # New
  alias Singularity.Execution.Orchestrator.ExecutionOrchestrator
  ```
  """

  @deprecated "Use Singularity.Execution.Orchestrator.ExecutionOrchestrator instead"
  defdelegate execute(goal, _opts \\ []),
    to: Singularity.Execution.Orchestrator.ExecutionOrchestrator

  @deprecated "Use Singularity.Execution.Orchestrator.ExecutionOrchestrator instead"
  defdelegate get_strategies_info(),
    to: Singularity.Execution.Orchestrator.ExecutionOrchestrator
end
