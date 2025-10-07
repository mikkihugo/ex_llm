defmodule Mix.Tasks.Templates do
  @moduledoc """
  Mix tasks for template management.

  Available tasks:
  - `mix templates.sync` - Sync all templates from /templates_data to database
  - `mix templates.validate` - Validate all template JSON files
  - `mix templates.embed` - Regenerate embeddings for all templates
  - `mix templates.list` - List all templates in database
  - `mix templates.stats` - Show template usage statistics
  """
end

defmodule Mix.Tasks.Templates.Sync do
  @moduledoc """
  Sync all templates from /templates_data to PostgreSQL.

  Reads all JSON files, validates schema, generates Qodo-Embed-1
  embeddings, and stores in database.

  ## Examples

      # Sync all templates
      mix templates.sync

      # Force update existing templates
      mix templates.sync --force

      # Dry run (validate only, don't write to DB)
      mix templates.sync --dry-run
  """

  use Mix.Task
  require Logger

  @shortdoc "Sync templates from /templates_data to database"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [force: :boolean, dry_run: :boolean],
        aliases: [f: :force, d: :dry_run]
      )

    force = Keyword.get(opts, :force, false)
    dry_run = Keyword.get(opts, :dry_run, false)

    Mix.shell().info("Syncing templates from /templates_data...")

    if dry_run do
      Mix.shell().info("DRY RUN - No changes will be made to database")
    end

    case Singularity.TemplateStore.sync(force: force, dry_run: dry_run) do
      {:ok, count} ->
        Mix.shell().info("✅ Successfully synced #{count} templates")

      {:error, reason} ->
        Mix.shell().error("❌ Sync failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end
end

defmodule Mix.Tasks.Templates.Validate do
  @moduledoc """
  Validate all template JSON files against schema.

  Checks:
  - Valid JSON syntax
  - Required fields present
  - Schema compliance
  - Quality scores for code_pattern type

  ## Examples

      # Validate all templates
      mix templates.validate

      # Validate specific template
      mix templates.validate templates_data/code_generation/quality/elixir.json
  """

  use Mix.Task

  @shortdoc "Validate template JSON files"

  @impl Mix.Task
  def run(args) do
    case args do
      [] ->
        validate_all()

      [path | _] ->
        validate_file(path)
    end
  end

  defp validate_all do
    templates_dir = Path.join([File.cwd!(), "..", "templates_data"])

    Mix.shell().info("Validating templates in #{templates_dir}...")

    files =
      templates_dir
      |> Path.join("**/*.json")
      |> Path.wildcard()
      |> Enum.reject(&String.ends_with?(&1, "schema.json"))

    {valid, invalid} =
      files
      |> Enum.map(&validate_file_quiet/1)
      |> Enum.split_with(fn
        {:ok, _} -> true
        _ -> false
      end)

    Mix.shell().info("✅ Valid: #{length(valid)}")

    if length(invalid) > 0 do
      Mix.shell().error("❌ Invalid: #{length(invalid)}")

      Enum.each(invalid, fn {:error, path, reason} ->
        Mix.shell().error("  - #{path}: #{reason}")
      end)

      exit({:shutdown, 1})
    else
      Mix.shell().info("All templates are valid!")
    end
  end

  defp validate_file(path) do
    case do_validate_file(path) do
      :ok ->
        Mix.shell().info("✅ #{path} is valid")

      {:error, reason} ->
        Mix.shell().error("❌ #{path}: #{reason}")
        exit({:shutdown, 1})
    end
  end

  defp validate_file_quiet(path) do
    case do_validate_file(path) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, path, reason}
    end
  end

  defp do_validate_file(path) do
    with {:ok, content} <- File.read(path),
         {:ok, data} <- Jason.decode(content),
         :ok <- validate_schema(data) do
      :ok
    else
      {:error, %Jason.DecodeError{}} -> {:error, "Invalid JSON syntax"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_schema(data) do
    required = ["version", "type", "metadata", "content"]

    missing =
      Enum.filter(required, fn key ->
        !Map.has_key?(data, key)
      end)

    if Enum.empty?(missing) do
      validate_metadata(data["metadata"])
    else
      {:error, "Missing required fields: #{Enum.join(missing, ", ")}"}
    end
  end

  defp validate_metadata(metadata) do
    required = ["id", "name", "description", "language"]

    missing =
      Enum.filter(required, fn key ->
        !Map.has_key?(metadata, key)
      end)

    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing metadata fields: #{Enum.join(missing, ", ")}"}
    end
  end
end

defmodule Mix.Tasks.Templates.Embed do
  @moduledoc """
  Regenerate embeddings for all templates using Qodo-Embed-1.

  Useful after:
  - Updating to newer Qodo-Embed-1 model
  - Fine-tuning Qodo-Embed-1 on YOUR code
  - Changing embedding generation logic

  ## Examples

      # Regenerate all embeddings
      mix templates.embed

      # Only re-embed templates without embeddings
      mix templates.embed --missing-only
  """

  use Mix.Task
  require Logger

  @shortdoc "Regenerate Qodo-Embed-1 embeddings for templates"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [missing_only: :boolean],
        aliases: [m: :missing_only]
      )

    missing_only = Keyword.get(opts, :missing_only, false)

    Mix.shell().info("Regenerating embeddings with Qodo-Embed-1...")

    # Get all templates
    {:ok, templates} = Singularity.TemplateStore.list()

    templates_to_embed =
      if missing_only do
        Enum.filter(templates, fn t -> is_nil(t.embedding) end)
      else
        templates
      end

    total = length(templates_to_embed)
    Mix.shell().info("Embedding #{total} templates...")

    # Batch process
    templates_to_embed
    |> Enum.chunk_every(10)
    |> Enum.with_index()
    |> Enum.each(fn {batch, idx} ->
      Enum.each(batch, fn template ->
        # Re-embed
        search_text = build_search_text(template)

        case Singularity.EmbeddingEngine.embed(search_text, model: :qodo_embed) do
          {:ok, embedding} ->
            # Update in DB
            Singularity.Repo.get!(Singularity.Schemas.Template, template.id)
            |> Singularity.Schemas.Template.changeset(%{embedding: embedding})
            |> Singularity.Repo.update!()

            :ok

          {:error, reason} ->
            Logger.error("Failed to embed #{template.id}: #{inspect(reason)}")
        end
      end)

      progress = ((idx + 1) * 10 / total * 100) |> min(100) |> Float.round(1)
      Mix.shell().info("Progress: #{progress}%")
    end)

    Mix.shell().info("✅ Embeddings regenerated")
  end

  defp build_search_text(template) do
    [
      template.metadata["name"],
      template.metadata["description"],
      template.metadata["language"],
      Enum.join(template.metadata["tags"] || [], " "),
      String.slice(template.content["code"] || "", 0..500)
    ]
    |> Enum.join(" ")
  end
