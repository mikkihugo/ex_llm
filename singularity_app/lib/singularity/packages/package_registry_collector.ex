defmodule Singularity.PackageRegistryCollector do
  @moduledoc """
  Bridge between Rust package_registry_indexer collectors and Elixir PackageRegistryKnowledge

  This module calls Rust collectors to download and analyze packages,
  then stores the results in PostgreSQL package registry tables.

  ## Architecture:

      Rust Collectors              Elixir Bridge                PostgreSQL
      ───────────────              ─────────────                ──────────
      CargoCollector    ───>       collect_and_store           dependency_catalog
      NpmCollector                 FactData → Schema           dependency_catalog_examples
      HexCollector                                             dependency_catalog_patterns

  ## Usage:

      # Collect a single package
      ToolCollectorBridge.collect_package("tokio", "1.35.0", ecosystem: :cargo)

      # Collect from manifest
      ToolCollectorBridge.collect_from_manifest("Cargo.toml")
      ToolCollectorBridge.collect_from_manifest("package.json")
      ToolCollectorBridge.collect_from_manifest("mix.exs")

      # Collect popular packages
      ToolCollectorBridge.collect_popular(:npm, limit: 100)
      ToolCollectorBridge.collect_popular(:cargo, limit: 100)
  """

  require Logger
  alias Singularity.PackageRegistryKnowledge

  # Path to Rust package_registry_indexer binary
  @package_registry_indexer_bin Path.join([
                                  __DIR__,
                                  "..",
                                  "..",
                                  "..",
                                  "rust",
                                  "package_registry_indexer",
                                  "target",
                                  "release",
                                  "package-registry-indexer"
                                ])

  @doc """
  Collect a package from a registry and store in PostgreSQL
  """
  def collect_package(package_name, version, opts \\ []) do
    ecosystem = Keyword.get(opts, :ecosystem, :cargo) |> Atom.to_string()

    Logger.info("Collecting #{package_name}@#{version} from #{ecosystem}")

    # Call Rust collector
    case call_rust_collector(package_name, version, ecosystem) do
      {:ok, fact_data} ->
        # Parse and store in PostgreSQL
        store_fact_data(fact_data, package_name, version, ecosystem)

      {:error, reason} ->
        Logger.error("Failed to collect #{package_name}@#{version}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Collect dependencies from a manifest file (Cargo.toml, package.json, mix.exs)
  """
  def collect_from_manifest(manifest_path) do
    case parse_manifest(manifest_path) do
      {:ok, {ecosystem, dependencies}} ->
        Logger.info("Found #{length(dependencies)} dependencies in #{manifest_path}")

        # Collect each dependency in parallel
        dependencies
        |> Task.async_stream(
          fn {name, version} ->
            collect_package(name, version, ecosystem: ecosystem)
          end,
          max_concurrency: 5,
          timeout: 60_000
        )
        |> Enum.to_list()

      {:error, reason} ->
        Logger.error("Failed to parse manifest #{manifest_path}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Collect popular packages from a registry
  """
  def collect_popular(ecosystem, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    Logger.info("Collecting top #{limit} packages from #{ecosystem}")

    # Get popular packages from registry
    case get_popular_packages(ecosystem, limit) do
      {:ok, packages} ->
        # Collect each package
        packages
        |> Task.async_stream(
          fn {name, version} ->
            collect_package(name, version, ecosystem: ecosystem)
          end,
          max_concurrency: 10,
          timeout: 120_000
        )
        |> Enum.to_list()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Refresh a package (re-download and update)
  """
  def refresh_package(package_name, opts \\ []) do
    ecosystem = Keyword.get(opts, :ecosystem, :cargo)

    # Get latest version
    case get_latest_version(package_name, ecosystem) do
      {:ok, version} ->
        collect_package(package_name, version, ecosystem: ecosystem)

      {:error, reason} ->
        {:error, reason}
    end
  end

  ## Private Functions

  defp call_rust_collector(package_name, version, ecosystem) do
    # Call Rust package_registry_indexer CLI
    # Format: package-registry-indexer collect --tool tokio --version 1.35.0 --ecosystem cargo --format json
    args = [
      "collect",
      "--tool",
      package_name,
      "--version",
      version,
      "--ecosystem",
      ecosystem,
      "--format",
      "json"
    ]

    case System.cmd(@package_registry_indexer_bin, args, stderr_to_stdout: true) do
      {output, 0} ->
        # Parse JSON output
        case Jason.decode(output) do
          {:ok, fact_data} ->
            {:ok, fact_data}

          {:error, reason} ->
            {:error, "Failed to parse JSON: #{inspect(reason)}"}
        end

      {error_output, exit_code} ->
        {:error, "Rust collector failed (exit #{exit_code}): #{error_output}"}
    end
  rescue
    error ->
      {:error, "Failed to call Rust collector: #{inspect(error)}"}
  end

  defp store_fact_data(fact_data, package_name, version, ecosystem) do
    Logger.info("Storing FactData for #{package_name}@#{version}")

    # Generate embeddings
    description = get_in(fact_data, ["description"]) || ""
    {:ok, description_embedding} = Singularity.EmbeddingGenerator.embed(description)

    # Build semantic text for embedding (description + keywords + tags)
    semantic_text = build_semantic_text(fact_data)
    {:ok, semantic_embedding} = Singularity.EmbeddingGenerator.embed(semantic_text)

    # Upsert tool
    tool_attrs = %{
      package_name: package_name,
      version: version,
      ecosystem: ecosystem,
      description: description,
      documentation: get_in(fact_data, ["documentation"]),
      homepage_url: get_in(fact_data, ["homepage_url"]),
      repository_url: get_in(fact_data, ["repository_url"]),
      license: get_in(fact_data, ["license"]),
      tags: get_in(fact_data, ["tags"]) || [],
      categories: get_in(fact_data, ["categories"]) || [],
      keywords: get_in(fact_data, ["keywords"]) || [],
      semantic_embedding: semantic_embedding,
      description_embedding: description_embedding,
      download_count: get_in(fact_data, ["download_count"]) || 0,
      github_stars: get_in(fact_data, ["github_stars"]),
      last_release_date: parse_datetime(get_in(fact_data, ["last_release_date"])),
      source_url: get_in(fact_data, ["source_url"]),
      collected_at: DateTime.utc_now(),
      last_updated_at: DateTime.utc_now()
    }

    case PackageRegistryKnowledge.upsert_tool(tool_attrs) do
      {:ok, tool} ->
        # Store examples
        store_examples(tool.id, fact_data)

        # Store patterns
        store_patterns(tool.id, fact_data)

        # Store dependencies
        store_dependencies(tool.id, fact_data)

        Logger.info("Successfully stored #{package_name}@#{version}")
        {:ok, tool}

      {:error, changeset} ->
        Logger.error("Failed to store tool: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  defp store_examples(tool_id, fact_data) do
    snippets = get_in(fact_data, ["snippets"]) || []

    snippets
    |> Enum.with_index()
    |> Enum.each(fn {snippet, index} ->
      code = get_in(snippet, ["code"]) || ""
      {:ok, code_embedding} = Singularity.EmbeddingGenerator.embed(code)

      example_attrs = %{
        tool_id: tool_id,
        title: get_in(snippet, ["title"]) || "Example #{index + 1}",
        code: code,
        language: get_in(snippet, ["language"]),
        explanation: get_in(snippet, ["description"]),
        tags: get_in(snippet, ["tags"]) || [],
        code_embedding: code_embedding,
        example_order: index
      }

      PackageRegistryKnowledge.upsert_example(example_attrs)
    end)
  end

  defp store_patterns(tool_id, fact_data) do
    patterns = get_in(fact_data, ["patterns"]) || []

    patterns
    |> Enum.each(fn pattern ->
      pattern_text = get_in(pattern, ["description"]) || ""
      {:ok, pattern_embedding} = Singularity.EmbeddingGenerator.embed(pattern_text)

      pattern_attrs = %{
        tool_id: tool_id,
        pattern_type: get_in(pattern, ["pattern_type"]) || "usage_pattern",
        title: get_in(pattern, ["title"]) || "Pattern",
        description: pattern_text,
        code_example: get_in(pattern, ["code_example"]),
        tags: get_in(pattern, ["tags"]) || [],
        pattern_embedding: pattern_embedding
      }

      PackageRegistryKnowledge.upsert_pattern(pattern_attrs)
    end)
  end

  defp store_dependencies(tool_id, fact_data) do
    dependencies = get_in(fact_data, ["dependencies"]) || []

    dependencies
    |> Enum.each(fn dep ->
      dep_attrs = %{
        tool_id: tool_id,
        dependency_name: get_in(dep, ["name"]),
        dependency_version: get_in(dep, ["version"]),
        dependency_type: get_in(dep, ["type"]) || "runtime",
        is_optional: get_in(dep, ["optional"]) || false
      }

      PackageRegistryKnowledge.upsert_dependency(dep_attrs)
    end)
  end

  defp build_semantic_text(fact_data) do
    description = get_in(fact_data, ["description"]) || ""
    keywords = get_in(fact_data, ["keywords"]) || []
    tags = get_in(fact_data, ["tags"]) || []
    categories = get_in(fact_data, ["categories"]) || []

    ([description] ++ keywords ++ tags ++ categories)
    |> Enum.join(" ")
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _offset} -> datetime
      {:error, _} -> nil
    end
  end

  defp parse_manifest(manifest_path) do
    cond do
      String.ends_with?(manifest_path, "Cargo.toml") ->
        parse_cargo_toml(manifest_path)

      String.ends_with?(manifest_path, "package.json") ->
        parse_package_json(manifest_path)

      String.ends_with?(manifest_path, "mix.exs") ->
        parse_mix_exs(manifest_path)

      true ->
        {:error, "Unsupported manifest type: #{manifest_path}"}
    end
  end

  defp parse_cargo_toml(path) do
    # Parse Cargo.toml using Rust TOML parser or Elixir library
    # For now, simple string parsing (in production, use proper TOML parser)
    case File.read(path) do
      {:ok, content} ->
        # Extract dependencies (very simplified - use proper TOML parser in production)
        dependencies = extract_cargo_dependencies(content)
        {:ok, {:cargo, dependencies}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_package_json(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, package_data} ->
            dependencies = extract_npm_dependencies(package_data)
            {:ok, {:npm, dependencies}}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_mix_exs(path) do
    # Parse mix.exs (Elixir AST)
    case File.read(path) do
      {:ok, content} ->
        # In production, properly parse Elixir AST
        dependencies = extract_mix_dependencies(content)
        {:ok, {:hex, dependencies}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_cargo_dependencies(content) do
    # Very simplified - use proper TOML parser in production
    content
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "="))
    |> Enum.map(fn line ->
      case String.split(line, "=", parts: 2) do
        [name, version] ->
          name = String.trim(name)
          version = String.trim(version) |> String.replace(~r/["']/, "")
          {name, version}

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_npm_dependencies(package_data) do
    dependencies = Map.get(package_data, "dependencies", %{})
    dev_dependencies = Map.get(package_data, "devDependencies", %{})

    Map.merge(dependencies, dev_dependencies)
    |> Enum.map(fn {name, version} -> {name, version} end)
  end

  defp extract_mix_dependencies(_content) do
    # Very simplified - properly parse Elixir AST in production
    []
  end

  defp get_popular_packages(:cargo, limit) do
    # Call crates.io API for popular crates
    url = "https://crates.io/api/v1/crates?page=1&per_page=#{limit}&sort=downloads"

    case Req.get(url, headers: [{"User-Agent", "Singularity/1.0"}]) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"crates" => crates}} ->
            packages =
              Enum.map(crates, fn crate ->
                {crate["name"], crate["newest_version"]}
              end)

            {:ok, packages}

          {:error, reason} ->
            {:error, reason}
        end

      {:ok, %{status_code: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_popular_packages(:npm, limit) do
    # Call npm API for popular packages
    # npm doesn't have a simple "popular" endpoint, so we'd use npms.io
    url = "https://api.npms.io/v2/search?q=boost-exact:false&size=#{limit}"

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"results" => results}} ->
            packages =
              Enum.map(results, fn result ->
                package = result["package"]
                {package["name"], package["version"]}
              end)

            {:ok, packages}

          {:error, reason} ->
            {:error, reason}
        end

      {:ok, %{status_code: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_popular_packages(:hex, limit) do
    # Call hex.pm API for popular packages
    url = "https://hex.pm/api/packages?sort=downloads&page=1"

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, packages} ->
            popular =
              packages
              |> Enum.take(limit)
              |> Enum.map(fn package ->
                {package["name"], package["latest_stable_version"] || package["latest_version"]}
              end)

            {:ok, popular}

          {:error, reason} ->
            {:error, reason}
        end

      {:ok, %{status_code: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_latest_version(package_name, :cargo) do
    url = "https://crates.io/api/v1/crates/#{package_name}"

    case Req.get(url, headers: [{"User-Agent", "Singularity/1.0"}]) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"crate" => %{"newest_version" => version}}} ->
            {:ok, version}

          {:error, reason} ->
            {:error, reason}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_latest_version(package_name, :npm) do
    url = "https://registry.npmjs.org/#{package_name}/latest"

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"version" => version}} ->
            {:ok, version}

          {:error, reason} ->
            {:error, reason}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_latest_version(package_name, :hex) do
    url = "https://hex.pm/api/packages/#{package_name}"

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"latest_stable_version" => version}} when not is_nil(version) ->
            {:ok, version}

          {:ok, %{"latest_version" => version}} ->
            {:ok, version}

          {:error, reason} ->
            {:error, reason}
        end

      {:ok, %{status_code: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
