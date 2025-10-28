defmodule Singularity.Infrastructure.Sasl do
  @moduledoc """
  SASL (Simple Authentication and Security Layer) implementation.

  Provides enhanced SASL mechanisms for telecommunications systems,
  including authentication protocols used in network equipment.

  ## Features

  - Multiple SASL mechanisms (Diameter, RADIUS extensions, SS7)
  - Telecom-grade authentication with mutual authentication
  - Integration with existing Erlang SASL infrastructure
  - Support for network protocols (SS7, SIGTRAN, etc.)
  - Enhanced security for telecommunications systems

  ## Architecture

  This module extends the standard Erlang SASL with telecom-specific
  authentication mechanisms commonly used in network equipment.

  ## Integration Points

  - Extends existing SASL configuration in config.exs
  - Integrates with security validator for policy enforcement
  - Provides Rust NIF implementations for performance-critical operations
  - Supports telecom protocol adapters (Diameter, RADIUS, etc.)
  """

  alias Singularity.Infrastructure.Sasl.{Mechanism, Protocol, Security}

  require Logger

  @type authentication_result :: {:ok, map()} | {:error, String.t()}
  @type sasl_mechanism :: :diameter | :radius | :ss7 | :standard_scram
  @type security_context :: map()

  # ============================================================================
  # Public API - Authentication
  # ============================================================================

  @doc """
  Authenticate using SASL mechanism.

  ## Parameters

  - `credentials` - Authentication credentials (username, password, etc.)
  - `mechanism` - SASL mechanism to use (default: :diameter)
  - `opts` - Additional options for authentication

  ## Returns

  - `{:ok, context}` - Authentication successful with security context
  - `{:error, reason}` - Authentication failed

  ## Examples

      iex> Sasl.authenticate(%{username: "admin", password: "secret"}, :diameter)
      {:ok, %{user_id: "admin", mechanism: :diameter, timestamp: ~U[2025-01-01 12:00:00Z]}}

      iex> Sasl.authenticate(%{username: "invalid", password: "wrong"}, :radius)
      {:error, "Authentication failed: Invalid credentials"}
  """
  @spec authenticate(map(), sasl_mechanism(), keyword()) :: authentication_result()
  def authenticate(credentials, mechanism \\ :diameter, opts \\ []) do
    Logger.debug("SASL authentication attempt: mechanism=#{mechanism}")

    with {:ok, validated_creds} <- validate_credentials(credentials),
         {:ok, mechanism_impl} <- get_mechanism_implementation(mechanism),
         {:ok, context} <- mechanism_impl.authenticate(validated_creds, opts) do
      Logger.info("SASL authentication successful: mechanism=#{mechanism}")
      {:ok, context}
    else
      {:error, reason} ->
        Logger.warning("SASL authentication failed: #{reason}")
        {:error, "Authentication failed: #{reason}"}
    end
  end

  @doc """
  Validate security context for ongoing operations.

  ## Parameters

  - `context` - Security context from successful authentication
  - `operation` - Operation being performed
  - `resource` - Resource being accessed

  ## Returns

  - `{:ok, updated_context}` - Validation successful
  - `{:error, reason}` - Validation failed
  """
  @spec validate_context(security_context(), atom(), String.t()) :: authentication_result()
  def validate_context(context, operation, resource) do
    Security.validate_context(context, operation, resource)
  end

  @doc """
  Generate challenge for mutual authentication.

  Used in protocols requiring mutual authentication (Diameter, etc.).
  """
  @spec generate_challenge(sasl_mechanism(), keyword()) :: {:ok, binary()} | {:error, String.t()}
  def generate_challenge(mechanism, opts \\ []) do
    case get_mechanism_implementation(mechanism) do
      {:ok, mechanism_impl} -> mechanism_impl.generate_challenge(opts)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Verify response to authentication challenge.

  ## Parameters

  - `challenge` - Original challenge sent to client
  - `response` - Client response to challenge
  - `mechanism` - SASL mechanism used
  - `opts` - Additional verification options

  ## Returns

  - `{:ok, context}` - Verification successful
  - `{:error, reason}` - Verification failed
  """
  @spec verify_response(binary(), binary(), sasl_mechanism(), keyword()) ::
          authentication_result()
  def verify_response(challenge, response, mechanism, opts \\ []) do
    case get_mechanism_implementation(mechanism) do
      {:ok, mechanism_impl} -> mechanism_impl.verify_response(challenge, response, opts)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List supported SASL mechanisms.

  ## Returns

  - List of supported mechanism atoms
  """
  @spec supported_mechanisms() :: [sasl_mechanism()]
  def supported_mechanisms do
    [:diameter, :radius, :ss7, :standard_scram]
  end

  @doc """
  Get mechanism capabilities and requirements.

  ## Parameters

  - `mechanism` - SASL mechanism to query

  ## Returns

  - `{:ok, capabilities}` - Mechanism capabilities and requirements
  - `{:error, reason}` - Mechanism not supported
  """
  @spec get_mechanism_info(sasl_mechanism()) :: {:ok, map()} | {:error, String.t()}
  def get_mechanism_info(mechanism) do
    case get_mechanism_implementation(mechanism) do
      {:ok, mechanism_impl} -> {:ok, mechanism_impl.get_info()}
      {:error, reason} -> {:error, reason}
    end
  end

  # ============================================================================
  # Private Helpers - Credential Validation
  # ============================================================================

  defp validate_credentials(credentials) do
    required_fields = [:username]

    case credentials do
      %{username: username} when is_binary(username) and username != "" ->
        {:ok, Map.put(credentials, :timestamp, DateTime.utc_now())}

      _ ->
        {:error, "Invalid credentials: missing or invalid username"}
    end
  end

  defp get_mechanism_implementation(mechanism) do
    case mechanism do
      :diameter -> {:ok, Mechanism.Diameter}
      :radius -> {:ok, Mechanism.Radius}
      :ss7 -> {:ok, Mechanism.SS7}
      :standard_scram -> {:ok, Mechanism.SCRAM}
      _ -> {:error, "Unsupported SASL mechanism: #{mechanism}"}
    end
  end
end
