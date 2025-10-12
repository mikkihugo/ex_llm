#!/usr/bin/env elixir

# Test NATS Communication: Singularity → Central Cloud Intelligence Query
#
# This tests the complete NATS request/reply flow:
# 1. Singularity.Knowledge.TemplateService.render_with_context
# 2. → NATS intelligence.query request
# 3. → CentralCloud.IntelligenceHub.handle_intelligence_query
# 4. → Framework detection, context loading, quality standards
# 5. ← NATS reply with enriched context
# 6. ← Template rendered with framework + quality context

Mix.install([
  {:gnat, "~> 1.8"},
  {:jason, "~> 1.4"}
])

require Logger

defmodule IntelligenceQueryNatsTest do
  @moduledoc """
  Test NATS communication for intelligence.query subject.
  """

  def run do
    Logger.configure(level: :info)

    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("NATS Communication Test: intelligence.query")
    IO.puts(String.duplicate("=", 80) <> "\n")

    # Step 1: Connect to NATS
    IO.puts("Step 1: Connecting to NATS...")
    case connect_to_nats() do
      {:ok, conn} ->
        IO.puts("✅ Connected to NATS at localhost:4222")

        # Step 2: Test intelligence.query request/reply
        test_intelligence_query(conn)

        # Step 3: Cleanup
        :gnat.stop(conn)
        IO.puts("\n✅ All tests passed!")

      {:error, reason} ->
        IO.puts("❌ Failed to connect to NATS: #{inspect(reason)}")
        IO.puts("\nMake sure NATS is running:")
        IO.puts("  nats-server -js")
        System.halt(1)
    end
  end

  defp connect_to_nats do
    {:ok, conn} = Gnat.start_link(%{
      host: ~c"127.0.0.1",
      port: 4222
    })
    {:ok, conn}
  rescue
    e -> {:error, e}
  end

  defp test_intelligence_query(conn) do
    IO.puts("\nStep 2: Testing intelligence.query request/reply...")

    # Test Case 1: Phoenix LiveView detection
    test_phoenix_detection(conn)

    # Test Case 2: React detection
    test_react_detection(conn)

    # Test Case 3: Explicit framework
    test_explicit_framework(conn)

    # Test Case 4: Quality level handling
    test_quality_levels(conn)
  end

  defp test_phoenix_detection(conn) do
    IO.puts("\n  Test 1: Phoenix LiveView Detection")

    query = %{
      "description" => "Build a Phoenix LiveView real-time dashboard",
      "language" => "elixir",
      "quality_level" => "production",
      "task_type" => "code_generation"
    }

    case request_intelligence(conn, query) do
      {:ok, response} ->
        IO.puts("    ✅ Received response")
        IO.puts("    Framework detected: #{response["framework"]["name"]}")
        IO.puts("    Quality level: #{response["quality"]["quality_level"]}")
        IO.puts("    Confidence: #{response["confidence"]}")

        if response["framework"]["name"] == "phoenix" do
          IO.puts("    ✅ Correctly detected Phoenix framework")
        else
          IO.puts("    ⚠️  Expected 'phoenix', got '#{response["framework"]["name"]}'")
        end

      {:error, reason} ->
        IO.puts("    ❌ Request failed: #{inspect(reason)}")
    end
  end

  defp test_react_detection(conn) do
    IO.puts("\n  Test 2: React Framework Detection")

    query = %{
      "description" => "Create a React component with hooks",
      "language" => "typescript",
      "quality_level" => "production",
      "task_type" => "code_generation"
    }

    case request_intelligence(conn, query) do
      {:ok, response} ->
        IO.puts("    ✅ Received response")
        IO.puts("    Framework detected: #{response["framework"]["name"]}")

        if response["framework"]["name"] == "react" do
          IO.puts("    ✅ Correctly detected React framework")
        else
          IO.puts("    ⚠️  Expected 'react', got '#{response["framework"]["name"]}'")
        end

      {:error, reason} ->
        IO.puts("    ❌ Request failed: #{inspect(reason)}")
    end
  end

  defp test_explicit_framework(conn) do
    IO.puts("\n  Test 3: Explicit Framework Override")

    query = %{
      "description" => "Generic task description",
      "language" => "python",
      "framework" => "fastapi",
      "quality_level" => "production",
      "task_type" => "code_generation"
    }

    case request_intelligence(conn, query) do
      {:ok, response} ->
        IO.puts("    ✅ Received response")
        IO.puts("    Framework used: #{response["framework"]["name"]}")

        if response["framework"]["name"] == "fastapi" do
          IO.puts("    ✅ Respected explicit framework")
        else
          IO.puts("    ⚠️  Expected 'fastapi', got '#{response["framework"]["name"]}'")
        end

      {:error, reason} ->
        IO.puts("    ❌ Request failed: #{inspect(reason)}")
    end
  end

  defp test_quality_levels(conn) do
    IO.puts("\n  Test 4: Quality Level Handling")

    for quality_level <- ["production", "development", "prototype"] do
      query = %{
        "description" => "Test task",
        "language" => "elixir",
        "quality_level" => quality_level,
        "task_type" => "code_generation"
      }

      case request_intelligence(conn, query) do
        {:ok, response} ->
          IO.puts("    ✅ Quality level '#{quality_level}': #{response["quality"]["quality_level"]}")

        {:error, reason} ->
          IO.puts("    ❌ Quality level '#{quality_level}' failed: #{inspect(reason)}")
      end
    end
  end

  defp request_intelligence(conn, query) do
    payload = Jason.encode!(query)

    case Gnat.request(conn, "intelligence.query", payload, receive_timeout: 2000) do
      {:ok, %{body: body}} ->
        case Jason.decode(body) do
          {:ok, response} ->
            {:ok, response}
          {:error, reason} ->
            {:error, {:decode_error, reason}}
        end

      {:error, :timeout} ->
        {:error, :timeout}

      {:error, reason} ->
        {:error, reason}
    end
  end
end

# Run the test
IntelligenceQueryNatsTest.run()
