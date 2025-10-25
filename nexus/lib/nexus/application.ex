defmodule Nexus.Application do
  @moduledoc """
  Nexus Application - LLM Router and HITL Bridge

  Starts the supervision tree for:
  - Queue Consumer - Polls pgmq for LLM requests from Singularity
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting Nexus application...")

    children = [
      # Queue consumer - polls llm_requests and publishes to llm_results
      {Nexus.QueueConsumer, get_queue_config()}
    ]

    opts = [strategy: :one_for_one, name: Nexus.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp get_queue_config do
    [
      database_url: get_database_url(),
      poll_interval_ms: get_poll_interval(),
      batch_size: get_batch_size()
    ]
  end

  defp get_database_url do
    System.get_env("SHARED_QUEUE_DB_URL") ||
      "postgresql://postgres:@localhost:5432/shared_queue"
  end

  defp get_poll_interval do
    case System.get_env("NEXUS_POLL_INTERVAL_MS") do
      nil -> 1000
      val -> String.to_integer(val)
    end
  end

  defp get_batch_size do
    case System.get_env("NEXUS_BATCH_SIZE") do
      nil -> 10
      val -> String.to_integer(val)
    end
  end
end