end

defmodule Mix.Tasks.Templates.List do
  @moduledoc """
  List all templates in database.

  ## Examples

      # List all
      mix templates.list

      # Filter by language
      mix templates.list --language elixir

      # Filter by type
      mix templates.list --type code_pattern
  """

  use Mix.Task

  @shortdoc "List templates in database"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [language: :string, type: :string],
        aliases: [l: :language, t: :type]
      )

    {:ok, templates} = Singularity.TemplateStore.list(opts)

    Mix.shell().info("Templates (#{length(templates)}):\n")

    Enum.each(templates, fn template ->
      Mix.shell().info("""
      #{template.id} (#{template.type})
        Language: #{template.metadata["language"]}
        Quality: #{template.quality["score"] || "N/A"}
        Usage: #{template.usage["count"] || 0} times, #{Float.round((template.usage["success_rate"] || 0.0) * 100, 1)}% success
      """)
    end)
  end
end

defmodule Mix.Tasks.Templates.Stats do
  @moduledoc """
  Show template usage statistics.

  ## Examples

      mix templates.stats
  """

  use Mix.Task

  @shortdoc "Show template usage statistics"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    {:ok, templates} = Singularity.TemplateStore.list()

    total = length(templates)
    by_type = Enum.group_by(templates, & &1.type) |> Enum.map(fn {k, v} -> {k, length(v)} end)

    by_language =
      Enum.group_by(templates, & &1.metadata["language"])
      |> Enum.map(fn {k, v} -> {k, length(v)} end)

    total_usage = Enum.sum(Enum.map(templates, &(&1.usage["count"] || 0)))

    avg_success_rate =
      Enum.sum(Enum.map(templates, &(&1.usage["success_rate"] || 0.0))) / max(total, 1)

    most_used =
      templates
      |> Enum.sort_by(&(&1.usage["count"] || 0), :desc)
      |> Enum.take(5)

    Mix.shell().info("""
    📊 Template Statistics

    Total Templates: #{total}

    By Type:
    #{Enum.map_join(by_type, "\n", fn {type, count} -> "  - #{type}: #{count}" end)}

    By Language:
    #{Enum.map_join(by_language, "\n", fn {lang, count} -> "  - #{lang}: #{count}" end)}

    Usage:
      Total Uses: #{total_usage}
      Average Success Rate: #{Float.round(avg_success_rate * 100, 1)}%

    Most Used:
    #{Enum.map_join(most_used, "\n", fn t -> "  - #{t.id}: #{t.usage["count"] || 0} uses (#{Float.round((t.usage["success_rate"] || 0.0) * 100, 1)}% success)" end)}
    """)
  end
end
