defmodule Singularity.TechnologyTemplateLoader do
  @moduledoc """
  Loads technology detection templates from JSON files.

  Sources:
  * `priv/technology_patterns/` for local overrides/defaults
  * `rust/tool_doc_index/templates/` for shared templates shipped with the repo

  JSON structure may either expose a top-level `patterns` list or nested
  `detector_signatures` (e.g. `import_patterns`, `dependencies`, etc.).
  """

  require Logger

  alias Singularity.PlatformIntegration.NatsConnector
  alias Singularity.TechnologyTemplateStore

  @doc "Return decoded template map (or nil if missing)"
  def template(identifier, opts \\ []) do
    case fetch_from_nats(identifier, opts) do
      {:ok, template} ->
        template

      _ ->
        case TechnologyTemplateStore.get(identifier) do
          %{} = template ->
            template

          _ ->
            relative = to_relative_path(identifier)

            opts
            |> directories()
            |> Enum.find_value(fn dir ->
              path = Path.join(dir, relative)

              case load_json(path) do
                %{} = template -> persist_template(identifier, template, :filesystem, opts)
                _ -> nil
              end
            end)
        end
    end
  end

  @doc "Return compiled regex patterns for identifier"
  def patterns(identifier, opts \\ []) do
    field = opts[:field]

    identifier
    |> template(opts)
    |> extract_patterns(field)
    |> compile_patterns()
  end

  @doc "Append template-based patterns to defaults"
  def compiled_patterns(identifier, defaults, opts \\ []) when is_list(defaults) do
    defaults ++ patterns(identifier, opts)
  end

  @doc "Fetch detector signatures map for identifier"
  def detector_signatures(identifier, opts \\ []) do
    case template(identifier, opts) do
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
        Path.expand("../../rust/tool_doc_index/templates", __DIR__)
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

  defp extract_patterns(%{"detector_signatures" => signatures} = template, field)
       when is_atom(field) do
    case Map.get(signatures, Atom.to_string(field)) do
      list when is_list(list) -> list
      _ -> extract_patterns(Map.delete(template, "detector_signatures"), nil)
    end
  end

  defp extract_patterns(%{"patterns" => patterns}, _field) when is_list(patterns), do: patterns
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

  defp fetch_from_nats(identifier, opts) do
    subject = opts[:nats_subject] || "singularity.tech.templates"
    payload = %{identifier: identifier}

    case NatsConnector.fetch_template(subject, payload) do
      {:ok, %{} = template} ->
        {:ok, persist_template(identifier, template, :nats, opts)}

      {:error, reason} ->
        Logger.debug("NATS template fetch failed",
          identifier: inspect(identifier),
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

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

  defp persist_template(_identifier, template, _source, _opts), do: template
end
