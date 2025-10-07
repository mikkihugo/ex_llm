defmodule Singularity.FrameworkDetector do
  @moduledoc """
  Dynamic framework detection using tech_detector (via package_registry_indexer).

  Instead of hardcoding frameworks, this queries the Rust tech_detector library
  to get framework patterns dynamically from the indexed knowledge base.

  This way, new frameworks are automatically detected as they're added
  to the package registry knowledge base.

  **Architecture:**
  - Elixir → NATS → package_registry_indexer → tech_detector (Rust library)
  """

  @doc """
  Detect frameworks from patterns using tech_detector.

  Falls back to hardcoded list if tech_detector unavailable.

  ## Examples

      iex> FrameworkDetector.detect_frameworks(["phoenix", "endpoint", "nats"])
      ["Phoenix", "NATS"]
  """
  def detect_frameworks(patterns) do
    # Try to load from tech_detector first
    case load_from_tech_detector(patterns) do
      {:ok, frameworks} when frameworks != [] ->
        frameworks

      _ ->
        # Fallback to hardcoded detection
        detect_frameworks_fallback(patterns)
    end
  end

  @doc """
  Load framework patterns from tech_detector via NATS.

  Sends request to package_registry_indexer which uses tech_detector library
  to get framework definitions and matches them against patterns.
  """
  def load_from_tech_detector(patterns) do
    # Call package_registry_indexer via NATS
    payload = Jason.encode!(%{patterns: patterns})

    case Singularity.NatsClient.request("packages.registry.detect.frameworks", payload,
           timeout: 5000
         ) do
      {:ok, response} ->
        case Jason.decode(response) do
          {:ok, %{"frameworks" => frameworks}} -> {:ok, frameworks}
          {:error, _} -> {:error, :invalid_response}
        end

      {:error, _reason} ->
        {:error, :nats_error}
    end
  end

  @doc """
  Get all known frameworks from tech_detector.

  This should query the Rust service for complete framework list.
  """
  def list_all_frameworks do
    # Query package_registry_indexer (tech_detector) for all frameworks
    case Singularity.NatsClient.request("packages.registry.detect.list_frameworks", "{}",
           timeout: 5000
         ) do
      {:ok, response} ->
        case Jason.decode(response) do
          {:ok, %{"frameworks" => frameworks}} -> {:ok, frameworks}
          {:error, _} -> {:error, :invalid_response}
        end

      {:error, _reason} ->
        {:error, :nats_error}
    end
  end

  @doc """
  Classify microservice type based on patterns.

  This should also come from tech_detector eventually.
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

  # Fallback detection (temporary until tech_detector integration)
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
