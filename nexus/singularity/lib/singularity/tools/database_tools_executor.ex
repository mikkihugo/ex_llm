defmodule Singularity.Tools.DatabaseToolsExecutor do
  @moduledoc """
  Database-First Tool Executor - Executes AI tool requests via pgmq

  ## Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Tools.DatabaseToolsExecutor",
    "purpose": "Execute database-first code tools via pgmq",
    "layer": "infrastructure",
    "category": "tool_execution",
    "database": "codebase_metadata",
    "tool_format": "OpenAI function calling"
  }
  ```

  ## Architecture

  TypeScript AI Server                     Elixir Tool Executor
  ────────────────────                     ─────────────────────
  pgmq Request
    │ Subject: tools.code.get
    │ Format: OpenAI function calling
    └───────────────────────►               GenServer
                                              │
                                              ├─ Security validation
                                              ├─ Query PostgreSQL
                                              ├─ Audit logging
                                              └─ pgmq Response

  ## Database-First Architecture

  **NO filesystem I/O** - All code access via PostgreSQL:
  - Pre-parsed AST, symbols, metrics
  - Vector embeddings for semantic search
  - Complex metrics (complexity, quality, security)
  - Dependency relationships

  ## Tool Tiers

  ### Tier 1: Essential Code Access (3 tools)
  - `tools.code.get` - Get file with AST/symbols
  - `tools.code.search` - Semantic search (pgvector)
  - `tools.code.list` - List indexed files

  ### Tier 2: Symbol Navigation (3 tools)
  - `tools.symbol.find` - Find symbol definition
  - `tools.symbol.refs` - Find references
  - `tools.symbol.list` - List symbols in file

  ### Tier 3: Dependencies (2 tools)
  - `tools.deps.get` - Get file dependencies
  - `tools.deps.graph` - Get dependency graph

  ## OpenAI Function Calling Format

  **Request:**
  ```json
  {
    "path": "/src/handler.ts",
    "codebase_id": "my-project",
    "include_ast": true,
    "include_symbols": true
  }
  ```

  **Response (Success):**
  ```json
  {
    "data": {
      "path": "/src/handler.ts",
      "content": "...",
      "ast": {...},
      "symbols": [...]
    },
    "error": null
  }
  ```

  **Response (Error):**
  ```json
  {
    "data": null,
    "error": "File not found: /src/handler.ts"
  }
  ```

  ## Security Policy

  - Path validation (no access outside allowed directories)
  - Rate limiting (prevent abuse)
  - Codebase isolation (users see only their codebases)
  - Query size limits (prevent expensive queries)

  ## Call Graph (YAML)

  ```yaml
  uses:
    - Singularity.Repo: Database queries
    - Singularity.CodeSearch: Semantic search
    - Singularity.Messaging.Client: PGFlow-based communication
    - Singularity.Tools.SecurityPolicy: Access control

  used_by:
    - AI Server (TypeScript): Via pgmq requests

  publishes:
    - No events

  subscribes:
    - tools.code.>: Code access tools
    - tools.symbol.>: Symbol navigation tools
    - tools.deps.>: Dependency tools
  ```

  ## Anti-Patterns

  ⚠️ **DO NOT**:
  - Read files from filesystem (use database only!)
  - Skip security validation
  - Return raw database records (sanitize first)
  - Execute without audit logging

  ## Search Keywords

  database-first, tool-execution, pgmq, postgresql, pgvector, semantic-search,
  ast-parsing, symbol-navigation, dependency-analysis, openai-format,
  security-policy, audit-logging, code-access
  """

  use GenServer
  require Logger

  alias Singularity.{Repo, CodeSearch}
  alias Singularity.Infrastructure.Telemetry
  alias Singularity.Tools.SecurityPolicy
  import Ecto.Query

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    Logger.info("[DatabaseToolsExecutor] Starting...")

    # Subscribe to all tool subjects
    subjects = [
      "tools.code.>",
      "tools.symbol.>",
      "tools.deps.>"
    ]

    Enum.each(subjects, fn subject ->
      # Subscribe to PGFlow workflow completion events for tool requests
      subscribe_to_pgflow_tool_requests(subject)
    end)

    {:ok, %{}}
  end

  @impl true
  def handle_call({:execute_tool, topic, request}, _from, state) do
    response = execute_tool(topic, request)
    # Convert response format from {data, error} to {:ok, result} or {:error, reason}
    case response do
      %{"data" => data, "error" => nil} -> {:reply, {:ok, data}, state}
      %{"data" => nil, "error" => error} -> {:reply, {:error, error}, state}
      other -> {:reply, {:ok, other}, state}
    end
  end

  @impl true
  def handle_info({:msg, %{topic: topic, body: body, reply_to: reply_to}}, state) do
    start_time = System.monotonic_time(:millisecond)

    Logger.debug("[DatabaseToolsExecutor] Received request: #{topic}")

    {response, decoded_request} =
      case Jason.decode(body) do
        {:ok, request} ->
          # Execute tool based on subject
          {execute_tool(topic, request), request}

        {:error, _} ->
          {error_response("Invalid JSON request"), %{}}
      end

    # Send response via workflow
    case Singularity.Infrastructure.PgFlow.Workflow.create_workflow(
           Singularity.Workflows.DatabaseToolExecutionWorkflow,
           %{
             "request" => decoded_request,
             "reply_to" => reply_to,
             "response" => response
           }
         ) do
      {:ok, workflow_id} ->
        duration = System.monotonic_time(:millisecond) - start_time
        log_tool_execution(topic, decoded_request, :success, duration)

        Logger.info("[DatabaseToolsExecutor] Created response workflow",
          workflow_id: workflow_id,
          reply_to: reply_to
        )

      {:error, reason} ->
        Logger.error(
          "[DatabaseToolsExecutor] Failed to create response workflow: #{inspect(reason)}"
        )
    end

    {:noreply, state}
  end

  ## Tool Execution

  defp execute_tool("tools.code.get", request) do
    with {:ok, _} <- SecurityPolicy.validate_code_access(request),
         {:ok, result} <- get_code(request) do
      success_response(result)
    else
      {:error, reason} -> error_response(reason)
    end
  end

  defp execute_tool("tools.code.search", request) do
    with {:ok, _} <- SecurityPolicy.validate_code_search(request),
         {:ok, result} <- search_code(request) do
      success_response(result)
    else
      {:error, reason} -> error_response(reason)
    end
  end

  defp execute_tool("tools.code.list", request) do
    with {:ok, _} <- SecurityPolicy.validate_code_list(request),
         {:ok, result} <- list_code_files(request) do
      success_response(result)
    else
      {:error, reason} -> error_response(reason)
    end
  end

  defp execute_tool("tools.symbol.find", request) do
    with {:ok, _} <- SecurityPolicy.validate_symbol_find(request),
         {:ok, result} <- find_symbol(request) do
      success_response(result)
    else
      {:error, reason} -> error_response(reason)
    end
  end

  defp execute_tool("tools.symbol.refs", request) do
    with {:ok, _} <- SecurityPolicy.validate_symbol_refs(request),
         {:ok, result} <- find_symbol_references(request) do
      success_response(result)
    else
      {:error, reason} -> error_response(reason)
    end
  end

  defp execute_tool("tools.symbol.list", request) do
    with {:ok, _} <- SecurityPolicy.validate_symbol_list(request),
         {:ok, result} <- list_symbols(request) do
      success_response(result)
    else
      {:error, reason} -> error_response(reason)
    end
  end

  defp execute_tool("tools.deps.get", request) do
    with {:ok, _} <- SecurityPolicy.validate_deps_get(request),
         {:ok, result} <- get_dependencies(request) do
      success_response(result)
    else
      {:error, reason} -> error_response(reason)
    end
  end

  defp execute_tool("tools.deps.graph", request) do
    with {:ok, _} <- SecurityPolicy.validate_deps_graph(request),
         {:ok, result} <- get_dependency_graph(request) do
      success_response(result)
    else
      {:error, reason} -> error_response(reason)
    end
  end

  defp execute_tool(unknown_subject, _request) do
    error_response("Unknown tool subject: #{unknown_subject}")
  end

  ## Tool Implementations

  defp get_code(%{"path" => path} = request) do
    codebase_id = Map.get(request, "codebase_id", "singularity")
    include_ast = Map.get(request, "include_ast", false)
    include_symbols = Map.get(request, "include_symbols", false)

    query =
      from(c in "codebase_metadata",
        where: c.codebase_id == ^codebase_id and c.path == ^path,
        select: %{
          path: c.path,
          language: c.language,
          size: c.size,
          lines: c.lines,
          functions: c.functions,
          classes: c.classes,
          structs: c.structs,
          enums: c.enums,
          imports: c.imports,
          exports: c.exports,
          cyclomatic_complexity: c.cyclomatic_complexity,
          maintainability_index: c.maintainability_index
        }
      )

    case Repo.one(query) do
      nil ->
        {:error, "File not found: #{path}"}

      result ->
        # Build response with optional fields
        response = %{
          path: result.path,
          language: result.language,
          size: result.size,
          lines: result.lines,
          metrics: %{
            cyclomatic_complexity: result.cyclomatic_complexity,
            maintainability_index: result.maintainability_index
          }
        }

        response =
          if include_symbols do
            Map.merge(response, %{
              functions: result.functions || [],
              classes: result.classes || [],
              structs: result.structs || [],
              enums: result.enums || []
            })
          else
            response
          end

        response =
          if include_ast do
            Map.put(response, :imports, result.imports || [])
            |> Map.put(:exports, result.exports || [])
          else
            response
          end

        {:ok, response}
    end
  end

  defp search_code(%{"query" => query} = request) do
    codebase_id = Map.get(request, "codebase_id", "singularity")
    limit = Map.get(request, "limit", 10)
    min_similarity = Map.get(request, "min_similarity", 0.7)

    # Use CodeSearch module for semantic search
    case CodeSearch.semantic_search(query,
           codebase_id: codebase_id,
           limit: limit,
           min_similarity: min_similarity
         ) do
      {:ok, results} ->
        {:ok,
         Enum.map(results, fn r ->
           %{
             path: r.path,
             language: r.language,
             similarity: r.similarity,
             snippet: truncate_text(r.path, 200)
           }
         end)}

      {:error, reason} ->
        {:error, "Search failed: #{inspect(reason)}"}
    end
  end

  defp list_code_files(request) do
    codebase_id = Map.get(request, "codebase_id", "singularity")
    language = Map.get(request, "language")
    pattern = Map.get(request, "pattern")

    query = from(c in "codebase_metadata", where: c.codebase_id == ^codebase_id)

    query =
      if language do
        from(c in query, where: c.language == ^language)
      else
        query
      end

    query =
      if pattern do
        from(c in query, where: ilike(c.path, ^pattern))
      else
        query
      end

    query =
      from(c in query,
        select: %{path: c.path, language: c.language, size: c.size, lines: c.lines},
        order_by: [asc: c.path],
        limit: 1000
      )

    results = Repo.all(query)
    {:ok, results}
  end

  defp find_symbol(%{"symbol" => symbol_name} = request) do
    codebase_id = Map.get(request, "codebase_id", "singularity")
    symbol_type = Map.get(request, "symbol_type")

    # Search in JSONB arrays for symbol definitions
    # This is a simplified implementation - real one would use more sophisticated search
    query =
      from(c in "codebase_metadata",
        where: c.codebase_id == ^codebase_id,
        where:
          fragment(
            "? @> ?::jsonb OR ? @> ?::jsonb OR ? @> ?::jsonb",
            c.functions,
            ^Jason.encode!([%{name: symbol_name}]),
            c.classes,
            ^Jason.encode!([%{name: symbol_name}]),
            c.structs,
            ^Jason.encode!([%{name: symbol_name}])
          ),
        select: %{
          path: c.path,
          language: c.language,
          functions: c.functions,
          classes: c.classes,
          structs: c.structs
        },
        limit: 10
      )

    results = Repo.all(query)

    # Extract matching symbols
    matches =
      Enum.flat_map(results, fn r ->
        [
          extract_symbols(r.functions, symbol_name, "function", r.path),
          extract_symbols(r.classes, symbol_name, "class", r.path),
          extract_symbols(r.structs, symbol_name, "struct", r.path)
        ]
      end)
      |> List.flatten()
      |> Enum.filter(& &1)

    {:ok, matches}
  end

  defp find_symbol_references(%{"symbol" => symbol_name} = request) do
    codebase_id = Map.get(request, "codebase_id", "singularity")

    # Query for files that reference this symbol (imports or usages)
    # Strategy: Search through functions and classes that reference the symbol
    query =
      from(c in "codebase_metadata",
        where: c.codebase_id == ^codebase_id,
        select: %{
          path: c.path,
          functions: c.functions,
          classes: c.classes,
          imports: c.imports,
          dependencies: c.dependencies
        }
      )

    case Repo.all(query) do
      [] ->
        {:ok, []}

      matches ->
        references =
          matches
          |> Enum.reduce([], fn result, acc ->
            file_refs =
              []
              # Check imports (from X import Y)
              |> maybe_add_import_refs(result.imports, symbol_name, result.path)
              # Check function references (functions calling this symbol)
              |> maybe_add_function_refs(result.functions, symbol_name, result.path)
              # Check class references (classes using this symbol)
              |> maybe_add_class_refs(result.classes, symbol_name, result.path)
              # Check dependencies (requires/uses)
              |> maybe_add_dependency_refs(result.dependencies, symbol_name, result.path)

            acc ++ file_refs
          end)

        {:ok, references}

      {:error, reason} ->
        {:error, "Failed to find references: #{inspect(reason)}"}
    end
  end

  defp maybe_add_import_refs(acc, nil, _symbol_name, _path), do: acc

  defp maybe_add_import_refs(acc, imports, symbol_name, path) when is_list(imports) do
    import_refs =
      imports
      |> Enum.filter(&String.contains?(&1, symbol_name))
      |> Enum.map(fn imp ->
        %{
          type: "import",
          path: path,
          symbol: symbol_name,
          reference: imp,
          context: "Module import"
        }
      end)

    acc ++ import_refs
  end

  defp maybe_add_import_refs(acc, _imports, _symbol_name, _path), do: acc

  defp maybe_add_function_refs(acc, nil, _symbol_name, _path), do: acc

  defp maybe_add_function_refs(acc, functions, symbol_name, path) when is_list(functions) do
    func_refs =
      functions
      |> Enum.filter(fn func ->
        Map.get(func, :calls, [])
        |> Enum.any?(&String.contains?(&1, symbol_name))
      end)
      |> Enum.map(fn func ->
        %{
          type: "function_call",
          path: path,
          symbol: symbol_name,
          reference: Map.get(func, :name, "unknown"),
          line: Map.get(func, :line),
          context: "Function call"
        }
      end)

    acc ++ func_refs
  end

  defp maybe_add_function_refs(acc, _functions, _symbol_name, _path), do: acc

  defp maybe_add_class_refs(acc, nil, _symbol_name, _path), do: acc

  defp maybe_add_class_refs(acc, classes, symbol_name, path) when is_list(classes) do
    class_refs =
      classes
      |> Enum.filter(fn cls ->
        Map.get(cls, :uses, [])
        |> Enum.any?(&String.contains?(&1, symbol_name))
      end)
      |> Enum.map(fn cls ->
        %{
          type: "class_usage",
          path: path,
          symbol: symbol_name,
          reference: Map.get(cls, :name, "unknown"),
          line: Map.get(cls, :line),
          context: "Class usage"
        }
      end)

    acc ++ class_refs
  end

  defp maybe_add_class_refs(acc, _classes, _symbol_name, _path), do: acc

  defp maybe_add_dependency_refs(acc, nil, _symbol_name, _path), do: acc

  defp maybe_add_dependency_refs(acc, dependencies, symbol_name, path)
       when is_list(dependencies) do
    dep_refs =
      dependencies
      |> Enum.filter(&String.contains?(&1, symbol_name))
      |> Enum.map(fn dep ->
        %{
          type: "dependency",
          path: path,
          symbol: symbol_name,
          reference: dep,
          context: "Module dependency"
        }
      end)

    acc ++ dep_refs
  end

  defp maybe_add_dependency_refs(acc, _dependencies, _symbol_name, _path), do: acc

  defp list_symbols(%{"path" => path} = request) do
    codebase_id = Map.get(request, "codebase_id", "singularity")
    symbol_type = Map.get(request, "symbol_type", "all")

    query =
      from(c in "codebase_metadata",
        where: c.codebase_id == ^codebase_id and c.path == ^path,
        select: %{
          functions: c.functions,
          classes: c.classes,
          structs: c.structs,
          enums: c.enums
        }
      )

    case Repo.one(query) do
      nil ->
        {:error, "File not found: #{path}"}

      result ->
        symbols =
          case symbol_type do
            "function" ->
              result.functions || []

            "class" ->
              result.classes || []

            "struct" ->
              result.structs || []

            "enum" ->
              result.enums || []

            "all" ->
              (result.functions || []) ++
                (result.classes || []) ++
                (result.structs || []) ++
                (result.enums || [])
          end

        {:ok, symbols}
    end
  end

  defp get_dependencies(%{"path" => path} = request) do
    codebase_id = Map.get(request, "codebase_id", "singularity")

    query =
      from(c in "codebase_metadata",
        where: c.codebase_id == ^codebase_id and c.path == ^path,
        select: %{
          imports: c.imports,
          dependencies: c.dependencies
        }
      )

    case Repo.one(query) do
      nil ->
        {:error, "File not found: #{path}"}

      result ->
        {:ok,
         %{
           imports: result.imports || [],
           dependencies: result.dependencies || []
         }}
    end
  end

  defp get_dependency_graph(request) do
    codebase_id = Map.get(request, "codebase_id", "singularity")
    format = Map.get(request, "format", "json")

    # Query all files with their dependencies
    query =
      from(c in "codebase_metadata",
        where: c.codebase_id == ^codebase_id,
        select: %{
          path: c.path,
          dependencies: c.dependencies
        }
      )

    results = Repo.all(query)

    graph = %{
      nodes: Enum.map(results, & &1.path),
      edges:
        Enum.flat_map(results, fn r ->
          Enum.map(r.dependencies || [], fn dep ->
            %{from: r.path, to: dep}
          end)
        end)
    }

    case format do
      "json" -> {:ok, graph}
      "mermaid" -> {:ok, generate_mermaid_graph(graph)}
      "dot" -> {:ok, generate_dot_graph(graph)}
      _ -> {:error, "Unknown format: #{format}"}
    end
  end

  ## Helpers

  defp success_response(data) do
    %{data: data, error: nil}
  end

  defp error_response(error) when is_binary(error) do
    %{data: nil, error: error}
  end

  defp error_response(error) do
    %{data: nil, error: inspect(error)}
  end

  defp extract_symbols(nil, _name, _type, _path), do: []

  defp extract_symbols(symbols, name, type, path) when is_list(symbols) do
    symbols
    |> Enum.filter(fn s -> s["name"] == name end)
    |> Enum.map(fn s ->
      %{
        name: s["name"],
        type: type,
        path: path,
        line: s["line"]
      }
    end)
  end

  # Subscribe to PGFlow workflow completion events for tool requests
  defp subscribe_to_pgflow_tool_requests(subject) do
    # Create PGFlow workflow subscription for tool execution requests
    workflow_name = "database_tool_execution_#{String.replace(subject, ".", "_")}"

    case Singularity.Infrastructure.PgFlow.Workflow.subscribe(workflow_name, fn workflow_result ->
           handle_tool_workflow_completion(workflow_result)
         end) do
      {:ok, subscription_id} ->
        Logger.info("[DatabaseToolsExecutor] Subscribed to PGFlow workflow",
          subject: subject,
          workflow: workflow_name,
          subscription_id: subscription_id
        )

        :ok

      {:error, reason} ->
        Logger.warning("[DatabaseToolsExecutor] Failed to subscribe to PGFlow workflow",
          subject: subject,
          reason: reason
        )

        # Fallback: log migration status
        Logger.info(
          "[DatabaseToolsExecutor] Migrating subscription from pgmq to Pgflow: #{subject}"
        )

        :ok
    end
  end

  defp handle_tool_workflow_completion(%{status: :completed, result: result}) do
    # Handle completed tool execution workflow
    Logger.debug("[DatabaseToolsExecutor] Received completed workflow result",
      result: result
    )

    :ok
  end

  defp handle_tool_workflow_completion(%{status: :failed, error: error}) do
    Logger.error("[DatabaseToolsExecutor] Tool execution workflow failed",
      error: error
    )

    :ok
  end

  defp handle_tool_workflow_completion(_), do: :ok

  defp truncate_text(text, max_len) do
    if String.length(text) > max_len do
      String.slice(text, 0, max_len) <> "..."
    else
      text
    end
  end

  defp generate_mermaid_graph(graph) do
    """
    graph TD
    #{Enum.map_join(graph.edges, "\n", fn edge -> "  #{edge.from} --> #{edge.to}" end)}
    """
  end

  defp generate_dot_graph(graph) do
    """
    digraph dependencies {
    #{Enum.map_join(graph.edges, "\n", fn edge -> "  \"#{edge.from}\" -> \"#{edge.to}\";" end)}
    }
    """
  end

  defp log_tool_execution(subject, request, result, duration) do
    Telemetry.log_tool_execution(%{
      subject: subject,
      codebase_id: Map.get(request, "codebase_id", "singularity"),
      result: result,
      duration_ms: duration
    })

    Logger.info("[DatabaseToolsExecutor] #{subject} completed in #{duration}ms: #{result}")
  end
end
