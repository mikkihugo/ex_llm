defmodule Singularity.LLM.Supervisor do
  @moduledoc """
  LLM Supervisor - Manages LLM-related infrastructure.

  Supervises LLM rate limiting and related processes. Note that `Singularity.LLM.Service`
  is a plain module (not a GenServer) and does not require supervision.

  ## Managed Processes

  - `Singularity.LLM.RateLimiter` - GenServer managing rate limits across providers

  ## Important Notes

  `Singularity.LLM.Service` is NOT supervised here because it's a stateless module
  that delegates to Singularity.Jobs.PgmqClient. All state is managed by:
  - RateLimiter (for rate limiting)
  - Messaging.Client (for PGFlow communication)
  - AI Server (TypeScript service via pgmq)

  ## Dependencies

  Depends on:
  - Singularity.Jobs.PgmqClient.Supervisor - For pgmq communication
  - Repo - For storing rate limit state (if persisted)
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("Starting LLM Supervisor...")

    children = [
      Singularity.LLM.RateLimiter
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
