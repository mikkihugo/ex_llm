# TaskGraph Code Ingestion Orchestration

Complete example of orchestrating code ingestion workflows with TaskGraph's role-based security.

---

## Existing Infrastructure

Singularity has powerful code ingestion infrastructure:

**1. ParserEngine (Rust NIF)** - `lib/singularity/engines/parser_engine.ex`
- High-performance parsing (5000 files/minute)
- 30+ languages supported
- AST extraction, metrics, dependencies
- Direct PostgreSQL streaming

**2. Mix.Tasks.Code.Ingest** - `lib/mix/tasks/code.ingest.ex`
- 5-step ingestion pipeline:
  1. Create schema
  2. Register codebase
  3. Parse files (Rust NIF)
  4. Generate embeddings (Google AI)
  5. Finalize

**3. CodeStore** - `lib/singularity/storage/code/storage/code_store.ex`
- Multi-codebase management
- Analysis comparison
- Version history

---

## TaskGraph Orchestration Example

Use TaskGraph to orchestrate complex code ingestion with dependencies, role-based security, and error handling.

### Step 1: Define Ingestion Tasks with Dependencies

```elixir
alias Singularity.Execution.TaskGraph.Orchestrator

# Full code ingestion workflow with role-based execution
ingestion_tasks = [
  # Step 1: Researcher fetches docs for new codebase (HTTP allowed)
  %{
    id: "fetch-docs",
    title: "Fetch documentation for target codebase",
    role: :researcher,
    depends_on: [],
    context: %{
      "codebase_url" => "https://github.com/user/repo",
      "docs_urls" => [
        "https://docs.example.com/api",
        "https://github.com/user/repo/wiki"
      ],
      "output_dir" => "/tmp/ingestion/docs"
    }
  },

  # Step 2: Coder clones repo and prepares (git allowed)
  %{
    id: "clone-repo",
    title: "Clone repository for ingestion",
    role: :coder,
    depends_on: ["fetch-docs"],  # Wait for docs
    context: %{
      "repo_url" => "https://github.com/user/repo",
      "target_dir" => "/tmp/ingestion/code",
      "branch" => "main"
    }
  },

  # Step 3: Coder parses codebase (file system read)
  %{
    id: "parse-codebase",
    title: "Parse all source files",
    role: :coder,
    depends_on: ["clone-repo"],
    context: %{
      "codebase_path" => "/tmp/ingestion/code",
      "codebase_id" => "user-repo",
      "languages" => ["elixir", "rust", "typescript"],
      "skip_embeddings" => false
    }
  },

  # Step 4: Researcher generates embeddings (HTTP to Google AI)
  %{
    id: "generate-embeddings",
    title: "Generate embeddings for semantic search",
    role: :researcher,
    depends_on: ["parse-codebase"],
    context: %{
      "codebase_id" => "user-repo",
      "model" => "text-embedding-004",
      "batch_size" => 100
    }
  },

  # Step 5: Critic reviews code quality (read-only)
  %{
    id: "review-quality",
    title: "Analyze code quality and patterns",
    role: :critic,
    depends_on: ["parse-codebase"],  # Parallel with embeddings
    context: %{
      "codebase_id" => "user-repo",
      "quality_checks" => ["complexity", "security", "maintainability"],
      "generate_report" => true
    }
  },

  # Step 6: Admin finalizes and indexes (database writes)
  %{
    id: "finalize-ingestion",
    title: "Finalize ingestion and update status",
    role: :admin,
    depends_on: ["generate-embeddings", "review-quality"],  # Wait for both
    context: %{
      "codebase_id" => "user-repo",
      "status" => "ready",
      "quality_report_path" => "/tmp/ingestion/quality-report.json"
    }
  }
]

# Enqueue all tasks
Enum.each(ingestion_tasks, &Orchestrator.enqueue/1)

# Monitor progress
Orchestrator.get_task_graph()
# => %{
#   "fetch-docs" => :completed,
#   "clone-repo" => :completed,
#   "parse-codebase" => :in_progress,
#   "generate-embeddings" => :pending,
#   "review-quality" => :pending,
#   "finalize-ingestion" => :pending
# }
```

---

## Task Implementations

### Task 1: Fetch Documentation (Researcher)

