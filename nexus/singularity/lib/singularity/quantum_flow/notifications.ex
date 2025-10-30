defmodule Singularity.QuantumFlow.Notifications do
  @moduledoc false
  defdelegate send_with_notify(queue, message, repo, opts \\ []), to: Pgflow.Notifications
  defdelegate listen(queue, repo), to: Pgflow.Notifications
  defdelegate unlisten(pid, repo), to: Pgflow.Notifications
end
