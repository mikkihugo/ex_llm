defmodule Genesis.LLMCallTracker do
  @moduledoc """
  Genesis LLM Call Tracker

  Measures and tracks LLM (Large Language Model) call usage to quantify
  the effectiveness of code improvement experiments.

  ## Purpose

  Experiments often aim to reduce LLM call volume by:
  - Caching common patterns
  - Implementing decision trees
  - Adding static analysis
  - Improving code decomposition

  This module tracks LLM calls before and after applying changes to
  calculate the `llm_reduction` metric.

  ## Measurement Strategy

  1. **Baseline Measurement** - Count LLM calls in original code
  2. **Snapshot Before** - Capture baseline metrics
  3. **Apply Changes** - Deploy experiment modifications
  4. **New Measurement** - Count LLM calls in modified code
  5. **Calculate Reduction** - (baseline - modified) / baseline

  ## LLM Call Detection

  Detects LLM calls by searching for:
  - HTTP calls to LLM APIs (Claude, Gemini, OpenAI)
  - NATS messages to ai.provider.* subjects
  - LLM.Service module calls
  - Direct imports of LLM modules
  """

  require Logger

  @doc """
  Measure LLM calls in a code sandbox.

  Analyzes the code in the sandbox and counts LLM API calls and related
  operations that would incur LLM usage.

  ## Returns

  - `{:ok, count}` - Number of estimated LLM calls
  - `{:error, reason}` - Failed to analyze code
  """
  def measure_llm_calls(sandbox) do
    try do
      # Analyze code in sandbox for LLM calls
      llm_call_count = analyze_code_for_llm_calls(sandbox)
      {:ok, llm_call_count}
    rescue
      e ->
        Logger.error("Failed to measure LLM calls in sandbox: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Calculate LLM reduction percentage.

  Compares baseline LLM calls with measured calls after experiment
  and returns the reduction as a percentage (0.0 to 1.0).

  ## Examples

      iex> calculate_reduction(100, 70)
      0.30  # 30% reduction

      iex> calculate_reduction(100, 150)
      -0.50  # 50% increase (negative)
  """
  def calculate_reduction(baseline_calls, measured_calls) when is_integer(baseline_calls) and is_integer(measured_calls) do
    if baseline_calls == 0 do
      0.0
    else
      (baseline_calls - measured_calls) / baseline_calls
      |> Float.round(4)
    end
  end

  @doc """
  Estimate LLM reduction based on code patterns detected.

  Uses heuristics to estimate LLM reduction when exact measurement
  is not available. Returns a probability-based estimate.

  ## Factors Considered

  - Code complexity reduction
  - Cache patterns added
  - Decision tree implementation
  - Pattern library usage
  - Memoization presence

  ## Returns

  Float between 0.0 (no reduction) and 1.0 (100% reduction)
  """
  def estimate_reduction(original_sandbox, modified_sandbox, risk_level) do
    try do
      original_patterns = count_llm_patterns(original_sandbox)
      modified_patterns = count_llm_patterns(modified_sandbox)

      # Calculate based on pattern reduction
      reduction = calculate_reduction(original_patterns, modified_patterns)

      # Adjust estimate based on risk level (higher risk = higher expected reduction)
      adjusted_reduction = case risk_level do
        "high" -> min(reduction * 1.2, 1.0)  # Up to 20% boost for high-risk experiments
        "medium" -> reduction
        "low" -> max(reduction * 0.8, 0.0)  # 20% discount for low-risk (less impactful)
        _ -> reduction
      end

      Logger.info("Estimated LLM reduction: #{Float.round(adjusted_reduction, 3)} (from #{original_patterns} to #{modified_patterns} patterns)")
      adjusted_reduction
    rescue
      e ->
        Logger.warning("Failed to estimate LLM reduction: #{inspect(e)}, defaulting to 0.0")
        0.0
    end
  end

  # ============================================================================
  # Private functions
  # ============================================================================

  defp analyze_code_for_llm_calls(sandbox) do
    # Count potential LLM calls in the sandbox code
    # Look for patterns indicating LLM usage:
    # - LLM.Service calls
    # - HTTP requests to LLM APIs
    # - NATS publishes to ai.provider.* subjects
    # - LLM module imports

    try do
      # Search for LLM-related code patterns
      llm_calls = count_llm_calls_in_directory(Path.join(sandbox, "lib"))
      llm_calls
    rescue
      _e -> 0
    end
  end

  defp count_llm_calls_in_directory(directory) do
    # Recursively count LLM calls in .ex files
    case File.ls(directory) do
      {:ok, files} ->
        files
        |> Enum.reduce(0, fn file, acc ->
          full_path = Path.join(directory, file)
          case File.stat(full_path) do
            {:ok, %{type: :directory}} ->
              # Recursively search subdirectories
              acc + count_llm_calls_in_directory(full_path)

            {:ok, %{type: :regular}} ->
              if String.ends_with?(file, ".ex") do
                acc + count_llm_calls_in_file(full_path)
              else
                acc
              end

            _ -> acc
          end
        end)

      {:error, _} -> 0
    end
  end

  defp count_llm_calls_in_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        # Count LLM-related patterns
        count =
          Enum.count([
            # Count LLM.Service calls
            Regex.scan(~r/LLM\.Service\.call/, content),
            # Count NATS publishes to ai.provider
            Regex.scan(~r/ai\.provider\.\w+/, content),
            # Count direct HTTP to LLM APIs
            Regex.scan(~r/(claude|gemini|openai|anthropic).*api/, content),
            # Count LLM-related imports
            Regex.scan(~r/alias.*LLM\.|import.*LLM\./, content)
          ])

        count

      {:error, _} -> 0
    end
  end

  defp count_llm_patterns(sandbox) do
    # Count LLM-related code patterns that indicate usage
    # This is an estimate based on code structure

    try do
      lib_path = Path.join(sandbox, "lib")
      count_llm_calls_in_directory(lib_path)
    rescue
      _e -> 0
    end
  end
end
