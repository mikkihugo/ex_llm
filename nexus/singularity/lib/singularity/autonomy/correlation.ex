defmodule Singularity.Autonomy.Correlation do
  @moduledoc """
  Correlation tracking for autonomous operations.

  Provides correlation IDs for tracking related operations across
  the system, enabling better observability and debugging.
  """

  require Logger

  @doc """
  Start a new correlation context.

  ## Parameters
  - `correlation_id` - String identifier for the correlation

  ## Returns
  - Correlation ID string
  """
  def start(correlation_id) when is_binary(correlation_id) do
    Logger.metadata(correlation_id: correlation_id)
    correlation_id
  end

  def start(context) when is_map(context) do
    correlation_id =
      Map.get(context, :correlation_id) ||
        Map.get(context, :id) ||
        generate_correlation_id()

    start(correlation_id)
  end

  def start(_other) do
    correlation_id = generate_correlation_id()
    start(correlation_id)
  end

  @doc """
  Get the current correlation ID from logger metadata.
  """
  def current_id do
    case Logger.metadata()[:correlation_id] do
      nil -> generate_correlation_id()
      id -> id
    end
  end

  @doc """
  Execute a function within a correlation context.
  """
  def with_correlation(correlation_id, fun) when is_function(fun, 0) do
    old_metadata = Logger.metadata()

    try do
      Logger.metadata(correlation_id: correlation_id)
      fun.()
    after
      Logger.metadata(old_metadata)
    end
  end

  @doc """
  Generate a new correlation ID.
  """
  def generate_correlation_id do
    # Generate a UUID-like correlation ID
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
    |> String.slice(0, 8)
    |> then(&"corr_#{&1}")
  end

  @doc """
  Check if a correlation ID is valid.
  """
  def valid_correlation_id?(correlation_id) when is_binary(correlation_id) do
    String.match?(correlation_id, ~r/^corr_[a-f0-9]{8}$/)
  end

  def valid_correlation_id?(_), do: false
end
