defmodule CentralCloud.Database.DistributedIds do
  @moduledoc """
  Distributed ID generation for CentralCloud using PostgreSQL pgx_ulid extension.

  Provides ULID generation for cross-instance tracking across multiple Singularity instances
  and CentralCloud services. ULIDs are sortable, monotonic IDs ideal for distributed systems.

  ## Use Cases
  - Correlation IDs for tracking requests across Singularity instances
  - Pattern synchronization batch IDs
  - Aggregation job IDs
  - Knowledge base entry IDs

  ## Migration Path
  - Current: pgx_ulid (PostgreSQL 17)
  - Future: PostgreSQL 18 native UUIDv7 support
  """

  require Logger
  alias CentralCloud.Repo

  @doc """
  Generate a new ULID for sync batch IDs (pattern aggregation, etc).
  """
  def generate_batch_id do
    case Repo.query("SELECT gen_ulid()") do
      {:ok, %{rows: [[ulid]]}} -> ulid
      error -> Logger.error("Failed to generate batch ULID: #{inspect(error)}"); nil
    end
  end

  @doc """
  Generate a new ULID for correlation/request tracking across instances.
  """
  def generate_correlation_id, do: generate_batch_id()

  @doc """
  Generate a new ULID for distributed tracing.
  """
  def generate_trace_id, do: generate_batch_id()

  @doc """
  Generate a new ULID for knowledge base entries.
  """
  def generate_knowledge_entry_id, do: generate_batch_id()

  @doc """
  Generate a new ULID for aggregation job IDs.
  """
  def generate_job_id, do: generate_batch_id()

  @doc """
  Extract timestamp from a ULID (useful for age calculations).
  """
  def ulid_timestamp(ulid_str) when is_binary(ulid_str) do
    case Repo.query(
      "SELECT (EXTRACT(EPOCH FROM ulid_to_timestamp($1)) * 1000)::bigint",
      [ulid_str]
    ) do
      {:ok, %{rows: [[timestamp]]}} when is_integer(timestamp) -> {:ok, timestamp}
      error -> {:error, error}
    end
  end

  @doc """
  Generate a batch of ULIDs efficiently.
  """
  def generate_batch(count) when is_integer(count) and count > 0 do
    case Repo.query(
      "SELECT generate_series(1, $1) as seq, gen_ulid() as ulid",
      [count]
    ) do
      {:ok, %{rows: rows}} -> Enum.map(rows, fn [_seq, ulid] -> ulid end)
      error -> []
    end
  end

  @doc """
  Check if a ULID was generated recently (within N seconds).
  """
  def recent?(ulid_str, seconds_ago) do
    case ulid_timestamp(ulid_str) do
      {:ok, timestamp_ms} ->
        now_ms = System.system_time(:millisecond)
        timestamp_ms > (now_ms - seconds_ago * 1000)
      {:error, _} -> false
    end
  end

  @doc """
  Get the age of a ULID in seconds.
  """
  def age_seconds(ulid_str) do
    case ulid_timestamp(ulid_str) do
      {:ok, timestamp_ms} ->
        now_ms = System.system_time(:millisecond)
        (now_ms - timestamp_ms) / 1000
      {:error, _} -> :error
    end
  end
end
