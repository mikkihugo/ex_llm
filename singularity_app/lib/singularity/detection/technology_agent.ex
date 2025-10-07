defmodule Singularity.TechnologyAgent do
  @moduledoc """
  Technology detection orchestrator.

  Delegates to Rust tech_detector library (via package_registry_indexer) for performance.
  Falls back to Elixir implementation if Rust unavailable.

  **Architecture:**
  - Elixir → NATS → package_registry_indexer → tech_detector (Rust library)
  """

  require Logger
  alias Singularity.{PolyglotCodeParser, TechnologyTemplateLoader, Repo}
  alias Singularity.Schemas.TechnologyDetection

  @rust_detector_path "rust/target/release/package-registry-indexer"

  @doc "Detect all technologies (Rust tech_detector with Elixir fallback)"
  def detect_technologies(codebase_path, opts \\ []) do
    Logger.info("Detecting technologies in: #{codebase_path}")

    case call_rust_detector(codebase_path) do
      {:ok, results} ->
        technologies = transform_rust_results(results)

        snapshot =
          build_snapshot(
            codebase_path,
            technologies,
            Keyword.put(opts, :detection_method, :rust_tech_detector)
          )

        maybe_persist_snapshot(
          snapshot,
          Keyword.put(opts, :detection_method, :rust_tech_detector)
        )

        {:ok, snapshot}

      {:error, reason} when reason in [:rust_unavailable, :not_found] ->
        Logger.warning("Rust detector unavailable, using Elixir fallback")
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
      architecture_patterns: extract_architecture_patterns(codebase_path, analysis),
      service_structure: extract_service_structure(codebase_path, analysis)
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

    # Extract service_structure separately (not part of flat summary)
    service_structure = Map.get(technologies, :service_structure, %{})
    technologies_without_services = Map.delete(technologies, :service_structure)

    summary = technologies_without_services
    detected = flatten_technologies(technologies_without_services)
    capabilities = build_capabilities(technologies_without_services)

    %{
      codebase_path: codebase_path,
      codebase_id: codebase_id,
      snapshot_id: snapshot_id,
      detection_timestamp: timestamp,
      detection_method: detection_method,
      technologies: technologies_without_services,
      detected_technologies: detected,
      metadata: metadata,
      summary: summary,
      capabilities: capabilities,
      service_structure: service_structure
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
          :capabilities,
          :service_structure
        ])

      case TechnologyDetection.upsert(Repo, attrs) do
        {:ok, _detection} ->
          Logger.debug("Persisted technology detection to database",
            codebase_id: codebase_id
          )

          :ok

        {:error, changeset} ->
          Logger.warning("Failed to persist detection to database",
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
      case values do
        list when is_list(list) ->
          Enum.map(list, fn value ->
            %{
              category: category,
              value: value,
              formatted: format_detected(category, value)
            }
          end)
        
        value ->
          [%{
            category: category,
            value: value,
            formatted: format_detected(category, value)
          }]
      end
    end)
    |> Enum.reject(fn tech -> is_nil(tech.value) or tech.value == "" end)
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
    case category do
      :framework -> format_framework(value)
      :language -> format_language(value)
      :database -> format_database(value)
      :tool -> format_tool(value)
      :service -> format_service(value)
      _ -> value
    end
  end

  defp format_detected(category, value) when is_list(value) do
    value
    |> Enum.map(&format_detected(category, &1))
    |> Enum.reject(&is_nil/1)
  end

  defp format_detected(_category, value), do: value

  defp format_framework(framework) do
    case String.downcase(framework) do
      "phoenix" -> "Phoenix Framework"
      "ecto" -> "Ecto ORM"
      "absinthe" -> "Absinthe GraphQL"
      "liveview" -> "Phoenix LiveView"
      "nats" -> "NATS Messaging"
      "rabbitmq" -> "RabbitMQ"
      "redis" -> "Redis"
      _ -> String.capitalize(framework)
    end
  end

  defp format_language(language) do
    case String.downcase(language) do
      "elixir" -> "Elixir"
      "gleam" -> "Gleam"
      "erlang" -> "Erlang"
      "javascript" -> "JavaScript"
      "typescript" -> "TypeScript"
      "rust" -> "Rust"
      "python" -> "Python"
      _ -> String.capitalize(language)
    end
  end

  defp format_database(database) do
    case String.downcase(database) do
      "postgresql" -> "PostgreSQL"
      "postgres" -> "PostgreSQL"
      "mysql" -> "MySQL"
      "sqlite" -> "SQLite"
      "mongodb" -> "MongoDB"
      _ -> String.capitalize(database)
    end
  end

  defp format_tool(tool) do
    case String.downcase(tool) do
      "mix" -> "Mix Build Tool"
      "hex" -> "Hex Package Manager"
      "rebar3" -> "Rebar3 Build Tool"
      "npm" -> "npm Package Manager"
      "yarn" -> "Yarn Package Manager"
      "cargo" -> "Cargo Package Manager"
      _ -> String.capitalize(tool)
    end
  end

  defp format_service(service) do
    case String.downcase(service) do
      "nats-server" -> "NATS Server"
      "postgres" -> "PostgreSQL Service"
      "redis-server" -> "Redis Server"
      _ -> String.capitalize(service)
    end
  end

  defp build_capabilities(technologies) do
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
  defp extract_architecture_patterns(codebase_path, analysis) do
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

  defp extract_service_structure(codebase_path, analysis) do
    # Extract service structure information from analysis
    %{
      service_count: analysis[:service_count] || 0,
      service_types: analysis[:service_types] || [],
      communication_patterns: analysis[:communication_patterns] || [],
      data_flow: analysis[:data_flow] || []
    }
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

  defp has_typescript_service?(_codebase_path, analysis) do
    package_json_exists =
      analysis.files
      |> Enum.any?(&String.ends_with?(&1.path, "package.json"))

    nestjs_imports =
      analysis.files
      |> Enum.any?(fn file ->
        content = file.content || ""
        String.contains?(content, "@nestjs/") or String.contains?(content, "NestFactory")
      end)

    package_json_exists and nestjs_imports
  end

  defp has_rust_service?(_codebase_path, analysis) do
    Enum.any?(analysis.files, &String.ends_with?(&1.path, "Cargo.toml"))
  end

  defp has_python_service?(_codebase_path, analysis) do
    python_files = Enum.any?(analysis.files, &String.ends_with?(&1.path, ".py"))

    fastapi_imports =
      Enum.any?(analysis.files, fn file ->
        content = file.content || ""
        String.contains?(content, "from fastapi import") or String.contains?(content, "FastAPI()")
      end)

    python_files and fastapi_imports
  end

  defp has_go_service?(_codebase_path, analysis) do
    Enum.any?(analysis.files, &String.ends_with?(&1.path, "go.mod"))
  end

  defp analyze_typescript_services(_codebase_path, analysis) do
    ts_files =
      analysis.files
      |> Enum.filter(&String.ends_with?(&1.path, ".ts"))
      |> length()

    %{
      type: :nestjs,
      file_count: ts_files,
      has_tests: has_test_files?(analysis, ".spec.ts"),
      completion_estimate: estimate_completion(ts_files, analysis)
    }
  end

  defp analyze_rust_services(_codebase_path, analysis) do
    rs_files =
      analysis.files
      |> Enum.filter(&String.ends_with?(&1.path, ".rs"))
      |> length()

    %{
      type: :rust,
      file_count: rs_files,
      has_tests: has_test_files?(analysis, "_test.rs") or has_cargo_test?(analysis),
      completion_estimate: estimate_completion(rs_files, analysis)
    }
  end

  defp analyze_python_services(_codebase_path, analysis) do
    py_files =
      analysis.files
      |> Enum.filter(&String.ends_with?(&1.path, ".py"))
      |> length()

    %{
      type: :fastapi,
      file_count: py_files,
      has_tests: has_test_files?(analysis, "test_"),
      completion_estimate: estimate_completion(py_files, analysis)
    }
  end

  defp analyze_go_services(_codebase_path, analysis) do
    go_files =
      analysis.files
      |> Enum.filter(&String.ends_with?(&1.path, ".go"))
      |> length()

    %{
      type: :go_service,
      file_count: go_files,
      has_tests: has_test_files?(analysis, "_test.go"),
      completion_estimate: estimate_completion(go_files, analysis)
    }
  end

  defp has_test_files?(analysis, pattern) do
    Enum.any?(analysis.files, &String.contains?(&1.path, pattern))
  end

  defp has_cargo_test?(analysis) do
    Enum.any?(analysis.files, fn file ->
      content = file.content || ""
      String.contains?(content, "#[test]") or String.contains?(content, "#[cfg(test)]")
    end)
  end

  defp estimate_completion(file_count, analysis) do
    # Simple heuristic: more files = more complete
    # Presence of tests adds 20%
    # Presence of docs adds 10%
    base = min(file_count * 5, 70)

    has_tests =
      Enum.any?(analysis.files, &String.contains?(&1.path, "test"))

    has_docs =
      Enum.any?(
        analysis.files,
        &(String.ends_with?(&1.path, ".md") or String.ends_with?(&1.path, "README"))
      )

    base + if(has_tests, do: 20, else: 0) + if has_docs, do: 10, else: 0
  end

  ## Rust Detector Integration

  defp call_rust_detector(codebase_path) do
    if File.exists?(@rust_detector_path) do
      # Use Runner for Rust detector execution
      case Singularity.Runner.execute_task(%{
        type: :tool,
        args: %{
          tool: "rust_detector",
          command: @rust_detector_path,
          args: ["detect", codebase_path]
        }
      }) do
        {:ok, result} ->
          case result.result do
            %{output: output, exit_code: 0} ->
              case Jason.decode(output) do
                {:ok, results} -> {:ok, results}
                {:error, _} -> {:error, :json_decode_failed}
              end
            %{output: output, exit_code: _} ->
              Logger.error("Rust detector failed: #{output}")
              {:error, :detector_failed}
            _ ->
              {:error, :no_output}
          end
        {:error, reason} ->
          Logger.error("Runner execution failed: #{inspect(reason)}")
          {:error, reason}
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
