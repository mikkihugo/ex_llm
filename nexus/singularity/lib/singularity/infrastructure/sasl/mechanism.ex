defmodule Singularity.Infrastructure.Sasl.Mechanism do
  @moduledoc """
  Base module for SASL mechanism implementations.

  This module defines the behavior that all SASL mechanisms must implement,
  providing a consistent interface for different authentication protocols used in
  telecommunications systems.
  """

  alias Singularity.Infrastructure.Sasl.Security

  @type credentials :: map()
  @type options :: keyword()
  @type context :: map()
  @type challenge :: binary()
  @type response :: binary()

  @doc """
  Behavior definition for SASL mechanisms.
  """
  @callback authenticate(credentials(), options()) :: {:ok, context()} | {:error, String.t()}
  @callback generate_challenge(options()) :: {:ok, challenge()} | {:error, String.t()}
  @callback verify_response(challenge(), response(), options()) :: {:ok, context()} | {:error, String.t()}
  @callback get_info() :: map()

  @doc """
  Generate a cryptographically secure random challenge.

  ## Parameters

  - `size` - Size of challenge in bytes (default: 32)

  ## Returns

  - Binary challenge of specified size
  """
  @spec generate_secure_challenge(pos_integer()) :: binary()
  def generate_secure_challenge(size \\ 32) do
    :crypto.strong_rand_bytes(size)
  end

  @doc """
  Hash password using telecom-grade hashing (PBKDF2 with high iteration count).

  ## Parameters

  - `password` - Password to hash
  - `salt` - Salt for hashing (optional, will generate if not provided)
  - `iterations` - Number of iterations (default: 100000 for telecom security)

  ## Returns

  - `{:ok, hash, salt}` - Hashed password with salt
  - `{:error, reason}` - Hashing failed
  """
  @spec hash_password(String.t(), binary() | nil, pos_integer()) :: {:ok, binary(), binary()} | {:error, String.t()}
  def hash_password(password, salt \\ nil, iterations \\ 100_000) do
    salt = salt || generate_secure_challenge(32)

    try do
      hash = :crypto.pbkdf2_hmac(:sha256, password, salt, iterations)
      {:ok, hash, salt}
    rescue
      _ -> {:error, "Password hashing failed"}
    end
  end

  @doc """
  Verify password against stored hash.

  ## Parameters

  - `password` - Password to verify
  - `hash` - Stored password hash
  - `salt` - Salt used for hashing

  ## Returns

  - `true` - Password is correct
  - `false` - Password is incorrect
  """
  @spec verify_password(String.t(), binary(), binary()) :: boolean()
  def verify_password(password, hash, salt) do
    case hash_password(password, salt, 100_000) do
      {:ok, computed_hash, _} -> :crypto.hash_equals(hash, computed_hash)
      {:error, _} -> false
    end
  end

  @doc """
  Create security context for authenticated session.

  ## Parameters

  - `credentials` - Authenticated credentials
  - `mechanism` - SASL mechanism used
  - `additional_info` - Additional context information

  ## Returns

  - Security context map
  """
  @spec create_security_context(credentials(), atom(), map()) :: context()
  def create_security_context(credentials, mechanism, additional_info \\ %{}) do
    %{
      user_id: credentials.username,
      mechanism: mechanism,
      authenticated_at: DateTime.utc_now(),
      session_id: generate_session_id(),
      permissions: Map.get(credentials, :permissions, []),
      telecom_context: Map.get(credentials, :telecom_context, %{})
    }
    |> Map.merge(additional_info)
  end

  @doc """
  Validate security context against operation requirements.

  ## Parameters

  - `context` - Security context to validate
  - `required_permissions` - Required permissions for operation

  ## Returns

  - `{:ok, context}` - Context is valid
  - `{:error, reason}` - Context is invalid or insufficient
  """
  @spec validate_security_context(context(), [String.t()]) :: {:ok, context()} | {:error, String.t()}
  def validate_security_context(context, required_permissions \\ []) do
    Security.validate_context(context, :generic_operation, "system", required_permissions)
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp generate_session_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end
end