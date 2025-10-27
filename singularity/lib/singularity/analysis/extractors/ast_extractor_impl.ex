defmodule Singularity.Analysis.Extractors.AstExtractorImpl do
  @moduledoc """
  AstExtractor Wrapper - Implements ExtractorType behavior for code structure extraction

  Wraps Singularity.Analysis.AstExtractor into unified ExtractorType behavior.

  ## Module Identity

  ```json
  {
    "module": "Singularity.Analysis.Extractors.AstExtractorImpl",
    "purpose": "Unified interface for extracting code structure from tree-sitter AST",
    "role": "extractor",
    "layer": "analysis",
    "alternatives": {
      "AstExtractor": "Direct module - use when not using ExtractorType system"
    },
    "disambiguation": {
      "vs_direct": "Impl = ExtractorType-compliant wrapper. Direct = Plain Elixir module"
    }
  }
  ```

  ## Call Graph

  ```yaml
  calls_out:
    - module: Singularity.Analysis.AstExtractor
      function: extract_metadata/2
      purpose: Extract code structure from AST JSON
      critical: true

  called_by:
    - module: UnifiedMetadataExtractor
      purpose: Coordinated metadata extraction
      frequency: high

  depends_on:
    - Singularity.Analysis.AstExtractor (implementation)

  supervision:
    supervised: false
    reason: "Stateless utility module"
  ```

  ## Anti-Patterns

  ### ❌ DO NOT create "AstExtractorWrapper"
  **Why:** This module already wraps AstExtractor!
  **Use instead:** This module via ExtractorType system

  ### ❌ DO NOT call AstExtractor.extract_metadata/2 directly in new code
  **Use instead:** Call via ExtractorType behavior:
  ```elixir
  ExtractorType.get_extractor_module(:ast)
  |> then(fn {:ok, module} -> module.extract(ast_json, file_path) end)
  ```

  ## Search Keywords

  ast extractor, tree-sitter, code structure, dependency extraction, call graph,
  type information, documentation extraction, metadata wrapper, extractor type
  """

  @behaviour Singularity.Analysis.ExtractorType
  require Logger
  alias Singularity.Analysis.AstExtractor

  @impl true
  def extractor_type, do: :ast

  @impl true
  def description do
    "Extract code structure (dependencies, call graphs, types, docs) from tree-sitter AST"
  end

  @impl true
  def capabilities do
    [
      "dependency_analysis",
      "call_graph_extraction",
      "type_information",
      "documentation_extraction"
    ]
  end

  @impl true
  def extract(ast_json_string, _opts \\ []) do
    file_path = Keyword.get(_opts, :file_path, "unknown")

    case AstExtractor.extract_metadata(ast_json_string, file_path) do
      result when is_map(result) ->
        {:ok, result}

      _ ->
        {:error, :extraction_failed}
    end
  rescue
    e ->
      Logger.error("AST extraction failed", error: inspect(e))
      {:error, :extraction_failed}
  end

  @impl true
  def learn_from_extraction(result) do
    case result do
      %{dependencies: deps, call_graph: graph} when is_map(deps) ->
        internal_count = length(deps[:internal] || [])
        external_count = length(deps[:external] || [])

        Logger.info("Successfully extracted code structure",
          internal_dependencies: internal_count,
          external_dependencies: external_count,
          has_call_graph: not is_nil(graph)
        )

        :ok

      _ ->
        :ok
    end
  end
end