```elixir
defmodule Singularity.Execution.Tasks.FetchDocs do
  alias Singularity.Execution.TaskGraph.Toolkit

  def execute(context) do
    with :ok <- validate_context(context),
         {:ok, _} <- ensure_output_dir(context["output_dir"]),
         {:ok, docs} <- fetch_all_docs(context["docs_urls"]) do
      {:ok, %{docs_fetched: length(docs), output_dir: context["output_dir"]}}
    end
  end

  defp fetch_all_docs(urls) do
    results =
      urls
      |> Task.async_stream(&fetch_doc/1, max_concurrency: 4)
      |> Enum.map(fn {:ok, result} -> result end)

    {:ok, results}
  end

  defp fetch_doc(url) do
    # Toolkit enforces :researcher can use HTTP
    Toolkit.run(:http, %{
      url: url,
      method: :get,
      headers: %{"User-Agent" => "Singularity Ingestion"}
    }, policy: :researcher)
  end

  defp ensure_output_dir(dir) do
    # Toolkit enforces :researcher can write to /tmp
    Toolkit.run(:fs, %{
      mkdir: dir,
      recursive: true
    }, policy: :researcher)
  end
end
```

### Task 2: Clone Repository (Coder)

```elixir
defmodule Singularity.Execution.Tasks.CloneRepo do
  alias Singularity.Execution.TaskGraph.Toolkit

  def execute(context) do
    with :ok <- validate_context(context),
         {:ok, _} <- clone_repository(context) do
      {:ok, %{
        cloned_to: context["target_dir"],
        branch: context["branch"]
      }}
    end
  end

  defp clone_repository(context) do
    # Toolkit enforces :coder can use git
    Toolkit.run(:git, %{
      cmd: ["clone", context["repo_url"], context["target_dir"], "--branch", context["branch"]]
    }, policy: :coder)
  end
end
```

### Task 3: Parse Codebase (Coder)

```elixir
defmodule Singularity.Execution.Tasks.ParseCodebase do
  alias Singularity.ParserEngine
  alias Singularity.CodeSearch

  def execute(context) do
    with :ok <- validate_context(context),
         {:ok, conn} <- get_db_connection(),
         {:ok, result} <- ingest_codebase(conn, context) do
      {:ok, %{
        files_parsed: result.files_parsed,
        languages: result.languages,
        codebase_id: context["codebase_id"]
      }}
    end
  end

  defp ingest_codebase(conn, context) do
    codebase_path = context["codebase_path"]
    codebase_id = context["codebase_id"]

    # Register codebase
    CodeSearch.register_codebase(
      conn,
      codebase_id,
      codebase_path,
      Path.basename(codebase_path),
      description: "Ingested via TaskGraph",
      metadata: %{ingested_at: DateTime.utc_now()}
    )

    # Parse with Rust NIF (high-performance)
    case ParserEngine.parse_and_store_tree(
      codebase_path,
      codebase_id: codebase_id,
      max_concurrency: 8
    ) do
      {:ok, results} ->
        success_count = Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)

        {:ok, %{
          files_parsed: success_count,
          languages: context["languages"]
        }}

      error -> error
    end
  end
end
```

### Task 4: Generate Embeddings (Researcher)

```elixir
defmodule Singularity.Execution.Tasks.GenerateEmbeddings do
  alias Singularity.EmbeddingGenerator
  alias Singularity.Execution.TaskGraph.Toolkit

  def execute(context) do
    with :ok <- validate_context(context),
         {:ok, conn} <- get_db_connection(),
         {:ok, result} <- generate_all_embeddings(conn, context) do
      {:ok, %{
        embeddings_generated: result.count,
        model: context["model"]
      }}
    end
  end

  defp generate_all_embeddings(conn, context) do
    codebase_id = context["codebase_id"]
    batch_size = context["batch_size"] || 100

    # Query files without embeddings
    files_needing_embeddings = query_files_without_embeddings(conn, codebase_id)

    # Process in batches (respects rate limits)
    files_needing_embeddings
    |> Enum.chunk_every(batch_size)
    |> Enum.each(fn batch ->
      batch
      |> Task.async_stream(&generate_embedding(conn, codebase_id, &1), max_concurrency: 4)
      |> Enum.to_list()

      Process.sleep(1000)  # Rate limit
    end)

    {:ok, %{count: length(files_needing_embeddings)}}
  end

  defp generate_embedding(conn, codebase_id, file) do
    # Read file content
    case File.read(file.path) do
      {:ok, content} ->
        # Generate embedding via Google AI (Toolkit enforces :researcher can use HTTP)
        case EmbeddingGenerator.embed(content) do
          {:ok, embedding} ->
            # Store in database
            Postgrex.query!(
              conn,
              "UPDATE codebase_metadata SET vector_embedding = $3 WHERE id = $1 AND codebase_id = $2",
              [file.id, codebase_id, embedding]
            )
            {:ok, :embedded}

          error -> error
        end

      error -> error
    end
  end
end
```

