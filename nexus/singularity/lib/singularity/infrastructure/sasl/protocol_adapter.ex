defmodule Singularity.Infrastructure.Sasl.ProtocolAdapter do
  @moduledoc """
  Protocol adapters for telecom systems integration with SASL.

  This module provides adapters for integrating SASL authentication with
  various telecommunications protocols including Diameter, RADIUS, and SS7.

  ## Features

  - Diameter protocol SASL integration
  - RADIUS protocol SASL integration
  - SS7 protocol SASL integration
  - Telecom-grade session management
  - Protocol-specific AVP/attribute handling

  ## Protocol Support

  - **Diameter**: 3G/4G/5G network authentication
  - **RADIUS**: Network access authentication
  - **SS7**: Legacy telecom signaling authentication
  """

  alias Singularity.Infrastructure.Sasl
  alias Singularity.Infrastructure.Sasl.{Mechanism, Security}

  require Logger

  @type protocol_type :: :diameter | :radius | :ss7 | :sigtran
  @type protocol_message :: map()
  @type adapter_result :: {:ok, map()} | {:error, String.t()}

  # ============================================================================
  # Public API - Protocol Integration
  # ============================================================================

  @doc """
  Authenticate using telecom protocol-specific SASL mechanism.

  ## Parameters

  - `credentials` - Authentication credentials
  - `protocol` - Telecom protocol type
  - `message` - Protocol-specific message data
  - `opts` - Additional options

  ## Returns

  - `{:ok, context}` - Authentication successful
  - `{:error, reason}` - Authentication failed

  ## Examples

      iex> ProtocolAdapter.authenticate_diameter(%{username: "admin", password: "secret"}, diameter_message)
      {:ok, %{user_id: "admin", mechanism: :diameter, session_id: "abc123"}}

      iex> ProtocolAdapter.authenticate_radius(%{username: "user", password: "pass"}, radius_request)
      {:ok, %{user_id: "user", mechanism: :radius, attributes: %{...}}}
  """
  @spec authenticate_protocol(map(), protocol_type(), protocol_message(), keyword()) ::
          adapter_result()
  def authenticate_protocol(credentials, protocol, message, opts \\ []) do
    Logger.debug("Protocol SASL authentication: protocol=#{protocol}")

    with {:ok, mechanism} <- get_protocol_mechanism(protocol),
         {:ok, protocol_credentials} <- adapt_credentials(credentials, protocol, message),
         {:ok, context} <- Sasl.authenticate(protocol_credentials, mechanism, opts) do
      Logger.info("Protocol SASL authentication successful: protocol=#{protocol}")
      {:ok, context}
    else
      {:error, reason} ->
        Logger.warning("Protocol SASL authentication failed: #{reason}")
        {:error, "Protocol authentication failed: #{reason}"}
    end
  end

  @doc """
  Generate protocol-specific challenge for mutual authentication.

  ## Parameters

  - `protocol` - Telecom protocol type
  - `opts` - Challenge generation options

  ## Returns

  - `{:ok, challenge}` - Challenge generated successfully
  - `{:error, reason}` - Challenge generation failed
  """
  @spec generate_protocol_challenge(protocol_type(), keyword()) :: adapter_result()
  def generate_protocol_challenge(protocol, opts \\ []) do
    case get_protocol_mechanism(protocol) do
      {:ok, mechanism} -> Sasl.generate_challenge(mechanism, opts)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Verify protocol-specific response to challenge.

  ## Parameters

  - `protocol` - Telecom protocol type
  - `challenge` - Original challenge
  - `response` - Protocol response
  - `opts` - Verification options

  ## Returns

  - `{:ok, context}` - Response verified successfully
  - `{:error, reason}` - Response verification failed
  """
  @spec verify_protocol_response(protocol_type(), binary(), binary(), keyword()) ::
          adapter_result()
  def verify_protocol_response(protocol, challenge, response, opts \\ []) do
    case get_protocol_mechanism(protocol) do
      {:ok, mechanism} -> Sasl.verify_response(challenge, response, mechanism, opts)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Extract SASL credentials from protocol message.

  ## Parameters

  - `protocol` - Telecom protocol type
  - `message` - Protocol message to extract from

  ## Returns

  - `{:ok, credentials}` - Credentials extracted successfully
  - `{:error, reason}` - Credential extraction failed
  """
  @spec extract_credentials(protocol_type(), protocol_message()) :: adapter_result()
  def extract_credentials(protocol, message) do
    case protocol do
      :diameter -> extract_diameter_credentials(message)
      :radius -> extract_radius_credentials(message)
      :ss7 -> extract_ss7_credentials(message)
      :sigtran -> extract_sigtran_credentials(message)
      _ -> {:error, "Unsupported protocol: #{protocol}"}
    end
  end

  @doc """
  Create protocol-specific response message.

  ## Parameters

  - `protocol` - Telecom protocol type
  - `context` - SASL authentication context
  - `result` - Authentication result

  ## Returns

  - Protocol-specific response message
  """
  @spec create_protocol_response(protocol_type(), map(), boolean()) :: protocol_message()
  def create_protocol_response(protocol, context, result) do
    case protocol do
      :diameter -> create_diameter_response(context, result)
      :radius -> create_radius_response(context, result)
      :ss7 -> create_ss7_response(context, result)
      :sigtran -> create_sigtran_response(context, result)
    end
  end

  # ============================================================================
  # Private Helpers - Protocol Adapters
  # ============================================================================

  defp get_protocol_mechanism(protocol) do
    case protocol do
      :diameter -> {:ok, :diameter}
      :radius -> {:ok, :radius}
      :ss7 -> {:ok, :ss7}
      # SIGTRAN uses Diameter SASL
      :sigtran -> {:ok, :diameter}
      _ -> {:error, "Unsupported protocol: #{protocol}"}
    end
  end

  defp adapt_credentials(credentials, protocol, message) do
    # Adapt generic credentials to protocol-specific format
    protocol_data = extract_protocol_data(protocol, message)

    adapted_credentials =
      credentials
      |> Map.merge(protocol_data)
      |> Map.put(:protocol, protocol)
      |> Map.put(:timestamp, DateTime.utc_now())

    {:ok, adapted_credentials}
  end

  defp extract_protocol_data(protocol, message) do
    case protocol do
      :diameter -> extract_diameter_data(message)
      :radius -> extract_radius_data(message)
      :ss7 -> extract_ss7_data(message)
      :sigtran -> extract_sigtran_data(message)
      _ -> %{}
    end
  end

  # ============================================================================
  # Diameter Protocol Adapter
  # ============================================================================

  defp extract_diameter_credentials(message) do
    # Extract credentials from Diameter message
    # Diameter uses AVPs (Attribute-Value Pairs)

    credentials = %{
      username: get_avp_value(message, "User-Name"),
      password: get_avp_value(message, "User-Password"),
      session_id: get_avp_value(message, "Session-Id"),
      origin_host: get_avp_value(message, "Origin-Host"),
      origin_realm: get_avp_value(message, "Origin-Realm")
    }

    # Add telecom-specific context
    telecom_context = %{
      node_type: get_avp_value(message, "Node-Type", "unknown"),
      network: get_avp_value(message, "Network-Type", "core"),
      protocol: "diameter"
    }

    {:ok, Map.put(credentials, :telecom_context, telecom_context)}
  end

  defp extract_diameter_data(message) do
    %{
      diameter_session_id: get_avp_value(message, "Session-Id"),
      application_id: get_avp_value(message, "Application-Id"),
      command_code: get_avp_value(message, "Command-Code"),
      avp_data: message[:avps] || []
    }
  end

  defp create_diameter_response(context, result) do
    # Create Diameter response message
    %{
      session_id: Map.get(context, :diameter_session_id),
      result_code: if(result, do: "DIAMETER_SUCCESS", else: "DIAMETER_AUTHENTICATION_REJECTED"),
      origin_host: "singularity.singularity",
      origin_realm: "singularity",
      user_name: Map.get(context, :user_id),
      auth_session_state: "NO_STATE_MAINTAINED"
    }
  end

  # ============================================================================
  # RADIUS Protocol Adapter
  # ============================================================================

  defp extract_radius_credentials(message) do
    # Extract credentials from RADIUS message

    credentials = %{
      username: get_radius_attribute(message, "User-Name"),
      password: get_radius_attribute(message, "User-Password"),
      nas_identifier: get_radius_attribute(message, "NAS-Identifier"),
      nas_ip_address: get_radius_attribute(message, "NAS-IP-Address"),
      called_station_id: get_radius_attribute(message, "Called-Station-Id"),
      calling_station_id: get_radius_attribute(message, "Calling-Station-Id")
    }

    # Add telecom-specific context
    telecom_context = %{
      node_type: "nas",
      network: "access",
      protocol: "radius",
      service_type: get_radius_attribute(message, "Service-Type")
    }

    {:ok, Map.put(credentials, :telecom_context, telecom_context)}
  end

  defp extract_radius_data(message) do
    %{
      radius_code: message[:code],
      identifier: message[:identifier],
      authenticator: message[:authenticator],
      attributes: message[:attributes] || []
    }
  end

  defp create_radius_response(context, result) do
    # Create RADIUS response message
    %{
      code: if(result, do: "Access-Accept", else: "Access-Reject"),
      identifier: Map.get(context, :radius_identifier),
      authenticator: generate_radius_authenticator(),
      attributes: [
        {"User-Name", Map.get(context, :user_id)},
        {"Session-Timeout", Map.get(context, :session_timeout, 3600)}
      ]
    }
  end

  # ============================================================================
  # SS7 Protocol Adapter
  # ============================================================================

  defp extract_ss7_credentials(message) do
    # Extract credentials from SS7 message

    credentials = %{
      username: get_ss7_parameter(message, "Calling-Party-Address"),
      global_title: get_ss7_parameter(message, "Global-Title"),
      point_code: get_ss7_parameter(message, "Point-Code"),
      subsystem_number: get_ss7_parameter(message, "Subsystem-Number")
    }

    # Add telecom-specific context
    telecom_context = %{
      node_type: get_ss7_node_type(message),
      network: "ss7",
      protocol: "ss7",
      signaling_link: get_ss7_parameter(message, "Signaling-Link")
    }

    {:ok, Map.put(credentials, :telecom_context, telecom_context)}
  end

  defp extract_ss7_data(message) do
    %{
      sccp_message_type: message[:message_type],
      tcap_transaction_id: message[:transaction_id],
      dialogue_id: message[:dialogue_id],
      application_context: message[:application_context]
    }
  end

  defp create_ss7_response(context, result) do
    # Create SS7 response message
    %{
      message_type: if(result, do: "Connection-Confirm", else: "Connection-Refuse"),
      source_address: Map.get(context, :calling_address),
      destination_address: Map.get(context, :called_address),
      result: if(result, do: "Authentication-Successful", else: "Authentication-Failed")
    }
  end

  # ============================================================================
  # SIGTRAN Protocol Adapter
  # ============================================================================

  defp extract_sigtran_credentials(message) do
    # SIGTRAN uses similar format to SS7 but over IP
    extract_ss7_credentials(message)
    |> Map.put(:protocol, "sigtran")
    |> Map.put(:transport, "sctp")
  end

  defp extract_sigtran_data(message) do
    data = extract_ss7_data(message)
    Map.put(data, :transport, "sctp")
  end

  defp create_sigtran_response(context, result) do
    response = create_ss7_response(context, result)
    Map.put(response, :transport, "sctp")
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp get_avp_value(message, avp_name, default \\ nil) do
    avps = Map.get(message, :avps, [])

    case Enum.find(avps, fn {name, _value} -> name == avp_name end) do
      {_name, value} -> value
      nil -> default
    end
  end

  defp get_radius_attribute(message, attribute_name, default \\ nil) do
    attributes = Map.get(message, :attributes, [])

    case Enum.find(attributes, fn {name, _value} -> name == attribute_name end) do
      {_name, value} -> value
      nil -> default
    end
  end

  defp get_ss7_parameter(message, parameter_name, default \\ nil) do
    parameters = Map.get(message, :parameters, [])

    case Enum.find(parameters, fn {name, _value} -> name == parameter_name end) do
      {_name, value} -> value
      nil -> default
    end
  end

  defp get_ss7_node_type(message) do
    case get_ss7_parameter(message, "Node-Type") do
      "STP" -> "stp"
      "MSC" -> "msc"
      "HLR" -> "hlr"
      "VLR" -> "vlr"
      _ -> "unknown"
    end
  end

  defp generate_radius_authenticator do
    # Generate RADIUS authenticator (16 bytes)
    :crypto.strong_rand_bytes(16)
  end
end
