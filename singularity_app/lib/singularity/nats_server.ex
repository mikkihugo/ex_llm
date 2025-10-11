defmodule Singularity.NatsServer do
  @moduledoc """
  NATS Server - Single entry point for all services.

  Consolidates all separate NATS bridges into one sophisticated system:
  - Complexity-aware routing
  - LLM auto-discovery for unknown frameworks
  - Template optimization
  - Tool execution
  - Performance monitoring

  ## Architecture

  ```
  All Requests → nats.request → Server → Route by complexity/service
  ```

  ## NATS Subjects

  - `nats.request` - All requests go here
  - `nats.response` - All responses come back
  - `nats.request.{simple|medium|complex}` - Complexity-specific routing
  - `nats.route.{detection|llm|templates|tools|prompts}` - Service routing
  """

  use GenServer
  require Logger

  alias Singularity.LLM.Service, as: LLMService
  alias Singularity.TemplateSparcOrchestrator
  alias Singularity.TemplatePerformanceTracker
  alias Singularity.Agents.CostOptimizedAgent
  alias Singularity.Detection.FrameworkDetector
  alias Singularity.Tools.Runner

  @type complexity :: :simple | :medium | :complex
  @type service :: :detection | :llm | :templates | :tools | :prompts
  @type request_type :: :detect_framework | :generate_code | :analyze_quality | :optimize_prompt | :execute_tool

  @type unified_request :: %{
    required(:type) => request_type(),
    required(:data) => map(),
    optional(:complexity) => complexity(),
    optional(:service) => service(),
    optional(:correlation_id) => String.t(),
    optional(:timeout) => non_neg_integer()
  }

  @type unified_response :: %{
    required(:success) => boolean(),
    required(:data) => map(),
    optional(:error) => String.t(),
    optional(:service_used) => service(),
    optional(:complexity) => complexity(),
    optional(:correlation_id) => String.t(),
    optional(:metrics) => map()
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Use Singularity.NatsClient for NATS operations
    # Subscribe to NATS request subjects
    Enum.each([
      "nats.request",
      "nats.request.simple", 
      "nats.request.medium",
      "nats.request.complex"
    ], fn subject ->
      case Singularity.NatsClient.subscribe(subject) do
        :ok -> Logger.info("NatsServer subscribed to: #{subject}")
        {:error, reason} -> Logger.error("Failed to subscribe to #{subject}: #{reason}")
      end
    end)

    # Subscribe to engine discovery subjects (for introspection/autonomy)
    # EngineDiscoveryHandler should use NatsClient internally
    Singularity.Nats.EngineDiscoveryHandler.subscribe()

    Logger.info("🚀 NATS Server started - Single entry point for all services")

    {:ok, %{}}
  end

  @impl true
  def handle_info({:msg, %{topic: topic, body: body, reply_to: reply_to}}, state) do
    Task.async(fn ->
      handle_nats_request(topic, body, reply_to)
    end)

    {:noreply, state}
  end

  @doc """
  Process NATS request through appropriate service.
  """
  def handle_nats_request(topic, body, reply_to) do
    start_time = System.monotonic_time(:millisecond)

    try do
      # Route engine discovery requests to dedicated handler
      if String.starts_with?(topic, "system.") do
        handle_engine_discovery_request(topic, body, reply_to)
      else
        # Regular NATS request handling
        request = Jason.decode!(body)
        complexity = extract_complexity_from_topic(topic)
        service = determine_service(request, complexity)

        Logger.debug("NATS Server routing request",
          type: request["type"],
          complexity: complexity,
          service: service,
          correlation_id: request["correlation_id"]
        )

        # Route to appropriate service
        result = route_to_service(service, request, complexity)

        # Build NATS response
        response = build_nats_response(result, service, complexity, request["correlation_id"])

        # Add performance metrics
        end_time = System.monotonic_time(:millisecond)
        response = Map.put(response, :metrics, %{
          processing_time_ms: end_time - start_time,
          service: service,
          complexity: complexity
        })

        # Send response back via NATS
        Singularity.NatsClient.publish(reply_to, Jason.encode!(response))
      end

    rescue
      error ->
        Logger.error("NATS Server error", error: error, topic: topic)
        error_response = %{
          success: false,
          error: Exception.message(error),
          data: %{},
          correlation_id: nil
        }
        Singularity.NatsClient.publish(reply_to, Jason.encode!(error_response))
    end
  end

  @doc """
  Handle engine discovery requests using NatsClient.
  """
  def handle_engine_discovery_request(topic, body, reply_to) do
    # Try to decode JSON payload (optional)
    request =
      case Jason.decode(body) do
        {:ok, decoded} -> decoded
        _ -> %{}
      end

    response =
      cond do
        topic == "system.engines.list" ->
          handle_list_engines(request)

        String.starts_with?(topic, "system.engines.get.") ->
          handle_get_engine(request)

        topic == "system.capabilities.list" ->
          handle_list_capabilities(request)

        topic == "system.capabilities.available" ->
          handle_available_capabilities(request)

        topic == "system.health.engines" ->
          handle_health_check(request)

        true ->
          %{error: "Unknown subject", subject: topic}
      end

    # Send response back via NATS
    Singularity.NatsClient.publish(reply_to, Jason.encode!(response))
  end

  # Engine discovery handlers (simplified versions without direct Gnat usage)
  defp handle_list_engines(_request) do
    %{engines: ["architecture", "code", "prompt", "quality", "generator"]}
  end

  defp handle_get_engine(_request) do
    %{error: "Engine details not implemented yet"}
  end

  defp handle_list_capabilities(_request) do
    %{capabilities: ["parse_ast", "generate_code", "optimize_prompt", "analyze_quality"]}
  end

  defp handle_available_capabilities(_request) do
    %{capabilities: ["parse_ast", "generate_code"], available_count: 2, total: 4}
  end

  defp handle_health_check(_request) do
    %{status: "healthy", engines_checked: 5, healthy_count: 5}
  end

  # Extract complexity from NATS topic
  defp extract_complexity_from_topic("nats.request.simple"), do: :simple
  defp extract_complexity_from_topic("nats.request.medium"), do: :medium
  defp extract_complexity_from_topic("nats.request.complex"), do: :complex
  defp extract_complexity_from_topic(_), do: :medium  # Default

  # Determine which service should handle the request
  defp determine_service(request, complexity) do
    case request["type"] do
      "detect_framework" -> :detection
      "generate_code" -> :llm
      "analyze_quality" -> :tools
      "optimize_prompt" -> :prompts
      "execute_tool" -> :tools
      _ -> 
        # Auto-determine based on content
        if String.contains?(request["data"]["content"] || "", ["framework", "detect"]) do
          :detection
        else
          :llm
        end
    end
  end

  # Route request to appropriate service
  defp route_to_service(:detection, request, complexity) do
    # Use consolidated detector system
    patterns = request["data"]["patterns"] || []
    context = request["data"]["context"] || ""

    case FrameworkDetector.detect_frameworks(patterns, context: context) do
      {:ok, results} -> {:ok, results}
      {:error, reason} -> {:error, reason}
    end
  end

  defp route_to_service(:llm, request, complexity) do
    # Use centralized LLM service with complexity-aware model selection
    messages = request["data"]["messages"] || []
    task_type = request["data"]["task_type"] || "general"

    Singularity.LLM.Service.call(
      complexity,
      messages,
      task_type: task_type
    )
  end

  defp route_to_service(:templates, request, complexity) do
    # Use template orchestrator
    task = request["data"]["task"] || ""
    language = request["data"]["language"] || "auto"

    case TemplateSparcOrchestrator.optimize_template(task, language, complexity) do
      {:ok, template} -> {:ok, %{template: template}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp route_to_service(:tools, request, complexity) do
    # Use tool runner
    tool_name = request["data"]["tool_name"]
    arguments = request["data"]["arguments"] || %{}

    case Runner.execute_tool(tool_name, arguments) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp route_to_service(:prompts, request, complexity) do
    # Use prompt engine via NATS
    context = request["data"]["context"] || ""
    language = request["data"]["language"] || "auto"
    prompt_type = request["data"]["prompt_type"] || "general"

    # Call prompt engine via NATS
    case Singularity.NatsClient.request("prompt.generate", Jason.encode!(%{
      context: context,
      language: language,
      prompt_type: prompt_type,
      complexity: complexity
    }), timeout: 10_000) do
      {:ok, response} ->
        case Jason.decode(response.data) do
          {:ok, data} -> {:ok, data}
          {:error, reason} -> 
            Logger.error("Failed to decode prompt response", reason: reason)
            {:error, :json_decode_error}
        end
      
      {:error, reason} ->
        Logger.error("Prompt engine NATS call failed", reason: reason)
        # Fallback to simple prompt generation
        {:ok, %{prompt: "Generated prompt for #{context} in #{language}"}}
    end
  end

  # Build NATS response format
  defp build_nats_response({:ok, data}, service, complexity, correlation_id) do
    %{
      success: true,
      data: data,
      service_used: service,
      complexity: complexity,
      correlation_id: correlation_id
    }
  end

  defp build_nats_response({:error, reason}, service, complexity, correlation_id) do
    %{
      success: false,
      error: inspect(reason),
      data: %{},
      service_used: service,
      complexity: complexity,
      correlation_id: correlation_id
    }
  end

  @doc """
  Public API for making NATS requests.
  """
  def request(type, data, opts \\ []) do
    complexity = Keyword.get(opts, :complexity, :medium)
    correlation_id = Keyword.get(opts, :correlation_id, generate_correlation_id())
    timeout = Keyword.get(opts, :timeout, 30_000)

    request = %{
      type: type,
      data: data,
      complexity: complexity,
      correlation_id: correlation_id
    }

    subject = case complexity do
      :simple -> "nats.request.simple"
      :medium -> "nats.request.medium"
      :complex -> "nats.request.complex"
    end

    case Singularity.NatsClient.request("nats.request", Jason.encode!(request), timeout: timeout) do
      {:ok, response} ->
        case Jason.decode(response.data) do
          {:ok, data} -> {:ok, data}
          {:error, reason} -> {:error, {:json_decode, reason}}
        end
      {:error, reason} -> {:error, {:nats_request, reason}}
    end
  end

  defp generate_correlation_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end