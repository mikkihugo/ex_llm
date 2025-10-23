defmodule Singularity.ArchitectureEngine.MetaRegistry.NatsSubscriptionRouter do
  @moduledoc """
  NATS message handlers for the meta-registry system.

  Listens on both application-facing subjects (clean names) and the
  "meta." prefixed subjects we use internally for learning.
  """

  use GenServer

  require Logger

  alias Singularity.MetaRegistry.QuerySystem
  alias Singularity.MetaRegistry.NatsSubjects

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, gnat} =
      Gnat.start_link(%{
        host: System.get_env("NATS_HOST", "127.0.0.1"),
        port: String.to_integer(System.get_env("NATS_PORT", "4222"))
      })

    # App-facing subjects
    {:ok, _sid} = Gnat.sub(gnat, self(), NatsSubjects.naming_suggestions())
    {:ok, _sid} = Gnat.sub(gnat, self(), NatsSubjects.architecture_patterns())
    {:ok, _sid} = Gnat.sub(gnat, self(), NatsSubjects.quality_checks())
    {:ok, _sid} = Gnat.sub(gnat, self(), NatsSubjects.dependencies_analysis())
    {:ok, _sid} = Gnat.sub(gnat, self(), NatsSubjects.patterns_suggestions())
    {:ok, _sid} = Gnat.sub(gnat, self(), NatsSubjects.templates_suggestions())
    {:ok, _sid} = Gnat.sub(gnat, self(), NatsSubjects.refactoring_suggestions())

    # Internal learning subjects
    {:ok, _sid} = Gnat.sub(gnat, self(), NatsSubjects.meta_registry_naming())
    {:ok, _sid} = Gnat.sub(gnat, self(), NatsSubjects.meta_registry_architecture())
    {:ok, _sid} = Gnat.sub(gnat, self(), NatsSubjects.meta_registry_quality())
    {:ok, _sid} = Gnat.sub(gnat, self(), NatsSubjects.meta_registry_dependencies())
    {:ok, _sid} = Gnat.sub(gnat, self(), NatsSubjects.meta_registry_patterns())
    {:ok, _sid} = Gnat.sub(gnat, self(), NatsSubjects.meta_registry_templates())
    {:ok, _sid} = Gnat.sub(gnat, self(), NatsSubjects.meta_registry_refactoring())

    Logger.info("Meta-Registry NatsSubscriptionRouter listening on NATS subjects")

    {:ok, %{gnat: gnat}}
  end

  @impl true
  def handle_info({:msg, %{topic: topic, body: body, reply_to: reply_to}}, state) do
    Task.async(fn -> handle_nats_message(topic, body, reply_to, state.gnat) end)
    {:noreply, state}
  end

  defp handle_nats_message(topic, body, reply_to, gnat) do
    case Jason.decode(body) do
      {:ok, payload} ->
        payload
        |> route_message(topic)
        |> Jason.encode!()
        |> then(&Gnat.pub(gnat, reply_to, &1))

      {:error, _error} ->
        %{error: "Invalid JSON payload"}
        |> Jason.encode!()
        |> then(&Gnat.pub(gnat, reply_to, &1))
    end
  rescue
    error ->
      Logger.error("Error handling message on #{topic}: #{inspect(error)}")

      %{error: "Internal server error"}
      |> Jason.encode!()
      |> then(&Gnat.pub(gnat, reply_to, &1))
  end

  defp route_message(payload, topic) do
    case topic do
      "analysis.meta.naming.suggestions" -> handle_naming_request(payload)
      "analysis.meta.architecture.patterns" -> handle_architecture_request(payload)
      "analysis.meta.quality.checks" -> handle_quality_request(payload)
      "analysis.meta.dependencies.analysis" -> handle_dependencies_request(payload)
      "analysis.meta.patterns.suggestions" -> handle_patterns_request(payload)
      "analysis.meta.templates.suggestions" -> handle_templates_request(payload)
      "analysis.meta.refactoring.suggestions" -> handle_refactoring_request(payload)
      "analysis.meta.registry.naming" -> handle_meta_naming_request(payload)
      "analysis.meta.registry.architecture" -> handle_meta_architecture_request(payload)
      "analysis.meta.registry.quality" -> handle_meta_quality_request(payload)
      "analysis.meta.registry.dependencies" -> handle_meta_dependencies_request(payload)
      "analysis.meta.registry.patterns" -> handle_meta_patterns_request(payload)
      "analysis.meta.registry.templates" -> handle_meta_templates_request(payload)
      "analysis.meta.registry.refactoring" -> handle_meta_refactoring_request(payload)
      _ -> {:error, %{error: "Unknown topic: #{topic}"}}
    end
  end

  @doc """
  Handle naming suggestions for application requests.
  """
  def handle_naming_request(payload) do
    with {:ok, attrs} <- normalize_payload(payload, [:codebase_id, :context, :description]) do
      codebase_id = attrs.codebase_id
      context = attrs.context
      description = attrs.description

      suggestions =
        QuerySystem.query_naming_suggestions(codebase_id, context)
        |> fallback_if_empty(fn -> generate_default_naming_suggestions(description, context) end)

      QuerySystem.track_usage(:naming, codebase_id, context, true)

      {:ok, build_response(codebase_id, context, suggestions)}
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Handle architecture pattern suggestions for application requests.
  """
  def handle_architecture_request(payload) do
    with {:ok, attrs} <- normalize_payload(payload, [:codebase_id, :context, :description]) do
      codebase_id = attrs.codebase_id
      context = attrs.context
      description = attrs.description

      suggestions =
        QuerySystem.query_architecture_suggestions(codebase_id, context)
        |> fallback_if_empty(fn ->
          generate_default_architecture_suggestions(description, context)
        end)

      QuerySystem.track_usage(:architecture, codebase_id, context, true)

      {:ok, build_response(codebase_id, context, suggestions)}
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Handle quality requests for application callers.
  """
  def handle_quality_request(payload) do
    with {:ok, attrs} <- normalize_payload(payload, [:codebase_id, :context, :description]) do
      codebase_id = attrs.codebase_id
      context = attrs.context
      description = attrs.description

      suggestions =
        QuerySystem.query_quality_suggestions(codebase_id, context)
        |> fallback_if_empty(fn -> generate_default_quality_suggestions(description, context) end)

      QuerySystem.track_usage(:quality, codebase_id, context, true)

      {:ok, build_response(codebase_id, context, suggestions)}
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Provide dependency analysis suggestions.
  """
  def handle_dependencies_request(payload) do
    with {:ok, attrs} <- normalize_payload(payload, [:codebase_id], [:context, :description]) do
      codebase_id = attrs.codebase_id
      context = Map.get(attrs, :context, "dependency")
      description = Map.get(attrs, :description, context)

      suggestions =
        QuerySystem.query_architecture_suggestions(codebase_id, context)
        |> fallback_if_empty(fn ->
          generate_default_dependency_suggestions(description, context)
        end)

      QuerySystem.track_usage(:dependencies, codebase_id, context, true)

      {:ok, build_response(codebase_id, context, suggestions)}
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Provide pattern suggestions (framework or domain patterns).
  """
  def handle_patterns_request(payload) do
    with {:ok, attrs} <-
           normalize_payload(payload, [:codebase_id], [:context, :category, :description]) do
      codebase_id = attrs.codebase_id
      context = Map.get(attrs, :context) || Map.get(attrs, :category, "pattern")
      description = Map.get(attrs, :description, context)

      suggestions =
        QuerySystem.query_architecture_suggestions(codebase_id, context)
        |> fallback_if_empty(fn -> generate_default_pattern_suggestions(description, context) end)

      QuerySystem.track_usage(:patterns, codebase_id, context, true)

      {:ok, build_response(codebase_id, context, suggestions)}
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Provide template suggestions (naming/layout guidance).
  """
  def handle_templates_request(payload) do
    with {:ok, attrs} <- normalize_payload(payload, [:codebase_id], [:context, :description]) do
      codebase_id = attrs.codebase_id
      context = Map.get(attrs, :context, "template")
      description = Map.get(attrs, :description, context)

      suggestions =
        QuerySystem.query_naming_suggestions(codebase_id, context)
        |> fallback_if_empty(fn ->
          generate_default_template_suggestions(description, context)
        end)

      QuerySystem.track_usage(:templates, codebase_id, context, true)

      {:ok, build_response(codebase_id, context, suggestions)}
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Provide refactoring suggestions.
  """
  def handle_refactoring_request(payload) do
    with {:ok, attrs} <- normalize_payload(payload, [:codebase_id], [:context, :description]) do
      codebase_id = attrs.codebase_id
      context = Map.get(attrs, :context, "refactoring")
      description = Map.get(attrs, :description, context)

      suggestions =
        QuerySystem.query_quality_suggestions(codebase_id, context)
        |> fallback_if_empty(fn ->
          generate_default_refactoring_suggestions(description, context)
        end)

      QuerySystem.track_usage(:refactoring, codebase_id, context, true)

      {:ok, build_response(codebase_id, context, suggestions)}
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Handle internal naming learning events.
  """
  def handle_meta_naming_request(payload) do
    with {:ok, attrs} <-
           normalize_payload(payload, [:codebase_id, :language, :framework, :patterns]) do
      learning_attrs = %{
        codebase_id: attrs.codebase_id,
        language: attrs.language,
        framework: attrs.framework,
        patterns: List.wrap(attrs.patterns)
      }

      handle_meta_learning(:naming, learning_attrs)
      |> learning_response()
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Handle internal architecture learning events.
  """
  def handle_meta_architecture_request(payload) do
    with {:ok, attrs} <- normalize_payload(payload, [:codebase_id, :patterns], [:services]) do
      patterns = List.wrap(attrs.patterns)
      services = attrs |> Map.get(:services, patterns) |> List.wrap()

      learning_attrs = %{
        codebase_id: attrs.codebase_id,
        patterns: patterns,
        services: services
      }

      handle_meta_learning(:architecture, learning_attrs)
      |> learning_response()
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Handle internal quality learning events.
  """
  def handle_meta_quality_request(payload) do
    with {:ok, attrs} <- normalize_payload(payload, [:codebase_id, :patterns], [:metrics]) do
      learning_attrs = %{
        codebase_id: attrs.codebase_id,
        patterns: List.wrap(attrs.patterns),
        metrics: Map.get(attrs, :metrics, %{})
      }

      handle_meta_learning(:quality, learning_attrs)
      |> learning_response()
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Handle internal dependency learning events.
  """
  def handle_meta_dependencies_request(payload) do
    with {:ok, attrs} <-
           normalize_payload(payload, [:codebase_id], [:patterns, :dependencies, :services]) do
      patterns = attrs |> Map.get(:patterns) || Map.get(attrs, :dependencies, [])
      services = attrs |> Map.get(:services, patterns)

      learning_attrs = %{
        codebase_id: attrs.codebase_id,
        patterns: List.wrap(patterns),
        services: List.wrap(services)
      }

      handle_meta_learning(:architecture, learning_attrs)
      |> learning_response()
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Handle internal pattern learning events (generic patterns).
  """
  def handle_meta_patterns_request(payload) do
    with {:ok, attrs} <- normalize_payload(payload, [:codebase_id, :patterns], [:services]) do
      learning_attrs = %{
        codebase_id: attrs.codebase_id,
        patterns: List.wrap(attrs.patterns),
        services: attrs |> Map.get(:services, attrs.patterns) |> List.wrap()
      }

      handle_meta_learning(:architecture, learning_attrs)
      |> learning_response()
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Handle internal template learning events.
  """
  def handle_meta_templates_request(payload) do
    with {:ok, attrs} <-
           normalize_payload(payload, [:codebase_id], [
             :patterns,
             :templates,
             :language,
             :framework
           ]) do
      patterns = attrs |> Map.get(:templates) || Map.get(attrs, :patterns, [])
      language = Map.get(attrs, :language, "generic")
      framework = Map.get(attrs, :framework, "templates")

      learning_attrs = %{
        codebase_id: attrs.codebase_id,
        language: language,
        framework: framework,
        patterns: List.wrap(patterns)
      }

      handle_meta_learning(:naming, learning_attrs)
      |> learning_response()
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Handle internal refactoring learning events.
  """
  def handle_meta_refactoring_request(payload) do
    with {:ok, attrs} <- normalize_payload(payload, [:codebase_id, :patterns], [:metrics]) do
      learning_attrs = %{
        codebase_id: attrs.codebase_id,
        patterns: List.wrap(attrs.patterns),
        metrics: Map.get(attrs, :metrics, %{})
      }

      handle_meta_learning(:quality, learning_attrs)
      |> learning_response()
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Internal helper used by meta.* handlers to store patterns.
  """
  def handle_meta_learning(:naming, attrs) do
    QuerySystem.learn_naming_patterns(attrs.codebase_id, attrs)
  end

  def handle_meta_learning(:architecture, attrs) do
    QuerySystem.learn_architecture_patterns(attrs.codebase_id, attrs)
  end

  def handle_meta_learning(:quality, attrs) do
    QuerySystem.learn_quality_patterns(attrs.codebase_id, attrs)
  end

  def handle_meta_learning(category, _attrs) do
    {:error, {:unknown_category, category}}
  end

  # ---------------------------------------------------------------------------
  # Default suggestion helpers
  # ---------------------------------------------------------------------------

  defp generate_default_naming_suggestions(description, context) do
    base = base_name(description, context)

    case String.downcase(context || "") do
      "controller" -> ["#{base}Controller", "#{base}ManagementController"]
      "model" -> ["#{base}Model", base]
      "service" -> ["#{base}Service", "#{base}Manager"]
      "repository" -> ["#{base}Repository", "#{base}Repo"]
      _ -> [base, "#{base}Handler"]
    end
  end

  defp generate_default_architecture_suggestions(description, context) do
    base = base_name(description, context)
    slug = base_slug(description, context)

    case String.downcase(context || "") do
      "service" -> ["#{slug}-service", "#{slug}-api"]
      "gateway" -> ["#{slug}-gateway", "#{slug}-proxy"]
      "worker" -> ["#{slug}-worker", "#{slug}-processor"]
      _ -> ["#{slug}-component", "#{slug}-module"]
    end
  end

  defp generate_default_quality_suggestions(_description, context) do
    case String.downcase(context || "") do
      "testing" -> ["test-driven", "unit-tests", "integration-tests"]
      "documentation" -> ["documented", "api-docs", "readme"]
      "type-safety" -> ["type-safe", "strict-types", "type-checking"]
      _ -> ["clean-code", "best-practices", "maintainable"]
    end
  end

  defp generate_default_dependency_suggestions(description, context) do
    slug = base_slug(description, context)
    ["#{slug}_service", "#{slug}_client", "#{slug}_adapter"]
  end

  defp generate_default_pattern_suggestions(description, context) do
    slug = base_slug(description, context)
    ["#{slug}_pattern", "#{slug}_builder", "#{slug}_strategy"]
  end

  defp generate_default_template_suggestions(description, context) do
    slug = base_slug(description, context)
    ["#{slug}_template", "#{slug}_layout", "#{slug}_snippet"]
  end

  defp generate_default_refactoring_suggestions(description, context) do
    slug = base_slug(description, context)
    ["extract_#{slug}_module", "simplify_#{slug}_logic", "document_#{slug}"]
  end

  defp base_name(description, context) do
    source =
      cond do
        is_binary(description) and String.trim(description) != "" -> description
        is_binary(context) and String.trim(context) != "" -> context
        true -> "Suggestion"
      end

    extract_base_name(source)
  end

  defp base_slug(description, context) do
    base_name(description, context)
    |> Macro.underscore()
  end

  defp extract_base_name(description) when is_binary(description) do
    description
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/, "")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join("")
    |> case do
      "" -> "Suggestion"
      value -> value
    end
  end

  defp extract_base_name(_), do: "Suggestion"

  # ---------------------------------------------------------------------------
  # Utility helpers
  # ---------------------------------------------------------------------------

  defp normalize_payload(payload, required_keys, optional_keys \\ []) when is_map(payload) do
    keys = required_keys ++ optional_keys

    normalized =
      Enum.reduce(keys, %{}, fn key, acc ->
        value = Map.get(payload, key) || Map.get(payload, Atom.to_string(key))

        if value == nil do
          acc
        else
          Map.put(acc, key, value)
        end
      end)

    case Enum.find(required_keys, fn key -> not Map.has_key?(normalized, key) end) do
      nil -> {:ok, normalized}
      missing -> {:error, {:missing_key, missing}}
    end
  end

  defp normalize_payload(_payload, _required, _optional), do: {:error, :invalid_payload}

  defp fallback_if_empty(nil, fallback_fun), do: fallback_fun.()
  defp fallback_if_empty([], fallback_fun), do: fallback_fun.()
  defp fallback_if_empty(list, _fallback_fun), do: list

  defp build_response(codebase_id, context, suggestions, extra \\ %{}) do
    %{
      suggestions: List.wrap(suggestions),
      source: "meta_registry",
      codebase_id: codebase_id,
      context: context
    }
    |> Map.merge(extra)
  end

  defp learning_response({:error, reason}), do: {:error, format_error(reason)}
  defp learning_response(_), do: {:ok, %{status: "learning_recorded"}}

  defp format_error({:missing_key, key}), do: %{error: "Missing required key: #{key}"}

  defp format_error({:unknown_category, category}),
    do: %{error: "Unknown learning category: #{inspect(category)}"}

  defp format_error(:invalid_payload), do: %{error: "Invalid payload"}
  defp format_error(reason), do: %{error: inspect(reason)}
end
