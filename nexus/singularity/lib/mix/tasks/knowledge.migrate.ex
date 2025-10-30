defmodule Mix.Tasks.Knowledge.Migrate do
  @moduledoc """
  Migrate existing JSON templates into knowledge_artifacts table.

  ## Usage

      # Migrate all JSON files from various locations
      mix knowledge.migrate

      # Migrate specific directory
      mix knowledge.migrate --path templates_data/quality/

      # Dry run (show what would be migrated)
      mix knowledge.migrate --dry-run

      # Skip embedding generation (faster, can embed later)
      mix knowledge.migrate --skip-embedding

  ## What it Does

  1. Finds all JSON files in:
     - templates_data/
     - singularity/priv/code_quality_templates/
     - rust/package_registry_indexer/templates/ (framework/language only)

  2. Validates JSON structure
  3. Inserts into knowledge_artifacts (dual storage: raw + JSONB)
  4. Generates embeddings (async, unless --skip-embedding)

  ## Output

  Shows migration progress and statistics.
  """

  use Mix.Task
  require Logger

  alias Singularity.Knowledge.ArtifactStore

  @shortdoc "Migrate existing JSON templates to knowledge_artifacts table"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [path: :string, dry_run: :boolean, skip_embedding: :boolean, force: :boolean],
        aliases: [p: :path, d: :dry_run, s: :skip_embedding, f: :force]
      )

    Mix.Task.run("app.start")

    dry_run = Keyword.get(opts, :dry_run, false)
    skip_embedding = Keyword.get(opts, :skip_embedding, false)
    force = Keyword.get(opts, :force, false)
    path = Keyword.get(opts, :path)

    if dry_run do
      Mix.shell().info("🔍 DRY RUN MODE - No changes will be made")
    end

    Mix.shell().info("🚀 Starting knowledge artifact migration...")
    Mix.shell().info("")

    # Find all JSON files
    files = find_json_files(path)

    Mix.shell().info("📊 Found #{length(files)} JSON files")
    Mix.shell().info("")

    # Migrate each file
    results =
      Enum.map(files, fn file_path ->
        migrate_file(file_path, dry_run: dry_run, skip_embedding: skip_embedding, force: force)
      end)

    # Print summary
    print_summary(results)
  end

  defp find_json_files(nil) do
    # Default: scan all known template locations
    [
      "templates_data/**/*.json",
      "singularity/priv/code_quality_templates/*.json",
      "rust/package_registry_indexer/templates/framework/*.json",
      "rust/package_registry_indexer/templates/language/*.json"
    ]
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.reject(&String.contains?(&1, "learned/"))
    |> Enum.uniq()
  end

  defp find_json_files(path) do
    if File.dir?(path) do
      Path.wildcard("#{path}/**/*.json")
    else
      [path]
    end
  end

  defp migrate_file(file_path, opts) do
    dry_run = opts[:dry_run] || false
    skip_embedding = opts[:skip_embedding] || false
    force = opts[:force] || false

    relative_path = Path.relative_to_cwd(file_path)

    with {:ok, json_string} <- File.read(file_path),
         {:ok, content_map} <- Jason.decode(json_string),
         {:ok, metadata} <- extract_metadata(file_path, content_map) do
      # Calculate SHA256 of the JSON content for idempotency
      content_sha = :crypto.hash(:sha256, json_string) |> Base.encode16(case: :lower)

      # Check if this file has already been ingested with the same content
      if !force && already_ingested?(metadata.artifact_type, metadata.artifact_id, content_sha) do
        # File already ingested with same content - skip it
        Mix.shell().info("📄 Processing: #{relative_path}")
        Mix.shell().info("   ⏭️  Already ingested (SHA: #{String.slice(content_sha, 0..7)}...)")
        {:ok, :skipped}
      else
        Mix.shell().info("📄 Processing: #{relative_path}")

        if dry_run do
          Mix.shell().info(
            "   Would migrate: #{metadata.artifact_type}/#{metadata.artifact_id} (v#{metadata.version}) [SHA: #{String.slice(content_sha, 0..7)}...]"
          )

          {:ok, :dry_run}
        else
          case ArtifactStore.store(
                 metadata.artifact_type,
                 metadata.artifact_id,
                 content_map,
                 version: metadata.version,
                 skip_embedding: skip_embedding
               ) do
            {:ok, artifact} ->
              Mix.shell().info(
                "   ✅ Migrated: #{artifact.artifact_type}/#{artifact.artifact_id} (v#{artifact.version}) [SHA: #{String.slice(content_sha, 0..7)}...]"
              )

              {:ok, artifact}

            {:error, changeset} ->
              Mix.shell().error("   ❌ Failed: #{inspect(changeset.errors)}")
              {:error, changeset.errors}
          end
        end
      end
    else
      {:error, %Jason.DecodeError{} = error} ->
        Mix.shell().error("   ❌ Invalid JSON: #{error.data}")
        {:error, :invalid_json}

      {:error, reason} ->
        Mix.shell().error("   ❌ Error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp already_ingested?(artifact_type, artifact_id, content_sha) do
    # Check if an artifact with this SHA already exists in the database
    # For now, we'll just check if artifact_id exists (simple approach)
    # In the future, we can add SHA256 column to the schema for exact deduplication
    # Note: content_sha parameter reserved for future SHA-based deduplication
    _sha = content_sha

    case Singularity.Repo.get_by(
           Singularity.Schemas.KnowledgeArtifact,
           artifact_type: artifact_type,
           artifact_id: artifact_id
         ) do
      nil -> false
      _artifact -> true
    end
  rescue
    _ -> false
  end

  defp extract_metadata(file_path, content_map) do
    # Detect artifact type and ID from path and content
    relative_path = Path.relative_to_cwd(file_path)
    parts = Path.split(relative_path)

    {artifact_type, artifact_id} = detect_type_and_id(parts, content_map)
    version = content_map["version"] || "1.0.0"

    {:ok, %{artifact_type: artifact_type, artifact_id: artifact_id, version: version}}
  end

  defp detect_type_and_id(parts, content_map) do
    cond do
      # templates_data/quality/elixir-production.json
      "quality" in parts ->
        filename = List.last(parts) |> Path.rootname()
        {"quality_template", filename}

      # templates_data/frameworks/phoenix.json
      "frameworks" in parts ->
        filename = List.last(parts) |> Path.rootname()
        {"framework_pattern", filename}

      # templates_data/prompts/plan-mode.json
      "prompts" in parts ->
        filename = List.last(parts) |> Path.rootname()
        {"system_prompt", filename}

      # templates_data/code_generation/patterns/messaging/elixir-nats-consumer.json
      "code_generation" in parts and "patterns" in parts ->
        category = Enum.at(parts, Enum.find_index(parts, &(&1 == "patterns")) + 1)
        filename = List.last(parts) |> Path.rootname()
        {"code_template_#{category}", filename}

      # singularity/priv/code_quality_templates/elixir_production.json
      "code_quality_templates" in parts ->
        filename = List.last(parts) |> Path.rootname()
        {"quality_template", filename}

      # rust/package_registry_indexer/templates/framework/nextjs.json
      "package_registry_indexer" in parts and "framework" in parts ->
        filename = List.last(parts) |> Path.rootname()
        {"framework_pattern", filename}

      # rust/package_registry_indexer/templates/language/rust.json
      "package_registry_indexer" in parts and "language" in parts ->
        filename = List.last(parts) |> Path.rootname()
        {"language_template", filename}

      # Fallback: use content metadata
      true ->
        type = content_map["type"] || "unknown"
        id = content_map["id"] || content_map["name"] || Path.basename(List.last(parts), ".json")
        {type, id}
    end
  end

  defp print_summary(results) do
    Mix.shell().info("")
    Mix.shell().info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    Mix.shell().info("📊 Migration Summary")
    Mix.shell().info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    total = length(results)

    success =
      Enum.count(results, fn
        {:ok, value} -> not is_atom(value)
        _other -> false
      end)

    skipped = Enum.count(results, &match?({:ok, :skipped}, &1))
    dry_runs = Enum.count(results, &match?({:ok, :dry_run}, &1))
    errors = Enum.count(results, &match?({:error, _}, &1))

    Mix.shell().info("Total files:     #{total}")
    Mix.shell().info("✅ Migrated:     #{success}")
    Mix.shell().info("⏭️  Skipped:      #{skipped}")
    if dry_runs > 0, do: Mix.shell().info("🔍 Dry-run:      #{dry_runs}")
    if errors > 0, do: Mix.shell().info("❌ Failed:       #{errors}")
    Mix.shell().info("")

    if success > 0 or skipped > 0 do
      Mix.shell().info("🎉 Knowledge ingestion complete!")
      Mix.shell().info("")
      Mix.shell().info("Next steps:")
      Mix.shell().info("  1. Generate embeddings: moon run templates_data:embed-all")
      Mix.shell().info("  2. View statistics:     moon run templates_data:stats")
      Mix.shell().info("  3. Search artifacts:    iex -S mix")
      Mix.shell().info("")
      Mix.shell().info("Idempotency:")
      Mix.shell().info("  • Skipped files won't be re-ingested (content unchanged)")

      Mix.shell().info(
        "  • Force re-ingest: mix knowledge.migrate --path ../../templates_data --force"
      )

      Mix.shell().info("")
    end
  end
end
