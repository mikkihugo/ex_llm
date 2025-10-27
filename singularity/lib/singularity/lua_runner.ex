defmodule Singularity.LuaRunner do
  @moduledoc """
  DEPRECATED: Use `Singularity.Execution.Runners.LuaRunner` instead.

  This module delegates all calls to the new location for backward compatibility.

  Migration path:
  ```elixir
  # Old (deprecated)
  alias Singularity.LuaRunner

  # New
  alias Singularity.Execution.Runners.LuaRunner
  ```
  """

  @deprecated "Use Singularity.Execution.Runners.LuaRunner instead"
  defdelegate execute(lua_code, _opts \\ []),
    to: Singularity.Execution.Runners.LuaRunner

  @deprecated "Use Singularity.Execution.Runners.LuaRunner instead"
  defdelegate execute_with_context(lua_code, context, _opts \\ []),
    to: Singularity.Execution.Runners.LuaRunner
end
