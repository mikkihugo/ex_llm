defmodule CentralCloud.Workflows.ArchitectureAnalysisWorkflow do
  @moduledoc """
  QuantumFlow Workflow Definition for Architecture Analysis Requests

  Replaces NATS-based delegation to Singularity with QuantumFlow workflow orchestration.
  Provides durable, observable architecture analysis request processing.

  Workflow Stages:
  1. Validate Request - Validate architecture analysis request
  2. Route to Singularity - Send request to Singularity analysis engine
  3. Process Response - Handle response from Singularity
  4. Format Results - Format results for CentralCloud consumption
  """

  use QuantumFlow.Workflow

  require Logger
  alias QuantumFlow.Executor

  @doc """
  Define the architecture analysis workflow structure
  """
  def workflow_definition do
    %{
      name: "architecture_analysis",
      version: (Application.spec(:central_services, :vsn) || "0.0.0") |> to_string(),
      description: "Workflow for delegating architecture analysis to Singularity",

      # Workflow-level configuration
      config: %{
        timeout_ms:
          Application.get_env(:centralcloud, :architecture_analysis_workflow, %{})[:timeout_ms] ||
            120_000,
        retries:
          Application.get_env(:centralcloud, :architecture_analysis_workflow, %{})[:retries] || 3,
        retry_delay_ms:
          Application.get_env(:centralcloud, :architecture_analysis_workflow, %{})[:retry_delay_ms] ||
            10000,
        concurrency:
          Application.get_env(:centralcloud, :architecture_analysis_workflow, %{})[:concurrency] ||
            2
      },

      # Define workflow steps
      steps: [
        %{
          id: :validate_request,
          name: "Validate Request",
          description: "Validate the architecture analysis request parameters",
          function: &__MODULE__.validate_request/1,
          timeout_ms: 5000,
          retry_count: 1
        },
        %{
          id: :route_to_singularity,
          name: "Route to Singularity",
          description: "Send the analysis request to Singularity via QuantumFlow",
          function: &__MODULE__.route_to_singularity/1,
          timeout_ms: 90000,
          retry_count: 2,
          depends_on: [:validate_request]
        },
        %{
          id: :process_response,
          name: "Process Response",
          description: "Process and validate the response from Singularity",
          function: &__MODULE__.process_response/1,
          timeout_ms: 10000,
          retry_count: 1,
          depends_on: [:route_to_singularity]
        },
        %{
          id: :format_results,
          name: "Format Results",
          description: "Format the analysis results for CentralCloud consumption",
          function: &__MODULE__.format_results/1,
          timeout_ms: 5000,
          retry_count: 1,
          depends_on: [:process_response]
        }
      ]
    }
  end

  @doc """
  Validate the architecture analysis request
  """
  def validate_request(%{"operation" => operation, "request" => request} = context) do
    valid_operations = ["detect_technologies", "get_architectural_suggestions"]

    if operation in valid_operations do
      if is_map(request) do
        Logger.debug("Architecture analysis request validated",
          operation: operation,
          request_keys: Map.keys(request)
        )
        {:ok, Map.put(context, "validated_request", request)}
      else
        {:error, "Request must be a map"}
      end
    else
      {:error, "Invalid operation: #{operation}. Valid operations: #{Enum.join(valid_operations, ", ")}"}
    end
  end

  @doc """
  Route the request to Singularity analysis engine
  """
  def route_to_singularity(%{"operation" => operation, "validated_request" => request} = context) do
    payload = %{
      "operation" => operation,
      "request" => request,
      "source" => "centralcloud",
      "workflow_id" => Map.get(context, "workflow_id")
    }

    Logger.info("Architecture analysis request routed to Singularity",
      operation: operation
    )

    case Executor.execute(
           Singularity.Workflows.ArchitectureAnalysisRequestWorkflow,
           payload,
           timeout: 120_000
         ) do
      {:ok, results} ->
        Logger.info("Architecture analysis workflow completed", operation: operation)
        {:ok, Map.put(context, "singularity_response", results)}

      {:error, :timeout} ->
        Logger.warning("Architecture analysis workflow timed out", operation: operation)

        fallback_response = %{
          "operation" => operation,
          "status" => "timeout",
          "results" => %{
            "technologies" => ["unknown"],
            "suggestions" => ["Analysis timed out - using fallback results"]
          }
        }

        {:ok, Map.put(context, "singularity_response", fallback_response)}

      {:error, reason} ->
        Logger.error("Architecture analysis workflow failed",
          operation: operation,
          reason: reason
        )

        {:error, "Workflow failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Process the response from Singularity
  """
  def process_response(%{"singularity_response" => response} = context) do
    if response["status"] == "completed" do
      Logger.debug("Singularity response processed successfully",
        operation: response["operation"],
        has_results: Map.has_key?(response, "results")
      )
      {:ok, context}
    else
      {:error, "Singularity analysis failed with status: #{response["status"]}"}
    end
  end

  @doc """
  Format results for CentralCloud consumption
  """
  def format_results(%{"singularity_response" => response} = context) do
    formatted_results = %{
      "status" => "success",
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "operation" => response["operation"],
      "data" => response["results"]
    }

    Logger.info("Architecture analysis results formatted",
      operation: response["operation"],
      result_keys: Map.keys(formatted_results)
    )

    {:ok, Map.put(context, "formatted_results", formatted_results)}
  end
end
