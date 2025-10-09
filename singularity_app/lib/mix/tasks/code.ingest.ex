defmodule Mix.Tasks.Code.Ingest do
  @moduledoc """
  Ingest codebase into PostgreSQL for semantic code search.

  ## Usage

      # Ingest current singularity repo
      mix code.ingest

      # Ingest specific codebase
      mix code.ingest --path /path/to/repo --id my-project

      # Skip embeddings (faster, but no semantic search)
      mix code.ingest --skip-embeddings

  ## What it does

  1. Creates database schema (if not exists)
  2. Registers codebase in codebase_registry
  3. Parses all source files with Rust parser
  4. Generates embeddings (Google AI text-embedding-004)
  5. Inserts into codebase_metadata table

  ## Performance

  - ~5000 files/minute (parsing with Rust NIF)
  - ~100 embeddings/minute (Google AI free tier: 1500/day)
  - Uses connection pooling for PostgreSQL
  """

  use Mix.Task
  require Logger

  alias Singularity.{Repo, ParserEngine, CodeSearch, EmbeddingGenerator}

  @shortdoc "Ingest codebase into database for semantic search"

  @default_codebase_id "singularity"
  @default_codebase_path File.cwd!()
  @batch_size 100

  @impl Mix.Task
  def run(args) do
    # Parse arguments
    {opts, _args} =
      OptionParser.parse!(args,
        strict: [
          path: :string,
          id: :string,
          skip_embeddings: :boolean,
          skip_schema: :boolean,
          languages: :string
        ],
        aliases: [
          p: :path,
          i: :id,
          s: :skip_embeddings
        ]
      )

    # Start application dependencies
    Mix.Task.run("app.start")

    codebase_path = Keyword.get(opts, :path, @default_codebase_path) |> Path.expand()
    codebase_id = Keyword.get(opts, :id, @default_codebase_id)
    skip_embeddings = Keyword.get(opts, :skip_embeddings, false)
    skip_schema = Keyword.get(opts, :skip_schema, false)
    languages = parse_languages(Keyword.get(opts, :languages))

    Mix.shell().info("Ingesting codebase...")
    Mix.shell().info("  Path: #{codebase_path}")
    Mix.shell().info("  ID: #{codebase_id}")
    Mix.shell().info("  Embeddings: #{if skip_embeddings, do: "SKIPPED", else: "enabled"}")

    # Verify path exists
    unless File.exists?(codebase_path) do
      Mix.raise("Path does not exist: #{codebase_path}")
    end

    # Get database connection
    {:ok, conn} = Postgrex.start_link(
      hostname: System.get_env("PGHOST", "localhost"),
      port: String.to_integer(System.get_env("PGPORT", "5432")),
      database: System.get_env("PGDATABASE", "singularity"),
      username: System.get_env("PGUSER", "postgres"),
      password: System.get_env("PGPASSWORD", "")
    )

    try do
      # Step 1: Create schema
      unless skip_schema do
        Mix.shell().info("\n[1/5] Creating database schema...")
        CodeSearch.create_unified_schema(conn)
        Mix.shell().info("✓ Schema created")
      end

      # Step 2: Register codebase
      Mix.shell().info("\n[2/5] Registering codebase...")
      codebase_name = Path.basename(codebase_path)

      CodeSearch.register_codebase(
        conn,
        codebase_id,
        codebase_path,
        codebase_name,
        description: "Ingested via mix code.ingest",
        language: detect_primary_language(codebase_path),
        metadata: %{ingested_at: DateTime.utc_now()}
      )

      CodeSearch.update_codebase_status(conn, codebase_id, "analyzing")
      Mix.shell().info("✓ Codebase registered: #{codebase_id}")

      # Step 3: Parse files
      Mix.shell().info("\n[3/5] Parsing files...")

      {:ok, files} = discover_source_files(codebase_path, languages)
      total_files = length(files)
      Mix.shell().info("Found #{total_files} files to parse")

      parse_results =
        ParserEngine.parse_and_store_tree(
          codebase_path,
          codebase_id: codebase_id,
          max_concurrency: 8
        )

      case parse_results do
        {:ok, results} ->
          success_count = Enum.count(results, fn
            {:ok, _} -> true
            _ -> false
          end)
          Mix.shell().info("✓ Parsed #{success_count}/#{total_files} files")

        {:error, reason} ->
          Mix.shell().error("Failed to parse files: #{inspect(reason)}")
      end

      # Step 4: Generate embeddings
      unless skip_embeddings do
        Mix.shell().info("\n[4/5] Generating embeddings...")
        Mix.shell().info("Using Google AI text-embedding-004 (768 dims, FREE tier)")
        Mix.shell().info("Rate limit: 1500 requests/day")

        # Query files without embeddings
        files_needing_embeddings = query_files_without_embeddings(conn, codebase_id)
        embedding_count = length(files_needing_embeddings)

        if embedding_count > 0 do
          Mix.shell().info("Generating #{embedding_count} embeddings...")

          # Process in batches with progress
          files_needing_embeddings
          |> Enum.chunk_every(@batch_size)
          |> Enum.with_index(1)
          |> Enum.each(fn {batch, batch_num} ->
            total_batches = ceil(embedding_count / @batch_size)
            Mix.shell().info("  Batch #{batch_num}/#{total_batches}...")

            batch
            |> Task.async_stream(
              fn file ->
                generate_and_store_embedding(conn, codebase_id, file)
              end,
              max_concurrency: 4,
              timeout: :infinity,
              on_timeout: :kill_task
            )
            |> Enum.to_list()

            # Small delay between batches to respect rate limits
            Process.sleep(1000)
          end)

          Mix.shell().info("✓ Generated #{embedding_count} embeddings")
        else
          Mix.shell().info("✓ All files already have embeddings")
        end
      end

      # Step 5: Update status
      Mix.shell().info("\n[5/5] Finalizing...")
      CodeSearch.update_codebase_status(conn, codebase_id, "ready")

      # Summary
      Mix.shell().info("\n✓ Ingestion complete!")
      print_summary(conn, codebase_id)

    after
      GenServer.stop(conn)
    end
  end

  # Private helpers

  defp parse_languages(nil), do: nil
  defp parse_languages(langs_str) do
    langs_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end

  defp discover_source_files(path, nil) do
    # All supported languages
    extensions = [
      ".ex", ".exs", ".gleam", ".rs", ".ts", ".tsx", ".js", ".jsx",
      ".py", ".go", ".java", ".c", ".cpp", ".h", ".hpp"
    ]

    files =
      Path.wildcard(Path.join(path, "**/*"))
      |> Enum.filter(fn file ->
        File.regular?(file) and Path.extname(file) in extensions
      end)

    {:ok, files}
  end

  defp discover_source_files(path, languages) when is_list(languages) do
    # Filter by specific languages
    extension_map = %{
      "elixir" => [".ex", ".exs"],
      "gleam" => [".gleam"],
      "rust" => [".rs"],
      "typescript" => [".ts", ".tsx"],
      "javascript" => [".js", ".jsx"],
      "python" => [".py"],
      "go" => [".go"]
    }

    extensions =
      languages
      |> Enum.flat_map(fn lang -> Map.get(extension_map, lang, []) end)

    files =
      Path.wildcard(Path.join(path, "**/*"))
      |> Enum.filter(fn file ->
        File.regular?(file) and Path.extname(file) in extensions
      end)

    {:ok, files}
  end

  defp detect_primary_language(path) do
    cond do
      File.exists?(Path.join(path, "mix.exs")) -> "elixir"
      File.exists?(Path.join(path, "Cargo.toml")) -> "rust"
      File.exists?(Path.join(path, "package.json")) -> "typescript"
      File.exists?(Path.join(path, "go.mod")) -> "go"
      File.exists?(Path.join(path, "requirements.txt")) -> "python"
      true -> "unknown"
    end
  end

  defp query_files_without_embeddings(conn, codebase_id) do
    result = Postgrex.query!(
      conn,
      """
      SELECT id, path, language, code_lines, comment_lines
      FROM codebase_metadata
      WHERE codebase_id = $1
        AND vector_embedding IS NULL
        AND code_lines > 0
      ORDER BY code_lines DESC
      """,
      [codebase_id]
    )

    result.rows
    |> Enum.map(fn [id, path, language, code_lines, comment_lines] ->
      %{
        id: id,
        path: path,
        language: language,
        code_lines: code_lines,
        comment_lines: comment_lines
      }
    end)
  end

  defp generate_and_store_embedding(conn, codebase_id, file) do
    # Read file content
    content = case File.read(file.path) do
      {:ok, content} -> content
      {:error, _} -> ""
    end

    if String.trim(content) == "" do
      Logger.debug("Skipping empty file: #{file.path}")
      {:ok, :skipped}
    else
      # Generate embedding for file content
      case EmbeddingGenerator.embed(content) do
        {:ok, embedding} ->
          # Store embedding in database
          Postgrex.query!(
            conn,
            """
            UPDATE codebase_metadata
            SET vector_embedding = $2,
                updated_at = NOW()
            WHERE id = $1
            """,
            [file.id, embedding]
          )
          {:ok, :embedded}

        {:error, reason} ->
          Logger.warning("Failed to generate embedding for #{file.path}: #{inspect(reason)}")
          {:error, reason}
      end
    end
  rescue
    error ->
      Logger.error("Error processing #{file.path}: #{inspect(error)}")
      {:error, error}
  end

  defp print_summary(conn, codebase_id) do
    result = Postgrex.query!(
      conn,
      """
      SELECT
        COUNT(*) as total_files,
        COUNT(DISTINCT language) as languages,
        SUM(code_lines) as total_code_lines,
        COUNT(CASE WHEN vector_embedding IS NOT NULL THEN 1 END) as embedded_files,
        AVG(quality_score) as avg_quality
      FROM codebase_metadata
      WHERE codebase_id = $1
      """,
      [codebase_id]
    )

    case result.rows do
      [[total, langs, lines, embedded, quality]] ->
        Mix.shell().info("\n=== Summary ===")
        Mix.shell().info("  Total files: #{total}")
        Mix.shell().info("  Languages: #{langs}")
        Mix.shell().info("  Code lines: #{lines || 0}")
        Mix.shell().info("  Embedded files: #{embedded}/#{total}")
        Mix.shell().info("  Avg quality: #{if quality, do: Float.round(quality, 2), else: "N/A"}")

      _ ->
        :ok
    end
  end
end
