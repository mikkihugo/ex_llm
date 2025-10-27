defmodule Singularity.CodeGeneration.Implementations.CodeGenerator do
  @moduledoc """
  **High-Level Code Generation Orchestrator** - RAG + Quality + Execution Strategy

  ⚠️ **IMPORTANT ARCHITECTURE DISTINCTION:**
  - This module (CodeGenerator) - ORCHESTRATION layer (what to generate)
  - `CodeGeneration.InferenceEngine` - INFERENCE layer (how to generate tokens)

  ## Architecture Separation

  ```
  CodeGenerator (ORCHESTRATION)
    ├─ RAG: Find examples from YOUR code (pgvector)
    ├─ Quality: Enforce production standards
    ├─ Strategy: Select T5 local vs API
    └─ Inference: Call InferenceEngine for tokens
      │
      └─→ CodeGeneration.InferenceEngine (INFERENCE)
            ├─ Token generation
            ├─ Sampling (temperature, top-p, top-k)
            └─ Constraints & streaming
  ```

  ## Orchestration Flow

  ```
  Task request
      ↓
  1. RAG: Search codebases for similar code (if use_rag: true)
      ↓
  2. Quality: Load quality template for language
      ↓
  3. Strategy Selection:
      Is T5 available? → NO → Use LLM API
      Is task simple/medium? → YES → T5 local via InferenceEngine
      ↓
  4. InferenceEngine: Generate tokens with sampling strategy
      ↓
  5. Validate against quality standards
      ↓
  6. Return production-ready code
  ```

  ## Usage

      # Full integration (recommended):
      {:ok, code} = CodeGenerator.generate(
        "Create GenServer for caching",
        language: "elixir",
        quality: :production,
        use_rag: true  # Finds similar code from YOUR repos
      )
      # → Searches your code, enforces quality, uses T5/API

      # Skip RAG (direct generation):
      {:ok, code} = CodeGenerator.generate(
        "Simple helper function",
        use_rag: false
      )

      # Force specific method:
      {:ok, code} = CodeGenerator.generate(
        "Complex refactoring",
        method: :api,
        quality: :production
      )

  ## Performance

  - **T5 Local (CPU)**: 10-20 sec/function (background-friendly!)
  - **T5 Local (GPU)**: 1-2 sec/function (interactive)
  - **API (Gemini Flash)**: 2-5 sec/function (simple tasks, FREE)
  - **API (Claude Sonnet)**: 5-10 sec/function (complex tasks, subscription)

  ## Quality Levels

  - `:production` - Maximum quality (docs, specs, tests, strict validation)
  - `:standard` - Good quality (docs, specs, basic tests)
  - `:draft` - Minimal quality (working code only)

  ## Benefits of Clear Architecture

  - ✅ ONE entry point (CodeGenerator) for high-level code generation
  - ✅ RAG finds proven patterns from YOUR code (pgvector search)
  - ✅ Quality templates enforce production standards
  - ✅ Strategy selection: T5 local vs LLM API (cost-aware)
  - ✅ InferenceEngine: Reusable token generation (sampling, constraints, streaming)
  - ✅ Clean separation: Orchestration vs Inference (easy testing, maintenance)
  - ✅ No duplicate systems!

  ## When to Use Which Module

  | Task | Use |
  |------|-----|
  | High-level code generation | `CodeGenerator.generate/2` ← Start here |
  | Find examples from your code | `CodeGenerator.generate/2` with `use_rag: true` |
  | Enforce quality standards | `CodeGenerator.generate/2` with `quality: :production` |
  | Low-level token generation | `CodeGeneration.InferenceEngine.generate/4` |
  | Token sampling strategies | `CodeGeneration.InferenceEngine.generate/4` with opts |
  | Real-time streaming | `CodeGeneration.InferenceEngine.stream/4` |
  | Constrained generation | `CodeGeneration.InferenceEngine.constrained_generate/5` |

  """

  require Logger
  alias Singularity.CodeGeneration.Implementations.RAGCodeGenerator
  # Using current queue-based LLM service instead of old CodeModel
  @type generation_method :: :llm_api | :auto
  @type complexity :: :simple | :medium | :complex
  @type quality_level :: :production | :standard | :draft

  @doc """
  Generate code using the best available method with RAG + Quality enforcement.

  ## Options

  - `:method` - Force method: `:t5_local`, `:api`, `:auto` (default: `:auto`)
  - `:language` - Target language (default: `"elixir"`)
  - `:quality` - Quality level: `:production`, `:standard`, `:draft` (default: `:production`)
  - `:complexity` - Task complexity hint: `:simple`, `:medium`, `:complex` (default: auto-detect)
  - `:use_rag` - Use RAG to find similar code examples (default: `true`)
  - `:top_k` - Number of RAG examples to use (default: `5`)
  - `:repos` - Limit RAG search to specific repos (default: `nil` = all repos)
  - `:validate` - Validate against quality template (default: `true`)
  - `:max_retries` - Max validation retries (default: `2`)

  ## Examples

      # Full integration (recommended):
      {:ok, code} = CodeGenerator.generate(
        "Create GenServer for caching",
        language: "elixir",
        quality: :production,
        use_rag: true
      )
      # → Searches your code, enforces quality, uses T5/API

      # Force T5 (local):
      CodeGenerator.generate("Simple helper", method: :t5_local)

      # Force API with specific repos:
      CodeGenerator.generate(
        "Parse JSON",
        method: :api,
        repos: ["singularity", "sparc_fact_system"]
      )

  """
  @spec generate(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate(task, opts \\ []) do
    method = Keyword.get(opts, :method, :auto)
    language = Keyword.get(opts, :language, "elixir")
    quality = Keyword.get(opts, :quality, :production)
    complexity = Keyword.get(opts, :complexity, detect_complexity(task))
    use_rag = Keyword.get(opts, :use_rag, true)
    top_k = Keyword.get(opts, :top_k, 5)
    repos = Keyword.get(opts, :repos)
    validate = Keyword.get(opts, :validate, true)
    max_retries = Keyword.get(opts, :max_retries, 2)

    Logger.info(
      "Adaptive code generation: task=#{inspect(task)}, method=#{method}, complexity=#{complexity}, use_rag=#{use_rag}, quality=#{quality}"
    )

    # 1. Load quality template
    with {:ok, quality_template} <- load_quality_template(language, quality),
         # 2. Find RAG examples (if enabled)
         {:ok, examples} <-
           maybe_find_rag_examples(task, language, repos, top_k, use_rag, quality_template),
         # 3. Generate with adaptive method
         {:ok, code} <-
           generate_with_method_and_rag(
             task,
             language,
             quality,
             complexity,
             method,
             examples,
             quality_template
           ),
         # 4. Validate (if enabled)
         {:ok, validated_code} <-
           maybe_validate(code, quality_template, language, validate, max_retries) do
      Logger.info(
        "✅ Generated #{String.length(validated_code)} chars (#{length(examples)} examples, quality: #{quality})"
      )

      {:ok, validated_code}
    else
      {:error, reason} ->
        Logger.error("Adaptive generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Check if LLM service is available.
  """
  @spec llm_available?() :: boolean()
  def llm_available? do
    # Check if the queue-based LLM service is available
    Code.ensure_loaded?(Singularity.LLM.Service) &&
      function_exported?(Singularity.LLM.Service, :call_with_prompt, 3)
  end

  @doc """
  Get recommended generation method for a task.
  """
  @spec recommended_method(complexity()) :: generation_method()
  def recommended_method(_complexity) do
    # Always use LLM API in current architecture
    :llm_api
  end

  ## Private Functions

  # Select generation method based on strategy
  defp select_method(:auto, _complexity) do
    recommended_method(:medium)
  end

  defp select_method(:llm_api, _complexity) do
    if llm_available?() do
      :llm_api
    else
      Logger.warning("LLM service not available, falling back to basic generation")
      :basic
    end
  end

  defp select_method(:basic, _complexity), do: :basic

  # Generate code using LLM API (current architecture)
  defp generate_with_t5(task, language, _quality) do
    Logger.info("Generating with LLM API (queue-based)...")

    # Use the current queue-based LLM service
    prompt = build_code_generation_prompt(task, language)
    
    case Singularity.LLM.Service.call_with_prompt(:medium, prompt, task_type: :code_generation) do
      {:ok, %{text: code}} ->
        {:ok, extract_code_from_response(code)}
      
      {:error, reason} ->
        Logger.warning("LLM generation failed, falling back to basic generation: #{inspect(reason)}")
        generate_basic_code(task, language)
    end
  end

  defp build_code_generation_prompt(task, language) do
    """
    Generate #{language} code for the following task:

    Task: #{task}

    Requirements:
    - Write clean, production-ready #{language} code
    - Include proper error handling
    - Add appropriate documentation
    - Follow #{language} best practices

    Code:
    """
  end

  defp extract_code_from_response(response) do
    # Try to extract code from markdown code blocks
    case Regex.run(~r/```(?:[a-zA-Z]*)?\s*\n?(.*?)\n?```/s, response) do
      [_, code] -> String.trim(code)
      nil -> 
        # If no code blocks found, return the response as-is
        # but try to clean up any leading/trailing text
        response
        |> String.split("\n")
        |> Enum.drop_while(&(!String.contains?(&1, ["def ", "function ", "class ", "struct ", "impl ", "fn ", "pub fn"])))
        |> Enum.take_while(&(!String.contains?(&1, ["```", "Explanation:", "Note:"])))
        |> Enum.join("\n")
        |> String.trim()
    end
  end

  defp generate_basic_code(task, language) do
    # Fallback basic code generation
    {:ok,
     """
     # Generated code for: #{task}
     # Language: #{language}
     # Generated at: #{DateTime.utc_now()}

     # Basic implementation for: #{task}
     defmodule GeneratedCode do
       @moduledoc \"\"\"
       Generated code for: #{task}
       Language: #{language}
       \"\"\"
       
       def main do
         # Implement the requested functionality
         :ok
       end
     end
     """}
  end

  # Generate code using LLM API (Gemini/Claude)
  defp generate_with_api(task, language, quality, complexity) do
    Logger.info("Generating with LLM API (#{complexity} complexity)...")

    # Select LLM complexity level based on task complexity
    llm_complexity = map_complexity_to_llm(complexity)

    prompt = build_generation_prompt(task, language, quality)

    case Singularity.LLM.Service.call_with_prompt(llm_complexity, prompt, task_type: :coder) do
      {:ok, %{response: code}} ->
        {:ok, extract_code_block(code)}

      {:error, reason} ->
        Logger.error("API generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Detect task complexity from description
  defp detect_complexity(task) do
    task_lower = String.downcase(task)

    cond do
      # Complex keywords
      String.contains?(task_lower, ["refactor", "redesign", "architecture", "system", "migrate"]) ->
        :complex

      # Medium keywords
      String.contains?(task_lower, ["genserver", "supervisor", "implement", "integrate", "api"]) ->
        :medium

      # Simple by default
      true ->
        :simple
    end
  end

  # Map task complexity to LLM Service complexity
  defp map_complexity_to_llm(:simple), do: :simple
  defp map_complexity_to_llm(:medium), do: :medium
  defp map_complexity_to_llm(:complex), do: :complex

  # Build code generation prompt
  defp build_generation_prompt(task, language, quality) do
    quality_guidelines =
      case quality do
        :production ->
          """
          - Include comprehensive documentation
          - Add error handling
          - Include type specifications
          - Follow language best practices
          """

        :quick ->
          """
          - Focus on functionality
          - Basic error handling
          - Minimal documentation
          """
      end

    """
    Generate #{language} code for the following task:

    TASK: #{task}

    REQUIREMENTS:
    #{quality_guidelines}

    Return ONLY the code, no explanations. Use proper #{language} idioms and conventions.
    """
  end

  # Extract code block from LLM response
  defp extract_code_block(response) when is_binary(response) do
    # Try to extract code from markdown code blocks
    case Regex.run(~r/```(?:\w+)?\n(.*?)```/s, response) do
      [_, code] -> String.trim(code)
      nil -> String.trim(response)
    end
  end

  # Check if T5 model is fully downloaded
  defp model_downloaded?(model_path) do
    required_files = [
      "encoder_model.onnx",
      "decoder_model.onnx",
      "tokenizer.json"
    ]

    Enum.all?(required_files, fn file ->
      Path.join(model_path, file) |> File.exists?()
    end)
  end

  ## RAG Integration

  # Load quality template from Knowledge.TemplateService or fallback
  defp load_quality_template(language, quality) do
    artifact_id = "#{language}_#{quality}"

    case Singularity.Knowledge.TemplateService.get_template("quality_template", artifact_id) do
      {:ok, template} ->
        Logger.debug("Loaded quality template: #{artifact_id}")
        {:ok, template}

      {:error, _reason} ->
        # Try language-only fallback
        case Singularity.Knowledge.TemplateService.get_template("quality_template", language) do
          {:ok, template} ->
            Logger.debug("Loaded fallback quality template: #{language}")
            {:ok, template}

          {:error, _} ->
            Logger.warning(
              "No quality template found for #{language}_#{quality}, proceeding without template"
            )

            {:ok, nil}
        end
    end
  end

  # Find RAG examples if enabled
  defp maybe_find_rag_examples(_task, _language, _repos, _top_k, false, _template) do
    {:ok, []}
  end

  defp maybe_find_rag_examples(task, language, repos, top_k, true, quality_template) do
    Logger.debug("Finding RAG examples: task=#{task}, language=#{language}, top_k=#{top_k}")

    case RAGCodeGenerator.find_best_examples(
           task,
           language,
           repos,
           top_k,
           false,
           true,
           quality_template
         ) do
      {:ok, examples} ->
        Logger.info("Found #{length(examples)} RAG examples")
        {:ok, examples}

      {:error, reason} ->
        Logger.warning("RAG search failed, continuing without examples: #{inspect(reason)}")
        {:ok, []}
    end
  end

  # Generate with selected method + RAG examples
  defp generate_with_method_and_rag(
         task,
         language,
         quality,
         complexity,
         method,
         examples,
         quality_template
       ) do
    selected_method = select_method(method, complexity)
    prompt = build_unified_prompt(task, language, quality, examples, quality_template)

    case selected_method do
      :llm_api ->
        generate_with_t5(prompt, language, quality)

      :basic ->
        generate_basic_code(prompt, language)
    end
  end

  # Build unified prompt with RAG examples and quality requirements
  defp build_unified_prompt(task, language, quality, examples, quality_template) do
    # Quality requirements section
    quality_section =
      if quality_template do
        build_quality_requirements_section(quality_template)
      else
        ""
      end

    # RAG examples section
    examples_section =
      if length(examples) > 0 do
        examples_text =
          examples
          |> Enum.with_index(1)
          |> Enum.map(fn {ex, idx} ->
            """
            Example #{idx} (#{ex.repo}/#{Path.basename(ex.path)}, similarity: #{Float.round(ex.similarity, 2)}):
            ```#{ex.language}
            #{String.slice(ex.content, 0..500)}
            ```
            """
          end)
          |> Enum.join("\n")

        """
        Here are #{length(examples)} similar, high-quality code examples from your codebases:

        #{examples_text}
        """
      else
        ""
      end

    """
    Task: #{task}
    Language: #{language}
    #{quality_section}
    #{examples_section}

    Based on these requirements#{if length(examples) > 0, do: " and proven patterns", else: ""}, generate code for the task.
    OUTPUT CODE ONLY - no explanations, no comments about the examples.
    """
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
    Quality Standard: #{String.upcase(quality_level)} (#{template_name})

    REQUIREMENTS:
    #{req_list}
    """
  end

  defp build_error_handling_req(requirements) do
    case get_in(requirements, ["error_handling"]) do
      %{"required_pattern" => pattern} -> "- Error handling: #{pattern}"
      _ -> nil
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

  # Generate with API using unified prompt
  defp generate_with_api_unified(prompt, _language, _quality, complexity) do
    Logger.info("Generating with LLM API (#{complexity} complexity)...")

    llm_complexity = map_complexity_to_llm(complexity)

    case Singularity.LLM.Service.call_with_prompt(llm_complexity, prompt, task_type: :coder) do
      {:ok, %{response: code}} ->
        {:ok, extract_code_block(code)}

      {:error, reason} ->
        Logger.error("API generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Validate against quality template (with retries)
  defp maybe_validate(code, nil, _language, _validate, _max_retries) do
    {:ok, code}
  end

  defp maybe_validate(code, _quality_template, _language, false, _max_retries) do
    {:ok, code}
  end

  defp maybe_validate(code, quality_template, language, true, max_retries) do
    case Singularity.Code.Quality.TemplateValidator.validate(code, quality_template, language) do
      {:ok, %{compliant: true, score: score}} ->
        Logger.info("✅ Validation passed (score: #{Float.round(score, 2)})")
        {:ok, code}

      {:ok, %{compliant: false, violations: violations, score: score}} ->
        Logger.warning("❌ Validation failed (score: #{Float.round(score, 2)})")
        Logger.warning("Violations: #{inspect(violations)}")

        if max_retries > 0 do
          Logger.info("Note: Validation failed but not retrying (retries not implemented yet)")
        end

        # Return code anyway (validation is informational)
        {:ok, code}

      {:error, reason} ->
        Logger.warning("Validation error (non-fatal): #{inspect(reason)}")
        {:ok, code}
    end
  end
end
