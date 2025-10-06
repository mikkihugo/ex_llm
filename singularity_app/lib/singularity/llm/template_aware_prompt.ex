defmodule Singularity.LLM.TemplateAwarePrompt do
  @moduledoc """
  Integrates template performance DAG with LLM prompting.

  Automatically:
  - Selects best template based on HTDAG performance data
  - Injects template context into prompts
  - Tracks which prompts work best
  - Learns from feedback to improve selection

  This connects:
  - TemplateOptimizer (which templates work)
  - LLM.Provider (generates code)
  - RAGCodeGenerator (finds examples)
  """

  require Logger

  alias Singularity.{TechnologyTemplateLoader, RAGCodeGenerator}
  alias Singularity.LLM.{Provider, SemanticCache}

  @doc """
  Generate LLM prompt with optimal template selection

  The HTDAG tells us which template performed best for similar tasks!
  """
  def generate_prompt(task, opts \\ []) do
    language = Keyword.get(opts, :language, "elixir")

    # 1. Ask HTDAG for best template based on history
    {:ok, template_id} = Singularity.TemplatePerformanceTracker.get_best_template(task.type, language)

    # 2. Load the selected template
    template = TechnologyTemplateLoader.template(template_id)

    # 3. Get RAG examples using the template's patterns
    {:ok, examples} = get_template_specific_examples(template, task, language)

    # 4. Build prompt with template structure
    prompt = build_template_aware_prompt(template, task, examples, opts)

    # 5. Return prompt with metadata for tracking
    %{
      prompt: prompt,
      template_id: template_id,
      template: template,
      examples_count: length(examples),
      metadata: %{
        task_type: task.type,
        language: language,
        timestamp: DateTime.utc_now()
      }
    }
  end

  @doc """
  Generate and execute with performance tracking
  """
  def generate_with_tracking(task, opts \\ []) do
    start_time = System.monotonic_time(:millisecond)

    # Get template-aware prompt
    prompt_data = generate_prompt(task, opts)

    # Check semantic cache first (with template context)
    cache_key = {task.type, task.description, prompt_data.template_id}

    case SemanticCache.get(cache_key) do
      :miss ->
        # Execute LLM call
        provider = select_provider_for_template(prompt_data.template)

        case Provider.call(provider, %{
               prompt: prompt_data.prompt,
               system_prompt: build_system_prompt(prompt_data.template),
               max_tokens: 4000,
               temperature: 0.3
             }) do
          {:ok, response} ->
            # Track performance
            end_time = System.monotonic_time(:millisecond)

            metrics = %{
              time_ms: end_time - start_time,
              quality: estimate_quality(response.content),
              success: true,
              lines: count_lines(response.content),
              complexity: estimate_complexity(response.content),
              # Would need test results
              coverage: 0.0,
              feedback: %{}
            }

            # Record in HTDAG for learning
            Singularity.TemplatePerformanceTracker.record_usage(
              prompt_data.template_id,
              task,
              metrics
            )

            # Cache the result
            SemanticCache.put(cache_key, response.content)

            {:ok, response.content, :generated}

          {:error, reason} ->
            # Record failure
            Singularity.TemplatePerformanceTracker.record_usage(
              prompt_data.template_id,
              task,
              %{success: false, error: reason}
            )

            {:error, reason}
        end
    end
  end

  defp build_template_aware_prompt(template, task, examples, opts) do
    """
    ## Task
    #{task.description}

    ## Template: #{template["name"]}
    #{template["description"]}

    ## Template Structure
    ```json
    #{Jason.encode!(template["steps"], pretty: true)}
    ```

    ## Similar Successful Examples
    #{format_examples(examples)}

    ## Requirements
    - Language: #{opts[:language] || "auto-detect"}
    - Quality Level: #{opts[:quality] || "production"}
    - Follow the template structure exactly
    - Use patterns from the examples
    - Generate production-ready code

    ## Output Format
    Generate code following the template's structure.
    Include all steps defined in the template.
    """
  end

  defp build_system_prompt(template) do
    detector_signatures = template["detector_signatures"] || %{}

    """
    You are an expert code generator specializing in #{template["name"]}.

    Key patterns to use:
    #{format_patterns(detector_signatures)}

    Always follow best practices for:
    - Error handling
    - Testing
    - Documentation
    - Performance

    Generate code that matches the quality of the examples provided.
    """
  end

  defp get_template_specific_examples(template, task, language) do
    # Use template's detector signatures to find relevant code
    patterns = template["detector_signatures"]["code_patterns"] || []

    # Build search query from patterns
    search_query = "#{task.description} #{Enum.join(patterns, " ")}"

    RAGCodeGenerator.find_best_examples(
      search_query,
      language,
      # All repos
      nil,
      # Top 5
      5,
      # Prefer recent
      true,
      # No tests
      false
    )
  end

  defp format_examples(examples) do
    examples
    |> Enum.with_index(1)
    |> Enum.map(fn {ex, idx} ->
      """
      ### Example #{idx} (#{ex.repo})
      ```#{ex.language}
      #{String.slice(ex.content, 0..400)}
      ```
      Similarity: #{Float.round(ex.similarity, 2)}
      """
    end)
    |> Enum.join("\n")
  end

  defp format_patterns(detector_signatures) do
    patterns =
      [
        detector_signatures["import_patterns"],
        detector_signatures["code_patterns"],
        detector_signatures["dependencies"]
      ]
      |> List.flatten()
      |> Enum.filter(& &1)
      |> Enum.take(10)

    if Enum.any?(patterns) do
      patterns |> Enum.map(&"- #{&1}") |> Enum.join("\n")
    else
      "- Follow language best practices"
    end
  end

  defp select_provider_for_template(template) do
    # Choose provider based on template complexity
    complexity = template["metadata"]["performance"]["complexity"] || 5

    cond do
      # Simple templates
      complexity <= 3 -> :gemini
      # Medium complexity
      complexity <= 7 -> :claude
      # Complex templates
      true -> :claude
    end
  end

  defp estimate_quality(code) do
    # Simple heuristic for code quality
    score = 0.5

    # Has error handling?
    score =
      score + if String.contains?(code, ["try", "catch", "rescue", "with"]), do: 0.1, else: 0

    # Has documentation?
    score = score + if String.contains?(code, ["@doc", "///", "/**"]), do: 0.1, else: 0

    # Has tests?
    score = score + if String.contains?(code, ["test", "spec", "assert"]), do: 0.1, else: 0

    # Reasonable length?
    lines = count_lines(code)
    score = score + if lines > 10 && lines < 500, do: 0.1, else: 0

    # Has types/specs?
    score =
      score + if String.contains?(code, ["@spec", "::", "type", "interface"]), do: 0.1, else: 0

    min(score, 1.0)
  end

  defp count_lines(code) do
    code |> String.split("\n") |> length()
  end

  defp estimate_complexity(code) do
    # Cyclomatic complexity estimate
    decision_points = ~r/if|case|cond|for|while|catch|rescue/
    matches = Regex.scan(decision_points, code)
    length(matches) + 1
  end

  @doc """
  Get prompt optimization suggestions from HTDAG analysis
  """
  def get_optimization_suggestions do
    {:ok, analysis} = Singularity.TemplatePerformanceTracker.analyze_performance()

    suggestions = [
      "Top performing templates: #{inspect(Enum.take(analysis.top_performers, 3))}",
      "Consider caching prompts for: #{identify_cacheable_patterns(analysis)}",
      "Low performers to avoid: #{identify_poor_performers(analysis)}"
    ]

    {:ok, suggestions}
  end

  defp identify_cacheable_patterns(analysis) do
    # Find frequently used template/task combinations
    analysis.usage_distribution
    |> Enum.filter(fn {_, usage} -> usage > 10 end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.take(5)
    |> Enum.join(", ")
  end

  defp identify_poor_performers(analysis) do
    analysis.top_performers
    |> Enum.reverse()
    |> Enum.take(3)
    |> Enum.map(& &1.template)
    |> Enum.join(", ")
  end
end
