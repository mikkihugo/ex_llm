defmodule Singularity.QuantumFlow.Notifications do
  @moduledoc false
  defdelegate send_with_notify(queue, message, repo, opts \\ []), to: QuantumFlow.Notifications
  defdelegate listen(queue, repo), to: QuantumFlow.Notifications
  defdelegate unlisten(pid, repo), to: QuantumFlow.Notifications
end
