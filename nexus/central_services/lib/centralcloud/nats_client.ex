defmodule CentralCloud.NatsClient do
  @moduledoc """
  NATS Client Stub - Placeholder for NATS integration.

  This module will be implemented when NATS messaging is added to CentralCloud.
  For now, it provides stub implementations to allow the application to compile.
  """

  require Logger

  @doc "Stub subscribe implementation"
  def subscribe(subject, opts \\ []) do
    Logger.debug("NATS stub subscribe: #{subject} with opts: #{inspect(opts)}")
    {:ok, :stub_sid}
  end

  @doc "Stub publish implementation"
  def publish(subject, message) do
    Logger.debug("NATS stub publish to #{subject}: #{inspect(message)}")
    :ok
  end

  @doc "Stub publish_request implementation"
  def publish_request(subject, message, timeout \\ 5000) do
    Logger.debug("NATS stub publish_request to #{subject}: #{inspect(message)}")
    {:ok, %{data: "{}"}}
  end
end
