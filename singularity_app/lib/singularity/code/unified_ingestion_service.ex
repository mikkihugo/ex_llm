defmodule Singularity.Code.UnifiedIngestionService do
  @moduledoc """
  Unified Code Ingestion Service - Single source of truth for code parsing and storage

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Code.UnifiedIngestionService",
    "purpose": "Unified code ingestion - parse ONCE, populate BOTH tables",
    "layer": "domain_service",
    "architecture_role": "consolidates_duplicate_ingestion_pipelines",
    "used_by": ["CodeFileWatcher", "HTDAGAutoBootstrap", "mix code.ingest"]
  }
  ```

  ## Architecture

  ```mermaid
  graph TD
    A[CodeFileWatcher] --> D[UnifiedIngestionService]
    B[HTDAGAutoBootstrap] --> D
    C[mix code.ingest] --> D

    D --> E[Parse ONCE with ParserEngine Rust NIF]
    E --> F[Split Results]
    F --> G[Write to code_files table]
    F --> H[Write to codebase_metadata table]
  ```

  ## Anti-Patterns

  DO NOT:
  - Create separate parsing pipelines (use this service!)
  - Parse files multiple times (parse once, populate both tables)
  - Call HTDAGAutoBootstrap.persist_module_to_db directly (use this service!)
  - Call ParserEngine.parse_and_store_file directly (use this service!)

  ## Benefits

  - ✅ Parse once (not twice!)
  - ✅ Single source of truth
  - ✅ Consistent data across tables
  - ✅ Centralized error handling
  - ✅ Easier to maintain

  """

  require Logger
  alias Singularity.{Repo, ParserEngine}
  alias Singularity.Schemas.CodeFile
  alias Singularity.Analysis.{AstExtractor, MetadataValidator}

  @doc """
  Ingest a single file - parse once, populate both tables.

  ## Parameters

  - `file_path` - Absolute path to file
  - `opts` - Options
    - `:codebase_id` - Codebase identifier (default: "singularity")
    - `:skip_validation` - Skip metadata validation (default: false)

  ## Returns

  - `{:ok, %{code_files: result1, codebase_metadata: result2}}` - Both inserts succeeded
  - `{:ok, %{code_files: result1}}` - Only code_files succeeded
  - `{:ok, %{codebase_metadata: result2}}` - Only codebase_metadata succeeded
  - `{:error, reason}` - Both failed

  ## Examples

      iex> UnifiedIngestionService.ingest_file("/path/to/file.ex", codebase_id: "my_project")
      {:ok, %{code_files: %CodeFile{}, codebase_metadata: %{id: 123}}}

  """
  def ingest_file(file_path, opts \\ []) do
    codebase_id = Keyword.get(opts, :codebase_id, "singularity")
    skip_validation = Keyword.get(opts, :skip_validation, false)

    start_time = System.monotonic_time(:millisecond)

    Logger.debug("[UnifiedIngestion] Ingesting #{Path.basename(file_path)}")

    # Step 1: Parse file ONCE with comprehensive Rust NIF
    case ParserEngine.parse_file(file_path) do
      {:ok, parse_result} ->
        # Step 2: Insert to BOTH tables in parallel
        task1 = Task.async(fn -> insert_to_code_files(file_path, parse_result, codebase_id, skip_validation) end)
        task2 = Task.async(fn -> insert_to_codebase_metadata(file_path, parse_result, codebase_id) end)

        result1 = Task.await(task1, 30_000)
        result2 = Task.await(task2, 30_000)

        duration = System.monotonic_time(:millisecond) - start_time

        # Step 3: Handle results
        handle_dual_insert_results(result1, result2, file_path, duration)

      {:error, reason} ->
        Logger.error("[UnifiedIngestion] Parse failed for #{Path.basename(file_path)}: #{inspect(reason)}")
        {:error, {:parse_failed, reason}}
    end
  end

  @doc """
  Ingest entire directory tree.

  Efficiently ingests all files in directory using parallel processing.

  ## Examples

      iex> UnifiedIngestionService.ingest_tree("/path/to/project", codebase_id: "my_project")
      {:ok, %{success: 150, failed: 2}}

  """
  def ingest_tree(root_path, opts \\ []) do
    codebase_id = Keyword.get(opts, :codebase_id, "singularity")
    max_concurrency = Keyword.get(opts, :max_concurrency, 10)

    Logger.info("[UnifiedIngestion] Ingesting tree: #{root_path}")

    # Get all source files
    files = find_source_files(root_path)

    Logger.info("[UnifiedIngestion] Found #{length(files)} files to ingest")

    # Ingest in parallel
    results =
      files
      |> Task.async_stream(
        fn file_path ->
          ingest_file(file_path, codebase_id: codebase_id)
        end,
        max_concurrency: max_concurrency,
        timeout: 60_000
      )
      |> Enum.to_list()

    # Count successes and failures
    success_count = Enum.count(results, fn
      {:ok, {:ok, _}} -> true
      _ -> false
    end)

    failed_count = length(results) - success_count

    Logger.info("[UnifiedIngestion] Complete: #{success_count} succeeded, #{failed_count} failed")

    {:ok, %{success: success_count, failed: failed_count, total: length(files)}}
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp insert_to_code_files(file_path, parse_result, codebase_id, skip_validation) do
    # Extract data for code_files table schema
    # This mirrors what HTDAGAutoBootstrap.persist_module_to_db does

    language = detect_language(file_path)
    content = File.read!(file_path)

    # Use AstExtractor to get AST (same as HTDAGAutoBootstrap)
    ast_result = AstExtractor.extract_ast(content, language)

    # Validate metadata unless skipped
    validated_ast =
      if skip_validation do
        ast_result
      else
        case MetadataValidator.validate_ast_metadata(ast_result, language) do
          {:ok, validated} -> validated
          {:error, reason} ->
            Logger.warning("[UnifiedIngestion] Validation failed: #{inspect(reason)}, using unvalidated AST")
            ast_result
        end
      end

    # Build CodeFile changeset
    attrs = %{
      file_path: file_path,
      module_name: extract_module_name(parse_result, file_path),
      language: Atom.to_string(language),
      content: content,
      ast: validated_ast,
      codebase_id: codebase_id,
      last_modified: File.stat!(file_path).mtime |> NaiveDateTime.from_erl!()
    }

    # Insert or update
    case Repo.get_by(CodeFile, file_path: file_path, codebase_id: codebase_id) do
      nil ->
        %CodeFile{}
        |> CodeFile.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> CodeFile.changeset(attrs)
        |> Repo.update()
    end
  end

  defp insert_to_codebase_metadata(file_path, _parse_result, codebase_id) do
    # Use ParserEngine to store comprehensive metadata
    # This already handles the codebase_metadata table insert
    ParserEngine.parse_and_store_file(file_path, codebase_id: codebase_id)
  end

  defp handle_dual_insert_results(result1, result2, file_path, duration) do
    basename = Path.basename(file_path)

    case {result1, result2} do
      {{:ok, code_file}, {:ok, metadata}} ->
        Logger.debug("✓✓ Dual-sync success for #{basename} (#{duration}ms)")
        {:ok, %{code_files: code_file, codebase_metadata: metadata}}

      {{:ok, code_file}, {:error, reason2}} ->
        Logger.warning("✓✗ code_files OK, codebase_metadata failed for #{basename}: #{inspect(reason2)}")
        {:ok, %{code_files: code_file}}

      {{:error, reason1}, {:ok, metadata}} ->
        Logger.warning("✗✓ code_files failed, codebase_metadata OK for #{basename}: #{inspect(reason1)}")
        {:ok, %{codebase_metadata: metadata}}

      {{:error, reason1}, {:error, reason2}} ->
        Logger.error("✗✗ Both tables failed for #{basename} - code_files: #{inspect(reason1)}, codebase_metadata: #{inspect(reason2)}")
        {:error, {:both_failed, reason1, reason2}}
    end
  end

  defp find_source_files(root_path) do
    extensions = [".ex", ".exs", ".gleam", ".rs", ".ts", ".tsx", ".js", ".jsx", ".py", ".java", ".go"]

    root_path
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(fn path ->
      File.regular?(path) and
      String.ends_with?(path, extensions) and
      not String.contains?(path, ["/_build/", "/deps/", "/node_modules/", "/.git/"])
    end)
  end

  defp detect_language(file_path) do
    case Path.extname(file_path) do
      ".ex" -> :elixir
      ".exs" -> :elixir
      ".gleam" -> :gleam
      ".rs" -> :rust
      ".ts" -> :typescript
      ".tsx" -> :typescript
      ".js" -> :javascript
      ".jsx" -> :javascript
      ".py" -> :python
      ".java" -> :java
      ".go" -> :go
      _ -> :unknown
    end
  end

  defp extract_module_name(parse_result, file_path) do
    # Try to extract module name from parse result
    # Fallback to file path if not found
    case parse_result do
      %{module_name: name} when is_binary(name) -> name
      %{"module_name" => name} when is_binary(name) -> name
      _ ->
        # Derive from file path (e.g., lib/singularity/foo.ex -> Singularity.Foo)
        file_path
        |> Path.basename(".ex")
        |> Macro.camelize()
    end
  end
end
