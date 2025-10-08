defmodule Singularity.PackageRegistryKnowledge do
  @moduledoc """
  Stubbed package-registry knowledge base.

  The original implementation depended on several external services and Rust
  NIFs that are not included in this repository snapshot. To keep the rest of
  the application compiling (and to make callers resilient), this module now
  returns lightweight placeholder data while logging the requests.

  When the full feature set is reinstated, these functions can be swapped back
  to their real implementations without touching the rest of the code.
  """

  require Logger

  @type package_result :: map()

  @doc """
  Perform a package search. Returns an empty list placeholder.
  """
  @spec search(String.t(), keyword()) :: {:ok, [package_result()]} | {:error, term()}
  def search(query, opts \\ []) do
    Logger.debug("[PackageRegistryKnowledge] search/2 placeholder", query: query, opts: opts)
    {:ok, []}
  end

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
