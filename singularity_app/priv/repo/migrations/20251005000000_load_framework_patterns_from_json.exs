defmodule Singularity.Repo.Migrations.LoadFrameworkPatternsFromJson do
  use Ecto.Migration
  require Logger

  @templates_dir Path.join([
    __DIR__, "..", "..", "..", "..",
    "rust", "tool_doc_index", "templates"
  ])

  def up do
    # Load framework patterns from JSON templates
    load_patterns_from_json()
  end

  def down do
    # Patterns will be recreated on next up
    execute "TRUNCATE framework_patterns"
  end

  defp load_patterns_from_json do
    Logger.info("Loading framework patterns from JSON templates...")

    templates = find_all_templates()
    count = Enum.count(templates)

    Logger.info("Found #{count} JSON templates to load")

    Enum.each(templates, fn {file_path, template_data} ->
      insert_pattern(template_data, file_path)
    end)

    Logger.info("✅ Loaded #{count} framework patterns from JSON")
  end

  defp find_all_templates do
    # Scan all JSON files in templates directory
    [@templates_dir, "framework/*.json"]
    |> Path.join()
    |> Path.wildcard()
    |> Enum.map(fn file_path ->
      case File.read(file_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, data} -> {file_path, data}
            {:error, reason} ->
              Logger.warn("Failed to parse #{file_path}: #{inspect(reason)}")
              nil
          end
        {:error, reason} ->
          Logger.warn("Failed to read #{file_path}: #{inspect(reason)}")
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp insert_pattern(data, source_file) do
    framework_name = data["id"] || data["name"] || Path.basename(source_file, ".json")
    framework_type = determine_type(data)

    # Extract detection patterns
    detect = data["detect"] || %{}
    file_patterns = detect["fileExtensions"] || []
    directory_patterns = detect["directoryPatterns"] || []
    config_files = detect["configFiles"] || []

    # Extract commands
    dev_command = get_in(data, ["dev", "command"])
    build_command = get_in(data, ["build", "command"])
    install_command = get_in(data, ["commands", "install"])
    test_command = get_in(data, ["commands", "test"])
    output_directory = get_in(data, ["build", "directory"])

    # Confidence weight
    confidence_weight = get_in(data, ["confidence", "baseWeight"]) || 0.8

    # Build metadata from template
    metadata = %{
      source_file: source_file,
      category: data["category"],
      ecosystem: get_in(data, ["metadata", "ecosystem"]),
      homepage: get_in(data, ["metadata", "homepage"]),
      repository: get_in(data, ["metadata", "repository"]),
      llm_enabled: !is_nil(data["llm"]),
      has_snippets: !is_nil(get_in(data, ["llm", "snippets"]))
    }

    execute """
    INSERT INTO framework_patterns (
      framework_name, framework_type,
      file_patterns, directory_patterns, config_files,
      build_command, dev_command, install_command, test_command,
      output_directory, confidence_weight,
      extended_metadata,
      created_at, updated_at
    ) VALUES (
      '#{escape_sql(framework_name)}',
      '#{framework_type}',
      '#{Jason.encode!(file_patterns)}'::jsonb,
      '#{Jason.encode!(directory_patterns)}'::jsonb,
      '#{Jason.encode!(config_files)}'::jsonb,
      #{quote_or_null(build_command)},
      #{quote_or_null(dev_command)},
      #{quote_or_null(install_command)},
      #{quote_or_null(test_command)},
      #{quote_or_null(output_directory)},
      #{confidence_weight},
      '#{Jason.encode!(metadata)}'::jsonb,
      NOW(),
      NOW()
    )
    ON CONFLICT (framework_name, framework_type) DO UPDATE SET
      file_patterns = EXCLUDED.file_patterns,
      directory_patterns = EXCLUDED.directory_patterns,
      config_files = EXCLUDED.config_files,
      build_command = EXCLUDED.build_command,
      dev_command = EXCLUDED.dev_command,
      install_command = EXCLUDED.install_command,
      test_command = EXCLUDED.test_command,
      output_directory = EXCLUDED.output_directory,
      confidence_weight = EXCLUDED.confidence_weight,
      extended_metadata = EXCLUDED.extended_metadata,
      updated_at = NOW()
    """

    Logger.info("  ✓ Loaded: #{framework_name}")
  rescue
    e ->
      Logger.error("Failed to insert pattern from #{source_file}: #{inspect(e)}")
  end

  defp determine_type(data) do
    case data["category"] do
      "fullstack_framework" -> "fullstack"
      "frontend_framework" -> "frontend"
      "backend_framework" -> "backend"
      "language" -> "language"
      "build_tool" -> "build_tool"
      _ -> "framework"
    end
  end

  defp escape_sql(nil), do: ""
  defp escape_sql(str) when is_binary(str) do
    String.replace(str, "'", "''")
  end

  defp quote_or_null(nil), do: "NULL"
  defp quote_or_null(str) when is_binary(str) do
    "'#{escape_sql(str)}'"
  end
end