### Task 5: Review Quality (Critic)

```elixir
defmodule Singularity.Execution.Tasks.ReviewQuality do
  alias Singularity.QualityEngine
  alias Singularity.Execution.TaskGraph.Toolkit

  def execute(context) do
    with :ok <- validate_context(context),
         {:ok, analysis} <- analyze_quality(context) do
      # Toolkit enforces :critic can only read (not write)
      if context["generate_report"] do
        write_report(analysis, context["codebase_id"])
      end

      {:ok, %{
        quality_score: analysis.overall_score,
        issues_found: analysis.issues_count,
        report_path: "/tmp/ingestion/quality-report.json"
      }}
    end
  end

  defp analyze_quality(context) do
    codebase_id = context["codebase_id"]

    # Run quality checks (read-only, safe for :critic)
    with {:ok, complexity} <- QualityEngine.analyze_complexity(codebase_id),
         {:ok, security} <- QualityEngine.analyze_security(codebase_id),
         {:ok, maintainability} <- QualityEngine.analyze_maintainability(codebase_id) do
      {:ok, %{
        overall_score: calculate_score(complexity, security, maintainability),
        issues_count: count_issues(complexity, security, maintainability),
        complexity: complexity,
        security: security,
        maintainability: maintainability
      }}
    end
  end

  defp write_report(analysis, codebase_id) do
    report = Jason.encode!(analysis, pretty: true)

    # Toolkit enforces :critic can write to /tmp (but not /code)
    Toolkit.run(:fs, %{
      write: "/tmp/ingestion/quality-report-#{codebase_id}.json",
      content: report
    }, policy: :critic)
  end
end
```

### Task 6: Finalize Ingestion (Admin)

```elixir
defmodule Singularity.Execution.Tasks.FinalizeIngestion do
  alias Singularity.CodeSearch

  def execute(context) do
    with :ok <- validate_context(context),
         {:ok, conn} <- get_db_connection(),
         :ok <- update_codebase_status(conn, context),
         :ok <- create_indexes(conn, context),
         :ok <- notify_completion(context) do
      {:ok, %{
        codebase_id: context["codebase_id"],
        status: context["status"],
        finalized_at: DateTime.utc_now()
      }}
    end
  end

  defp update_codebase_status(conn, context) do
    CodeSearch.update_codebase_status(
      conn,
      context["codebase_id"],
      context["status"]
    )
  end

  defp create_indexes(conn, context) do
    # Create pgvector indexes for semantic search
    Postgrex.query!(
      conn,
      """
      CREATE INDEX IF NOT EXISTS codebase_metadata_vector_idx
      ON codebase_metadata
      USING ivfflat (vector_embedding vector_cosine_ops)
      WITH (lists = 100)
      WHERE codebase_id = $1;
      """,
      [context["codebase_id"]]
    )

    :ok
  end

  defp notify_completion(context) do
    # Notify via NATS
    NatsClient.publish(
      "code.ingestion.completed",
      Jason.encode!(%{
        codebase_id: context["codebase_id"],
        completed_at: DateTime.utc_now()
      })
    )

    :ok
  end
end
```

---

## Dependency Graph Visualization

```
fetch-docs (researcher)
     ↓
clone-repo (coder)
     ↓
parse-codebase (coder)
     ↓ ↘
     ↓   review-quality (critic) ← Read-only
     ↓                  ↓
generate-embeddings    ↓
   (researcher)        ↓
     ↓                ↓
     └────────────────┘
            ↓
    finalize-ingestion (admin)
```

**Automatic orchestration:**
- Tasks execute only when dependencies complete
- Parallel execution where possible (embeddings + quality review)
- Role-based security enforced automatically
- Failure handling per-task

---

## Error Handling and Retries

TaskGraph automatically handles errors and retries:

