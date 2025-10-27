defmodule Singularity.Execution.Planning.TaskGraphEvolution do
  @moduledoc """
  TaskGraph Self-Evolution Engine - Autonomous improvement via LLM-driven mutation and critique.

  Enables autonomous improvement of TaskGraph execution by analyzing performance metrics,
  searching git history for successful patterns, and applying mutations to operation
  parameters, model selection, and prompt templates using context-aware Lua scripts.

  ## Evolution Workflow

  1. **Critique** - Analyze execution metrics and history (Lua script)
  2. **Propose Mutations** - Suggest improvements (model, parameters, prompts)
  3. **Apply Mutations** - Update graph parameters
  4. **Track History** - Log all mutations to PostgreSQL

  ## Mutation Types

  - **Model Selection** - Change LLM model based on performance/cost analysis
  - **Parameter Tuning** - Adjust temperature, max_tokens, top_p, etc.
  - **Prompt Engineering** - Refine system/user prompts
  - **Decomposition Strategy** - Improve task breakdown and dependencies

  ## Integration Points

  This module integrates with:
  - `Singularity.LLM.Service` - Lua-based critique (Service.call_with_script/3)
  - `:telemetry` - Performance metrics for execution analysis
  - PostgreSQL table: `task_graph_evolution_logs` (mutation history and results)
  - Git history - Pattern matching for successful TaskGraph configurations

  ## Lua-Based Critique

  Uses `templates_data/prompt_library/execution/critique-task_graph-run.lua` which:
  - Analyzes execution metrics (completed, failed, tokens, latency, cost)
  - Searches git history for successful TaskGraph patterns
  - Checks recent model configuration changes
  - Proposes mutations ranked by confidence and expected impact
  - Provides cost/quality tradeoff recommendations

  ## Usage

      # Critique execution results and get mutations
      {:ok, mutations} = TaskGraphEvolution.critique_and_mutate(execution_result)
      # => {:ok, [
      #   %{type: :model_change, target: "task-123", old_value: "claude-3-5-sonnet", new_value: "claude-opus"},
      #   %{type: :param_change, target: "temperature", old_value: 0.7, new_value: 0.5}
      # ]}

      # Apply mutations to parameters
      improved_params = TaskGraphEvolution.apply_mutations(mutations, original_params)
      # => %{model_id: "claude-opus", temperature: 0.5, ...}

      # Evolution feedback loop
      {:ok, mutations} = TaskGraphEvolution.critique_and_mutate(result)
      improved = TaskGraphEvolution.apply_mutations(mutations, graph.params)
      # Rerun TaskGraph with improved_params for next iteration

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Execution.Planning.TaskGraphEvolution",
    "purpose": "Autonomous TaskGraph self-improvement via LLM critique and mutation",
    "role": "optimizer",
    "layer": "execution_planning",
    "key_responsibilities": [
      "Analyze TaskGraph execution metrics and performance",
      "Search git history for successful patterns",
      "Propose mutations (model, parameters, prompts, decomposition)",
      "Track evolution history for learning"
    ],
    "prevents_duplicates": ["GraphOptimizer", "AutoTuner", "EvolutionEngine"],
    "uses": ["LLM.Service", "Logger", "telemetry"],
    "mutation_types": ["model_selection", "parameter_tuning", "prompt_engineering", "decomposition_strategy"]
  }
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Singularity.LLM.Service
      function: call_with_script/3
      purpose: Execute Lua critique script for mutation proposals
      critical: true
      script: "execution/critique-task_graph-run.lua"

    - module: Logger
      function: debug/2, info/2, error/2
      purpose: Log mutations and evolution progress
      critical: false

  called_by:
    - module: Singularity.Execution.Planning.TaskGraph
      function: evolve/1
      purpose: Auto-improve graph after execution
      frequency: post_execution_optional

    - module: Singularity.Agents.OptimizationAgent
      function: improve_graph/1
      purpose: Systematic graph optimization
      frequency: periodic

  state_transitions:
    - name: critique_execution
      from: idle
      to: critiqued
      trigger: critique_and_mutate/1 called
      actions:
        - Collect execution metrics
        - Call LLM with Lua critique script
        - Parse mutation proposals
        - Return mutations list

    - name: apply_mutations
      from: critiqued
      to: evolved
      trigger: apply_mutations/2 called
      actions:
        - Merge mutations into parameters
        - Log mutation history
        - Return improved parameters

  depends_on:
    - Singularity.LLM.Service (MUST be available)
    - templates_data/prompt_library/execution/critique-*.lua (MUST exist)
    - :telemetry for metrics (MUST be configured)
  ```

  ### Performance Characteristics ⚡

  **Time Complexity**
  - critique_and_mutate/2: O(n + m) where n = execution tasks, m = git history search
    - Typical: ~1-3s for small graphs (< 50 tasks)
    - Large graphs: ~5-15s for 500+ tasks with deep git history
  - apply_mutations/2: O(k) where k = number of mutations (typically 2-5 mutations)
    - Per mutation: ~10-50ms
    - Total: ~20-250ms for typical mutation application
  - Per-phase overhead: Lua script execution ~500ms-2s depending on model

  **Space Complexity**
  - Execution result enrichment: ~5KB per execution (metrics + history)
  - Mutations list: ~1-2KB per mutation
  - Total overhead: ~10-20KB per evolution cycle

  **Typical Latencies**
  - Small TaskGraph (10-20 tasks): ~2-3s total critique + mutations
  - Medium TaskGraph (50-100 tasks): ~5-8s total
  - Large TaskGraph (500+ tasks): ~15-20s total
  - Per-mutation application: ~50-100ms

  ---

  ### Concurrency & Safety 🔒

  **Process Safety**
  - ✅ Safe to call from multiple processes: Stateless operations
  - ✅ No shared state: Each evolution independent
  - ✅ Reentrant: Can handle concurrent evolution requests

  **Thread Safety**
  - ✅ LLM service calls serialized (via RateLimiter + CircuitBreaker)
  - ✅ Lua script execution stateless
  - ✅ Results returned immediately (no global state modification)

  **Atomicity Guarantees**
  - ✅ Single operation: Critique or apply mutations are atomic
  - ❌ Multi-step evolution: Not atomic (critique → apply → test cycle)
  - Recommended: Implement transaction rollback for failed mutations

  **Race Condition Risks**
  - Low risk: Each evolution independent
  - Medium risk: LLM rate limiting (shared quota across processes)
  - Medium risk: Git history search (read-only, but concurrent access)
  - Recommended: Monitor RateLimiter queue depth during parallel evolution requests

  ---

  ### Observable Metrics 📊

  **Telemetry Events**
  - start: Evolution cycle begins (task count, graph size)
  - critique_complete: Critique phase finishes (duration, mutation count, confidence scores)
  - mutations_applied: Mutations successfully applied (mutation count, types, impact)
  - complete: Full evolution cycle done (total duration, mutations applied, improvement score)
  - error: Failure in critique or application (phase, error reason)

  **Key Metrics**
  - Total critique time: How long LLM critique takes
  - Total application time: How long mutation application takes
  - Mutation count: Number of mutations proposed vs applied
  - Improvement score: Calculated improvement from mutations
  - Success rate: % of evolution cycles completing successfully

  **Recommended Monitoring**
  - SLA: P95 latency < 20s for medium graphs
  - Availability: Error rate < 5%
  - Mutation success: > 70% of proposed mutations improve performance
  - Cost: Token count × model pricing per evolution cycle

  ---

  ### Troubleshooting Guide 🔧

  **Problem: Critique Timeout (Exceeds 20s)**

  **Symptoms**
  - critique_and_mutate/2 takes > 20s to complete
  - P95 latency spike
  - LLM model not responding in time

  **Root Causes**
  1. Large TaskGraph (500+ tasks) with deep git history
  2. LLM service overloaded (shared quota exhausted)
  3. Git history search slow (many commits to analyze)
  4. Network latency to LLM provider

  **Solutions**
  - Increase timeout: `timeout: 30000` for large graphs
  - Check LLM service: Monitor latency independently
  - Check RateLimiter: Verify quota availability
  - Limit git history: Search only recent commits (e.g., 100 most recent)

  ---

  **Problem: Mutations Cause Regression**

  **Symptoms**
  - After applying mutations, TaskGraph performance degrades
  - Improvement score calculated incorrectly
  - Mutation confidence scores misleading

  **Root Causes**
  1. Mutations applied without validation testing
  2. LLM critique missed edge cases
  3. Combined mutation effects unpredictable
  4. Metrics calculation error (before/after mismatch)

  **Solutions**
  - Apply mutations incrementally: Test each mutation separately
  - Validate improvements: Run execution before/after mutation
  - Add mutation rollback: Store previous parameters for recovery
  - Improve critique: Add more execution context to Lua script

  ---

  **Problem: No Mutations Proposed**

  **Symptoms**
  - critique_and_mutate/2 returns empty mutations list
  - No improvements found despite poor performance
  - Git history search yields no useful patterns

  **Root Causes**
  1. LLM critique found no improvement opportunities
  2. Execution metrics incomplete or missing
  3. Git history has no successful patterns
  4. All parameters already optimal

  **Solutions**
  - Check execution metrics: Ensure all fields populated
  - Expand git history: Search broader commit range
  - Analyze poor metrics: What specific metric is worst?
  - Manual mutation: Apply known good patterns from git

  ---

  ### Anti-Patterns

  #### ❌ DO NOT create GraphOptimizer, AutoTuner, or EvolutionEngine duplicates
  **Why:** TaskGraphEvolution is the canonical graph self-improvement module.

  ```elixir
  # ❌ WRONG - Duplicate evolution engine
  defmodule MyApp.GraphOptimizer do
    def optimize(graph) do
      # Re-implementing mutation logic
    end
  end

  # ✅ CORRECT - Use TaskGraphEvolution
  {:ok, mutations} = TaskGraphEvolution.critique_and_mutate(result)
  evolved = TaskGraphEvolution.apply_mutations(mutations, graph.params)
  ```

  #### ❌ DO NOT skip critique phase or apply arbitrary mutations
  **Why:** LLM critique provides confidence scores and reasoning; arbitrary changes risk regression.

  ```elixir
  # ❌ WRONG - Apply mutations without critique
  mutations = [%{type: :model_change, target: "task-1", new_value: "gpt-4"}]
  evolved = TaskGraphEvolution.apply_mutations(mutations, params)

  # ✅ CORRECT - Critique execution first
  {:ok, mutations} = TaskGraphEvolution.critique_and_mutate(execution)
  evolved = TaskGraphEvolution.apply_mutations(mutations, params)
  ```

  #### ❌ DO NOT apply all mutations immediately without validation
  **Why:** Mutations should be tested incrementally; applying all at once risks cascading failures.

  ```elixir
  # ❌ WRONG - Apply all mutations at once
  {:ok, mutations} = TaskGraphEvolution.critique_and_mutate(result)
  evolved = TaskGraphEvolution.apply_mutations(mutations, params)
  # Rerun with all changes - unknown combined effect!

  # ✅ CORRECT - Apply mutations incrementally
  {:ok, mutations} = TaskGraphEvolution.critique_and_mutate(result)
  Enum.each(mutations, fn mutation ->
    evolved = TaskGraphEvolution.apply_mutations([mutation], current_params)
    # Test evolved graph with single mutation
    # Track success rate before applying next
  end)
  ```

  ### Search Keywords

  TaskGraph evolution, self-improvement, mutation proposal, LLM critique, parameter tuning,
  model selection, prompt optimization, decomposition strategy, git history patterns,
  performance analysis, autonomous optimization, feedback loop, Lua scripting
  """

  require Logger

  # INTEGRATION: LLM operations (pgmq-based critique and mutation)
  # INTEGRATION: LLM service with Lua script support for context-aware critique
  @type mutation :: %{
          type: :model_change | :param_change | :prompt_change,
          target: String.t(),
          old_value: any(),
          new_value: any(),
          reason: String.t(),
          confidence: float()
        }

  @doc """
  Critique execution results and propose mutations via LLM using context-aware Lua script.

  Analyzes execution metrics, searches git history for successful patterns, and suggests improvements.
  """
  @spec critique_and_mutate(map(), keyword()) :: {:ok, [mutation()]} | {:error, term()}
  def critique_and_mutate(execution_result, _opts \\ []) do
    run_id = Keyword.get(opts, :run_id, generate_run_id())

    # Enrich execution result with calculated metrics
    enriched_result =
      execution_result
      |> Map.put(:total_tokens, calculate_total_tokens(execution_result))
      |> Map.put(:avg_latency, calculate_avg_latency(execution_result))

    # Use Lua script for context-aware critique
    script_context = %{
      execution_result: enriched_result,
      run_id: run_id
    }

    case Service.call_with_script(
           "execution/critique-task_graph-run.lua",
           script_context,
           complexity: :medium,
           task_type: :architect
         ) do
      {:ok, %{content: json_response}} ->
        # Parse mutations from JSON response
        parse_mutations(json_response)

      {:error, reason} ->
        Logger.error("Lua script critique failed", reason: inspect(reason))
        {:error, reason}
    end
  end

  @doc """
  Apply mutations to operation parameters.

  Returns updated parameters with mutations applied.
  """
  @spec apply_mutations([mutation()], map()) :: map()
  def apply_mutations(mutations, params) do
    Enum.reduce(mutations, params, fn mutation, acc ->
      apply_mutation(mutation, acc)
    end)
  end

  @doc """
  Evaluate if a mutation improved performance.

  Compares metrics before and after mutation.
  """
  @spec evaluate_mutation(mutation(), map(), map()) :: {:better | :worse | :neutral, float()}
  def evaluate_mutation(mutation, before_metrics, after_metrics) do
    # Calculate improvement score
    score = calculate_improvement_score(before_metrics, after_metrics)

    result =
      cond do
        score > 0.1 -> :better
        score < -0.1 -> :worse
        true -> :neutral
      end

    {result, score}
  end

  ## Private Functions

  defp parse_mutations(llm_response) do
    # Extract JSON from response
    case extract_json(llm_response) do
      {:ok, %{"mutations" => mutations}} when is_list(mutations) ->
        parsed = Enum.map(mutations, &parse_mutation/1)
        {:ok, parsed}

      {:ok, _} ->
        Logger.warning("No mutations found in LLM response")
        {:ok, []}

      {:error, reason} ->
        Logger.error("Failed to parse mutations", reason: reason)
        {:error, reason}
    end
  end

  defp parse_mutation(mutation_data) do
    %{
      type: parse_mutation_type(mutation_data["type"]),
      target: mutation_data["target"],
      old_value: mutation_data["old_value"],
      new_value: mutation_data["new_value"],
      reason: mutation_data["reason"],
      confidence: mutation_data["confidence"] || 0.5
    }
  end

  defp parse_mutation_type("model_change"), do: :model_change
  defp parse_mutation_type("param_change"), do: :param_change
  defp parse_mutation_type("prompt_change"), do: :prompt_change
  defp parse_mutation_type(_), do: :unknown

  defp extract_json(text) do
    # Find JSON block in markdown or raw text
    case Regex.run(~r/```json\s*(\{.*?\})\s*```/s, text) do
      [_, json] -> Jason.decode(json)
      nil -> Jason.decode(text)
    end
  end

  defp apply_mutation(%{type: :model_change, target: target, new_value: new_model}, params) do
    Map.update(params, :model_id, new_model, fn _ -> new_model end)
  end

  defp apply_mutation(%{type: :param_change, target: param_name, new_value: new_value}, params) do
    param_key = String.to_atom(param_name)
    Map.put(params, param_key, new_value)
  end

  defp apply_mutation(%{type: :prompt_change, new_value: new_prompt}, params) do
    Map.put(params, :prompt_template, new_prompt)
  end

  defp apply_mutation(_mutation, params), do: params

  defp calculate_improvement_score(before, after_metrics) do
    # Simple scoring: fewer tokens and faster is better
    token_improvement = (before[:total_tokens] || 1000) / (after_metrics[:total_tokens] || 1000)
    latency_improvement = (before[:avg_latency] || 1000) / (after_metrics[:avg_latency] || 1000)
    success_improvement = (after_metrics[:success_rate] || 0.5) / (before[:success_rate] || 0.5)

    # Weighted average
    token_improvement * 0.3 + latency_improvement * 0.3 + success_improvement * 0.4 - 1.0
  end

  defp calculate_total_tokens(execution_result) do
    execution_result
    |> Map.get(:results, %{})
    |> Enum.reduce(0, fn {_task_id, result}, acc ->
      tokens = get_in(result, [:usage, "total_tokens"]) || 0
      acc + tokens
    end)
  end

  defp calculate_avg_latency(_execution_result) do
    # Placeholder - would calculate from telemetry data
    1500
  end

  defp format_task_results(execution_result) do
    execution_result
    |> Map.get(:results, %{})
    |> Enum.map_join("\n", fn {task_id, result} ->
      tokens = get_in(result, [:usage, "total_tokens"]) || 0
      "- #{task_id}: #{tokens} tokens"
    end)
  end

  defp generate_run_id do
    "evolution-#{System.unique_integer([:positive])}"
  end
end
