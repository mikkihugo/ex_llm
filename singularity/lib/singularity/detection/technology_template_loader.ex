defmodule Singularity.TechnologyTemplateLoader do
  @moduledoc """
  Loads technology detection templates from JSON files.

  Sources:
  * `priv/technology_patterns/` for local overrides/defaults
  * `rust/package_registry_indexer/templates/` for shared templates shipped with the repo

  JSON structure may either expose a top-level `patterns` list or nested
  `detector_signatures` (e.g. `import_patterns`, `dependencies`, etc.).
  """

  require Logger

  alias Singularity.TemplateStore

  @doc "Return decoded template map (or nil if missing)"
  def template(identifier, _opts \\ []) do
    # Use dynamic template discovery - tries multiple patterns and semantic search
    case Singularity.Knowledge.TemplateService.find_technology_template(identifier) do
      {:ok, template} ->
        template

      {:error, reason} ->
        Logger.warning("Technology template not found: #{identifier}, reason: #{reason}")
        nil
    end
  end

  @doc "Return compiled regex patterns for identifier"
  def patterns(identifier, opts \\ []) do
    field = opts[:field]

    identifier
    |> template(_opts)
    |> extract_patterns(field)
    |> compile_patterns()
  end

  @doc "Append template-based patterns to defaults"
  def compiled_patterns(identifier, defaults, _opts \\ []) when is_list(defaults) do
    defaults ++ patterns(identifier, _opts)
  end

  @doc "Fetch detector signatures map for identifier"
  def detector_signatures(identifier, _opts \\ []) do
    case template(identifier, _opts) do
      %{"detector_signatures" => signatures} when is_map(signatures) -> signatures
      _ -> %{}
    end
  end

  @doc """
  Resolve directories searched for template JSON files. Accepts optional
  `:dirs` override for tests or custom locations.
  """
  def directories(opts \\ []) do
    base =
      [
        Application.get_env(:singularity, :technology_pattern_dir),
        Application.app_dir(:singularity, "priv/technology_patterns"),
        Path.expand("../../rust/package_registry_indexer/templates", __DIR__)
      ]
      |> Enum.filter(&(&1 && File.dir?(&1)))

    Enum.uniq(opts[:dirs] || base)
  end

  defp to_relative_path(identifier) when is_atom(identifier),
    do: Atom.to_string(identifier) <> ".json"

  defp to_relative_path({group, name}) do
    Path.join(Atom.to_string(group), Atom.to_string(name) <> ".json")
  end

  defp to_relative_path(list) when is_list(list) do
    case Enum.split(list, -1) do
      {segments, [last]} ->
        Path.join(Enum.map(segments, &Atom.to_string/1))
        |> Path.join(Atom.to_string(last) <> ".json")

      _ ->
        raise ArgumentError, "invalid identifier for technology template"
    end
  end

  defp load_json(path) do
    cond do
      File.dir?(path) ->
        nil

      not File.exists?(path) ->
        nil

      true ->
        case File.read(path) do
          {:ok, content} ->
            case Jason.decode(content) do
              {:ok, decoded} ->
                decoded

              {:error, reason} ->
                Logger.debug("Failed to decode technology template",
                  file: path,
                  reason: inspect(reason)
                )

                nil
            end

          {:error, reason} ->
            Logger.debug("Failed to read technology template",
              file: path,
              reason: inspect(reason)
            )

            nil
        end
    end
  end

  defp extract_patterns(nil, _field), do: []

  defp extract_patterns(template, field) when is_map(template) do
    case Map.get(template, field) do
      patterns when is_list(patterns) ->
        patterns
        |> Enum.map(&normalize_pattern/1)
        |> Enum.reject(&is_nil/1)

      pattern when is_binary(pattern) ->
        [String.trim(pattern)]

      pattern when is_atom(pattern) ->
        [Atom.to_string(pattern)]

      _ ->
        []
    end
  end

  defp extract_patterns(template, field) when is_list(template) do
    template
    |> Enum.flat_map(&extract_patterns(&1, field))
    |> Enum.uniq()
  end

  defp extract_patterns(_template, _field), do: []

  defp compile_patterns(patterns) do
    patterns
    |> Enum.reduce([], fn pattern, acc ->
      case compile_pattern(pattern) do
        {:ok, regex} ->
          [regex | acc]

        {:error, reason} ->
          Logger.debug("Skipping invalid technology pattern", reason: inspect(reason))
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp compile_pattern(%{"regex" => pattern}) when is_binary(pattern),
    do: compile_pattern(pattern)

  defp compile_pattern(pattern) when is_binary(pattern), do: Regex.compile(pattern, "i")
  defp compile_pattern(%Regex{} = regex), do: {:ok, regex}
  defp compile_pattern(_), do: {:error, :invalid_pattern}

  defp persist_template(identifier, %{} = template, source, opts) do
    if Keyword.get(opts, :persist, true) do
      try do
        case TechnologyTemplateStore.upsert(identifier, template,
               source: to_string(source),
               metadata: %{persisted_at: DateTime.utc_now()}
             ) do
          {:ok, _record} ->
            :ok

          {:error, changeset} ->
            Logger.debug("Failed to persist technology template",
              identifier: inspect(identifier),
              errors: inspect(changeset.errors)
            )
        end
      rescue
        error ->
          Logger.debug("Technology template persistence error",
            identifier: inspect(identifier),
            source: source,
            error: Exception.message(error)
          )
      end
    end

    template
  end

  defp persist_template(identifier, template, source, opts) do
    # Extract options
    quality_level = Keyword.get(opts, :quality_level, :production)
    force_update = Keyword.get(opts, :force_update, false)
    validate_schema = Keyword.get(opts, :validate_schema, true)

    # Validate template schema if requested
    if validate_schema do
      case validate_template_schema(template) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning("Template validation failed", identifier: identifier, reason: reason)
          {:error, {:validation_failed, reason}}
      end
    end

    # Check if template already exists
    case get_existing_template(identifier) do
      nil ->
        # Create new template
        create_template(identifier, template, source, quality_level)

      existing_template ->
        if force_update or template_updated?(existing_template, template) do
          # Update existing template
          update_template(identifier, template, source, quality_level)
        else
          # No changes needed
          {:ok, existing_template}
        end
    end
  end

  defp normalize_pattern(pattern) when is_binary(pattern) do
    trimmed = String.trim(pattern)
    if trimmed == "", do: nil, else: trimmed
  end

  defp normalize_pattern(pattern) when is_atom(pattern) do
    Atom.to_string(pattern)
  end

  defp normalize_pattern(%{"name" => name}), do: normalize_pattern(name)
  defp normalize_pattern(%{name: name}), do: normalize_pattern(name)
  defp normalize_pattern(%{"pattern" => pattern}), do: normalize_pattern(pattern)
  defp normalize_pattern(%{pattern: pattern}), do: normalize_pattern(pattern)

  defp normalize_pattern(_), do: nil

  # Helper functions for persist_template
  defp validate_template_schema(template) do
    required_fields = ["name", "description", "patterns", "quality_standards"]

    missing_fields =
      required_fields
      |> Enum.reject(fn field -> Map.has_key?(template, field) end)

    if length(missing_fields) > 0 do
      {:error, {:missing_fields, missing_fields}}
    else
      :ok
    end
  end

  defp get_existing_template(identifier) do
    # Try to get existing template from database
    case TechnologyTemplateStore.get(identifier) do
      {:ok, template} -> template
      {:error, :not_found} -> nil
      {:error, _reason} -> nil
    end
  end

  defp create_template(identifier, template, source, quality_level) do
    # Create new template in database
    template_data =
      Map.merge(template, %{
        "identifier" => identifier,
        "source" => source,
        "quality_level" => quality_level,
        "created_at" => DateTime.utc_now(),
        "updated_at" => DateTime.utc_now()
      })

    case TechnologyTemplateStore.create(template_data) do
      {:ok, created_template} ->
        Logger.info("Created new technology template",
          identifier: identifier,
          source: source,
          quality_level: quality_level
        )

        {:ok, created_template}

      {:error, reason} ->
        Logger.error("Failed to create technology template",
          identifier: identifier,
          reason: reason
        )

        {:error, {:creation_failed, reason}}
    end
  end

  defp update_template(identifier, template, source, quality_level) do
    # Update existing template in database
    update_data =
      Map.merge(template, %{
        "source" => source,
        "quality_level" => quality_level,
        "updated_at" => DateTime.utc_now()
      })

    case TechnologyTemplateStore.update(identifier, update_data) do
      {:ok, updated_template} ->
        Logger.info("Updated technology template",
          identifier: identifier,
          source: source,
          quality_level: quality_level
        )

        {:ok, updated_template}

      {:error, reason} ->
        Logger.error("Failed to update technology template",
          identifier: identifier,
          reason: reason
        )

        {:error, {:update_failed, reason}}
    end
  end

  defp template_updated?(existing_template, new_template) do
    # Compare key fields to see if template has been updated
    key_fields = ["name", "description", "patterns", "quality_standards"]

    key_fields
    |> Enum.any?(fn field ->
      Map.get(existing_template, field) != Map.get(new_template, field)
    end)
  end
end
