defmodule Singularity.SharedQueuePublisher do
  @moduledoc """
  Publisher for shared_queue messages (pgmq).

  Singularity publishes requests to the central shared_queue database
  (PostgreSQL with pgmq extension) for other services to consume:

  - **LLM Requests** → External LLM router (routes to Claude, Gemini, etc.)
  - **Approval Requests** → External HITL bridge
  - **Question Requests** → External HITL bridge
  - **Job Requests** → Genesis (code execution)

  Singularity reads responses back from the same queues:
  - **LLM Results** ← External LLM router
  - **Job Results** ← Genesis
  - **Approval Responses** ← Browser (via HITL bridge)
  - **Question Responses** ← Browser (via HITL bridge)

  ## Queue Architecture

  ```
  pgmq.llm_requests         ← Publish LLM requests to external router
  pgmq.llm_results          ← Read LLM responses from external router

  pgmq.approval_requests    ← Publish code approval requests
  pgmq.approval_responses   ← Read human approval decisions

  pgmq.question_requests    ← Publish questions to humans
  pgmq.question_responses   ← Read human responses

  pgmq.job_requests         ← Publish code execution requests to Genesis
  pgmq.job_results          ← Read code execution results from Genesis
  ```

  ## Configuration

  ```elixir
  # config/config.exs
  config :singularity, :shared_queue,
    enabled: true,
    database_url: System.get_env("SHARED_QUEUE_DB_URL"),
    poll_interval_ms: 1000,
    batch_size: 10
  ```

  ## Usage

  ```elixir
  # Publish LLM request to be routed by external LLM router
  Singularity.SharedQueuePublisher.publish_llm_request(%{
    agent_id: "self-improving-agent",
    task_type: "architect",
    complexity: :complex,
    messages: [
      %{role: "user", content: "Design a new feature"}
    ]
  })

  # Publish approval request
  Singularity.SharedQueuePublisher.publish_approval_request(%{
    id: UUID.uuid4(),
    file_path: "lib/my_module.ex",
    diff: "diff content",
    description: "Add feature X",
    agent_id: "self-improving-agent"
  })

  # Publish question to humans
  Singularity.SharedQueuePublisher.publish_question_request(%{
    id: UUID.uuid4(),
    question: "Should we use this design pattern?",
    context: %{code: "...", architecture: "..."},
    agent_id: "architecture-agent"
  })

  # Read LLM results
  case Singularity.SharedQueuePublisher.read_llm_results(limit: 10) do
    {:ok, results} -> process_results(results)
    :empty -> :no_results
  end
  ```

  ## Message Flow

  1. Agent publishes LLM request to shared_queue
  2. External LLM router consumes from `pgmq.llm_requests`
  3. External LLM router calls LLM provider (Claude, Gemini, etc.)
  4. External LLM router publishes result to `pgmq.llm_results`
  5. Singularity consumer reads from `pgmq.llm_results`
  6. Agent processes result and continues execution

  All communication is async and durable (persisted in PostgreSQL).
  """

  require Logger
  alias Singularity.SharedQueueConsumer

  # Queue names
  @queue_llm_requests "llm_requests"
  @queue_llm_results "llm_results"
  @queue_approval_requests "approval_requests"
  @queue_approval_responses "approval_responses"
  @queue_question_requests "question_requests"
  @queue_question_responses "question_responses"
  @queue_job_requests "job_requests"
  @queue_job_results "job_results"

  @doc """
  Publish LLM request to external LLM router for routing.

  Also stores the request in the local llm_requests table for faster polling
  by the SharedQueueConsumer.

  Returns `{:ok, msg_id}` on success, `{:error, reason}` on failure.

  ## Parameters

  - `request` - Map with keys:
    - `agent_id` (string, required) - Agent making the request
    - `task_type` (atom, required) - :simple, :medium, :complex
    - `complexity` (atom, optional) - Complexity level for model selection
    - `messages` (list, required) - Chat messages for LLM
    - `context` (map, optional) - Additional context for the LLM
  """
  def publish_llm_request(request) when is_map(request) do
    with :ok <- validate_llm_request(request),
         msg_id <- send_to_queue(@queue_llm_requests, request),
         true <- msg_id != nil,
         :ok <- store_llm_request(request) do
      Logger.info("[SharedQueue] Published LLM request", %{
        msg_id: msg_id,
        agent_id: request[:agent_id],
        task_type: request[:task_type]
      })

      {:ok, msg_id}
    else
      {:error, reason} ->
        Logger.error("[SharedQueue] Failed to publish LLM request", %{
          error: reason,
          request: request
        })

        {:error, reason}

      false ->
        Logger.error("[SharedQueue] Failed to publish LLM request (send_to_queue returned nil)", %{
          request: request
        })

        {:error, :failed_to_send}
    end
  end

  @doc """
  Publish code approval request to HITL bridge.

  Returns `{:ok, msg_id}` on success, `{:error, reason}` on failure.

  ## Parameters

  - `request` - Map with keys:
    - `id` (string, required) - Unique request ID (UUID)
    - `file_path` (string, required) - Path to file being modified
    - `diff` (string, required) - Diff of changes
    - `description` (string, required) - What/why this change
    - `agent_id` (string, required) - Agent making the request
  """
  def publish_approval_request(request) when is_map(request) do
    with :ok <- validate_approval_request(request),
         msg_id <- send_to_queue(@queue_approval_requests, request) do
      Logger.info("[SharedQueue] Published approval request", %{
        msg_id: msg_id,
        request_id: request[:id],
        agent_id: request[:agent_id],
        file_path: request[:file_path]
      })

      {:ok, msg_id}
    else
      {:error, reason} ->
        Logger.error("[SharedQueue] Failed to publish approval request", %{
          error: reason,
          request_id: request[:id]
        })

        {:error, reason}
    end
  end

  @doc """
  Publish question request to HITL bridge.

  Returns `{:ok, msg_id}` on success, `{:error, reason}` on failure.

  ## Parameters

  - `request` - Map with keys:
    - `id` (string, required) - Unique request ID (UUID)
    - `question` (string, required) - Question for human
    - `context` (map, optional) - Additional context (code, architecture, etc.)
    - `agent_id` (string, required) - Agent asking the question
  """
  def publish_question_request(request) when is_map(request) do
    with :ok <- validate_question_request(request),
         msg_id <- send_to_queue(@queue_question_requests, request) do
      Logger.info("[SharedQueue] Published question request", %{
        msg_id: msg_id,
        request_id: request[:id],
        agent_id: request[:agent_id]
      })

      {:ok, msg_id}
    else
      {:error, reason} ->
        Logger.error("[SharedQueue] Failed to publish question request", %{
          error: reason,
          request_id: request[:id]
        })

        {:error, reason}
    end
  end

  @doc """
  Publish code execution request to Genesis.

  Returns `{:ok, msg_id}` on success, `{:error, reason}` on failure.

  ## Parameters

  - `request` - Map with keys:
    - `id` (string, required) - Unique request ID (UUID)
    - `code` (string, required) - Code to execute
    - `language` (atom or string, required) - :elixir, :rust, :js, etc.
    - `agent_id` (string, required) - Agent making the request
    - `context` (map, optional) - Additional context
  """
  def publish_job_request(request) when is_map(request) do
    with :ok <- validate_job_request(request),
         msg_id <- send_to_queue(@queue_job_requests, request) do
      Logger.info("[SharedQueue] Published job request", %{
        msg_id: msg_id,
        request_id: request[:id],
        agent_id: request[:agent_id],
        language: request[:language]
      })

      {:ok, msg_id}
    else
      {:error, reason} ->
        Logger.error("[SharedQueue] Failed to publish job request", %{
          error: reason,
          request_id: request[:id]
        })

        {:error, reason}
    end
  end

  @doc """
  Read LLM results from external LLM router.

  Returns `{:ok, [results]}` or `:empty` if no messages.

  ## Options

  - `:limit` - Number of messages to read (default: 10)
  """
  def read_llm_results(opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    case read_from_queue(@queue_llm_results, limit) do
      {:ok, results} when is_list(results) ->
        Logger.debug("[SharedQueue] Read LLM results", %{count: length(results)})
        {:ok, results}

      :empty ->
        Logger.debug("[SharedQueue] No LLM results available")
        :empty

      {:error, reason} ->
        Logger.error("[SharedQueue] Failed to read LLM results", %{error: reason})
        {:error, reason}
    end
  end

  @doc """
  Read approval responses from humans (via browser).

  Returns `{:ok, [responses]}` or `:empty` if no messages.

  ## Options

  - `:limit` - Number of messages to read (default: 10)
  """
  def read_approval_responses(opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    case read_from_queue(@queue_approval_responses, limit) do
      {:ok, responses} when is_list(responses) ->
        Logger.debug("[SharedQueue] Read approval responses", %{count: length(responses)})
        {:ok, responses}

      :empty ->
        Logger.debug("[SharedQueue] No approval responses available")
        :empty

      {:error, reason} ->
        Logger.error("[SharedQueue] Failed to read approval responses", %{error: reason})
        {:error, reason}
    end
  end

  @doc """
  Read question responses from humans (via browser).

  Returns `{:ok, [responses]}` or `:empty` if no messages.

  ## Options

  - `:limit` - Number of messages to read (default: 10)
  """
  def read_question_responses(opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    case read_from_queue(@queue_question_responses, limit) do
      {:ok, responses} when is_list(responses) ->
        Logger.debug("[SharedQueue] Read question responses", %{count: length(responses)})
        {:ok, responses}

      :empty ->
        Logger.debug("[SharedQueue] No question responses available")
        :empty

      {:error, reason} ->
        Logger.error("[SharedQueue] Failed to read question responses", %{error: reason})
        {:error, reason}
    end
  end

  @doc """
  Read job results from Genesis.

  Returns `{:ok, [results]}` or `:empty` if no messages.

  ## Options

  - `:limit` - Number of messages to read (default: 10)
  """
  def read_job_results(opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    case read_from_queue(@queue_job_results, limit) do
      {:ok, results} when is_list(results) ->
        Logger.debug("[SharedQueue] Read job results", %{count: length(results)})
        {:ok, results}

      :empty ->
        Logger.debug("[SharedQueue] No job results available")
        :empty

      {:error, reason} ->
        Logger.error("[SharedQueue] Failed to read job results", %{error: reason})
        {:error, reason}
    end
  end

  # --- Private Helpers ---

  defp validate_llm_request(request) do
    required = [:agent_id, :task_type, :messages]

    case Enum.all?(required, &Map.has_key?(request, &1)) do
      true -> :ok
      false -> {:error, :missing_required_fields}
    end
  end

  defp validate_approval_request(request) do
    required = [:id, :file_path, :diff, :description, :agent_id]

    case Enum.all?(required, &Map.has_key?(request, &1)) do
      true -> :ok
      false -> {:error, :missing_required_fields}
    end
  end

  defp validate_question_request(request) do
    required = [:id, :question, :agent_id]

    case Enum.all?(required, &Map.has_key?(request, &1)) do
      true -> :ok
      false -> {:error, :missing_required_fields}
    end
  end

  defp validate_job_request(request) do
    required = [:id, :code, :language, :agent_id]

    case Enum.all?(required, &Map.has_key?(request, &1)) do
      true -> :ok
      false -> {:error, :missing_required_fields}
    end
  end

  defp send_to_queue(queue_name, message) do
    unless enabled?() do
      Logger.warn("[SharedQueue] Shared queue disabled, message not sent", %{queue: queue_name})
      nil
    else
      try do
        # Convert message to JSON
        json_msg = Jason.encode!(message)

        # Get database connection
        db_url = database_url()
        {:ok, pid} = Postgrex.start_link(parse_connection_string(db_url))

        # Call pgmq.send(queue_name, json_msg)
        case Postgrex.query(
               pid,
               "SELECT pgmq.send($1, $2::jsonb)",
               [queue_name, json_msg]
             ) do
          {:ok, result} ->
            msg_id = extract_msg_id(result)

            Logger.debug("[SharedQueue] Published message to queue", %{
              queue: queue_name,
              msg_id: msg_id
            })

            Postgrex.close(pid)
            msg_id

          {:error, reason} ->
            Logger.error("[SharedQueue] Failed to send to queue", %{
              queue: queue_name,
              error: inspect(reason)
            })

            Postgrex.close(pid)
            nil
        end
      rescue
        e ->
          Logger.error("[SharedQueue] Exception sending to queue", %{
            queue: queue_name,
            error: inspect(e)
          })

          nil
      end
    end
  end

  defp read_from_queue(queue_name, limit) do
    unless enabled?() do
      Logger.debug("[SharedQueue] Shared queue disabled, cannot read", %{queue: queue_name})
      :empty
    else
      try do
        # Get database connection
        db_url = database_url()
        {:ok, pid} = Postgrex.start_link(parse_connection_string(db_url))

        # Call pgmq.read(queue_name, limit)
        case Postgrex.query(
               pid,
               "SELECT msg_id, read_ct, enqueued_at, vt, msg FROM pgmq.read($1, $2)",
               [queue_name, limit]
             ) do
          {:ok, result} when result.num_rows > 0 ->
            messages = parse_pgmq_results(result)

            Logger.debug("[SharedQueue] Read messages from queue", %{
              queue: queue_name,
              count: length(messages)
            })

            Postgrex.close(pid)
            {:ok, messages}

          {:ok, _result} ->
            Logger.debug("[SharedQueue] No messages in queue", %{queue: queue_name})
            Postgrex.close(pid)
            :empty

          {:error, reason} ->
            Logger.error("[SharedQueue] Failed to read from queue", %{
              queue: queue_name,
              error: inspect(reason)
            })

            Postgrex.close(pid)
            {:error, reason}
        end
      rescue
        e ->
          Logger.error("[SharedQueue] Exception reading from queue", %{
            queue: queue_name,
            error: inspect(e)
          })

          :empty
      end
    end
  end

  # --- Helper Functions ---

  defp parse_connection_string(url) do
    case URI.parse(url) do
      %URI{
        host: host,
        port: port,
        userinfo: userinfo,
        path: path
      } ->
        [user, password] = if userinfo, do: String.split(userinfo, ":"), else: ["postgres", ""]
        database = String.trim_leading(path, "/")

        [
          hostname: host,
          port: port || 5432,
          username: user,
          password: password,
          database: database
        ]

      _ ->
        raise "Invalid database URL: #{url}"
    end
  end

  defp extract_msg_id(result) do
    case result.rows do
      [[msg_id]] -> msg_id
      _ -> nil
    end
  end

  defp parse_pgmq_results(result) do
    Enum.map(result.rows, fn row ->
      case row do
        [msg_id, read_ct, enqueued_at, vt, msg] ->
          %{
            msg_id: msg_id,
            read_ct: read_ct,
            enqueued_at: enqueued_at,
            vt: vt,
            msg: msg
          }

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # --- LLM Request Storage ---

  @doc """
  Store LLM request in local table for faster polling.

  Stores the request with status 'pending' so that SharedQueueConsumer
  can poll the local table more frequently (100ms) instead of polling pgmq (1000ms).

  Returns :ok on success, {:error, reason} on failure.
  """
  defp store_llm_request(request) do
    complexity = request[:complexity] || "medium"

    attrs = %{
      agent_id: request[:agent_id],
      task_type: request[:task_type],
      complexity: to_string(complexity),
      messages: request[:messages] || [],
      context: request[:context] || %{},
      status: "pending"
    }

    try do
      case Singularity.Repo.insert(
             Singularity.Schemas.Core.LLMRequest.changeset(
               %Singularity.Schemas.Core.LLMRequest{},
               attrs
             )
           ) do
        {:ok, _llm_request} ->
          Logger.debug("[SharedQueue] Stored LLM request in local table", %{
            agent_id: request[:agent_id],
            task_type: request[:task_type]
          })

          :ok

        {:error, changeset} ->
          Logger.error("[SharedQueue] Failed to store LLM request", %{
            errors: inspect(changeset.errors)
          })

          {:error, :storage_failed}
      end
    rescue
      e ->
        Logger.error("[SharedQueue] Exception storing LLM request", %{
          error: inspect(e)
        })

        {:error, :storage_error}
    end
  end

  @doc """
  Check if shared_queue is enabled and connected.

  Returns true/false based on configuration.
  """
  def enabled? do
    Application.get_env(:singularity, :shared_queue)[:enabled] == true
  end

  @doc """
  Get shared_queue database URL from config.
  """
  def database_url do
    Application.get_env(:singularity, :shared_queue)[:database_url]
  end
end
