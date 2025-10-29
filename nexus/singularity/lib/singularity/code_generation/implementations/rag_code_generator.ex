defmodule Singularity.CodeGeneration.Implementations.RAGCodeGenerator do
  @moduledoc """
  RAG-powered Code Generation - Find and use the BEST code from all codebases

  Uses Retrieval-Augmented Generation (RAG) to:
  1. Search ALL codebases in PostgreSQL for similar code patterns
  2. Find the BEST examples using semantic similarity (pgvector)
  3. Use those examples as context for code generation
  4. Generate code that matches proven patterns from your repos

  ## How it works

  ```
  User asks: "Generate function to parse JSON API response"
      ↓
  1. Embed the request → [0.23, 0.45, ...] (768 dims)
      ↓
  2. Search PostgreSQL for similar code (vector similarity)
      → Found: 10 similar functions from 5 different repos
      ↓
  3. Rank by quality (tests passing, recently used, etc.)
      ↓
  4. Use TOP 3 as examples for code generation
      ↓
  5. StarCoder2 generates code following those patterns
      ↓
  Result: High-quality code matching YOUR best practices!
  ```

  ## Benefits

  - ✅ Learns from ALL your codebases (not just one repo)
  - ✅ Finds PROVEN patterns (tested, working code)
  - ✅ Automatically adapts to your best practices
  - ✅ Cross-language learning (Elixir patterns → Rust, etc.)
  - ✅ Zero-shot quality (no training needed!)

  ## Usage

      # Generate with RAG (finds best examples automatically)
      {:ok, code} = RAGCodeGenerator.generate(
        task: "Parse JSON response with error handling",
        language: "elixir",
        top_k: 5  # Use top 5 similar code examples
      )

      # Generate with specific repo context
      {:ok, code} = RAGCodeGenerator.generate(
        task: "Create GenServer for cache",
        repos: ["singularity", "sparc_fact_system"],
        prefer_recent: true  # Prefer recently modified code
      )
  """

  require Logger
  alias Singularity.{EmbeddingEngine, CodeModel, HotReload.SafeCodeChangeDispatcher}
  alias Jason
  alias Singularity.Code.Quality.TemplateValidator

  @type generationopts :: [
          task: String.t(),
          language: String.t() | nil,
          repos: [String.t()] | nil,
          top_k: integer(),
          prefer_recent: boolean(),
          temperature: float(),
          quality_level: String.t(),
          validate: boolean(),
          max_retries: integer(),
          dispatch: boolean(),
          dispatch_agent_id: String.t(),
          dispatch_metadata: map()
        ]

  @doc """
  Generate code using RAG - finds best examples from all codebases

  ## Options

  - `:task` - What to generate (required) - e.g. "Parse JSON API response"
  - `:language` - Target language (e.g. "elixir", "rust") - auto-detected if nil
  - `:repos` - Limit to specific repos (nil = search all)
  - `:top_k` - Number of example code snippets to use (default: 5)
  - `:prefer_recent` - Prefer recently modified code (default: false)
  - `:temperature` - Generation temperature (default: 0.05 for strict)
  - `:include_tests` - Include test examples (default: true)
  - `:quality_level` - Quality level (default: "production") - uses quality templates
  - `:validate` - Validate generated code against template (default: true)
  - `:max_retries` - Max validation retries (default: 2)
  - `:dispatch` - Dispatch generated code via improvement gateway (default: true)
  - `:dispatch_agent_id` - Agent id used for dispatch (default: "rag-runtime")
  - `:dispatch_metadata` - Additional metadata merged into dispatch payload
  """
  @spec generate(generationopts()) :: {:ok, String.t()} | {:error, term()}
  def generate(opts) do
    task = Keyword.fetch!(opts, :task)
    language = Keyword.get(opts, :language)
    repos = Keyword.get(opts, :repos)
    top_k = Keyword.get(opts, :top_k, 5)
    prefer_recent = Keyword.get(opts, :prefer_recent, false)
    temperature = Keyword.get(opts, :temperature, 0.05)
    include_tests = Keyword.get(opts, :include_tests, true)
    quality_level = Keyword.get(opts, :quality_level, "production")
    validate = Keyword.get(opts, :validate, true)
    max_retries = Keyword.get(opts, :max_retries, 2)
    dispatch? = Keyword.get(opts, :dispatch, true)

    Logger.info("RAG Code Generation: #{task} (quality: #{quality_level}, validate: #{validate})")

    with {:ok, quality_template} <- load_quality_template(language, quality_level),
         {:ok, examples} <-
           find_best_examples(
             task,
             language,
             repos,
             top_k,
             prefer_recent,
             include_tests,
             quality_template
           ),
         {:ok, prompt} <- build_rag_prompt(task, examples, language, quality_template),
         {:ok, code} <-
           generate_with_validation(
             prompt,
             temperature,
             quality_template,
             language,
             validate,
             max_retries
           ),
         {:ok, code} <-
           maybe_dispatch_improvement(
             code,
             opts,
             build_dispatch_metadata(
               task,
               language,
               quality_level,
               repos,
               examples,
               quality_template,
               validate,
               max_retries,
               temperature
             ),
             dispatch?
           ) do
      Logger.info(
        "✅ Generated #{String.length(code)} chars using #{length(examples)} examples (template: #{(quality_template && quality_template.artifact_id) || "none"})"
      )

      {:ok, code}
    else
      {:error, reason} ->
        Logger.error("RAG generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Find the BEST code examples from all codebases using semantic search

  Returns ranked examples with metadata (quality scores, repo, path, etc.)

  If quality_template is provided, filters examples to match template requirements.
  """
  @spec find_best_examples(
          String.t(),
          String.t() | nil,
          [String.t()] | nil,
          integer(),
          boolean(),
          boolean(),
          map() | nil
        ) ::
          {:ok, [map()]} | {:error, term()}
  def find_best_examples(
        task,
        language,
        repos,
        top_k,
        prefer_recent,
        include_tests,
        quality_template \\ nil
      )

  def find_best_examples(
        task,
        language,
        repos,
        top_k,
        prefer_recent,
        include_tests,
        quality_template
      ) do
    # 1. Create search query (semantic)
    search_query = build_search_query(task, language)

    Logger.debug("Searching for similar code: #{search_query}")

    # 2. Semantic search in PostgreSQL (pgvector)
    multiplier = if quality_template, do: 3, else: 2

    with {:ok, embedding} <- EmbeddingEngine.embed(search_query),
         {:ok, results} <- semantic_search(embedding, language, repos, top_k * multiplier) do
      # 3. Rank and filter results
      ranked =
        results
        |> filter_quality(include_tests)
        |> filter_by_template(quality_template)
        |> rank_by_quality(prefer_recent, quality_template)
        |> Enum.take(top_k)

      template_name = if quality_template, do: quality_template.artifact_id, else: "none"
      Logger.debug("Found #{length(ranked)} high-quality examples (template: #{template_name})")
      {:ok, ranked}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  ## Private Functions

  defp build_search_query(task, language) do
    # Enhance task with language-specific keywords for better retrieval
    lang_prefix =
      case language do
        "elixir" -> "Elixir function module defmodule"
        "rust" -> "Rust function impl struct"
        "typescript" -> "TypeScript function class interface"
        _ -> ""
      end

    "#{lang_prefix} #{task}"
  end

  defp semantic_search(embedding, language, repos, limit) do
    # Use optimized function with parallel partition scanning
    query = """
    SELECT * FROM search_similar_code(
      $1::vector,
      $2,
      $3,
      $4
    )
    """

    params =
      [
        embedding,
        if(language, do: language, else: nil),
        if(repos, do: repos, else: nil),
        limit
      ]
      |> Enum.reject(&is_nil/1)

    case Singularity.Repo.query(query, params) do
      {:ok, %{rows: rows}} ->
        examples =
          Enum.map(rows, fn row ->
            [id, path, content, lang, metadata, repo, updated_at, similarity] = row

            %{
              id: id,
              path: path,
              content: content,
              language: lang,
              metadata: metadata || %{},
              repo: repo,
              updated_at: updated_at,
              similarity: similarity
            }
          end)

        {:ok, examples}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp filter_quality(examples, include_tests) do
    examples
    |> Enum.filter(fn ex ->
      # Filter out low-quality code
      content = ex.content
      metadata = ex.metadata

      # Basic quality checks
      has_min_length = String.length(content) >= 50
      not_generated = not String.contains?(content, ["TODO", "FIXME", "XXX"])
      not_commented_out = not String.starts_with?(String.trim(content), "#")

      # Metadata-based quality checks
      has_good_metadata =
        case metadata do
          %{"language" => lang, "complexity" => complexity} when is_number(complexity) ->
            # Prefer code with reasonable complexity and matching language
            complexity > 0.1 and complexity < 0.9 and is_binary(lang) and String.length(lang) > 0

          %{"language" => lang} when is_binary(lang) ->
            # Has language info - verify it's valid
            String.length(lang) > 0

          _ ->
            # No metadata or incomplete
            false
        end

      # Test file handling
      is_test = String.contains?(ex.path, ["test", "spec", "_test."])
      include_this = if include_tests, do: true, else: not is_test

      # Similarity threshold
      has_good_similarity = ex.similarity >= 0.7

      has_min_length and not_generated and not_commented_out and has_good_metadata and
        include_this and has_good_similarity
    end)
  end

  defp filter_by_template(examples, nil), do: examples

  defp filter_by_template(examples, quality_template) do
    requirements = get_in(quality_template.content, ["requirements"]) || %{}

    examples
    |> Enum.filter(fn ex ->
      metadata = ex.metadata || %{}

      # Check if example meets template requirements
      meets_doc_requirements = check_doc_requirements(ex.content, requirements)
      meets_spec_requirements = check_spec_requirements(ex.content, requirements)
      meets_error_requirements = check_error_requirements(ex.content, requirements)
      meets_test_requirements = check_test_requirements(metadata, requirements)

      meets_doc_requirements and meets_spec_requirements and
        meets_error_requirements and meets_test_requirements
    end)
  end

  defp rank_by_quality(examples, prefer_recent, quality_template) do
    examples
    |> Enum.sort_by(fn ex ->
      # Multi-factor ranking score
      # 0-1000
      similarity_score = ex.similarity * 1000

      # Recency bonus (if preferred)
      recency_score =
        if prefer_recent do
          days_old = DateTime.diff(DateTime.utc_now(), ex.updated_at, :day)
          # 100 points for today, 0 for 100+ days
          max(0, 100 - days_old)
        else
          0
        end

      # Code size bonus (prefer substantial code, not snippets)
      size_score = min(100, div(String.length(ex.content), 10))

      # Template compliance bonus (if template provided)
      template_score =
        if quality_template do
          calculate_template_compliance(ex, quality_template) * 500
        else
          0
        end

      # Total score
      # Negative for DESC sort
      -(similarity_score + recency_score + size_score + template_score)
    end)
  end

  defp build_rag_prompt(task, examples, language, quality_template \\ nil)

  defp build_rag_prompt(task, examples, language, quality_template) do
    # Build prompt with examples from best codebases
    language_hint = if language, do: language, else: "auto-detect"

    # Build quality requirements section if template provided
    quality_section =
      if quality_template do
        build_quality_requirements_section(quality_template)
      else
        ""
      end

    examples_text =
      examples
      |> Enum.with_index(1)
      |> Enum.map(fn {ex, idx} ->
        compliance =
          if quality_template do
            " (compliance: #{round(calculate_template_compliance(ex, quality_template) * 100)}%)"
          else
            ""
          end

        """
        Example #{idx} (from #{ex.repo}/#{Path.basename(ex.path)}, similarity: #{Float.round(ex.similarity, 2)}#{compliance}):
        ```#{ex.language}
        #{String.slice(ex.content, 0..500)}
        ```
        """
      end)
      |> Enum.join("\n")

    prompt = """
    Task: #{task}
    Language: #{language_hint}
    #{quality_section}
    Here are #{length(examples)} similar, high-quality code examples from your codebases:

    #{examples_text}

    Based on these proven patterns#{if quality_template, do: " and PRODUCTION QUALITY REQUIREMENTS", else: ""}, generate code for the task.
    OUTPUT CODE ONLY - no explanations, no comments about the examples.

    """

    {:ok, prompt}
  end

  @doc """
  Analyze code quality across all repos - find best practices

  Returns insights like:
  - Most common patterns
  - Best-performing code (by similarity to many files)
  - Repos with highest quality code
  """
  @spec analyze_best_practices(keyword()) :: {:ok, map()} | {:error, term()}
  def analyze_best_practices(opts \\ []) do
    language = Keyword.get(opts, :language)

    query = """
    WITH code_similarities AS (
      SELECT
        cf.repo_name,
        cf.language,
        COUNT(*) as file_count,
        AVG(LENGTH(cf.content)) as avg_file_size,
        COUNT(DISTINCT cf.file_path) as unique_files
      FROM codebase_chunks cf
      #{if language, do: "WHERE cf.language = $1", else: ""}
      GROUP BY cf.repo_name, cf.language
      ORDER BY file_count DESC
    )
    SELECT * FROM code_similarities
    LIMIT 20
    """

    params = if language, do: [language], else: []

    case Singularity.Repo.query(query, params) do
      {:ok, %{rows: rows}} ->
        stats =
          Enum.map(rows, fn [repo, lang, count, avg_size, unique] ->
            %{
              repo: repo,
              language: lang,
              file_count: count,
              avg_file_size: round(avg_size),
              unique_files: unique
            }
          end)

        {:ok,
         %{
           top_repos: stats,
           total_repos: length(stats),
           languages: Enum.map(stats, & &1.language) |> Enum.uniq()
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  ## Code Generation with Validation

  defp generate_with_validation(
         prompt,
         temperature,
         quality_template,
         language,
         validate,
         max_retries
       ) do
    generate_with_validation_loop(
      prompt,
      temperature,
      quality_template,
      language,
      validate,
      max_retries,
      0
    )
  end

  defp generate_with_validation_loop(
         prompt,
         temperature,
         quality_template,
         language,
         validate,
         max_retries,
         attempt
       ) do
    # Generate code
    case CodeModel.complete(prompt, temperature: temperature) do
      {:ok, code} ->
        # Validate if requested and template available
        if validate && quality_template && language do
          case TemplateValidator.validate(code, quality_template, language) do
            {:ok, %{compliant: true, score: score}} ->
              Logger.info(
                "✅ Validation passed (score: #{Float.round(score, 2)}, attempt: #{attempt + 1})"
              )

              {:ok, code}

            {:ok, %{compliant: false, violations: violations, score: score}} ->
              Logger.warning(
                "❌ Validation failed (score: #{Float.round(score, 2)}, attempt: #{attempt + 1})"
              )

              Logger.warning("Violations: #{inspect(violations)}")

              if attempt < max_retries do
                Logger.info(
                  "🔄 Retrying with stricter prompt (attempt #{attempt + 2}/#{max_retries + 1})"
                )

                # Build stricter prompt with violations feedback
                stricter_prompt = add_violation_feedback(prompt, violations)

                generate_with_validation_loop(
                  stricter_prompt,
                  # Lower temperature for more deterministic output
                  temperature * 0.8,
                  quality_template,
                  language,
                  validate,
                  max_retries,
                  attempt + 1
                )
              else
                Logger.error("❌ Max retries reached, returning code anyway")
                # Return code even if it doesn't validate (with warning in log)
                {:ok, code}
              end

            {:error, reason} ->
              Logger.warning("Validation error (non-fatal): #{inspect(reason)}")
              # Return code anyway
              {:ok, code}
          end
        else
          # No validation requested or no template
          {:ok, code}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp add_violation_feedback(original_prompt, violations) do
    violations_text =
      violations
      |> Enum.map(fn v -> "- #{v}" end)
      |> Enum.join("\n")

    """
    #{original_prompt}

    ⚠️ PREVIOUS ATTEMPT FAILED VALIDATION:
    #{violations_text}

    Please regenerate the code ensuring ALL requirements are met.
    Pay special attention to the violations listed above.
    """
  end

  ## Quality Template Helper Functions

  defp load_quality_template(nil, _quality_level), do: {:ok, nil}

  defp load_quality_template(language, quality_level) do
    artifact_id = "#{language}_#{quality_level}"

    case fetch_remote_quality_template(language, artifact_id) do
      {:ok, template} ->
        Logger.debug("Loaded quality template",
          artifact_id: template_value(template, :artifact_id),
          source: template_value(template, :source)
        )

        {:ok, template}

      {:error, remote_reason} ->
        case load_local_quality_template(language, quality_level) do
          {:ok, template} ->
            Logger.debug("Loaded local quality template",
              artifact_id: template_value(template, :artifact_id)
            )

            {:ok, template}

          {:error, local_reason} ->
            Logger.warning("No quality template available, proceeding without template",
              language: language,
              quality_level: quality_level,
              remote_reason: inspect(remote_reason),
              local_reason: inspect(local_reason)
            )

            {:ok, nil}
        end
    end
  end

  defp build_quality_requirements_section(quality_template) do
    requirements = get_in(quality_template.content, ["requirements"]) || %{}
    template_name = quality_template.content["name"] || "Quality Template"
    quality_level = quality_template.content["quality_level"] || "production"

    req_list =
      [
        build_error_handling_req(requirements),
        build_documentation_req(requirements),
        build_testing_req(requirements),
        build_observability_req(requirements)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    """
    Quality Standard: #{String.upcase(quality_level)} (#{template_name} v#{quality_template.version})

    REQUIREMENTS:
    #{req_list}
    """
  end

  defp build_error_handling_req(requirements) do
    case get_in(requirements, ["error_handling"]) do
      %{"required_pattern" => pattern} ->
        "- Error handling: #{pattern}"

      _ ->
        nil
    end
  end

  defp build_documentation_req(requirements) do
    case get_in(requirements, ["documentation"]) do
      %{} = doc_req ->
        moduledoc = get_in(doc_req, ["moduledoc", "must_include"]) || []
        doc = get_in(doc_req, ["doc", "must_include"]) || []
        parts = (moduledoc ++ doc) |> Enum.uniq() |> Enum.join(", ")
        if parts != "", do: "- Documentation: Must include #{parts}", else: nil

      _ ->
        nil
    end
  end

  defp build_testing_req(requirements) do
    case get_in(requirements, ["testing"]) do
      %{"coverage_target" => target, "test_types" => types} when is_list(types) ->
        "- Testing: #{target}% coverage (#{Enum.join(types, ", ")})"

      %{"coverage_target" => target} ->
        "- Testing: #{target}% coverage"

      _ ->
        nil
    end
  end

  defp build_observability_req(requirements) do
    telemetry = get_in(requirements, ["observability", "telemetry", "required"])
    logging = get_in(requirements, ["observability", "logging", "use_logger"])

    cond do
      telemetry && logging -> "- Observability: Telemetry events + structured logging"
      telemetry -> "- Observability: Telemetry events required"
      logging -> "- Observability: Structured logging required"
      true -> nil
    end
  end

  defp fetch_remote_quality_template(language, artifact_id) do
    case Singularity.Knowledge.TemplateService.get_template("quality_template", artifact_id) do
      {:ok, template} ->
        {:ok, normalize_template(template, artifact_id, :remote)}

      {:error, reason_primary} ->
        case Singularity.Knowledge.TemplateService.get_template("quality_template", language) do
          {:ok, template} ->
            {:ok, normalize_template(template, language, :remote)}

          {:error, reason_fallback} ->
            {:error, {:remote_not_found, reason_primary, reason_fallback}}
        end
    end
  end

  defp load_local_quality_template(nil, _quality_level), do: {:error, :language_required}

  defp load_local_quality_template(language, quality_level) do
    with {:ok, base_dir} <- local_quality_template_dir() do
      candidates = local_quality_candidates(language, quality_level)

      Enum.reduce_while(candidates, {:error, :not_found}, fn file, acc ->
        path = Path.join(base_dir, file)

        if File.exists?(path) do
          case parse_local_template(path, language) do
            {:ok, template} -> {:halt, {:ok, template}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        else
          {:cont, acc}
        end
      end)
    end
  end

  defp local_quality_template_dir do
    case :code.priv_dir(:singularity) do
      {:error, reason} -> {:error, reason}
      dir -> {:ok, Path.join(to_string(dir), "code_quality_templates")}
    end
  end

  defp local_quality_candidates(language, quality_level) do
    base = String.downcase(language)

    [
      "#{base}_#{String.downcase(quality_level)}.json",
      "#{base}_standard.json",
      "#{base}_production.json",
      "#{base}.json"
    ]
  end

  defp parse_local_template(path, language) do
    with {:ok, body} <- File.read(path),
         {:ok, content} <- Jason.decode(body) do
      artifact_id = Map.get(content, "artifact_id") || Path.rootname(Path.basename(path))

      template = %{
        "artifact_id" => artifact_id,
        "version" => Map.get(content, "spec_version") || Map.get(content, "version") || "1.0",
        "content" => content,
        "language" => Map.get(content, "language") || language,
        "quality_level" => Map.get(content, "quality_level"),
        "source" => :local
      }

      {:ok, normalize_template(template, artifact_id, :local)}
    end
  end

  defp normalize_template(template, default_artifact_id, source) do
    map = Map.new(template)
    content = Map.get(map, :content) || Map.get(map, "content") || map
    artifact_id = Map.get(map, :artifact_id) || Map.get(map, "artifact_id") || default_artifact_id

    version =
      Map.get(map, :version) || Map.get(map, "version") || Map.get(content, "spec_version") ||
        "1.0"

    map
    |> Map.put(:artifact_id, artifact_id)
    |> Map.put(:version, version)
    |> Map.put(:source, source)
    |> Map.put(:content, content)
  end

  defp template_value(nil, _key), do: nil

  defp template_value(template, key) do
    Map.get(template, key) || Map.get(template, Atom.to_string(key))
  end

  defp build_dispatch_metadata(
         task,
         language,
         quality_level,
         repos,
         examples,
         quality_template,
         validate,
         max_retries,
         temperature
       ) do
    %{
      reason: "rag_generation",
      task: task,
      language: language,
      quality_level: quality_level,
      repositories: repos,
      example_count: length(examples),
      example_paths:
        examples |> Enum.map(&example_path/1) |> Enum.reject(&is_nil/1) |> Enum.take(5),
      template_id: template_value(quality_template, :artifact_id),
      template_source: template_value(quality_template, :source),
      validation_enabled: validate,
      max_retries: max_retries,
      temperature: temperature
    }
  end

  defp example_path(example) do
    Map.get(example, :path) || Map.get(example, "path")
  end

  defp maybe_dispatch_improvement(code, opts, _metadata, false) do
    # When dispatch is disabled, still log opts for debugging
    if Keyword.get(opts, :log_disabled_dispatch, false) do
      Logger.debug("Improvement dispatch disabled", opts: Keyword.drop(opts, [:dispatch_agent_id, :dispatch_metadata]))
    end
    {:ok, code}
  end

  defp maybe_dispatch_improvement(code, opts, metadata, true) do
    agent_id = Keyword.get(opts, :dispatch_agent_id, "rag-runtime")
    extra_metadata = Keyword.get(opts, :dispatch_metadata, %{})

    final_metadata =
      metadata
      |> compact_metadata()
      |> Map.merge(compact_metadata(extra_metadata))
      |> Map.put_new("source", "rag_code_generator")

    case SafeCodeChangeDispatcher.dispatch(%{"code" => code},
           agent_id: agent_id,
           metadata: final_metadata
         ) do
      :ok ->
        Logger.debug("Dispatched RAG improvement via gateway",
          agent_id: agent_id,
          task: Map.get(final_metadata, "task"),
          language: Map.get(final_metadata, "language")
        )

        {:ok, code}

      {:error, reason} ->
        Logger.warning("Failed to dispatch RAG improvement",
          agent_id: agent_id,
          reason: inspect(reason)
        )

        {:ok, code}
    end
  end

  defp compact_metadata(map) when is_map(map) do
    map
    |> Enum.reduce(%{}, fn
      {_key, nil}, acc -> acc
      {_key, ""}, acc -> acc
      {_key, []}, acc -> acc
      {key, value}, acc -> Map.put(acc, normalize_key(key), value)
    end)
  end

  defp compact_metadata(nil), do: %{}
  defp compact_metadata(other), do: %{"extra" => other}

  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key) when is_binary(key), do: key
  defp normalize_key(key), do: inspect(key)

  defp check_doc_requirements(content, requirements) do
    doc_req = get_in(requirements, ["documentation"])

    if doc_req do
      # Check for @doc and @moduledoc (Elixir)
      # Or equivalent in other languages
      String.contains?(content, ["@doc", "@moduledoc", "///", "/**", "#"])
    else
      true
    end
  end

  defp check_spec_requirements(content, requirements) do
    type_req = get_in(requirements, ["type_specs"])

    if type_req && type_req["required"] do
      # Check for type specs (@spec in Elixir, type hints in Python, etc.)
      String.contains?(content, ["@spec", ": ", "->", "type"])
    else
      true
    end
  end

  defp check_error_requirements(content, requirements) do
    error_req = get_in(requirements, ["error_handling"])

    if error_req && error_req["required_pattern"] do
      pattern = error_req["required_pattern"]
      # Check if content uses the required error pattern
      String.contains?(content, [pattern, "{:ok,", "{:error,", "Result<", "Option<"])
    else
      true
    end
  end

  defp check_test_requirements(metadata, requirements) do
    test_req = get_in(requirements, ["testing"])

    if test_req && test_req["required"] do
      # Check if code has associated tests in metadata
      metadata["has_tests"] == true || metadata["test_coverage"] != nil
    else
      true
    end
  end

  defp calculate_template_compliance(example, quality_template) do
    requirements = get_in(quality_template.content, ["requirements"]) || %{}
    metadata = example.metadata || %{}
    content = example.content

    checks = [
      {check_doc_requirements(content, requirements), 0.25},
      {check_spec_requirements(content, requirements), 0.25},
      {check_error_requirements(content, requirements), 0.25},
      {check_test_requirements(metadata, requirements), 0.25}
    ]

    total_score =
      checks
      |> Enum.reduce(0.0, fn {passes, weight}, acc ->
        if passes, do: acc + weight, else: acc
      end)

    total_score
  end

  @doc """
  Find a similar module in the codebase to use as a template.

  Searches for modules with similar names or purposes to use as templates
  for generating new modules.

  ## Examples

      iex> RAGCodeGenerator.find_similar_module("Singularity.Code.NewParser")
      {:ok, "Singularity.Code.ExistingParser"}
      
      iex> RAGCodeGenerator.find_similar_module("NonExistent.Module")
      {:error, :no_similar_module_found}
  """
  @spec find_similar_module(String.t()) :: {:ok, String.t()} | {:error, :no_similar_module_found}
  def find_similar_module(module_name) do
    # Extract keywords from module name for similarity search
    parts = String.split(module_name, ".")
    last_part = List.last(parts) || ""

    # Get all loaded modules
    loaded_modules =
      :code.all_loaded()
      |> Enum.map(fn {mod, _} -> Atom.to_string(mod) end)
      |> Enum.filter(&String.starts_with?(&1, "Elixir.Singularity"))

    # Find modules with similar names
    similar =
      loaded_modules
      |> Enum.map(fn mod ->
        similarity = calculate_module_similarity(mod, module_name, last_part)
        {mod, similarity}
      end)
      |> Enum.filter(fn {_, sim} -> sim > 0.3 end)
      |> Enum.sort_by(fn {_, sim} -> -sim end)

    case similar do
      [{best_match, _score} | _] ->
        Logger.info("Found similar module: #{best_match} (similarity score available)")
        {:ok, best_match}

      [] ->
        # Fallback: find module in same namespace
        namespace = Enum.slice(parts, 0..-2//1) |> Enum.join(".")

        fallback =
          loaded_modules
          |> Enum.find(fn mod -> String.starts_with?(mod, namespace) end)

        case fallback do
          nil ->
            {:error, :no_similar_module_found}

          mod ->
            Logger.info("Using fallback module from same namespace: #{mod}")
            {:ok, mod}
        end
    end
  end

  defp calculate_module_similarity(candidate, target, target_last_part) do
    candidate_parts = String.split(candidate, ".")
    target_parts = String.split(target, ".")
    candidate_last = List.last(candidate_parts) || ""

    # Calculate similarity based on:
    # 1. Common namespace parts
    # 2. Similar final module name
    # 3. Levenshtein distance

    common_namespace =
      Enum.zip(candidate_parts, target_parts)
      |> Enum.take_while(fn {a, b} -> a == b end)
      |> length()

    namespace_score = common_namespace / max(length(candidate_parts), length(target_parts))

    # Simple string similarity for last part
    name_score =
      if String.contains?(candidate_last, target_last_part) or
           String.contains?(target_last_part, candidate_last) do
        0.8
      else
        0.0
      end

    # Weighted average
    0.6 * namespace_score + 0.4 * name_score
  end
end