```elixir
# Enqueue with custom retry logic
Orchestrator.enqueue(%{
  id: "parse-codebase-large",
  title: "Parse large codebase",
  role: :coder,
  depends_on: ["clone-repo"],
  context: %{...},
  max_retries: 5,           # Retry up to 5 times
  timeout: 600_000,         # 10 minute timeout
  priority: 8               # High priority
})

# Monitor for failures
case Orchestrator.get_status("parse-codebase-large") do
  {:ok, :failed} ->
    # Automatic retry will be attempted
    Logger.info("Task failed, will retry automatically")

  {:ok, :in_progress} ->
    # Still running
    :ok

  {:ok, :completed} ->
    # Success!
    {:ok, result} = Orchestrator.get_result("parse-codebase-large")
end
```

---

## Testing Code Ingestion Workflow

```elixir
defmodule Singularity.CodeIngestionTest do
  use ExUnit.Case, async: false
  alias Singularity.Execution.TaskGraph.Orchestrator

  test "ingests codebase with all steps" do
    # Setup test repo
    test_repo = "/tmp/test-ingestion"
    File.mkdir_p!(test_repo)
    File.write!(Path.join(test_repo, "test.ex"), "defmodule Test, do: :ok")

    # Enqueue ingestion tasks
    ingestion_tasks = [
      %{id: "fetch-docs", ...},
      %{id: "clone-repo", ...},
      %{id: "parse-codebase", ...},
      %{id: "generate-embeddings", ...},
      %{id: "review-quality", ...},
      %{id: "finalize-ingestion", ...}
    ]

    Enum.each(ingestion_tasks, &Orchestrator.enqueue/1)

    # Wait for completion (with timeout)
    wait_for_task("finalize-ingestion", timeout: 60_000)

    # Verify results
    assert {:ok, :completed} = Orchestrator.get_status("finalize-ingestion")
    {:ok, result} = Orchestrator.get_result("finalize-ingestion")
    assert result.status == "ready"
    assert result.codebase_id == "test-repo"

    # Cleanup
    File.rm_rf!(test_repo)
  end

  defp wait_for_task(task_id, opts) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    start_time = System.monotonic_time(:millisecond)

    Stream.repeatedly(fn ->
      case Orchestrator.get_status(task_id) do
        {:ok, :completed} -> :completed
        {:ok, :failed} -> :failed
        _ ->
          Process.sleep(100)
          :waiting
      end
    end)
    |> Enum.reduce_while(nil, fn status, _acc ->
      current_time = System.monotonic_time(:millisecond)

      cond do
        status in [:completed, :failed] ->
          {:halt, status}

        current_time - start_time > timeout ->
          {:halt, :timeout}

        true ->
          {:cont, nil}
      end
    end)
  end
end
```

---

## Benefits of TaskGraph Orchestration

**vs. Manual mix code.ingest:**

| Feature | Manual Task | TaskGraph |
|---------|-------------|-----------|
| **Dependencies** | Manual sequencing | Automatic DAG resolution |
| **Parallelism** | None | Automatic (embeddings + quality) |
| **Error Handling** | Script exits | Per-task retries |
| **Security** | All-or-nothing | Role-based per step |
| **Observability** | Logs only | Task graph + telemetry |
| **Resume** | Start from scratch | Resume from failure |

**Security improvements:**

- **Researcher** can fetch docs (HTTP allowed) but can't write code
- **Coder** can parse and git clone but can't make HTTP requests
- **Critic** can only read (can't modify codebase)
- **Admin** finalizes but doesn't have access to earlier steps

**Observability:**

```elixir
# See entire workflow status at a glance
Orchestrator.get_task_graph()
# => %{
#   "fetch-docs" => :completed,
#   "clone-repo" => :completed,
#   "parse-codebase" => :completed,
#   "generate-embeddings" => :completed,
#   "review-quality" => :completed,
#   "finalize-ingestion" => :completed
# }

# Detailed metrics per step
:telemetry.attach("ingestion-metrics", [:task_graph, :toolkit, :execute], &log_metrics/4, nil)
```

---

## Summary

TaskGraph provides:

1. **Dependency-aware orchestration** - Automatic task ordering
2. **Role-based security** - Different privileges per step
3. **Parallel execution** - Where dependencies allow
4. **Error resilience** - Per-task retries and timeouts
5. **Full observability** - Task graph + telemetry

Perfect for complex workflows like code ingestion that need security, reliability, and visibility!
