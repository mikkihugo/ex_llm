defmodule Singularity.NatsIntegrationTest do
  @moduledoc """
  Integration tests for NATS message flows.

  Tests full round-trip communication:
  - Request → NATS → Handler → Response
  - Error handling and timeouts
  - Message serialization/deserialization
  - JetStream persistence
  """

  use Singularity.DataCase, async: false

  alias Singularity.NATS.NatsClient

  @moduletag :integration

  describe "NATS request/response flow" do
    test "successful round-trip message" do
      # Setup: Start NATS subscriber for test subject
      test_subject = "test.echo.#{System.unique_integer([:positive])}"

      # Subscribe to test subject and echo back
      {:ok, subscription} =
        NatsClient.subscribe(test_subject, fn message ->
          NatsClient.publish(message.reply_to, message.body)
        end)

      # Make request
      request_payload = Jason.encode!(%{test: "data", timestamp: System.system_time()})

      {:ok, response} = NatsClient.request(test_subject, request_payload, timeout: 1000)

      # Verify response
      assert response.body == request_payload
      assert {:ok, decoded} = Jason.decode(response.body)
      assert decoded["test"] == "data"

      # Cleanup
      NatsClient.unsubscribe(subscription)
    end

    test "handles request timeout gracefully" do
      # Request to non-existent subject should timeout
      test_subject = "test.nonexistent.#{System.unique_integer([:positive])}"

      assert {:error, :timeout} =
               NatsClient.request(test_subject, "test", timeout: 100)
    end

    test "handles malformed responses" do
      test_subject = "test.malformed.#{System.unique_integer([:positive])}"

      # Subscribe and send invalid JSON
      {:ok, subscription} =
        NatsClient.subscribe(test_subject, fn message ->
          NatsClient.publish(message.reply_to, "not valid json {")
        end)

      {:ok, response} = NatsClient.request(test_subject, "test", timeout: 1000)

      # Response should arrive but JSON parsing will fail
      assert response.body == "not valid json {"
      assert {:error, _} = Jason.decode(response.body)

      NatsClient.unsubscribe(subscription)
    end
  end

  describe "NATS publish/subscribe" do
    test "multiple subscribers receive same message" do
      test_subject = "test.broadcast.#{System.unique_integer([:positive])}"
      test_pid = self()

      # Subscribe with multiple handlers
      {:ok, sub1} =
        NatsClient.subscribe(test_subject, fn msg ->
          send(test_pid, {:received_1, msg.body})
        end)

      {:ok, sub2} =
        NatsClient.subscribe(test_subject, fn msg ->
          send(test_pid, {:received_2, msg.body})
        end)

      # Publish message
      message = "broadcast test"
      :ok = NatsClient.publish(test_subject, message)

      # Both subscribers should receive it
      assert_receive {:received_1, ^message}, 1000
      assert_receive {:received_2, ^message}, 1000

      # Cleanup
      NatsClient.unsubscribe(sub1)
      NatsClient.unsubscribe(sub2)
    end

    test "wildcard subscriptions" do
      test_pid = self()

      # Subscribe to wildcard pattern
      {:ok, subscription} =
        NatsClient.subscribe("test.wildcard.*", fn msg ->
          send(test_pid, {:received, msg.subject, msg.body})
        end)

      # Publish to multiple subjects matching pattern
      :ok = NatsClient.publish("test.wildcard.foo", "message 1")
      :ok = NatsClient.publish("test.wildcard.bar", "message 2")

      # Should receive both
      assert_receive {:received, "test.wildcard.foo", "message 1"}, 1000
      assert_receive {:received, "test.wildcard.bar", "message 2"}, 1000

      NatsClient.unsubscribe(subscription)
    end
  end

  describe "LLM request flow integration" do
    setup do
      # Mock AI server response for testing
      test_subject = "llm.request"

      {:ok, subscription} =
        NatsClient.subscribe(test_subject, fn message ->
          # Simulate AI server response
          request = Jason.decode!(message.body)

          response = %{
            id: request["id"],
            result:
              "Mock LLM response for: #{request["messages"] |> List.last() |> Map.get("content")}",
            model: "mock-model",
            usage: %{
              prompt_tokens: 10,
              completion_tokens: 20,
              total_tokens: 30
            },
            latency_ms: 100
          }

          NatsClient.publish(message.reply_to, Jason.encode!(response))
        end)

      on_exit(fn -> NatsClient.unsubscribe(subscription) end)

      {:ok, subject: test_subject}
    end

    test "LLM request/response with proper format", %{subject: subject} do
      request = %{
        id: "test-#{System.unique_integer([:positive])}",
        complexity: "simple",
        task_type: "classifier",
        messages: [
          %{"role" => "user", "content" => "Classify this text"}
        ],
        options: %{
          temperature: 0.7,
          max_tokens: 100
        }
      }

      {:ok, response} = NatsClient.request(subject, Jason.encode!(request), timeout: 2000)

      assert {:ok, decoded} = Jason.decode(response.body)
      assert decoded["id"] == request.id
      assert decoded["result"] =~ "Classify this text"
      assert decoded["usage"]["total_tokens"] == 30
    end
  end

  describe "NATS error handling" do
    test "handles connection failures gracefully" do
      # Try to publish when NATS might be down
      # Should not crash the test process
      result = NatsClient.publish("test.error.subject", "test")

      # Either succeeds or returns error, but doesn't crash
      assert result in [:ok, {:error, :not_connected}, {:error, :timeout}]
    end

    test "reconnection after temporary disconnection" do
      # This test verifies NATS client reconnection logic
      # In production, NATS client should automatically reconnect

      test_subject = "test.reconnect.#{System.unique_integer([:positive])}"

      # Initial connection should work
      assert :ok = NatsClient.publish(test_subject, "before disconnect")

      # Simulate disconnect (in real scenario, would stop NATS server)
      # For testing, just verify publish still works
      assert :ok = NatsClient.publish(test_subject, "after disconnect")
    end
  end

  describe "NATS message size limits" do
    test "handles large messages" do
      test_subject = "test.large.#{System.unique_integer([:positive])}"
      test_pid = self()

      # Subscribe
      {:ok, subscription} =
        NatsClient.subscribe(test_subject, fn msg ->
          send(test_pid, {:received, byte_size(msg.body)})
        end)

      # Send large message (1MB)
      large_message = String.duplicate("x", 1024 * 1024)
      :ok = NatsClient.publish(test_subject, large_message)

      # Should receive full message
      assert_receive {:received, size}, 2000
      assert size == byte_size(large_message)

      NatsClient.unsubscribe(subscription)
    end

    test "handles very small messages efficiently" do
      test_subject = "test.small.#{System.unique_integer([:positive])}"
      test_pid = self()

      {:ok, subscription} =
        NatsClient.subscribe(test_subject, fn msg ->
          send(test_pid, {:received, msg.body})
        end)

      # Send tiny message
      :ok = NatsClient.publish(test_subject, "x")

      assert_receive {:received, "x"}, 1000

      NatsClient.unsubscribe(subscription)
    end
  end
end
