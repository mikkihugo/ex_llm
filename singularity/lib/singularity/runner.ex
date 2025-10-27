defmodule Singularity.Runner do
  @moduledoc """
  DEPRECATED: Use `Singularity.Execution.Runners.Runner` instead.

  This module delegates all calls to the new location for backward compatibility.

  Migration path:
  ```elixir
  # Old (deprecated)
  alias Singularity.Runner

  # New
  alias Singularity.Execution.Runners.Runner
  ```
  """

  @deprecated "Use Singularity.Execution.Runners.Runner instead"
  defdelegate start_link(opts \\ []),
    to: Singularity.Execution.Runners.Runner

  @deprecated "Use Singularity.Execution.Runners.Runner instead"
  defdelegate execute_concurrent(tasks, opts \\ []),
    to: Singularity.Execution.Runners.Runner

  @deprecated "Use Singularity.Execution.Runners.Runner instead"
  defdelegate stream_execution(tasks, opts \\ []),
    to: Singularity.Execution.Runners.Runner
end
