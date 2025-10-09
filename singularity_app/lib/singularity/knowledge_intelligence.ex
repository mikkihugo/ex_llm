defmodule Singularity.KnowledgeIntelligence do
  @moduledoc """
  Knowledge Intelligence - Fast local NIF for knowledge caching

  Client-side NIF that provides ultra-fast access to knowledge assets
  (patterns, templates, prompts, intelligence modules).

  ## Architecture

  ```
  knowledge_engine/          # Shared Rust lib (core logic)
  knowledge_intelligence/    # This NIF (client-side, fast)
  knowledge_central_service/ # Central NATS daemon (distribution)
  ```

  ## Usage

      # Load asset from local cache
      {:ok, asset} = KnowledgeIntelligence.load_asset("phoenix-liveview-pattern")

      # Save asset to local cache
      asset = %{
        id: "new-pattern",
        asset_type: "pattern",
        data: Jason.encode!(%{...}),
        metadata: %{"language" => "elixir"},
        version: 1
      }
      KnowledgeIntelligence.save_asset(asset)

      # Get cache statistics
      stats = KnowledgeIntelligence.get_stats()
      # => %{total_entries: 42, patterns: 15, templates: 20, ...}

      # Search by type
      patterns = KnowledgeIntelligence.search_by_type("pattern")
  """

  use Rustler,
    otp_app: :singularity,
    crate: :knowledge_engine,
    skip_compilation?: true

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Load asset from local cache.

  Returns `{:ok, asset}` if found, `{:ok, nil}` if not found.
  """
  def load_asset(_id), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Save asset to local cache.

  Returns `{:ok, asset_id}` on success.
  """
  def save_asset(_asset), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Get cache statistics.

  Returns stats map with counts by asset type.
  """
  def get_stats(), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Clear entire local cache.

  Returns number of entries cleared.
  """
  def clear_cache(), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Search assets by type.

  Returns list of assets matching the type.
  """
  def search_by_type(_asset_type), do: :erlang.nif_error(:nif_not_loaded)
end
