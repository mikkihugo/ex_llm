defmodule Genesis.Database.DistributedIds do
  @moduledoc """
  Distributed ID generation for Genesis using PostgreSQL pgx_ulid extension.

  Provides ULID generation for cross-system tracking between Genesis and Singularity instances.
  ULIDs are sortable, monotonic IDs ideal for distributed systems.

  ## Migration Path
  - Current: pgx_ulid (PostgreSQL 17)
  - Future: PostgreSQL 18 native UUIDv7 support
  """

  require Logger
  alias Genesis.Repo

  @doc """
  Generate a new ULID for experiment IDs.
  """
  def generate_experiment_id do
    case Repo.query("SELECT gen_ulid()") do
      {:ok, %{rows: [[ulid]]}} -> ulid
      error -> Logger.error("Failed to generate experiment ULID: #{inspect(error)}"); nil
    end
  end

  @doc """
  Generate a new ULID for correlation/request tracking.
  """
  def generate_correlation_id, do: generate_experiment_id()

  @doc """
  Generate a new ULID for distributed tracing.
  """
  def generate_trace_id, do: generate_experiment_id()

  @doc """
  Generate a new ULID for sandbox IDs.
  """
  def generate_sandbox_id, do: generate_experiment_id()

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
      _error -> []
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
