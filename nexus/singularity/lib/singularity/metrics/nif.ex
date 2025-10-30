defmodule Singularity.Metrics.NIF do
  @moduledoc """
  NIF Bindings - Calls to Rust metric calculation engines

  This module provides Elixir bindings to the singularity-code-analysis Rust library
  for fast, language-aware metric calculations.

  ## Metrics Provided

  1. **Type Safety Score** - Type coverage and correctness (Rust: unsafe, TypeScript: annotations, etc.)
  2. **Dependency Coupling** - Inter-module coupling strength and cyclic dependencies
  3. **Error Handling Coverage** - Exception path completeness and robustness

  ## Example

      iex> code = "fn process(x: i32) -> Result<String, Error> { ... }"
      iex> {:ok, metrics} = Singularity.Metrics.NIF.type_safety(:rust, code)
      iex> metrics.score
      85.5
  """

  @on_load :load_nif

  def load_nif do
    nif_file = :filename.join(:code.priv_dir(:singularity), "native/metrics")

    case :erlang.load_nif(nif_file, 0) do
      :ok ->
        :ok

      {:error, {:load_failure, reason}} ->
        IO.warn("Failed to load metrics NIF: #{reason}")
        # Graceful fallback
        :ok
    end
  end

  @doc """
  Calculate Type Safety Score for code

  ## Parameters
    - language: atom (:rust, :typescript, :python, :javascript, :java, :cpp)
    - code: binary - source code to analyze

  ## Returns
    - {:ok, %{score: float, details: map}} on success
    - {:error, reason} on failure

  ## Example
      iex> Singularity.Metrics.NIF.type_safety(:rust, "let x: i32 = 42;")
      {:ok, %{
        score: 92.0,
        annotation_coverage: 90.0,
        generic_usage: 10.0,
        unsafe_ratio: 0.0,
        explicit_type_ratio: 100.0,
        pattern_matching_score: 50.0
      }}
  """
  def type_safety(_language, _code) do
    raise "NIF not loaded"
  end

  @doc """
  Calculate Dependency Coupling Score

  Analyzes imports to detect cyclic dependencies, deep chains, and architectural violations.

  ## Parameters
    - imports: list of {from_module, to_module} tuples
    - options: keyword list
      - language: atom (:rust, :elixir, :python, etc.)
      - ignore_external: boolean (default: true) - ignore vendor/node_modules imports

  ## Returns
    - {:ok, %{score: float, details: map}} on success

  ## Example
      iex> imports = [
      ...>   {"app", "lib"},
      ...>   {"lib", "utils"},
      ...>   {"utils", "core"}
      ...> ]
      iex> Singularity.Metrics.NIF.dependency_coupling(imports, language: :elixir)
      {:ok, %{
        score: 85.0,
        import_density: 3.0,
        cyclic_dependencies: 0,
        max_chain_depth: 3,
        layer_violations: 0
      }}
  """
  def dependency_coupling(_imports, _opts \\ []) do
    raise "NIF not loaded"
  end

  @doc """
  Calculate Error Handling Coverage Score

  Measures completeness of error paths and exception handling quality.

  ## Parameters
    - language: atom (:rust, :python, :javascript, :typescript, :java)
    - code: binary - source code to analyze

  ## Returns
    - {:ok, %{score: float, details: map}} on success

  ## Example
      iex> code = \"\"\"
      ...> try {
      ...>   let result = await process(data);
      ...> } catch (error) {
      ...>   console.error("Error:", error);
      ...>   throw error;
      ...> } finally {
      ...>   cleanup();
      ...> }
      ...> \"\"\"
      iex> Singularity.Metrics.NIF.error_handling(:typescript, code)
      {:ok, %{
        score: 88.0,
        error_type_coverage: 90.0,
        unhandled_paths_ratio: 0.1,
        specific_catches_ratio: 85.0,
        logging_coverage: 80.0,
        fallback_coverage: 100.0
      }}
  """
  def error_handling(_language, _code) do
    raise "NIF not loaded"
  end

  @doc """
  Batch analyze metrics for multiple code snippets

  More efficient than calling individual functions repeatedly.

  ## Parameters
    - files: list of %{path: string, language: atom, code: binary}

  ## Returns
    - {:ok, list of metric results}

  ## Example
      iex> files = [
      ...>   %{path: "lib/a.rs", language: :rust, code: "fn main() { ... }"},
      ...>   %{path: "lib/b.rs", language: :rust, code: "..."}
      ...> ]
      iex> Singularity.Metrics.NIF.batch_analyze(files)
      {:ok, [
        %{path: "lib/a.rs", type_safety: 85.0, coupling: 72.0, error_handling: 90.0},
        %{path: "lib/b.rs", type_safety: 92.0, coupling: 65.0, error_handling: 88.0}
      ]}
  """
  def batch_analyze(_files) do
    raise "NIF not loaded"
  end

  # Helper functions for common use cases

  @doc """
  Calculate all three metrics at once for a code file

  Convenience function that calls all three metric calculations.
  """
  def analyze_all(language, code) when is_atom(language) and is_binary(code) do
    with {:ok, type_safety} <- type_safety(language, code),
         {:ok, error_handling} <- error_handling(language, code) do
      {:ok,
       %{
         type_safety: type_safety,
         error_handling: error_handling,
         language: language
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def analyze_all(_, _) do
    {:error, "language must be atom and code must be binary"}
  end

  @doc """
  Convert language string to atom

  Helper for converting file extensions to language atoms.
  """
  def language_from_extension(ext) when is_binary(ext) do
    case String.downcase(ext) do
      "rs" -> :rust
      "ts" -> :typescript
      "tsx" -> :typescript
      "js" -> :javascript
      "jsx" -> :javascript
      "py" -> :python
      "java" -> :java
      "cpp" -> :cpp
      "c++" -> :cpp
      "h" -> :cpp
      "hpp" -> :cpp
      "ex" -> :elixir
      "exs" -> :elixir
      "erl" -> :erlang
      "gleam" -> :gleam
      _ -> nil
    end
  end

  def language_from_extension(_), do: nil

  @doc """
  Safety wrapper for metric calculation with error handling

  Wraps NIF calls with timeouts and error recovery.
  """
  def safe_analyze(language, code, timeout_ms \\ 5000) do
    task =
      Task.async(fn ->
        analyze_all(language, code)
      end)

    case Task.yield(task, timeout_ms) do
      {:ok, result} ->
        result

      nil ->
        Task.shutdown(task)
        {:error, "metric calculation timeout after #{timeout_ms}ms"}
    end
  end
end
