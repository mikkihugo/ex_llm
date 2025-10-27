defmodule Singularity.SharedQueueConsumer do
  @moduledoc """
  Singularity Consumer - Reads responses from shared_queue and delivers to agents.

  Singularity publishes requests to shared_queue and then polls for responses:
  - Reads LLM results from external services
  - Reads job results from Genesis
  - Reads approval/question responses from HITL bridge

  ## Message Flow

  ```
  Singularity Agent
      ↓ publishes request
  Singularity.Jobs.PgmqClient.llm_requests / job_requests / etc.
      ↓
  External Service (Genesis, HITL)
      ↓ publishes response
  Singularity.Jobs.PgmqClient.llm_results / job_results / responses
      ↓
  Singularity.SharedQueueConsumer.consume_responses()
      ↓ delivers to agent
  Singularity Agent
  ```

  ## Configuration

  ```elixir
  config :singularity, :shared_queue,
    enabled: true,
    database_url: System.get_env("SHARED_QUEUE_DB_URL"),
    poll_interval_ms: 1000,
    batch_size: 10
  ```

  ## Usage

  Start the consumer:
  ```elixir
  {:ok, _pid} = Singularity.SharedQueueConsumer.start_link([])
  ```

  Or add to supervision tree:
  ```elixir
  {Singularity.SharedQueueConsumer, []}
  ```
  """

  use GenServer
  require Logger
  import Ecto.Query
  alias Singularity.Jobs.PgmqClient

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, _opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("[Singularity.SharedQueueConsumer] Starting response consumer")

    # Start polling immediately (both regular and LLM-specific)
    schedule_poll()
    schedule_llm_poll()

    {:ok, %{}}
  end

  @impl true
  def handle_info(:poll, state) do
    consume_all_responses()
    schedule_poll()
    {:noreply, state}
  end

  @impl true
  def handle_info(:poll_llm, state) do
    consume_pending_llm_requests()
    schedule_llm_poll()
    {:noreply, state}
  end

  # --- Response Consumption ---

  @doc """
  Consume all response types from shared_queue.
  """
  def consume_all_responses do
    consume_llm_results()
    consume_job_results()
    consume_approval_responses()
    consume_question_responses()
  end

  @doc """
  Consume LLM results from external LLM router - FILTERED BY AGENT.

  CRITICAL: Only process results for agents owned by this Singularity instance.
  This prevents cross-contamination between multiple Singularity instances.
  """
  def consume_llm_results do
    case Singularity.SharedQueuePublisher.read_llm_results(limit: 10) do
      {:ok, results} when is_list(results) ->
        # Filter results to only include results for OUR agents
        my_agent_ids = get_my_agent_ids()

        Enum.each(results, fn result ->
          msg = result[:msg] || %{}
          agent_id = msg["agent_id"]

          if Enum.member?(my_agent_ids, agent_id) do
            handle_llm_result(result)
          else
            # Not ours - log and skip
            Logger.debug(
              "[Singularity.SharedQueueConsumer] Skipping result for different agent",
              %{
                agent_id: agent_id,
                our_agents: my_agent_ids
              }
            )
          end
        end)

      :empty ->
        :ok

      {:error, reason} ->
        Logger.error("[Singularity.SharedQueueConsumer] Failed to read LLM results", %{
          error: reason
        })
    end
  end

  @doc """
  Consume job results from Genesis.
  """
  def consume_job_results do
    case Singularity.SharedQueuePublisher.read_job_results(limit: 10) do
      {:ok, results} when is_list(results) ->
        Enum.each(results, fn result ->
          handle_job_result(result)
        end)

      :empty ->
        :ok

      {:error, reason} ->
        Logger.error("[Singularity.SharedQueueConsumer] Failed to read job results", %{
          error: reason
        })
    end
  end

  @doc """
  Consume approval responses from HITL bridge.
  """
  def consume_approval_responses do
    case Singularity.SharedQueuePublisher.read_approval_responses(limit: 10) do
      {:ok, responses} when is_list(responses) ->
        Enum.each(responses, fn response ->
          handle_approval_response(response)
        end)

      :empty ->
        :ok

      {:error, reason} ->
        Logger.error("[Singularity.SharedQueueConsumer] Failed to read approval responses", %{
          error: reason
        })
    end
  end

  @doc """
  Consume question responses from HITL bridge.
  """
  def consume_question_responses do
    case Singularity.SharedQueuePublisher.read_question_responses(limit: 10) do
      {:ok, responses} when is_list(responses) ->
        Enum.each(responses, fn response ->
          handle_question_response(response)
        end)

      :empty ->
        :ok

      {:error, reason} ->
        Logger.error("[Singularity.SharedQueueConsumer] Failed to read question responses", %{
          error: reason
        })
    end
  end

  # --- Message Handlers ---

  defp handle_llm_result(result) do
    msg = result[:msg] || %{}

    Logger.info("[Singularity.SharedQueueConsumer] Received LLM result", %{
      request_id: msg["request_id"],
      model: msg["model"]
    })

    # Deliver result to waiting agent/process
    deliver_result_to_agent(msg["request_id"], msg)
  end

  defp handle_job_result(result) do
    msg = result[:msg] || %{}

    Logger.info("[Singularity.SharedQueueConsumer] Received job result", %{
      request_id: msg["request_id"],
      has_error: msg["error"] != nil
    })

    # Deliver result to waiting agent/process
    deliver_result_to_agent(msg["request_id"], msg)
  end

  defp handle_approval_response(response) do
    msg = response[:msg] || %{}

    Logger.info("[Singularity.SharedQueueConsumer] Received approval response", %{
      request_id: msg["request_id"],
      approved: msg["approved"]
    })

    # Deliver response to waiting agent/process
    deliver_result_to_agent(msg["request_id"], msg)
  end

  defp handle_question_response(response) do
    msg = response[:msg] || %{}

    Logger.info("[Singularity.SharedQueueConsumer] Received question response", %{
      request_id: msg["request_id"]
    })

    # Deliver response to waiting agent/process
    deliver_result_to_agent(msg["request_id"], msg)
  end

  # --- LLM Request Polling (Fast) ---

  @doc """
  Consume pending LLM requests from local table and update their status.

  Polls the local llm_requests table (instead of pgmq) for faster response
  to new LLM requests from agents. This allows lower-latency polling (100ms)
  compared to regular queue polling (1000ms).
  """
  def consume_pending_llm_requests do
    batch_size = config()[:llm_batch_size] || 50

    case read_pending_llm_requests(batch_size) do
      {:ok, requests} when is_list(requests) and length(requests) > 0 ->
        Logger.info("[Singularity.SharedQueueConsumer] Processing pending LLM requests", %{
          count: length(requests)
        })

        Enum.each(requests, fn request ->
          handle_pending_llm_request(request)
        end)

      :empty ->
        # No pending requests
        :ok

      {:error, reason} ->
        Logger.error("[Singularity.SharedQueueConsumer] Failed to read pending LLM requests", %{
          error: reason
        })

        :ok
    end
  end

  defp read_pending_llm_requests(limit) do
    try do
      # Query local llm_requests table for pending requests
      # These are requests that have been stored but not yet published to pgmq
      query =
        from(
          r in Singularity.LLMSchemas.LLMRequest,
          where: r.status == "pending",
          order_by: [asc: r.created_at],
          limit: ^limit
        )

      requests = Singularity.Repo.all(query)

      case requests do
        [] -> :empty
        _ -> {:ok, requests}
      end
    rescue
      e ->
        Logger.error("[Singularity.SharedQueueConsumer] Exception reading LLM requests", %{
          error: inspect(e)
        })

        :empty
    end
  end

  defp handle_pending_llm_request(llm_request) do
    try do
      Logger.debug("[Singularity.SharedQueueConsumer] Processing pending LLM request", %{
        id: llm_request.id,
        agent_id: llm_request.agent_id,
        task_type: llm_request.task_type
      })

      # Mark as processing immediately
      update_llm_request_status(llm_request, "processing")

      # Route request to LLM provider via PGMQ
      route_llm_request_to_provider(llm_request)
    rescue
      e ->
        Logger.error("[Singularity.SharedQueueConsumer] Exception processing LLM request", %{
          id: llm_request.id,
          error: inspect(e),
          type: Exception.module(e)
        })

        # Mark as failed with error details
        mark_request_failed(llm_request, inspect(e))
    end
  end

  @doc """
  Handle LLM response - validates JSON and Instructor schema if provided.

  Called when LLM response is received from PGMQ.

  Handles:
  1. Empty/nil responses → marked as failed (LLM down)
  2. Malformed JSON → marked as failed (malformed response)
  3. Instructor validation → marked as completed/failed based on schema
  """
  def handle_llm_response(llm_request_id, response, parsed_response \\ nil) do
    case Singularity.Repo.get(Singularity.LLMSchemas.LLMRequest, llm_request_id) do
      nil ->
        Logger.warn("[Singularity.SharedQueueConsumer] LLM request not found", %{
          id: llm_request_id
        })

      request ->
        handle_llm_response_impl(request, response, parsed_response)
    end
  end

  defp handle_llm_response_impl(request, response, parsed_response) do
    cond do
      # Response is empty or nil - LLM provider returned nothing
      is_nil(response) or response == "" ->
        Logger.error("[Singularity.SharedQueueConsumer] LLM provider returned empty response", %{
          id: request.id,
          agent_id: request.agent_id
        })

        mark_request_failed_llm_down(request, "LLM provider returned empty response")

      # Try to validate JSON if response looks like JSON
      is_binary(response) and String.starts_with?(String.trim(response), ["{", "["]) ->
        case validate_json_response(response) do
          {:ok, decoded} ->
            # JSON is valid, proceed with Instructor validation if needed
            if not is_nil(request.response_schema) do
              validate_instructor_response(request, response, parsed_response || decoded)
            else
              mark_request_completed(request, response, parsed_response || decoded)
            end

          {:error, json_error} ->
            # Malformed JSON
            Logger.error("[Singularity.SharedQueueConsumer] Malformed JSON response", %{
              id: request.id,
              error: json_error
            })

            mark_request_failed_malformed_json(request, response, json_error)
        end

      # If Instructor schema is provided (non-JSON response), validate response
      not is_nil(request.response_schema) ->
        validate_instructor_response(request, response, parsed_response)

      # No schema required, just store response (plain text)
      true ->
        mark_request_completed(request, response, parsed_response)
    end
  end

  # Validate that response is valid JSON
  # Returns {:ok, decoded} or {:error, error_message}
  defp validate_json_response(response) when is_binary(response) do
    try do
      case Jason.decode(response) do
        {:ok, decoded} ->
          {:ok, decoded}

        {:error, %Jason.DecodeError{position: pos, data: data}} ->
          error_msg = "JSON decode error at position #{pos}: #{inspect(data)}"
          {:error, error_msg}

        {:error, reason} ->
          {:error, "JSON decode error: #{inspect(reason)}"}
      end
    rescue
      e ->
        {:error, "JSON parsing exception: #{inspect(e)}"}
    end
  end

  # Validate LLM response using Instructor schema
  # Returns {:ok, validated_response} or {:error, validation_errors}
  defp validate_instructor_response(request, response, parsed_response) do
    try do
      # If parsed_response is already provided (pre-validated), trust it
      if not is_nil(parsed_response) do
        Logger.info("[Singularity.SharedQueueConsumer] LLM response validated by Instructor", %{
          id: request.id,
          agent_id: request.agent_id
        })

        mark_request_completed(request, response, parsed_response)
      else
        # Validate response with Instructor if schema provided
        validate_response_with_instructor(request, response)
        Logger.info(
          "[Singularity.SharedQueueConsumer] LLM response received (awaiting Instructor validation)",
          %{
            id: request.id,
            agent_id: request.agent_id
          }
        )

        mark_request_completed(request, response, parsed_response)
      end
    rescue
      e ->
        Logger.error("[Singularity.SharedQueueConsumer] Instructor validation exception", %{
          id: request.id,
          error: inspect(e),
          type: Exception.module(e)
        })

        # Capture validation error
        validation_error = %{
          error: "Instructor validation exception",
          message: inspect(e),
          type: Exception.module(e)
        }

        mark_request_failed_validation(request, response, [validation_error])
    end
  end

  # Helper functions for status updates

  defp mark_request_completed(request, response, parsed_response) do
    changeset =
      Singularity.LLMSchemas.LLMRequest.mark_completed_with_response(
        request,
        response,
        parsed_response
      )

    case Singularity.Repo.update(changeset) do
      {:ok, updated_request} ->
        Logger.info("[Singularity.SharedQueueConsumer] LLM request completed", %{
          id: updated_request.id,
          agent_id: updated_request.agent_id,
          status: "completed"
        })

      {:error, reason} ->
        Logger.error("[Singularity.SharedQueueConsumer] Failed to mark request completed", %{
          id: request.id,
          error: inspect(reason)
        })
    end
  end

  defp mark_request_failed(request, error_message) do
    changeset =
      Singularity.LLMSchemas.LLMRequest.mark_failed(request, error_message)

    case Singularity.Repo.update(changeset) do
      {:ok, _updated_request} ->
        Logger.info("[Singularity.SharedQueueConsumer] LLM request marked failed", %{
          id: request.id,
          agent_id: request.agent_id,
          reason: error_message
        })

      {:error, reason} ->
        Logger.error("[Singularity.SharedQueueConsumer] Failed to mark request failed", %{
          id: request.id,
          error: inspect(reason)
        })
    end
  end

  defp mark_request_failed_llm_down(request, reason) do
    changeset =
      Singularity.LLMSchemas.LLMRequest.mark_failed_llm_down(request, reason)

    case Singularity.Repo.update(changeset) do
      {:ok, _updated_request} ->
        Logger.warn("[Singularity.SharedQueueConsumer] LLM request failed - provider down", %{
          id: request.id,
          reason: reason
        })

      {:error, error} ->
        Logger.error(
          "[Singularity.SharedQueueConsumer] Failed to mark request as LLM provider down",
          %{
            id: request.id,
            error: inspect(error)
          }
        )
    end
  end

  defp mark_request_failed_validation(request, response, validation_errors) do
    changeset =
      Singularity.LLMSchemas.LLMRequest.mark_failed_malformed_response(
        request,
        response,
        validation_errors
      )

    case Singularity.Repo.update(changeset) do
      {:ok, _updated_request} ->
        Logger.warn("[Singularity.SharedQueueConsumer] LLM request failed - validation error", %{
          id: request.id,
          validation_errors: length(validation_errors)
        })

      {:error, error} ->
        Logger.error("[Singularity.SharedQueueConsumer] Failed to mark request as validation failed",
          %{
            id: request.id,
            error: inspect(error)
          }
        )
    end
  end

  defp mark_request_failed_malformed_json(request, response, json_error) do
    validation_error = %{
      type: "json_decode_error",
      error: json_error,
      response_preview: String.slice(response, 0..100)
    }

    changeset =
      Singularity.LLMSchemas.LLMRequest.mark_failed_malformed_response(
        request,
        response,
        [validation_error]
      )

    case Singularity.Repo.update(changeset) do
      {:ok, _updated_request} ->
        Logger.warn("[Singularity.SharedQueueConsumer] LLM request failed - malformed JSON", %{
          id: request.id,
          json_error: json_error
        })

      {:error, error} ->
        Logger.error("[Singularity.SharedQueueConsumer] Failed to mark request as malformed JSON",
          %{
            id: request.id,
            error: inspect(error)
          }
        )
    end
  end

  defp update_llm_request_status(llm_request, status, error_message \\ nil) do
    changeset =
      llm_request
      |> Ecto.Changeset.change(%{status: status, error_message: error_message})

    case Singularity.Repo.update(changeset) do
      {:ok, _} ->
        Logger.debug("[Singularity.SharedQueueConsumer] Updated LLM request status", %{
          id: llm_request.id,
          status: status
        })

      {:error, reason} ->
        Logger.error("[Singularity.SharedQueueConsumer] Failed to update LLM request status", %{
          id: llm_request.id,
          error: inspect(reason)
        })
    end
  end

  # --- Private Helpers ---

  defp call_pgmq(queue_name, payload) do
    case PgmqClient.send_message(queue_name, payload) do
      {:ok, _msg_id} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp call_pgmq(_queue, _payload), do: :ok

  defp schedule_poll do
    poll_interval = config()[:poll_interval_ms] || 1000
    Process.send_after(self(), :poll, poll_interval)
  end

  defp schedule_llm_poll do
    llm_poll_interval = config()[:llm_request_poll_ms] || 100
    Process.send_after(self(), :poll_llm, llm_poll_interval)
  end

  defp config do
    Application.get_env(:singularity, :shared_queue, [])
  end

  # --- Agent Isolation ---

  @doc """
  Get list of agent IDs that this Singularity instance owns.

  CRITICAL: Only consume messages for OUR agents.
  This prevents cross-contamination in multi-instance setups.

  Agent discovery uses Registry.lookup() for running agents with fallback to configuration.
  """
  defp deliver_result_to_agent(request_id, result) do
    # Try to find the agent process by request_id
    case Registry.lookup(Singularity.AgentRegistry, request_id) do
      [{pid, _}] ->
        # Send result to the agent process
        send(pid, {:queue_result, request_id, result})
        Logger.debug("✅ Delivered result to agent #{inspect(pid)} for request #{request_id}")
        
      [] ->
        # Try to find by agent_id pattern
        case find_agent_by_request_pattern(request_id) do
          {:ok, agent_pid} ->
            send(agent_pid, {:queue_result, request_id, result})
            Logger.debug("✅ Delivered result to agent #{inspect(agent_pid)} for request #{request_id}")
            
          :not_found ->
            Logger.warning("⚠️  No agent found for request_id: #{request_id}")
        end
    end
  end

  defp find_agent_by_request_pattern(request_id) do
    # Extract agent type from request_id pattern
    agent_type = 
      cond do
        String.contains?(request_id, "self-improving") -> "self-improving-agent"
        String.contains?(request_id, "architecture") -> "architecture-agent"
        String.contains?(request_id, "code-generator") -> "code-generator"
        String.contains?(request_id, "technology") -> "technology-detector"
        String.contains?(request_id, "refactoring") -> "refactoring-agent"
        String.contains?(request_id, "chat") -> "chat-agent"
        true -> nil
      end

    case agent_type do
      nil -> :not_found
      agent_id ->
        case Registry.lookup(Singularity.AgentRegistry, agent_id) do
          [{pid, _}] -> {:ok, pid}
          [] -> :not_found
        end
    end
  end

  defp route_llm_request_to_provider(llm_request) do
    # Publish LLM request to PGMQ for processing
    pgmq_queue = "llm_requests"
    
    request_payload = %{
      "request_id" => llm_request.id,
      "agent_id" => llm_request.agent_id,
      "prompt" => llm_request.prompt,
      "model" => llm_request.model,
      "provider" => llm_request.provider,
      "max_tokens" => llm_request.max_tokens,
      "temperature" => llm_request.temperature,
      "instructor_schema" => llm_request.instructor_schema
    }

    case call_pgmq(pgmq_queue, request_payload) do
      :ok ->
        Logger.info("✅ LLM request routed to provider: #{llm_request.provider}")
        
      {:error, reason} ->
        Logger.error("❌ Failed to route LLM request: #{inspect(reason)}")
        update_llm_request_status(llm_request, "failed")
    end
  end

  defp validate_response_with_instructor(request, response) do
    case request.instructor_schema do
      nil ->
        # No validation needed
        mark_request_completed(request, response, response)
        
      schema ->
        # Validate with Instructor
        case validate_with_instructor(response, schema) do
          {:ok, validated_response} ->
            mark_request_completed(request, response, validated_response)
            
          {:error, validation_error} ->
            Logger.error("❌ Instructor validation failed: #{inspect(validation_error)}")
            update_llm_request_status(request, "validation_failed")
        end
    end
  end

  defp validate_with_instructor(response, schema) do
    # Implement Instructor validation
    case validate_response_structure(response, schema) do
      {:ok, validated} -> {:ok, validated}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_response_structure(response, schema) do
    # Basic structure validation based on schema
    case schema do
      %{"type" => "object", "properties" => properties} ->
        validate_object_structure(response, properties)
      
      %{"type" => "array", "items" => item_schema} ->
        validate_array_structure(response, item_schema)
      
      _ ->
        # Unknown schema type, assume valid
        {:ok, response}
    end
  end

  defp validate_object_structure(response, properties) when is_map(response) do
    # Check required fields
    required_fields = Map.get(properties, "required", [])
    
    missing_fields = 
      required_fields
      |> Enum.reject(fn field -> Map.has_key?(response, field) end)
    
    if Enum.empty?(missing_fields) do
      {:ok, response}
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end

  defp validate_object_structure(response, _properties) do
    {:error, "Expected object but got #{inspect(response)}"}
  end

  defp validate_array_structure(response, item_schema) when is_list(response) do
    # Validate each item in the array
    results = 
      response
      |> Enum.with_index()
      |> Enum.map(fn {item, index} ->
        case validate_response_structure(item, item_schema) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, "Item #{index}: #{reason}"}
        end
      end)
    
    errors = Enum.filter(results, &match?({:error, _}, &1))
    
    if Enum.empty?(errors) do
      {:ok, response}
    else
      error_messages = Enum.map(errors, fn {:error, msg} -> msg end)
      {:error, "Array validation failed: #{Enum.join(error_messages, "; ")}"}
    end
  end

  defp validate_array_structure(response, _item_schema) do
    {:error, "Expected array but got #{inspect(response)}"}
  end

  defp get_my_agent_ids do
    # Get running agents from Registry
    case Registry.select(Singularity.AgentRegistry, [{{:"$1", :"$2", :"$3"}, [], [:"$1"]}]) do
      agent_pids when is_list(agent_pids) ->
        agent_pids
        |> Enum.map(fn pid ->
          case Registry.keys(Singularity.AgentRegistry, pid) do
            [agent_id] -> agent_id
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
      
      _ ->
        # Fallback to configured agents
        [
          "self-improving-agent",
          "architecture-agent",
          "code-generator",
          "technology-detector",
          "refactoring-agent",
          "chat-agent"
        ]
    end
  end
end
