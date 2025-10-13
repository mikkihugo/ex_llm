defmodule Singularity.Tools.CodeGeneration do
  @moduledoc """
  Code generation tools using SPARC methodology + RAG.

  Enables agents to write code autonomously using:
  - SPARC Methodology (5-phase: Spec → Pseudocode → Arch → Refine → Complete)
  - RAG (Retrieval-Augmented Generation from YOUR codebases)
  - Combined approach (default: SPARC + RAG for best quality)

  ## Tools

  - `code_generate` - Generate code using SPARC + RAG (production quality)
  - `code_generate_quick` - Generate code using RAG only (fast, pattern-based)
  - `code_find_examples` - Find similar code examples for reference
  - `code_validate` - Validate generated code quality
  - `code_refine` - Refine code based on validation feedback (NEW!)
  - `code_iterate` - Iteratively improve until quality threshold met (NEW!)
  """

  alias Singularity.Tools.{Tool, Catalog}
  alias Singularity.{MethodologyExecutor, RAGCodeGenerator, QualityCodeGenerator, AdaptiveCodeGenerator}

  @doc "Register code generation tools with the shared registry."
  def register(provider) do
    Catalog.add_tools(provider, [
      code_generate_tool(),
      code_generate_quick_tool(),
      code_find_examples_tool(),
      code_validate_tool(),
      code_refine_tool(),
      code_iterate_tool()
    ])
  end

  # ============================================================================
  # TOOL DEFINITIONS
  # ============================================================================

  defp code_generate_tool do
    Tool.new!(%{
      name: "code_generate",
      description: """
      Generate production-quality code using SPARC methodology + RAG.

      Uses 5-phase approach (Specification → Pseudocode → Architecture → Refinement → Completion)
      combined with examples from YOUR codebases for best results.

      Returns: Complete, production-ready code with docs and error handling.
      """,
      display_text: "Generate Code (SPARC + RAG)",
      parameters: [
        %{
          name: "task",
          type: :string,
          required: true,
          description: "What to generate (e.g., 'Create GenServer for caching with TTL')"
        },
        %{
          name: "language",
          type: :string,
          required: false,
          description:
            "Target language: 'elixir', 'rust', 'typescript', 'python' (default: 'elixir')"
        },
        %{
          name: "repo",
          type: :string,
          required: false,
          description: "Codebase to learn patterns from (optional)"
        },
        %{
          name: "quality",
          type: :string,
          required: false,
          description: "Quality level: 'production', 'prototype', 'quick' (default: 'production')"
        },
        %{
          name: "include_tests",
          type: :boolean,
          required: false,
          description: "Generate tests (default: true for production)"
        }
      ],
      function: &code_generate/2
    })
  end

  defp code_generate_quick_tool do
    Tool.new!(%{
      name: "code_generate_quick",
      description: """
      Quick code generation using RAG (pattern-based).

      Finds similar code in YOUR codebases and generates matching code.
      Faster than full SPARC but less thorough.

      Good for: Simple functions, quick prototypes, following existing patterns.
      """,
      display_text: "Quick Generate (RAG)",
      parameters: [
        %{
          name: "task",
          type: :string,
          required: true,
          description: "What to generate"
        },
        %{
          name: "language",
          type: :string,
          required: false,
          description: "Target language (default: 'elixir')"
        },
        %{
          name: "repos",
          type: :array,
          required: false,
          description: "List of repos to search for examples"
        },
        %{
          name: "top_k",
          type: :integer,
          required: false,
          description: "Number of example patterns to use (default: 5)"
        }
      ],
      function: &code_generate_quick/2
    })
  end

  defp code_find_examples_tool do
    Tool.new!(%{
      name: "code_find_examples",
      description: """
      Find similar code examples from YOUR codebases.

      Uses semantic search to find the most relevant code patterns.
      Great for understanding existing patterns before generating new code.
      """,
      display_text: "Find Code Examples",
      parameters: [
        %{
          name: "query",
          type: :string,
          required: true,
          description: "What to search for (e.g., 'async worker pattern')"
        },
        %{
          name: "language",
          type: :string,
          required: false,
          description: "Filter by language (optional)"
        },
        %{
          name: "repos",
          type: :array,
          required: false,
          description: "Repos to search (default: all)"
        },
        %{
          name: "limit",
          type: :integer,
          required: false,
          description: "Max results (default: 5)"
        }
      ],
      function: &code_find_examples/2
    })
  end

  defp code_validate_tool do
    Tool.new!(%{
      name: "code_validate",
      description: """
      Validate code quality against standards.

      Checks:
      - Syntax correctness
      - Quality standards adherence
      - Completeness (docs, tests, error handling)
      - Best practices
      """,
      display_text: "Validate Code Quality",
      parameters: [
        %{
          name: "code",
          type: :string,
          required: true,
          description: "Code to validate"
        },
        %{
          name: "language",
          type: :string,
          required: true,
          description: "Code language"
        },
        %{
          name: "quality_level",
          type: :string,
          required: false,
          description: "Expected quality: 'production', 'prototype' (default: 'production')"
        }
      ],
      function: &code_validate/2
    })
  end

  defp code_refine_tool do
    Tool.new!(%{
      name: "code_refine",
      description: """
      Refine code based on validation feedback.

      Takes validation results and improves the code to address issues.
      Use this after `code_validate` to fix quality issues.

      Example workflow:
      1. code_generate → get initial code
      2. code_validate → check quality
      3. code_refine → fix issues (THIS TOOL)
      4. code_validate → verify fixes
      """,
      display_text: "Refine Code",
      parameters: [
        %{
          name: "code",
          type: :string,
          required: true,
          description: "Original code to refine"
        },
        %{
          name: "validation_result",
          type: :object,
          required: true,
          description: "Validation result from code_validate (issues, score, etc.)"
        },
        %{
          name: "language",
          type: :string,
          required: true,
          description: "Code language"
        },
        %{
          name: "focus",
          type: :string,
          required: false,
          description: "Focus area: 'docs', 'tests', 'error_handling', 'all' (default: 'all')"
        }
      ],
      function: &code_refine/2
    })
  end

  defp code_iterate_tool do
    Tool.new!(%{
      name: "code_iterate",
      description: """
      Iteratively improve code until quality threshold is met.

      Automatically loops: generate → validate → refine until score >= threshold.
      Max iterations to prevent infinite loops.

      Use this for fully autonomous quality assurance!
      """,
      display_text: "Iterate Until Quality Met",
      parameters: [
        %{
          name: "task",
          type: :string,
          required: true,
          description: "What to generate"
        },
        %{
          name: "language",
          type: :string,
          required: false,
          description: "Target language (default: 'elixir')"
        },
        %{
          name: "quality_threshold",
          type: :number,
          required: false,
          description: "Min quality score 0-1 (default: 0.85)"
        },
        %{
          name: "max_iterations",
          type: :integer,
          required: false,
          description: "Max refinement rounds (default: 3)"
        }
      ],
      function: &code_iterate/2
    })
  end

  # ============================================================================
  # TOOL IMPLEMENTATIONS
  # ============================================================================

  def code_generate(%{"task" => task} = args, _ctx) do
    language = Map.get(args, "language", "elixir")
    quality = Map.get(args, "quality", "production") |> String.to_atom()
    include_tests = Map.get(args, "include_tests", quality == :production)

    # Use adaptive generation (T5 local or LLM API)
    case AdaptiveCodeGenerator.generate(task, language: language, quality: quality) do
      {:ok, code} ->
        method = if AdaptiveCodeGenerator.t5_available?(), do: "T5-small (local)", else: "LLM API"

        {:ok,
         %{
           task: task,
           language: language,
           method: method,
           code: code,
           quality: quality,
           lines: count_lines(code),
           includes_tests: include_tests
         }}

      {:error, reason} ->
        {:error, "Code generation failed: #{inspect(reason)}"}
    end
  end

  def code_generate_quick(%{"task" => task} = args, _ctx) do
    language = Map.get(args, "language", "elixir")
    repos = Map.get(args, "repos")
    top_k = Map.get(args, "top_k", 5)

    opts = [
      task: task,
      language: language,
      repos: repos,
      top_k: top_k,
      prefer_recent: true,
      include_tests: false
    ]

    case RAGCodeGenerator.generate(opts) do
      {:ok, code} ->
        {:ok,
         %{
           task: task,
           language: language,
           method: "RAG (pattern-based)",
           code: code,
           quality: "quick",
           lines: count_lines(code),
           examples_used: top_k
         }}

      {:error, reason} ->
        {:error, "Quick code generation failed: #{inspect(reason)}"}
    end
  end

  def code_find_examples(%{"query" => query} = args, _ctx) do
    language = Map.get(args, "language")
    repos = Map.get(args, "repos")
    limit = Map.get(args, "limit", 5)

    case RAGCodeGenerator.find_best_examples(
           query,
           language,
           repos,
           limit,
           # prefer_recent
           true,
           # exclude_tests
           false
         ) do
      {:ok, examples} ->
        formatted_examples =
          Enum.map(examples, fn ex ->
            %{
              file: ex.file_path,
              repo: ex.repo || "unknown",
              similarity: Float.round(ex.similarity, 3),
              code_preview: String.slice(ex.content, 0, 200) <> "...",
              language: ex.language
            }
          end)

        {:ok,
         %{
           query: query,
           language: language,
           examples: formatted_examples,
           count: length(formatted_examples)
         }}

      {:error, reason} ->
        {:error, "Failed to find examples: #{inspect(reason)}"}
    end
  end

  def code_validate(%{"code" => code, "language" => language} = args, _ctx) do
    quality_level = Map.get(args, "quality_level", "production") |> String.to_atom()

    case QualityCodeGenerator.validate_code(code, language, quality_level) do
      {:ok, validation} ->
        {:ok,
         %{
           language: language,
           quality_level: quality_level,
           valid: validation.valid,
           score: validation.score,
           issues: validation.issues,
           suggestions: validation.suggestions,
           completeness: %{
             has_docs: validation.has_docs,
             has_tests: validation.has_tests,
             has_error_handling: validation.has_error_handling,
             has_types: validation.has_types
           }
         }}

      {:error, reason} ->
        {:error, "Code validation failed: #{inspect(reason)}"}
    end
  end

  def code_refine(
        %{"code" => code, "validation_result" => validation, "language" => language} = args,
        _ctx
      ) do
    focus = Map.get(args, "focus", "all")

    # Build refinement prompt based on validation issues
    issues_text = format_issues(validation["issues"] || [])
    suggestions_text = format_suggestions(validation["suggestions"] || [])

    prompt = """
    Refine this #{language} code to address quality issues:

    ORIGINAL CODE:
    ```#{language}
    #{code}
    ```

    VALIDATION ISSUES (Score: #{validation["score"]}):
    #{issues_text}

    SUGGESTIONS:
    #{suggestions_text}

    COMPLETENESS GAPS:
    #{format_completeness(validation["completeness"] || %{})}

    #{if focus != "all", do: "FOCUS ON: #{focus}", else: "Address ALL issues"}

    Return ONLY the refined code, maintaining the same functionality but fixing quality issues.
    """

    # Use RAG to find better examples
    {:ok, examples} =
      RAGCodeGenerator.find_best_examples(
        "high quality #{language} #{focus}",
        language,
        nil,
        3,
        true,
        false
      )

    # Generate refined code
    {:ok, refined_code} =
      RAGCodeGenerator.generate(
        task: "Refine code fixing: #{issues_text}",
        language: language,
        context: %{
          original_code: code,
          issues: validation["issues"],
          examples: examples,
          prompt: prompt
        }
      )

    {:ok,
     %{
       original_code: code,
       refined_code: refined_code,
       issues_addressed: length(validation["issues"] || []),
       focus: focus,
       lines_changed: abs(count_lines(refined_code) - count_lines(code))
     }}
  end

  def code_iterate(%{"task" => task} = args, ctx) do
    language = Map.get(args, "language", "elixir")
    threshold = Map.get(args, "quality_threshold", 0.85)
    max_iterations = Map.get(args, "max_iterations", 3)

    # Initial generation
    {:ok, gen_result} = code_generate(%{"task" => task, "language" => language}, ctx)
    current_code = gen_result.code

    # Iteration loop
    iterations = iterate_until_quality(current_code, language, threshold, max_iterations, 0, [])

    final_iteration = List.last(iterations)

    {:ok,
     %{
       task: task,
       language: language,
       threshold: threshold,
       iterations: length(iterations),
       max_iterations: max_iterations,
       final_code: final_iteration.code,
       final_score: final_iteration.score,
       threshold_met: final_iteration.score >= threshold,
       iteration_history:
         Enum.map(iterations, fn it ->
           %{iteration: it.iteration, score: it.score, issues_count: length(it.issues)}
         end)
     }}
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp iterate_until_quality(code, language, threshold, max_iter, current_iter, history)
       when current_iter >= max_iter do
    # Max iterations reached
    {:ok, validation} = code_validate(%{"code" => code, "language" => language}, nil)

    history ++
      [%{iteration: current_iter, code: code, score: validation.score, issues: validation.issues}]
  end

  defp iterate_until_quality(code, language, threshold, max_iter, current_iter, history) do
    # Validate current code
    {:ok, validation} = code_validate(%{"code" => code, "language" => language}, nil)

    iteration_result = %{
      iteration: current_iter,
      code: code,
      score: validation.score,
      issues: validation.issues
    }

    new_history = history ++ [iteration_result]

    if validation.score >= threshold do
      # Threshold met!
      new_history
    else
      # Refine and continue
      {:ok, refined} =
        code_refine(
          %{
            "code" => code,
            "validation_result" => validation,
            "language" => language
          },
          nil
        )

      iterate_until_quality(
        refined.refined_code,
        language,
        threshold,
        max_iter,
        current_iter + 1,
        new_history
      )
    end
  end

  defp format_issues([]), do: "None"

  defp format_issues(issues) do
    issues
    |> Enum.with_index(1)
    |> Enum.map(fn {issue, idx} -> "  #{idx}. #{issue}" end)
    |> Enum.join("\n")
  end

  defp format_suggestions([]), do: "None"

  defp format_suggestions(suggestions) do
    suggestions
    |> Enum.with_index(1)
    |> Enum.map(fn {suggestion, idx} -> "  #{idx}. #{suggestion}" end)
    |> Enum.join("\n")
  end

  defp format_completeness(completeness) do
    [
      "Has docs: #{completeness["has_docs"] || false}",
      "Has tests: #{completeness["has_tests"] || false}",
      "Has error handling: #{completeness["has_error_handling"] || false}",
      "Has types: #{completeness["has_types"] || false}"
    ]
    |> Enum.join("\n")
  end

  defp count_lines(code) when is_binary(code) do
    code
    |> String.split("\n")
    |> length()
  end

  defp count_lines(_), do: 0
end
