defmodule Singularity.CodeQuality.PatternRegistryNIF do
  @moduledoc """
  Rustler NIF bridge to PatternRegistry for Rust engine integration.

  Provides native functions that allow Rust engines (code_quality_engine, parser_engine, linting_engine)
  to query the comprehensive 55 code quality patterns stored in PatternRegistry without embedding
  all pattern knowledge in Rust.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.CodeQuality.PatternRegistryNIF",
    "purpose": "Rustler NIF bridge enabling Rust engines to query Elixir PatternRegistry",
    "role": "interop_bridge",
    "layer": "code_quality",
    "dependencies": [
      "Rustler (NIF runtime)",
      "Singularity.CodeQuality.PatternRegistry (Elixir side)",
      "pattern_registry_nif (Rust crate)"
    ],
    "capabilities": [
      "Query patterns by language",
      "Query patterns by framework",
      "Query patterns by category",
      "Record pattern matches for effectiveness tracking",
      "Serialize patterns to JSON for Rust consumption"
    ]
  }
  ```

  ## Architecture

  ```
  Rust Engines (code_quality_engine, parser_engine)
       ↓
  PatternRegistryNIF (Rustler NIF bridge)
       ↓
  Elixir PatternRegistry (query layer)
       ↓
  PostgreSQL knowledge_artifacts (storage)
  ```

  ## Integration Pattern

  Rust engines call NIF functions:
  ```rust
  // In Rust (pattern_registry_nif)
  let patterns = get_patterns_for_language("python")?;
  for pattern in patterns {
    if matches_pattern(&ast, &pattern) {
      record_pattern_match(&pattern.id, ...)?;
    }
  }
  ```

  Elixir returns serialized patterns:
  ```elixir
  [
    %{
      "pattern_id" => "owasp_sql_injection",
      "name" => "SQL Injection Vulnerability",
      "severity" => "critical",
      "category" => "security",
      "applicable_languages" => ["python", "javascript"],
      ...
    },
    ...
  ]
  ```

  ## Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Singularity.CodeQuality.PatternRegistry
      function: find_by_language/2, find_by_framework/1, find_by_category/1
      purpose: Query patterns from Elixir side
      critical: true

    - module: Rustler
      function: NIF runtime
      purpose: Execute native Rust code in safe environment
      critical: true

  called_by:
    - module: pattern_registry_nif (Rust crate)
      purpose: Rust NIF implementation calls these functions
      frequency: per-analysis

    - module: Rust engines
      purpose: code_quality_engine, parser_engine query patterns
      frequency: per-file-analysis

  supervision:
    supervised: false
    reason: "NIF module - loaded once at startup, stateless"
  ```

  ## Anti-Patterns

  ❌ DO NOT duplicate pattern definitions in Rust
  **Why:** Rust engines would get out of sync with PatternRegistry updates
  **Use:** Always query PatternRegistry for authoritative patterns

  ❌ DO NOT call Rust NIF from Elixir hot paths
  **Why:** NIF calls have overhead, Elixir code should query PatternRegistry directly
  **Use:** Elixir code uses PatternRegistry directly, only Rust engines use NIF

  ❌ DO NOT skip recording pattern matches
  **Why:** Genesis needs effectiveness data to learn
  **Use:** Always call `record_pattern_match/2` when pattern evaluated

  ## Usage

  ```elixir
  # From Rust via NIF:
  patterns = PatternRegistryNIF.get_patterns_for_language("python")
  patterns = PatternRegistryNIF.get_patterns_for_framework("django")
  patterns = PatternRegistryNIF.get_patterns_for_category("security")

  # Record matches (called from Rust via NIF):
  PatternRegistryNIF.record_pattern_match("owasp_sql_injection", %{
    "matched" => true,
    "severity" => "critical",
    "file" => "app.py",
    "line" => 42
  })
  ```

  ## Search Keywords

  pattern registry nif rustler rust engine integration elixir interop
  code quality pattern query effectiveness tracking genesis feedback
  security compliance language patterns rust engine bridge
  """

  require Logger

  # Load the NIF module (pattern_registry_nif compiled to native)
  # Initially, these functions return :erlang.nif_error(:not_loaded) until Rust crate is compiled
  use Rustler, otp_app: :singularity, crate: "pattern_registry_nif"

  @doc """
  Get all patterns applicable to a specific programming language.

  Returns list of pattern maps serialized as JSON.

  ## Examples

      iex> PatternRegistryNIF.get_patterns_for_language("python")
      [
        %{
          "pattern_id" => "owasp_sql_injection",
          "name" => "SQL Injection Vulnerability",
          "severity" => "critical",
          "applicable_languages" => ["python", "javascript"],
          ...
        },
        ...
      ]
  """
  def get_patterns_for_language(_language), do: :erlang.nif_error(:not_loaded)

  @doc """
  Get all patterns applicable to a specific framework.

  Returns list of pattern maps serialized as JSON.

  ## Examples

      iex> PatternRegistryNIF.get_patterns_for_framework("django")
      [
        %{
          "pattern_id" => "django_security",
          "name" => "Django Security Patterns",
          ...
        },
        ...
      ]
  """
  def get_patterns_for_framework(_framework), do: :erlang.nif_error(:not_loaded)

  @doc """
  Get all patterns in a specific category.

  Category can be: "security", "compliance", "language", "package", "architecture", "framework"

  Returns list of pattern maps serialized as JSON.

  ## Examples

      iex> PatternRegistryNIF.get_patterns_for_category("security")
      [
        %{
          "pattern_id" => "owasp_sql_injection",
          ...
        },
        ...
      ]
  """
  def get_patterns_for_category(_category), do: :erlang.nif_error(:not_loaded)

  @doc """
  Record a pattern match for effectiveness tracking (Genesis feedback loop).

  Called from Rust after evaluating patterns on code. Emits telemetry for
  Genesis to monitor pattern effectiveness.

  ## Parameters

  - `pattern_id` (String) - Unique pattern identifier (e.g., "owasp_sql_injection")
  - `metadata` (Map) - Match metadata:
    - "matched" (Boolean) - Whether pattern matched
    - "severity" (String) - Pattern severity
    - "file" (String) - File where match occurred (optional)
    - "line" (Integer) - Line number of match (optional)
    - "false_positive" (Boolean) - Was this a false positive? (optional)

  ## Examples

      iex> PatternRegistryNIF.record_pattern_match("owasp_sql_injection", %{
      ...>   "matched" => true,
      ...>   "severity" => "critical",
      ...>   "file" => "app.py",
      ...>   "line" => 42
      ...> })
      :ok
  """
  def record_pattern_match(_pattern_id, _metadata), do: :erlang.nif_error(:not_loaded)

  # ============================================================================
  # Fallback implementations (when Rust NIF not available)
  # ============================================================================

  @doc false
  def nif_not_loaded(function_name) do
    Logger.warning(
      "PatternRegistryNIF.#{function_name} not loaded - Rust NIF not compiled. " <>
        "Run: cd singularity && cargo build --release in packages/pattern_registry_nif"
    )
    []
  end
end
