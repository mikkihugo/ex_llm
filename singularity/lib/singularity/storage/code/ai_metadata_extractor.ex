defmodule Singularity.Code.AIMetadataExtractor do
  @moduledoc """
  AI Metadata Extractor - Parses AI navigation metadata from Elixir module documentation.

  ## Module Identity (AI Navigation)

  ```json
  {
    "module": "Singularity.Code.AIMetadataExtractor",
    "purpose": "Extract and parse AI metadata (JSON/YAML/Mermaid) from @moduledoc for indexing",
    "role": "analyzer",
    "layer": "domain_services",
    "alternatives": {
      "Code.Parser": "Generic AST parsing - use for code structure (not docs)",
      "Documentation": "Read plain text docs - use when AI metadata not needed"
    },
    "disambiguation": {
      "vs_parser": "Extractor = Parses metadata blocks. Parser = Parses code AST",
      "vs_documentation": "Extractor = Structured metadata. Documentation = Plain text"
    }
  }
  ```

  ## Architecture

  ```mermaid
  graph TB
      Caller[SelfImprovingAgent/CodeStore]
      Extractor[AIMetadataExtractor]
      Parser[Module AST]
      JSON[Jason]
      YAML[YamlElixir]

      Caller -->|1. extract/1| Extractor
      Extractor -->|2. parse AST| Parser
      Extractor -->|3. find blocks| Extractor
      Extractor -->|4. decode JSON| JSON
      Extractor -->|5. parse YAML| YAML
      Extractor -->|6. metadata| Caller

      style Extractor fill:#90EE90
  ```

  ## Call Graph

  ```yaml
  calls_out:
    - module: Code
      function: string_to_quoted/1
      purpose: Parse Elixir source to AST
      critical: true

    - module: Jason
      function: decode/1
      purpose: Parse Module Identity JSON
      critical: false

    - module: YamlElixir
      function: read_from_string/1
      purpose: Parse Call Graph YAML
      critical: false

  called_by:
    - module: Singularity.SelfImprovingAgent
      purpose: Analyze code for improvements
      frequency: high

    - module: Singularity.Code.CodeStore
      purpose: Index code with metadata
      frequency: high

    - module: Singularity.Knowledge.ArtifactStore
      purpose: Store documentation metadata
      frequency: medium

  depends_on:
    - Jason (for JSON parsing)
    - YamlElixir (for YAML parsing)

  supervision:
    supervised: false
    reason: "Stateless utility module"
  ```

  ## Anti-Patterns

  ### ❌ DO NOT create "MetadataParser" or "DocParser"
  **Why:** This module already does that!
  **Use instead:** `AIMetadataExtractor.extract/1`

  ### ❌ DO NOT parse @moduledoc as plain text
  ```elixir
  # ❌ WRONG - Loses structured metadata
  {:ok, module} = Code.string_to_quoted(source)
  text = extract_plain_moduledoc(module)

  # ✅ CORRECT - Extracts structured blocks
  metadata = AIMetadataExtractor.extract(source)
  identity = metadata.module_identity
  ```

  ### ❌ DO NOT manually parse JSON/YAML from strings
  ```elixir
  # ❌ WRONG - Error-prone, reinventing wheel
  json_start = String.index(doc, "```json")
  json = extract_between_markers(doc, "```json", "```")

  # ✅ CORRECT - Robust extraction
  AIMetadataExtractor.extract_module_identity(source)
  ```

  ## Search Keywords

  ai metadata, moduledoc parser, json extraction, yaml extraction, mermaid extraction,
  documentation analyzer, code metadata, module identity, call graph parser,
  structured documentation, ai navigation metadata, vector db indexing, graph db indexing

  ## Public API

  - `extract/1` - Extract all AI metadata from Elixir source
  - `extract_module_identity/1` - Extract Module Identity JSON
  - `extract_call_graph/1` - Extract Call Graph YAML
  - `extract_diagrams/1` - Extract all Mermaid diagrams
  - `extract_anti_patterns/1` - Extract anti-patterns section
  - `extract_search_keywords/1` - Extract search keywords

  ## Examples

      # Extract all metadata
      iex> source = File.read!("lib/singularity/llm/service.ex")
      iex> metadata = AIMetadataExtractor.extract(source)
      %{
        module_identity: %{"module" => "Singularity.LLM.Service", ...},
        call_graph: %{"calls_out" => [...], "called_by" => [...]},
        diagrams: ["graph TB...", "sequenceDiagram..."],
        anti_patterns: "### ❌ DO NOT...",
        search_keywords: "llm service, ai call, claude..."
      }

      # Extract just Module Identity
      iex> identity = AIMetadataExtractor.extract_module_identity(source)
      %{
        "module" => "Singularity.LLM.Service",
        "purpose" => "ONLY way to call LLM providers",
        "role" => "service",
        "layer" => "domain_services"
      }

      # Extract call graph for Neo4j
      iex> graph = AIMetadataExtractor.extract_call_graph(source)
      %{
        "calls_out" => [
          %{"module" => "NatsClient", "function" => "request/3"}
        ],
        "called_by" => [
          %{"module" => "Agent", "frequency" => "high"}
        ]
      }
  """

  require Logger

  @type source :: String.t()

  @type diagram :: %{
          type: atom(),
          text: String.t(),
          ast: map() | nil
        }

  @type metadata :: %{
          module_identity: map() | nil,
          call_graph: map() | nil,
          diagrams: [diagram()],
          anti_patterns: String.t() | nil,
          search_keywords: String.t() | nil
        }

  @doc """
  Extract all AI metadata from Elixir source code.

  Returns a map with all extracted metadata sections.
  Returns empty/nil values for missing sections.
  """
  @spec extract(source()) :: metadata()
  def extract(source) when is_binary(source) do
    with {:ok, moduledoc} <- extract_moduledoc(source) do
      %{
        module_identity: extract_json_block(moduledoc, "Module Identity"),
        call_graph: extract_yaml_block(moduledoc, "Call Graph"),
        diagrams: extract_mermaid_blocks(moduledoc),
        anti_patterns: extract_section(moduledoc, "Anti-Patterns"),
        search_keywords: extract_section(moduledoc, "Search Keywords")
      }
    else
      _ ->
        %{
          module_identity: nil,
          call_graph: nil,
          diagrams: [],
          anti_patterns: nil,
          search_keywords: nil
        }
    end
  end

  @doc """
  Extract Module Identity JSON from source.
  """
  @spec extract_module_identity(source()) :: map() | nil
  def extract_module_identity(source) do
    with {:ok, moduledoc} <- extract_moduledoc(source),
         json when not is_nil(json) <- extract_json_block(moduledoc, "Module Identity") do
      json
    else
      _ -> nil
    end
  end

  @doc """
  Extract Call Graph YAML from source.
  """
  @spec extract_call_graph(source()) :: map() | nil
  def extract_call_graph(source) do
    with {:ok, moduledoc} <- extract_moduledoc(source),
         yaml when not is_nil(yaml) <- extract_yaml_block(moduledoc, "Call Graph") do
      yaml
    else
      _ -> nil
    end
  end

  @doc """
  Extract all Mermaid diagrams from source.
  """
  @spec extract_diagrams(source()) :: [String.t()]
  def extract_diagrams(source) do
    case extract_moduledoc(source) do
      {:ok, moduledoc} -> extract_mermaid_blocks(moduledoc)
      _ -> []
    end
  end

  @doc """
  Extract anti-patterns section from source.
  """
  @spec extract_anti_patterns(source()) :: String.t() | nil
  def extract_anti_patterns(source) do
    case extract_moduledoc(source) do
      {:ok, moduledoc} -> extract_section(moduledoc, "Anti-Patterns")
      _ -> nil
    end
  end

  @doc """
  Extract search keywords from source.
  """
  @spec extract_search_keywords(source()) :: String.t() | nil
  def extract_search_keywords(source) do
    case extract_moduledoc(source) do
      {:ok, moduledoc} -> extract_section(moduledoc, "Search Keywords")
      _ -> nil
    end
  end

  ## Private Functions

  defp extract_moduledoc(source) do
    case Code.string_to_quoted(source) do
      {:ok, {:defmodule, _, [_name, [do: {:__block__, _, exprs}]]}} ->
        find_moduledoc(exprs)

      {:ok, {:defmodule, _, [_name, [do: expr]]}} ->
        find_moduledoc([expr])

      {:error, reason} ->
        Logger.debug("Failed to parse source", reason: reason)
        {:error, :parse_error}

      _ ->
        {:error, :no_moduledoc}
    end
  end

  defp find_moduledoc(exprs) do
    Enum.find_value(exprs, {:error, :no_moduledoc}, fn
      {:@, _, [{:moduledoc, _, [doc]}]} when is_binary(doc) ->
        {:ok, doc}

      _ ->
        nil
    end)
  end

  defp extract_json_block(moduledoc, section_name) do
    case extract_code_block(moduledoc, section_name, "json") do
      nil ->
        nil

      json_string ->
        case Jason.decode(json_string) do
          {:ok, data} -> data
          {:error, _} -> nil
        end
    end
  end

  defp extract_yaml_block(moduledoc, section_name) do
    case extract_code_block(moduledoc, section_name, "yaml") do
      nil ->
        nil

      yaml_string ->
        case YamlElixir.read_from_string(yaml_string) do
          {:ok, data} -> data
          {:error, _} -> nil
        end
    end
  end

  defp extract_mermaid_blocks(moduledoc) do
    # Find all ```mermaid ... ``` blocks
    regex = ~r/```mermaid\s*\n(.*?)\n\s*```/s

    Regex.scan(regex, moduledoc)
    |> Enum.map(fn [_, diagram_text] ->
      diagram_text = String.trim(diagram_text)

      # Try to parse the diagram with tree-sitter-little-mermaid
      ast = parse_mermaid_diagram(diagram_text)

      %{
        type: :mermaid,
        text: diagram_text,
        ast: ast
      }
    end)
  end

  @doc false
  @spec parse_mermaid_diagram(String.t()) :: map() | nil
  defp parse_mermaid_diagram(diagram_text) when is_binary(diagram_text) do
    # Attempt to parse Mermaid diagram with Rust NIF via ParserEngine
    # If not available or fails, returns nil (diagram text still preserved)
    case Singularity.ParserEngine.parse_mermaid(diagram_text) do
      {:ok, json_string} ->
        # JSON string returned from Rust NIF
        case Jason.decode(json_string) do
          {:ok, ast_data} -> normalize_mermaid_ast(ast_data)
          {:error, _} -> nil
        end

      {:error, _reason} ->
        Logger.debug("Failed to parse Mermaid diagram, storing text only")
        nil

      _ ->
        nil
    end
  rescue
    _ ->
      # If ParserEngine not available or NIF call fails, gracefully degrade
      Logger.debug("Mermaid parsing unavailable, storing text only")
      nil
  end

  @doc false
  @spec normalize_mermaid_ast(map() | String.t()) :: map() | nil
  defp normalize_mermaid_ast(ast_data) when is_map(ast_data) do
    # Normalize raw AST to consistent format
    # AST structure: %{"type" => string, "text" => string, "children" => [...]
    ast_data
  end

  defp normalize_mermaid_ast(_), do: nil

  defp extract_code_block(moduledoc, section_name, language) do
    # Find section heading
    section_regex = ~r/##\s+#{Regex.escape(section_name)}/

    case Regex.run(section_regex, moduledoc) do
      nil ->
        nil

      _ ->
        # Extract content after section heading
        parts = Regex.split(section_regex, moduledoc, parts: 2)

        case parts do
          [_, after_section] ->
            # Find code block with specified language
            block_regex = ~r/```#{language}\s*\n(.*?)\n\s*```/s

            case Regex.run(block_regex, after_section) do
              [_, code] -> String.trim(code)
              _ -> nil
            end

          _ ->
            nil
        end
    end
  end

  defp extract_section(moduledoc, section_name) do
    # Find section heading
    section_regex = ~r/##\s+#{Regex.escape(section_name)}\s*\n/

    case Regex.split(section_regex, moduledoc, parts: 2) do
      [_, after_section] ->
        # Extract content until next ## heading
        case Regex.run(~r/^(.*?)(?=##|\z)/s, after_section) do
          [_, content] -> String.trim(content)
          _ -> nil
        end

      _ ->
        nil
    end
  end
end
