defmodule Singularity.TechnologyDetector do
  @moduledoc """
  Advanced technology detection for codebase analysis.
  Detects technologies by analyzing code patterns, not just file names.
  """

  require Logger

  @doc "Detect all technologies in a codebase"
  def detect_technologies(codebase_path) do
    Logger.info("Detecting technologies in: #{codebase_path}")
    
    with {:ok, technologies} <- perform_technology_detection(codebase_path) do
      %{
        codebase_path: codebase_path,
        technologies: technologies,
        detection_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Technology detection failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Detect specific technology category"
  def detect_technology_category(codebase_path, category) do
    Logger.info("Detecting #{category} technologies in: #{codebase_path}")
    
    case category do
      :messaging -> detect_messaging_technologies(codebase_path)
      :databases -> detect_database_technologies(codebase_path)
      :build_systems -> detect_build_systems(codebase_path)
      :frameworks -> detect_frameworks(codebase_path)
      :languages -> detect_languages(codebase_path)
      :monitoring -> detect_monitoring_technologies(codebase_path)
      :security -> detect_security_technologies(codebase_path)
      :ai_frameworks -> detect_ai_frameworks(codebase_path)
      :deployment -> detect_deployment_technologies(codebase_path)
      _ -> {:error, :unsupported_category}
    end
  end

  @doc "Analyze technology patterns in code"
  def analyze_code_patterns(codebase_path) do
    Logger.info("Analyzing code patterns in: #{codebase_path}")
    
    with {:ok, patterns} <- scan_code_patterns(codebase_path) do
      %{
        codebase_path: codebase_path,
        patterns: patterns,
        analysis_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Code pattern analysis failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  ## Private Functions

  defp perform_technology_detection(codebase_path) do
    # Advanced technology detection with confidence scoring
    technologies = %{
      languages: detect_languages_with_confidence(codebase_path),
      frameworks: detect_frameworks_with_confidence(codebase_path),
      databases: detect_database_technologies_with_confidence(codebase_path),
      messaging: detect_messaging_technologies_with_confidence(codebase_path),
      build_systems: detect_build_systems_with_confidence(codebase_path),
      monitoring: detect_monitoring_technologies_with_confidence(codebase_path),
      security: detect_security_technologies_with_confidence(codebase_path),
      ai_frameworks: detect_ai_frameworks_with_confidence(codebase_path),
      deployment: detect_deployment_technologies_with_confidence(codebase_path),
      cloud_platforms: detect_cloud_platforms_with_confidence(codebase_path),
      architecture_patterns: detect_architecture_patterns_with_confidence(codebase_path),
      # Dynamic discovery capabilities
      discovered_technologies: Singularity.AdvancedAnalyzer.discover_unknown_technologies(codebase_path),
      import_patterns: Singularity.AdvancedAnalyzer.analyze_import_patterns(codebase_path),
      api_patterns: Singularity.AdvancedAnalyzer.discover_api_patterns(codebase_path),
      data_patterns: Singularity.AdvancedAnalyzer.discover_data_patterns(codebase_path),
      workflow_patterns: Singularity.AdvancedAnalyzer.discover_workflow_patterns(codebase_path)
    }
    
    {:ok, technologies}
  end

  defp detect_languages(codebase_path) do
    languages = []
    
    # Detect by file extensions and patterns
    languages = detect_by_file_extensions(codebase_path, languages)
    
    # Detect by configuration files
    languages = detect_by_config_files(codebase_path, languages)
    
    # Detect by code patterns
    languages = detect_by_code_patterns(codebase_path, languages)
    
    languages
  end

  defp detect_by_file_extensions(codebase_path, languages) do
    extensions = %{
      ".ts" => :typescript,
      ".tsx" => :typescript,
      ".js" => :javascript,
      ".jsx" => :javascript,
      ".rs" => :rust,
      ".py" => :python,
      ".go" => :go,
      ".ex" => :elixir,
      ".exs" => :elixir,
      ".erl" => :erlang,
      ".hrl" => :erlang,
      ".gleam" => :gleam,
      ".java" => :java,
      ".kt" => :kotlin,
      ".scala" => :scala,
      ".clj" => :clojure,
      ".hs" => :haskell,
      ".ml" => :ocaml,
      ".fs" => :fsharp,
      ".cs" => :csharp,
      ".cpp" => :cpp,
      ".c" => :c,
      ".php" => :php,
      ".rb" => :ruby,
      ".swift" => :swift,
      ".dart" => :dart
    }
    
    detected_languages = Enum.reduce(extensions, [], fn {ext, lang}, acc ->
      if has_files_with_extension?(codebase_path, ext) do
        [lang | acc]
      else
        acc
      end
    end)
    
    languages ++ detected_languages
  end

  defp detect_by_config_files(codebase_path, languages) do
    config_files = %{
      "package.json" => :javascript,
      "tsconfig.json" => :typescript,
      "Cargo.toml" => :rust,
      "requirements.txt" => :python,
      "go.mod" => :go,
      "mix.exs" => :elixir,
      "rebar.config" => :erlang,
      "gleam.toml" => :gleam,
      "pom.xml" => :java,
      "build.gradle" => :java,
      "composer.json" => :php,
      "Gemfile" => :ruby,
      "Podfile" => :swift,
      "pubspec.yaml" => :dart
    }
    
    detected_languages = Enum.reduce(config_files, [], fn {file, lang}, acc ->
      if File.exists?(Path.join(codebase_path, file)) do
        [lang | acc]
      else
        acc
      end
    end)
    
    languages ++ detected_languages
  end

  defp detect_by_code_patterns(codebase_path, languages) do
    # Scan source files for language-specific patterns
    source_files = find_source_files(codebase_path)
    
    patterns = %{
      :elixir => [
        ~r/defmodule\s+\w+/,
        ~r/def\s+\w+/,
        ~r/use\s+\w+/,
        ~r/GenServer/
      ],
      :erlang => [
        ~r/-module\(\w+\)/,
        ~r/-export\(\[/,
        ~r/gen_server/,
        ~r/supervisor/
      ],
      :rust => [
        ~r/fn\s+\w+/,
        ~r/struct\s+\w+/,
        ~r/impl\s+\w+/,
        ~r/use\s+\w+::/
      ],
      :python => [
        ~r/def\s+\w+/,
        ~r/class\s+\w+/,
        ~r/import\s+\w+/,
        ~r/from\s+\w+\s+import/
      ],
      :go => [
        ~r/func\s+\w+/,
        ~r/type\s+\w+/,
        ~r/package\s+\w+/,
        ~r/import\s+\(/
      ],
      :typescript => [
        ~r/interface\s+\w+/,
        ~r/type\s+\w+/,
        ~r/class\s+\w+/,
        ~r/export\s+/
      ]
    }
    
    detected_languages = Enum.reduce(patterns, [], fn {lang, lang_patterns}, acc ->
      if matches_patterns?(source_files, lang_patterns) do
        [lang | acc]
      else
        acc
      end
    end)
    
    languages ++ detected_languages
  end

  defp detect_messaging_technologies(codebase_path) do
    messaging_techs = []
    
    # NATS detection
    messaging_techs = if detect_nats_patterns(codebase_path) do
      [:nats | messaging_techs]
    else
      messaging_techs
    end
    
    # Kafka detection
    messaging_techs = if detect_kafka_patterns(codebase_path) do
      [:kafka | messaging_techs]
    else
      messaging_techs
    end
    
    # Redis detection
    messaging_techs = if detect_redis_patterns(codebase_path) do
      [:redis | messaging_techs]
    else
      messaging_techs
    end
    
    # RabbitMQ detection
    messaging_techs = if detect_rabbitmq_patterns(codebase_path) do
      [:rabbitmq | messaging_techs]
    else
      messaging_techs
    end
    
    # OTP/BEAM messaging detection
    messaging_techs = if detect_otp_messaging_patterns(codebase_path) do
      [:otp_messaging | messaging_techs]
    else
      messaging_techs
    end
    
    messaging_techs
  end

  defp detect_nats_patterns(codebase_path) do
    # Look for NATS-specific patterns in code
    nats_patterns = [
      ~r/nats\.connect/,
      ~r/nats\.subscribe/,
      ~r/nats\.publish/,
      ~r/jetstream/,
      ~r/nats\.js/,
      ~r/nats\.Connection/,
      ~r/nats\.Subscription/
    ]
    
    # Check package.json for NATS dependencies
    package_json_path = Path.join(codebase_path, "package.json")
    has_nats_dependency = if File.exists?(package_json_path) do
      case File.read(package_json_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, %{"dependencies" => deps}} ->
              Map.has_key?(deps, "nats") or Map.has_key?(deps, "nats.js")
            _ -> false
          end
        _ -> false
      end
    else
      false
    end
    
    # Check for NATS configuration files
    nats_config_files = [
      "nats.conf",
      "jetstream.conf",
      ".natsrc"
    ]
    
    has_nats_config = Enum.any?(nats_config_files, fn file ->
      File.exists?(Path.join(codebase_path, file))
    end)
    
    # Check code patterns
    has_nats_patterns = matches_patterns_in_codebase?(codebase_path, nats_patterns)
    
    has_nats_dependency or has_nats_config or has_nats_patterns
  end

  defp detect_kafka_patterns(codebase_path) do
    kafka_patterns = [
      ~r/kafka\.producer/,
      ~r/kafka\.consumer/,
      ~r/KafkaProducer/,
      ~r/KafkaConsumer/,
      ~r/kafka\.admin/,
      ~r/KafkaAdmin/
    ]
    
    # Check for Kafka dependencies
    package_json_path = Path.join(codebase_path, "package.json")
    has_kafka_dependency = if File.exists?(package_json_path) do
      case File.read(package_json_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, %{"dependencies" => deps}} ->
              Enum.any?(Map.keys(deps), &String.contains?(&1, "kafka"))
            _ -> false
          end
        _ -> false
      end
    else
      false
    end
    
    # Check for Kafka configuration
    kafka_config_files = [
      "kafka.properties",
      "kafka.yml",
      "kafka.yaml"
    ]
    
    has_kafka_config = Enum.any?(kafka_config_files, fn file ->
      File.exists?(Path.join(codebase_path, file))
    end)
    
    has_kafka_dependency or has_kafka_config or matches_patterns_in_codebase?(codebase_path, kafka_patterns)
  end

  defp detect_redis_patterns(codebase_path) do
    redis_patterns = [
      ~r/redis\.createClient/,
      ~r/Redis\.createClient/,
      ~r/redis\.connect/,
      ~r/redis\.get/,
      ~r/redis\.set/,
      ~r/redis\.hget/,
      ~r/redis\.hset/
    ]
    
    # Check for Redis dependencies
    package_json_path = Path.join(codebase_path, "package.json")
    has_redis_dependency = if File.exists?(package_json_path) do
      case File.read(package_json_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, %{"dependencies" => deps}} ->
              Enum.any?(Map.keys(deps), &String.contains?(&1, "redis"))
            _ -> false
          end
        _ -> false
      end
    else
      false
    end
    
    has_redis_dependency or matches_patterns_in_codebase?(codebase_path, redis_patterns)
  end

  defp detect_rabbitmq_patterns(codebase_path) do
    rabbitmq_patterns = [
      ~r/amqp\.connect/,
      ~r/rabbitmq/,
      ~r/amqplib/,
      ~r/Channel\.create/
    ]
    
    # Check for RabbitMQ dependencies
    package_json_path = Path.join(codebase_path, "package.json")
    has_rabbitmq_dependency = if File.exists?(package_json_path) do
      case File.read(package_json_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, %{"dependencies" => deps}} ->
              Enum.any?(Map.keys(deps), &String.contains?(&1, "amqp"))
            _ -> false
          end
        _ -> false
      end
    else
      false
    end
    
    has_rabbitmq_dependency or matches_patterns_in_codebase?(codebase_path, rabbitmq_patterns)
  end

  defp detect_otp_messaging_patterns(codebase_path) do
    otp_patterns = [
      ~r/GenServer/,
      ~r/send\(/,
      ~r/receive\s+do/,
      ~r/cast\(/,
      ~r/call\(/,
      ~r/Phoenix\.PubSub/,
      ~r/Registry/,
      ~r/Agent/,
      ~r/Task/
    ]
    
    matches_patterns_in_codebase?(codebase_path, otp_patterns)
  end

  defp detect_database_technologies(codebase_path) do
    databases = []
    
    # PostgreSQL detection
    databases = if detect_postgresql_patterns(codebase_path) do
      [:postgresql | databases]
    else
      databases
    end
    
    # MongoDB detection
    databases = if detect_mongodb_patterns(codebase_path) do
      [:mongodb | databases]
    else
      databases
    end
    
    # SQLite detection
    databases = if detect_sqlite_patterns(codebase_path) do
      [:sqlite | databases]
    else
      databases
    end
    
    # Redis as database
    databases = if detect_redis_patterns(codebase_path) do
      [:redis | databases]
    else
      databases
    end
    
    databases
  end

  defp detect_postgresql_patterns(codebase_path) do
    postgres_patterns = [
      ~r/postgresql/,
      ~r/pg\.connect/,
      ~r/Pool\.connect/,
      ~r/postgres:\/\/,
      ~r/pgvector/,
      ~r/PostgreSQL/
    ]
    
    # Check for PostgreSQL dependencies
    package_json_path = Path.join(codebase_path, "package.json")
    has_postgres_dependency = if File.exists?(package_json_path) do
      case File.read(package_json_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, %{"dependencies" => deps}} ->
              Enum.any?(Map.keys(deps), fn dep ->
                String.contains?(dep, "pg") or String.contains?(dep, "postgres")
              end)
            _ -> false
          end
        _ -> false
      end
    else
      false
    end
    
    has_postgres_dependency or matches_patterns_in_codebase?(codebase_path, postgres_patterns)
  end

  defp detect_mongodb_patterns(codebase_path) do
    mongo_patterns = [
      ~r/mongodb/,
      ~r/MongoClient/,
      ~r/mongoose/,
      ~r/mongodb:\/\/,
      ~r/MongoDB/
    ]
    
    # Check for MongoDB dependencies
    package_json_path = Path.join(codebase_path, "package.json")
    has_mongo_dependency = if File.exists?(package_json_path) do
      case File.read(package_json_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, %{"dependencies" => deps}} ->
              Enum.any?(Map.keys(deps), fn dep ->
                String.contains?(dep, "mongo") or String.contains?(dep, "mongoose")
              end)
            _ -> false
          end
        _ -> false
      end
    else
      false
    end
    
    has_mongo_dependency or matches_patterns_in_codebase?(codebase_path, mongo_patterns)
  end

  defp detect_sqlite_patterns(codebase_path) do
    sqlite_patterns = [
      ~r/sqlite3/,
      ~r/SQLite/,
      ~r/\.db$/,
      ~r/\.sqlite/
    ]
    
    # Check for SQLite dependencies
    package_json_path = Path.join(codebase_path, "package.json")
    has_sqlite_dependency = if File.exists?(package_json_path) do
      case File.read(package_json_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, %{"dependencies" => deps}} ->
              Enum.any?(Map.keys(deps), &String.contains?(&1, "sqlite"))
            _ -> false
          end
        _ -> false
      end
    else
      false
    end
    
    has_sqlite_dependency or matches_patterns_in_codebase?(codebase_path, sqlite_patterns)
  end

  defp detect_build_systems(codebase_path) do
    build_systems = []
    
    # Bazel detection
    build_systems = if detect_bazel_patterns(codebase_path) do
      [:bazel | build_systems]
    else
      build_systems
    end
    
    # Nx detection
    build_systems = if detect_nx_patterns(codebase_path) do
      [:nx | build_systems]
    else
      build_systems
    end
    
    # Moon detection
    build_systems = if detect_moon_patterns(codebase_path) do
      [:moon | build_systems]
    else
      build_systems
    end
    
    # Lerna detection
    build_systems = if detect_lerna_patterns(codebase_path) do
      [:lerna | build_systems]
    else
      build_systems
    end
    
    build_systems
  end

  defp detect_bazel_patterns(codebase_path) do
    bazel_files = [
      "WORKSPACE",
      "MODULE.bazel",
      "BUILD",
      "BUILD.bazel"
    ]
    
    Enum.any?(bazel_files, fn file ->
      File.exists?(Path.join(codebase_path, file))
    end)
  end

  defp detect_nx_patterns(codebase_path) do
    nx_files = [
      "nx.json",
      ".nxrc"
    ]
    
    Enum.any?(nx_files, fn file ->
      File.exists?(Path.join(codebase_path, file))
    end)
  end

  defp detect_moon_patterns(codebase_path) do
    moon_files = [
      "moon.yml",
      "moon.yaml"
    ]
    
    Enum.any?(moon_files, fn file ->
      File.exists?(Path.join(codebase_path, file))
    end)
  end

  defp detect_lerna_patterns(codebase_path) do
    lerna_files = [
      "lerna.json",
      ".lernarc"
    ]
    
    Enum.any?(lerna_files, fn file ->
      File.exists?(Path.join(codebase_path, file))
    end)
  end

  defp detect_frameworks(codebase_path) do
    frameworks = []
    
    # NestJS detection
    frameworks = if detect_nestjs_patterns(codebase_path) do
      [:nestjs | frameworks]
    else
      frameworks
    end
    
    # Express detection
    frameworks = if detect_express_patterns(codebase_path) do
      [:express | frameworks]
    else
      frameworks
    end
    
    # Phoenix detection
    frameworks = if detect_phoenix_patterns(codebase_path) do
      [:phoenix | frameworks]
    else
      frameworks
    end
    
    # FastAPI detection
    frameworks = if detect_fastapi_patterns(codebase_path) do
      [:fastapi | frameworks]
    else
      frameworks
    end
    
    frameworks
  end

  defp detect_nestjs_patterns(codebase_path) do
    nestjs_patterns = [
      ~r/@Controller/,
      ~r/@Injectable/,
      ~r/@Module/,
      ~r/@Get/,
      ~r/@Post/,
      ~r/@Put/,
      ~r/@Delete/,
      ~r/NestFactory/,
      ~r/NestJS/
    ]
    
    # Check for NestJS dependencies
    package_json_path = Path.join(codebase_path, "package.json")
    has_nestjs_dependency = if File.exists?(package_json_path) do
      case File.read(package_json_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, %{"dependencies" => deps}} ->
              Map.has_key?(deps, "@nestjs/core")
            _ -> false
          end
        _ -> false
      end
    else
      false
    end
    
    has_nestjs_dependency or matches_patterns_in_codebase?(codebase_path, nestjs_patterns)
  end

  defp detect_express_patterns(codebase_path) do
    express_patterns = [
      ~r/express\(\)/,
      ~r/app\.get/,
      ~r/app\.post/,
      ~r/app\.put/,
      ~r/app\.delete/,
      ~r/express\.Router/,
      ~r/middleware/
    ]
    
    # Check for Express dependencies
    package_json_path = Path.join(codebase_path, "package.json")
    has_express_dependency = if File.exists?(package_json_path) do
      case File.read(package_json_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, %{"dependencies" => deps}} ->
              Map.has_key?(deps, "express")
            _ -> false
          end
        _ -> false
      end
    else
      false
    end
    
    has_express_dependency or matches_patterns_in_codebase?(codebase_path, express_patterns)
  end

  defp detect_phoenix_patterns(codebase_path) do
    phoenix_patterns = [
      ~r/use\s+Phoenix\.Controller/,
      ~r/use\s+Phoenix\.Router/,
      ~r/use\s+Phoenix\.Channel/,
      ~r/Phoenix\.Controller/,
      ~r/Phoenix\.Router/,
      ~r/Phoenix\.Channel/,
      ~r/Phoenix\.LiveView/
    ]
    
    # Check for Phoenix dependencies in mix.exs
    mix_exs_path = Path.join(codebase_path, "mix.exs")
    has_phoenix_dependency = if File.exists?(mix_exs_path) do
      case File.read(mix_exs_path) do
        {:ok, content} ->
          String.contains?(content, "phoenix")
        _ -> false
      end
    else
      false
    end
    
    has_phoenix_dependency or matches_patterns_in_codebase?(codebase_path, phoenix_patterns)
  end

  defp detect_fastapi_patterns(codebase_path) do
    fastapi_patterns = [
      ~r/FastAPI/,
      ~r/@app\.get/,
      ~r/@app\.post/,
      ~r/@app\.put/,
      ~r/@app\.delete/,
      ~r/APIRouter/,
      ~r/Depends/
    ]
    
    # Check for FastAPI dependencies
    requirements_path = Path.join(codebase_path, "requirements.txt")
    has_fastapi_dependency = if File.exists?(requirements_path) do
      case File.read(requirements_path) do
        {:ok, content} ->
          String.contains?(content, "fastapi")
        _ -> false
      end
    else
      false
    end
    
    has_fastapi_dependency or matches_patterns_in_codebase?(codebase_path, fastapi_patterns)
  end

  defp detect_monitoring_technologies(codebase_path) do
    monitoring_techs = []
    
    # Prometheus detection
    monitoring_techs = if detect_prometheus_patterns(codebase_path) do
      [:prometheus | monitoring_techs]
    else
      monitoring_techs
    end
    
    # Grafana detection
    monitoring_techs = if detect_grafana_patterns(codebase_path) do
      [:grafana | monitoring_techs]
    else
      monitoring_techs
    end
    
    # Jaeger detection
    monitoring_techs = if detect_jaeger_patterns(codebase_path) do
      [:jaeger | monitoring_techs]
    else
      monitoring_techs
    end
    
    # OpenTelemetry detection
    monitoring_techs = if detect_otel_patterns(codebase_path) do
      [:opentelemetry | monitoring_techs]
    else
      monitoring_techs
    end
    
    monitoring_techs
  end

  defp detect_prometheus_patterns(codebase_path) do
    prometheus_patterns = [
      ~r/prometheus/,
      ~r/metrics/,
      ~r/counter/,
      ~r/gauge/,
      ~r/histogram/,
      ~r/summary/
    ]
    
    matches_patterns_in_codebase?(codebase_path, prometheus_patterns)
  end

  defp detect_grafana_patterns(codebase_path) do
    grafana_patterns = [
      ~r/grafana/,
      ~r/dashboard/,
      ~r/grafana\.json/
    ]
    
    matches_patterns_in_codebase?(codebase_path, grafana_patterns)
  end

  defp detect_jaeger_patterns(codebase_path) do
    jaeger_patterns = [
      ~r/jaeger/,
      ~r/tracing/,
      ~r/span/,
      ~r/tracer/
    ]
    
    matches_patterns_in_codebase?(codebase_path, jaeger_patterns)
  end

  defp detect_otel_patterns(codebase_path) do
    otel_patterns = [
      ~r/opentelemetry/,
      ~r/@opentelemetry/,
      ~r/otel/,
      ~r/tracing/
    ]
    
    matches_patterns_in_codebase?(codebase_path, otel_patterns)
  end

  defp detect_security_technologies(codebase_path) do
    security_techs = []
    
    # SPIFFE/SPIRE detection
    security_techs = if detect_spiffe_patterns(codebase_path) do
      [:spiffe_spire | security_techs]
    else
      security_techs
    end
    
    # OPA detection
    security_techs = if detect_opa_patterns(codebase_path) do
      [:opa | security_techs]
    else
      security_techs
    end
    
    # Falco detection
    security_techs = if detect_falco_patterns(codebase_path) do
      [:falco | security_techs]
    else
      security_techs
    end
    
    security_techs
  end

  defp detect_spiffe_patterns(codebase_path) do
    spiffe_patterns = [
      ~r/spiffe/,
      ~r/spire/,
      ~r/spiffe:\/\/,
      ~r/workloadapi/
    ]
    
    matches_patterns_in_codebase?(codebase_path, spiffe_patterns)
  end

  defp detect_opa_patterns(codebase_path) do
    opa_patterns = [
      ~r/openpolicyagent/,
      ~r/opa/,
      ~r/rego/,
      ~r/policy/
    ]
    
    matches_patterns_in_codebase?(codebase_path, opa_patterns)
  end

  defp detect_falco_patterns(codebase_path) do
    falco_patterns = [
      ~r/falco/,
      ~r/rules/,
      ~r/falco\.rules/
    ]
    
    matches_patterns_in_codebase?(codebase_path, falco_patterns)
  end

  defp detect_ai_frameworks(codebase_path) do
    ai_frameworks = []
    
    # LangChain detection
    ai_frameworks = if detect_langchain_patterns(codebase_path) do
      [:langchain | ai_frameworks]
    else
      ai_frameworks
    end
    
    # CrewAI detection
    ai_frameworks = if detect_crewai_patterns(codebase_path) do
      [:crewai | ai_frameworks]
    else
      ai_frameworks
    end
    
    # MCP detection
    ai_frameworks = if detect_mcp_patterns(codebase_path) do
      [:mcp | ai_frameworks]
    else
      ai_frameworks
    end
    
    ai_frameworks
  end

  defp detect_langchain_patterns(codebase_path) do
    langchain_patterns = [
      ~r/langchain/,
      ~r/@langchain/,
      ~r/LLMChain/,
      ~r/ChatOpenAI/,
      ~r/PromptTemplate/
    ]
    
    matches_patterns_in_codebase?(codebase_path, langchain_patterns)
  end

  defp detect_crewai_patterns(codebase_path) do
    crewai_patterns = [
      ~r/crewai/,
      ~r/Crew/,
      ~r/Agent/,
      ~r/Task/,
      ~r/Tool/
    ]
    
    matches_patterns_in_codebase?(codebase_path, crewai_patterns)
  end

  defp detect_mcp_patterns(codebase_path) do
    mcp_patterns = [
      ~r/mcp/,
      ~r/@modelcontextprotocol/,
      ~r/ModelContextProtocol/
    ]
    
    matches_patterns_in_codebase?(codebase_path, mcp_patterns)
  end

  defp detect_deployment_technologies(codebase_path) do
    deployment_techs = []
    
    # Kubernetes detection
    deployment_techs = if detect_kubernetes_patterns(codebase_path) do
      [:kubernetes | deployment_techs]
    else
      deployment_techs
    end
    
    # Docker detection
    deployment_techs = if detect_docker_patterns(codebase_path) do
      [:docker | deployment_techs]
    else
      deployment_techs
    end
    
    # Helm detection
    deployment_techs = if detect_helm_patterns(codebase_path) do
      [:helm | deployment_techs]
    else
      deployment_techs
    end
    
    deployment_techs
  end

  defp detect_kubernetes_patterns(codebase_path) do
    k8s_files = Path.wildcard(Path.join(codebase_path, "**/k8s/**/*.yaml"))
    k8s_files_count = length(k8s_files)
    
    k8s_patterns = [
      ~r/apiVersion:/,
      ~r/kind:\s+(Deployment|Service|ConfigMap|Secret)/,
      ~r/metadata:/,
      ~r/spec:/
    ]
    
    k8s_files_count > 0 or matches_patterns_in_codebase?(codebase_path, k8s_patterns)
  end

  defp detect_docker_patterns(codebase_path) do
    docker_files = [
      "Dockerfile",
      "docker-compose.yml",
      "docker-compose.yaml",
      ".dockerignore"
    ]
    
    Enum.any?(docker_files, fn file ->
      File.exists?(Path.join(codebase_path, file))
    end)
  end

  defp detect_helm_patterns(codebase_path) do
    helm_files = [
      "Chart.yaml",
      "values.yaml",
      "values.yml"
    ]
    
    Enum.any?(helm_files, fn file ->
      File.exists?(Path.join(codebase_path, file))
    end)
  end

  defp detect_cloud_platforms(codebase_path) do
    cloud_platforms = []
    
    # AWS detection
    cloud_platforms = if detect_aws_patterns(codebase_path) do
      [:aws | cloud_platforms]
    else
      cloud_platforms
    end
    
    # Azure detection
    cloud_platforms = if detect_azure_patterns(codebase_path) do
      [:azure | cloud_platforms]
    else
      cloud_platforms
    end
    
    # GCP detection
    cloud_platforms = if detect_gcp_patterns(codebase_path) do
      [:gcp | cloud_platforms]
    else
      cloud_platforms
    end
    
    cloud_platforms
  end

  defp detect_aws_patterns(codebase_path) do
    aws_patterns = [
      ~r/aws-sdk/,
      ~r/@aws-sdk/,
      ~r/aws\./,
      ~r/amazonaws/,
      ~r/s3\./,
      ~r/lambda/,
      ~r/ec2/,
      ~r/rds/
    ]
    
    matches_patterns_in_codebase?(codebase_path, aws_patterns)
  end

  defp detect_azure_patterns(codebase_path) do
    azure_patterns = [
      ~r/@azure/,
      ~r/azure-/,
      ~r/microsoft/,
      ~r/azure\./,
      ~r/azureml/
    ]
    
    matches_patterns_in_codebase?(codebase_path, azure_patterns)
  end

  defp detect_gcp_patterns(codebase_path) do
    gcp_patterns = [
      ~r/@google-cloud/,
      ~r/google-cloud/,
      ~r/gcp/,
      ~r/firebase/,
      ~r/gcloud/
    ]
    
    matches_patterns_in_codebase?(codebase_path, gcp_patterns)
  end

  # Helper functions

  defp has_files_with_extension?(codebase_path, extension) do
    pattern = Path.join(codebase_path, "**/*#{extension}")
    files = Path.wildcard(pattern)
    length(files) > 0
  end

  defp find_source_files(codebase_path) do
    source_patterns = [
      "**/*.ts",
      "**/*.tsx",
      "**/*.js",
      "**/*.jsx",
      "**/*.rs",
      "**/*.py",
      "**/*.go",
      "**/*.ex",
      "**/*.exs",
      "**/*.erl",
      "**/*.hrl",
      "**/*.gleam"
    ]
    
    Enum.flat_map(source_patterns, fn pattern ->
      Path.wildcard(Path.join(codebase_path, pattern))
    end)
    |> Enum.reject(&String.contains?(&1, "node_modules"))
    |> Enum.reject(&String.contains?(&1, "target"))
    |> Enum.reject(&String.contains?(&1, "__pycache__"))
    |> Enum.reject(&String.contains?(&1, ".git"))
  end

  defp matches_patterns?(files, patterns) do
    Enum.any?(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.any?(patterns, fn pattern ->
            Regex.match?(pattern, content)
          end)
        _ -> false
      end
    end)
  end

  defp matches_patterns_in_codebase?(codebase_path, patterns) do
    source_files = find_source_files(codebase_path)
    matches_patterns?(source_files, patterns)
  end

  defp scan_code_patterns(codebase_path) do
    source_files = find_source_files(codebase_path)
    
    patterns = %{
      async_patterns: detect_async_patterns(source_files),
      error_handling_patterns: detect_error_handling_patterns(source_files),
      testing_patterns: detect_testing_patterns(source_files),
      logging_patterns: detect_logging_patterns(source_files),
      caching_patterns: detect_caching_patterns(source_files),
      api_patterns: detect_api_patterns(source_files)
    }
    
    {:ok, patterns}
  end

  defp detect_async_patterns(files) do
    async_patterns = [
      ~r/async\s+function/,
      ~r/await\s+/,
      ~r/Promise/,
      ~r/async\s+/,
      ~r/spawn/,
      ~r/Task\.async/,
      ~r/GenServer\.call/,
      ~r/GenServer\.cast/
    ]
    
    Enum.count(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.any?(async_patterns, &Regex.match?(&1, content))
        _ -> false
      end
    end)
  end

  defp detect_error_handling_patterns(files) do
    error_patterns = [
      ~r/try\s*{/,
      ~r/catch\s*\(/,
      ~r/throw\s+/,
      ~r/rescue/,
      ~r/raise/,
      ~r/Result\.ok/,
      ~r/Result\.error/,
      ~r/{:ok,/,
      ~r/{:error,/
    ]
    
    Enum.count(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.any?(error_patterns, &Regex.match?(&1, content))
        _ -> false
      end
    end)
  end

  defp detect_testing_patterns(files) do
    test_patterns = [
      ~r/describe\(/,
      ~r/it\(/,
      ~r/test\(/,
      ~r/assert/,
      ~r/expect\(/,
      ~r/ExUnit\.Case/,
      ~r/test\s+"/
    ]
    
    Enum.count(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.any?(test_patterns, &Regex.match?(&1, content))
        _ -> false
      end
    end)
  end

  defp detect_logging_patterns(files) do
    logging_patterns = [
      ~r/console\.log/,
      ~r/console\.error/,
      ~r/console\.warn/,
      ~r/Logger\.info/,
      ~r/Logger\.error/,
      ~r/Logger\.warn/,
      ~r/logging/,
      ~r/tracing/
    ]
    
    Enum.count(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.any?(logging_patterns, &Regex.match?(&1, content))
        _ -> false
      end
    end)
  end

  defp detect_caching_patterns(files) do
    cache_patterns = [
      ~r/cache/,
      ~r/memoize/,
      ~r/Cachex/,
      ~r/redis/,
      ~r/memcached/,
      ~r/lru/,
      ~r/ttl/
    ]
    
    Enum.count(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.any?(cache_patterns, &Regex.match?(&1, content))
        _ -> false
      end
    end)
  end

  defp detect_api_patterns(files) do
    api_patterns = [
      ~r/@Get/,
      ~r/@Post/,
      ~r/@Put/,
      ~r/@Delete/,
      ~r/app\.get/,
      ~r/app\.post/,
      ~r/app\.put/,
      ~r/app\.delete/,
      ~r/def\s+index/,
      ~r/def\s+create/,
      ~r/def\s+update/,
      ~r/def\s+delete/
    ]
    
    Enum.count(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.any?(api_patterns, &Regex.match?(&1, content))
        _ -> false
      end
    end)
  end

  # Advanced confidence-based detection functions (inspired by zenflow analysis-suite)

  defp detect_languages_with_confidence(codebase_path) do
    # Language detection with confidence scoring
    language_patterns = %{
      :typescript => %{
        patterns: [
          ~r/interface\s+\w+/,
          ~r/type\s+\w+/,
          ~r/:\s*\w+\[\]/,
          ~r/:\s*Promise<\w+>/,
          ~r/:\s*string\s*\|/,
          ~r/:\s*number\s*\|/
        ],
        config_files: ["tsconfig.json", "package.json"],
        extensions: [".ts", ".tsx"],
        weight: 1.0
      },
      :rust => %{
        patterns: [
          ~r/fn\s+\w+/,
          ~r/struct\s+\w+/,
          ~r/impl\s+\w+/,
          ~r/use\s+\w+::/,
          ~r/let\s+\w+:/,
          ~r/match\s+\w+/
        ],
        config_files: ["Cargo.toml"],
        extensions: [".rs"],
        weight: 1.0
      },
      :elixir => %{
        patterns: [
          ~r/defmodule\s+\w+/,
          ~r/def\s+\w+/,
          ~r/use\s+\w+/,
          ~r/GenServer/,
          ~r/defp\s+\w+/,
          ~r/defmacro\s+\w+/
        ],
        config_files: ["mix.exs"],
        extensions: [".ex", ".exs"],
        weight: 1.0
      },
      :python => %{
        patterns: [
          ~r/def\s+\w+/,
          ~r/class\s+\w+/,
          ~r/import\s+\w+/,
          ~r/from\s+\w+\s+import/,
          ~r/if\s+__name__/,
          ~r/async\s+def/
        ],
        config_files: ["requirements.txt", "setup.py", "pyproject.toml"],
        extensions: [".py"],
        weight: 1.0
      },
      :go => %{
        patterns: [
          ~r/func\s+\w+/,
          ~r/type\s+\w+/,
          ~r/package\s+\w+/,
          ~r/import\s+\(/,
          ~r/var\s+\w+/,
          ~r/const\s+\w+/
        ],
        config_files: ["go.mod", "go.sum"],
        extensions: [".go"],
        weight: 1.0
      }
    }
    
    detect_technologies_with_confidence(codebase_path, language_patterns)
  end

  defp detect_frameworks_with_confidence(codebase_path) do
    framework_patterns = %{
      :nestjs => %{
        patterns: [
          ~r/@Controller/,
          ~r/@Injectable/,
          ~r/@Module/,
          ~r/@Get/,
          ~r/@Post/,
          ~r/@Put/,
          ~r/@Delete/,
          ~r/NestFactory/,
          ~r/NestJS/
        ],
        dependencies: ["@nestjs/core", "@nestjs/common"],
        config_files: ["package.json"],
        weight: 1.0
      },
      :phoenix => %{
        patterns: [
          ~r/use\s+Phoenix\.Controller/,
          ~r/use\s+Phoenix\.Router/,
          ~r/use\s+Phoenix\.Channel/,
          ~r/Phoenix\.Controller/,
          ~r/Phoenix\.Router/,
          ~r/Phoenix\.LiveView/
        ],
        dependencies: ["phoenix"],
        config_files: ["mix.exs"],
        weight: 1.0
      },
      :fastapi => %{
        patterns: [
          ~r/FastAPI/,
          ~r/@app\.get/,
          ~r/@app\.post/,
          ~r/@app\.put/,
          ~r/@app\.delete/,
          ~r/APIRouter/,
          ~r/Depends/
        ],
        dependencies: ["fastapi"],
        config_files: ["requirements.txt"],
        weight: 1.0
      },
      :express => %{
        patterns: [
          ~r/express\(\)/,
          ~r/app\.get/,
          ~r/app\.post/,
          ~r/app\.put/,
          ~r/app\.delete/,
          ~r/express\.Router/,
          ~r/middleware/
        ],
        dependencies: ["express"],
        config_files: ["package.json"],
        weight: 1.0
      }
    }
    
    detect_technologies_with_confidence(codebase_path, framework_patterns)
  end

  defp detect_messaging_technologies_with_confidence(codebase_path) do
    messaging_patterns = %{
      :nats => %{
        patterns: [
          ~r/nats\.connect/,
          ~r/nats\.subscribe/,
          ~r/nats\.publish/,
          ~r/jetstream/,
          ~r/nats\.js/,
          ~r/nats\.Connection/,
          ~r/nats\.Subscription/,
          ~r/nats.*jetstream/i,
          ~r/jetstream.*nats/i,
          ~r/nats.*streaming/i,
          ~r/nats.*cluster/i
        ],
        dependencies: ["nats", "nats.js"],
        config_files: ["nats.conf", "jetstream.conf"],
        weight: 1.0
      },
      :kafka => %{
        patterns: [
          ~r/kafka\.producer/,
          ~r/kafka\.consumer/,
          ~r/KafkaProducer/,
          ~r/KafkaConsumer/,
          ~r/kafka\.admin/,
          ~r/KafkaAdmin/
        ],
        dependencies: ["kafka", "kafkajs"],
        config_files: ["kafka.properties"],
        weight: 1.0
      },
      :otp_messaging => %{
        patterns: [
          ~r/GenServer/,
          ~r/send\(/,
          ~r/receive\s+do/,
          ~r/cast\(/,
          ~r/call\(/,
          ~r/Phoenix\.PubSub/,
          ~r/Registry/,
          ~r/Agent/,
          ~r/Task/
        ],
        dependencies: [],
        config_files: ["mix.exs"],
        weight: 1.0
      },
      :redis => %{
        patterns: [
          ~r/redis\.createClient/,
          ~r/Redis\.createClient/,
          ~r/redis\.connect/,
          ~r/redis\.get/,
          ~r/redis\.set/,
          ~r/redis\.hget/,
          ~r/redis\.hset/
        ],
        dependencies: ["redis", "ioredis"],
        config_files: ["redis.conf"],
        weight: 1.0
      },
      # Singularity-engine specific messaging
      :event_bus => %{
        patterns: [
          ~r/event.*bus/i,
          ~r/bus.*event/i,
          ~r/event.*stream/i,
          ~r/stream.*event/i,
          ~r/event.*pipeline/i,
          ~r/pipeline.*event/i,
          ~r/event.*orchestration/i,
          ~r/orchestration.*event/i
        ],
        dependencies: [],
        config_files: [],
        weight: 1.0
      },
      :service_mesh => %{
        patterns: [
          ~r/service.*mesh/i,
          ~r/mesh.*service/i,
          ~r/service.*discovery/i,
          ~r/discovery.*service/i,
          ~r/service.*registry/i,
          ~r/registry.*service/i,
          ~r/service.*communication/i,
          ~r/communication.*service/i
        ],
        dependencies: [],
        config_files: [],
        weight: 1.0
      }
    }
    
    detect_technologies_with_confidence(codebase_path, messaging_patterns)
  end

  defp detect_database_technologies_with_confidence(codebase_path) do
    database_patterns = %{
      :postgresql => %{
        patterns: [
          ~r/postgresql/,
          ~r/pg\.connect/,
          ~r/Pool\.connect/,
          ~r/postgres:\/\/,
          ~r/pgvector/,
          ~r/PostgreSQL/
        ],
        dependencies: ["pg", "postgresql"],
        config_files: ["postgresql.conf"],
        weight: 1.0
      },
      :mongodb => %{
        patterns: [
          ~r/mongodb/,
          ~r/MongoClient/,
          ~r/mongoose/,
          ~r/mongodb:\/\/,
          ~r/MongoDB/
        ],
        dependencies: ["mongodb", "mongoose"],
        config_files: ["mongod.conf"],
        weight: 1.0
      },
      :sqlite => %{
        patterns: [
          ~r/sqlite3/,
          ~r/SQLite/,
          ~r/\.db$/,
          ~r/\.sqlite/
        ],
        dependencies: ["sqlite3"],
        config_files: [],
        weight: 1.0
      }
    }
    
    detect_technologies_with_confidence(codebase_path, database_patterns)
  end

  defp detect_build_systems_with_confidence(codebase_path) do
    build_patterns = %{
      :bazel => %{
        patterns: [
          ~r/load\("@bazel/,
          ~r/cc_binary/,
          ~r/cc_library/,
          ~r/java_binary/,
          ~r/java_library/,
          ~r/ts_library/
        ],
        config_files: ["WORKSPACE", "MODULE.bazel", "BUILD", "BUILD.bazel"],
        weight: 1.0
      },
      :nx => %{
        patterns: [
          ~r/@nx/,
          ~r/nx\s+run/,
          ~r/nx\s+build/,
          ~r/nx\s+test/,
          ~r/nx\s+lint/
        ],
        config_files: ["nx.json", ".nxrc"],
        weight: 1.0
      },
      :moon => %{
        patterns: [
          ~r/moon\s+run/,
          ~r/moon\s+build/,
          ~r/moon\s+test/,
          ~r/moon\s+lint/
        ],
        config_files: ["moon.yml", "moon.yaml"],
        weight: 1.0
      },
      :lerna => %{
        patterns: [
          ~r/lerna\s+run/,
          ~r/lerna\s+bootstrap/,
          ~r/lerna\s+publish/
        ],
        config_files: ["lerna.json", ".lernarc"],
        weight: 1.0
      }
    }
    
    detect_technologies_with_confidence(codebase_path, build_patterns)
  end

  defp detect_monitoring_technologies_with_confidence(codebase_path) do
    monitoring_patterns = %{
      :prometheus => %{
        patterns: [
          ~r/prometheus/,
          ~r/metrics/,
          ~r/counter/,
          ~r/gauge/,
          ~r/histogram/,
          ~r/summary/
        ],
        dependencies: ["prom-client"],
        config_files: ["prometheus.yml"],
        weight: 1.0
      },
      :grafana => %{
        patterns: [
          ~r/grafana/,
          ~r/dashboard/,
          ~r/grafana\.json/
        ],
        dependencies: ["grafana"],
        config_files: ["grafana.ini"],
        weight: 1.0
      },
      :jaeger => %{
        patterns: [
          ~r/jaeger/,
          ~r/tracing/,
          ~r/span/,
          ~r/tracer/
        ],
        dependencies: ["jaeger-client"],
        config_files: ["jaeger.yml"],
        weight: 1.0
      },
      :opentelemetry => %{
        patterns: [
          ~r/opentelemetry/,
          ~r/@opentelemetry/,
          ~r/otel/,
          ~r/tracing/
        ],
        dependencies: ["@opentelemetry/api"],
        config_files: [],
        weight: 1.0
      }
    }
    
    detect_technologies_with_confidence(codebase_path, monitoring_patterns)
  end

  defp detect_security_technologies_with_confidence(codebase_path) do
    security_patterns = %{
      :spiffe_spire => %{
        patterns: [
          ~r/spiffe/,
          ~r/spire/,
          ~r/spiffe:\/\/,
          ~r/workloadapi/
        ],
        dependencies: [],
        config_files: ["spire.conf"],
        weight: 1.0
      },
      :opa => %{
        patterns: [
          ~r/openpolicyagent/,
          ~r/opa/,
          ~r/rego/,
          ~r/policy/
        ],
        dependencies: ["@openpolicyagent/opa"],
        config_files: ["opa.conf"],
        weight: 1.0
      },
      :falco => %{
        patterns: [
          ~r/falco/,
          ~r/rules/,
          ~r/falco\.rules/
        ],
        dependencies: [],
        config_files: ["falco.yaml"],
        weight: 1.0
      }
    }
    
    detect_technologies_with_confidence(codebase_path, security_patterns)
  end

  defp detect_ai_frameworks_with_confidence(codebase_path) do
    ai_patterns = %{
      :langchain => %{
        patterns: [
          ~r/langchain/,
          ~r/@langchain/,
          ~r/LLMChain/,
          ~r/ChatOpenAI/,
          ~r/PromptTemplate/
        ],
        dependencies: ["langchain", "@langchain/core"],
        config_files: [],
        weight: 1.0
      },
      :crewai => %{
        patterns: [
          ~r/crewai/,
          ~r/Crew/,
          ~r/Agent/,
          ~r/Task/,
          ~r/Tool/
        ],
        dependencies: ["crewai"],
        config_files: [],
        weight: 1.0
      },
      :mcp => %{
        patterns: [
          ~r/mcp/,
          ~r/@modelcontextprotocol/,
          ~r/ModelContextProtocol/
        ],
        dependencies: ["@modelcontextprotocol/sdk"],
        config_files: [],
        weight: 1.0
      },
      # Singularity-engine specific AI frameworks
      :bpmn_ai => %{
        patterns: [
          ~r/bpmn.*ai/i,
          ~r/ai.*bpmn/i,
          ~r/process.*ai/i,
          ~r/ai.*process/i,
          ~r/workflow.*ai/i,
          ~r/ai.*workflow/i
        ],
        dependencies: [],
        config_files: [],
        weight: 1.0
      },
      :sandbox_ai => %{
        patterns: [
          ~r/sandbox.*ai/i,
          ~r/ai.*sandbox/i,
          ~r/secure.*ai/i,
          ~r/ai.*security/i,
          ~r/isolated.*ai/i,
          ~r/ai.*isolation/i
        ],
        dependencies: [],
        config_files: [],
        weight: 1.0
      },
      :vector_ai => %{
        patterns: [
          ~r/vector.*ai/i,
          ~r/ai.*vector/i,
          ~r/embedding.*ai/i,
          ~r/ai.*embedding/i,
          ~r/semantic.*ai/i,
          ~r/ai.*semantic/i
        ],
        dependencies: [],
        config_files: [],
        weight: 1.0
      }
    }
    
    detect_technologies_with_confidence(codebase_path, ai_patterns)
  end

  defp detect_deployment_technologies_with_confidence(codebase_path) do
    deployment_patterns = %{
      :kubernetes => %{
        patterns: [
          ~r/apiVersion:/,
          ~r/kind:\s+(Deployment|Service|ConfigMap|Secret)/,
          ~r/metadata:/,
          ~r/spec:/
        ],
        dependencies: [],
        config_files: ["k8s/**/*.yaml"],
        weight: 1.0
      },
      :docker => %{
        patterns: [
          ~r/FROM\s+\w+/,
          ~r/RUN\s+/,
          ~r/COPY\s+/,
          ~r/EXPOSE\s+/
        ],
        dependencies: [],
        config_files: ["Dockerfile", "docker-compose.yml"],
        weight: 1.0
      },
      :helm => %{
        patterns: [
          ~r/Chart\.yaml/,
          ~r/values\.yaml/,
          ~r/templates/
        ],
        dependencies: [],
        config_files: ["Chart.yaml", "values.yaml"],
        weight: 1.0
      }
    }
    
    detect_technologies_with_confidence(codebase_path, deployment_patterns)
  end

  defp detect_cloud_platforms_with_confidence(codebase_path) do
    cloud_patterns = %{
      :aws => %{
        patterns: [
          ~r/aws-sdk/,
          ~r/@aws-sdk/,
          ~r/aws\./,
          ~r/amazonaws/,
          ~r/s3\./,
          ~r/lambda/,
          ~r/ec2/,
          ~r/rds/
        ],
        dependencies: ["aws-sdk", "@aws-sdk/client-s3"],
        config_files: [],
        weight: 1.0
      },
      :azure => %{
        patterns: [
          ~r/@azure/,
          ~r/azure-/,
          ~r/microsoft/,
          ~r/azure\./,
          ~r/azureml/
        ],
        dependencies: ["@azure/core"],
        config_files: [],
        weight: 1.0
      },
      :gcp => %{
        patterns: [
          ~r/@google-cloud/,
          ~r/google-cloud/,
          ~r/gcp/,
          ~r/firebase/,
          ~r/gcloud/
        ],
        dependencies: ["@google-cloud/storage"],
        config_files: [],
        weight: 1.0
      }
    }
    
    detect_technologies_with_confidence(codebase_path, cloud_patterns)
  end

  defp detect_architecture_patterns_with_confidence(codebase_path) do
    architecture_patterns = %{
      :microservices => %{
        patterns: [
          ~r/services\//,
          ~r/service\s+discovery/,
          ~r/api\s+gateway/,
          ~r/service\s+mesh/,
          ~r/distributed/,
          ~r/service\s+registry/
        ],
        config_files: ["services/**"],
        weight: 1.0
      },
      :domain_driven_design => %{
        patterns: [
          ~r/domains\//,
          ~r/domain\s+model/,
          ~r/aggregate/,
          ~r/value\s+object/,
          ~r/entity/,
          ~r/repository\s+pattern/
        ],
        config_files: ["domains/**"],
        weight: 1.0
      },
      :event_driven => %{
        patterns: [
          ~r/event\s+bus/,
          ~r/event\s+sourcing/,
          ~r/publish\s+subscribe/,
          ~r/event\s+store/,
          ~r/event\s+stream/,
          ~r/message\s+queue/
        ],
        config_files: [],
        weight: 1.0
      },
      :cqrs => %{
        patterns: [
          ~r/command\s+query/,
          ~r/command\s+handler/,
          ~r/query\s+handler/,
          ~r/read\s+model/,
          ~r/write\s+model/,
          ~r/cqrs/
        ],
        config_files: [],
        weight: 1.0
      },
      :layered_architecture => %{
        patterns: [
          ~r/presentation\s+layer/,
          ~r/business\s+layer/,
          ~r/data\s+access\s+layer/,
          ~r/service\s+layer/,
          ~r/controller\s+layer/,
          ~r/repository\s+layer/,
          ~r/layered\s+architecture/i
        ],
        config_files: [],
        weight: 1.0
      },
      # Extended patterns from analysis-suite
      :hexagonal_architecture => %{
        patterns: [
          ~r/hexagonal\s+architecture/i,
          ~r/ports\s+and\s+adapters/i,
          ~r/clean\s+architecture/i,
          ~r/domain\s+core/,
          ~r/infrastructure\s+layer/,
          ~r/application\s+layer/
        ],
        config_files: [],
        weight: 1.0
      },
      :modular_monolith => %{
        patterns: [
          ~r/modular\s+monolith/i,
          ~r/module\s+boundaries/,
          ~r/internal\s+apis/,
          ~r/module\s+communication/
        ],
        config_files: [],
        weight: 1.0
      },
      :mvc => %{
        patterns: [
          ~r/model.*view.*controller/i,
          ~r/mvc\s+pattern/i,
          ~r/controller.*model.*view/i,
          ~r/views\//,
          ~r/models\//,
          ~r/controllers\//
        ],
        config_files: [],
        weight: 1.0
      },
      :mvp => %{
        patterns: [
          ~r/model.*view.*presenter/i,
          ~r/mvp\s+pattern/i,
          ~r/presenter.*model.*view/i
        ],
        config_files: [],
        weight: 1.0
      },
      :mvvm => %{
        patterns: [
          ~r/model.*view.*viewmodel/i,
          ~r/mvvm\s+pattern/i,
          ~r/viewmodel.*model.*view/i,
          ~r/data\s+binding/i
        ],
        config_files: [],
        weight: 1.0
      },
      :repository_pattern => %{
        patterns: [
          ~r/repository\s+pattern/i,
          ~r/repository\s+interface/i,
          ~r/data\s+repository/i,
          ~r/repository\s+implementation/i
        ],
        config_files: [],
        weight: 1.0
      },
      :factory_pattern => %{
        patterns: [
          ~r/factory\s+pattern/i,
          ~r/factory\s+method/i,
          ~r/abstract\s+factory/i,
          ~r/object\s+factory/i
        ],
        config_files: [],
        weight: 1.0
      },
      :observer_pattern => %{
        patterns: [
          ~r/observer\s+pattern/i,
          ~r/publish.*subscribe/i,
          ~r/event\s+listener/i,
          ~r/subject.*observer/i
        ],
        config_files: [],
        weight: 1.0
      },
      :strategy_pattern => %{
        patterns: [
          ~r/strategy\s+pattern/i,
          ~r/algorithm\s+strategy/i,
          ~r/behavioral\s+strategy/i
        ],
        config_files: [],
        weight: 1.0
      },
      :command_pattern => %{
        patterns: [
          ~r/command\s+pattern/i,
          ~r/command\s+handler/i,
          ~r/undo.*redo/i,
          ~r/action\s+command/i
        ],
        config_files: [],
        weight: 1.0
      },
      :saga_pattern => %{
        patterns: [
          ~r/saga\s+pattern/i,
          ~r/distributed\s+saga/i,
          ~r/transaction\s+saga/i,
          ~r/orchestration\s+saga/i
        ],
        config_files: [],
        weight: 1.0
      },
      :api_gateway => %{
        patterns: [
          ~r/api\s+gateway/i,
          ~r/gateway\s+pattern/i,
          ~r/request\s+routing/i,
          ~r/load\s+balancing/i
        ],
        config_files: [],
        weight: 1.0
      },
      :circuit_breaker => %{
        patterns: [
          ~r/circuit\s+breaker/i,
          ~r/fault\s+tolerance/i,
          ~r/resilience\s+pattern/i,
          ~r/fallback\s+mechanism/i
        ],
        config_files: [],
        weight: 1.0
      },
      :database_per_service => %{
        patterns: [
          ~r/database\s+per\s+service/i,
          ~r/service\s+database/i,
          ~r/data\s+isolation/i
        ],
        config_files: [],
        weight: 1.0
      },
      :shared_database => %{
        patterns: [
          ~r/shared\s+database/i,
          ~r/common\s+database/i,
          ~r/centralized\s+data/i
        ],
        config_files: [],
        weight: 1.0
      },
      :event_sourcing => %{
        patterns: [
          ~r/event\s+sourcing/i,
          ~r/event\s+store/i,
          ~r/event\s+history/i,
          ~r/event\s+replay/i
        ],
        config_files: [],
        weight: 1.0
      }
    }
    
    detect_technologies_with_confidence(codebase_path, architecture_patterns)
  end

  # Core confidence-based detection algorithm (inspired by zenflow analysis-suite)
  defp detect_technologies_with_confidence(codebase_path, technology_patterns) do
    Enum.map(technology_patterns, fn {tech_name, config} ->
      confidence = calculate_technology_confidence(codebase_path, config)
      
      if confidence > 0.3 do
        %{
          name: tech_name,
          confidence: confidence,
          patterns_matched: count_matching_patterns(codebase_path, config.patterns),
          total_patterns: length(config.patterns),
          config_files_found: count_config_files(codebase_path, config.config_files),
          dependencies_found: count_dependencies(codebase_path, config.dependencies)
        }
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp calculate_technology_confidence(codebase_path, config) do
    # Pattern matching confidence (0.0 - 1.0)
    pattern_confidence = calculate_pattern_confidence(codebase_path, config.patterns)
    
    # Config file confidence (0.0 - 1.0)
    config_confidence = calculate_config_confidence(codebase_path, config.config_files)
    
    # Dependency confidence (0.0 - 1.0)
    dependency_confidence = calculate_dependency_confidence(codebase_path, config.dependencies)
    
    # Weighted average with zenflow-style confidence scoring
    total_weight = config.weight
    weighted_confidence = (
      pattern_confidence * 0.6 +  # Pattern matching is most important
      config_confidence * 0.25 +   # Config files are strong indicators
      dependency_confidence * 0.15 # Dependencies are supporting evidence
    ) * total_weight
    
    Float.round(weighted_confidence, 3)
  end

  defp calculate_pattern_confidence(codebase_path, patterns) do
    source_files = find_source_files(codebase_path)
    total_patterns = length(patterns)
    
    if total_patterns == 0 do
      0.0
    else
      matches = count_matching_patterns(codebase_path, patterns)
      matches / total_patterns
    end
  end

  defp calculate_config_confidence(codebase_path, config_files) do
    if length(config_files) == 0 do
      0.5  # Neutral confidence if no config files expected
    else
      found_files = count_config_files(codebase_path, config_files)
      found_files / length(config_files)
    end
  end

  defp calculate_dependency_confidence(codebase_path, dependencies) do
    if length(dependencies) == 0 do
      0.5  # Neutral confidence if no dependencies expected
    else
      found_deps = count_dependencies(codebase_path, dependencies)
      found_deps / length(dependencies)
    end
  end

  defp count_matching_patterns(codebase_path, patterns) do
    source_files = find_source_files(codebase_path)
    
    Enum.count(patterns, fn pattern ->
      Enum.any?(source_files, fn file ->
        case File.read(file) do
          {:ok, content} ->
            Regex.match?(pattern, content)
          _ ->
            false
        end
      end)
    end)
  end

  defp count_config_files(codebase_path, config_files) do
    Enum.count(config_files, fn file_pattern ->
      if String.contains?(file_pattern, "**") do
        # Handle glob patterns
        files = Path.wildcard(Path.join(codebase_path, file_pattern))
        length(files) > 0
      else
        # Handle single files
        File.exists?(Path.join(codebase_path, file_pattern))
      end
    end)
  end

  defp count_dependencies(codebase_path, dependencies) do
    package_json_path = Path.join(codebase_path, "package.json")
    
    if File.exists?(package_json_path) do
      case File.read(package_json_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, %{"dependencies" => deps}} ->
              Enum.count(dependencies, fn dep ->
                Map.has_key?(deps, dep)
              end)
            _ ->
              0
          end
        _ ->
          0
      end
    else
      0
    end
  end
end