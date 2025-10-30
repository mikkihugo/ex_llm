defmodule Singularity.Ingestion.Workflows.ExecuteAutoCodeIngestionWorkflow do
  @moduledoc """
  QuantumFlow workflow for automatic code ingestion

  This workflow automatically ingests code changes into the database using QuantumFlow
  for orchestration, providing a robust, scalable, and observable code ingestion system.

  ## Workflow Steps

  1. **File Detection** - Monitor file system changes
  2. **Validation** - Validate file types and content
  3. **Parsing** - Parse code with appropriate language parsers
  4. **Storage** - Store in database with embeddings
  5. **Indexing** - Update search indexes
  6. **Notification** - Notify completion

  ## QuantumFlow Integration

  Uses QuantumFlow for:
  - Workflow orchestration and state management
  - Retry logic and error handling
  - Progress tracking and observability
  - Integration with other system workflows

  ## Configuration

  Configure via `:auto_ingestion` config key:
  ```elixir
  config :singularity, :auto_ingestion,
    enabled: true,
    watch_directories: ["lib", "packages", "nexus", "observer"],
    debounce_delay_ms: 500,
    max_concurrent_workflows: 10
  ```

  ## Usage

      # Start the workflow
      {:ok, workflow_id} = AutoCodeIngestion.start_workflow(%{
        file_path: "/path/to/file.ex",
        codebase_id: "singularity"
      })

      # Check workflow status
      {:ok, status} = AutoCodeIngestion.get_workflow_status(workflow_id)

      # Get workflow results
      {:ok, results} = AutoCodeIngestion.get_workflow_results(workflow_id)
  """

  require Logger
  alias Singularity.Workflows
  alias Singularity.Code.{UnifiedIngestionService, CodebaseDetector}

  @workflow_type "auto_code_ingestion"
  @config Application.get_env(:singularity, :auto_ingestion, %{})

  # Workflow step definitions
  @steps [
    :validate_file,
    :parse_code,
    :store_in_database,
    :update_indexes,
    :notify_completion
  ]

  @doc """
  Start a new automatic code ingestion workflow.

  ## Parameters

  - `attrs` - Workflow attributes
    - `:file_path` - Path to file to ingest (required)
    - `:codebase_id` - Codebase identifier (optional, auto-detected if not provided)
    - `:priority` - Workflow priority (optional, default: :normal)
    - `:retry_count` - Number of retries (optional, default: 3)

  ## Returns

  - `{:ok, workflow_id}` - Workflow started successfully
  - `{:error, reason}` - Failed to start workflow

  ## Examples

      # Ingest a single file
      {:ok, id} = AutoCodeIngestion.start_workflow(%{
        file_path: "/path/to/file.ex"
      })

      # Ingest with specific codebase
      {:ok, id} = AutoCodeIngestion.start_workflow(%{
        file_path: "/path/to/file.ex",
        codebase_id: "my-project"
      })
  """
  def start_workflow(attrs) do
    workflow_id = generate_workflow_id()

    # Auto-detect codebase if not provided
    codebase_id = attrs[:codebase_id] || CodebaseDetector.detect(format: :full)

    workflow_attrs = %{
      workflow_id: workflow_id,
      type: @workflow_type,
      payload: %{
        file_path: attrs[:file_path],
        codebase_id: codebase_id,
        priority: attrs[:priority] || :normal,
        retry_count: attrs[:retry_count] || 3,
        current_step: :validate_file,
        completed_steps: [],
        failed_steps: [],
        results: %{},
        started_at: DateTime.utc_now()
      },
      status: "running"
    }

    case Workflows.create_workflow(workflow_attrs) do
      {:ok, workflow} ->
        Logger.info("Started auto code ingestion workflow",
          workflow_id: workflow_id,
          file_path: attrs[:file_path]
        )

        # Start workflow execution asynchronously
        Task.start(fn -> execute_workflow(workflow_id) end)

        {:ok, workflow_id}

      {:error, reason} ->
        Logger.error("Failed to start auto code ingestion workflow",
          error: reason,
          file_path: attrs[:file_path]
        )

        {:error, reason}
    end
  end

  @doc """
  Get the current status of a workflow.

  ## Parameters

  - `workflow_id` - The workflow ID

  ## Returns

  - `{:ok, status}` - Current workflow status
  - `{:error, :not_found}` - Workflow not found
  """
  def get_workflow_status(workflow_id) do
    case Workflows.fetch_workflow(workflow_id) do
      {:ok, workflow} ->
        {:ok,
         %{
           status: workflow.status,
           current_step: workflow.payload.current_step,
           completed_steps: workflow.payload.completed_steps,
           failed_steps: workflow.payload.failed_steps,
           progress: calculate_progress(workflow.payload)
         }}

      :not_found ->
        {:error, :not_found}
    end
  end

  @doc """
  Get the results of a completed workflow.

  ## Parameters

  - `workflow_id` - The workflow ID

  ## Returns

  - `{:ok, results}` - Workflow results
  - `{:error, :not_found}` - Workflow not found
  - `{:error, :not_completed}` - Workflow not yet completed
  """
  def get_workflow_results(workflow_id) do
    case Workflows.fetch_workflow(workflow_id) do
      {:ok, workflow} ->
        case workflow.status do
          "completed" ->
            {:ok, workflow.payload.results}

          "failed" ->
            {:ok,
             %{
               status: :failed,
               error: workflow.payload.results.error,
               failed_steps: workflow.payload.failed_steps
             }}

          _ ->
            {:error, :not_completed}
        end

      :not_found ->
        {:error, :not_found}
    end
  end

  @doc """
  Start bulk ingestion workflow for multiple files.

  ## Parameters

  - `file_paths` - List of file paths to ingest
  - `opts` - Options
    - `:codebase_id` - Codebase identifier
    - `:max_concurrent` - Maximum concurrent workflows (default: 5)
    - `:batch_size` - Files per batch (default: 10)

  ## Returns

  - `{:ok, workflow_ids}` - List of started workflow IDs
  - `{:error, reason}` - Failed to start workflows
  """
  def start_bulk_ingestion(file_paths, opts \\ []) do
    max_concurrent = Keyword.get(opts, :max_concurrent, 5)
    batch_size = Keyword.get(opts, :batch_size, 10)
    codebase_id = Keyword.get(opts, :codebase_id)

    Logger.info("Starting bulk code ingestion",
      file_count: length(file_paths),
      max_concurrent: max_concurrent
    )

    # Process files in batches to avoid overwhelming the system
    file_paths
    |> Enum.chunk_every(batch_size)
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {batch, batch_index}, {:ok, acc} ->
      # Start workflows for this batch
      batch_results =
        batch
        |> Task.async_stream(
          fn file_path ->
            start_workflow(%{
              file_path: file_path,
              codebase_id: codebase_id,
              priority: :bulk
            })
          end,
          max_concurrency: max_concurrent,
          timeout: 30_000
        )
        |> Enum.to_list()

      # Check if any failed
      failed =
        Enum.filter(batch_results, fn
          {:ok, _} -> false
          {:error, _} -> true
        end)

      if length(failed) > 0 do
        Logger.warning("Some workflows failed to start in batch #{batch_index}",
          failed_count: length(failed)
        )
      end

      # Collect successful workflow IDs
      successful_ids =
        batch_results
        |> Enum.filter_map(fn {:ok, id} -> id end, fn
          {:ok, _} -> true
          _ -> false
        end)

      {:cont, {:ok, acc ++ successful_ids}}
    end)
  end

  # Private Functions

  defp execute_workflow(workflow_id) do
    case Workflows.fetch_workflow(workflow_id) do
      {:ok, workflow} ->
        execute_workflow_steps(workflow)

      :not_found ->
        Logger.error("Workflow not found during execution", workflow_id: workflow_id)
    end
  end

  defp execute_workflow_steps(workflow) do
    payload = workflow.payload
    current_step = payload.current_step

    Logger.debug("Executing workflow step",
      workflow_id: workflow.workflow_id,
      step: current_step
    )

    case execute_step(current_step, payload) do
      {:ok, updated_payload} ->
        # Move to next step or complete
        next_step = get_next_step(current_step)

        if next_step do
          # Update workflow with next step
          updated_payload = %{
            updated_payload
            | current_step: next_step,
              completed_steps: [current_step | updated_payload.completed_steps]
          }

          update_workflow_payload(workflow.workflow_id, updated_payload)

          # Continue to next step
          execute_workflow_steps(%{workflow | payload: updated_payload})
        else
          # Workflow completed
          complete_workflow(workflow.workflow_id, updated_payload)
        end

      {:error, reason} ->
        # Handle step failure
        handle_step_failure(workflow, current_step, reason)
    end
  end

  defp execute_step(:validate_file, payload) do
    file_path = payload.file_path

    Logger.debug("Validating file", file_path: file_path)

    case validate_file(file_path) do
      :ok ->
        {:ok, payload}

      {:error, reason} ->
        {:error, {:validation_failed, reason}}
    end
  end

  defp execute_step(:parse_code, payload) do
    file_path = payload.file_path
    codebase_id = payload.codebase_id

    Logger.debug("Parsing code", file_path: file_path)

    case UnifiedIngestionService.ingest_file(file_path, codebase_id: codebase_id) do
      {:ok, results} ->
        updated_payload = %{payload | results: Map.put(payload.results, :parse_results, results)}
        {:ok, updated_payload}

      {:error, reason} ->
        {:error, {:parse_failed, reason}}
    end
  end

  defp execute_step(:store_in_database, payload) do
    # This step is already completed in parse_code step
    # Just mark as completed
    {:ok, payload}
  end

  defp execute_step(:update_indexes, payload) do
    file_path = payload.file_path

    Logger.debug("Updating search indexes", file_path: file_path)

    # Update semantic search indexes
    case update_semantic_indexes(file_path) do
      :ok ->
        {:ok, payload}

      {:error, reason} ->
        {:error, {:index_update_failed, reason}}
    end
  end

  defp execute_step(:notify_completion, payload) do
    workflow_id = payload.workflow_id || "unknown"
    file_path = payload.file_path

    Logger.info("Code ingestion workflow completed",
      workflow_id: workflow_id,
      file_path: file_path
    )

    # Send notification
    send_completion_notification(workflow_id, file_path, payload.results)

    {:ok, payload}
  end

  defp validate_file(file_path) do
    cond do
      not File.exists?(file_path) ->
        {:error, :file_not_found}

      not File.regular?(file_path) ->
        {:error, :not_a_file}

      not is_source_file?(file_path) ->
        {:error, :unsupported_file_type}

      true ->
        :ok
    end
  end

  defp is_source_file?(file_path) do
    extensions =
      @config[:include_extensions] ||
        [
          ".ex",
          ".exs",
          ".rs",
          ".ts",
          ".tsx",
          ".js",
          ".jsx",
          ".py",
          ".go",
          ".nix",
          ".sh",
          ".toml",
          ".json",
          ".yaml",
          ".yml",
          ".md"
        ]

    Enum.any?(extensions, fn ext ->
      String.ends_with?(file_path, ext)
    end)
  end

  defp update_semantic_indexes(file_path) do
    # Update semantic search indexes for the file
    # This would typically involve updating vector embeddings
    # and rebuilding search indexes

    try do
      # Placeholder for semantic index update
      # In a real implementation, this would:
      # 1. Generate embeddings for the file
      # 2. Update vector database
      # 3. Rebuild search indexes

      :ok
    rescue
      error ->
        Logger.error("Failed to update semantic indexes",
          file_path: file_path,
          error: inspect(error)
        )

        {:error, :index_update_failed}
    end
  end

  defp send_completion_notification(workflow_id, file_path, results) do
    # Send notification about workflow completion
    # This could be via webhooks, email, or other notification systems

    Logger.info("Code ingestion completed",
      workflow_id: workflow_id,
      file_path: file_path,
      results: results
    )
  end

  defp get_next_step(current_step) do
    case current_step do
      :validate_file -> :parse_code
      :parse_code -> :store_in_database
      :store_in_database -> :update_indexes
      :update_indexes -> :notify_completion
      :notify_completion -> nil
    end
  end

  defp calculate_progress(payload) do
    total_steps = length(@steps)
    completed_steps = length(payload.completed_steps)

    (completed_steps / total_steps * 100) |> round()
  end

  defp complete_workflow(workflow_id, payload) do
    final_payload = %{payload | status: :completed, completed_at: DateTime.utc_now()}

    update_workflow_payload(workflow_id, final_payload)
    update_workflow_status(workflow_id, "completed")

    Logger.info("Workflow completed successfully", workflow_id: workflow_id)
  end

  defp handle_step_failure(workflow, step, reason) do
    retry_count = workflow.payload.retry_count

    if retry_count > 0 do
      # Retry the step
      Logger.warning("Step failed, retrying",
        workflow_id: workflow.workflow_id,
        step: step,
        reason: reason,
        retries_left: retry_count - 1
      )

      updated_payload = %{workflow.payload | retry_count: retry_count - 1}

      update_workflow_payload(workflow.workflow_id, updated_payload)

      # Retry after a delay
      Process.send_after(self(), {:retry_step, workflow.workflow_id}, 1000)
    else
      # Max retries exceeded, fail the workflow
      Logger.error("Workflow failed after max retries",
        workflow_id: workflow.workflow_id,
        step: step,
        reason: reason
      )

      failed_payload = %{
        workflow.payload
        | status: :failed,
          failed_steps: [step | workflow.payload.failed_steps],
          results: %{error: reason}
      }

      update_workflow_payload(workflow.workflow_id, failed_payload)
      update_workflow_status(workflow.workflow_id, "failed")
    end
  end

  defp update_workflow_payload(workflow_id, payload) do
    case Workflows.fetch_workflow(workflow_id) do
      {:ok, workflow} ->
        updated_workflow = %{workflow | payload: payload}
        Workflows.update_workflow_status(workflow_id, updated_workflow.payload)

      :not_found ->
        Logger.error("Workflow not found for payload update", workflow_id: workflow_id)
    end
  end

  defp update_workflow_status(workflow_id, status) do
    case Workflows.fetch_workflow(workflow_id) do
      {:ok, workflow} ->
        Workflows.update_workflow_status(workflow_id, status)

      :not_found ->
        Logger.error("Workflow not found for status update", workflow_id: workflow_id)
    end
  end

  defp generate_workflow_id do
    "auto_ingest_#{:erlang.unique_integer([:positive])}"
  end
end
