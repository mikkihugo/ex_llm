defmodule Singularity.TechnologyAgent do
  @moduledoc """
  Technology detection orchestrator.
  Delegates to Rust LayeredDetector via Port for performance.
  Falls back to Elixir implementation if Rust unavailable.
  """

  require Logger
  alias Singularity.{PolyglotCodeParser, TechnologyTemplateLoader, Repo}
  alias Singularity.Schemas.CodebaseSnapshot

  @rust_detector_path "rust/target/release/tool-doc-index"

  @doc "Detect all technologies (Rust LayeredDetector with Elixir fallback)"
  def detect_technologies(codebase_path, opts \\ []) do
    Logger.info("Detecting technologies in: #{codebase_path}")

    case call_rust_detector(codebase_path) do
      {:ok, results} ->
        technologies = transform_rust_results(results)

        snapshot =
          build_snapshot(
            codebase_path,
            technologies,
            Keyword.put(opts, :detection_method, :rust_layered)
          )

        maybe_persist_snapshot(snapshot, Keyword.put(opts, :detection_method, :rust_layered))

        {:ok, snapshot}

      {:error, reason} when reason in [:rust_unavailable, :not_found] ->
        Logger.warn("Rust detector unavailable, using Elixir fallback")
        detect_technologies_elixir(codebase_path, opts)

      {:error, reason} ->
        Logger.error("Rust detection failed: #{inspect(reason)}, using fallback")
        detect_technologies_elixir(codebase_path, opts)
    end
  end

  @doc "Elixir fallback implementation"
  def detect_technologies_elixir(codebase_path, opts \\ []) do
    with {:ok, analysis} <- resolve_analysis(codebase_path, opts),
         {:ok, patterns} <- extract_technology_patterns(codebase_path, analysis) do
      snapshot = build_snapshot(codebase_path, patterns, opts)
      maybe_persist_snapshot(snapshot, opts)

      {:ok, snapshot}
    else
      {:error, reason} ->
        Logger.error("Technology detection failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Detect specific technology category"
  def detect_technology_category(codebase_path, category, opts \\ []) do
    Logger.info("Detecting #{category} technologies in: #{codebase_path}")

    with {:ok, analysis} <- resolve_analysis(codebase_path, opts) do
      patterns = extract_category_patterns(analysis, category)
      {:ok, patterns}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Analyze technology patterns in code"
  def analyze_code_patterns(codebase_path, opts \\ []) do
    Logger.info("Analyzing code patterns in: #{codebase_path}")

    with {:ok, analysis} <- resolve_analysis(codebase_path, opts) do
      snapshot = %{
        codebase_path: codebase_path,
        patterns: Map.get(analysis, :patterns, []),
        analysis_timestamp: DateTime.utc_now()
      }

      maybe_persist_snapshot(snapshot, opts)

      snapshot
    else
      {:error, reason} ->
        Logger.error("Code pattern analysis failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  ## Private Functions

  defp resolve_analysis(codebase_path, opts) do
    case Keyword.get(opts, :analysis) do
      %{} = analysis -> {:ok, analysis}
      nil -> PolyglotCodeParser.analyze_codebase(codebase_path)
    end
  end

  defp extract_technology_patterns(codebase_path, analysis) do
    # Extract patterns from polyglot analysis
    technologies = %{
      languages: extract_languages(analysis),
      frameworks: extract_frameworks(codebase_path, analysis),
      databases: extract_databases(codebase_path, analysis),
      messaging: extract_messaging(codebase_path, analysis),
      build_systems: extract_build_systems(analysis),
      monitoring: extract_monitoring(codebase_path, analysis),
      security: extract_security(codebase_path, analysis),
      ai_frameworks: extract_ai_frameworks(codebase_path, analysis),
      deployment: extract_deployment(analysis),
      cloud_platforms: extract_cloud_platforms(codebase_path, analysis),
      architecture_patterns: extract_architecture_patterns(codebase_path, analysis)
    }

    {:ok, technologies}
  end

  defp build_snapshot(codebase_path, technologies, opts) do
    detection_method = opts[:detection_method] || :elixir_fallback
    timestamp = DateTime.utc_now()
    codebase_id = opts[:codebase_id] || codebase_path
    snapshot_id = opts[:snapshot_id] || System.unique_integer([:positive])

    metadata =
      %{
        codebase_path: codebase_path,
        detection_method: detection_method,
        detection_timestamp: timestamp
      }
      |> Map.merge(Map.get(opts, :metadata, %{}))

    summary = technologies
    detected = flatten_technologies(technologies)
    features = build_features(technologies)

    %{
      codebase_path: codebase_path,
      codebase_id: codebase_id,
      snapshot_id: snapshot_id,
      detection_timestamp: timestamp,
      detection_method: detection_method,
      technologies: technologies,
      detected_technologies: detected,
      metadata: metadata,
      summary: summary,
      features: features
    }
  end

  defp maybe_persist_snapshot(%{codebase_id: codebase_id} = snapshot, opts) do
    if Keyword.get(opts, :persist_snapshot, true) do
      # Insert directly using Ecto instead of NATS
      attrs =
        Map.take(snapshot, [
          :codebase_id,
          :snapshot_id,
          :metadata,
          :summary,
          :detected_technologies,
          :features
        ])

      case CodebaseSnapshot.upsert(Repo, attrs) do
        {:ok, _snapshot} ->
          Logger.debug("Persisted technology snapshot to database",
            codebase_id: codebase_id
          )

          :ok

        {:error, changeset} ->
          Logger.warn("Failed to persist snapshot to database",
            codebase_id: codebase_id,
            errors: inspect(changeset.errors)
          )
      end
    end

    :ok
  end

  defp maybe_persist_snapshot(_snapshot, _opts), do: :ok

  defp flatten_technologies(technologies) when is_map(technologies) do
    technologies
    |> Enum.flat_map(fn {category, values} ->
      values
      |> List.wrap()
      |> Enum.map(&normalize_detected_value(category, &1))
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp flatten_technologies(_), do: []

  defp normalize_detected_value(category, value) when is_atom(value) do
    format_detected(category, Atom.to_string(value))
  end

  defp normalize_detected_value(category, value) when is_binary(value) do
    format_detected(category, value)
  end

  defp normalize_detected_value(category, %{} = map) do
    cond do
      Map.has_key?(map, :name) ->
        format_detected(category, map[:name])

      Map.has_key?(map, "name") ->
        format_detected(category, map["name"])

      Map.has_key?(map, :technology_name) ->
        format_detected(category, map[:technology_name])

      Map.has_key?(map, "technology_name") ->
        format_detected(category, map["technology_name"])

      true ->
        map
        |> Map.values()
        |> Enum.find(&is_binary/1)
        |> case do
          nil -> nil
          binary -> format_detected(category, binary)
        end
    end
  end

  defp normalize_detected_value(category, value), do: format_detected(category, to_string(value))

  defp format_detected(category, value) when is_binary(value) do
    category_label =
      case category do
        atom when is_atom(atom) -> Atom.to_string(atom)
        other -> to_string(other)
      end

    String.downcase(category_label) <> ":" <> value
  end

  defp format_detected(_category, _value), do: nil

  defp build_features(technologies) do
    Enum.reduce(technologies, %{}, fn {category, values}, acc ->
      count = values |> List.wrap() |> length()
      Map.put(acc, "#{category}_count", count)
    end)
  end

  defp extract_category_patterns(analysis, category) do
    case category do
      :languages -> extract_languages(analysis)
      :frameworks -> extract_frameworks(nil, analysis)
      :databases -> extract_databases(nil, analysis)
      :messaging -> extract_messaging(nil, analysis)
      :build_systems -> extract_build_systems(analysis)
      :monitoring -> extract_monitoring(nil, analysis)
      :security -> extract_security(nil, analysis)
      :ai_frameworks -> extract_ai_frameworks(nil, analysis)
      :deployment -> extract_deployment(analysis)
      :cloud_platforms -> extract_cloud_platforms(nil, analysis)
      :architecture_patterns -> extract_architecture_patterns(nil, analysis)
      _ -> []
    end
  end

  # Language detection via polyglot parser
  defp extract_languages(analysis) do
    # Parser already identifies languages by AST
    analysis.files
    |> Enum.map(& &1.language)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end

  # Framework detection via templates
  defp extract_frameworks(codebase_path, analysis) do
    framework_keys = [
      {:framework, :nestjs},
      {:framework, :express},
      {:framework, :phoenix},
      {:framework, :fastapi}
    ]

    detect_from_templates(codebase_path, framework_keys, analysis)
  end

  # Database detection via templates
  defp extract_databases(codebase_path, analysis) do
    database_keys = [
      {:database, :postgresql},
      {:database, :timescale},
      {:database, :mongodb},
      {:database, :mysql},
      {:database, :cassandra},
      {:database, :cockroachdb},
      {:database, :sqlite},
      {:database, :redis}
    ]

    detect_from_templates(codebase_path, database_keys, analysis)
  end

  # Messaging detection via templates
  defp extract_messaging(codebase_path, analysis) do
    messaging_keys = [
      {:messaging, :nats},
      {:messaging, :kafka},
      {:messaging, :rabbitmq},
      {:messaging, :redis}
    ]

    detect_from_templates(codebase_path, messaging_keys, analysis)
  end

  # Build system detection via file presence
  defp extract_build_systems(analysis) do
    build_markers = %{
      bazel: ["WORKSPACE", "MODULE.bazel", "BUILD.bazel"],
      nx: ["nx.json"],
      moon: ["moon.yml", "moon.yaml"],
      lerna: ["lerna.json"]
    }

    Enum.filter(build_markers, fn {_system, files} ->
      Enum.any?(files, fn file ->
        Enum.any?(analysis.files, &String.ends_with?(&1.path, file))
      end)
    end)
    |> Enum.map(fn {system, _} -> system end)
  end

  # Monitoring detection via templates
  defp extract_monitoring(codebase_path, analysis) do
    monitoring_keys = [
      {:monitoring, :prometheus},
      {:monitoring, :grafana},
      {:monitoring, :jaeger},
      {:monitoring, :opentelemetry}
    ]

    detect_from_templates(codebase_path, monitoring_keys, analysis)
  end

  # Security detection via templates
  defp extract_security(codebase_path, analysis) do
    security_keys = [
      {:security, :spiffe},
      {:security, :opa},
      {:security, :falco}
    ]

    detect_from_templates(codebase_path, security_keys, analysis)
  end

  # AI framework detection via templates
  defp extract_ai_frameworks(codebase_path, analysis) do
    ai_keys = [
      {:ai, :langchain},
      {:ai, :crewai},
      {:ai, :mcp}
    ]

    detect_from_templates(codebase_path, ai_keys, analysis)
  end

  # Deployment detection via file markers
  defp extract_deployment(analysis) do
    deployment_markers = %{
      kubernetes: ["k8s", "apiVersion:"],
      docker: ["Dockerfile", "docker-compose.yml"],
      helm: ["Chart.yaml", "values.yaml"]
    }

    Enum.filter(deployment_markers, fn {_tech, markers} ->
      Enum.any?(markers, fn marker ->
        Enum.any?(analysis.files, fn file ->
          String.contains?(file.path, marker) or
            (file.content && String.contains?(file.content, marker))
        end)
      end)
    end)
    |> Enum.map(fn {tech, _} -> tech end)
  end

  # Cloud platform detection via templates
  defp extract_cloud_platforms(codebase_path, analysis) do
    cloud_keys = [
      {:cloud, :aws},
      {:cloud, :azure},
      {:cloud, :gcp}
    ]

    detect_from_templates(codebase_path, cloud_keys, analysis)
  end

  # Architecture pattern detection via polyglot analysis
  defp extract_architecture_patterns(_codebase_path, analysis) do
    # Use polyglot parser's architecture detection
    patterns = []

    # Microservices: multiple services in analysis
    patterns = if has_microservices?(analysis), do: [:microservices | patterns], else: patterns

    # Event-driven: GenServer/async patterns
    patterns = if has_event_driven?(analysis), do: [:event_driven | patterns], else: patterns

    # Layered: controller/service/repository structure
    patterns = if has_layered?(analysis), do: [:layered_architecture | patterns], else: patterns

    patterns
  end

  # Core template-based detection
  defp detect_from_templates(codebase_path, template_keys, analysis) do
    template_keys
    |> List.wrap()
    |> Enum.filter(&match_template(codebase_path, &1, analysis))
    |> Enum.map(fn {_category, tech} -> tech end)
  end

  defp match_template(codebase_path, template_key, analysis) do
    template = TechnologyTemplateLoader.template(template_key) || %{}
    signatures = Map.get(template, "detector_signatures", %{})

    pattern_match =
      matches_patterns?(template_key, analysis) or
        matches_patterns?(template_key, analysis, field: :code_patterns) or
        matches_patterns?(template_key, analysis, field: :content_patterns)

    dependency_match = has_any_dependency?(analysis, codebase_path, signatures["dependencies"])
    config_match = has_any_config_file?(signatures["config_files"], analysis)
    file_match = matches_file_patterns?(analysis, codebase_path, signatures["file_patterns"])

    pattern_match or dependency_match or config_match or file_match
  end

  defp matches_patterns?(template_key, analysis, opts \\ []) do
    regexes = TechnologyTemplateLoader.patterns(template_key, opts)

    if regexes == [] do
      false
    else
      analysis
      |> Map.get(:files, [])
      |> Enum.any?(fn file ->
        content = Map.get(file, :content) || Map.get(file, "content") || ""

        Enum.any?(regexes, fn
          %Regex{} = regex ->
            Regex.match?(regex, content)

          pattern when is_binary(pattern) ->
            case Regex.compile(pattern, "i") do
              {:ok, regex} -> Regex.match?(regex, content)
              _ -> false
            end

          _ ->
            false
        end)
      end)
    end
  end

  defp has_any_dependency?(_analysis, _codebase_path, nil), do: false

  defp has_any_dependency?(analysis, codebase_path, dependencies) do
    Enum.any?(List.wrap(dependencies), fn dependency ->
      dependency_in_analysis?(analysis, dependency) or
        dependency_in_filesystem?(codebase_path, dependency)
    end)
  end

  defp dependency_in_analysis?(analysis, dependency) do
    analysis
    |> Map.get(:files, [])
    |> Enum.any?(fn file ->
      content = Map.get(file, :content) || Map.get(file, "content") || ""
      String.contains?(content, dependency)
    end)
  end

  defp dependency_in_filesystem?(nil, _dependency), do: false

  defp dependency_in_filesystem?(codebase_path, dependency) do
    candidates = [
      Path.join(codebase_path, "mix.exs"),
      Path.join(codebase_path, "package.json"),
      Path.join(codebase_path, "pyproject.toml"),
      Path.join(codebase_path, "requirements.txt"),
      Path.join(codebase_path, "Cargo.toml"),
      Path.join(codebase_path, "setup.cfg")
    ]

    Enum.any?(candidates, fn path ->
      File.exists?(path) && contains_dependency?(path, dependency)
    end)
  end

  defp contains_dependency?(path, dependency) do
    case File.read(path) do
      {:ok, content} -> String.contains?(content, dependency)
      _ -> false
    end
  end

  defp has_any_config_file?(nil, _analysis), do: false

  defp has_any_config_file?(config_files, analysis) do
    Enum.any?(List.wrap(config_files), fn config_file ->
      Enum.any?(Map.get(analysis, :files, []), fn file ->
        path = Map.get(file, :path) || Map.get(file, "path") || ""
        String.ends_with?(path, config_file)
      end)
    end)
  end

  defp matches_file_patterns?(_analysis, _codebase_path, nil), do: false

  defp matches_file_patterns?(analysis, codebase_path, patterns) do
    regexes = compile_globs(List.wrap(patterns))

    analysis_match =
      Enum.any?(Map.get(analysis, :files, []), fn file ->
        path = Map.get(file, :path) || Map.get(file, "path") || ""
        Enum.any?(regexes, &Regex.match?(&1, path))
      end)

    filesystem_match =
      if codebase_path do
        Enum.any?(List.wrap(patterns), fn pattern ->
          Path.wildcard(Path.join(codebase_path, pattern)) != []
        end)
      else
        false
      end

    analysis_match or filesystem_match
  end

  defp compile_globs(patterns) do
    Enum.reduce(patterns, [], fn pattern, acc ->
      case glob_to_regex(pattern) do
        {:ok, regex} -> [regex | acc]
        _ -> acc
      end
    end)
  end

  defp glob_to_regex(pattern) when is_binary(pattern) do
    escaped =
      pattern
      |> Regex.escape()
      |> String.replace("\\*\\*", ".*")
      |> String.replace("\\*", "[^/]*")

    Regex.compile("^" <> escaped <> "$", "i")
  end

  defp glob_to_regex(_pattern), do: {:error, :invalid_pattern}

  # Architecture pattern helpers
  defp has_microservices?(analysis) do
    service_count =
      Enum.count(analysis.files, fn file ->
        String.contains?(file.path, "services/") or
          String.contains?(file.path, "microservices/")
      end)

    service_count > 3
  end

  defp has_event_driven?(analysis) do
    Enum.any?(analysis.files, fn file ->
      content = file.content || ""

      String.contains?(content, "GenServer") or
        String.contains?(content, "pub_sub") or
        String.contains?(content, "event_bus")
    end)
  end

  defp has_layered?(analysis) do
    has_controllers = Enum.any?(analysis.files, &String.contains?(&1.path, "controllers/"))
    has_services = Enum.any?(analysis.files, &String.contains?(&1.path, "services/"))
    has_repos = Enum.any?(analysis.files, &String.contains?(&1.path, "repositories/"))

    has_controllers and has_services and has_repos
  end

  ## Rust Detector Integration

  defp call_rust_detector(codebase_path) do
    if File.exists?(@rust_detector_path) do
      case System.cmd(@rust_detector_path, ["detect", codebase_path], stderr_to_stdout: true) do
        {output, 0} ->
          case Jason.decode(output) do
            {:ok, results} -> {:ok, results}
            {:error, _} -> {:error, :json_decode_failed}
          end

        {_output, _code} ->
          {:error, :rust_execution_failed}
      end
    else
      {:error, :rust_unavailable}
    end
  rescue
    e -> {:error, {:exception, Exception.message(e)}}
  end

  defp transform_rust_results(results) when is_list(results) do
    Enum.group_by(results, fn result ->
      Map.get(result, "category", "other")
    end)
    |> Enum.into(%{}, fn {category, items} ->
      {String.to_atom(category), Enum.map(items, &transform_result_item/1)}
    end)
  end

  defp transform_rust_results(_), do: %{}

  defp transform_result_item(item) do
    %{
      name: Map.get(item, "technology_name"),
      confidence: Map.get(item, "confidence"),
      evidence: Map.get(item, "evidence", [])
    }
  end
end
