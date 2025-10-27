defmodule CentralCloud.SharedQueueRepo do
  @moduledoc """
  Ecto Database Repository for the shared_queue database.

  NOTE: "Repo" here means Ecto database repository (NOT Git repository).
  Standard Elixir/Ecto naming convention for database connections.

  This connects to the separate `shared_queue` PostgreSQL database
  (which uses pgmq extension for message queuing).

  ## Purpose

  Provides Ecto type-safe queries for analyzing archived messages,
  while pgmq functions handle the actual pub/sub messaging.

  ## Usage

  ```elixir
  # Query archived LLM requests
  CentralCloud.SharedQueueRepo.all(CentralCloud.SharedQueueSchemas.LLMRequestArchive)

  # Find requests from last 7 days
  import Ecto.Query

  from(msg in CentralCloud.SharedQueueSchemas.LLMRequestArchive,
    where: msg.enqueued_at > ago(7, "day"),
    select: msg.msg
  ) |> CentralCloud.SharedQueueRepo.all()
  ```

  ## Configuration

  Configured in config/config.exs:

  ```elixir
  config :centralcloud, CentralCloud.SharedQueueRepo,
    database: System.get_env("SHARED_QUEUE_DB", "shared_queue"),
    hostname: System.get_env("SHARED_QUEUE_HOST", "localhost"),
    port: String.to_integer(System.get_env("SHARED_QUEUE_PORT", "5432")),
    username: System.get_env("SHARED_QUEUE_USER", "postgres"),
    password: System.get_env("SHARED_QUEUE_PASSWORD", ""),
    pool_size: 5
  ```
  """

  use Ecto.Repo,
    otp_app: :centralcloud,
    adapter: Ecto.Adapters.Postgres
end
