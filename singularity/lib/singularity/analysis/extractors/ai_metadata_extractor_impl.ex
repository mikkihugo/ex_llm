defmodule Singularity.Analysis.Extractors.AIMetadataExtractorImpl do
  @moduledoc """
  AIMetadataExtractor Wrapper - Implements ExtractorType behavior for AI metadata extraction

  Wraps Singularity.Code.AIMetadataExtractor into unified ExtractorType behavior.

  ## Module Identity

  ```json
  {
    "module": "Singularity.Analysis.Extractors.AIMetadataExtractorImpl",
    "purpose": "Unified interface for extracting AI navigation metadata from @moduledoc",
    "role": "extractor",
    "layer": "analysis",
    "alternatives": {
      "Code.AIMetadataExtractor": "Direct module - use when not using ExtractorType system"
    },
    "disambiguation": {
      "vs_direct": "Impl = ExtractorType-compliant wrapper. Direct = Plain Elixir module"
    }
  }
  ```

  ## Call Graph

  ```yaml
  calls_out:
    - module: Singularity.Code.AIMetadataExtractor
      function: extract/1
      purpose: Extract all AI metadata from source
      critical: true

  called_by:
    - module: UnifiedMetadataExtractor
      purpose: Coordinated metadata extraction
      frequency: high

  depends_on:
    - Singularity.Code.AIMetadataExtractor (implementation)

  supervision:
    supervised: false
    reason: "Stateless utility module"
  ```

  ## Anti-Patterns

  ### ❌ DO NOT create "MetadataExtractorWrapper"
  **Why:** This module already wraps AIMetadataExtractor!
  **Use instead:** This module via ExtractorType system

  ### ❌ DO NOT call AIMetadataExtractor.extract/1 directly in new code
  **Use instead:** Call via ExtractorType behavior:
  ```elixir
  ExtractorType.get_extractor_module(:ai_metadata)
  |> then(fn {:ok, module} -> module.extract(source) end)
  ```

  ## Search Keywords

  ai metadata extractor, moduledoc parser, json extraction, yaml extraction, mermaid extraction,
  metadata wrapper, extractor type, unified interface, documentation analyzer
  """

  @behaviour Singularity.Analysis.ExtractorType
  require Logger
  alias Singularity.Code.AIMetadataExtractor

  @impl true
  def extractor_type, do: :ai_metadata

  @impl true
  def description do
    "Extract AI navigation metadata (JSON/YAML/Mermaid/Markdown/Keywords) from @moduledoc"
  end

  @impl true
  def capabilities do
    [
      "module_identity_json",
      "call_graph_yaml",
      "mermaid_diagrams",
      "anti_patterns",
      "search_keywords"
    ]
  end

  @impl true
  def extract(source_or_path, opts \\ []) do
    case read_source(source_or_path) do
      {:ok, source} ->
        metadata = AIMetadataExtractor.extract(source)
        {:ok, metadata}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("AI metadata extraction failed", error: inspect(e))
      {:error, :extraction_failed}
  end

  @impl true
  def learn_from_extraction(result) do
    case result do
      %{module_identity: identity, call_graph: graph} when not is_nil(identity) ->
        Logger.info("Successfully extracted AI metadata",
          module: identity["module"],
          has_call_graph: not is_nil(graph)
        )

        :ok

      _ ->
        :ok
    end
  end

  # Private Helpers

  defp read_source(source) when is_binary(source) do
    # Could be either:
    # 1. Raw source code (contains "defmodule")
    # 2. File path (contains "/" or ".ex")

    case source do
      "defmodule " <> _ ->
        # Treat as source code
        {:ok, source}

      source ->
        # Check if it looks like a file path
        if String.contains?(source, ["/", ".ex"]) do
          # Treat as file path
          File.read(source)
        else
          # Unknown format
          {:error, :invalid_source_format}
        end
    end
  end

  defp read_source(_), do: {:error, :invalid_input}
end
