defmodule Singularity.Tools.Behaviour do
  @moduledoc """
  Behaviour for tool modules executed through `Singularity.Tools`.

  Modules that implement this behaviour expose declarative metadata via
  `tool_definitions/0` and provide runtime execution through
  `execute_tool/2`. The router in `Singularity.Tools` uses these callbacks
  to surface available tools and delegate work.
  """

  @type tool_name :: Singularity.Tools.tool_name()
  @type tool_args :: Singularity.Tools.args()
  @type tool_result :: Singularity.Tools.result()
  @type tool_definition :: map()

  @callback tool_definitions() :: [tool_definition()]
  @callback execute_tool(tool_name(), tool_args()) :: tool_result()
end
