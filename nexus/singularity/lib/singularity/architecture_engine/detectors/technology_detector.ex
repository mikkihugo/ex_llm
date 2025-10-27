defmodule Singularity.Architecture.Detectors.TechnologyDetector do
  @moduledoc """
  Technology Pattern Detector - Detects programming languages and tech stack.

  Implements `@behaviour PatternType` to detect technology patterns in codebases.
  Uses `LanguageDetector` under the hood for consistent language detection.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Architecture.Detectors.TechnologyDetector",
    "type": "detector",
    "purpose": "Detect programming languages, runtimes, and technology stack",
    "layer": "architecture_engine",
    "behavior": "PatternType",
    "registered_in": "config :singularity, :pattern_types, technology: ...",
    "scope": "Language detection, runtime identification, technology stack analysis"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      A[detect/2] --> B[detect_technologies]
      B --> C[LanguageDetection]
      B --> D[database detection]
      B --> E[messaging detection]
      C --> F[extract tech info]
      D --> F
      E --> F
      F --> G[uniq by name]
      G --> H[return results]
  ```

  ## Call Graph (YAML)

  ```yaml
  calls:
    - Singularity.CodeAnalysis.LanguageDetection (language detection)
    - Singularity.Architecture.PatternStore (confidence tracking)
    - Logger (error handling)

  called_by:
    - Singularity.Architecture.PatternDetector (orchestrator)
    - Technology stack analysis
    - Codebase assessment pipelines
  ```

  ## Anti-Patterns

  - ❌ `TechStackDetector` - Use TechnologyDetector for tech detection
  - ❌ `LanguageRegistry` - Use PatternStore for persistence
  - ✅ Use PatternDetector for discovery
  - ✅ Leverage LanguageDetection for consistent language detection

  ## Detected Technologies

  - **Languages**: TypeScript, Rust, Python, Go, Elixir, Java, Ruby, PHP, C/C++
  - **Runtimes**: Node.js, JVM, CPython, Go Runtime
  - **Databases**: PostgreSQL, MongoDB, Redis, MySQL
  - **Messaging**: RabbitMQ, Kafka, pgmq

  ## Search Keywords

  technology detection, language detection, tech stack, runtime detection,
  database detection, programming language, technology assessment
  """

  @behaviour Singularity.Architecture.PatternType
  require Logger
  alias Singularity.CodeAnalysis.LanguageDetection
  alias Singularity.Architecture.PatternStore

  @impl true
  def pattern_type, do: :technology

  @impl true
  def description,
    do:
      "Detect programming languages, runtimes, technology stack, and infrastructure systems (Phase 7)"

  @impl true
  def supported_types do
    [
      "language",
      "runtime",
      "database",
      "cache",
      "messaging",
      "ci_cd",
      "container",
      # Phase 7: Infrastructure types via registry cache
      "service_mesh",
      "api_gateway",
      "container_orchestration"
    ]
  end

  @impl true
  def detect(path, opts \\ []) when is_binary(path) do
    # Step 1: Run hardcoded detectors
    hardcoded_results = detect_technologies(path)

    # Step 2: Fetch learned patterns from database
    learned_patterns = fetch_learned_patterns()

    # Step 3: Enhance results with learned pattern confidence
    enhanced_results = enhance_with_learned_patterns(hardcoded_results, learned_patterns)

    # Step 4: Apply learned patterns not yet detected
    all_results = apply_learned_patterns(enhanced_results, learned_patterns, path)

    # Return unique results sorted by confidence
    all_results
    |> Enum.uniq_by(& &1.name)
    |> Enum.sort_by(& &1.confidence, :desc)
  end

  @impl true
  def learn_pattern(result) do
    # Update technology confidence in PatternStore
    case result do
      %{name: name, success: true} ->
        Singularity.Architecture.PatternStore.update_confidence(:technology, name, success: true)

      %{name: name, success: false} ->
        Singularity.Architecture.PatternStore.update_confidence(:technology, name, success: false)

      _ ->
        :ok
    end
  end

  # Private: Pattern learning integration

  defp fetch_learned_patterns do
    case PatternStore.list_patterns(:technology, limit: 100) do
      {:ok, patterns} ->
        Enum.filter(patterns, &(&1.confidence > 0.5))

      {:error, reason} ->
        Logger.warning("Failed to fetch learned technology patterns: #{inspect(reason)}")
        []
    end
  end

  defp enhance_with_learned_patterns(hardcoded_results, learned_patterns) do
    Enum.map(hardcoded_results, fn result ->
      # Look up pattern in learned patterns
      case Enum.find(learned_patterns, &(&1.name == result.name)) do
        nil ->
          result

        learned ->
          # Use learned confidence if it's higher
          %{
            result
            | confidence: max(result.confidence, learned.confidence),
              learned: true
          }
      end
    end)
  end

  defp apply_learned_patterns(results, learned_patterns, path) do
    # Find learned patterns that match the path but weren't detected
    new_detections =
      learned_patterns
      |> Enum.reject(&Enum.any?(results, fn r -> r.name == &1.name end))
      |> Enum.filter(&pattern_matches_path?(&1, path))

    results ++ new_detections
  end

  defp pattern_matches_path?(_pattern, ""), do: false

  defp pattern_matches_path?(pattern, path) do
    # Try to match file patterns from the learned pattern
    file_patterns = Map.get(pattern, :file_patterns, [])
    directory_patterns = Map.get(pattern, :directory_patterns, [])
    config_files = Map.get(pattern, :config_files, [])

    all_patterns = (file_patterns ++ directory_patterns ++ config_files) |> Enum.uniq()

    # Check if any patterns match files in the path
    Enum.any?(all_patterns, &has_file?(path, &1))
  end

  # Private: Technology detection logic

  defp detect_technologies(path) do
    [
      detect_languages(path),
      detect_databases(path),
      detect_caching(path),
      detect_messaging(path),
      detect_ci_cd(path),
      detect_containers(path),
      # Phase 7: Dynamic infrastructure detection via registry cache
      detect_service_mesh(path),
      detect_api_gateways(path),
      detect_container_orchestration(path)
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end

  defp detect_languages(path) do
    # Use authoritative LanguageDetection (Rust NIF-backed registry)
    case LanguageDetection.detect(path) do
      {:ok, lang} when is_atom(lang) ->
        [
          %{
            name: language_name(lang),
            type: "language",
            confidence: 0.95,
            description: language_description(lang)
          }
        ]

      {:error, _} ->
        []
    end
  end

  defp detect_databases(path) do
    [
      detect_postgres(path),
      detect_mongodb(path),
      detect_redis(path),
      detect_mysql(path)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp detect_postgres(path) do
    if has_any_file?(path, ["docker-compose.yml", "docker-compose.yaml"]) &&
         contains_text?(path, "postgres") do
      %{
        name: "PostgreSQL",
        type: "database",
        confidence: 0.75,
        description: "PostgreSQL database"
      }
    else
      nil
    end
  end

  defp detect_mongodb(path) do
    if contains_dependency?(path, "mongodb") || contains_dependency?(path, "mongoose") do
      %{
        name: "MongoDB",
        type: "database",
        confidence: 0.80,
        description: "MongoDB NoSQL database"
      }
    else
      nil
    end
  end

  defp detect_redis(path) do
    if contains_dependency?(path, "redis") do
      %{
        name: "Redis",
        type: "cache",
        confidence: 0.85,
        description: "Redis cache"
      }
    else
      nil
    end
  end

  defp detect_mysql(path) do
    if has_any_file?(path, ["docker-compose.yml", "docker-compose.yaml"]) &&
         contains_text?(path, "mysql") do
      %{
        name: "MySQL",
        type: "database",
        confidence: 0.75,
        description: "MySQL database"
      }
    else
      nil
    end
  end

  defp detect_caching(path) do
    [
      if(contains_dependency?(path, "redis"), do: detect_redis(path)),
      if(contains_dependency?(path, "memcached"),
        do: %{
          name: "Memcached",
          type: "cache",
          confidence: 0.85,
          description: "Memcached cache"
        }
      )
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp detect_messaging(path) do
    [
      if(has_file?(path, "Singularity.Jobs.PgmqClient.js"),
        do: %{name: "pgmq", type: "messaging", confidence: 0.90, description: "pgmq messaging"}
      ),
      if(contains_dependency?(path, "amqp"),
        do: %{name: "RabbitMQ", type: "messaging", confidence: 0.75, description: "RabbitMQ"}
      ),
      if(contains_dependency?(path, "kafka"),
        do: %{name: "Kafka", type: "messaging", confidence: 0.80, description: "Apache Kafka"}
      )
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp detect_ci_cd(path) do
    [
      if(has_file?(path, ".github/workflows"),
        do: %{
          name: "GitHub Actions",
          type: "ci_cd",
          confidence: 0.95,
          description: "GitHub Actions CI/CD"
        }
      ),
      if(has_file?(path, ".gitlab-ci.yml"),
        do: %{name: "GitLab CI", type: "ci_cd", confidence: 0.98, description: "GitLab CI/CD"}
      ),
      if(has_file?(path, ".circleci/config.yml"),
        do: %{name: "CircleCI", type: "ci_cd", confidence: 0.98, description: "CircleCI"}
      ),
      if(has_file?(path, "Jenkinsfile"),
        do: %{name: "Jenkins", type: "ci_cd", confidence: 0.95, description: "Jenkins CI/CD"}
      )
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp detect_containers(path) do
    [
      if(has_file?(path, "Dockerfile"),
        do: %{
          name: "Docker",
          type: "container",
          confidence: 0.99,
          description: "Docker containerization"
        }
      ),
      if(has_file?(path, "docker-compose.yml") || has_file?(path, "docker-compose.yaml"),
        do: %{
          name: "Docker Compose",
          type: "container",
          confidence: 0.99,
          description: "Docker Compose"
        }
      ),
      if(has_file?(path, "k8s") || has_file?(path, "kubernetes"),
        do: %{
          name: "Kubernetes",
          type: "container",
          confidence: 0.90,
          description: "Kubernetes orchestration"
        }
      )
    ]
    |> Enum.reject(&is_nil/1)
  end

  # Phase 7: Infrastructure detection via registry cache

  defp detect_service_mesh(path) do
    alias Singularity.Architecture.InfrastructureRegistryCache

    case InfrastructureRegistryCache.get_registry() do
      {:ok, registry} ->
        meshes = registry["service_mesh"] || %{}

        meshes
        |> Enum.reduce([], fn {system_name, schema}, acc ->
          patterns = schema["detection_patterns"] || []

          if Enum.any?(patterns, &has_file?(path, &1)) do
            [
              %{
                name: system_name,
                type: "service_mesh",
                confidence: 0.80,
                description: schema["description"] || "Service mesh"
              }
              | acc
            ]
          else
            acc
          end
        end)

      {:error, _} ->
        []
    end
  end

  defp detect_api_gateways(path) do
    alias Singularity.Architecture.InfrastructureRegistryCache

    case InfrastructureRegistryCache.get_registry() do
      {:ok, registry} ->
        gateways = registry["api_gateways"] || %{}

        gateways
        |> Enum.reduce([], fn {system_name, schema}, acc ->
          patterns = schema["detection_patterns"] || []

          if Enum.any?(patterns, &has_file?(path, &1)) do
            [
              %{
                name: system_name,
                type: "api_gateway",
                confidence: 0.80,
                description: schema["description"] || "API gateway"
              }
              | acc
            ]
          else
            acc
          end
        end)

      {:error, _} ->
        []
    end
  end

  defp detect_container_orchestration(path) do
    alias Singularity.Architecture.InfrastructureRegistryCache

    case InfrastructureRegistryCache.get_registry() do
      {:ok, registry} ->
        orchestrators = registry["container_orchestration"] || %{}

        orchestrators
        |> Enum.reduce([], fn {system_name, schema}, acc ->
          patterns = schema["detection_patterns"] || []

          if Enum.any?(patterns, &has_file?(path, &1)) do
            [
              %{
                name: system_name,
                type: "container_orchestration",
                confidence: 0.85,
                description: schema["description"] || "Container orchestration"
              }
              | acc
            ]
          else
            acc
          end
        end)

      {:error, _} ->
        []
    end
  end

  # Helpers

  defp language_name(:typescript), do: "TypeScript"
  defp language_name(:javascript), do: "JavaScript"
  defp language_name(:rust), do: "Rust"
  defp language_name(:python), do: "Python"
  defp language_name(:go), do: "Go"
  defp language_name(:elixir), do: "Elixir"
  defp language_name(:java), do: "Java"
  defp language_name(:ruby), do: "Ruby"
  defp language_name(:php), do: "PHP"
  defp language_name(:cpp), do: "C++"
  defp language_name(other), do: Atom.to_string(other)

  defp language_description(:typescript), do: "TypeScript programming language"
  defp language_description(:javascript), do: "JavaScript programming language"
  defp language_description(:rust), do: "Rust programming language"
  defp language_description(:python), do: "Python programming language"
  defp language_description(:go), do: "Go programming language"
  defp language_description(:elixir), do: "Elixir programming language"
  defp language_description(:java), do: "Java programming language"
  defp language_description(:ruby), do: "Ruby programming language"
  defp language_description(:php), do: "PHP programming language"
  defp language_description(:cpp), do: "C++ programming language"
  defp language_description(_), do: "Programming language"

  defp has_file?(path, filename) do
    File.exists?(Path.join(path, filename))
  end

  defp has_any_file?(path, filenames) do
    Enum.any?(filenames, fn f -> has_file?(path, f) end)
  end

  defp contains_dependency?(path, dep_name) do
    package_json = Path.join(path, "package.json")

    if File.exists?(package_json) do
      case File.read(package_json) do
        {:ok, content} ->
          String.contains?(content, "\"#{dep_name}\"")

        {:error, _} ->
          false
      end
    else
      false
    end
  end

  defp contains_text?(path, text) do
    case File.ls(path) do
      {:ok, files} ->
        Enum.any?(files, fn f ->
          file_path = Path.join(path, f)

          if File.regular?(file_path) do
            case File.read(file_path) do
              {:ok, content} -> String.contains?(content, text)
              {:error, _} -> false
            end
          else
            false
          end
        end)

      {:error, _} ->
        false
    end
  end
end
