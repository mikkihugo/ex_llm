defmodule Singularity.Workflows.AgentImprovementWorkflow do
  @moduledoc """
  PGFlow Workflow Definition for Agent Improvement Event Publishing

  Replaces pgmq-based agent improvement event publishing with PGFlow workflow orchestration.
  Provides durable, observable agent improvement event processing.

  Workflow Stages:
  1. Validate Event - Validate improvement event structure
  2. Store Event - Persist event to database
  3. Notify Subscribers - Notify interested components
  4. Update Metrics - Update agent performance metrics
  """

  use Pgflow.Workflow

  require Logger
  alias Singularity.Repo
  alias Singularity.Agents.Agent

  @doc """
  Define the agent improvement workflow structure
  """
  def workflow_definition do
    %{
      name: "agent_improvement",
      version: Singularity.BuildInfo.version(),
      description: "Workflow for processing agent improvement events",

      # Workflow-level configuration
      config: %{
        timeout_ms:
          Application.get_env(:singularity, :agent_improvement_workflow, %{})[:timeout_ms] ||
            30_000,
        retries:
          Application.get_env(:singularity, :agent_improvement_workflow, %{})[:retries] || 2,
        retry_delay_ms:
          Application.get_env(:singularity, :agent_improvement_workflow, %{})[:retry_delay_ms] ||
            1000,
        concurrency:
          Application.get_env(:singularity, :agent_improvement_workflow, %{})[:concurrency] ||
            5
      },

      # Define workflow steps
      steps: [
        %{
          id: :validate_event,
          name: "Validate Improvement Event",
          description: "Validate the structure and content of the improvement event",
          function: &__MODULE__.validate_event/1,
          timeout_ms: 5000,
          retry_count: 1
        },
        %{
          id: :store_event,
          name: "Store Event",
          description: "Persist the improvement event to the database",
          function: &__MODULE__.store_event/1,
          timeout_ms: 10000,
          retry_count: 2,
          depends_on: [:validate_event]
        },
        %{
          id: :notify_subscribers,
          name: "Notify Subscribers",
          description: "Notify components subscribed to agent improvement events",
          function: &__MODULE__.notify_subscribers/1,
          timeout_ms: 5000,
          retry_count: 1,
          depends_on: [:store_event]
        },
        %{
          id: :update_metrics,
          name: "Update Metrics",
          description: "Update agent performance and improvement metrics",
          function: &__MODULE__.update_metrics/1,
          timeout_ms: 5000,
          retry_count: 1,
          depends_on: [:store_event]
        }
      ]
    }
  end

  @doc """
  Validate the improvement event structure
  """
  def validate_event(%{"event" => event} = context) do
    required_fields = ["agent_id", "payload", "timestamp"]
    missing_fields = Enum.filter(required_fields, &(!Map.has_key?(event, &1)))

    if missing_fields != [] do
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    else
      # Validate agent_id is a string
      if not is_binary(event["agent_id"]) do
        {:error, "agent_id must be a string"}
      else
        {:ok, Map.put(context, "validated_event", event)}
      end
    end
  end

  @doc """
  Store the improvement event in the database
  """
  def store_event(%{"validated_event" => event} = context) do
    agent_id = event["agent_id"]

    # For now, we'll log the event. In a real implementation,
    # this would store to a database table for agent improvements
    Logger.info("Storing agent improvement event",
      agent_id: event["agent_id"],
      payload_keys: Map.keys(event["payload"]),
      timestamp: event["timestamp"]
    )

    # Store improvement event via Telemetry for aggregation
    :telemetry.execute(
      [:singularity, :agent, :improvement, :event],
      %{count: 1},
      %{
        agent_id: agent_id,
        improvement_type: event["improvement_type"],
        timestamp: event["timestamp"]
      }
    )

    Logger.debug("Stored agent improvement event",
      agent_id: agent_id,
      improvement_type: event["improvement_type"]
    )

    {:ok, Map.put(context, "stored_event", event)}
  end

  @doc """
  Notify subscribers of the improvement event
  """
  def notify_subscribers(%{"stored_event" => event} = context) do
    agent_id = event["agent_id"]

    # Notify agent-specific subscribers
    # This replaces the pgmq publish to "agent_improvements.{agent_id}"
    Logger.debug("Notifying subscribers for agent improvement",
      agent_id: agent_id,
      subject: "agent_improvements.#{agent_id}"
    )

    # Notify via Telemetry (consumed by Observer and other subscribers)
    :telemetry.execute(
      [:singularity, :agent, :improvement, :notify],
      %{count: 1},
      %{
        agent_id: agent_id,
        improvement_type: event["improvement_type"],
        timestamp: event["timestamp"]
      }
    )

    # Notify AgentSupervisor if running (for dynamic agent updates)
    case Process.whereis(Singularity.Agents.AgentSupervisor) do
      nil ->
        Logger.debug("AgentSupervisor not running - skipping GenServer notification")

      _pid ->
        # GenServer cast would require a public API on AgentSupervisor
        # For now, Telemetry is sufficient for decoupled notification
        Logger.debug("Agent improvement notification sent via Telemetry")
    end

    {:ok, Map.put(context, "notified_subscribers", true)}
  end

  @doc """
  Update agent performance metrics
  """
  def update_metrics(%{"stored_event" => event} = context) do
    agent_id = event["agent_id"]

    # Update metrics for the agent
    Logger.debug("Updating metrics for agent improvement",
      agent_id: agent_id,
      improvement_count: 1
    )

    # Update agent metrics via Telemetry
    :telemetry.execute(
      [:singularity, :agent, :metrics, :improvement],
      %{improvement_count: 1},
      %{agent_id: agent_id}
    )

    Logger.debug("Updated metrics for agent improvement",
      agent_id: agent_id,
      improvement_count: 1
    )

    {:ok, Map.put(context, "metrics_updated", true)}
  end
end
