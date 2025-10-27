defmodule Mix.Tasks.TemplatesData.Load do
  @moduledoc """
  Load all templates_data/ (Git) into PostgreSQL JSONB

  ## Architecture: Git ↔ PostgreSQL ↔ CentralCloud

  - **Git** (templates_data/) - Version control, curated defaults
  - **PostgreSQL JSONB** - Runtime cache, fast queries (no parsing)
  - **CentralCloud** - Learn detection rules, distribute improvements

  ## Usage

      mix templates_data.load              # Load all templates
      mix templates_data.load architecture_patterns
      mix templates_data.load frameworks
      mix templates_data.load all

  ## Storage Strategy

  - **content_raw** (TEXT) - Original JSON (audit trail, export to git)
  - **content** (JSONB) - Parsed JSON (fast @> queries, no parsing)
  - **embedding** (pgvector) - Semantic search
  - **source** - "git" (curated) or "learned" (from CentralCloud)

  Queries use JSONB operators (@>, ?|, etc) which are indexed and optimized
  by PostgreSQL. No Ecto.Query needed for JSON querying.

  ## Export Learned

  After templates are used successfully (100+ times, 95%+ success rate):

      mix templates_data.export --min-usage 100 --min-success 0.95

  This promotes learned improvements back to Git for review.
  """

  use Mix.Task
  require Logger

  alias Singularity.Repo
  alias Singularity.Schemas.KnowledgeArtifact

  # Directory -> primary type mapping (can be overridden by JSON "type" field)
  @type_map %{
    "architecture_patterns" => "architecture_pattern",
    "frameworks" => "framework",
    "quality_standards" => "quality_standard",
    "code_generation" => "code_template",
    "prompt_library" => "prompt",
    "code_snippets" => "code_snippet",
    "workflows" => "workflow",
    "htdag_strategies" => "strategy",
    "base" => "base_template",
    "partials" => "partial_template",
    "rules" => "rule"
  }

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [] ->
        load_all()

      ["all"] ->
        load_all()

      [dir_name] ->
        if Map.has_key?(@type_map, dir_name) do
          load_directory(dir_name)
        else
          Logger.error("Unknown directory: #{dir_name}")
          Logger.info("Available: #{Enum.join(Map.keys(@type_map), ", ")}")
          System.halt(1)
        end

      _ ->
        IO.puts("Usage: mix templates_data.load [dir_name | all]")
        System.halt(1)
    end
  end

  defp load_all do
    Logger.info("Loading all templates_data/ into PostgreSQL JSONB...")

    results =
      @type_map
      |> Map.keys()
      |> Enum.flat_map(&load_directory/1)

    successful = Enum.count(results, &match?({:ok, _}, &1))
    failed = Enum.count(results, &match?({:error, _}, &1))

    if failed > 0 do
      Logger.warning("Loaded #{successful} templates, #{failed} failed")
    else
      Logger.info("✓ Loaded #{successful} templates")
    end
  end

  defp load_directory(dir_name) do
    primary_type = Map.get(@type_map, dir_name)
    path = Path.join("templates_data", dir_name)

    Logger.info("Loading #{dir_name}...")

    case File.ls(path) do
      {:ok, entries} ->
        Enum.flat_map(entries, fn entry ->
          full_path = Path.join(path, entry)

          if File.dir?(full_path) and not String.starts_with?(entry, ".") do
            load_recursive(full_path, primary_type)
          else
            if String.ends_with?(entry, ".json") do
              [load_file(full_path, primary_type)]
            else
              []
            end
          end
        end)

      {:error, _reason} ->
        Logger.warning("Directory not found: #{path}")
        []
    end
  end

  defp load_recursive(path, artifact_type) do
    case File.ls(path) do
      {:ok, entries} ->
        Enum.flat_map(entries, fn entry ->
          full_path = Path.join(path, entry)

          if File.dir?(full_path) and not String.starts_with?(entry, ".") do
            load_recursive(full_path, artifact_type)
          else
            if String.ends_with?(entry, ".json") do
              [load_file(full_path, artifact_type)]
            else
              []
            end
          end
        end)

      {:error, _reason} ->
        []
    end
  end

  defp load_file(file_path, primary_type) do
    case File.read(file_path) do
      {:ok, json_string} ->
        case Jason.decode(json_string) do
          {:ok, content_map} ->
            # Extract or generate artifact_id and version
            artifact_id =
              content_map["id"] ||
                content_map["artifact_id"] ||
                Path.basename(file_path, ".json")

            version =
              content_map["version"] ||
                content_map["spec_version"] ||
                "1.0.0"

            # Auto-detect type from JSON structure (allows overriding primary_type)
            artifact_type =
              detect_type_from_json(content_map) ||
                primary_type ||
                "generic_template"

            # Extract hierarchical type information
            type_hierarchy = extract_type_hierarchy(content_map, artifact_type)

            # Enrich content_map with type hierarchy (stored in JSONB for queries)
            enriched_content =
              Map.merge(content_map, %{
                "_type_hierarchy" => type_hierarchy,
                "_detected_type" => artifact_type
              })

            attrs = %{
              artifact_type: artifact_type,
              artifact_id: artifact_id,
              version: version,
              content_raw: json_string,
              content: enriched_content,
              source: "git",
              created_by: "templates_loader"
            }

            case Repo.insert(
                   KnowledgeArtifact.changeset(%KnowledgeArtifact{}, attrs),
                   on_conflict: :replace_all,
                   conflict_target: [:artifact_type, :artifact_id, :version]
                 ) do
              {:ok, _} ->
                {:ok, file_path}

              {:error, reason} ->
                Logger.error("Failed to insert #{file_path}: #{inspect(reason)}")
                {:error, reason}
            end

          {:error, reason} ->
            Logger.error("Invalid JSON in #{file_path}: #{inspect(reason)}")
            {:error, "invalid_json"}
        end

      {:error, reason} ->
        Logger.error("Failed to read #{file_path}: #{inspect(reason)}")
        {:error, "file_not_found"}
    end
  end

  # Extract hierarchical type information from JSON
  # Returns a map with parent and child type relationships
  defp extract_type_hierarchy(content_map, detected_type) do
    parent_pattern = content_map["parent_pattern"]
    parent_type = content_map["parent_type"]
    category = content_map["category"]

    %{
      type: detected_type,
      parent: parent_pattern || parent_type,
      category: category,
      self_documenting: true,
      hierarchy_path: build_hierarchy_path(detected_type, parent_pattern || parent_type)
    }
  end

  # Build a hierarchical path for queries
  # e.g., "architecture/microservices/saga" or "code_generation/quality"
  defp build_hierarchy_path(type, parent) when is_binary(parent) do
    "#{parent}/#{type}"
  end

  defp build_hierarchy_path(type, _nil) do
    type
  end

  # Auto-detect template type from JSON structure
  # Returns nil if no specific type detected (use primary_type instead)
  defp detect_type_from_json(content_map) when is_map(content_map) do
    # Priority order of detection:

    # 1. Explicit type field
    type_field =
      content_map["type"] || content_map["artifact_type"] || content_map["template_type"]

    if type_field, do: type_field, else: detect_from_structure(content_map)
  end

  defp detect_type_from_json(_), do: nil

  defp detect_from_structure(content_map) do
    # 2. Structure-based detection (falling back to hierarchical indicators)
    cond do
      has_keys?(content_map, ["indicators", "benefits", "concerns"]) ->
        "architecture_pattern"

      has_keys?(content_map, ["steps", "inputs", "outputs"]) ->
        "code_generator"

      has_keys?(content_map, ["code", "language", "description"]) ->
        "code_snippet"

      has_keys?(content_map, ["capabilities", "language", "quality_level"]) ->
        "quality_standard"

      has_keys?(content_map, ["role", "content"]) and
          String.contains?(Map.get(content_map, "role", ""), ["system", "assistant"]) ->
        "system_prompt"

      has_keys?(content_map, ["workflows"]) ->
        "workflow"

      has_keys?(content_map, ["rules"]) ->
        "rule"

      has_keys?(content_map, ["llm_team_templates"]) ->
        "pattern_detector"

      has_keys?(content_map, ["workspace"]) ->
        "workspace_pattern"

      true ->
        nil
    end
  end

  # Helper: check if map has all keys
  defp has_keys?(map, keys) when is_map(map) and is_list(keys) do
    Enum.all?(keys, &Map.has_key?(map, &1))
  end

  defp has_keys?(_, _), do: false
end
