defmodule CentralCloud.SharedQueueSchemas do
  @moduledoc """
  Ecto schemas for shared_queue database tables.

  pgmq (PostgreSQL Message Queue) automatically creates tables:
  - pgmq.llm_requests
  - pgmq.llm_requests_archive
  - pgmq.approval_requests
  - pgmq.approval_requests_archive
  - etc.

  These schemas provide Ecto type safety for querying and analyzing
  archived messages, while pgmq functions handle publish/subscribe.

  ## Usage

  ```elixir
  # Read archived messages for analytics
  archived = CentralCloud.Repo.all(CentralCloud.SharedQueueSchemas.LLMRequestArchive)

  # Query specific requests
  from(msg in CentralCloud.SharedQueueSchemas.LLMRequestArchive,
    where: msg.enqueued_at > ago(7, "day"),
    select: msg.msg
  ) |> CentralCloud.Repo.all()
  ```

  ## Note on Schema Implementation

  pgmq manages the actual queue tables. These schemas are provided for optional
  use when reading archived messages. You can implement specific schemas as needed
  for your analytics and monitoring requirements.
  """

  # Placeholder for future schema implementations
  # Each queue maintains its own _archive table for message history
end
