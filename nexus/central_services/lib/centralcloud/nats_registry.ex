defmodule CentralCloud.NatsRegistry do
  @moduledoc """
  Compatibility registry that maps legacy NATS subjects to their PGFlow queue
  equivalents.

  The CentralCloud codebase historically routed request/response style
  interactions through NATS subjects such as `llm.request`.  PGFlow replaces
  those subjects with pgmq-backed queues while keeping the same semantic
  meaning.  This module provides a tiny translation layer so that existing
  calls to `CentralCloud.NatsRegistry.subject/1` continue to work.
  """

  @subjects %{
    llm_request: "central.llm.requests"
  }

  @spec subject(atom()) :: String.t()
  def subject(key) do
    Map.get(@subjects, key) ||
      raise ArgumentError, "Unknown subject #{inspect(key)} for CentralCloud.NatsRegistry"
  end
end
