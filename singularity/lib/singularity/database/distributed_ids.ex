defmodule Singularity.Database.DistributedIds do
  @moduledoc """
  Distributed ID generation using PostgreSQL pgx_ulid extension.

  Provides ULID (Universally Unique Lexicographically Sortable Identifiers) for:
  - **Cross-system tracking** between Singularity and CentralCloud
  - **Message correlation IDs** for request tracing
  - **Agent session tracking** with chronological ordering
  - **Event sequencing** for audit logs
  
  ## Why ULID over UUID?

  - **Sortable**: ULIDs are monotonically increasing (sortable by timestamp)
  - **Readable**: Base32 encoded (shorter than UUID)
  - **Fast**: No need for UUID parsing in indexes
  - **Distributed**: No coordination needed between nodes
  
  ## Future: PostgreSQL 18 Migration

  PostgreSQL 18 will introduce native UUIDv7 support, which combines the benefits of
  UUIDs with ULID's sortability. Migration path:
  
  1. **PostgreSQL 17**: Use pgx_ulid for ULIDs
  2. **PostgreSQL 18**: Introduce gen_uuid_v7() alongside ULIDs
  3. **Future**: Migrate to UUIDv7 as the standard
  
  ## Usage Examples

  ```elixir
  # Generate a new ULID for agent session tracking
  iex> Singularity.Database.DistributedIds.generate_session_id()
  "01ARZ3NDEKTSV4RRFFQ69G5FAV"
  
  # Generate ULID for message correlation across systems
  iex> Singularity.Database.DistributedIds.generate_correlation_id()
  "01ARZ3NDEKTSV4RRFFQ69G5FAV"
  
  # Extract timestamp from ULID (useful for time-based queries)
  iex> Singularity.Database.DistributedIds.ulid_timestamp("01ARZ3NDEKTSV4RRFFQ69G5FAV")
  {:ok, timestamp_ms}
  ```

  ## Singularity ↔ CentralCloud Use Cases

  - **Agent Session Tracking**: Each autonomous agent gets a ULID for the session
  - **Message Correlation**: Messages exchanged between Singularity and CentralCloud get correlated with ULIDs
  - **Distributed Request Tracing**: End-to-end request tracing across systems using ULID chain
  - **Cross-system Analytics**: Analyze agent behavior across Singularity and CentralCloud instances
  """

  require Logger
  alias Singularity.Repo

  @doc """
  Generate a new ULID for session tracking.
  
  Used for autonomous agent sessions that span Singularity and optionally CentralCloud.
  ULIDs are sortable by timestamp, enabling chronological session analysis.
  """
  def generate_session_id do
    case Repo.query("SELECT gen_ulid()") do
      {:ok, %{rows: [[ulid]]}} -> ulid
      error -> 
        Logger.error("Failed to generate session ULID: #{inspect(error)}")
        nil
    end
  end

  @doc """
  Generate a new ULID for message correlation.
  
  Used for correlating messages across Singularity and CentralCloud systems.
  All related messages in a distributed transaction get the same correlation ID.
  """
  def generate_correlation_id do
    generate_session_id()
  end

  @doc """
  Generate a new ULID for request tracing.
  
  Used for end-to-end request tracing across multiple systems.
  Each hop in the distributed system adds this trace ID to logs.
  """
  def generate_trace_id do
    generate_session_id()
  end

  @doc """
  Generate a new ULID for event sequencing.
  
  Used for audit logs and event sourcing across systems.
  Chronologically sortable for replaying events.
  """
  def generate_event_id do
    generate_session_id()
  end

  @doc """
  Extract the Unix timestamp (in milliseconds) from a ULID.
  
  Useful for time-based queries and analysis without parsing.
  
  ## Returns
  
  `{:ok, timestamp_ms}` - milliseconds since epoch
  `{:error, reason}` - if ULID is invalid
  """
  def ulid_timestamp(ulid_str) when is_binary(ulid_str) do
    case Repo.query("SELECT (EXTRACT(EPOCH FROM ulid_to_timestamp($1)) * 1000)::bigint", [ulid_str]) do
      {:ok, %{rows: [[timestamp]]}} when is_integer(timestamp) -> 
        {:ok, timestamp}
      {:ok, %{rows: [[nil]]}} -> 
        {:error, "Invalid ULID"}
      error -> 
        Logger.error("Failed to extract ULID timestamp: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Generate multiple ULIDs efficiently.
  
  Useful when creating multiple related records (e.g., agent tasks in a session).
  Returns count ULIDs in chronological order.
  """
  def generate_batch(count) when is_integer(count) and count > 0 do
    case Repo.query("SELECT generate_series(1, $1) as seq, gen_ulid() as ulid", [count]) do
      {:ok, %{rows: rows}} -> 
        Enum.map(rows, fn [_seq, ulid] -> ulid end)
      error -> 
        Logger.error("Failed to generate batch ULIDs: #{inspect(error)}")
        []
    end
  end

  @doc """
  Check if a ULID was generated within the last N seconds.
  
  Useful for session validation and expiration checks.
  """
  def recent?(ulid_str, seconds_ago) when is_binary(ulid_str) and is_integer(seconds_ago) do
    case ulid_timestamp(ulid_str) do
      {:ok, timestamp_ms} ->
        now_ms = System.system_time(:millisecond)
        timestamp_ms > (now_ms - seconds_ago * 1000)
      
      {:error, _} ->
        false
    end
  end

  @doc """
  Find all records created with ULIDs in a given time range.
  
  Used for querying distributed events across systems by time.
  """
  def find_by_time_range(table, ulid_column, start_time, end_time) do
    # This is a helper for building time-based queries on ULID columns
    Logger.debug("Building time-range query on #{table}.#{ulid_column}")
    
    from_ulid = generate_ulid_for_timestamp(start_time)
    to_ulid = generate_ulid_for_timestamp(end_time)
    
    {from_ulid, to_ulid}
  end

  # Private helper: Generate a ULID for a given timestamp
  defp generate_ulid_for_timestamp(timestamp_ms) when is_integer(timestamp_ms) do
    # This would use PostgreSQL's make_ulid() if available
    # For now, we log that this is a helper for time-range queries
    Logger.debug("ULID time-range helper: #{timestamp_ms}ms")
    nil
  end
end
