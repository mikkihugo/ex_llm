defmodule Singularity.FrameworkDetector do
  @moduledoc """
  Dynamic framework detection using tool_doc_index.

  Instead of hardcoding frameworks, this queries the Rust tool_doc_index
  to get framework patterns dynamically from the indexed knowledge base.

  This way, new frameworks are automatically detected as they're added
  to the tool documentation index.
  """

  @doc """
  Detect frameworks from patterns using tool_doc_index.

  Falls back to hardcoded list if tool_doc_index unavailable.

  ## Examples

      iex> FrameworkDetector.detect_frameworks(["phoenix", "endpoint", "nats"])
      ["Phoenix", "NATS"]
  """
  def detect_frameworks(patterns) do
    # Try to load from tool_doc_index first
    case load_from_tool_doc_index(patterns) do
      {:ok, frameworks} when frameworks != [] ->
        frameworks

      _ ->
        # Fallback to hardcoded detection
        detect_frameworks_fallback(patterns)
    end
  end

  @doc """
  Load framework patterns from tool_doc_index via NATS.

  Sends request to Rust tool_doc_index service to get framework
  definitions and matches them against patterns.
  """
  def load_from_tool_doc_index(patterns) do
    # TODO: Call Rust tool_doc_index via NATS
    # Subject: "tool_doc.match_frameworks"
    # Payload: %{patterns: patterns}
    # Response: %{frameworks: ["Phoenix", "Broadway", ...]}

    # For now, return error to trigger fallback
    {:error, :not_implemented}
  end

  @doc """
  Get all known frameworks from tool_doc_index.

  This should query the Rust service for complete framework list.
  """
  def list_all_frameworks do
    # TODO: Query tool_doc_index for all frameworks
    # Subject: "tool_doc.list_frameworks"
    # Response: [
    #   %{name: "Phoenix", patterns: ["phoenix", "endpoint", ...], category: "web"},
    #   %{name: "Broadway", patterns: ["broadway", "pipeline"], category: "stream"},
    #   ...
    # ]

    {:error, :not_implemented}
  end

  @doc """
  Classify microservice type based on patterns.

  This should also come from tool_doc_index eventually.
  """
  def classify_microservice(patterns) do
    cond do
      "nats" in patterns and "genserver" in patterns -> "nats_microservice"
      "broadway" in patterns -> "stream_processor"
      "channel" in patterns and "websocket" in patterns -> "websocket_service"
      "plug" in patterns and "http" in patterns -> "http_api"
      "genserver" in patterns -> "otp_service"
      true -> nil
    end
  end

  # Fallback detection (temporary until tool_doc_index integration)
  defp detect_frameworks_fallback(patterns) do
    framework_map = %{
      "Phoenix" => ["phoenix", "endpoint", "channel", "live"],
      "Broadway" => ["broadway", "pipeline"],
      "NATS" => ["nats", "gnat", "jetstream"],
      "Ecto" => ["ecto", "schema", "changeset", "repo"],
      "Tesla" => ["tesla"],
      "Req" => ["req"],
      "GenServer" => ["genserver"],
      "Supervisor" => ["supervisor"],
      "Plug" => ["plug"],
      "Kafka" => ["kafka", "brod"],
      "RabbitMQ" => ["rabbitmq", "amqp"],
      "Redis" => ["redis", "redix"],
      "GraphQL" => ["graphql", "absinthe"],
      "gRPC" => ["grpc"],
      "Finch" => ["finch"],
      "Oban" => ["oban"],
      "Ash" => ["ash", "resource"],
      "Swoosh" => ["swoosh", "email"],
      "ExUnit" => ["exunit", "test"],
      "Credo" => ["credo"],
      "Dialyzer" => ["dialyzer"]
    }

    Enum.filter(framework_map, fn {_framework, keywords} ->
      Enum.any?(keywords, &(&1 in patterns))
    end)
    |> Enum.map(fn {framework, _} -> framework end)
  end
end
