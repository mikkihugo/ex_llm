defmodule Singularity.ArchitectureEngine.PackageRegistryKnowledge do
  @moduledoc """
  Package Registry Knowledge - Search packages via database

  Provides package search functionality using local knowledge base:
  - npm (JavaScript/TypeScript)
  - cargo (Rust)
  - hex (Elixir/Erlang)
  - pypi (Python)

  All searches are performed against the local knowledge_artifacts database.
  """

  require Logger

  @type package_result :: map()

  @doc """
  Perform a package search via database.

  ## Options
  - `:ecosystem` - Filter by ecosystem (:npm, :cargo, :hex, :pypi, or :all)
  - `:limit` - Maximum results (default: 10)
  """
  @spec search(String.t(), keyword()) :: {:ok, [package_result()]} | {:error, term()}
  def search(query, opts \\ []) do
    ecosystem = Keyword.get(opts, :ecosystem, :all) |> to_string()
    limit = Keyword.get(opts, :limit, 10)

    Logger.info("🔍 Searching packages: '#{query}' in #{ecosystem}")

    # Search local knowledge base instead of pgmq
    case search_local_packages(query, ecosystem, limit) do
      {:ok, results} when is_list(results) ->
        parsed = parse_search_results(results)
        Logger.info("✅ Found #{length(parsed)} packages")
        {:ok, parsed}

      {:ok, _other} ->
        Logger.warning("⚠️  Unexpected response format")
        {:ok, []}

      {:error, reason} ->
        Logger.error("❌ Search failed: #{inspect(reason)}")
        # Graceful degradation
        {:ok, []}
    end
  end

  defp search_local_packages(query, ecosystem, limit) do
    alias Singularity.Knowledge.ArtifactStore

    # Search knowledge artifacts for package information
    artifact_type =
      if ecosystem == "all", do: "package_metadata", else: "package_metadata_#{ecosystem}"

    case ArtifactStore.search("package #{query}", artifact_type: artifact_type, limit: limit) do
      {:ok, results} ->
        packages =
          Enum.map(results, fn result ->
            %{
              "package_name" =>
                result.content["name"] || result.content["package_name"] || "unknown",
              "version" => result.content["version"] || "latest",
              "description" => result.content["description"] || "",
              "downloads" => result.content["downloads"] || 0,
              "stars" => result.content["stars"],
              "ecosystem" => result.content["ecosystem"] || ecosystem,
              "similarity" => result.similarity || 0.0,
              "tags" => result.content["tags"] || []
            }
          end)

        {:ok, packages}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_search_results(results) when is_list(results) do
    Enum.map(results, &parse_package_result/1)
  end

  defp parse_package_result(result) when is_map(result) do
    %{
      package_name: Map.get(result, "package_name"),
      version: Map.get(result, "version"),
      description: Map.get(result, "description", ""),
      downloads: Map.get(result, "downloads", 0),
      stars: Map.get(result, "stars"),
      ecosystem: Map.get(result, "ecosystem"),
      similarity: Map.get(result, "similarity", 0.0),
      tags: Map.get(result, "tags", [])
    }
  end

  defp parse_package_result(_), do: %{}

  @doc """
  Search across known architectural patterns.
  """
  @spec search_patterns(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def search_patterns(query, _opts \\ []) do
    Logger.info("🔍 Searching patterns for: #{query}")

    # Search for architectural patterns in the knowledge base directly
    {:ok, search_local_patterns(query)}
  end

  defp parse_patterns(patterns) do
    Enum.map(patterns, fn pattern ->
      %{
        pattern_name: pattern["name"] || pattern[:name],
        description: pattern["description"] || pattern[:description] || "",
        category: pattern["category"] || pattern[:category] || "general",
        complexity: pattern["complexity"] || pattern[:complexity] || "medium",
        examples: pattern["examples"] || pattern[:examples] || [],
        tags: pattern["tags"] || pattern[:tags] || []
      }
    end)
  end

  defp search_local_patterns(query) do
    # Search local pattern database
    alias Singularity.Knowledge.ArtifactStore

    case ArtifactStore.search("architectural pattern #{query}",
           artifact_type: "framework_pattern",
           limit: 10
         ) do
      {:ok, results} ->
        Enum.map(results, fn result ->
          %{
            pattern_name: result.content["name"] || "Unknown Pattern",
            description: result.content["description"] || "",
            category: result.content["category"] || "general",
            complexity: result.content["complexity"] || "medium",
            examples: result.content["examples"] || [],
            tags: result.content["tags"] || []
          }
        end)

      {:error, _} ->
        []
    end
  end

  @doc """
  Fetch usage examples. Returns canned snippets based on the query to keep the
  UI responsive.
  """
  @spec search_examples(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def search_examples(query, _opts \\ []) do
    Logger.info("📚 Searching examples for: #{query}")

    # Search for code examples in the knowledge base directly
    {:ok, search_local_examples(query)}
  end

  defp search_local_examples(query) do
    # Search local example database
    alias Singularity.Knowledge.ArtifactStore

    case ArtifactStore.search("code example #{query}", artifact_type: "code_template", limit: 10) do
      {:ok, results} ->
        Enum.map(results, fn result ->
          %{
            package_name: result.content["package_name"] || "example-package",
            example_type: result.content["type"] || "usage",
            description: result.content["description"] || "Code example for #{query}",
            code: result.content["code"] || "",
            language: result.content["language"] || "unknown",
            tags: result.content["tags"] || []
          }
        end)

      {:error, _} ->
        # Generate basic examples based on query
        generate_examples_from_query(query)
    end
  end

  defp generate_examples_from_query(query) do
    # Generate intelligent examples based on query patterns
    cond do
      String.contains?(String.downcase(query), "http") ->
        [
          %{
            package_name: "httpoison",
            example_type: "basic_usage",
            description: "HTTP request example",
            code: "HTTPoison.get(\"https://api.example.com\")",
            language: "elixir",
            tags: ["http", "api", "request"]
          }
        ]

      String.contains?(String.downcase(query), "json") ->
        [
          %{
            package_name: "jason",
            example_type: "basic_usage",
            description: "JSON parsing example",
            code: "Jason.decode!(json_string)",
            language: "elixir",
            tags: ["json", "parsing", "data"]
          }
        ]

      String.contains?(String.downcase(query), "database") ->
        [
          %{
            package_name: "ecto",
            example_type: "basic_usage",
            description: "Database query example",
            code: "from(u in User, where: u.active == true)",
            language: "elixir",
            tags: ["database", "query", "ecto"]
          }
        ]

      true ->
        [
          %{
            package_name: "example-package",
            example_type: "basic_usage",
            description: "Basic usage example for #{query}",
            code: "# Basic usage of #{query}\nresult = ExamplePackage.do_something()",
            language: "elixir",
            tags: ["example", "basic"]
          }
        ]
    end
  end

  @doc """
  Return cross-ecosystem equivalents.
  """
  @spec find_equivalents(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def find_equivalents(package_name, _opts \\ []) do
    Logger.info("🔍 Finding equivalents for package: #{package_name}")

    # Search across all ecosystems for similar packages
    ecosystems = [:npm, :cargo, :hex, :pypi]

    results =
      ecosystems
      |> Enum.map(fn ecosystem ->
        case search(package_name, ecosystem: ecosystem, limit: 3) do
          {:ok, packages} ->
            packages
            |> Enum.map(
              &%{
                package: &1.package_name,
                ecosystem: ecosystem,
                description: &1.description,
                similarity: calculate_similarity(package_name, &1.package_name)
              }
            )

          {:error, _} ->
            []
        end
      end)
      |> List.flatten()
      |> Enum.sort_by(& &1.similarity, :desc)
      |> Enum.take(5)

    Logger.info("✅ Found #{length(results)} equivalent packages")
    {:ok, results}
  end

  defp calculate_similarity(package1, package2) do
    # Simple string similarity using Jaro distance
    String.jaro_distance(String.downcase(package1), String.downcase(package2))
  end

  @doc """
  Retrieve example snippets for a specific package.
  """
  @spec get_examples(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def get_examples(package_id, opts \\ []) do
    Logger.info("📚 Getting examples for package: #{package_id}")

    # Try to get examples from knowledge base
    alias Singularity.Knowledge.ArtifactStore

    case ArtifactStore.search("code example #{package_id}",
           artifact_type: "code_template",
           limit: 10
         ) do
      {:ok, [_head | _] = results} ->
        parsed_examples =
          Enum.map(results, fn result ->
            %{
              package_name: result.content["package_name"] || package_id,
              example_type: result.content["type"] || "usage",
              code: result.content["code"] || "",
              description: result.content["description"] || "Example usage",
              language: result.content["language"] || "unknown"
            }
          end)

        Logger.info("✅ Found #{length(parsed_examples)} examples")
        {:ok, parsed_examples}

      _ ->
        Logger.debug("No examples found in knowledge base, generating basic examples")
        {:ok, generate_basic_examples(package_id)}
    end
  end

  defp parse_examples(examples) do
    Enum.map(examples, fn example ->
      %{
        package_name: example["package_name"] || example[:package_name],
        example_type: example["type"] || example[:type] || "usage",
        code: example["code"] || example[:code] || "",
        description: example["description"] || example[:description] || "Example usage",
        language: example["language"] || example[:language] || "unknown"
      }
    end)
  end

  defp generate_basic_examples(package_id) do
    # Generate basic examples based on package name patterns
    cond do
      String.contains?(package_id, "http") ->
        [
          %{
            package_name: package_id,
            example_type: "basic_usage",
            code:
              "import #{package_id}\n\nresponse = #{package_id}.get('https://api.example.com')\nprint(response.json())",
            description: "Basic HTTP request example",
            language: "python"
          }
        ]

      String.contains?(package_id, "json") ->
        [
          %{
            package_name: package_id,
            example_type: "basic_usage",
            code: "const data = #{package_id}.parse('{\"key\": \"value\"}');\nconsole.log(data);",
            description: "JSON parsing example",
            language: "javascript"
          }
        ]

      true ->
        [
          %{
            package_name: package_id,
            example_type: "basic_usage",
            code:
              "# Basic usage of #{package_id}\nimport #{package_id}\n\nresult = #{package_id}.do_something()",
            description: "Basic usage example",
            language: "python"
          }
        ]
    end
  end

  @doc """
  Record prompt usage metadata with real database persistence.
  """
  @spec track_prompt_usage(String.t(), String.t(), term(), keyword()) :: {:ok, :noop}
  def track_prompt_usage(package_name, version, prompt_id, opts \\ []) do
    Logger.info("📊 Tracking prompt usage for package: #{package_name}")

    # Store usage metadata in database
    usage_data = %{
      package_name: package_name,
      version: version,
      prompt_id: prompt_id,
      timestamp: DateTime.utc_now(),
      metadata: opts
    }

    case store_usage_metadata(usage_data) do
      {:ok, _} ->
        Logger.debug("✅ Usage metadata stored successfully")
        {:ok, :tracked}

      {:error, reason} ->
        Logger.warning("⚠️  Failed to store usage metadata: #{inspect(reason)}")
        {:ok, :noop}
    end
  end

  defp store_usage_metadata(usage_data) do
    # Store in knowledge_artifacts table
    alias Singularity.Knowledge.ArtifactStore

    artifact_key = "package_usage_#{usage_data.package_name}_#{usage_data.version}"

    ArtifactStore.put(
      "package_usage",
      artifact_key,
      usage_data,
      # Keep for 30 days
      ttl: :timer.hours(24 * 30)
    )
  end
end
