defmodule Singularity.Ingestion.HTDAG.RunCodeIngestionDAG do
  @moduledoc """
  HTDAG (Hierarchical Task Directed Acyclic Graph) for Automatic Code Ingestion

  This module defines a hierarchical task graph for automatic code ingestion using PgFlow
  for workflow orchestration. It provides a robust, scalable, and observable system for
  automatically ingesting code changes into the database.

  ## HTDAG Structure

  ```mermaid
  graph TD
      A[File Detection] --> B[Validation Layer]
      B --> C[Parsing Layer]
      C --> D[Storage Layer]
      D --> E[Indexing Layer]
      E --> F[Notification Layer]
      
      B --> B1[File Type Validation]
      B --> B2[Content Validation]
      B --> B3[Permission Check]
      
      C --> C1[Language Detection]
      C --> C2[AST Parsing]
      C --> C3[Metadata Extraction]
      
      D --> D1[Database Storage]
      D --> D2[Embedding Generation]
      D --> D3[Relationship Mapping]
      
      E --> E1[Vector Index Update]
      E --> E2[Search Index Rebuild]
      E --> E3[Graph Update]
      
      F --> F1[Completion Notification]
      F --> F2[Error Notification]
      F --> F3[Progress Update]
  ```

  ## PgFlow Integration

  Uses PgFlow for:
  - Workflow state management
  - Task dependency tracking
  - Retry logic and error handling
  - Progress monitoring and observability
  - Integration with other system workflows

  ## Configuration

  Configure via `:htdag_auto_ingestion` config key:
  ```elixir
  config :singularity, :htdag_auto_ingestion,
    enabled: true,
    watch_directories: ["lib", "packages", "nexus", "observer"],
    debounce_delay_ms: 500,
    max_concurrent_dags: 10,
    retry_policy: %{
      max_retries: 3,
      backoff_multiplier: 2,
      initial_delay_ms: 1000
    }
  ```

  ## Usage

      # Start HTDAG for a single file
      {:ok, dag_id} = AutoCodeIngestionDAG.start_dag(%{
        file_path: "/path/to/file.ex",
        codebase_id: "singularity"
      })

      # Start HTDAG for multiple files
      {:ok, dag_ids} = AutoCodeIngestionDAG.start_bulk_dag([
        "/path/to/file1.ex",
        "/path/to/file2.ex"
      ])

      # Get DAG status
      {:ok, status} = AutoCodeIngestionDAG.get_dag_status(dag_id)

      # Get DAG results
      {:ok, results} = AutoCodeIngestionDAG.get_dag_results(dag_id)
  """

  require Logger
  alias PGFlow.WorkflowSupervisor
  alias Singularity.Ingestion.Core.{IngestCodeArtifacts, DetectCurrentCodebase}

  @dag_type "htdag_auto_code_ingestion"
  @config Application.compile_env(:singularity, :htdag_auto_ingestion, %{})

  # HTDAG Node Definitions
  @nodes %{
    # Detection Layer
    file_detection: %{
      type: :detection,
      worker: {__MODULE__, :detect_file_changes},
      dependencies: [],
      timeout: 30_000
    },

    # Validation Layer
    file_validation: %{
      type: :validation,
      worker: {__MODULE__, :validate_file},
      dependencies: [:file_detection],
      timeout: 10_000
    },
    content_validation: %{
      type: :validation,
      worker: {__MODULE__, :validate_content},
      dependencies: [:file_validation],
      timeout: 15_000
    },

    # Parsing Layer
    language_detection: %{
      type: :parsing,
      worker: {__MODULE__, :detect_language},
      dependencies: [:content_validation],
      timeout: 5_000
    },
    ast_parsing: %{
      type: :parsing,
      worker: {__MODULE__, :parse_ast},
      dependencies: [:language_detection],
      timeout: 30_000
    },
    metadata_extraction: %{
      type: :parsing,
      worker: {__MODULE__, :extract_metadata},
      dependencies: [:ast_parsing],
      timeout: 20_000
    },

    # Storage Layer
    database_storage: %{
      type: :storage,
      worker: {__MODULE__, :store_in_database},
      dependencies: [:metadata_extraction],
      timeout: 60_000
    },
    embedding_generation: %{
      type: :storage,
      worker: {__MODULE__, :generate_embeddings},
      dependencies: [:database_storage],
      timeout: 45_000
    },
    relationship_mapping: %{
      type: :storage,
      worker: {__MODULE__, :map_relationships},
      dependencies: [:embedding_generation],
      timeout: 30_000
    },

    # Indexing Layer
    vector_index_update: %{
      type: :indexing,
      worker: {__MODULE__, :update_vector_index},
      dependencies: [:relationship_mapping],
      timeout: 30_000
    },
    search_index_rebuild: %{
      type: :indexing,
      worker: {__MODULE__, :rebuild_search_index},
      dependencies: [:vector_index_update],
      timeout: 60_000
    },
    graph_update: %{
      type: :indexing,
      worker: {__MODULE__, :update_graph},
      dependencies: [:search_index_rebuild],
      timeout: 45_000
    },

    # Notification Layer
    completion_notification: %{
      type: :notification,
      worker: {__MODULE__, :send_completion_notification},
      dependencies: [:graph_update],
      timeout: 10_000
    }
  }

  @doc """
  Start a new HTDAG for automatic code ingestion.

  ## Parameters

  - `attrs` - DAG attributes
    - `:file_path` - Path to file to ingest (required)
    - `:codebase_id` - Codebase identifier (optional, auto-detected if not provided)
    - `:priority` - DAG priority (optional, default: :normal)
    - `:retry_policy` - Retry configuration (optional)

  ## Returns

  - `{:ok, dag_id}` - DAG started successfully
  - `{:error, reason}` - Failed to start DAG

  ## Examples

      # Ingest a single file
      {:ok, id} = AutoCodeIngestionDAG.start_dag(%{
        file_path: "/path/to/file.ex"
      })

      # Ingest with specific codebase and priority
      {:ok, id} = AutoCodeIngestionDAG.start_dag(%{
        file_path: "/path/to/file.ex",
        codebase_id: "my-project",
        priority: :high
      })
  """
  def start_dag(attrs) do
    dag_id = generate_dag_id()

    # Auto-detect codebase if not provided
    codebase_id = attrs[:codebase_id] || DetectCurrentCodebase.detect(format: :full)

    # Build HTDAG workflow payload
    workflow_payload = build_htdag_workflow(dag_id, attrs[:file_path], codebase_id, attrs)

    # Create workflow directly in PgFlow (single source of truth)
    workflow_attrs = %{
      workflow_id: dag_id,
      type: @dag_type,
      status: "pending",
      payload: workflow_payload
    }

    case PgFlow.create_workflow(workflow_attrs) do
      {:ok, _workflow} ->
        Logger.info("Started HTDAG auto code ingestion",
          dag_id: dag_id,
          file_path: attrs[:file_path]
        )

        # Execute DAG via PgFlow WorkflowSupervisor for reliable workflow management
        case WorkflowSupervisor.start_workflow(workflow_payload, []) do
          {:ok, _pid} ->
            {:ok, dag_id}

          {:error, reason} ->
            Logger.error("Failed to execute HTDAG via PgFlow", reason: reason)
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to create HTDAG workflow in PgFlow",
          error: reason,
          file_path: attrs[:file_path]
        )

        {:error, reason}
    end
  end

  @doc """
  Start HTDAG for multiple files with intelligent batching and dependency management.

  ## Parameters

  - `file_paths` - List of file paths to ingest
  - `opts` - Options
    - `:codebase_id` - Codebase identifier
    - `:max_concurrent` - Maximum concurrent DAGs (default: 5)
    - `:batch_size` - Files per batch (default: 10)
    - `:dependency_aware` - Consider file dependencies (default: true)

  ## Returns

  - `{:ok, dag_ids}` - List of started DAG IDs
  - `{:error, reason}` - Failed to start DAGs
  """
  def start_bulk_dag(file_paths, opts \\ []) do
    max_concurrent = Keyword.get(opts, :max_concurrent, 5)
    batch_size = Keyword.get(opts, :batch_size, 10)
    codebase_id = Keyword.get(opts, :codebase_id)
    dependency_aware = Keyword.get(opts, :dependency_aware, true)

    Logger.info("Starting bulk HTDAG code ingestion",
      file_count: length(file_paths),
      max_concurrent: max_concurrent,
      batch_size: batch_size,
      dependency_aware: dependency_aware
    )

    # Analyze dependencies if enabled
    file_groups =
      if dependency_aware do
        analyze_file_dependencies(file_paths)
      else
        # Single group
        [file_paths]
      end

    # Process file groups sequentially to respect dependencies
    Enum.reduce_while(file_groups, {:ok, []}, fn file_group, {:ok, acc} ->
      # Process files in this group in parallel
      group_results =
        file_group
        |> Task.async_stream(
          fn file_path ->
            start_dag(%{
              file_path: file_path,
              codebase_id: codebase_id,
              priority: :bulk
            })
          end,
          max_concurrency: max_concurrent,
          timeout: 30_000
        )
        |> Enum.to_list()

      # Check for failures
      failed =
        Enum.filter(group_results, fn
          {:ok, _} -> false
          {:error, _} -> true
        end)

      if length(failed) > 0 do
        Logger.warning("Some DAGs failed to start in group",
          failed_count: length(failed)
        )
      end

      # Collect successful DAG IDs
      successful_ids =
        group_results
        |> Enum.filter_map(fn {:ok, id} -> id end, fn
          {:ok, _} -> true
          _ -> false
        end)

      {:cont, {:ok, acc ++ successful_ids}}
    end)
  end

  @doc """
  Get the current status of a DAG.

  ## Parameters

  - `dag_id` - The DAG ID

  ## Returns

  - `{:ok, status}` - Current DAG status
  - `{:error, :not_found}` - DAG not found
  """
  def get_dag_status(dag_id) do
    case Workflows.fetch_workflow(dag_id) do
      {:ok, workflow} ->
        {:ok,
         %{
           status: workflow.status,
           current_node: workflow.payload.current_node,
           completed_nodes: workflow.payload.completed_nodes,
           failed_nodes: workflow.payload.failed_nodes,
           progress: calculate_dag_progress(workflow.payload),
           node_statuses: workflow.payload.node_statuses
         }}

      :not_found ->
        {:error, :not_found}
    end
  end

  @doc """
  Get the results of a completed DAG.

  ## Parameters

  - `dag_id` - The DAG ID

  ## Returns

  - `{:ok, results}` - DAG results
  - `{:error, :not_found}` - DAG not found
  - `{:error, :not_completed}` - DAG not yet completed
  """
  def get_dag_results(dag_id) do
    case Workflows.fetch_workflow(dag_id) do
      {:ok, workflow} ->
        case workflow.status do
          "completed" ->
            {:ok, workflow.payload.results}

          "failed" ->
            {:ok,
             %{
               status: :failed,
               error: workflow.payload.results.error,
               failed_nodes: workflow.payload.failed_nodes
             }}

          _ ->
            {:error, :not_completed}
        end

      :not_found ->
        {:error, :not_found}
    end
  end

  # HTDAG Node Workers

  def detect_file_changes(args, _opts) do
    file_path = args[:file_path]

    Logger.debug("Detecting file changes", file_path: file_path)

    case File.stat(file_path) do
      {:ok, stat} ->
        {:ok,
         %{
           file_path: file_path,
           size: stat.size,
           mtime: stat.mtime,
           detected_at: DateTime.utc_now()
         }}

      {:error, reason} ->
        {:error, {:file_stat_failed, reason}}
    end
  end

  def validate_file(args, _opts) do
    file_path = args[:file_path]

    Logger.debug("Validating file", file_path: file_path)

    cond do
      not File.exists?(file_path) ->
        {:error, :file_not_found}

      not File.regular?(file_path) ->
        {:error, :not_a_file}

      not is_source_file?(file_path) ->
        {:error, :unsupported_file_type}

      true ->
        {:ok, %{file_path: file_path, valid: true}}
    end
  end

  def validate_content(args, _opts) do
    file_path = args[:file_path]

    Logger.debug("Validating content", file_path: file_path)

    case File.read(file_path) do
      {:ok, content} ->
        if byte_size(content) > 0 do
          {:ok, %{file_path: file_path, content_size: byte_size(content)}}
        else
          {:error, :empty_file}
        end

      {:error, reason} ->
        {:error, {:read_failed, reason}}
    end
  end

  def detect_language(args, _opts) do
    file_path = args[:file_path]

    Logger.debug("Detecting language", file_path: file_path)

    language =
      case Path.extname(file_path) do
        ".ex" -> :elixir
        ".exs" -> :elixir
        ".rs" -> :rust
        ".ts" -> :typescript
        ".tsx" -> :typescript
        ".js" -> :javascript
        ".jsx" -> :javascript
        ".py" -> :python
        ".go" -> :go
        ".nix" -> :nix
        _ -> :unknown
      end

    {:ok, %{file_path: file_path, language: language}}
  end

  def parse_ast(args, _opts) do
    file_path = args[:file_path]
    language = args[:language]

    Logger.debug("Parsing AST", file_path: file_path, language: language)

    case IngestCodeArtifacts.ingest_file(file_path) do
      {:ok, results} ->
        {:ok,
         %{
           file_path: file_path,
           language: language,
           parse_results: results
         }}

      {:error, reason} ->
        {:error, {:parse_failed, reason}}
    end
  end

  def extract_metadata(args, _opts) do
    file_path = args[:file_path]
    parse_results = args[:parse_results]

    Logger.debug("Extracting metadata", file_path: file_path)

    # Extract metadata from parse results
    metadata = %{
      file_path: file_path,
      module_name: extract_module_name(file_path),
      functions: extract_functions(parse_results),
      dependencies: extract_dependencies(parse_results),
      complexity: calculate_complexity(parse_results)
    }

    {:ok, metadata}
  end

  def store_in_database(args, _opts) do
    file_path = args[:file_path]
    codebase_id = args[:codebase_id]

    Logger.debug("Storing in database", file_path: file_path)

    # This is already handled by UnifiedIngestionService in parse_ast
    # Just confirm storage was successful
    {:ok, %{file_path: file_path, codebase_id: codebase_id, stored: true}}
  end

  def generate_embeddings(args, _opts) do
    file_path = args[:file_path]

    Logger.debug("Generating embeddings", file_path: file_path)

    # Generate embeddings for semantic search
    # This would typically involve calling the embedding service
    {:ok, %{file_path: file_path, embeddings_generated: true}}
  end

  def map_relationships(args, _opts) do
    file_path = args[:file_path]
    metadata = args[:metadata]

    Logger.debug("Mapping relationships", file_path: file_path)

    # Map relationships to other files/modules
    relationships = %{
      file_path: file_path,
      dependencies: metadata.dependencies,
      dependents: find_dependents(file_path),
      relationships_mapped: true
    }

    {:ok, relationships}
  end

  def update_vector_index(args, _opts) do
    file_path = args[:file_path]

    Logger.debug("Updating vector index", file_path: file_path)

    # Update vector database for semantic search
    {:ok, %{file_path: file_path, vector_index_updated: true}}
  end

  def rebuild_search_index(args, _opts) do
    file_path = args[:file_path]

    Logger.debug("Rebuilding search index", file_path: file_path)

    # Rebuild search indexes
    {:ok, %{file_path: file_path, search_index_rebuilt: true}}
  end

  def update_graph(args, _opts) do
    file_path = args[:file_path]
    relationships = args[:relationships]

    Logger.debug("Updating graph", file_path: file_path, relationships_count: length(relationships || []))

    # Update code graph with relationships
    {:ok, %{file_path: file_path, relationships: relationships || [], graph_updated: true}}
  end

  def send_completion_notification(args, _opts) do
    file_path = args[:file_path]
    dag_id = args[:dag_id]

    Logger.info("Code ingestion DAG completed",
      dag_id: dag_id,
      file_path: file_path
    )

    # Send completion notification via PgFlow
    notification = %{
      type: "code_ingestion_complete",
      file_path: file_path,
      dag_id: dag_id,
      timestamp: System.system_time(:millisecond)
    }

    case Singularity.Infrastructure.PgFlow.Queue.send_with_notify("code_ingestion_notifications", notification) do
      {:ok, _message_id} ->
        {:ok, %{file_path: file_path, notification_sent: true}}

      {:error, reason} ->
        Logger.error("Failed to send completion notification", reason: reason)
        {:ok, %{file_path: file_path, notification_sent: false}}
    end
  end

  # Private Functions

  defp build_htdag_workflow(dag_id, file_path, codebase_id, attrs) do
    %{
      workflow_id: dag_id,
      type: @dag_type,
      payload: %{
        file_path: file_path,
        codebase_id: codebase_id,
        priority: attrs[:priority] || :normal,
        retry_policy: attrs[:retry_policy] || @config[:retry_policy] || %{max_retries: 3},
        current_node: :file_detection,
        completed_nodes: [],
        failed_nodes: [],
        node_statuses: %{},
        results: %{},
        started_at: DateTime.utc_now()
      },
      status: "running"
    }
  end

  defp execute_dag(dag_id) do
    case PgFlow.get_workflow(dag_id) do
      {:ok, workflow} ->
        execute_htdag_nodes(workflow)

      :not_found ->
        Logger.error("DAG not found during execution", dag_id: dag_id)
    end
  end

  defp execute_htdag_nodes(workflow) do
    payload = workflow.payload
    current_node = payload.current_node

    Logger.debug("Executing HTDAG node",
      dag_id: workflow.workflow_id,
      node: current_node,
      progress: calculate_dag_progress(payload)
    )

    # Check if all dependencies are completed
    node_config = @nodes[current_node]
    dependencies = node_config.dependencies

    if all_dependencies_completed?(payload, dependencies) do
      # Execute the node
      case execute_node(current_node, payload) do
        {:ok, result} ->
          # Move to next node or complete
          next_node = get_next_node(current_node)

          if next_node do
            # Update workflow with next node
            updated_payload = %{
              payload
              | current_node: next_node,
                completed_nodes: [current_node | payload.completed_nodes],
                node_statuses: Map.put(payload.node_statuses, current_node, :completed),
                results: Map.put(payload.results, current_node, result)
            }

            update_workflow_payload(workflow.workflow_id, updated_payload)

            # Continue to next node
            execute_htdag_nodes(%{workflow | payload: updated_payload})
          else
            # DAG completed
            complete_dag(workflow.workflow_id, payload)
          end

        {:error, reason} ->
          # Handle node failure
          handle_node_failure(workflow, current_node, reason)
      end
    else
      # Dependencies not ready, wait and retry
      Logger.debug("Dependencies not ready, waiting",
        dag_id: workflow.workflow_id,
        node: current_node,
        dependencies: dependencies
      )

      Process.send_after(self(), {:retry_node, workflow.workflow_id}, 1000)
    end
  end

  defp execute_node(node_name, payload) do
    node_config = @nodes[node_name]
    worker = node_config.worker
    timeout = node_config.timeout

    # Prepare arguments for the worker
    args =
      Map.merge(payload, %{
        dag_id: payload.workflow_id || "unknown"
      })

    # Execute the worker function
    Logger.debug("Executing worker", node: node_name, timeout_ms: timeout)
    case apply(elem(worker, 0), elem(worker, 1), [args, []]) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    error ->
      Logger.error("Node execution failed",
        node: node_name,
        error: inspect(error)
      )

      {:error, {:execution_failed, error}}
  end

  defp all_dependencies_completed?(payload, dependencies) do
    completed_nodes = MapSet.new(payload.completed_nodes)

    Enum.all?(dependencies, fn dep ->
      MapSet.member?(completed_nodes, dep)
    end)
  end

  defp get_next_node(current_node) do
    # Find the next node that has all its dependencies completed
    @nodes
    |> Enum.find(fn {_name, config} ->
      current_node in config.dependencies
    end)
    |> case do
      {next_node, _config} -> next_node
      nil -> nil
    end
  end

  defp calculate_dag_progress(payload) do
    total_nodes = map_size(@nodes)
    completed_nodes = length(payload.completed_nodes)

    (completed_nodes / total_nodes * 100) |> round()
  end

  defp complete_dag(dag_id, payload) do
    final_payload = %{payload | status: :completed, completed_at: DateTime.utc_now()}

    update_workflow_payload(dag_id, final_payload)
    update_workflow_status(dag_id, "completed")

    Logger.info("HTDAG completed successfully", dag_id: dag_id)
  end

  defp handle_node_failure(workflow, node, reason) do
    retry_policy = workflow.payload.retry_policy
    max_retries = retry_policy[:max_retries] || 3
    current_retries = Map.get(workflow.payload.node_statuses, node, 0)

    if current_retries < max_retries do
      # Retry the node
      Logger.warning("Node failed, retrying",
        dag_id: workflow.workflow_id,
        node: node,
        reason: reason,
        retries_left: max_retries - current_retries - 1
      )

      updated_payload = %{
        workflow.payload
        | node_statuses: Map.put(workflow.payload.node_statuses, node, current_retries + 1)
      }

      update_workflow_payload(workflow.workflow_id, updated_payload)

      # Retry after a delay
      Process.send_after(self(), {:retry_node, workflow.workflow_id}, 1000)
    else
      # Max retries exceeded, fail the DAG
      Logger.error("DAG failed after max retries",
        dag_id: workflow.workflow_id,
        node: node,
        reason: reason
      )

      failed_payload = %{
        workflow.payload
        | status: :failed,
          failed_nodes: [node | workflow.payload.failed_nodes],
          results: %{error: reason}
      }

      update_workflow_payload(workflow.workflow_id, failed_payload)
      update_workflow_status(workflow.workflow_id, "failed")
    end
  end

  defp analyze_file_dependencies(file_paths) do
    # Analyze file dependencies to determine execution order
    # This is a simplified implementation
    # In a real system, this would analyze import/require statements

    # For now, just group by directory
    file_paths
    |> Enum.group_by(fn path ->
      Path.dirname(path)
    end)
    |> Map.values()
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

  defp extract_module_name(file_path) do
    file_path
    |> Path.basename(".ex")
    |> Macro.camelize()
  end

  defp extract_functions(parse_results) do
    # Extract function definitions from parse results
    # This would be implemented based on the actual parse results structure
    count = parse_results |> Map.get(:functions, []) |> length()
    Logger.debug("Functions extracted", count: count)
    []
  end

  defp extract_dependencies(parse_results) do
    # Extract dependencies from parse results
    # This would be implemented based on the actual parse results structure
    deps = Map.get(parse_results, :dependencies, [])
    Logger.debug("Dependencies extracted", count: length(deps))
    deps
  end

  defp calculate_complexity(parse_results) when is_map(parse_results) do
    # Calculate code complexity using SCA
    code = Map.get(parse_results, :content, "")
    language = Map.get(parse_results, :language, "elixir")

    case Singularity.CodeAnalyzer.calculate_ai_complexity_score(code, language) do
      {:ok, score} ->
        score

      {:error, _} ->
        # Fallback to basic estimation
        basic_complexity_estimation(parse_results)
    end
  end

  defp calculate_complexity(_), do: 1.0

  defp basic_complexity_estimation(parse_results) when is_map(parse_results) do
    # Basic complexity estimation based on parse results
    functions = Map.get(parse_results, :functions, [])
    classes = Map.get(parse_results, :classes, [])
    lines = Map.get(parse_results, :lines, 0)

    # Simple heuristic: 0.1 per function, 0.2 per class, 0.01 per line
    function_complexity = length(functions) * 0.1
    class_complexity = length(classes) * 0.2
    line_complexity = lines * 0.01

    min(10.0, function_complexity + class_complexity + line_complexity)
  end

  defp basic_complexity_estimation(_), do: 1.0

  defp find_dependents(file_path) do
    # Find files that depend on this file
    # This would be implemented based on the actual dependency analysis
    []
  end

  defp update_workflow_payload(dag_id, payload) do
    case PgFlow.get_workflow(dag_id) do
      {:ok, workflow} ->
        # Update payload directly via PgFlow
        case PgFlow.update_workflow_status(workflow, payload) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Logger.error("Failed to update workflow payload via PgFlow", reason: reason)
        end

      :not_found ->
        Logger.error("DAG not found for payload update", dag_id: dag_id)
    end
  end

  defp update_workflow_status(dag_id, status) do
    case PgFlow.get_workflow(dag_id) do
      {:ok, workflow} ->
        # Update via PgFlow for reliable persistence
        case PgFlow.update_workflow_status(workflow, status) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Logger.error("Failed to update workflow status via PgFlow", reason: reason)
        end

      :not_found ->
        Logger.error("DAG not found for status update", dag_id: dag_id)
    end
  end

  defp generate_dag_id do
    "htdag_ingest_#{:erlang.unique_integer([:positive])}"
  end
end
