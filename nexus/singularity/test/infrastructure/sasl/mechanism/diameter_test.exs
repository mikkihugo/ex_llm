defmodule Singularity.Infrastructure.Sasl.Mechanism.DiameterTest do
  use ExUnit.Case, async: true

  alias Singularity.Infrastructure.Sasl.Mechanism.Diameter

  doctest Singularity.Infrastructure.Sasl.Mechanism.Diameter

  describe "authenticate/2" do
    test "authenticates admin user successfully" do
      credentials = %{username: "admin", password: "admin_password"}

      assert {:ok, context} = Diameter.authenticate(credentials)
      assert context.user_id == "admin"
      assert context.mechanism == :diameter
      assert Map.has_key?(context, :diameter_session_id)
      assert Map.has_key?(context, :avp_data)
      assert Map.has_key?(context, :network_context)
    end

    test "authenticates operator user successfully" do
      credentials = %{username: "operator", password: "operator_password"}

      assert {:ok, context} = Diameter.authenticate(credentials)
      assert context.user_id == "operator"
      assert context.mechanism == :diameter
      assert context.telecom_context.node_type == "mme"
      assert context.telecom_context.network == "access"
    end

    test "fails authentication with wrong password" do
      credentials = %{username: "admin", password: "wrong_password"}

      assert {:error, reason} = Diameter.authenticate(credentials)
      assert String.contains?(reason, "Authentication failed")
    end

    test "fails authentication with non-existent user" do
      credentials = %{username: "nonexistent", password: "password"}

      assert {:error, reason} = Diameter.authenticate(credentials)
      assert String.contains?(reason, "User not found")
    end
  end

  describe "generate_challenge/1" do
    test "generates challenge with default size" do
      assert {:ok, challenge} = Diameter.generate_challenge()
      assert is_binary(challenge)
      assert byte_size(challenge) == 32  # Default challenge size
    end

    test "generates challenge with custom size" do
      assert {:ok, challenge} = Diameter.generate_challenge(challenge_size: 64)
      assert is_binary(challenge)
      assert byte_size(challenge) == 64
    end
  end

  describe "verify_response/3" do
    test "verifies valid response successfully" do
      challenge = "test_challenge_32_bytes_long"
      response = "valid_response_data_with_timestamp"

      assert {:ok, context} = Diameter.verify_response(challenge, response)
      assert context.mechanism == :diameter
      assert context.challenge == challenge
      assert context.response == response
      assert Map.has_key?(context, :verified_at)
      assert Map.has_key?(context, :replay_protection)
    end

    test "fails verification with too short response" do
      challenge = "test_challenge_32_bytes_long"
      response = "short"

      assert {:error, reason} = Diameter.verify_response(challenge, response)
      assert String.contains?(reason, "Invalid response format")
    end
  end

  describe "get_info/0" do
    test "returns correct mechanism information" do
      info = Diameter.get_info()

      assert info.name == "Diameter SASL"
      assert info.mechanism == :diameter
      assert info.description == "Diameter protocol authentication for telecommunications"
      assert info.security_level == :high
      assert :mutual_authentication in info.features
      assert :challenge_response in info.features
      assert :replay_protection in info.features
      assert :avp_support in info.features
      assert :telecom_grade_security in info.features
    end
  end

  describe "integration with telecom protocols" do
    test "handles telecom-specific credentials" do
      credentials = %{
        username: "admin",
        password: "admin_password",
        network_context: %{node_type: "hss", network: "core"},
        session_timeout: 1800,
        service_type: "authentication"
      }

      assert {:ok, context} = Diameter.authenticate(credentials)
      assert context.network_context.node_type == "hss"
      assert context.network_context.network == "core"
    end

    test "includes AVP data in context" do
      credentials = %{username: "admin", password: "admin_password"}

      assert {:ok, context} = Diameter.authenticate(credentials)
      assert Map.has_key?(context, :avp_data)

      avp_data = context.avp_data
      assert avp_data.user_name == "admin"
      assert avp_data.service_type == "authenticate-only"
      assert is_integer(avp_data.session_timeout)
    end
  end

  describe "security features" do
    test "generates unique session IDs" do
      credentials = %{username: "admin", password: "admin_password"}

      assert {:ok, context1} = Diameter.authenticate(credentials)
      assert {:ok, context2} = Diameter.authenticate(credentials)

      assert context1.diameter_session_id != context2.diameter_session_id
    end

    test "includes replay protection" do
      challenge = "test_challenge"
      response = "test_response_with_sufficient_length_for_validation"

      assert {:ok, context} = Diameter.verify_response(challenge, response)
      assert Map.has_key?(context, :replay_protection)
      assert is_binary(context.replay_protection)
      assert String.length(context.replay_protection) > 0
    end
  end
end