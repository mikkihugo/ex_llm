defmodule Singularity.Tools.Backup do
  @moduledoc """
  Minimal stub for backup tooling.

  The real backup pipeline isn't part of the stripped-down workspace, but
  other modules still call `Singularity.Tools.Backup.register/1`. To keep the
  tool catalog happy (and avoid compile errors) we register a no-op placeholder
  tool that simply reports a friendly message.
  """

  alias Singularity.Tools.Tool
  require Logger

  @doc """
  Register a simple informational tool so callers don't break.
  """
  def register(provider) do
    Singularity.Tools.Catalog.add_tools(provider, [status_tool()])
    Logger.debug("Registered stub backup tool for #{inspect(provider)}")
    :ok
  end

  defp status_tool do
    Tool.new!(%{
      name: "backup_status",
      description: "Placeholder backup tool (feature paused)",
      display_text: "Check backup status",
      parameters: [],
      function: fn _args, _ctx ->
        {:ok, "Backup tooling is temporarily unavailable in this build."}
      end
    })
  end
end
