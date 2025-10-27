defmodule Singularity.CodeGeneration.Implementations.QualityCodeGenerator do
  @moduledoc """
  High-Quality Code Generation with enforced standards

  Forces generated code to meet quality requirements:
  - ✅ Documentation (@moduledoc, @doc for every function)
  - ✅ Type specs (@spec for every function)
  - ✅ Tests (generated alongside code)
  - ✅ Error handling (explicit error cases)
  - ✅ Naming conventions (snake_case, descriptive names)
  - ✅ No code smells (no TODOs, no long functions)

  ## Quality Levels

  - `:production` - Maximum quality (docs, specs, tests, strict)
  - `:standard` - Good quality (docs, specs, basic tests)
  - `:draft` - Minimal quality (just working code)

  ## Usage

      # Generate production-quality code
      {:ok, result} = QualityCodeGenerator.generate(
        task: "Parse JSON API response",
        language: "elixir",
        quality: :production
      )

      # result = %{
      #   code: "...",           # Main implementation
      #   docs: "...",           # @moduledoc + @doc
      #   specs: "...",          # @spec declarations
      #   tests: "...",          # ExUnit tests
      #   quality_score: 0.95   # 0-1 quality rating
      # }
  """

  require Logger
  alias Singularity.{RAGCodeGenerator, CodeModel}
  alias Singularity.Knowledge.TemplateGeneration

  @templates_dir "priv/code_quality_templates"
  @supported_languages ~w(elixir erlang gleam rust go typescript python)

  @type quality_level :: :production | :standard | :draft
  @type generation_result :: %{
          code: String.t(),
          docs: String.t(),
          specs: String.t(),
          tests: String.t(),
          quality_score: float()
        }

  @doc """
  Get quality template for a specific language.

  Returns the appropriate quality template based on language.
  """
  def get_template(language) when language in @supported_languages do
    case language do
      "elixir" -> load_template("elixir_production.json")
      "erlang" -> load_template("erlang_production.json")
      "gleam" -> load_template("gleam_production.json")
      "rust" -> load_template("rust_production.json")
      "go" -> load_template("go_production.json")
      "typescript" -> load_template("typescript_production.json")
      "python" -> load_template("python_production.json")
      _ -> load_template("default_production.json")
    end
  end

  def get_template(_language), do: load_template("default_production.json")

  @doc """
  Load quality template from file.
  """
  def load_template(filename) do
    template_path = Path.join(@templates_dir, filename)

    case File.read(template_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, template} -> {:ok, template}
          {:error, _reason} -> {:error, :json_decode_error}
        end

      {:error, _reason} ->
        Logger.warning("Template file not found: #{template_path}, using default")
        {:ok, default_template()}
    end
  end

  def load_template(filename, _opts) do
    case load_template(filename) do
      {:ok, template} ->
        {:ok, template}

      {:error, _reason} ->
        # Fallback to default template with options
        {:ok, default_template(_opts)}
    end
  end

  defp default_template(_opts \\ []) do
    %{
      "quality_standards" => %{
        "documentation" => %{
          "required" => true,
          "min_coverage" => 0.9
        },
        "type_specs" => %{
          "required" => true,
          "min_coverage" => 0.8
        },
        "tests" => %{
          "required" => true,
          "min_coverage" => 0.8
        },
        "error_handling" => %{
          "required" => true,
          "explicit_errors" => true
        }
      },
      "naming_conventions" => %{
        "functions" => "snake_case",
        "modules" => "PascalCase",
        "variables" => "snake_case"
      },
      "code_quality" => %{
        "max_function_length" => 50,
        "max_module_length" => 500,
        "no_todos" => true,
        "no_debug_prints" => true
      }
    }
  end

  @doc """
  Generate high-quality code with enforced standards

  ## Supported Languages

  - Elixir, Erlang, Gleam (BEAM languages)
  - Rust
  - Go
  - TypeScript
  - Python

  ## Options

  - `:task` - What to generate (required)
  - `:language` - Target language (elixir, rust, go, typescript, python, etc.)
  - `:quality` - Quality level (:production, :standard, :draft)
  - `:template` - Custom template path (optional)
  - `:use_rag` - Use RAG to find best examples (default: true)
  - `:output_path` - File path where code will be written (for tracking)
  """
  @spec generate(keyword()) :: {:ok, generation_result()} | {:error, term()}
  def generate(opts) do
    task = Keyword.fetch!(opts, :task)
    language = Keyword.get(opts, :language, "elixir")
    quality = Keyword.get(opts, :quality, :production)
    use_rag = Keyword.get(opts, :use_rag, true)
    template_path = Keyword.get(opts, :template)
    output_path = Keyword.get(opts, :output_path)

    # Load quality template
    with {:ok, template} <- load_template(language, quality, template_path) do
      generate_with_template(task, language, quality, use_rag, template, output_path)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp generate_with_template(task, language, quality, use_rag, template, output_path \\ nil) do
    Logger.info("Generating #{quality} quality code: #{task}")

    # NEW: Ask questions if template has them (Phase 2: 2-way templates)
    answers = ask_template_questions(template, task, language, quality)
    Logger.debug("Template answers: #{inspect(answers)}")

    # Merge answers into template context for generation
    template_with_answers = Map.put(template, "answers", answers)

    with {:ok, code} <-
           generate_implementation(task, language, quality, use_rag, template_with_answers),
         {:ok, docs} <- generate_documentation(code, task, language, quality),
         {:ok, specs} <- generate_type_specs(code, language, quality),
         {:ok, tests} <- generate_tests(code, task, language, quality),
         {:ok, score} <- calculate_quality_score(code, docs, specs, tests, quality) do
      result = %{
        code: code,
        docs: docs,
        specs: specs,
        tests: tests,
        quality_score: score
      }

      # Track this generation (Copier pattern) with answers
      track_generation(
        template_with_answers,
        task,
        language,
        quality,
        output_path,
        score >= 0.7,
        score,
        answers
      )

      Logger.info("✅ Generated code with quality score: #{Float.round(score, 2)}")
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Ask template questions if they exist (Phase 2: 2-way templates).

  Questions are inferred from LLM context based on the task.
  """
  defp ask_template_questions(template, task, language, quality) do
    case Map.get(template, "questions") do
      questions when is_list(questions) and length(questions) > 0 ->
        Logger.info(
          "Template has #{length(questions)} questions, asking via LLM context inference..."
        )

        # Use TemplateQuestion to ask questions via LLM
        case Singularity.Knowledge.TemplateQuestion.ask_via_llm(
               questions,
               llm_context: "User task: #{task}. Language: #{language}. Quality: #{quality}.",
               strategy: :infer_from_context,
               template_id: "quality_template:#{language}-#{quality}"
             ) do
          {:ok, answers} ->
            Logger.info("Got answers: #{inspect(Map.keys(answers))}")
            answers

          {:error, reason} ->
            Logger.warning("Failed to get answers from LLM: #{inspect(reason)}, using defaults")
            get_default_answers(questions)
        end

      _ ->
        # No questions in template
        Logger.debug("Template has no questions, skipping")
        %{}
    end
  end

  defp get_default_answers(questions) do
    questions
    |> Enum.map(fn q ->
      name = Map.get(q, "name")
      default = Map.get(q, "default")
      {name, default}
    end)
    |> Enum.into(%{})
  end

  defp track_generation(
         template,
         task,
         language,
         quality,
         output_path,
         success,
         score,
         question_answers \\ %{}
       ) do
    # Only track if output_path provided
    if output_path do
      template_id = "quality_template:#{language}-#{quality}"

      # Read version from template, fallback to 1.0.0
      # Check multiple possible version fields in order of preference
      template_version =
        case template do
          %{"spec_version" => version} when is_binary(version) -> version
          %{"version" => version} when is_binary(version) -> version
          %{"metadata" => %{"version" => version}} when is_binary(version) -> version
          %{"metadata" => %{"spec_version" => version}} when is_binary(version) -> version
          _ -> "1.0.0"
        end

      # Merge basic answers with question answers
      all_answers =
        Map.merge(
          %{
            task: task,
            language: language,
            quality: quality,
            quality_score: score
          },
          question_answers
        )

      case TemplateGeneration.record(
             template_id: template_id,
             template_version: template_version,
             file_path: output_path,
             answers: all_answers,
             success: success
           ) do
        {:ok, _} ->
          Logger.debug(
            "Tracked generation: #{template_id} v#{template_version} -> #{output_path}"
          )

        {:error, reason} ->
          Logger.warning("Failed to track generation: #{inspect(reason)}")
      end
    end

    :ok
  end

  @doc """
  Enforce quality standards on existing code

  Takes code and adds:
  - Missing documentation
  - Missing type specs
  - Missing error handling
  - Tests
  """
  @spec enforce_quality(String.t(), keyword()) :: {:ok, generation_result()} | {:error, term()}
  def enforce_quality(code, _opts \\ []) do
    language = Keyword.get(opts, :language, "elixir")
    quality = Keyword.get(opts, :quality, :standard)

    Logger.info("Enforcing #{quality} quality on existing code")

    with {:ok, docs} <- add_missing_docs(code, language, quality),
         {:ok, specs} <- add_missing_specs(code, language, quality),
         {:ok, enhanced} <- add_error_handling(code, language, quality),
         {:ok, tests} <- generate_tests(enhanced, "existing code", language, quality),
         {:ok, score} <- calculate_quality_score(enhanced, docs, specs, tests, quality) do
      {:ok,
       %{
         code: enhanced,
         docs: docs,
         specs: specs,
         tests: tests,
         quality_score: score
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Load quality template from disk

  Templates are JSON files in priv/code_quality_templates/
  """
  @spec load_template(String.t(), quality_level(), String.t() | nil) ::
          {:ok, map()} | {:error, term()}
  def load_template(language, quality, custom_path \\ nil) do
    # If custom_path is provided, try to load from that path first
    if custom_path do
      case load_template_from_path(custom_path) do
        {:ok, template} ->
          Logger.debug("Loaded quality template from custom path: #{custom_path}")
          {:ok, template}

        {:error, _} ->
          Logger.warning(
            "Failed to load template from custom path: #{custom_path}, falling back to discovery"
          )

          load_template_via_discovery(language, quality)
      end
    else
      load_template_via_discovery(language, quality)
    end
  end

  defp load_template_via_discovery(language, quality) do
    # Use dynamic template discovery - tries multiple patterns and semantic search
    case Singularity.Knowledge.TemplateService.find_quality_template(language, quality) do
      {:ok, template} ->
        Logger.debug("Loaded quality template via dynamic discovery: #{language}_#{quality}")
        {:ok, template}

      {:error, reason} ->
        Logger.warning(
          "Quality template not found via discovery: #{language}_#{quality}, reason: #{reason}"
        )

        # Fallback to default template
        {:ok, default_template(language, quality)}
    end
  end

  ## Private Functions

  defp load_template_from_path(custom_path) do
    case File.read(custom_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, template} -> {:ok, template}
          {:error, reason} -> {:error, "Invalid JSON in custom template: #{reason}"}
        end

      {:error, reason} ->
        {:error, "Failed to read custom template: #{reason}"}
    end
  end

  defp default_template(language, quality) do
    %{
      "name" => "#{language} #{quality} (default)",
      "language" => language,
      "quality_level" => to_string(quality),
      "requirements" => %{},
      "prompts" => %{
        "code_generation" =>
          "Generate #{quality} quality #{language} code for: {task}\n\nOUTPUT CODE ONLY."
      }
    }
  end

  defp generate_implementation(task, language, quality, use_rag, template) do
    quality_prompt = build_quality_prompt_from_template(task, template)

    if use_rag do
      # Use RAG to find best examples
      RAGCodeGenerator.generate(
        task: quality_prompt,
        language: language,
        top_k: quality_examples_count(quality),
        prefer_recent: true
      )
    else
      # Direct generation without RAG
      CodeModel.complete(quality_prompt, temperature: quality_temperature(quality))
    end
  end

  defp generate_documentation(code, task, language, quality) do
    case quality do
      :production ->
        # Generate comprehensive docs
        prompt = """
        Generate complete documentation for this #{language} code.
        Include:
        - @moduledoc with overview, examples, and important notes
        - @doc for EVERY public function with examples
        - Inline comments for complex logic only

        Code:
        ```#{language}
        #{code}
        ```

        OUTPUT DOCUMENTATION ONLY (no explanations):
        """

        CodeModel.complete(prompt, temperature: 0.05)

      :standard ->
        # Generate basic docs
        prompt = """
        Generate documentation for this #{language} code.
        Include @moduledoc and @doc for public functions.

        Code:
        ```#{language}
        #{code}
        ```

        OUTPUT DOCUMENTATION ONLY:
        """

        CodeModel.complete(prompt, temperature: 0.1)

      :draft ->
        # Minimal docs
        {:ok, "# #{task}\n"}
    end
  end

  defp generate_type_specs(code, language, quality) do
    case {language, quality} do
      {"elixir", level} when level in [:production, :standard] ->
        prompt = """
        Generate @spec type specifications for this Elixir code.
        Be precise with types (use String.t(), integer(), map(), etc.).

        Code:
        ```elixir
        #{code}
        ```

        OUTPUT @spec DECLARATIONS ONLY:
        """

        CodeModel.complete(prompt, temperature: 0.05)

      {"rust", level} when level in [:production, :standard] ->
        # Rust has built-in types, just validate
        {:ok, ""}

      _ ->
        {:ok, ""}
    end
  end

  defp generate_tests(code, task, language, quality) do
    case {language, quality} do
      {"elixir", :production} ->
        # Comprehensive tests
        prompt = """
        Generate comprehensive ExUnit tests for this code.
        Include:
        - Happy path tests
        - Edge cases (nil, empty, invalid input)
        - Error cases
        - Property-based tests (if applicable)

        Task: #{task}

        Code:
        ```elixir
        #{code}
        ```

        OUTPUT TEST CODE ONLY (complete ExUnit test module):
        """

        CodeModel.complete(prompt, temperature: 0.1)

      {"elixir", :standard} ->
        # Basic tests
        prompt = """
        Generate basic ExUnit tests for this code.
        Include happy path and basic error cases.

        Code:
        ```elixir
        #{code}
        ```

        OUTPUT TEST CODE ONLY:
        """

        CodeModel.complete(prompt, temperature: 0.1)

      {"rust", level} when level in [:production, :standard] ->
        # Generate Rust tests
        prompt = """
        Generate #{if level == :production, do: "comprehensive", else: "basic"} Rust tests.

        Code:
        ```rust
        #{code}
        ```

        OUTPUT TEST CODE ONLY (#[cfg(test)] module):
        """

        CodeModel.complete(prompt, temperature: 0.1)

      _ ->
        {:ok, ""}
    end
  end

  defp add_missing_docs(code, "elixir", quality) do
    # Check which functions are missing @doc
    quality_instruction =
      case quality do
        :production -> "Add comprehensive @moduledoc and @doc with examples for production code."
        :standard -> "Add @moduledoc and @doc for public functions."
        _ -> "Add basic @doc for public functions."
      end

    prompt = """
    #{quality_instruction}
    Keep existing docs unchanged.

    Code:
    ```elixir
    #{code}
    ```

    OUTPUT CODE WITH DOCS (full code, not just docs):
    """

    CodeModel.complete(prompt, temperature: 0.05)
  end

  defp add_missing_docs(code, "typescript", quality) do
    quality_instruction =
      case quality do
        :production ->
          "Add JSDoc comments with @param, @returns, and @example for all public functions."

        :standard ->
          "Add JSDoc comments for public functions."

        _ ->
          "Add basic JSDoc comments."
      end

    prompt = """
    #{quality_instruction}

    Code:
    ```typescript
    #{code}
    ```

    OUTPUT CODE WITH DOCS:
    """

    CodeModel.complete(prompt, temperature: 0.1)
  end

  defp add_missing_docs(code, "rust", quality) do
    quality_instruction =
      case quality do
        :production -> "Add comprehensive documentation comments with examples and safety notes."
        :standard -> "Add documentation comments for public items."
        _ -> "Add basic documentation comments."
      end

    prompt = """
    #{quality_instruction}

    Code:
    ```rust
    #{code}
    ```

    OUTPUT CODE WITH DOCS:
    """

    CodeModel.complete(prompt, temperature: 0.1)
  end

  defp add_missing_docs(code, language, quality) do
    # Generic documentation addition for unsupported languages
    Logger.info("Adding documentation for #{language} code (quality: #{quality})")

    prompt = """
    Add appropriate documentation comments for #{language} code.
    Follow language conventions for documentation.

    Code:
    ```#{language}
    #{code}
    ```

    OUTPUT CODE WITH DOCS:
    """

    CodeModel.complete(prompt, temperature: 0.2)
  end

  defp add_missing_specs(code, "elixir", quality) when quality in [:production, :standard] do
    prompt = """
    Add @spec to functions that are missing type specifications.
    Keep existing specs unchanged.

    Code:
    ```elixir
    #{code}
    ```

    OUTPUT CODE WITH SPECS (full code):
    """

    CodeModel.complete(prompt, temperature: 0.05)
  end

  defp add_missing_specs(code, "typescript", quality) when quality in [:production, :standard] do
    prompt = """
    Add TypeScript type annotations to functions that are missing them.
    Use appropriate TypeScript types and interfaces.

    Code:
    ```typescript
    #{code}
    ```

    OUTPUT CODE WITH TYPES:
    """

    CodeModel.complete(prompt, temperature: 0.1)
  end

  defp add_missing_specs(code, "rust", quality) when quality in [:production, :standard] do
    prompt = """
    Add explicit type annotations to functions that are missing them.
    Use Rust's type system effectively.

    Code:
    ```rust
    #{code}
    ```

    OUTPUT CODE WITH TYPES:
    """

    CodeModel.complete(prompt, temperature: 0.1)
  end

  defp add_missing_specs(code, language, quality) do
    # Generic type specification addition for unsupported languages
    Logger.info("Adding type specs for #{language} code (quality: #{quality})")

    prompt = """
    Add appropriate type annotations or specifications for #{language} code.
    Follow language conventions for type safety.

    Code:
    ```#{language}
    #{code}
    ```

    OUTPUT CODE WITH TYPES:
    """

    CodeModel.complete(prompt, temperature: 0.2)
  end

  defp add_error_handling(code, language, quality) do
    try do
      case language do
        :elixir ->
          add_elixir_error_handling(code, quality)

        :rust ->
          add_rust_error_handling(code, quality)

        :javascript ->
          add_javascript_error_handling(code, quality)

        :typescript ->
          add_typescript_error_handling(code, quality)

        _ ->
          {:ok, code}
      end
    rescue
      error ->
        Logger.warning("Error handling addition failed: #{inspect(error)}")
        {:ok, code}
    end
  end

  defp add_elixir_error_handling(code, quality) do
    case quality do
      :production ->
        # Add comprehensive error handling for production
        enhanced_code = """
        #{code}

        # Error handling utilities
        defmodule ErrorHandler do
          @moduledoc \"\"\"
          Production error handling utilities.
          \"\"\"

          @spec handle_error(term(), String.t()) :: {:error, map()}
          def handle_error(error, context) do
            error_info = %{
              error: inspect(error),
              context: context,
              timestamp: DateTime.utc_now(),
              stacktrace: __STACKTRACE__
            }
            
            Logger.error("Error in \#{context}: \#{inspect(error_info)}")
            {:error, error_info}
          end

          @spec safe_call(function(), String.t()) :: {:ok, term()} | {:error, map()}
          def safe_call(fun, context) do
            try do
              result = fun.()
              {:ok, result}
            rescue
              error ->
                handle_error(error, context)
            end
          end
        end
        """

        {:ok, enhanced_code}

      :development ->
        # Add basic error handling for development
        enhanced_code = """
        #{code}

        # Basic error handling for development
        defmodule DevErrorHandler do
          def handle_error(error, context) do
            IO.puts("Error in \#{context}: \#{inspect(error)}")
            {:error, %{error: error, context: context}}
          end
        end
        """

        {:ok, enhanced_code}

      _ ->
        {:ok, code}
    end
  end

  defp add_rust_error_handling(code, quality) do
    case quality do
      :production ->
        enhanced_code = """
        #{code}

        // Production error handling
        use std::error::Error;
        use std::fmt;

        #[derive(Debug)]
        pub struct AppError {
            pub message: String,
            pub context: String,
        }

        impl fmt::Display for AppError {
            fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
                write!(f, "Error in {}: {}", self.context, self.message)
            }
        }

        impl Error for AppError {}

        pub fn handle_error<E: Error>(error: E, context: &str) -> AppError {
            AppError {
                message: error.to_string(),
                context: context.to_string(),
            }
        }
        """

        {:ok, enhanced_code}

      _ ->
        {:ok, code}
    end
  end

  defp add_javascript_error_handling(code, quality) do
    case quality do
      :production ->
        enhanced_code = """
        #{code}

        // Production error handling
        class AppError extends Error {
          constructor(message, context) {
            super(message);
            this.name = 'AppError';
            this.context = context;
            this.timestamp = new Date().toISOString();
          }
        }

        function handleError(error, context) {
          const errorInfo = {
            message: error.message,
            context: context,
            timestamp: new Date().toISOString(),
            stack: error.stack
          };
          
          console.error('Error in', context, ':', error);
          return new AppError(error.message, context);
        }

        function safeCall(fn, context) {
          try {
            return { ok: true, result: fn() };
          } catch (error) {
            return { ok: false, error: handleError(error, context) };
          }
        }
        """

        {:ok, enhanced_code}

      _ ->
        {:ok, code}
    end
  end

  defp add_typescript_error_handling(code, quality) do
    case quality do
      :production ->
        enhanced_code = """
        #{code}

        // Production error handling
        interface ErrorInfo {
          message: string;
          context: string;
          timestamp: string;
          stack?: string;
        }

        class AppError extends Error {
          public readonly context: string;
          public readonly timestamp: string;

          constructor(message: string, context: string) {
            super(message);
            this.name = 'AppError';
            this.context = context;
            this.timestamp = new Date().toISOString();
          }
        }

        function handleError(error: Error, context: string): AppError {
          const errorInfo: ErrorInfo = {
            message: error.message,
            context: context,
            timestamp: new Date().toISOString(),
            stack: error.stack
          };
          
          console.error('Error in', context, ':', error);
          return new AppError(error.message, context);
        }

        function safeCall<T>(fn: () => T, context: string): { ok: true; result: T } | { ok: false; error: AppError } {
          try {
            return { ok: true, result: fn() };
          } catch (error) {
            return { ok: false, error: handleError(error as Error, context) };
          }
        }
        """

        {:ok, enhanced_code}

      _ ->
        {:ok, code}
    end
  end

  defp calculate_quality_score(code, docs, specs, tests, quality) do
    # Multi-factor quality scoring
    scores = %{
      has_code: if(String.length(code) > 50, do: 1.0, else: 0.0),
      has_docs: if(String.length(docs) > 100, do: 1.0, else: 0.5),
      has_specs: if(String.length(specs) > 20, do: 1.0, else: 0.5),
      has_tests: if(String.length(tests) > 100, do: 1.0, else: 0.5),
      no_todos: if(String.contains?(code, ["TODO", "FIXME"]), do: 0.0, else: 1.0),
      reasonable_length: if(String.length(code) < 1000, do: 1.0, else: 0.8)
    }

    # Weight by quality level
    weights =
      case quality do
        :production ->
          %{
            has_code: 1.0,
            has_docs: 1.0,
            has_specs: 1.0,
            has_tests: 1.0,
            no_todos: 1.0,
            reasonable_length: 0.5
          }

        :standard ->
          %{
            has_code: 1.0,
            has_docs: 0.8,
            has_specs: 0.7,
            has_tests: 0.6,
            no_todos: 0.8,
            reasonable_length: 0.5
          }

        :draft ->
          %{
            has_code: 1.0,
            has_docs: 0.3,
            has_specs: 0.2,
            has_tests: 0.2,
            no_todos: 0.5,
            reasonable_length: 0.5
          }
      end

    total_weight = Map.values(weights) |> Enum.sum()

    weighted_score =
      Enum.reduce(scores, 0.0, fn {key, score}, acc ->
        acc + score * Map.get(weights, key, 0.0)
      end)

    {:ok, weighted_score / total_weight}
  end

  defp build_quality_prompt_from_template(task, template) do
    # Use template's code_generation prompt
    prompt_template =
      get_in(template, ["prompts", "code_generation"]) ||
        "Generate code for: {task}\n\nOUTPUT CODE ONLY."

    String.replace(prompt_template, "{task}", task)
  end

  defp quality_examples_count(:production), do: 10
  defp quality_examples_count(:standard), do: 5
  defp quality_examples_count(:draft), do: 2

  # Very strict
  defp quality_temperature(:production), do: 0.05
  defp quality_temperature(:standard), do: 0.1
  defp quality_temperature(:draft), do: 0.2
end
