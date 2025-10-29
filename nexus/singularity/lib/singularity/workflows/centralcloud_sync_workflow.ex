defmodule Singularity.Workflows.CentralCloudSyncWorkflow do
  @moduledoc """
  PGFlow Workflow Definition for CentralCloud Synchronization

  Replaces pgmq-based CentralCloud sync with PGFlow workflow orchestration.
  Provides durable, observable data synchronization with CentralCloud.

  Workflow Stages:
  1. Collect Data - Gather data to be synchronized
  2. Validate Data - Ensure data integrity before sync
  3. Compress/Encode - Prepare data for transmission
  4. Send to CentralCloud - Route data to CentralCloud via Pgflow
  5. Track Sync - Record synchronization status
  """

  use Pgflow.Workflow

  require Logger

  @doc """
  Define the CentralCloud sync workflow structure
  """
  def workflow_definition do
    %{
      name: "centralcloud_sync",
      version: Singularity.BuildInfo.version(),
      description: "Workflow for synchronizing data with CentralCloud",

      # Workflow-level configuration
      config: %{
        timeout_ms:
          Application.get_env(:singularity, :centralcloud_sync_workflow, %{})[:timeout_ms] ||
            120_000,
        retries:
          Application.get_env(:singularity, :centralcloud_sync_workflow, %{})[:retries] || 3,
        retry_delay_ms:
          Application.get_env(:singularity, :centralcloud_sync_workflow, %{})[:retry_delay_ms] ||
            10000,
        concurrency:
          Application.get_env(:singularity, :centralcloud_sync_workflow, %{})[:concurrency] || 1
      },

      # Define workflow steps
      steps: [
        %{
          id: :collect_data,
          name: "Collect Sync Data",
          description: "Gather the data that needs to be synchronized with CentralCloud",
          function: &__MODULE__.collect_data/1,
          timeout_ms: 30000,
          retry_count: 1
        },
        %{
          id: :validate_data,
          name: "Validate Data",
          description: "Validate data integrity and structure before synchronization",
          function: &__MODULE__.validate_data/1,
          timeout_ms: 10000,
          retry_count: 1,
          depends_on: [:collect_data]
        },
        %{
          id: :encode_data,
          name: "Encode Data",
          description: "Encode data for transmission to CentralCloud",
          function: &__MODULE__.encode_data/1,
          timeout_ms: 15000,
          retry_count: 2,
          depends_on: [:validate_data]
        },
        %{
          id: :send_to_centralcloud,
          name: "Send to CentralCloud",
          description: "Send the encoded data to CentralCloud via Pgflow",
          function: &__MODULE__.send_to_centralcloud/1,
          timeout_ms: 60000,
          retry_count: 3,
          depends_on: [:encode_data]
        },
        %{
          id: :track_sync,
          name: "Track Synchronization",
          description: "Record the synchronization status and metrics",
          function: &__MODULE__.track_sync/1,
          timeout_ms: 5000,
          retry_count: 1,
          depends_on: [:send_to_centralcloud]
        }
      ]
    }
  end

  @doc """
  Collect the data to be synchronized
  """
  def collect_data(%{"sync_type" => sync_type, "data" => data} = context) do
    Logger.debug("Collecting data for CentralCloud sync",
      sync_type: sync_type,
      data_keys: Map.keys(data)
    )

    # Add metadata to the data
    enriched_data = Map.merge(data, %{
      "sync_type" => sync_type,
      "instance_id" => System.get_env("SINGULARITY_INSTANCE_ID", "unknown"),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "workflow_id" => Map.get(context, "workflow_id")
    })

    {:ok, Map.put(context, "collected_data", enriched_data)}
  end

  @doc """
  Validate the data before synchronization
  """
  def validate_data(%{"collected_data" => data} = context) do
    sync_type = data["sync_type"]

    # Basic validation based on sync type
    validation_result = case sync_type do
      "capabilities" ->
        # Validate capabilities data structure
        capabilities = Map.get(data, "capabilities", [])
        if is_list(capabilities) and length(capabilities) > 0 do
          :ok
        else
          {:error, "Invalid capabilities data"}
        end

      "learning_data" ->
        # Validate learning data
        if Map.has_key?(data, "learning_metrics") do
          :ok
        else
          {:error, "Missing learning metrics"}
        end

      _ ->
        # Generic validation
        :ok
    end

    case validation_result do
      :ok ->
        Logger.debug("Data validation passed", sync_type: sync_type)
        {:ok, Map.put(context, "validated_data", data)}

      {:error, reason} ->
        Logger.error("Data validation failed", sync_type: sync_type, reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Encode data for transmission
  """
  def encode_data(%{"validated_data" => data} = context) do
    case Jason.encode(data) do
      {:ok, encoded_data} ->
        Logger.debug("Data encoded successfully",
          sync_type: data["sync_type"],
          encoded_size: byte_size(encoded_data)
        )
        {:ok, Map.put(context, "encoded_data", encoded_data)}

      {:error, reason} ->
        Logger.error("Failed to encode data", reason: reason)
        {:error, "Encoding failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Send the data to CentralCloud
  """
  def send_to_centralcloud(%{"encoded_data" => encoded_data, "validated_data" => data} = context) do
    sync_type = data["sync_type"]

    # Send data to CentralCloud via pgflow queue (CentralCloud has consumers processing centralcloud_updates)
    message_payload = %{
      "data" => encoded_data,
      "sync_type" => sync_type,
      "source_instance" => data["instance_id"],
      "metadata" => %{
        "original_workflow_id" => data["workflow_id"],
        "sync_timestamp" => data["timestamp"]
      }
    }

    case Singularity.PgFlow.send_with_notify("centralcloud_updates", message_payload) do
      {:ok, _msg_id} ->
        Logger.info("Data sent to CentralCloud via queue",
          sync_type: sync_type,
          queue: "centralcloud_updates"
        )

        {:ok, Map.put(context, "sent_to_centralcloud", true)}

      {:error, reason} ->
        Logger.error("Failed to send data to CentralCloud",
          sync_type: sync_type,
          reason: reason
        )

        {:error, "Failed to send to CentralCloud: #{inspect(reason)}"}
    end
  end

  @doc """
  Track the synchronization status
  """
  def track_sync(%{"validated_data" => data, "sent_to_centralcloud" => true} = context) do
    sync_type = data["sync_type"]
    instance_id = data["instance_id"]

    # Record sync tracking information
    Logger.info("CentralCloud sync completed",
      sync_type: sync_type,
      instance_id: instance_id,
      queue: "centralcloud_updates",
      status: :completed
    )

    # Store sync tracking via Telemetry for monitoring
    :telemetry.execute(
      [:singularity, :centralcloud, :sync, :complete],
      %{count: 1},
      %{
        sync_type: sync_type,
        instance_id: instance_id,
        queue: "centralcloud_updates"
      }
    )

    Logger.debug("Tracked CentralCloud sync completion",
      sync_type: sync_type,
      instance_id: instance_id,
      queue: "centralcloud_updates"
    )

    {:ok, Map.put(context, "sync_tracked", true)}
  end
end
