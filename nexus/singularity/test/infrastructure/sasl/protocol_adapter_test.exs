defmodule Singularity.Infrastructure.Sasl.ProtocolAdapterTest do
  use ExUnit.Case, async: true

  alias Singularity.Infrastructure.Sasl.ProtocolAdapter

  doctest Singularity.Infrastructure.Sasl.ProtocolAdapter

  describe "authenticate_protocol/4" do
    test "authenticates via diameter protocol successfully" do
      credentials = %{username: "admin", password: "admin_password"}
      diameter_message = %{
        avps: [
          {"User-Name", "admin"},
          {"Session-Id", "diameter_session_123"},
          {"Origin-Host", "hss.singularity"},
          {"Origin-Realm", "singularity"}
        ]
      }

      assert {:ok, context} = ProtocolAdapter.authenticate_protocol(credentials, :diameter, diameter_message)
      assert context.user_id == "admin"
      assert context.mechanism == :diameter
      assert Map.has_key?(context, :diameter_session_id)
    end

    test "authenticates via radius protocol successfully" do
      credentials = %{username: "radius_admin", password: "radius_secret"}
      radius_message = %{
        code: "Access-Request",
        identifier: 1,
        authenticator: "radius_authenticator_data",
        attributes: [
          {"User-Name", "radius_admin"},
          {"NAS-Identifier", "singularity-nas"},
          {"Service-Type", "Login-User"}
        ]
      }

      assert {:ok, context} = ProtocolAdapter.authenticate_protocol(credentials, :radius, radius_message)
      assert context.user_id == "radius_admin"
      assert context.mechanism == :radius
      assert Map.has_key?(context, :radius_session_id)
    end

    test "authenticates via ss7 protocol successfully" do
      credentials = %{username: "ss7_admin", password: "ss7_secret"}
      ss7_message = %{
        message_type: "Connection-Request",
        calling_address: "1-234-5",
        called_address: "1-234-6",
        parameters: [
          {"Global-Title", "ss7_admin"},
          {"Point-Code", "1-234-5"},
          {"Subsystem-Number", 3}
        ]
      }

      assert {:ok, context} = ProtocolAdapter.authenticate_protocol(credentials, :ss7, ss7_message)
      assert context.user_id == "ss7_admin"
      assert context.mechanism == :ss7
      assert Map.has_key?(context, :ss7_session_id)
    end

    test "fails authentication with invalid credentials" do
      credentials = %{username: "invalid", password: "wrong"}
      diameter_message = %{avps: [{"User-Name", "invalid"}]}

      assert {:error, reason} = ProtocolAdapter.authenticate_protocol(credentials, :diameter, diameter_message)
      assert String.contains?(reason, "Protocol authentication failed")
    end

    test "fails with unsupported protocol" do
      credentials = %{username: "admin", password: "secret"}
      message = %{}

      assert {:error, reason} = ProtocolAdapter.authenticate_protocol(credentials, :unsupported, message)
      assert String.contains?(reason, "Protocol authentication failed")
    end
  end

  describe "generate_protocol_challenge/2" do
    test "generates challenge for diameter protocol" do
      assert {:ok, challenge} = ProtocolAdapter.generate_protocol_challenge(:diameter)
      assert is_binary(challenge)
      assert byte_size(challenge) > 0
    end

    test "generates challenge for radius protocol" do
      assert {:ok, challenge} = ProtocolAdapter.generate_protocol_challenge(:radius)
      assert is_binary(challenge)
      assert byte_size(challenge) > 0
    end

    test "generates challenge for ss7 protocol" do
      assert {:ok, challenge} = ProtocolAdapter.generate_protocol_challenge(:ss7)
      assert is_binary(challenge)
      assert byte_size(challenge) > 0
    end

    test "fails for unsupported protocol" do
      assert {:error, reason} = ProtocolAdapter.generate_protocol_challenge(:unsupported)
      assert String.contains?(reason, "Unsupported SASL mechanism")
    end
  end

  describe "verify_protocol_response/4" do
    test "verifies response for diameter protocol" do
      challenge = "diameter_challenge_data"
      response = "diameter_response_data"

      assert {:ok, context} = ProtocolAdapter.verify_protocol_response(:diameter, challenge, response)
      assert context.mechanism == :diameter
      assert context.challenge == challenge
      assert context.response == response
    end

    test "verifies response for radius protocol" do
      challenge = "radius_challenge_data"
      response = "radius_response_data"

      assert {:ok, context} = ProtocolAdapter.verify_protocol_response(:radius, challenge, response)
      assert context.mechanism == :radius
    end

    test "fails for unsupported protocol" do
      challenge = "test_challenge"
      response = "test_response"

      assert {:error, reason} = ProtocolAdapter.verify_protocol_response(:unsupported, challenge, response)
      assert String.contains?(reason, "Unsupported SASL mechanism")
    end
  end

  describe "extract_credentials/2" do
    test "extracts credentials from diameter message" do
      diameter_message = %{
        avps: [
          {"User-Name", "admin"},
          {"User-Password", "secret"},
          {"Session-Id", "session_123"},
          {"Origin-Host", "hss.example.com"}
        ]
      }

      assert {:ok, credentials} = ProtocolAdapter.extract_credentials(:diameter, diameter_message)
      assert credentials.username == "admin"
      assert credentials.password == "secret"
      assert credentials.session_id == "session_123"
      assert credentials.origin_host == "hss.example.com"
      assert credentials.telecom_context.protocol == "diameter"
    end

    test "extracts credentials from radius message" do
      radius_message = %{
        attributes: [
          {"User-Name", "radius_user"},
          {"User-Password", "radius_secret"},
          {"NAS-Identifier", "nas_01"},
          {"Called-Station-Id", "555-1234"}
        ]
      }

      assert {:ok, credentials} = ProtocolAdapter.extract_credentials(:radius, radius_message)
      assert credentials.username == "radius_user"
      assert credentials.password == "radius_secret"
      assert credentials.nas_identifier == "nas_01"
      assert credentials.called_station_id == "555-1234"
      assert credentials.telecom_context.protocol == "radius"
    end

    test "extracts credentials from ss7 message" do
      ss7_message = %{
        parameters: [
          {"Calling-Party-Address", "ss7_user"},
          {"Global-Title", "123456789"},
          {"Point-Code", "1-234-5"},
          {"Subsystem-Number", 3}
        ]
      }

      assert {:ok, credentials} = ProtocolAdapter.extract_credentials(:ss7, ss7_message)
      assert credentials.username == "ss7_user"
      assert credentials.global_title == "123456789"
      assert credentials.point_code == "1-234-5"
      assert credentials.subsystem_number == 3
      assert credentials.telecom_context.protocol == "ss7"
    end

    test "fails for unsupported protocol" do
      message = %{}

      assert {:error, reason} = ProtocolAdapter.extract_credentials(:unsupported, message)
      assert String.contains?(reason, "Unsupported protocol")
    end
  end

  describe "create_protocol_response/3" do
    test "creates diameter response for successful authentication" do
      context = %{
        user_id: "admin",
        diameter_session_id: "diameter_session_123",
        session_timeout: 3600
      }

      response = ProtocolAdapter.create_protocol_response(:diameter, context, true)

      assert response.session_id == "diameter_session_123"
      assert response.result_code == "DIAMETER_SUCCESS"
      assert response.user_name == "admin"
    end

    test "creates diameter response for failed authentication" do
      context = %{user_id: "invalid", diameter_session_id: "session_456"}

      response = ProtocolAdapter.create_protocol_response(:diameter, context, false)

      assert response.result_code == "DIAMETER_AUTHENTICATION_REJECTED"
      assert response.user_name == "invalid"
    end

    test "creates radius response for successful authentication" do
      context = %{
        user_id: "radius_user",
        radius_session_id: "radius_session_789",
        session_timeout: 1800
      }

      response = ProtocolAdapter.create_protocol_response(:radius, context, true)

      assert response.code == "Access-Accept"
      assert response.attributes |> Enum.find(fn {k, _} -> k == "User-Name" end)
      assert response.attributes |> Enum.find(fn {k, v} -> k == "Session-Timeout" && v == 1800 end)
    end

    test "creates ss7 response for successful authentication" do
      context = %{
        user_id: "ss7_user",
        calling_address: "1-234-5",
        called_address: "1-234-6"
      }

      response = ProtocolAdapter.create_protocol_response(:ss7, context, true)

      assert response.message_type == "Connection-Confirm"
      assert response.source_address == "1-234-5"
      assert response.destination_address == "1-234-6"
      assert response.result == "Authentication-Successful"
    end
  end

  describe "protocol-specific features" do
    test "handles telecom-specific context in diameter" do
      credentials = %{username: "admin", password: "admin_password"}
      diameter_message = %{
        avps: [
          {"User-Name", "admin"},
          {"Node-Type", "HSS"},
          {"Network-Type", "Core"}
        ]
      }

      assert {:ok, context} = ProtocolAdapter.authenticate_protocol(credentials, :diameter, diameter_message)
      assert context.telecom_context.node_type == "hss"
      assert context.telecom_context.network == "core"
    end

    test "handles framed information in radius" do
      credentials = %{username: "radius_admin", password: "radius_secret"}
      radius_message = %{
        attributes: [
          {"User-Name", "radius_admin"},
          {"Framed-Protocol", "PPP"},
          {"Framed-IP-Address", "192.168.1.100"}
        ]
      }

      assert {:ok, context} = ProtocolAdapter.authenticate_protocol(credentials, :radius, radius_message)
      assert Map.has_key?(context, :framed_info)
    end

    test "handles global title routing in ss7" do
      credentials = %{username: "ss7_admin", password: "ss7_secret"}
      ss7_message = %{
        parameters: [
          {"Global-Title", "123456789"},
          {"Node-Type", "STP"}
        ]
      }

      assert {:ok, context} = ProtocolAdapter.authenticate_protocol(credentials, :ss7, ss7_message)
      assert context.global_title == "123456789"
      assert context.telecom_context.node_type == "stp"
    end
  end
end