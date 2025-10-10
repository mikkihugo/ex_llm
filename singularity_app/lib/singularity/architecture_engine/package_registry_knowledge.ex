defmodule Singularity.ArchitectureEngine.PackageRegistryKnowledge do
  @moduledoc """
  Package Registry Knowledge - Search packages via NATS

  Communicates with Rust package_lib collectors via NATS to search:
  - npm (JavaScript/TypeScript)
  - cargo (Rust)
  - hex (Elixir/Erlang)
  - pypi (Python)

  NATS Subjects:
  - packages.registry.search - Search all ecosystems
  - packages.registry.collect.npm - Collect npm package
  - packages.registry.collect.cargo - Collect cargo package
  - packages.registry.collect.hex - Collect hex package
  """

  require Logger

  @type package_result :: map()

  @doc """
  Perform a package search via NATS.

  ## Options
  - `:ecosystem` - Filter by ecosystem (:npm, :cargo, :hex, :pypi, or :all)
  - `:limit` - Maximum results (default: 10)
  """
  @spec search(String.t(), keyword()) :: {:ok, [package_result()]} | {:error, term()}
  def search(query, opts \\ []) do
    ecosystem = Keyword.get(opts, :ecosystem, :all) |> to_string()
    limit = Keyword.get(opts, :limit, 10)

    Logger.info("🔍 Searching packages: '#{query}' in #{ecosystem}")

    request = %{
      "query" => query,
      "ecosystem" => ecosystem,
      "limit" => limit
    }

    case call_nats("packages.registry.search", request) do
      {:ok, results} when is_list(results) ->
        parsed = parse_search_results(results)
        Logger.info("✅ Found #{length(parsed)} packages")
        {:ok, parsed}

      {:ok, _other} ->
        Logger.warn("⚠️  Unexpected response format")
        {:ok, []}

      {:error, :timeout} ->
        Logger.warn("⏱️  Search timed out")
        {:ok, []}

      {:error, reason} ->
        Logger.error("❌ Search failed: #{inspect(reason)}")
        {:ok, []}  # Graceful degradation
    end
  end

  defp call_nats(subject, request) do
    case Singularity.NatsOrchestrator.request(subject, request, timeout: 10_000) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error ->
      Logger.error("NATS call exception: #{inspect(error)}")
      {:error, :exception}
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
  def search_patterns(query, opts \\ []) do
    Logger.debug("[PackageRegistryKnowledge] search_patterns/2 placeholder",
      query: query,
      opts: opts
    )

    {:ok, []}
  end

  @doc """
  Fetch usage examples. Returns canned snippets based on the query to keep the
  UI responsive.
  """
  @spec search_examples(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def search_examples(query, opts \\ []) do
    Logger.debug("[PackageRegistryKnowledge] search_examples/2 placeholder",
      query: query,
      opts: opts
    )

    {:ok,
     [%{
        package_name: "example-package",
        example_type: "placeholder",
        description: "Placeholder example for '#{query}'",
        code: "// TODO: integrate real examples",
        tags: []
      }]}
  end

  @doc """
  Return cross-ecosystem equivalents.
  """
  @spec find_equivalents(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def find_equivalents(package_name, opts \\ []) do
    Logger.debug("[PackageRegistryKnowledge] find_equivalents/2 placeholder",
      package_name: package_name,
      opts: opts
    )

    {:ok,
     [%{
        package: package_name,
        equivalents: [],
        note: "Real equivalents unavailable in stub mode"
      }]}
  end

  @doc """
  Retrieve example snippets for a specific package.
  """
  @spec get_examples(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def get_examples(package_id, opts \\ []) do
    Logger.debug("[PackageRegistryKnowledge] get_examples/2 placeholder",
      package_id: package_id,
      opts: opts
    )

    {:ok,
     [%{
        package_name: package_id,
        example_type: "getting_started",
        code: "// Placeholder example",
        description: "Example data unavailable in stub"
      }]}
  end

  @doc """
  Record prompt usage metadata. In stub mode we just log and return :ok.
  """
  @spec track_prompt_usage(String.t(), String.t(), term(), keyword()) :: {:ok, :noop}
  def track_prompt_usage(package_name, version, prompt_id, opts \\ []) do
    Logger.debug("[PackageRegistryKnowledge] track_prompt_usage/4 placeholder",
      package: package_name,
      version: version,
      prompt_id: prompt_id,
      opts: opts
    )

    {:ok, :noop}
  end
end
