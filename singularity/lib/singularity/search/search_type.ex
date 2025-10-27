defmodule Singularity.Search.SearchType do
  @moduledoc """
  Search Type Behavior - Contract for all code search operations.

  Defines the interface that all search implementations (semantic, hybrid, AST, package, etc.)
  must implement to be used with the config-driven `SearchOrchestrator`.

  Consolidates scattered search implementations (CodeSearch, HybridCodeSearch, AstGrepCodeSearch,
  PackageAndCodebaseSearch, etc.) into a unified system with consistent configuration and
  orchestration.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Search.SearchType",
    "purpose": "Behavior contract for config-driven search orchestration",
    "type": "behavior/protocol",
    "layer": "search",
    "status": "production"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      Config["Config: search_types"]
      Orchestrator["SearchOrchestrator"]
      Behavior["SearchType Behavior"]

      Config -->|enabled: true| Search1["SemanticSearch"]
      Config -->|enabled: true| Search2["HybridSearch"]
      Config -->|enabled: true| Search3["AstSearch"]
      Config -->|enabled: true| Search4["PackageSearch"]

      Orchestrator -->|discover| Behavior
      Behavior -->|implemented by| Search1
      Behavior -->|implemented by| Search2
      Behavior -->|implemented by| Search3
      Behavior -->|implemented by| Search4

      Search1 -->|search/2| Results1["Semantic Results"]
      Search2 -->|search/2| Results2["Hybrid Results"]
      Search3 -->|search/2| Results3["AST Results"]
      Search4 -->|search/2| Results4["Package Results"]
  ```

  ## Configuration Example

  ```elixir
  # config/config.exs
  config :singularity, :search_types,
    semantic: %{
      module: Singularity.Search.Searchers.SemanticSearch,
      enabled: true,
      description: "Semantic search using embeddings and pgvector"
    },
    hybrid: %{
      module: Singularity.Search.Searchers.HybridSearch,
      enabled: true,
      description: "Hybrid search combining FTS and semantic"
    },
    ast: %{
      module: Singularity.Search.Searchers.AstSearch,
      enabled: false,
      description: "AST-based search using tree-sitter"
    },
    package: %{
      module: Singularity.Search.Searchers.PackageSearch,
      enabled: true,
      description: "Package registry search combined with codebase RAG"
    }
  ```

  ## Anti-Patterns (Prevents Duplicates)

  - ❌ **DO NOT** create hardcoded search lists
  - ❌ **DO NOT** scatter search implementations across directories
  - ❌ **DO NOT** call search modules directly instead of through orchestrator
  - ✅ **DO** always use `SearchOrchestrator.search/2` which routes through config
  - ✅ **DO** add new search types only via config, not code
  - ✅ **DO** implement search as `@behaviour SearchType` modules

  ## Search Keywords

  search, semantic search, code search, embeddings, pgvector, full-text search,
  hybrid search, AST search, package search, code discovery, similarity search,
  vector similarity, ranking, relevance
  """

  require Logger

  @doc """
  Returns the atom identifier for this search type.

  Examples: `:semantic`, `:hybrid`, `:ast`, `:package`
  """
  @callback search_type() :: atom()

  @doc """
  Returns human-readable description of what this search does.
  """
  @callback description() :: String.t()

  @doc """
  Returns list of search capabilities this implementation provides.

  Examples: `["natural_language", "similarity", "fuzzy_matching"]`
  """
  @callback capabilities() :: [String.t()]

  @doc """
  Execute a search query.

  Returns list of search results: `[%{path: string, similarity: float, ...}]`
  """
  @callback search(query :: String.t(), _opts :: Keyword.t()) :: {:ok, [map()]} | {:error, term()}

  @doc """
  Learn from search results to improve future searches.

  Called after search to update ranking/relevance based on results.
  """
  @callback learn_from_search(result :: map()) :: :ok | {:error, term()}

  # Config loading helpers

  @doc """
  Load all enabled search types from config.

  Returns: `[{search_type, config_map}, ...]`
  """
  def load_enabled_searches do
    :singularity
    |> Application.get_env(:search_types, %{})
    |> Enum.filter(fn {_type, config} -> config[:enabled] == true end)
    |> Enum.to_list()
  end

  @doc """
  Check if a specific search type is enabled.
  """
  def enabled?(search_type) when is_atom(search_type) do
    searches = load_enabled_searches()
    Enum.any?(searches, fn {type, _config} -> type == search_type end)
  end

  @doc """
  Get the module implementing a specific search type.
  """
  def get_search_module(search_type) when is_atom(search_type) do
    case Application.get_env(:singularity, :search_types, %{})[search_type] do
      %{module: module} -> {:ok, module}
      nil -> {:error, :search_not_configured}
      _ -> {:error, :invalid_config}
    end
  end

  @doc """
  Get description for a specific search type.
  """
  def get_description(search_type) when is_atom(search_type) do
    case get_search_module(search_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) do
          module.description()
        else
          "Unknown search"
        end

      {:error, _} ->
        "Unknown search"
    end
  end
end
