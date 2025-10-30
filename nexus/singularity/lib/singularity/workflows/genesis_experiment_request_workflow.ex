defmodule Singularity.Workflows.GenesisExperimentRequestWorkflow do
  @moduledoc """
  PGFlow Workflow Definition for Genesis Experiment Requests

  Replaces pgmq-based Genesis experiment request publishing with PGFlow workflow orchestration.
  Provides durable, observable experiment request processing.

  Workflow Stages:
  1. Validate Request - Validate experiment request structure
  2. Enrich Context - Add additional context for Genesis processing
  3. Route to Genesis - Send request to appropriate Genesis queue/workflow
  4. Track Request - Store request tracking information
  """

  use Pgflow.Workflow

  require Logger

  @doc """
  Define the Genesis experiment request workflow structure
  """
  def workflow_definition do
    %{
      name: "genesis_experiment_request",
      version: Singularity.BuildInfo.version(),
      description: "Workflow for processing Genesis experiment requests from agents",

      # Workflow-level configuration
      config: %{
        timeout_ms:
          Application.get_env(:singularity, :genesis_experiment_workflow, %{})[:timeout_ms] ||
            60_000,
        retries:
          Application.get_env(:singularity, :genesis_experiment_workflow, %{})[:retries] || 3,
        retry_delay_ms:
          Application.get_env(:singularity, :genesis_experiment_workflow, %{})[:retry_delay_ms] ||
            5000,
        concurrency:
          Application.get_env(:singularity, :genesis_experiment_workflow, %{})[:concurrency] ||
            2
      },

      # Define workflow steps
      steps: [
        %{
          id: :validate_request,
          name: "Validate Experiment Request",
          description: "Validate the structure and content of the experiment request",
          function: &__MODULE__.validate_request/1,
          timeout_ms: 5000,
          retry_count: 1
        },
        %{
          id: :enrich_context,
          name: "Enrich Context",
          description: "Add additional context and metadata for Genesis processing",
          function: &__MODULE__.enrich_context/1,
          timeout_ms: 10000,
          retry_count: 1,
          depends_on: [:validate_request]
        },
        %{
          id: :route_to_genesis,
          name: "Route to Genesis",
          description: "Route the request to the appropriate Genesis processing workflow",
          function: &__MODULE__.route_to_genesis/1,
          timeout_ms: 30000,
          retry_count: 2,
          depends_on: [:enrich_context]
        },
        %{
          id: :track_request,
          name: "Track Request",
          description: "Store tracking information for the experiment request",
          function: &__MODULE__.track_request/1,
          timeout_ms: 5000,
          retry_count: 1,
          depends_on: [:route_to_genesis]
        }
      ]
    }
  end

  @doc """
  Validate the experiment request structure
  """
  def validate_request(%{"request" => request, "agent_id" => agent_id} = context) do
    required_fields = ["experiment_id", "context", "timestamp"]
    missing_fields = Enum.filter(required_fields, &(!Map.has_key?(request, &1)))

    if missing_fields != [] do
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    else
      # Validate agent_id and experiment_id are strings
      if not (is_binary(agent_id) and is_binary(request["experiment_id"])) do
        {:error, "agent_id and experiment_id must be strings"}
      else
        {:ok, Map.put(context, "validated_request", request)}
      end
    end
  end

  @doc """
  Enrich the request context with additional metadata
  """
  def enrich_context(%{"validated_request" => request, "agent_id" => agent_id} = context) do
    enriched_request =
      Map.merge(request, %{
        "agent_id" => agent_id,
        "workflow_id" => Map.get(context, "workflow_id"),
        "processed_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "source" => "agent_self_improvement"
      })

    Logger.debug("Enriched Genesis experiment request context",
      agent_id: agent_id,
      experiment_id: request["experiment_id"]
    )

    {:ok, Map.put(context, "enriched_request", enriched_request)}
  end

  @doc """
  Route the request to Genesis processing
  """
  def route_to_genesis(%{"enriched_request" => request, "agent_id" => agent_id} = context) do
    experiment_id = request["experiment_id"]

    # Send experiment request to Genesis via pgflow queue (Genesis consumes from job_requests queue)
    message_payload = %{
      "experiment_request" => request,
      "agent_id" => agent_id,
      "experiment_id" => experiment_id,
      "type" => "experiment_request"
    }

    case Singularity.Infrastructure.PgFlow.Queue.send_with_notify("job_requests", message_payload) do
      {:ok, _msg_id} ->
        Logger.info("Routed experiment request to Genesis via queue",
          agent_id: agent_id,
          experiment_id: experiment_id,
          queue: "job_requests"
        )

        {:ok, Map.put(context, "sent_to_genesis", true)}

      {:error, reason} ->
        Logger.error("Failed to route experiment request to Genesis",
          agent_id: agent_id,
          experiment_id: experiment_id,
          reason: reason
        )

        {:error, "Failed to route to Genesis: #{inspect(reason)}"}
    end
  end

  @doc """
  Track the request for monitoring and debugging
  """
  def track_request(%{"enriched_request" => request, "sent_to_genesis" => true} = context) do
    agent_id = request["agent_id"]
    experiment_id = request["experiment_id"]

    # Store tracking information
    Logger.debug("Tracking Genesis experiment request",
      agent_id: agent_id,
      experiment_id: experiment_id,
      queue: "job_requests",
      tracking_info: %{status: :routed, timestamp: DateTime.utc_now()}
    )

    # Store tracking via Telemetry for monitoring
    :telemetry.execute(
      [:singularity, :genesis, :experiment, :tracked],
      %{count: 1},
      %{
        experiment_id: experiment_id,
        queue: "job_requests",
        agent_id: agent_id
      }
    )

    Logger.debug("Tracked Genesis experiment request",
      experiment_id: experiment_id,
      queue: "job_requests",
      agent_id: agent_id
    )

    {:ok, Map.put(context, "tracking_complete", true)}
  end
end
