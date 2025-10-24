defmodule Singularity.Tools.CodeGeneration do
  @moduledoc """
  Code Generation Tools - SPARC + RAG for autonomous code generation

  **PURPOSE**: Enable agents to write production-quality code using SPARC methodology
  combined with RAG (Retrieval-Augmented Generation) from your codebases.

  ## Module Identity (JSON)

  ```json
  {
    "module_name": "Singularity.Tools.CodeGeneration",
    "purpose": "Tool interface for autonomous code generation",
    "type": "Tool Registry + Adapter",
    "operates_on": "Code generation tasks (any language)",
    "delegates_to": "Singularity.CodeGeneration.Orchestrator.GenerationOrchestrator",
    "dependencies": ["GenerationOrchestrator", "RAGCodeGenerator", "Catalog"]
  }
  ```

  ## Architecture Diagram (Mermaid)

  ```mermaid
  graph TD
      A[Agent Request] --> B{Tool Type?}
      B -->|code_generate| C[GenerationOrchestrator.generate]
      B -->|code_generate_quick| C
      B -->|code_find_examples| D[RAGCodeGenerator.find_best_examples]
      B -->|code_validate| E[Validation Loop]
      B -->|code_refine| E
      B -->|code_iterate| F[Iterative Quality Loop]

      C --> G{Registered Generators}
      G -->|code_generator| H[CodeGeneratorImpl]
      G -->|rag| I[RAGGeneratorImpl]
      G -->|quality| J[QualityGenerator]

      H --> K[Production Code]
      I --> K
      J --> K

      E --> C
      F --> C
  ```

  ## Call Graph (YAML)

  ```yaml
  CodeGeneration:
    calls:
      - GenerationOrchestrator.generate/2     # Config-driven orchestration
      - RAGCodeGenerator.find_best_examples/6 # Semantic code search
    called_by:
      - Singularity.Tools.Catalog             # Tool registry
      - Agents (via tool execution)           # Agent-driven code generation
    registers:
      - code_generate                         # Multi-generator (via orchestrator)
      - code_generate_quick                   # RAG only (via orchestrator)
      - code_find_examples                    # Direct search
      - code_validate                         # Quality validation
      - code_refine                           # Refinement loop
      - code_iterate                          # Iterative improvement
  ```

  ## Anti-Patterns

  **DO NOT call individual generators directly:**
  - ❌ `CodeGenerator.generate(task)` - Use GenerationOrchestrator via this tool
  - ❌ `QualityCodeGenerator.enforce_quality(code)` - Use code_validate tool
  - ❌ `RAGCodeGenerator.generate(opts)` - Use code_generate_quick tool or orchestrator
  - ❌ Bypass tools to call orchestrator - Always use these tools for agent-driven generation

  **Use this module when:**
  - ✅ Agents need to generate code via tools
  - ✅ Need quality-assured code generation with orchestration
  - ✅ Want config-driven generator selection

  **Use GenerationOrchestrator directly (bypass tools) when:**
  - ✅ Internal batch processing
  - ✅ Complex custom workflows
  - ✅ Direct API without tool wrapping

  ## Search Keywords

  code-generation, sparc-methodology, rag, quality-assurance, autonomous-coding,
  tool-registry, agent-tools, llm-code-generation, t5-local, pattern-based,
  iterative-refinement, production-quality, elixir-rust-typescript-python

  ## Tools Provided

  - `code_generate` - Generate code using SPARC + RAG (production quality)
  - `code_generate_quick` - Generate code using RAG only (fast, pattern-based)
  - `code_find_examples` - Find similar code examples for reference
  - `code_validate` - Validate generated code quality
  - `code_refine` - Refine code based on validation feedback
  - `code_iterate` - Iteratively improve until quality threshold met
  """

  alias Singularity.Tools.Catalog
  alias Singularity.Schemas.Tools.Tool
  alias Singularity.CodeGeneration.Orchestrator.GenerationOrchestrator
  alias Singularity.CodeGeneration.Implementations.RAGCodeGenerator

  require Logger

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

    spec = %{
      "task" => task,
      "language" => language,
      "quality" => quality
    }

    # Use GenerationOrchestrator for config-driven generation with all registered generators
    case GenerationOrchestrator.generate(spec) do
      {:ok, results} ->
        # Merge results from all generators (code_generator, rag, quality, etc.)
        merged_code = merge_generation_results(results)

        {:ok,
         %{
           task: task,
           language: language,
           method: "GenerationOrchestrator (multi-generator)",
           code: merged_code,
           quality: quality,
           lines: count_lines(merged_code),
           generator_count: map_size(results)
         }}

      {:error, reason} ->
        {:error, "Code generation failed: #{inspect(reason)}"}
    end
  end

  def code_generate_quick(%{"task" => task} = args, _ctx) do
    language = Map.get(args, "language", "elixir")
    _repos = Map.get(args, "repos")
    top_k = Map.get(args, "top_k", 5)

    spec = %{
      "task" => task,
      "language" => language,
      "top_k" => top_k
    }

    # Use GenerationOrchestrator with RAG generator only (fast, pattern-based)
    case GenerationOrchestrator.generate(spec, generator_types: [:rag]) do
      {:ok, results} ->
        code = get_rag_result(results)

        {:ok,
         %{
           task: task,
           language: language,
           method: "RAG (pattern-based via orchestrator)",
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

    spec = %{
      "task" => "Validate and enhance this #{language} code",
      "code" => code,
      "language" => language,
      "quality" => quality_level
    }

    # Use GenerationOrchestrator with quality generator only
    case GenerationOrchestrator.generate(spec, generator_types: [:quality]) do
      {:ok, results} ->
        quality_result = get_quality_result(results)

        {:ok,
         %{
           language: language,
           quality_level: quality_level,
           valid: true,
           score: quality_result.quality_score,
           issues: [],
           suggestions: [],
           completeness: %{
             has_docs: String.length(quality_result.docs) > 100,
             has_tests: String.length(quality_result.tests) > 100,
             has_error_handling: String.contains?(quality_result.code, ["rescue", "try", "handle"]),
             has_types: String.length(quality_result.specs) > 20
           }
         }}

      {:error, reason} ->
        Logger.warning("Code validation failed: #{inspect(reason)}")
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

  defp iterate_until_quality(code, language, _threshold, max_iter, current_iter, history)
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

  # Extract code from merged generation results
  defp merge_generation_results(results) when is_map(results) do
    results
    |> Enum.find_value(fn {_generator_type, result} ->
      case result do
        %{"code" => code} -> code
        %{code: code} -> code
        code when is_binary(code) -> code
        _ -> nil
      end
    end)
    |> Kernel.||("# No code generated")
  end

  # Extract RAG result from orchestrator results
  defp get_rag_result(results) when is_map(results) do
    case Map.get(results, :rag) do
      result when is_map(result) ->
        Map.get(result, "code") || Map.get(result, :code) || ""

      result when is_binary(result) ->
        result

      _ ->
        merge_generation_results(results)
    end
  end

  # Extract quality result from orchestrator results
  defp get_quality_result(results) when is_map(results) do
    case Map.get(results, :quality) do
      result when is_map(result) ->
        result

      _ ->
        # Fallback: return a default structure
        %{
          code: "",
          docs: "",
          specs: "",
          tests: "",
          quality_score: 0.0
        }
    end
  end
end
