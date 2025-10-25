defmodule Nexus.ID do
  @moduledoc """
  ID generation utilities using UUIDv7.

  UUIDv7 provides:
  - Timestamp-based ordering (sortable by creation time)
  - 128-bit random component for uniqueness
  - Compatible with standard UUID format
  - Better database indexing performance than UUIDv4

  ## Examples

      # Generate a new UUIDv7
      id = Nexus.ID.generate()
      # Returns: "019a1cfd-a58f-77cd-abe9-40ce27a2ef8c"

      # Generate multiple IDs (sorted by timestamp)
      ids = [Nexus.ID.generate(), Nexus.ID.generate()]
      # Returns: ["019a1cfd-a58e-7e84-bb05-51b3ad8ba906",
      #           "019a1cfd-a58e-7917-9e56-498bc07d32b6"]

  ## Performance

  UUIDv7 vs UUIDv4 in PostgreSQL:
  - Better INSERT performance (sequential writes)
  - Better INDEX performance (ordered keys)
  - Better SELECT performance (range queries by creation time)
  """

  @doc """
  Generate a new UUIDv7 string.

  Returns a string-formatted UUIDv7 with timestamp ordering.

  ## Examples

      iex> id = Nexus.ID.generate()
      iex> String.length(id)
      36

      iex> id = Nexus.ID.generate()
      iex> String.match?(id, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/)
      true
  """
  @spec generate() :: String.t()
  def generate do
    Uniq.UUID.uuid7()
  end

  @doc """
  Generate a new UUIDv7 in binary format.

  Returns a 16-byte binary representation of UUIDv7.

  ## Examples

      iex> id = Nexus.ID.generate_binary()
      iex> byte_size(id)
      16
  """
  @spec generate_binary() :: binary()
  def generate_binary do
    Uniq.UUID.uuid7(:raw)
  end

  @doc """
  Parse a UUIDv7 string to extract its timestamp.

  Returns the Unix timestamp (milliseconds) embedded in the UUIDv7.

  ## Examples

      iex> id = Nexus.ID.generate()
      iex> {:ok, timestamp} = Nexus.ID.extract_timestamp(id)
      iex> is_integer(timestamp) and timestamp > 0
      true
  """
  @spec extract_timestamp(String.t()) :: {:ok, integer()} | {:error, :invalid_uuid}
  def extract_timestamp(uuid_string) when is_binary(uuid_string) do
    case Uniq.UUID.info(uuid_string) do
      {:ok, uuid} ->
        # Extract timestamp from UUIDv7 struct (field is named 'time')
        {:ok, uuid.time}

      {:error, _} ->
        {:error, :invalid_uuid}
    end
  end

  @doc """
  Check if a string is a valid UUIDv7.

  ## Examples

      iex> id = Nexus.ID.generate()
      iex> Nexus.ID.valid?(id)
      true

      iex> Nexus.ID.valid?("not-a-uuid")
      false

      iex> Nexus.ID.valid?("550e8400-e29b-41d4-a716-446655440000")  # UUIDv4
      false
  """
  @spec valid?(String.t()) :: boolean()
  def valid?(uuid_string) when is_binary(uuid_string) do
    case Uniq.UUID.info(uuid_string) do
      {:ok, uuid} ->
        # Check that it's version 7
        uuid.version == 7

      {:error, _} ->
        false
    end
  end
end
