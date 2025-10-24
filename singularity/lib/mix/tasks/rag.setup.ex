defmodule Mix.Tasks.Rag.Setup do
  @moduledoc """
  Setup RAG Quality-Aware Code Generation system.

  This task sets up the complete RAG system with quality templates:
  1. Syncs templates to knowledge_artifacts table
  2. Generates embeddings for semantic search
  3. Parses codebase into code_files and chunks
  4. Tests the system end-to-end

  ## Usage

      # Full setup (recommended)
      mix rag.setup

      # Individual steps
      mix rag.setup --step templates    # Just sync templates
      mix rag.setup --step parse        # Just parse codebase
      mix rag.setup --step test         # Just test generation

      # Skip steps
      mix rag.setup --skip-parsing      # Skip codebase parsing
      mix rag.setup --skip-test         # Skip end-to-end test

  ## What it does

  1. **Sync Templates** (mix knowledge.migrate)
     - Loads quality templates from templates_data/
     - Stores in knowledge_artifacts table
     - Generates embeddings for semantic search

  2. **Parse Codebase** (optional, ~2-5 min)
     - Parses lib/ directory with Rust parser
     - Extracts AST, functions, metrics
     - Stores in code_files table
     - Chunks into codebase_chunks for RAG

  3. **Generate Embeddings** (optional, ~1-3 min)
     - Creates vector embeddings for code chunks
     - Enables semantic search with pgvector

  4. **Test System** (optional)
     - Tests RAG generation with validation
     - Verifies quality template loading
     - Confirms parser integration

  ## Requirements

  - PostgreSQL running with pgvector extension
  - GOOGLE_AI_STUDIO_API_KEY for embeddings (free tier OK)
  """

  use Mix.Task
  require Logger

  @shortdoc "Setup RAG quality-aware code generation system"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          step: :string,
          skip_parsing: :boolean,
          skip_embeddings: :boolean,
          skip_test: :boolean,
          path: :string
        ],
        aliases: [s: :step, p: :path]
      )

    Mix.Task.run("app.start")

    step = opts[:step]
    skip_parsing = opts[:skip_parsing] || false
    skip_embeddings = opts[:skip_embeddings] || false
    skip_test = opts[:skip_test] || false
    parse_path = opts[:path] || "lib/"

    Mix.shell().info("""

    ╔══════════════════════════════════════════════════════════════╗
    ║  RAG Quality-Aware Code Generation - Setup                   ║
    ╚══════════════════════════════════════════════════════════════╝
    """)

    case step do
      "templates" ->
        run_templates_sync()

      "parse" ->
        run_codebase_parsing(parse_path)

      "embeddings" ->
        run_embedding_generation()

      "test" ->
        run_system_test()

      nil ->
        # Full setup
        run_full_setup(skip_parsing, skip_embeddings, skip_test, parse_path)

      _ ->
        Mix.shell().error("Unknown step: #{step}")
        Mix.shell().error("Valid steps: templates, parse, embeddings, test")
    end

    Mix.shell().info("""

    ✅ Setup complete!

    Try it:
      iex -S mix
      alias Singularity.CodeGeneration.Implementations.RAGCodeGenerator
      {:ok, code} = RAGCodeGenerator.generate(
        task: "Parse JSON with error handling",
        language: "elixir",
        quality_level: "production",
        validate: true
      )
    """)
  end

  defp run_full_setup(skip_parsing, skip_embeddings, skip_test, parse_path) do
    # Step 1: Sync templates (always)
    run_templates_sync()

    # Step 2: Parse codebase (optional)
    unless skip_parsing do
      run_codebase_parsing(parse_path)
    end

    # Step 3: Generate embeddings (optional)
    unless skip_embeddings || skip_parsing do
      run_embedding_generation()
    end

    # Step 4: Test system (optional)
    unless skip_test do
      run_system_test()
    end
  end

  defp run_templates_sync do
    Mix.shell().info("""

    ┌──────────────────────────────────────────────────────────┐
    │ Step 1: Syncing Quality Templates                        │
    └──────────────────────────────────────────────────────────┘
    """)

    Mix.Task.run("knowledge.migrate", ["--path", "../templates_data/code_generation/quality/"])

    Mix.shell().info("✅ Templates synced to knowledge_artifacts table")
  end

  defp run_codebase_parsing(parse_path) do
    Mix.shell().info("""

    ┌──────────────────────────────────────────────────────────┐
    │ Step 2: Parsing Codebase (#{parse_path})
    │ This may take 2-5 minutes...                             │
    └──────────────────────────────────────────────────────────┘
    """)

    # Check if path exists
    unless File.exists?(parse_path) do
      Mix.shell().error("Path does not exist: #{parse_path}")
      Mix.shell().error("Skipping codebase parsing")
      :ok
    else
      alias Singularity.ParserEngine

      case ParserEngine.parse_and_store_tree(parse_path) do
        {:ok, results} ->
          success_count = Enum.count(results, fn r -> match?({:ok, _}, r) end)
          error_count = Enum.count(results, fn r -> match?({:error, _}, r) end)

          Mix.shell().info("✅ Parsed #{success_count} files successfully")

          if error_count > 0 do
            Mix.shell().warn("⚠️  #{error_count} files failed to parse")
          end

        {:error, reason} ->
          Mix.shell().error("Failed to parse codebase: #{inspect(reason)}")
      end
    end
  end

  defp run_embedding_generation do
    Mix.shell().info("""

    ┌──────────────────────────────────────────────────────────┐
    │ Step 3: Generating Embeddings                            │
    │ This may take 1-3 minutes...                             │
    └──────────────────────────────────────────────────────────┘
    """)

    # Check if GOOGLE_AI_STUDIO_API_KEY is set
    unless System.get_env("GOOGLE_AI_STUDIO_API_KEY") do
      Mix.shell().error("⚠️  GOOGLE_AI_STUDIO_API_KEY not set")
      Mix.shell().error("Skipping embedding generation")
      Mix.shell().info("Get a free key at: https://makersuite.google.com/app/apikey")
      :ok
    else
      Mix.Task.run("knowledge.embed", ["--type", "quality_template"])

      Mix.shell().info("✅ Embeddings generated for quality templates")
    end
  end

  defp run_system_test do
    Mix.shell().info("""

    ┌──────────────────────────────────────────────────────────┐
    │ Step 4: Testing RAG System                               │
    └──────────────────────────────────────────────────────────┘
    """)

    alias Singularity.Knowledge.ArtifactStore

    # Test 1: Check if templates are loaded
    Mix.shell().info("Testing: Quality template loading...")

    case ArtifactStore.get("quality_template", "elixir_production") do
      {:ok, template} ->
        Mix.shell().info("  ✅ elixir_production template loaded (v#{template.version})")

      {:error, reason} ->
        Mix.shell().error("  ❌ Failed to load template: #{inspect(reason)}")
    end

    # Test 2: Check template validator
    Mix.shell().info("Testing: Template validator...")

    test_code = """
    @doc \"\"\"
    Parses JSON data.

    ## Examples
        iex> parse("{}")
        {:ok, %{}}
    \"\"\"
    @spec parse(String.t()) :: {:ok, map()} | {:error, term()}
    def parse(data) do
      Logger.debug("Parsing", size: byte_size(data))
      case Jason.decode(data) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> {:error, reason}
      end
    end
    """

    case ArtifactStore.get("quality_template", "elixir_production") do
      {:ok, template} ->
        alias Singularity.Code.Quality.TemplateValidator

        case TemplateValidator.validate(test_code, template, "elixir") do
          {:ok, %{compliant: true, score: score}} ->
            Mix.shell().info("  ✅ Validator works (score: #{Float.round(score, 2)})")

          {:ok, %{compliant: false, score: score, violations: violations}} ->
            Mix.shell().warn(
              "  ⚠️  Validator works but test code failed (score: #{Float.round(score, 2)})"
            )

            Mix.shell().warn("  Violations: #{inspect(violations)}")

          {:error, reason} ->
            Mix.shell().error("  ❌ Validator error: #{inspect(reason)}")
        end

      {:error, _} ->
        Mix.shell().warn("  ⚠️  Skipping validator test (template not loaded)")
    end

    # Test 3: Check parser
    Mix.shell().info("Testing: Parser engine...")

    case Singularity.ParserEngine.supported_languages() do
      languages when is_list(languages) ->
        Mix.shell().info("  ✅ Parser ready (#{length(languages)} languages)")

      _ ->
        Mix.shell().warn("  ⚠️  Parser may not be ready")
    end

    Mix.shell().info("""

    ✅ System tests complete!
    """)
  end
end
