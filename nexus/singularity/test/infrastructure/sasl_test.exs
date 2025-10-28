defmodule Singularity.Infrastructure.SaslTest do
  use ExUnit.Case, async: true

  alias Singularity.Infrastructure.Sasl
  alias Singularity.Infrastructure.Sasl.{Mechanism, Security}

  doctest Singularity.Infrastructure.Sasl

  describe "authenticate/3" do
    test "authenticates with diameter mechanism successfully" do
      credentials = %{username: "admin", password: "secret"}

      assert {:ok, context} = Sasl.authenticate(credentials, :diameter)
      assert context.user_id == "admin"
      assert context.mechanism == :diameter
      assert Map.has_key?(context, :session_id)
      assert Map.has_key?(context, :authenticated_at)
    end

    test "authenticates with radius mechanism successfully" do
      credentials = %{username: "radius_admin", password: "radius_secret"}

      assert {:ok, context} = Sasl.authenticate(credentials, :radius)
      assert context.user_id == "radius_admin"
      assert context.mechanism == :radius
      assert Map.has_key?(context, :session_id)
    end

    test "authenticates with ss7 mechanism successfully" do
      credentials = %{username: "ss7_admin", password: "ss7_secret"}

      assert {:ok, context} = Sasl.authenticate(credentials, :ss7)
      assert context.user_id == "ss7_admin"
      assert context.mechanism == :ss7
      assert Map.has_key?(context, :session_id)
    end

    test "authenticates with scram mechanism successfully" do
      credentials = %{username: "scram_admin", password: "scram_secret"}

      assert {:ok, context} = Sasl.authenticate(credentials, :standard_scram)
      assert context.user_id == "scram_admin"
      assert context.mechanism == :standard_scram
      assert Map.has_key?(context, :session_id)
    end

    test "fails authentication with invalid credentials" do
      credentials = %{username: "invalid", password: "wrong"}

      assert {:error, reason} = Sasl.authenticate(credentials, :diameter)
      assert String.contains?(reason, "Authentication failed")
    end

    test "fails authentication with missing username" do
      credentials = %{password: "secret"}

      assert {:error, reason} = Sasl.authenticate(credentials, :diameter)
      assert String.contains?(reason, "Invalid credentials")
    end

    test "fails authentication with unsupported mechanism" do
      credentials = %{username: "admin", password: "secret"}

      assert {:error, reason} = Sasl.authenticate(credentials, :unsupported)
      assert String.contains?(reason, "Unsupported SASL mechanism")
    end
  end

  describe "generate_challenge/2" do
    test "generates challenge for diameter mechanism" do
      assert {:ok, challenge} = Sasl.generate_challenge(:diameter)
      assert is_binary(challenge)
      assert byte_size(challenge) > 0
    end

    test "generates challenge for radius mechanism" do
      assert {:ok, challenge} = Sasl.generate_challenge(:radius)
      assert is_binary(challenge)
      assert byte_size(challenge) > 0
    end

    test "fails to generate challenge for unsupported mechanism" do
      assert {:error, reason} = Sasl.generate_challenge(:unsupported)
      assert String.contains?(reason, "Unsupported SASL mechanism")
    end
  end

  describe "verify_response/4" do
    test "verifies response for diameter mechanism" do
      challenge = "test_challenge"
      response = "test_response"

      assert {:ok, context} = Sasl.verify_response(challenge, response, :diameter)
      assert context.mechanism == :diameter
      assert context.challenge == challenge
      assert context.response == response
    end

    test "fails to verify response for unsupported mechanism" do
      challenge = "test_challenge"
      response = "test_response"

      assert {:error, reason} = Sasl.verify_response(challenge, response, :unsupported)
      assert String.contains?(reason, "Unsupported SASL mechanism")
    end
  end

  describe "supported_mechanisms/0" do
    test "returns list of supported mechanisms" do
      mechanisms = Sasl.supported_mechanisms()

      assert :diameter in mechanisms
      assert :radius in mechanisms
      assert :ss7 in mechanisms
      assert :standard_scram in mechanisms
      assert length(mechanisms) == 4
    end
  end

  describe "get_mechanism_info/1" do
    test "returns info for diameter mechanism" do
      assert {:ok, info} = Sasl.get_mechanism_info(:diameter)
      assert info.name == "Diameter SASL"
      assert info.mechanism == :diameter
      assert info.security_level == :high
      assert :mutual_authentication in info.features
    end

    test "returns info for radius mechanism" do
      assert {:ok, info} = Sasl.get_mechanism_info(:radius)
      assert info.name == "RADIUS SASL"
      assert info.mechanism == :radius
      assert info.security_level == :medium
      assert :pap_authentication in info.features
    end

    test "fails for unsupported mechanism" do
      assert {:error, reason} = Sasl.get_mechanism_info(:unsupported)
      assert String.contains?(reason, "Unsupported SASL mechanism")
    end
  end

  describe "validate_context/3" do
    test "validates context successfully" do
      context = %{
        user_id: "admin",
        mechanism: :diameter,
        session_id: "test_session",
        authenticated_at: DateTime.utc_now(),
        permissions: ["read", "write"]
      }

      assert {:ok, updated_context} =
               Sasl.validate_context(context, :read_operation, "test_resource")

      assert updated_context == context
    end

    test "fails validation with expired session" do
      # 1 hour ago
      expired_time = DateTime.add(DateTime.utc_now(), -3600, :second)

      context = %{
        user_id: "admin",
        mechanism: :diameter,
        session_id: "test_session",
        authenticated_at: expired_time,
        permissions: ["read"]
      }

      assert {:error, reason} = Sasl.validate_context(context, :read_operation, "test_resource")
      assert String.contains?(reason, "Session expired")
    end

    test "fails validation with insufficient permissions" do
      context = %{
        user_id: "user",
        mechanism: :diameter,
        session_id: "test_session",
        authenticated_at: DateTime.utc_now(),
        permissions: ["read"]
      }

      assert {:error, reason} = Sasl.validate_context(context, :admin_operation, "admin_resource")
      assert String.contains?(reason, "Missing required permissions")
    end
  end

  describe "integration with security validator" do
    test "SASL security checks are included in validation" do
      # This test ensures SASL security patterns are checked
      code_with_violation = """
      defmodule TestModule do
        def authenticate(user_input) do
          :crypto.hash_equals(user_input, "password")  # Missing crypto.hash_equals
        end
      end
      """

      # The security validator should catch SASL-related violations
      assert {:error, violations} =
               Singularity.Validators.SecurityValidator.validate(code_with_violation)

      assert Enum.any?(violations, &String.contains?(&1, "SASL Security"))
    end
  end
end
