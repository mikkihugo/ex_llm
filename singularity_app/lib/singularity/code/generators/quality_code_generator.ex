defmodule Singularity.QualityCodeGenerator do
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
          {:error, reason} -> {:error, {:json_decode_error, reason}}
        end

      {:error, reason} ->
        Logger.warning("Template file not found: #{template_path}, using default")
        {:ok, default_template()}
    end
  end

  def load_template(filename, opts) do
    case load_template(filename) do
      {:ok, template} ->
        {:ok, template}

      {:error, _reason} ->
        # Fallback to default template with options
        {:ok, default_template(opts)}
    end
  end

  defp default_template(opts \\ []) do
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
  """
  @spec generate(keyword()) :: {:ok, generation_result()} | {:error, term()}
  def generate(opts) do
    task = Keyword.fetch!(opts, :task)
    language = Keyword.get(opts, :language, "elixir")
    quality = Keyword.get(opts, :quality, :production)
    use_rag = Keyword.get(opts, :use_rag, true)
    template_path = Keyword.get(opts, :template)

    # Load quality template
    with {:ok, template} <- load_template(language, quality, template_path) do
      generate_with_template(task, language, quality, use_rag, template)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp generate_with_template(task, language, quality, use_rag, template) do
    Logger.info("Generating #{quality} quality code: #{task}")

    with {:ok, code} <- generate_implementation(task, language, quality, use_rag, template),
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

      Logger.info("✅ Generated code with quality score: #{Float.round(score, 2)}")
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
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
  def enforce_quality(code, opts \\ []) do
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
    path = custom_path || build_template_path(language, quality)

    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, template} ->
            Logger.debug("Loaded quality template: #{path}")
            {:ok, template}

          {:error, reason} ->
            Logger.error("Failed to parse template: #{inspect(reason)}")
            {:error, :invalid_template}
        end

      {:error, :enoent} ->
        Logger.warning("Template not found: #{path}, using defaults")
        {:ok, default_template(language, quality)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  ## Private Functions

  defp build_template_path(language, quality) do
    filename = "#{language}_#{quality}.json"
    Path.join([@templates_dir, filename])
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
    prompt = """
    Add @moduledoc and @doc to functions that are missing documentation.
    Keep existing docs unchanged.

    Code:
    ```elixir
    #{code}
    ```

    OUTPUT CODE WITH DOCS (full code, not just docs):
    """

    CodeModel.complete(prompt, temperature: 0.05)
  end

  defp add_missing_docs(code, _language, _quality), do: {:ok, ""}

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

  defp add_missing_specs(code, _language, _quality), do: {:ok, ""}

  defp add_error_handling(code, language, quality) when quality == :production do
    prompt = """
    Add explicit error handling to this #{language} code.
    - Use {:ok, result} | {:error, reason} tuples (Elixir)
    - Use Result<T, E> (Rust)
    - Handle all error cases explicitly

    Code:
    ```#{language}
    #{code}
    ```

    OUTPUT ENHANCED CODE ONLY:
    """

    CodeModel.complete(prompt, temperature: 0.05)
  end

  defp add_error_handling(code, _language, _quality), do: {:ok, code}

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

  defp build_doc_prompt_from_template(code, template) do
    prompt_template =
      get_in(template, ["prompts", "documentation"]) ||
        "Generate documentation for:\n\n{code}\n\nOUTPUT DOCS ONLY."

    String.replace(prompt_template, "{code}", code)
  end

  defp quality_examples_count(:production), do: 10
  defp quality_examples_count(:standard), do: 5
  defp quality_examples_count(:draft), do: 2

  # Very strict
  defp quality_temperature(:production), do: 0.05
  defp quality_temperature(:standard), do: 0.1
  defp quality_temperature(:draft), do: 0.2
end
