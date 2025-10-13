defmodule Singularity.Example.AIOptimizedModule do
  @moduledoc """
  # Example Module - AI-Optimized Documentation Pattern

  This is an example showing the FULL AI-optimized documentation pattern
  for billion-line codebases with graph/vector DB indexing.

  ## Module Identity (AI Navigation)

  ```json
  {
    "module": "Singularity.Example.AIOptimizedModule",
    "purpose": "Example demonstrating AI-optimized documentation patterns",
    "role": "example",
    "layer": "documentation",
    "alternatives": {
      "RegularModule": "Standard docs without AI metadata (harder for AI to navigate)",
      "LegacyModule": "Old-style docs (no structured metadata)"
    },
    "disambiguation": {
      "vs_regular": "This = AI-optimized (use for production). Regular = Basic docs only",
      "vs_legacy": "This = Modern pattern. Legacy = Deprecated approach"
    },
    "replaces": [],
    "replaced_by": null
  }
  ```

  **Why JSON?** Vector DBs embed this for semantic search. Graph DBs parse it for relationship indexing.

  ---

  ## Architecture Diagram

  ```mermaid
  graph TB
      Caller[Client Code]
      Module[AIOptimizedModule]
      Dep1[Dependency1]
      Dep2[Dependency2]

      Caller -->|1. call/2| Module
      Module -->|2. process| Dep1
      Module -->|3. store| Dep2
      Dep1 -->|4. result| Module
      Dep2 -->|5. ok| Module
      Module -->|6. response| Caller

      style Module fill:#90EE90
      style Caller fill:#87CEEB
  ```

  **Why Mermaid?** AI sees visual flow instantly without reading code. Can be rendered in docs/wikis.

  ---

  ## Decision Tree (When/How to Use)

  ```mermaid
  graph TD
      Start[Need this module?]
      Start -->|Yes| CheckPurpose{What's the goal?}

      CheckPurpose -->|Example/docs| UseDirectly[Use this module]
      CheckPurpose -->|Production| UsePattern[Copy pattern to prod module]

      UseDirectly --> SimpleExample[Call example_function/2]
      UsePattern --> CreateNew[Create new module with this pattern]

      style UseDirectly fill:#90EE90
      style UsePattern fill:#FFD700
  ```

  **Why decision tree?** AI knows HOW to use the module without trial-and-error.

  ---

  ## Call Graph (Machine-Readable)

  ```yaml
  # Graph DB can auto-index this!
  calls_out:
    - module: Singularity.Dependency1
      function: process/2
      purpose: Data processing
      critical: true

    - module: Singularity.Dependency2
      function: store/1
      purpose: Persistence
      critical: true

    - module: Logger
      functions: [info/2, error/2]
      purpose: Logging
      critical: false

  called_by:
    - module: Singularity.ClientModule
      purpose: Example usage
      frequency: high

    - module: Tests
      purpose: Testing pattern
      frequency: low

  depends_on:
    - Singularity.Dependency1 (MUST exist)
    - Singularity.Dependency2 (MUST exist)

  supervision:
    supervised: false
    reason: "Stateless module - no process"
  ```

  **Why YAML?** Graph DBs (Neo4j) can parse and build call graphs automatically!

  ---

  ## Data Flow (Sequence Diagram)

  ```mermaid
  sequenceDiagram
      participant Client
      participant Module
      participant Dep1
      participant Dep2

      Client->>Module: example_function(data, opts)
      Module->>Module: validate_input(data)
      Module->>Dep1: process(data)
      Dep1-->>Module: {:ok, processed}
      Module->>Dep2: store(processed)
      Dep2-->>Module: {:ok, stored}
      Module->>Module: build_response(stored)
      Module-->>Client: {:ok, response}
  ```

  **Why sequence?** Shows async flow, error handling, state changes.

  ---

  ## Anti-Patterns (Duplicate Prevention)

  ### ❌ DO NOT create "Example.AIModule" or "Example.OptimizedDocs"
  **Why:** This module already demonstrates that! Would be a duplicate.
  **Use instead:** Reference this module as example.

  ### ❌ DO NOT create wrapper modules
  ```elixir
  # ❌ WRONG - Unnecessary wrapper
  defmodule Example.SimpleWrapper do
    def call(data), do: AIOptimizedModule.example_function(data, [])
  end

  # ✅ CORRECT - Use directly
  AIOptimizedModule.example_function(data, [])
  ```

  ### ❌ DO NOT bypass validation
  ```elixir
  # ❌ WRONG - Skips validation
  AIOptimizedModule.unsafe_call(unvalidated_data)

  # ✅ CORRECT - Validates input
  AIOptimizedModule.example_function(validated_data, [])
  ```

  **Why anti-patterns?** At billion-line scale, AI sees similar modules and might create duplicates.
  Explicit anti-patterns PREVENT this!

  ---

  ## Search Keywords (Vector DB Optimization)

  ai optimized docs, documentation pattern, mermaid diagrams, graph db indexing,
  vector db optimization, module identity, call graph yaml, anti patterns,
  billion line codebase, ai navigation, semantic search, code disambiguation,
  example module, production pattern

  **Why keywords?** Vector search on "ai optimized docs" returns THIS module with high confidence!

  ---

  ## Public API

  - `example_function/2` - Main function demonstrating pattern
  - `get_metadata/0` - Returns module metadata for tooling

  ## Examples

      # Basic usage
      iex> AIOptimizedModule.example_function("data", [])
      {:ok, "processed: data"}

      # With options
      iex> AIOptimizedModule.example_function("data", validate: false)
      {:ok, "processed: data"}

      # Error case
      iex> AIOptimizedModule.example_function("", [])
      {:error, :invalid_input}

  ## Performance Notes

  - Input validation: < 1ms
  - Processing: Depends on Dependency1 (typically < 10ms)
  - Total: < 20ms P95

  ## Related Modules

  - `Singularity.LLM.Service` - Real production example using this pattern
  - `Singularity.Agent` - Another production example
  """

  require Logger

  @type data :: String.t()
  @type opts :: keyword()
  @type response :: {:ok, String.t()} | {:error, atom()}

  @doc """
  Example function demonstrating AI-optimized documentation.

  ## Parameters
  - `data` - Input data to process
  - `opts` - Options (validate: boolean, timeout: integer)

  ## Returns
  - `{:ok, processed}` - Successfully processed
  - `{:error, :invalid_input}` - Input validation failed
  - `{:error, :processing_failed}` - Processing error

  ## Examples

      iex> example_function("test", [])
      {:ok, "processed: test"}

      iex> example_function("", [])
      {:error, :invalid_input}

  ## Edge Cases
  - Empty string → `:invalid_input`
  - nil → `:invalid_input`
  - Very long strings (> 1MB) → May timeout
  """
  @spec example_function(data(), opts()) :: response()
  def example_function(data, opts \\ []) do
    with :ok <- validate_input(data),
         {:ok, processed} <- process_data(data, opts) do
      {:ok, "processed: #{processed}"}
    else
      {:error, reason} ->
        Logger.error("Processing failed", reason: reason, data: data)
        {:error, reason}
    end
  end

  @doc """
  Get module metadata for tooling.

  Returns structured metadata for graph/vector DB indexing.

  ## Examples

      iex> get_metadata()
      %{
        module: "Singularity.Example.AIOptimizedModule",
        purpose: "Example demonstrating AI-optimized docs",
        has_mermaid: true,
        has_yaml: true,
        has_json: true
      }
  """
  @spec get_metadata() :: map()
  def get_metadata do
    %{
      module: "Singularity.Example.AIOptimizedModule",
      purpose: "Example demonstrating AI-optimized docs",
      has_mermaid: true,
      has_yaml: true,
      has_json: true,
      capabilities: [:graph_db, :vector_db, :ai_navigation]
    }
  end

  # Private functions

  defp validate_input(data) when is_binary(data) and byte_size(data) > 0, do: :ok
  defp validate_input(_), do: {:error, :invalid_input}

  defp process_data(data, _opts) do
    # Simulate processing
    {:ok, data}
  end
end
