defmodule Singularity.Control do
  @moduledoc """
  DEPRECATED: Use `Singularity.Execution.Runners.Control` instead.

  This module delegates all calls to the new location for backward compatibility.

  Migration path:
  ```elixir
  # Old (deprecated)
  alias Singularity.Control

  # New
  alias Singularity.Execution.Runners.Control
  ```
  """

  @deprecated "Use Singularity.Execution.Runners.Control instead"
  defdelegate start_link(_opts \\ []),
    to: Singularity.Execution.Runners.Control

  @deprecated "Use Singularity.Execution.Runners.Control instead"
  defdelegate publish_improvement(agent_id, payload),
    to: Singularity.Execution.Runners.Control

  @deprecated "Use Singularity.Execution.Runners.Control instead"
  defdelegate publish_system_event(event_type, data),
    to: Singularity.Execution.Runners.Control

  @deprecated "Use Singularity.Execution.Runners.Control instead"
  defdelegate get_state(),
    to: Singularity.Execution.Runners.Control
end
