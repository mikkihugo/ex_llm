defmodule Singularity.Workflows.KnowledgeMigration do
  @moduledoc """
  PgFlow workflow for durable knowledge artifact migration from Git to PostgreSQL.

  Replaces manual `mix knowledge.migrate` with observable, retryable pgflow execution.

  ## Overview

  Knowledge migration syncs JSON templates from `templates_data/` to the PostgreSQL
  `knowledge_artifacts` table with full audit trails, error handling, and retry capability.

  ## Workflow Steps

  1. **prepare_context** - Initialize workflow with options
  2. **validate_paths** - Verify templates_data directory exists
  3. **sync_artifacts** - Sync JSON files to database via ArtifactStore
  4. **generate_embeddings** - Generate semantic search embeddings (async)
  5. **summarize** - Log results and return summary

  ## Integration

  Uses pgflow for:
  - Durable execution (survives crashes/restarts)
  - Automatic retries on failure
  - Observable status tracking
  - Event-based notifications via Observer UI

  ## Usage

  ```elixir
  # Trigger knowledge migration workflow
  {:ok, workflow} = Singularity.Workflows.execute(
    "knowledge_migration",
    %{},
    dry_run: false
  )

  # With options (sync specific directory)
  {:ok, workflow} = Singularity.Workflows.execute(
    "knowledge_migration",
    %{
      "options" => %{
        "path" => "templates_data/quality/"
      }
    },
    dry_run: false
  )
  ```

  ## Return Value

  ```elixir
  %{
    "status" => "completed",
    "synced_count" => 42,
    "error_count" => 0,
    "embedding_jobs_started" => 42,
    "duration_ms" => 1234,
    "timestamp" => "2025-10-27T12:34:56Z"
  }
  ```
  """

  require Logger

  alias Singularity.Knowledge.ArtifactStore

  @default_templates_dir "templates_data"

  def __workflow_steps__ do
    [
      {:prepare_context, &__MODULE__.prepare_context/1},
      {:validate_paths, &__MODULE__.validate_paths/1},
      {:sync_artifacts, &__MODULE__.sync_artifacts/1},
      {:generate_embeddings, &__MODULE__.generate_embeddings/1},
      {:summarize, &__MODULE__.summarize/1}
    ]
  end

  @doc false
  def prepare_context(input) do
    options = Map.get(input, "options", %{})
    start_time = System.monotonic_time()

    prepared = %{
      path: Map.get(options, "path", @default_templates_dir),
      skip_embedding: Map.get(options, "skip_embedding", false),
      start_time: start_time,
      results: nil,
      artifact_ids: []
    }

    Logger.info("KnowledgeMigration workflow: Preparing context",
      path: prepared.path,
      skip_embedding: prepared.skip_embedding
    )

    {:ok, prepared}
  end

  @doc false
  def validate_paths(%{path: path} = state) do
    full_path = Path.expand(path)

    case File.dir?(full_path) do
      true ->
        Logger.info("KnowledgeMigration workflow: Validated path",
          path: full_path,
          exists: true
        )

        {:ok, state}

      false ->
        Logger.error("KnowledgeMigration workflow: Path does not exist",
          path: full_path
        )

        {:error, {:invalid_path, full_path}}
    end
  end

  @doc false
  def sync_artifacts(%{path: path, skip_embedding: skip_embedding} = state) do
    Logger.info("KnowledgeMigration workflow: Starting artifact sync",
      path: path,
      skip_embedding: skip_embedding
    )

    {:ok, %{success: success_count, errors: error_count, results: results}} =
      ArtifactStore.sync_from_git(path: path, skip_embedding: skip_embedding)

    # Extract artifact IDs from results for embedding generation
    artifact_ids =
      results
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, artifact} -> artifact.id end)

    Logger.info("KnowledgeMigration workflow: Sync completed",
      success: success_count,
      errors: error_count,
      artifact_ids: length(artifact_ids)
    )

    {:ok,
     state
     |> Map.put(:synced_count, success_count)
     |> Map.put(:error_count, error_count)
     |> Map.put(:artifact_ids, artifact_ids)}
  end

  @doc false
  def generate_embeddings(%{artifact_ids: artifact_ids, skip_embedding: skip_embedding} = state) do
    if skip_embedding or Enum.empty?(artifact_ids) do
      Logger.debug("KnowledgeMigration workflow: Skipping embedding generation",
        count: length(artifact_ids),
        skip_embedding: skip_embedding
      )

      {:ok, Map.put(state, :embedding_jobs_started, 0)}
    else
      Logger.info("KnowledgeMigration workflow: Starting embedding generation",
        artifact_count: length(artifact_ids)
      )

      # Embeddings are generated asynchronously by ArtifactStore.store/4
      # during sync_artifacts step (unless skip_embedding: true)
      # No need to start additional jobs - just record the count
      {:ok, Map.put(state, :embedding_jobs_started, length(artifact_ids))}
    end
  end

  @doc false
  def summarize(%{
        start_time: start_time,
        synced_count: synced_count,
        error_count: error_count,
        embedding_jobs_started: embedding_jobs_started
      }) do
    duration_ms = div(System.monotonic_time() - start_time, 1_000_000)

    summary = %{
      "status" => if(error_count == 0, do: "completed", else: "completed_with_errors"),
      "synced_count" => synced_count,
      "error_count" => error_count,
      "embedding_jobs_started" => embedding_jobs_started,
      "duration_ms" => duration_ms,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    {log_level, message} =
      if error_count == 0 do
        {:info,
         "✅ Knowledge migration completed: #{synced_count} artifacts synced, " <>
           "#{embedding_jobs_started} embeddings queued"}
      else
        {:warning,
         "⚠️  Knowledge migration completed with errors: #{synced_count} synced, " <>
           "#{error_count} failed, #{embedding_jobs_started} embeddings queued"}
      end

    Logger.log(log_level, message,
      synced: synced_count,
      errors: error_count,
      embeddings: embedding_jobs_started,
      duration_ms: duration_ms
    )

    {:ok, summary}
  end
end
