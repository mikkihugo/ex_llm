defmodule Singularity.SharedQueueConsumer do
  @moduledoc """
  Singularity Consumer - Reads responses from shared_queue and delivers to agents.

  Singularity publishes requests to shared_queue and then polls for responses:
  - Reads LLM results from Nexus
  - Reads job results from Genesis
  - Reads approval/question responses from HITL bridge

  ## Message Flow

  ```
  Singularity Agent
      ↓ publishes request
  pgmq.llm_requests / job_requests / etc.
      ↓
  External Service (Nexus, Genesis, HITL)
      ↓ publishes response
  pgmq.llm_results / job_results / responses
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

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
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
  Consume LLM results from Nexus - FILTERED BY AGENT.

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

    # TODO: Deliver result to waiting agent/process
    # This would typically be done via:
    # - Agent mailbox (if using Agent)
    # - GenServer state
    # - Named process
    # - Registry lookup by request_id
  end

  defp handle_job_result(result) do
    msg = result[:msg] || %{}

    Logger.info("[Singularity.SharedQueueConsumer] Received job result", %{
      request_id: msg["request_id"],
      has_error: msg["error"] != nil
    })

    # TODO: Deliver result to waiting agent/process
  end

  defp handle_approval_response(response) do
    msg = response[:msg] || %{}

    Logger.info("[Singularity.SharedQueueConsumer] Received approval response", %{
      request_id: msg["request_id"],
      approved: msg["approved"]
    })

    # TODO: Deliver response to waiting agent/process
  end

  defp handle_question_response(response) do
    msg = response[:msg] || %{}

    Logger.info("[Singularity.SharedQueueConsumer] Received question response", %{
      request_id: msg["request_id"]
    })

    # TODO: Deliver response to waiting agent/process
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
          r in Singularity.Schemas.Core.LLMRequest,
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

      # TODO: Route request to LLM provider via NATS
      # When response arrives, handle_llm_response should:
      # 1. Check if response is valid (call succeeded)
      # 2. Validate with Instructor schema (if provided)
      # 3. Mark as completed or failed accordingly
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

  Called when LLM response is received (either from NATS or pgmq).

  Handles:
  1. Empty/nil responses → marked as failed (LLM down)
  2. Malformed JSON → marked as failed (malformed response)
  3. Instructor validation → marked as completed/failed based on schema
  """
  def handle_llm_response(llm_request_id, response, parsed_response \\ nil) do
    case Singularity.Repo.get(Singularity.Schemas.Core.LLMRequest, llm_request_id) do
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
        # TODO: Call Instructor validation if needed
        # For now, assume response is valid if we received it
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
      Singularity.Schemas.Core.LLMRequest.mark_completed_with_response(
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
      Singularity.Schemas.Core.LLMRequest.mark_failed(request, error_message)

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
      Singularity.Schemas.Core.LLMRequest.mark_failed_llm_down(request, reason)

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
      Singularity.Schemas.Core.LLMRequest.mark_failed_malformed_response(
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
      Singularity.Schemas.Core.LLMRequest.mark_failed_malformed_response(
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

  TODO: Replace with actual agent discovery mechanism:
  - Option 1: Registry.lookup() for running agents
  - Option 2: Configuration from config.exs
  - Option 3: Supervision tree introspection
  """
  defp get_my_agent_ids do
    # For now, return all agents
    # TODO: Implement proper agent discovery
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
