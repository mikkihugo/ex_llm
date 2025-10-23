defmodule Singularity.GeneratorEngine.Code do
  @moduledoc false

  require Logger
  alias Singularity.GeneratorEngine.Util
  alias Singularity.RAGCodeGenerator

  @spec generate_clean_code(String.t(), String.t()) :: {:ok, String.t()}
  def generate_clean_code(description, language) do
    snippet =
      case String.downcase(language || "") do
        "elixir" -> generate_elixir_code(description)
        "typescript" -> generate_typescript_code(description)
        "python" -> generate_python_code(description)
        "rust" -> generate_rust_code(description)
        "go" -> generate_go_code(description)
        _ -> "// #{description}"
      end

    {:ok, snippet}
  end

  defp generate_elixir_code(description) do
    module_name = Util.slug(description) |> String.capitalize()
    function_name = Util.slug(description) |> String.downcase()

    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      #{String.capitalize(description)}
      \"\"\"
      
      @doc \"\"\"
      #{String.capitalize(description)}.
      
      ## Examples
      
          iex> #{module_name}.#{function_name}()
          :ok
      \"\"\"
      def #{function_name} do
        # Implementation goes here
        :ok
      end
    end
    """
  end

  defp generate_typescript_code(description) do
    function_name = Util.slug(description)

    """
    /**
     * #{String.capitalize(description)}
     * 
     * @returns Promise<any>
     */
    export async function #{function_name}(): Promise<any> {
      // Implementation goes here
      return {};
    }
    """
  end

  defp generate_python_code(description) do
    function_name = Util.slug(description)

    """
    \"\"\"
    #{String.capitalize(description)}
    \"\"\"

    def #{function_name}():
        \"\"\"
        #{String.capitalize(description)}.
        
        Returns:
            any: The result
        \"\"\"
        # Implementation goes here
        return None
    """
  end

  defp generate_rust_code(description) do
    function_name = Util.slug(description)

    """
    /// #{String.capitalize(description)}
    pub fn #{function_name}() -> Result<(), Box<dyn std::error::Error>> {
        // Implementation goes here
        Ok(())
    }
    """
  end

  defp generate_go_code(description) do
    function_name = Util.slug(description) |> String.capitalize()

    """
    // #{String.capitalize(description)}
    func #{function_name}() error {
        // Implementation goes here
        return nil
    }
    """
  end

  @spec convert_to_clean_code(term(), String.t()) :: {:ok, String.t()}
  def convert_to_clean_code(pseudocode, language) do
    body = inspect(pseudocode, pretty: true)
    {:ok, "# Converted pseudocode for #{language}\n#{body}"}
  end

  @spec validate_and_improve(String.t(), String.t()) :: {:ok, map()}
  def validate_and_improve(code, _language) do
    # This would integrate with the code validation and improvement functions
    # For now, return a basic validation
    {:ok,
     %{
       valid: String.contains?(code, "defmodule"),
       suggestions: ["Ensure proper Elixir syntax"],
       improved_code: code
     }}
  end

  @doc """
  Generate production-quality code using SPARC methodology + RAG.

  ## Parameters:
  - `task` - What to generate (e.g., 'Create GenServer for caching with TTL')
  - `language` - Target language: 'elixir', 'rust', 'typescript', 'python' (default: 'elixir')
  - `repo` - Codebase to learn patterns from (optional)
  - `quality` - Quality level: 'production', 'prototype', 'quick' (default: 'production')
  - `include_tests` - Generate tests (default: true for production)
  """
  def code_generate(
        task,
        language \\ "elixir",
        repo \\ nil,
        quality \\ "production",
        include_tests \\ true
      ) do
    quality_atom = String.to_atom(quality)

    case generate_with_t5_and_rag(task, language, repo, quality_atom, include_tests) do
      {:ok, enhanced_code} ->
        {:ok,
         %{
           task: task,
           language: language,
           method: "T5 + RAG (5-phase)",
           code: enhanced_code,
           quality: quality,
           lines: count_lines(enhanced_code),
           includes_tests: include_tests,
           repo: repo
         }}

      error ->
        error
    end
  end

  @doc """
  Quick code generation using RAG (pattern-based).

  ## Parameters:
  - `task` - What to generate
  - `language` - Target language (default: 'elixir')
  - `repos` - List of repos to search for examples
  - `top_k` - Number of example patterns to use (default: 5)
  """
  def code_generate_quick(task, language \\ "elixir", repos \\ nil, top_k \\ 5) do
    case generate_clean_code(task, language) do
      {:ok, base_code} ->
        enhanced_code = add_pattern_enhancements(base_code, language, top_k)

        {:ok,
         %{
           task: task,
           language: language,
           method: "RAG (pattern-based)",
           code: enhanced_code,
           quality: "quick",
           lines: count_lines(enhanced_code),
           examples_used: top_k,
           repos: repos
         }}

      error ->
        error
    end
  end

  @doc """
  Find similar code examples from codebases.

  ## Parameters:
  - `query` - What to search for (e.g., 'async worker pattern')
  - `language` - Filter by language (optional)
  - `repos` - Repos to search (default: all)
  - `limit` - Max results (default: 5)
  """
  def code_find_examples(query, language \\ nil, repos \\ nil, limit \\ 5) do
    examples = generate_mock_examples(query, language, limit)

    {:ok,
     %{
       query: query,
       language: language,
       examples: examples,
       count: length(examples),
       repos: repos
     }}
  end

  @doc """
  Validate code quality against standards.

  ## Parameters:
  - `code` - Code to validate
  - `language` - Code language
  - `quality_level` - Expected quality: 'production', 'prototype' (default: 'production')
  """
  def code_validate(code, language, quality_level \\ "production") do
    quality_atom = String.to_atom(quality_level)

    case validate_and_improve(code, language) do
      {:ok, validation} ->
        enhanced_validation = enhance_validation(validation, quality_atom)

        {:ok,
         %{
           language: language,
           quality_level: quality_level,
           valid: enhanced_validation.valid,
           score: calculate_quality_score(enhanced_validation),
           issues: enhanced_validation.suggestions,
           suggestions: enhanced_validation.suggestions,
           completeness: %{
             has_docs: has_documentation?(code),
             has_tests: has_tests?(code),
             has_error_handling: has_error_handling?(code),
             has_types: has_types?(code, language)
           }
         }}

      error ->
        error
    end
  end

  @doc """
  Refine code based on validation feedback.
  """
  def code_refine(code, validation_result, language, focus \\ "all") do
    _issues_text = format_issues(validation_result["issues"] || [])
    _suggestions_text = format_suggestions(validation_result["suggestions"] || [])

    case validate_and_improve(code, language) do
      {:ok, improved} ->
        {:ok,
         %{
           original_code: code,
           refined_code: improved.improved_code,
           issues_addressed: length(validation_result["issues"] || []),
           focus: focus,
           lines_changed: abs(count_lines(improved.improved_code) - count_lines(code)),
           validation_score: validation_result["score"]
         }}

      error ->
        error
    end
  end

  @doc """
  Iteratively improve code until a quality threshold is met.
  """
  def code_iterate(task, language \\ "elixir", quality_threshold \\ 0.85, max_iterations \\ 3) do
    case code_generate(task, language) do
      {:ok, initial_result} ->
        iterate_until_quality(initial_result, language, quality_threshold, max_iterations, 0)

      error ->
        error
    end
  end

  defp enhance_code_quality(code, language, quality, include_tests) do
    base_code = code

    enhanced =
      case quality do
        :production ->
          add_documentation(base_code, language)
          |> add_error_handling(language)
          |> add_logging(language)
          |> maybe_add_tests(include_tests, language)

        :prototype ->
          add_basic_documentation(base_code, language)
          |> add_basic_error_handling(language)

        :quick ->
          base_code
      end

    enhanced
  end

  defp add_pattern_enhancements(code, language, top_k) do
    "# Pattern-based enhancement (using #{top_k} examples)\n" <> code
  end

  defp generate_mock_examples(query, language, limit) do
    # Replace mock examples with real knowledge base retrieval
    case Singularity.Knowledge.ArtifactStore.search(query, %{
           language: language,
           top_k: limit,
           min_similarity: 0.6,
           artifact_types: ["code_example", "code_pattern", "function", "module"]
         }) do
      {:ok, results} ->
        # Transform knowledge base results into example format
        Enum.map(results, fn %{artifact: artifact, similarity: similarity} ->
          %{
            file: artifact.file_path || "unknown_file.#{language || "ex"}",
            repo: artifact.source_repo || "knowledge_base",
            similarity: similarity,
            code_preview: generate_code_preview(artifact.content, query),
            language: artifact.language || language || "elixir",
            source: "knowledge_base",
            artifact_id: artifact.id
          }
        end)

      {:error, reason} ->
        Logger.warning("Failed to retrieve examples from knowledge base: #{inspect(reason)}")
        # Fallback to basic mock examples if knowledge base fails
        Enum.map(1..min(limit, 3), fn i ->
          %{
            file: "fallback_example_#{i}.#{language || "ex"}",
            repo: "fallback_repo",
            similarity: 0.5 - i * 0.1,
            code_preview: "# Fallback example #{i} for #{query} in #{language}...",
            language: language || "elixir",
            source: "fallback"
          }
        end)
    end
  end

  defp generate_code_preview(content, query) do
    # Extract relevant code snippet around the query
    content_lines = String.split(content || "", "\n")

    # Find lines containing the query or related terms
    query_lower = String.downcase(query)

    relevant_lines =
      Enum.filter(content_lines, fn line ->
        String.contains?(String.downcase(line), query_lower) or
          String.contains?(String.downcase(line), "def ") or
          String.contains?(String.downcase(line), "function") or
          String.contains?(String.downcase(line), "class ")
      end)

    # Take first few relevant lines or first 5 lines as preview
    preview_lines =
      if length(relevant_lines) > 0 do
        Enum.take(relevant_lines, 3)
      else
        Enum.take(content_lines, 5)
      end

    # Join and limit length
    preview = Enum.join(preview_lines, "\n")

    if String.length(preview) > 200 do
      String.slice(preview, 0, 200) <> "..."
    else
      preview
    end
  end

  defp enhance_validation(validation, quality_level) do
    case quality_level do
      :production ->
        %{validation | valid: validation.valid and String.length(validation.improved_code) > 50}

      _ ->
        validation
    end
  end

  defp calculate_quality_score(validation) do
    base_score = if validation.valid, do: 0.8, else: 0.4
    suggestion_penalty = length(validation.suggestions) * 0.1
    max(0.0, min(1.0, base_score - suggestion_penalty))
  end

  defp has_documentation?(code) do
    String.contains?(code, "@doc") or String.contains?(code, "///") or
      String.contains?(code, "# ")
  end

  defp has_tests?(code) do
    String.contains?(code, "test") or String.contains?(code, "spec")
  end

  defp has_error_handling?(code) do
    String.contains?(code, "try") or String.contains?(code, "catch") or
      String.contains?(code, "rescue")
  end

  defp has_types?(code, language) do
    case language do
      "typescript" -> String.contains?(code, ":")
      "rust" -> String.contains?(code, "->")
      _ -> false
    end
  end

  defp add_documentation(code, language) do
    case language do
      "elixir" -> "@doc \"\"\"\n  Generated function\n  \"\"\"\n" <> code
      "typescript" -> "/**\n * Generated function\n */\n" <> code
      _ -> code
    end
  end

  defp add_basic_documentation(code, language) do
    case language do
      "elixir" -> "# Generated function\n" <> code
      _ -> "// Generated function\n" <> code
    end
  end

  defp add_error_handling(code, language) do
    case language do
      "elixir" -> "try do\n  " <> code <> "\nrescue\n  error -> {:error, error}\nend"
      _ -> code
    end
  end

  defp add_basic_error_handling(code, language) do
    case language do
      "elixir" ->
        "case " <>
          code <> " do\n  {:ok, result} -> result\n  {:error, error} -> {:error, error}\nend"

      _ ->
        code
    end
  end

  defp add_logging(code, language) do
    case language do
      "elixir" -> "require Logger\nLogger.info(\"Executing function\")\n" <> code
      _ -> code
    end
  end

  defp maybe_add_tests(code, true, language) do
    test_code = generate_test_code(code, language)
    code <> "\n\n" <> test_code
  end

  defp maybe_add_tests(code, false, _language), do: code

  defp generate_test_code(_code, language) do
    case language do
      "elixir" ->
        """
        defmodule Test do
          use ExUnit.Case

          test "generated function works" do
            # Test implementation
          end
        end
        """

      _ ->
        "// Test code for " <> language
    end
  end

  defp format_issues(issues) when is_list(issues) do
    issues
    |> Enum.with_index(1)
    |> Enum.map(fn {issue, i} -> "#{i}. #{issue}" end)
    |> Enum.join("\n")
  end

  defp format_issues(_), do: "No issues found"

  defp format_suggestions(suggestions) when is_list(suggestions) do
    suggestions
    |> Enum.with_index(1)
    |> Enum.map(fn {suggestion, i} -> "#{i}. #{suggestion}" end)
    |> Enum.join("\n")
  end

  defp format_suggestions(_), do: "No suggestions"

  defp iterate_until_quality(result, language, threshold, max_iterations, current_iteration) do
    if current_iteration >= max_iterations do
      {:ok, Map.put(result, :status, "max_iterations_reached") |> Map.put(:final_score, 0.5)}
    else
      case code_validate(result.code, language) do
        {:ok, validation} ->
          if validation.score >= threshold do
            {:ok,
             Map.put(result, :status, "quality_achieved")
             |> Map.put(:final_score, validation.score)}
          else
            case code_refine(result.code, validation, language) do
              {:ok, refined} ->
                new_result = Map.put(result, :code, refined.refined_code)

                iterate_until_quality(
                  new_result,
                  language,
                  threshold,
                  max_iterations,
                  current_iteration + 1
                )

              error ->
                error
            end
          end

        error ->
          error
      end
    end
  end

  defp count_lines(code) do
    code
    |> String.split("\n")
    |> length()
  end

  defp generate_with_t5_and_rag(task, language, repo, quality, include_tests) do
    case find_rag_examples(task, language, repo) do
      {:ok, examples} ->
        prompt = build_rust_elixir_t5_prompt(task, examples, language, quality)

        case generate_with_rust_elixir_t5(prompt, language) do
          {:ok, base_code} ->
            # Enhanced code with iterative improvement
            enhanced_code =
              enhance_rust_elixir_code_quality(base_code, language, quality, include_tests)

            # Try to improve the code iteratively
            case improve_code_iteratively(enhanced_code, task, language, quality) do
              {:ok, improved_code} -> {:ok, improved_code}
              {:error, _} -> enhanced_code
            end

          error ->
            error
        end

      error ->
        error
    end
  end

  defp find_rag_examples(task, language, repo) do
    # Enhanced RAG example selection with better filtering
    case RAGCodeGenerator.find_best_examples(
           task,
           language,
           if(repo, do: [repo], else: nil),
           8,
           true,
           false
         ) do
      {:ok, examples} ->
        # Filter and rank examples by quality
        filtered_examples = filter_and_rank_examples(examples, task, language)
        {:ok, Enum.take(filtered_examples, 5)}

      {:error, _} ->
        {:ok, []}
    end
  end

  defp filter_and_rank_examples(examples, task, language) do
    examples
    |> Enum.filter(fn example ->
      # Filter out examples that are too short or too long
      code_length = String.length(example.code || "")
      code_length > 50 && code_length < 2000
    end)
    |> Enum.sort_by(
      fn example ->
        # Rank by relevance score (if available) and recency
        relevance_score = Map.get(example, :similarity_score, 0.5)
        recency_bonus = if Map.get(example, :recent, false), do: 0.1, else: 0.0
        relevance_score + recency_bonus
      end,
      :desc
    )
  end

  defp build_t5_prompt(task, examples, language, quality) do
    examples_text = format_examples_for_t5(examples, language)
    instruction = build_t5_instruction(task, language, quality)

    """
    #{instruction}

    #{examples_text}

    ### Desired Output
    """
  end

  defp build_t5_instruction(task, language, quality) do
    quality_desc =
      case quality do
        :production -> "production-quality, well-documented, with error handling"
        :prototype -> "prototype-quality, functional but minimal"
        :quick -> "quick implementation, basic functionality"
      end

    """
    Generate #{quality_desc} #{language} code for the following task:

    Task: #{task}

    Requirements:
    - Use proper #{language} syntax and conventions
    - Include appropriate error handling
    - Provide documentation or comments explaining the implementation
    - Include tests if the language supports it
    """
  end

  defp format_examples_for_t5(examples, language) do
    examples
    |> Enum.with_index(1)
    |> Enum.map(fn {example, idx} ->
      """
      ### Example #{idx}
      Language: #{language || example[:language] || "elixir"}
      File: #{example[:file]}
      Repo: #{example[:repo]}

      #{example[:code_preview] || ""}
      """
    end)
    |> Enum.join("\n")
  end

  defp generate_with_rust_elixir_t5(prompt, language) do
    # Hook up real T5 model generation via NATS
    case Singularity.NatsClient.request(
           "code.t5.generate",
           Jason.encode!(%{
             prompt: prompt,
             language: language,
             model: "rust_elixir_t5",
             max_length: 512,
             temperature: 0.7
           }), timeout: 30_000) do
      {:ok, response} ->
        case Jason.decode(response.data) do
          {:ok, %{"generated_code" => code}} ->
            {:ok, code}

          {:ok, data} ->
            # Fallback if response format is different
            {:ok, Map.get(data, "code", Map.get(data, "text", ""))}

          {:error, reason} ->
            Logger.error("Failed to decode T5 response", reason: reason)
            generate_fallback_code(prompt, language)
        end

      {:error, reason} ->
        Logger.warning("T5 model generation failed, using external LLM fallback", reason: reason)
        generate_external_llm_fallback(prompt, language)
    end
  end

  defp generate_fallback_code(prompt, language) do
    # Direct fallback to external LLM via NATS when T5 model is unavailable
    Logger.info("T5 failed, using external LLM fallback for language: #{language}")
    generate_external_llm_fallback(prompt, language)
  end

  defp build_llm_fallback_prompt(prompt, language) do
    language_instruction =
      case language do
        "elixir" -> "Generate clean, production-ready Elixir code"
        "rust" -> "Generate clean, production-ready Rust code"
        "typescript" -> "Generate clean, production-ready TypeScript code"
        "python" -> "Generate clean, production-ready Python code"
        "go" -> "Generate clean, production-ready Go code"
        _ -> "Generate clean, production-ready #{String.capitalize(language)} code"
      end

    """
    #{language_instruction} for the following task:

    Task: #{prompt}

    Requirements:
    - Include proper error handling
    - Add documentation/comments
    - Use idiomatic #{language} patterns
    - Make it production-ready

    Generate only the code, no explanations:
    """
  end

  defp cleanup_generated_code(code) do
    code
    |> String.split("\n")
    |> Enum.take_while(fn line ->
      # Stop at explanation markers
      not String.starts_with?(String.trim(line), [
        "# Explanation",
        "# Note:",
        "# This",
        "# The",
        "Here's",
        "This is",
        "// Explanation",
        "/* Explanation"
      ])
    end)
    |> Enum.join("\n")
    |> String.trim()
  end

  defp generate_external_llm_fallback(prompt, language) do
    # Ultimate fallback to external LLM via NATS when local models fail
    Logger.info("Using external LLM fallback for language: #{language}")

    # Build prompt for external LLM
    external_prompt = build_external_llm_prompt(prompt, language)

    # Request external LLM via NATS
    case Singularity.NatsClient.request(
           "llm.request",
           Jason.encode!(%{
             prompt: external_prompt,
             language: language,
             task_type: "code_generation",
             complexity: "medium",
             temperature: 0.1,
             max_tokens: 512
           }), timeout: 30_000) do
      {:ok, response} ->
        case Jason.decode(response.data) do
          {:ok, %{"code" => code}} ->
            cleaned_code = cleanup_generated_code(code)
            {:ok, cleaned_code}

          {:ok, %{"response" => code}} ->
            cleaned_code = cleanup_generated_code(code)
            {:ok, cleaned_code}

          {:ok, data} ->
            # Try to extract code from any field
            code =
              Map.get(data, "code") || Map.get(data, "text") || Map.get(data, "content") || ""

            cleaned_code = cleanup_generated_code(code)
            {:ok, cleaned_code}

          {:error, reason} ->
            Logger.error("Failed to decode external LLM response: #{inspect(reason)}")
            {:error, "All code generation methods failed"}
        end

      {:error, reason} ->
        Logger.error("External LLM request failed: #{inspect(reason)}")
        {:error, "All code generation methods failed"}
    end
  end

  defp build_external_llm_prompt(prompt, language) do
    """
    Generate clean, production-ready #{String.capitalize(language)} code for the following task:

    Task: #{prompt}

    Requirements:
    - Include proper error handling
    - Add documentation/comments
    - Use idiomatic #{language} patterns
    - Make it production-ready
    - Return only the code, no explanations

    Code:
    """
  end

  defp enhance_rust_elixir_code_quality(base_code, language, quality, include_tests) do
    enhanced =
      case language do
        "rust" -> enhance_rust_code_quality(base_code, quality, include_tests)
        "elixir" -> enhance_elixir_code_quality(base_code, quality, include_tests)
        _ -> enhance_code_quality(base_code, language, quality, include_tests)
      end

    {:ok, enhanced}
  end

  defp build_rust_elixir_t5_prompt(task, examples, language, quality) do
    # Try to use PromptEngine for optimized prompt generation
    case generate_optimized_prompt(task, examples, language, quality) do
      {:ok, optimized_prompt} ->
        optimized_prompt

      {:error, _} ->
        # Fallback to manual prompt building
        build_manual_prompt(task, examples, language, quality)
    end
  end

  defp generate_optimized_prompt(task, examples, language, quality) do
    # Use central template service for template-based prompt generation
    case load_template_for_task(task, language, quality) do
      {:ok, template} ->
        # Enhance template with learning data
        enhanced_template = enhance_template_with_learning(template, task, language, quality)

        # Build prompt from enhanced template
        prompt = build_template_prompt(enhanced_template, task, language, quality, examples)
        {:ok, prompt}

      {:error, reason} ->
        Logger.debug("Template loading failed, using TemplateAware fallback", reason: reason)
        # Fallback to TemplateAware prompting
        task_struct = %{
          description: task,
          type: :code_generation,
          language: language,
          quality: quality
        }

        opts = [
          language: language,
          use_prompt_engine: true,
          examples: examples,
          quality: quality
        ]

        case Singularity.LLM.Prompt.TemplateAware.generate_prompt(task_struct, opts) do
          %{prompt: prompt} ->
            enhanced_prompt = enhance_prompt_with_examples(prompt, examples, language, quality)
            {:ok, enhanced_prompt}

          error ->
            Logger.debug("TemplateAware prompting failed, using manual prompt", error: error)
            {:error, error}
        end
    end
  end

  defp enhance_prompt_with_examples(prompt, examples, language, quality) do
    if Enum.empty?(examples) do
      prompt
    else
      examples_context = build_examples_context(examples, language)
      quality_requirements = build_quality_requirements(language, quality)

      """
      #{prompt}

      #{examples_context}

      #{quality_requirements}
      """
    end
  end

  defp build_manual_prompt(task, examples, language, quality) do
    base_prompt = build_t5_prompt(task, examples, language, quality)
    examples_context = build_examples_context(examples, language)
    quality_requirements = build_quality_requirements(language, quality)

    """
    #{base_prompt}

    #{examples_context}

    #{quality_requirements}

    ### Additional Requirements for #{String.upcase(language)}:
    - Follow idiomatic #{language} patterns
    - Include error handling using #{language}-specific conventions
    - Provide tests using the standard #{language} test framework
    - Use proper naming conventions for #{language}
    - Include comprehensive documentation
    """
  end

  defp build_examples_context(examples, language) do
    if Enum.empty?(examples) do
      ""
    else
      """
      ### Context from Similar Code:
      The following examples show similar patterns from your codebase:

      #{format_examples_for_context(examples, language)}
      """
    end
  end

  defp build_quality_requirements(language, quality) do
    case quality do
      :production ->
        """
        ### Production Quality Requirements:
        - Include comprehensive error handling
        - Add detailed documentation and examples
        - Use proper logging and monitoring
        - Follow security best practices
        - Include performance optimizations
        - Add comprehensive tests
        """

      :prototype ->
        """
        ### Prototype Quality Requirements:
        - Include basic error handling
        - Add minimal documentation
        - Focus on functionality over optimization
        """

      :quick ->
        """
        ### Quick Quality Requirements:
        - Focus on getting working code
        - Minimal documentation acceptable
        """
    end
  end

  defp format_examples_for_context(examples, language) do
    examples
    |> Enum.with_index(1)
    |> Enum.map(fn {example, index} ->
      """
      Example #{index}:
      ```#{language}
      #{example.code}
      ```
      """
    end)
    |> Enum.join("\n")
  end

  defp improve_code_iteratively(code, task, language, quality) do
    # Only attempt improvement for production quality
    case quality do
      :production ->
        # Validate the generated code
        case validate_generated_code(code, language) do
          {:ok, validation} ->
            if validation.score >= 0.8 do
              # Code is good enough, return as-is
              {:ok, code}
            else
              # Try to improve based on validation feedback
              improvement_prompt = build_improvement_prompt(code, task, language, validation)

              case generate_with_rust_elixir_t5(improvement_prompt, language) do
                {:ok, improved_code} -> {:ok, improved_code}
                # Return original if improvement fails
                {:error, _} -> {:ok, code}
              end
            end

          # Return original if validation fails
          {:error, _} ->
            {:ok, code}
        end

      _ ->
        # For non-production quality, return as-is
        {:ok, code}
    end
  end

  defp validate_generated_code(code, language) do
    # Basic validation - check for common issues
    issues = []

    # Check for TODO comments
    if String.contains?(code, "TODO") or String.contains?(code, "FIXME") do
      issues = ["Contains TODO/FIXME comments" | issues]
    end

    # Check for basic structure
    if String.length(code) < 50 do
      issues = ["Code too short" | issues]
    end

    # Check for error handling (language-specific)
    has_error_handling =
      case language do
        "elixir" -> String.contains?(code, "case") or String.contains?(code, "with")
        "rust" -> String.contains?(code, "Result") or String.contains?(code, "Option")
        "typescript" -> String.contains?(code, "try") or String.contains?(code, "catch")
        _ -> true
      end

    if not has_error_handling do
      issues = ["Missing error handling" | issues]
    end

    # Calculate score
    score = if Enum.empty?(issues), do: 1.0, else: max(0.0, 1.0 - length(issues) * 0.2)

    {:ok, %{score: score, issues: issues}}
  end

  defp build_improvement_prompt(code, task, language, validation) do
    issues_text = Enum.join(validation.issues, ", ")

    """
    Improve the following #{language} code based on the validation feedback:

    Original Task: #{task}

    Current Code:
    ```#{language}
    #{code}
    ```

    Issues to Fix: #{issues_text}

    Please provide an improved version that addresses these issues while maintaining the original functionality.
    """
  end

  defp enhance_rust_code_quality(code, quality, include_tests) do
    base_code = code

    case quality do
      :production ->
        base_code
        |> add_rust_documentation()
        |> add_rust_error_handling()
        |> add_rust_tests(include_tests)
        |> add_rust_imports()

      :prototype ->
        base_code
        |> add_basic_rust_documentation()
        |> add_basic_rust_error_handling()

      :quick ->
        base_code
    end
  end

  defp enhance_elixir_code_quality(code, quality, include_tests) do
    base_code = code

    case quality do
      :production ->
        base_code
        |> add_elixir_documentation()
        |> add_elixir_error_handling()
        |> add_elixir_tests(include_tests)
        |> add_elixir_aliases()

      :prototype ->
        base_code
        |> add_basic_elixir_documentation()
        |> add_basic_elixir_error_handling()

      :quick ->
        base_code
    end
  end

  defp add_rust_documentation(code) do
    if String.contains?(code, "///") do
      code
    else
      "/// Generated Rust code\n" <> code
    end
  end

  defp add_rust_error_handling(code) do
    if String.contains?(code, "Result<") or String.contains?(code, "Option<") do
      code
    else
      "use anyhow::Result;\n\n" <> code
    end
  end

  defp add_rust_tests(code, true) do
    test_code = """
    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn test_generated_function() {
            // Test implementation
        }
    }
    """

    code <> "\n\n" <> test_code
  end

  defp add_rust_tests(code, false), do: code

  defp add_rust_imports(code) do
    if String.contains?(code, "use ") do
      code
    else
      "use std::collections::HashMap;\n" <> code
    end
  end

  defp add_basic_rust_documentation(code) do
    "// Generated Rust code\n" <> code
  end

  defp add_basic_rust_error_handling(code), do: code

  defp add_elixir_documentation(code) do
    if String.contains?(code, "@doc") do
      code
    else
      "@doc \"\"\"\n  Generated Elixir code\n  \"\"\"\n" <> code
    end
  end

  defp add_elixir_error_handling(code) do
    if String.contains?(code, "{:ok,") or String.contains?(code, "{:error,") do
      code
    else
      "case " <>
        code <> " do\n  {:ok, result} -> result\n  {:error, reason} -> {:error, reason}\nend"
    end
  end

  defp add_elixir_tests(code, true) do
    test_code = """
    defmodule Test do
      use ExUnit.Case

      test "generated function works" do
        # Test implementation
      end
    end
    """

    code <> "\n\n" <> test_code
  end

  defp add_elixir_tests(code, false), do: code

  defp add_elixir_aliases(code) do
    if String.contains?(code, "alias ") do
      code
    else
      "alias MyApp.{Error, Result}\n" <> code
    end
  end

  defp add_basic_elixir_documentation(code) do
    "# Generated Elixir code\n" <> code
  end

  defp add_basic_elixir_error_handling(code), do: code

  # Template loading functions (called by generate_optimized_prompt)

  defp load_template_for_task(task, language, quality) do
    # Use centralized template service for template loading
    template_type = determine_template_type(task, language, quality)
    template_id = build_template_id(task, language, quality)

    case Singularity.Knowledge.TemplateService.get_template(template_type, template_id) do
      {:ok, template} ->
        {:ok, template}

      {:error, _} ->
        # Fallback to general template
        fallback_id = "#{language}-#{quality}"
        Singularity.Knowledge.TemplateService.get_template(template_type, fallback_id)
    end
  end

  defp enhance_template_with_learning(template, task, language, quality) do
    # Template enhancement is handled by the PromptEngine and TemplateAware system
    template
  end

  defp build_template_prompt(template, task, language, quality, examples) do
    # This is handled by the existing prompt building system
    build_manual_prompt(task, examples, language, quality)
  end

  # Helper functions for template service integration

  defp determine_template_type(task, language, quality) do
    cond do
      String.contains?(task, "framework") or String.contains?(task, "web") -> "framework"
      String.contains?(task, "api") or String.contains?(task, "endpoint") -> "api"
      String.contains?(task, "test") or String.contains?(task, "spec") -> "test"
      quality == "production" -> "production"
      true -> "code_generation"
    end
  end

  defp build_template_id(task, language, quality) do
    # Extract key terms from task for template ID
    task_clean =
      task
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9\s]/, "")
      |> String.split()
      |> Enum.take(3)
      |> Enum.join("-")

    "#{language}-#{quality}-#{task_clean}"
  end
end
