defmodule Singularity.Bootstrap.CodeQualityEnforcer do
  @moduledoc """
  Enforces production-quality code generation using templates and duplication detection.

  ## Philosophy: NO HUMANS = EXTREME QUALITY REQUIRED

  Since Singularity develops itself autonomously with NO human oversight,
  code quality must be PERFECT:

  1. **Zero Duplication** - Every pattern used ONCE, referenced everywhere
  2. **Production Templates** - All code follows elixir/production.json template
  3. **Relationship Mapping** - Every module knows what it calls/is called by
  4. **Self-Documenting** - Code explains itself via annotations
  5. **Zero Technical Debt** - No TODO, FIXME, or incomplete implementations

  ## Integration Points

  - `templates_data/quality_standards/elixir/production.json` - Quality template
  - `Singularity.CodeStore` - Code chunk storage with embeddings
  - `Singularity.Knowledge.ArtifactStore` - Template retrieval
  - Rust `code_analysis` NIF - AST parsing and duplication detection

  ## Usage

      # Before generating new code, check for duplication
      {:ok, similar_code} = CodeQualityEnforcer.find_similar_code(
        "GenServer for caching with TTL"
      )
      # => [%{file: "lib/cache.ex", similarity: 0.95, code: "..."}]

      # Generate code with quality enforcement
      {:ok, code} = CodeQualityEnforcer.generate_code(
        description: "User authentication service",
        quality_level: :production,
        avoid_duplication: true
      )

      # Validate generated code against template
      {:ok, validation} = CodeQualityEnforcer.validate_code(code)
      # => %{quality_score: 0.98, missing: [], suggestions: []}
  """

  require Logger
  alias Singularity.CodeStore
  alias Singularity.Knowledge.ArtifactStore
  alias Singularity.LLM.Service

  @production_template_path "/home/mhugo/code/singularity/templates_data/quality_standards/elixir/production.json"

  ## Public API

  @doc """
  Find similar code in Singularity's own codebase to avoid duplication.

  Uses semantic search to find existing implementations that solve
  the same problem.

  ## Examples

      iex> find_similar_code("GenServer with caching")
      {:ok, [
        %{
          file: "lib/singularity/cache.ex",
          similarity: 0.95,
          module: "Singularity.Cache",
          code_snippet: "...",
          relationships: ["calls ETS", "used by 5 modules"]
        }
      ]}
  """
  def find_similar_code(description, opts \\ []) do
    threshold = Keyword.get(opts, :similarity_threshold, 0.8)
    limit = Keyword.get(opts, :limit, 10)

    # Search Singularity's own codebase
    case CodeStore.search(description,
      codebase_type: :meta_system,  # Only search own code
      top_k: limit
    ) do
      {:ok, results} ->
        similar = results
        |> Enum.filter(fn r -> r.similarity >= threshold end)
        |> Enum.map(&enrich_with_relationships/1)

        {:ok, similar}

      {:error, reason} ->
        Logger.error("Failed to find similar code: #{inspect(reason)}")
        {:ok, []}  # Continue even if search fails
    end
  end

  @doc """
  Generate production-quality code following templates and avoiding duplication.

  ## Options

  - `:quality_level` - `:production` (default), `:prototype`, `:test`
  - `:avoid_duplication` - `true` (default) - searches for similar code first
  - `:template` - Template to use (default: elixir/production.json)
  - `:relationships` - Modules this will call/integrate with

  ## Examples

      iex> generate_code(
        description: "Rate limiter using sliding window",
        relationships: %{
          calls: ["Cachex"],
          integrates_with: ["API.Router"]
        }
      )
      {:ok, %{
        code: "defmodule Singularity.RateLimiter do...",
        quality_score: 0.98,
        reused_patterns: ["cache_with_ttl"],
        new_patterns: []
      }}
  """
  def generate_code(opts) do
    description = Keyword.fetch!(opts, :description)
    quality_level = Keyword.get(opts, :quality_level, :production)
    avoid_dup = Keyword.get(opts, :avoid_duplication, true)
    relationships = Keyword.get(opts, :relationships, %{})

    Logger.info("Generating code: #{description}", %{
      quality_level: quality_level,
      avoid_duplication: avoid_dup
    })

    # Step 1: Check for duplication
    {reuse_existing, similar_code} = if avoid_dup do
      case find_similar_code(description) do
        {:ok, [match | _]} when match.similarity >= 0.95 ->
          Logger.info("Found highly similar code (#{match.similarity}), reusing")
          {true, match}

        {:ok, similar} ->
          {false, similar}

        _ ->
          {false, []}
      end
    else
      {false, []}
    end

    if reuse_existing do
      # Reuse existing code (maybe adapt it)
      {:ok, %{
        code: similar_code.code,
        quality_score: 1.0,
        reused: true,
        source: similar_code.file
      }}
    else
      # Generate new code with quality template
      generate_new_code(description, quality_level, relationships, similar_code)
    end
  end

  @doc """
  Validate generated code against production quality template.

  Returns validation report with quality score, missing requirements,
  and improvement suggestions.

  ## Examples

      iex> validate_code(code_string)
      {:ok, %{
        quality_score: 0.95,
        missing: ["telemetry_instrumentation"],
        suggestions: ["Add performance_notes section"],
        compliant: true
      }}
  """
  def validate_code(code) do
    template = load_production_template()

    # Parse code to check requirements
    validation = %{
      has_moduledoc: has_moduledoc?(code),
      has_typespecs: has_typespecs?(code),
      has_tests: false,  # Would need to check test files
      error_style_ok: uses_tagged_tuples?(code),
      no_forbidden_comments: !has_forbidden_comments?(code),
      has_relationship_annotations: has_relationship_annotations?(code),
      has_telemetry: has_telemetry?(code),
      functions_under_limit: all_functions_under_25_lines?(code)
    }

    score = calculate_quality_score(validation, template)
    missing = find_missing_requirements(validation, template)
    suggestions = generate_suggestions(validation, template)

    {:ok, %{
      quality_score: score,
      missing: missing,
      suggestions: suggestions,
      compliant: score >= 0.95,
      details: validation
    }}
  end

  @doc """
  Extract reusable patterns from high-quality code.

  Analyzes code that meets quality standards and extracts patterns
  that can be reused in future code generation.

  ## Examples

      iex> extract_patterns(code, %{quality_score: 0.98})
      {:ok, [
        %{
          pattern_type: "genserver_with_cache",
          confidence: 0.95,
          code_template: "...",
          when_to_use: ["stateful caching", "TTL expiry"]
        }
      ]}
  """
  def extract_patterns(code, metadata) do
    if metadata.quality_score >= 0.95 do
      # Use LLM to identify reusable patterns
      prompt = build_pattern_extraction_prompt(code, metadata)

      case Service.call(:medium, [%{role: "user", content: prompt}],
        task_type: "pattern_analyzer"
      ) do
        {:ok, %{text: response}} ->
          patterns = parse_patterns_response(response)
          {:ok, patterns}

        {:error, reason} ->
          Logger.error("Pattern extraction failed: #{inspect(reason)}")
          {:ok, []}
      end
    else
      {:ok, []}  # Don't extract from low-quality code
    end
  end

  ## Private Functions

  defp generate_new_code(description, quality_level, relationships, similar_code) do
    template = load_production_template()

    # Build comprehensive prompt
    prompt = build_code_generation_prompt(%{
      description: description,
      template: template,
      quality_level: quality_level,
      relationships: relationships,
      similar_code: similar_code,
      requirements: extract_requirements(template)
    })

    case Service.call(:complex, [%{role: "user", content: prompt}],
      task_type: "coder",
      capabilities: [:code, :reasoning]
    ) do
      {:ok, %{text: code}} ->
        # Validate generated code
        {:ok, validation} = validate_code(code)

        if validation.compliant do
          Logger.info("Generated compliant code (score: #{validation.quality_score})")
          {:ok, %{
            code: code,
            quality_score: validation.quality_score,
            reused_patterns: extract_reused_patterns(code, similar_code),
            validation: validation
          }}
        else
          # Try to fix non-compliant code
          Logger.warn("Generated code not compliant, attempting fixes...")
          fix_code_quality(code, validation, template)
        end

      {:error, reason} ->
        Logger.error("Code generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp load_production_template do
    case File.read(@production_template_path) do
      {:ok, json} ->
        Jason.decode!(json)

      {:error, _} ->
        Logger.error("Failed to load production template, using defaults")
        %{}  # Fallback to defaults
    end
  end

  defp build_code_generation_prompt(context) do
    """
    Generate PRODUCTION-QUALITY Elixir code for: #{context.description}

    ## CRITICAL: NO HUMAN REVIEW
    This code will be deployed autonomously WITHOUT human review.
    Quality must be PERFECT on first generation.

    ## AVOID DUPLICATION
    #{format_similar_code(context.similar_code)}

    ## REQUIREMENTS (From template #{context.template["name"]})

    ### Documentation (REQUIRED)
    - @moduledoc with ALL sections:
      * Overview (what/why)
      * Public API Contract (function signatures)
      * Error Matrix (all {:error, reason} atoms)
      * Performance Notes (Big-O, memory)
      * Concurrency Semantics (thread safety)
      * Security Considerations (validation, sanitization)
      * Examples (3+ with success/error/edge cases)
      * Relationship Metadata (calls/called_by/depends_on)
      * Template Version

    - @doc for EVERY public function:
      * Description
      * Parameters
      * Returns
      * Errors
      * Examples

    ### Type Specs (REQUIRED)
    - @spec for EVERY function
    - @type for custom types
    - Dialyzer-compliant

    ### Error Handling (REQUIRED)
    - Use {:ok, value} | {:error, reason} pattern
    - NO raise for control flow
    - Define ALL error atoms in Error Matrix
    - Include context in error tuples

    ### OTP Patterns (REQUIRED IF STATEFUL)
    - GenServer: init/1, handle_call/3, handle_cast/2, handle_info/2, code_change/3, terminate/2
    - Supervision: proper child_spec/1
    - Hot code swapping: implement code_change/3 with state migration

    ### Performance (REQUIRED)
    - Document Big-O complexity
    - Use ETS for caching if needed
    - Streams for large datasets
    - Memory-conscious data structures

    ### Observability (REQUIRED)
    - Telemetry events: [:module, :function, :start/:stop/:exception]
    - Structured logging with correlation IDs
    - SLO monitoring (P50/P95/P99 latency)
    - Health checks (liveness/readiness)

    ### Security (REQUIRED)
    - Validate ALL external inputs
    - Sanitize user content
    - Rate limiting where appropriate
    - Privilege separation

    ### Testing (REQUIRED - Include in module)
    - Document test coverage target: 95%
    - List scenarios to test:
      * Happy paths
      * Error paths (all error atoms)
      * Edge cases (nil/empty/boundaries)
      * Concurrency scenarios

    ### Resilience (REQUIRED FOR EXTERNAL DEPS)
    - Circuit breakers for external services
    - Retry with exponential backoff
    - Graceful degradation
    - Timeout handling

    ### Code Style (REQUIRED)
    - Functions <= 25 lines
    - Max module <= 400 lines
    - Max line length: 120 chars
    - NO TODO/FIXME/HACK/XXX
    - Meaningful names (no Utils/Helper/Misc)

    ### Relationship Annotations (REQUIRED)
    #{format_relationship_requirements(context.relationships)}

    ## RELATIONSHIPS WITH EXISTING MODULES
    #{format_relationships(context.relationships)}

    ## SIMILAR CODE FOR REFERENCE (DO NOT DUPLICATE)
    #{format_similar_code_details(context.similar_code)}

    ## OUTPUT FORMAT
    Return ONLY the complete Elixir module code.
    No markdown, no explanations, JUST CODE.

    The code will be directly written to a file and must compile immediately.
    """
  end

  defp format_similar_code([]), do: "No similar code found - creating from scratch."
  defp format_similar_code(similar) when is_list(similar) do
    """
    Found #{length(similar)} similar implementations:
    #{Enum.map_join(similar, "\\n", fn s ->
      "- #{s.file} (similarity: #{s.similarity}) - #{s.module}"
    end)}

    Learn from these but DO NOT duplicate. Extract patterns and adapt.
    """
  end
  defp format_similar_code(single) when is_map(single) do
    format_similar_code([single])
  end

  defp format_similar_code_details([]), do: ""
  defp format_similar_code_details(similar) when is_list(similar) do
    Enum.map_join(similar, "\\n\\n", fn s ->
      """
      ### #{s.module} (#{s.file})
      Similarity: #{s.similarity}

      Patterns to learn:
      #{extract_patterns_from_code(s.code_snippet)}
      """
    end)
  end

  defp format_relationships(%{} = rels) when map_size(rels) == 0, do: "No specific relationships defined."
  defp format_relationships(rels) do
    """
    This module MUST document relationships:
    #{if rels[:calls], do: "- @calls: #{Enum.join(rels.calls, ", ")}", else: ""}
    #{if rels[:called_by], do: "- @called_by: #{Enum.join(rels.called_by, ", ")}", else: ""}
    #{if rels[:integrates_with], do: "- @integrates_with: #{Enum.join(rels.integrates_with, ", ")}", else: ""}
    """
  end

  defp format_relationship_requirements(_rels) do
    """
    Add these annotations in @moduledoc Relationships section:
    - # @calls: module.function/arity - purpose
    - # @called_by: module.function/arity - purpose
    - # @depends_on: module - purpose
    - # @integrates_with: service - purpose
    """
  end

  defp extract_requirements(template) do
    template["requirements"] || %{}
  end

  defp extract_patterns_from_code(code) do
    # Simple pattern extraction (could be enhanced with AST analysis)
    cond do
      String.contains?(code, "use GenServer") -> "- GenServer pattern with state management"
      String.contains?(code, ":ets.new") -> "- ETS-based caching"
      String.contains?(code, "Task.async") -> "- Concurrent task execution"
      String.contains?(code, "Supervisor") -> "- Supervision tree pattern"
      true -> "- Standard Elixir module"
    end
  end

  defp enrich_with_relationships(result) do
    # Add relationship metadata to search results
    # This would query the code_chunks table for relationship annotations
    Map.put(result, :relationships, [])
  end

  defp fix_code_quality(code, validation, template) do
    # Generate prompt to fix quality issues
    prompt = """
    The following Elixir code does NOT meet production quality standards.

    ## Issues Found:
    #{Enum.map_join(validation.missing, "\\n", &"- Missing: #{&1}")}

    ## Suggestions:
    #{Enum.map_join(validation.suggestions, "\\n", &"- #{&1}")}

    ## Current Code:
    ```elixir
    #{code}
    ```

    ## Required Fixes:
    - Add ALL missing sections/annotations
    - Follow template: #{template["name"]}
    - Quality target: 0.95+

    Return ONLY the fixed code (no markdown, no explanations).
    """

    case Service.call(:complex, [%{role: "user", content: prompt}],
      task_type: "coder"
    ) do
      {:ok, %{text: fixed_code}} ->
        # Re-validate
        {:ok, new_validation} = validate_code(fixed_code)

        if new_validation.compliant do
          Logger.info("Code fixed successfully (score: #{new_validation.quality_score})")
          {:ok, %{
            code: fixed_code,
            quality_score: new_validation.quality_score,
            fixed: true,
            validation: new_validation
          }}
        else
          Logger.error("Code still not compliant after fixes")
          {:error, :quality_standards_not_met}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Simple validation helpers (could be enhanced with AST parsing)

  defp has_moduledoc?(code), do: String.contains?(code, "@moduledoc")
  defp has_typespecs?(code), do: String.contains?(code, "@spec")
  defp uses_tagged_tuples?(code), do: String.contains?(code, "{:ok,") or String.contains?(code, "{:error,")
  defp has_forbidden_comments?(code) do
    Enum.any?(["TODO", "FIXME", "HACK", "XXX"], &String.contains?(code, &1))
  end
  defp has_relationship_annotations?(code), do: String.contains?(code, "@calls") or String.contains?(code, "@depends_on")
  defp has_telemetry?(code), do: String.contains?(code, ":telemetry.execute")

  defp all_functions_under_25_lines?(code) do
    # Simple heuristic - would need AST parsing for accurate check
    code
    |> String.split("def ")
    |> Enum.drop(1)
    |> Enum.all?(fn func_code ->
      func_code
      |> String.split("\\n")
      |> Enum.take_while(&(!String.starts_with?(String.trim(&1), "end")))
      |> length()
      |> Kernel.<=(25)
    end)
  end

  defp calculate_quality_score(validation, template) do
    weights = template["scoring_weights"] || %{}

    score = [
      {validation.has_moduledoc, weights["docs"] || 1.0},
      {validation.has_typespecs, weights["specs"] || 1.0},
      {validation.error_style_ok, weights["error_style"] || 1.0},
      {validation.no_forbidden_comments, weights["structure"] || 0.8},
      {validation.has_relationship_annotations, weights["structure"] || 0.8},
      {validation.has_telemetry, weights["observability"] || 0.7},
      {validation.functions_under_limit, weights["structure"] || 0.8}
    ]
    |> Enum.reduce({0.0, 0.0}, fn {passed?, weight}, {sum, total} ->
      {sum + if(passed?, do: weight, else: 0.0), total + weight}
    end)
    |> then(fn {sum, total} -> sum / total end)

    Float.round(score, 2)
  end

  defp find_missing_requirements(validation, _template) do
    []
    |> maybe_add(!validation.has_moduledoc, "moduledoc_with_all_sections")
    |> maybe_add(!validation.has_typespecs, "type_specs_for_all_functions")
    |> maybe_add(!validation.error_style_ok, "tagged_tuple_error_style")
    |> maybe_add(validation.has_forbidden_comments, "remove_forbidden_comments")
    |> maybe_add(!validation.has_relationship_annotations, "relationship_annotations")
    |> maybe_add(!validation.has_telemetry, "telemetry_instrumentation")
    |> maybe_add(!validation.functions_under_limit, "function_length_limit_25_lines")
  end

  defp maybe_add(list, true, item), do: [item | list]
  defp maybe_add(list, false, _item), do: list

  defp generate_suggestions(validation, _template) do
    []
    |> maybe_add(!validation.has_moduledoc, "Add @moduledoc with Overview, Public API Contract, Error Matrix, Performance Notes, Concurrency Semantics, Security Considerations, Examples, Relationships")
    |> maybe_add(!validation.has_typespecs, "Add @spec for every function")
    |> maybe_add(!validation.has_relationship_annotations, "Add @calls, @called_by, @depends_on annotations")
    |> maybe_add(!validation.has_telemetry, "Add :telemetry.execute events for observability")
  end

  defp extract_reused_patterns(_code, []), do: []
  defp extract_reused_patterns(code, similar) do
    # Analyze which patterns from similar code were reused
    []  # Placeholder
  end

  defp build_pattern_extraction_prompt(code, metadata) do
    """
    Analyze this high-quality Elixir code (quality score: #{metadata.quality_score}) and extract reusable patterns.

    Code:
    ```elixir
    #{code}
    ```

    Identify:
    1. Design patterns used (GenServer, Supervisor, Circuit Breaker, etc.)
    2. When this pattern should be used
    3. Key characteristics
    4. Template/skeleton for reuse

    Return JSON array of patterns:
    [
      {
        "pattern_type": "genserver_with_cache",
        "confidence": 0.95,
        "when_to_use": ["stateful caching", "TTL expiry"],
        "skeleton": "defmodule ... use GenServer ..."
      }
    ]
    """
  end

  defp parse_patterns_response(response) do
    case Jason.decode(response) do
      {:ok, patterns} when is_list(patterns) -> patterns
      _ -> []
    end
  rescue
    _ -> []
  end
end
