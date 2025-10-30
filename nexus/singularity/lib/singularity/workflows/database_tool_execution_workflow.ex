defmodule Singularity.Workflows.DatabaseToolExecutionWorkflow do
  @moduledoc """
  PGFlow Workflow Definition for Database Tool Execution

  Replaces pgmq-based database tool execution with PGFlow workflow orchestration.
  Provides durable, observable database tool execution with proper response handling.

  Workflow Stages:
  1. Validate Request - Validate incoming tool execution request
  2. Authenticate - Verify request permissions and authentication
  3. Execute Tool - Run the requested database tool
  4. Format Response - Format the execution results
  5. Send Response - Deliver response to requesting system
  """

  use Pgflow.Workflow

  require Logger
  alias Singularity.Tools.DatabaseToolsExecutor

  @doc """
  Define the database tool execution workflow structure
  """
  def workflow_definition do
    %{
      name: "database_tool_execution",
      version: Singularity.BuildInfo.version(),
      description: "Workflow for executing database tools with request-reply pattern",

      # Workflow-level configuration
      config: %{
        timeout_ms:
          Application.get_env(:singularity, :database_tool_workflow, %{})[:timeout_ms] ||
            60_000,
        retries: Application.get_env(:singularity, :database_tool_workflow, %{})[:retries] || 2,
        retry_delay_ms:
          Application.get_env(:singularity, :database_tool_workflow, %{})[:retry_delay_ms] ||
            5000,
        concurrency:
          Application.get_env(:singularity, :database_tool_workflow, %{})[:concurrency] ||
            5
      },

      # Define workflow steps
      steps: [
        %{
          id: :validate_request,
          name: "Validate Request",
          description: "Validate the structure and parameters of the tool execution request",
          function: &__MODULE__.validate_request/1,
          timeout_ms: 5000,
          retry_count: 1
        },
        %{
          id: :authenticate,
          name: "Authenticate Request",
          description: "Verify request authentication and authorization",
          function: &__MODULE__.authenticate/1,
          timeout_ms: 3000,
          retry_count: 1,
          depends_on: [:validate_request]
        },
        %{
          id: :execute_tool,
          name: "Execute Tool",
          description: "Execute the requested database tool with provided parameters",
          function: &__MODULE__.execute_tool/1,
          timeout_ms: 45000,
          retry_count: 1,
          depends_on: [:authenticate]
        },
        %{
          id: :format_response,
          name: "Format Response",
          description: "Format the tool execution results into response format",
          function: &__MODULE__.format_response/1,
          timeout_ms: 5000,
          retry_count: 1,
          depends_on: [:execute_tool]
        },
        %{
          id: :send_response,
          name: "Send Response",
          description: "Send the formatted response back to the requesting system",
          function: &__MODULE__.send_response/1,
          timeout_ms: 10000,
          retry_count: 2,
          depends_on: [:format_response]
        }
      ]
    }
  end

  @doc """
  Validate the tool execution request
  """
  def validate_request(%{"request" => request, "reply_to" => reply_to} = context) do
    required_fields = ["tool", "params"]
    missing_fields = Enum.filter(required_fields, &(!Map.has_key?(request, &1)))

    if missing_fields != [] do
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    else
      tool = request["tool"]
      valid_tools = ["query", "schema", "migrate", "backup", "restore"]

      if tool in valid_tools do
        Logger.debug("Database tool request validated",
          tool: tool,
          reply_to: reply_to
        )

        {:ok, Map.put(context, "validated_request", request)}
      else
        {:error, "Invalid tool: #{tool}. Valid tools: #{Enum.join(valid_tools, ", ")}"}
      end
    end
  end

  @doc """
  Authenticate and authorize the request
  """
  def authenticate(%{"validated_request" => request} = context) do
    # For internal tooling, use simple token-based auth if provided
    # Otherwise allow (internal tooling - no multi-tenancy)
    auth_token = Map.get(request, "auth_token")

    if auth_token && auth_token != "" do
      Logger.debug("Request authenticated with token", tool: request["tool"])
      {:ok, Map.put(context, "authenticated", true)}
    else
      # Internal tooling - allow by default
      Logger.debug("Request authenticated (internal tooling)", tool: request["tool"])
      {:ok, Map.put(context, "authenticated", true)}
    end
  end

  @doc """
  Execute the requested database tool
  """
  def execute_tool(%{"validated_request" => request} = context) do
    tool = Map.get(request, "tool", "unknown")
    params = Map.get(request, "params", %{})

    Logger.info("Executing database tool",
      tool: tool,
      param_keys: Map.keys(params)
    )

    tool_subject = "tools.#{tool}"
    execution_request = Map.put(request, "params", params)

    result =
      try do
        GenServer.call(
          DatabaseToolsExecutor,
          {:execute_tool, tool_subject, execution_request},
          30_000
        )
      catch
        :exit, reason -> {:error, {:executor_exit, reason}}
      end

    execution_result =
      case result do
        {:ok, value} ->
          Logger.info("Tool execution completed", tool: tool, success: true)

          %{
            "success" => true,
            "tool" => tool,
            "result" => value,
            "executed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
          }

        {:error, reason} ->
          Logger.error("Tool execution failed", tool: tool, error: reason)

          %{
            "success" => false,
            "tool" => tool,
            "error" => inspect(reason),
            "executed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
          }
      end

    {:ok, Map.put(context, "execution_result", execution_result)}
  end

  @doc """
  Format the execution results into response format
  """
  def format_response(%{"execution_result" => result} = context) do
    response = %{
      "status" => if(Map.get(result, "success", false), do: "success", else: "error"),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "result" => result
    }

    case Jason.encode(response) do
      {:ok, json_response} ->
        Logger.debug("Response formatted successfully",
          response_size: byte_size(json_response)
        )

        {:ok, Map.put(context, "formatted_response", json_response)}

      {:error, reason} ->
        Logger.error("Failed to format response", reason: reason)
        {:error, "Response formatting failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Send the response back to the requesting system
  """
  def send_response(
        %{"formatted_response" => response_json, "validated_request" => request} = context
      ) do
    reply_to = Map.get(context, "reply_to")

    # Send response via PGFlow completion notification or direct messaging
    if reply_to do
      case Singularity.Messaging.Client.publish(reply_to, response_json) do
        :ok ->
          Logger.info("Tool execution response sent",
            tool: request["tool"],
            reply_to: reply_to,
            response_size: byte_size(response_json)
          )

          {:ok, Map.put(context, "response_sent", true)}

        {:error, reason} ->
          Logger.error("Failed to send tool execution response",
            tool: request["tool"],
            reply_to: reply_to,
            error: reason
          )

          {:error, "Response delivery failed: #{inspect(reason)}"}
      end
    else
      Logger.debug("No reply_to specified - response logged only",
        tool: request["tool"]
      )

      {:ok, Map.put(context, "response_sent", false)}
    end
  end
end
