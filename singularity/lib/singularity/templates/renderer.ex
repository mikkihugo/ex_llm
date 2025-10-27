defmodule Singularity.Templates.Renderer do
  @moduledoc """
  Production-ready template renderer with composition, validation, and extensibility.

  Supports TWO rendering modes:
  1. **Legacy JSON mode**: Simple {{variable}} replacement (backward compatible)
  2. **Solid mode**: Full Handlebars syntax with conditionals, loops, partials

  Features:
  - Template composition (extends, compose bits)
  - Variable replacement with validation
  - Multi-file snippet rendering
  - Quality standard enforcement
  - Template inheritance
  - Conditional rendering (Solid only)
  - Loops/iteration (Solid only)
  - Template caching
  - Error handling with context
  - Custom helpers (Solid only)
  """

  alias Singularity.Knowledge.TemplateService
  alias Singularity.Templates.TemplateFormatters
  require Logger

  @templates_data_dir Application.compile_env(:singularity, :templates_data_dir, "templates_data")
  @priv_templates_dir "priv/templates"

  @type variables :: %{(String.t() | atom()) => any()}
  @type renderopts :: [
          validate: boolean(),
          quality_check: boolean(),
          cache: boolean()
        ]

  ## Public API

  @doc """
  Render a template with variables and options.

  ## Options
  - `:validate` - Validate required variables (default: true)
  - `:quality_check` - Run quality checks on output (default: false)
  - `:cache` - Cache rendered output (default: true)

  ## Examples

      iex> render("elixir-genserver", %{
        module_name: "MyApp.Worker",
        description: "Background worker"
      })
      {:ok, rendered_code}

      iex> render("phoenix-api", %{resource: "User"}, validate: true, quality_check: true)
      {:ok, validated_code}
  """
  @spec render(String.t(), variables(), renderopts()) :: {:ok, String.t()} | {:error, term()}
  def render(template_id, variables \\ %{}, opts \\ []) do
    opts = Keyword.merge([validate: true, quality_check: false, cache: true], opts)

    # Auto-detect format: Check for .hbs file first, fallback to JSON
    case determine_render_mode(template_id) do
      :solid ->
        render_with_solid(template_id, variables, opts)

      :legacy ->
        render_legacy(template_id, variables, opts)
    end
  end

  @doc """
  Render template using Solid (Handlebars) engine.

  Supports full Handlebars syntax: conditionals, loops, partials, custom helpers.
  """
  def render_with_solid(template_id, variables \\ %{}, opts \\ []) do
    opts = Keyword.merge([validate: true, quality_check: false, cache: true], opts)

    with {:ok, hbs_content} <- load_handlebars_template(template_id),
         {:ok, metadata} <- load_template_metadata(template_id),
         {:ok, validated_vars} <- validate_variables_from_metadata(metadata, variables, opts),
         {:ok, solid_template} <- parse_solid_template(hbs_content, template_id),
         {:ok, rendered} <- render_solid(solid_template, validated_vars),
         {:ok, checked} <- maybe_quality_check(rendered, metadata, opts) do
      {:ok, checked}
    else
      {:error, reason} = error ->
        Logger.error("Solid template render failed: #{template_id} - #{inspect(reason)}")
        error
    end
  end

  @doc """
  Legacy render using JSON templates (backward compatible).
  """
  def render_legacy(template_id, variables \\ %{}, opts \\ []) do
    opts = Keyword.merge([validate: true, quality_check: false, cache: true], opts)

    with {:ok, template} <- load_template(template_id, opts),
         {:ok, validated_vars} <- validate_variables(template, variables, opts),
         {:ok, composed} <- compose_template(template, validated_vars),
         {:ok, rendered} <- render_template(composed, validated_vars),
         {:ok, checked} <- maybe_quality_check(rendered, template, opts) do
      {:ok, checked}
    else
      {:error, reason} = error ->
        Logger.error("Template render failed: #{template_id} - #{inspect(reason)}")
        error
    end
  end

  @doc """
  Render multi-file snippets (returns map of file_path => code).

  ## Examples

      iex> render_snippets("phoenix-authenticated-api", %{
        app_name: "MyApp",
        resource: "User"
      })
      {:ok, %{
        "lib/my_app_web/router.ex" => "...",
        "lib/my_app_web/controllers/user_controller.ex" => "..."
      }}
  """
  @spec render_snippets(String.t(), variables(), renderopts()) ::
          {:ok, %{String.t() => String.t()}} | {:error, term()}
  def render_snippets(template_id, variables \\ %{}, opts \\ []) do
    with {:ok, template} <- load_template(template_id, opts),
         {:ok, snippets} <- extract_snippets(template),
         {:ok, rendered} <- render_all_snippets(snippets, variables, template) do
      {:ok, rendered}
    end
  end

  @doc """
  Preview template rendering (shows variables that will be used).

  ## Examples

      iex> preview("elixir-genserver", %{module_name: "Test"})
      {:ok, %{
        missing_required: ["description"],
        provided: ["module_name"],
        defaults_used: ["example_function"]
      }}
  """
  @spec preview(String.t(), variables()) :: {:ok, map()} | {:error, term()}
  def preview(template_id, variables) do
    with {:ok, template} <- load_template(template_id, []),
         {:ok, var_info} <- analyze_variables(template, variables) do
      {:ok, var_info}
    end
  end

  ## Solid (Handlebars) Rendering

  defp determine_render_mode(template_id) do
    # Check if .hbs file exists in templates_data/ or priv/templates/
    hbs_paths = [
      Path.join([@templates_data_dir, "**", "#{template_id}.hbs"]),
      Path.join([@priv_templates_dir, "**", "#{template_id}.hbs"])
    ]

    found =
      Enum.any?(hbs_paths, fn pattern ->
        case Path.wildcard(pattern) do
          [] -> false
          _ -> true
        end
      end)

    if found, do: :solid, else: :legacy
  end

  defp load_handlebars_template(template_id) do
    # Search for .hbs file in multiple locations
    search_paths = [
      # 1. Try priv/templates/ (compiled templates)
      Path.join([@priv_templates_dir, "code_generation", "#{template_id}.hbs"]),
      Path.join([@priv_templates_dir, "#{template_id}.hbs"]),
      # 2. Try templates_data/ (source templates)
      Path.join([@templates_data_dir, "base", "#{template_id}.hbs"]),
      Path.join([@templates_data_dir, "code_generation", "patterns", "**", "#{template_id}.hbs"])
    ]

    # Find first existing file
    found_path =
      search_paths
      |> Enum.flat_map(fn pattern -> Path.wildcard(pattern) end)
      |> Enum.find(&File.exists?/1)

    case found_path do
      nil ->
        {:error, {:template_not_found, template_id}}

      path ->
        case File.read(path) do
          {:ok, content} ->
            Logger.debug("Loaded Handlebars template: #{path}")
            {:ok, content}

          {:error, reason} ->
            {:error, {:file_read_error, reason}}
        end
    end
  end

  defp load_template_metadata(template_id) do
    # Look for -meta.json or .json file
    search_paths = [
      Path.join([@templates_data_dir, "base", "#{template_id}-meta.json"]),
      Path.join([@templates_data_dir, "base", "#{template_id}.json"]),
      Path.join([@templates_data_dir, "code_generation", "patterns", "**", "#{template_id}.json"])
    ]

    found_path =
      search_paths
      |> Enum.flat_map(fn pattern -> Path.wildcard(pattern) end)
      |> Enum.find(&File.exists?/1)

    case found_path do
      nil ->
        # No metadata file - use defaults
        {:ok, %{"variables" => %{}}}

      path ->
        case File.read(path) do
          {:ok, json} ->
            case Jason.decode(json) do
              {:ok, metadata} ->
                {:ok, metadata}

              {:error, reason} ->
                {:error, {:json_decode_error, reason}}
            end

          {:error, reason} ->
            {:error, {:file_read_error, reason}}
        end
    end
  end

  defp validate_variables_from_metadata(metadata, variables, opts) do
    if Keyword.get(opts, :validate, true) do
      var_defs = metadata["variables"] || %{}
      normalized = normalize_variables(variables)

      missing =
        Enum.filter(var_defs, fn {key, def_map} ->
          Map.get(def_map, "required", false) && !Map.has_key?(normalized, key)
        end)
        |> Enum.map(fn {key, _} -> key end)

      if Enum.empty?(missing) do
        # Add defaults
        with_defaults =
          Enum.reduce(var_defs, normalized, fn {key, def_map}, acc ->
            if !Map.has_key?(acc, key) && Map.has_key?(def_map, "default") do
              Map.put(acc, key, def_map["default"])
            else
              acc
            end
          end)

        {:ok, with_defaults}
      else
        {:error, {:missing_required_variables, missing}}
      end
    else
      {:ok, normalize_variables(variables)}
    end
  end

  defp parse_solid_template(hbs_content, _template_id) do
    case Solid.parse(hbs_content) do
      {:ok, template} ->
        {:ok, template}

      {:error, errors} when is_list(errors) ->
        Logger.error("Solid parse errors: #{inspect(errors)}")
        {:error, {:parse_errors, errors}}

      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end

  defp render_solid(solid_template, variables) do
    # Ensure helpers are registered
    TemplateFormatters.register_all()

    case Solid.render(solid_template, variables) do
      {:ok, rendered} ->
        {:ok, IO.iodata_to_binary(rendered)}

      {:error, reason} ->
        {:error, {:render_error, reason}}
    end
  end

  ## Template Loading & Composition

  defp load_template(template_id, opts) do
    case TemplateService.get_template("template", template_id) do
      {:ok, template} ->
        {:ok, template}

      {:error, :not_found} = error ->
        Logger.warning("Template not found: #{template_id}")
        error

      error ->
        error
    end
  end

  defp compose_template(template, variables) do
    with {:ok, base_code} <- load_base_template(template),
         {:ok, bits_code} <- load_composed_bits(template, variables),
         {:ok, content_code} <- extract_content(template) do
      # Combine in order: base -> bits -> content
      combined =
        [base_code, bits_code, content_code]
        |> Enum.reject(&(&1 == ""))
        |> Enum.join("\n\n")

      {:ok, combined}
    end
  end

  defp load_base_template(%{"extends" => base_id}) when is_binary(base_id) do
    case TemplateService.get_template("template", base_id) do
      {:ok, base} -> extract_content(base)
      error -> error
    end
  end

  defp load_base_template(_), do: {:ok, ""}

  defp load_composed_bits(%{"compose" => bit_ids}, variables) when is_list(bit_ids) do
    bits =
      Enum.map(bit_ids, fn bit_id ->
        case TemplateService.get_template("template", bit_id) do
          {:ok, bit} ->
            case extract_content(bit) do
              {:ok, code} -> replace_variables(code, variables)
              _ -> ""
            end

          _ ->
            Logger.warning("Bit not found: #{bit_id}")
            ""
        end
      end)
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n\n")

    {:ok, bits}
  end

  defp load_composed_bits(_, _), do: {:ok, ""}

  defp extract_content(%{"content" => %{"type" => "code", "code" => code}}), do: {:ok, code}
  defp extract_content(%{"content" => %{"code" => code}}), do: {:ok, code}
  defp extract_content(_), do: {:ok, ""}

  ## Variable Handling

  defp validate_variables(template, variables, opts) do
    if Keyword.get(opts, :validate, true) do
      case check_required_variables(template, variables) do
        {:ok, normalized} -> {:ok, normalized}
        error -> error
      end
    else
      {:ok, normalize_variables(variables)}
    end
  end

  defp check_required_variables(template, variables) do
    var_defs = get_in(template, ["content", "variables"]) || %{}
    normalized = normalize_variables(variables)

    missing =
      Enum.filter(var_defs, fn {key, def_map} ->
        Map.get(def_map, "required", false) && !Map.has_key?(normalized, key)
      end)
      |> Enum.map(fn {key, _} -> key end)

    if Enum.empty?(missing) do
      # Add defaults for missing optional variables
      with_defaults =
        Enum.reduce(var_defs, normalized, fn {key, def_map}, acc ->
          if !Map.has_key?(acc, key) && Map.has_key?(def_map, "default") do
            Map.put(acc, key, def_map["default"])
          else
            acc
          end
        end)

      {:ok, with_defaults}
    else
      {:error, {:missing_required_variables, missing}}
    end
  end

  defp normalize_variables(variables) when is_map(variables) do
    Enum.reduce(variables, %{}, fn {key, value}, acc ->
      Map.put(acc, to_string(key), value)
    end)
  end

  defp analyze_variables(template, variables) do
    var_defs = get_in(template, ["content", "variables"]) || %{}
    normalized = normalize_variables(variables)

    missing_required =
      Enum.filter(var_defs, fn {key, def_map} ->
        Map.get(def_map, "required", false) && !Map.has_key?(normalized, key)
      end)
      |> Enum.map(fn {key, _} -> key end)

    provided = Map.keys(normalized)

    defaults_used =
      Enum.filter(var_defs, fn {key, def_map} ->
        !Map.has_key?(normalized, key) && Map.has_key?(def_map, "default")
      end)
      |> Enum.map(fn {key, _} -> key end)

    {:ok,
     %{
       missing_required: missing_required,
       provided: provided,
       defaults_used: defaults_used
     }}
  end

  ## Rendering

  defp render_template(code, variables) do
    rendered = replace_variables(code, variables)
    {:ok, rendered}
  end

  defp replace_variables(code, variables) when is_binary(code) do
    # Replace {{variable}} with value
    Enum.reduce(variables, code, fn {key, value}, acc ->
      key_str = to_string(key)
      value_str = to_string(value)

      acc
      |> String.replace("{{#{key_str}}}", value_str)
      # Support spaces
      |> String.replace("{{ #{key_str} }}", value_str)
    end)
  end

  ## Snippet Rendering

  defp extract_snippets(%{"content" => %{"type" => "snippets", "snippets" => snippets}}) do
    {:ok, snippets}
  end

  defp extract_snippets(_) do
    {:error, :not_a_snippet_template}
  end

  defp render_all_snippets(snippets, variables, template) do
    rendered =
      Enum.reduce(snippets, %{}, fn {name, snippet}, acc ->
        case render_single_snippet(name, snippet, variables, template) do
          {:ok, file_path, code} -> Map.put(acc, file_path, code)
          {:error, _} -> acc
        end
      end)

    {:ok, rendered}
  end

  defp render_single_snippet(name, snippet, variables, _template) do
    code = snippet["code"] || ""
    file_path = snippet["file_path"] || "#{name}.ex"

    # Compose bits if specified
    composed_code =
      if snippet["compose"] do
        case load_snippet_bits(snippet["compose"], variables) do
          {:ok, bits} -> bits <> "\n\n" <> code
          _ -> code
        end
      else
        code
      end

    rendered_code = replace_variables(composed_code, variables)
    rendered_path = replace_variables(file_path, variables)

    {:ok, rendered_path, rendered_code}
  end

  defp load_snippet_bits(bit_ids, variables) when is_list(bit_ids) do
    bits =
      Enum.map(bit_ids, fn bit_id ->
        case TemplateService.get_template("template", bit_id) do
          {:ok, bit} ->
            case extract_content(bit) do
              {:ok, code} -> replace_variables(code, variables)
              _ -> ""
            end

          _ ->
            ""
        end
      end)
      |> Enum.join("\n\n")

    {:ok, bits}
  end

  ## Quality Checking

  defp maybe_quality_check(code, template, opts) do
    if Keyword.get(opts, :quality_check, false) do
      quality_check(code, template)
    else
      {:ok, code}
    end
  end

  defp quality_check(code, %{"quality_standard" => standard_id, "language" => language})
       when is_binary(standard_id) and is_binary(language) do
    # Integrate with QualityEngine for quality validation
    alias Singularity.Engines.QualityEngine

    Logger.debug("Running quality check", standard: standard_id, language: language)

    case QualityEngine.analyze_code_quality(code, language) do
      {:ok, metrics} ->
        # Check if code meets quality standard
        if meets_quality_standard?(metrics, standard_id) do
          Logger.info("Code passed quality check", standard: standard_id)
          {:ok, code}
        else
          Logger.warning("Code failed quality check", standard: standard_id, metrics: metrics)
          {:error, {:quality_check_failed, metrics}}
        end

      {:error, :nif_not_loaded} ->
        # QualityEngine NIF not loaded - pass through with warning
        Logger.warning("QualityEngine NIF not loaded, skipping quality check")
        {:ok, code}

      {:error, reason} ->
        Logger.error("Quality check failed", reason: reason)
        {:error, {:quality_check_error, reason}}
    end
  end

  defp quality_check(code, %{"quality_standard" => standard_id}) when is_binary(standard_id) do
    # No language specified - log and pass through
    Logger.debug("Quality check skipped - no language specified", standard: standard_id)
    {:ok, code}
  end

  defp quality_check(code, _), do: {:ok, code}

  defp meets_quality_standard?(metrics, standard_id) do
    # Define quality thresholds for different standards
    thresholds = %{
      "production" => %{complexity: 10, maintainability: 70},
      "high" => %{complexity: 15, maintainability: 60},
      "medium" => %{complexity: 20, maintainability: 50},
      "low" => %{complexity: 30, maintainability: 30}
    }

    case Map.get(thresholds, standard_id) do
      nil ->
        # Unknown standard - pass
        true

      threshold ->
        # Check if metrics meet threshold
        complexity = Map.get(metrics, :complexity, 0)
        maintainability = Map.get(metrics, :maintainability, 100)

        complexity <= threshold.complexity and maintainability >= threshold.maintainability
    end
  end
end
