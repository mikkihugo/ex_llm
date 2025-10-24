defmodule Singularity.LLM.Prompt.TemplateAware do
  @moduledoc """
  Integrates template performance DAG with LLM prompting.

  Automatically:
  - Selects best template based on TaskGraph performance data
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
  alias Singularity.LLM.{Service, PromptCache}

  @doc """
  Generate LLM prompt with optimal template selection

  The TaskGraph tells us which template performed best for similar tasks!
  Now enhanced with Rust prompt engine for context-aware generation.
  """
  def generate_prompt(task, opts \\ []) do
    language = Keyword.get(opts, :language, "elixir")
    use_prompt_engine = Keyword.get(opts, :use_prompt_engine, true)

    if use_prompt_engine do
      generate_prompt_with_engine(task, language, opts)
    else
      generate_prompt_legacy(task, language, opts)
    end
  end

  defp generate_prompt_with_engine(task, language, opts) do
    # 1. Use centralized template service for template selection
    case detect_context_type(task) do
      {:framework, framework, category} ->
        case get_template_for_framework(framework, category, language) do
          {:ok, template} ->
            prompt = build_prompt_from_template(template, task.description, language)

            Logger.info("Generated prompt using centralized template service",
              framework: framework,
              category: category,
              template_id: template.id
            )

            %{
              prompt: prompt,
              template_id: template.id,
              template: %{name: template.name, framework: framework, category: category},
              examples_count: 0,
              metadata: %{
                task_type: task.type,
                language: language,
                timestamp: DateTime.utc_now(),
                generated_by: :template_service,
                confidence: 0.9
              }
            }

          {:error, reason} ->
            Logger.warning("Template service failed, falling back to legacy", reason: reason)
            generate_prompt_legacy(task, language, opts)
        end

      {:language, lang, category} ->
        case get_template_for_language(lang, category) do
          {:ok, template} ->
            prompt = build_prompt_from_template(template, task.description, language)

            Logger.info("Generated prompt using centralized template service",
              language: lang,
              category: category,
              template_id: template.id
            )

            %{
              prompt: prompt,
              template_id: template.id,
              template: %{name: template.name, language: lang, category: category},
              examples_count: 0,
              metadata: %{
                task_type: task.type,
                language: language,
                timestamp: DateTime.utc_now(),
                generated_by: :template_service,
                confidence: 0.8
              }
            }

          {:error, reason} ->
            Logger.warning("Prompt engine failed, falling back to legacy", reason: reason)
            generate_prompt_legacy(task, language, opts)
        end

      {:pattern, pattern, category} ->
        case PromptEngine.generate_pattern_prompt(task.description, pattern, category, language) do
          {:ok, %{prompt: prompt, confidence: confidence, template_used: template_used}} ->
            Logger.info("Generated prompt using prompt engine",
              pattern: pattern,
              category: category,
              confidence: confidence
            )

            %{
              prompt: prompt,
              template_id: template_used,
              template: %{name: template_used, pattern: pattern, category: category},
              examples_count: 0,
              metadata: %{
                task_type: task.type,
                language: language,
                timestamp: DateTime.utc_now(),
                generated_by: :prompt_engine,
                confidence: confidence
              }
            }

          {:error, reason} ->
            Logger.warning("Prompt engine failed, falling back to legacy", reason: reason)
            generate_prompt_legacy(task, language, opts)
        end

      :unknown ->
        # Fall back to legacy template system
        generate_prompt_legacy(task, language, opts)
    end
  end

  defp generate_prompt_legacy(task, language, opts) do
    # 1. Ask TaskGraph for best template based on history
    {:ok, template_id} =
      Singularity.Quality.TemplateTracker.get_best_template(task.type, language)

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
        timestamp: DateTime.utc_now(),
        generated_by: :legacy
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

    # Check memory cache first (faster than semantic cache)
    cache_key = :erlang.phash2({task.type, task.description, prompt_data.template_id})

    case Cache.get(:memory, cache_key) do
      {:ok, cached_response} ->
        Logger.info("Using cached prompt response", cache_key: cache_key)
        cached_response

      :miss ->
        # Optimize prompt using prompt engine if available
        optimized_prompt = optimize_prompt_if_available(prompt_data.prompt, task, opts)

        # Execute LLM call via NATS (determine complexity from task)
        complexity = determine_complexity(task, prompt_data.template)
        system_prompt = build_system_prompt(prompt_data.template)

        case Service.call_with_system(complexity, system_prompt, optimized_prompt,
               max_tokens: 4000,
               temperature: 0.3,
               task_type: task.type
             ) do
          {:ok, response} ->
            # Track performance
            end_time = System.monotonic_time(:millisecond)
            content = response.text

            metrics = %{
              time_ms: end_time - start_time,
              quality: estimate_quality(content),
              success: true,
              lines: count_lines(content),
              complexity: estimate_complexity(content),
              # Would need test results
              coverage: 0.0,
              feedback: %{},
              prompt_optimized: optimized_prompt != prompt_data.prompt
            }

            # Record in TaskGraph for learning
            Singularity.Quality.TemplateTracker.record_usage(
              prompt_data.template_id,
              task,
              metrics
            )

            # Cache the result (using ETS for fast access)
            Cache.put(:memory, cache_key, content, ttl: :timer.hours(1))

            {:ok, content, :generated}

          {:error, reason} ->
            # Record failure
            Singularity.Quality.TemplateTracker.record_usage(
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

  defp determine_complexity(task, template) do
    # Determine complexity level for NATS routing based on task and template
    template_complexity = get_in(template, ["metadata", "performance", "complexity"]) || 5

    cond do
      # Simple: basic tasks, simple templates
      template_complexity <= 3 and task.type in [:simple, :basic, :prototype] -> :simple
      # Medium: standard code generation
      template_complexity <= 7 -> :medium
      # Complex: architecture, planning, production code
      true -> :complex
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
  Get prompt optimization suggestions from TaskGraph analysis
  """
  def get_optimization_suggestions do
    {:ok, analysis} = Singularity.Quality.TemplateTracker.analyze_performance()

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

  # Helper functions for prompt engine integration

  defp detect_context_type(task) do
    description = String.downcase(task.description)

    # Detect framework patterns
    cond do
      String.contains?(description, "phoenix") ->
        {:framework, "phoenix", detect_category(description)}

      String.contains?(description, "rails") ->
        {:framework, "rails", detect_category(description)}

      String.contains?(description, "nextjs") or String.contains?(description, "next.js") ->
        {:framework, "nextjs", detect_category(description)}

      String.contains?(description, "react") ->
        {:framework, "react", detect_category(description)}

      String.contains?(description, "spring") ->
        {:framework, "spring", detect_category(description)}

      # Detect language patterns
      String.contains?(description, "rust") ->
        {:language, "rust", detect_category(description)}

      String.contains?(description, "elixir") ->
        {:language, "elixir", detect_category(description)}

      String.contains?(description, "python") ->
        {:language, "python", detect_category(description)}

      String.contains?(description, "javascript") or String.contains?(description, "js") ->
        {:language, "javascript", detect_category(description)}

      String.contains?(description, "go") ->
        {:language, "go", detect_category(description)}

      # Detect pattern types
      String.contains?(description, "microservice") ->
        {:pattern, "microservice", detect_category(description)}

      String.contains?(description, "api") ->
        {:pattern, "api", detect_category(description)}

      String.contains?(description, "database") or String.contains?(description, "db") ->
        {:pattern, "database", detect_category(description)}

      String.contains?(description, "test") or String.contains?(description, "testing") ->
        {:pattern, "testing", detect_category(description)}

      true ->
        :unknown
    end
  end

  defp detect_category(description) do
    cond do
      String.contains?(description, "command") or String.contains?(description, "run") ->
        "commands"

      String.contains?(description, "depend") or String.contains?(description, "install") ->
        "dependencies"

      String.contains?(description, "config") or String.contains?(description, "setup") ->
        "configuration"

      String.contains?(description, "example") or String.contains?(description, "sample") ->
        "examples"

      String.contains?(description, "test") or String.contains?(description, "testing") ->
        "testing"

      String.contains?(description, "deploy") or String.contains?(description, "production") ->
        "deployment"

      String.contains?(description, "integrate") or String.contains?(description, "connect") ->
        "integration"

      true ->
        # Default fallback
        "commands"
    end
  end

  defp optimize_prompt_if_available(prompt, task, opts) do
    use_optimization = Keyword.get(opts, :optimize_prompt, true)

    if use_optimization do
      case PromptEngine.optimize_prompt(prompt,
             context: task.description,
             language: Keyword.get(opts, :language, "elixir")
           ) do
        {:ok, %{optimized_prompt: optimized}} ->
          Logger.info("Prompt optimized using prompt engine",
            original_length: String.length(prompt),
            optimized_length: String.length(optimized)
          )

          optimized

        {:error, reason} ->
          Logger.debug("Prompt optimization failed, using original", reason: reason)
          prompt
      end
    else
      prompt
    end
  end

  # Helper functions using centralized template service

  @doc """
  Get template for framework and category using centralized template service.
  """
  defp get_template_for_framework(framework, category, language) do
    # Use dynamic template discovery for framework templates
    case Singularity.Knowledge.TemplateService.find_framework_template(language, framework) do
      {:ok, template} ->
        {:ok, template}

      {:error, _} ->
        # Try with category as use case
        Singularity.Knowledge.TemplateService.find_template("framework", language, category)
    end
  end

  @doc """
  Get template for language and category using centralized template service.
  """
  defp get_template_for_language(language, category) do
    # Use dynamic template discovery for language templates
    case Singularity.Knowledge.TemplateService.find_template("language", language, category) do
      {:ok, template} ->
        {:ok, template}

      {:error, _} ->
        # Fallback to general language template
        Singularity.Knowledge.TemplateService.find_template("language", language, "general")
    end
  end

  @doc """
  Build prompt from template using the template content.
  """
  defp build_prompt_from_template(template, task_description, language) do
    # Extract prompt template from the template content
    prompt_template =
      get_in(template, ["content", "prompt"]) ||
        get_in(template, ["prompt"]) ||
        template["content"] ||
        "Generate #{language} code for: {{task}}"

    # Replace placeholders
    prompt_template
    |> String.replace("{{task}}", task_description)
    |> String.replace("{{language}}", language)
    |> String.replace("{{description}}", task_description)
  end
end
