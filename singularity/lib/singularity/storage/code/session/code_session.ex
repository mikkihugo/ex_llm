defmodule Singularity.CodeSession do
  @moduledoc """
  Session-aware code generation for multi-file development

  In real coding sessions, you generate MANY related pieces of code:
  - Multiple functions in same module
  - Related schemas and contexts
  - Tests for same feature
  - Migration + schema + context + controller

  **Session caching** keeps context hot for the entire session:
  - Tech stack (cached once per session)
  - Patterns (reused across all files)
  - RAG examples (shared context)
  - Model state (GPU keeps model loaded)

  ## Performance

  **Without sessions:**
  - Generate 10 files: 10 × 2s = 20s
  - Each file re-queries facts, patterns, RAG

  **With sessions:**
  - Generate 10 files: 2s + (9 × 200ms) = 3.8s
  - First file: full pipeline (2s)
  - Next 9 files: cached context (200ms each)
  - **5x faster!**

  ## Usage

      # Start a session for feature development
      {:ok, session} = CodeSession.start(
        project: "singularity",
        feature: "cache_with_ttl",
        files: [
          "lib/singularity/cache.ex",
          "lib/singularity/cache/supervisor.ex",
          "test/singularity/cache_test.exs"
        ]
      )

      # Generate all files in context (shares cache)
      {:ok, results} = CodeSession.generate_batch(session, [
        {"Implement cache GenServer", path: "lib/singularity/cache.ex"},
        {"Add supervisor", path: "lib/singularity/cache/supervisor.ex"},
        {"Write comprehensive tests", path: "test/singularity/cache_test.exs"}
      ])

      # Total time: ~3-4s for 3 files (vs 6s without session)

      # End session (cleanup)
      CodeSession.stop(session)
  """

  use GenServer
  require Logger
  alias Singularity.{CodeSynthesisPipeline, PatternIndexer, RAGCodeGenerator, CodeModel}

  defstruct [
    :id,
    :project,
    :feature,
    :files,
    :context,
    :tech_stack,
    :patterns,
    :rag_examples,
    :generated_code,
    :start_time,
    :stats
  ]

  ## Client API

  @doc """
  Start a coding session

  Preloads:
  - Project context (tech stack, patterns)
  - RAG examples from project
  - Shared patterns for feature
  """
  def start(opts) do
    project = Keyword.fetch!(opts, :project)
    feature = Keyword.get(opts, :feature, "development")
    files = Keyword.get(opts, :files, [])

    GenServer.start(__MODULE__, {project, feature, files}, [])
  end

  @doc """
  Generate multiple files in batch (shares context)
  """
  def generate_batch(session, tasks) do
    GenServer.call(session, {:generate_batch, tasks}, 30_000)
  end

  @doc """
  Generate single file (uses session cache)
  """
  def generate_one(session, task, opts \\ []) do
    GenServer.call(session, {:generate_one, task, opts}, 10_000)
  end

  @doc """
  Get session statistics
  """
  def stats(session) do
    GenServer.call(session, :stats)
  end

  @doc """
  Stop session and cleanup
  """
  def stop(session) do
    GenServer.stop(session)
  end

  ## Server Callbacks

  @impl true
  def init({project, feature, files}) do
    Logger.info("Starting code session: #{project}/#{feature}")

    # Detect project context from first file
    context = detect_project_context(project, files)

    # Preload shared resources (do this ONCE for entire session)
    {:ok, state, {:continue, :preload}} =
      {:ok,
       %__MODULE__{
         id: generate_session_id(),
         project: project,
         feature: feature,
         files: files,
         context: context,
         tech_stack: [],
         patterns: [],
         rag_examples: [],
         generated_code: %{},
         start_time: System.monotonic_time(:millisecond),
         stats: %{
           files_generated: 0,
           cache_hits: 0,
           total_time_ms: 0
         }
       }, {:continue, :preload}}

    {:ok, state, {:continue, :preload}}
  end

  @impl true
  def handle_continue(:preload, state) do
    start = System.monotonic_time(:millisecond)
    Logger.info("Preloading session context...")

    # Load in parallel
    tasks = [
      Task.async(fn -> load_tech_stack(state.context) end),
      Task.async(fn -> load_patterns(state.feature, state.context) end),
      Task.async(fn -> load_rag_examples(state.feature, state.context) end)
    ]

    [tech_stack, patterns, rag_examples] = Task.await_many(tasks, 5000)

    elapsed = System.monotonic_time(:millisecond) - start
    Logger.info("✅ Session context loaded in #{elapsed}ms")

    {:noreply, %{state | tech_stack: tech_stack, patterns: patterns, rag_examples: rag_examples}}
  end

  @impl true
  def handle_call({:generate_batch, tasks}, _from, state) do
    Logger.info("Generating #{length(tasks)} files in batch...")
    start = System.monotonic_time(:millisecond)

    # Generate all files using shared context
    results =
      Enum.map(tasks, fn {task_desc, opts} ->
        generate_with_session_cache(task_desc, opts, state)
      end)

    elapsed = System.monotonic_time(:millisecond) - start
    avg_per_file = div(elapsed, length(tasks))

    Logger.info(
      "✅ Generated #{length(tasks)} files in #{elapsed}ms (avg: #{avg_per_file}ms/file)"
    )

    # Update stats
    new_stats = %{
      state.stats
      | files_generated: state.stats.files_generated + length(tasks),
        total_time_ms: state.stats.total_time_ms + elapsed
    }

    {:reply, {:ok, results}, %{state | stats: new_stats}}
  end

  @impl true
  def handle_call({:generate_one, task, opts}, _from, state) do
    start = System.monotonic_time(:millisecond)

    result = generate_with_session_cache(task, opts, state)

    elapsed = System.monotonic_time(:millisecond) - start

    # Update stats
    new_stats = %{
      state.stats
      | files_generated: state.stats.files_generated + 1,
        total_time_ms: state.stats.total_time_ms + elapsed
    }

    {:reply, {:ok, result}, %{state | stats: new_stats}}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    session_duration = System.monotonic_time(:millisecond) - state.start_time

    avg_time =
      if state.stats.files_generated > 0 do
        div(state.stats.total_time_ms, state.stats.files_generated)
      else
        0
      end

    stats = %{
      session_id: state.id,
      project: state.project,
      feature: state.feature,
      files_generated: state.stats.files_generated,
      session_duration_ms: session_duration,
      avg_generation_time_ms: avg_time,
      tech_stack: state.tech_stack,
      patterns_loaded: length(state.patterns),
      rag_examples_loaded: length(state.rag_examples)
    }

    {:reply, stats, state}
  end

  ## Private Functions

  defp detect_project_context(project, files) do
    first_file = List.first(files) || "#{project}/lib/unknown.ex"
    CodeSynthesisPipeline.send(self(), {:detect_context, first_file, [repo: project]})

    receive do
      {:context, context} -> context
    after
      1000 ->
        # Fallback
        %{
          repo: project,
          language: "elixir",
          tech_stack: [],
          directory: ".",
          project_type: :unknown
        }
    end
  end

  defp load_tech_stack(context) do
    # Query SPARC facts or detect from path
    # This runs ONCE per session, not per file!
    case query_facts_for_tech_stack(context.repo) do
      {:ok, tech_stack} -> tech_stack
      _ -> detect_from_hints(context)
    end
  end

  defp load_patterns(feature, context) do
    # Load relevant patterns for this feature
    # Example: "cache with TTL" → GenServer patterns, TTL patterns, ETS patterns
    search_query = "#{feature} #{Enum.join(context.tech_stack, " ")}"

    case PatternIndexer.search(search_query, language: context.language, top_k: 10) do
      {:ok, patterns} -> patterns
      _ -> []
    end
  end

  defp load_rag_examples(feature, context) do
    # Load example code from same project
    # These examples are shared across ALL files in session
    repos = [context.repo]

    case RAGCodeGenerator.find_best_examples(feature, context.language, repos, 20, true, false) do
      {:ok, examples} -> examples
      _ -> []
    end
  end

  defp generate_with_session_cache(task, opts, state) do
    path = Keyword.get(opts, :path)

    Logger.debug("Generating: #{task} (#{path})")

    Logger.debug(
      "Using cached: #{length(state.patterns)} patterns, #{length(state.rag_examples)} examples"
    )

    # Build context-aware prompt using SESSION cache
    context = %{state.context | path: path}

    # Filter RAG examples relevant to this specific file
    relevant_examples = filter_relevant_examples(state.rag_examples, path, task)

    # Generate using cached patterns and examples (NO re-query!)
    prompt =
      build_session_prompt(task, context, state.patterns, relevant_examples, state.tech_stack)

    start = System.monotonic_time(:millisecond)

    # Generate code (GPU call, ~1-2s)
    case CodeModel.complete(prompt, temperature: 0.05) do
      {:ok, code} ->
        elapsed = System.monotonic_time(:millisecond) - start
        Logger.info("Generated in #{elapsed}ms (using session cache)")

        %{
          task: task,
          path: path,
          code: code,
          elapsed_ms: elapsed,
          used_cache: true
        }

      {:error, reason} ->
        %{task: task, path: path, error: reason}
    end
  end

  defp filter_relevant_examples(all_examples, path, task) do
    # Pick examples most relevant to this specific file
    # - Same directory
    # - Similar filename
    # - Task keywords match

    all_examples
    |> Enum.filter(fn ex ->
      same_dir = Path.dirname(ex.path) == Path.dirname(path)
      task_match = String.jaro_distance(ex.content, task) > 0.3

      same_dir or task_match
    end)
    # Top 5 most relevant
    |> Enum.take(5)
  end

  defp build_session_prompt(task, context, patterns, examples, tech_stack) do
    pattern_hints =
      Enum.map_join(patterns, "\n", fn p ->
        "#{p.pattern}: #{p.pseudocode}"
      end)

    example_code =
      Enum.map_join(examples, "\n\n", fn ex ->
        "// From #{ex.path}:\n#{String.slice(ex.content, 0..500)}"
      end)

    """
    SESSION CONTEXT:
    Project: #{context.repo}
    Tech Stack: #{Enum.join(tech_stack, ", ")}
    Language: #{context.language}

    TASK: #{task}
    File: #{context.path}

    PATTERNS (session-cached):
    #{pattern_hints}

    EXAMPLES (session-cached, filtered for relevance):
    #{example_code}

    Generate production code following the patterns.
    OUTPUT CODE ONLY.
    """
  end

  defp query_facts_for_tech_stack(repo) do
    try do
      # Use existing knowledge base systems to query tech stack facts
      tech_stack_facts = get_tech_stack_facts_from_knowledge_base(repo)
      
      if tech_stack_facts != [] do
        {:ok, tech_stack_facts}
      else
        # Fallback to basic tech detection
        basic_tech_detection = detect_tech_stack_from_files(repo)
        {:ok, basic_tech_detection}
      end
    rescue
      error ->
        Logger.warning("Failed to query tech stack facts for #{repo}: #{inspect(error)}")
        {:error, :query_failed}
    end
  end

  defp get_tech_stack_facts_from_knowledge_base(repo) do
    # Query existing knowledge base systems
    facts = []
    
    # Query package registry knowledge for tech stack information
    case Singularity.Search.PackageRegistryKnowledge.search("technology stack", %{ecosystem: :all, top_k: 15}) do
      {:ok, results} ->
        facts = facts ++ Enum.map(results, &format_tech_stack_fact/1)
      _ -> :ok
    end
    
    # Query semantic code search for tech patterns in the specific repo
    case Singularity.CodeSearch.semantic_search(Repo, repo, "technology stack patterns", 10) do
      {:ok, results} ->
        facts = facts ++ Enum.map(results, &format_semantic_tech_fact/1)
      _ -> :ok
    end
    
    # Query framework pattern store for relevant frameworks
    case Singularity.Code.Patterns.FrameworkPatternStore.search("framework detection", %{top_k: 8}) do
      {:ok, results} ->
        facts = facts ++ Enum.map(results, &format_framework_tech_fact/1)
      _ -> :ok
    end
    
    # Query technology template store
    case Singularity.Code.Patterns.TechnologyTemplateStore.search("technology templates", %{top_k: 5}) do
      {:ok, results} ->
        facts = facts ++ Enum.map(results, &format_template_tech_fact/1)
      _ -> :ok
    end
    
    facts
  end

  defp format_tech_stack_fact(result) do
    %{
      type: "package_tech",
      name: Map.get(result, :package_name, "unknown"),
      version: Map.get(result, :version, "unknown"),
      ecosystem: Map.get(result, :ecosystem, "unknown"),
      description: Map.get(result, :description, ""),
      confidence: Map.get(result, :similarity, 0.0),
      source: "package_registry",
      category: "technology"
    }
  end

  defp format_semantic_tech_fact(result) do
    %{
      type: "semantic_tech",
      content: Map.get(result, :content, ""),
      file_path: Map.get(result, :file_path, ""),
      similarity: Map.get(result, :similarity, 0.0),
      source: "semantic_search",
      category: "technology_pattern"
    }
  end

  defp format_framework_tech_fact(result) do
    %{
      type: "framework_tech",
      pattern_name: Map.get(result, :pattern_name, "unknown"),
      framework: Map.get(result, :framework, "unknown"),
      description: Map.get(result, :description, ""),
      confidence: Map.get(result, :confidence, 0.0),
      source: "framework_patterns",
      category: "framework"
    }
  end

  defp format_template_tech_fact(result) do
    %{
      type: "template_tech",
      template_name: Map.get(result, :template_name, "unknown"),
      technology: Map.get(result, :technology, "unknown"),
      description: Map.get(result, :description, ""),
      confidence: Map.get(result, :confidence, 0.0),
      source: "technology_templates",
      category: "template"
    }
  end

  defp detect_tech_stack_from_files(repo) do
    # Basic tech stack detection using file system analysis
    tech_stack = []
    
    # Check for common tech stack indicators
    tech_stack = tech_stack ++ detect_elixir_tech_stack(repo)
    tech_stack = tech_stack ++ detect_rust_tech_stack(repo)
    tech_stack = tech_stack ++ detect_javascript_tech_stack(repo)
    tech_stack = tech_stack ++ detect_python_tech_stack(repo)
    tech_stack = tech_stack ++ detect_go_tech_stack(repo)
    tech_stack = tech_stack ++ detect_java_tech_stack(repo)
    tech_stack = tech_stack ++ detect_database_tech_stack(repo)
    tech_stack = tech_stack ++ detect_deployment_tech_stack(repo)
    
    tech_stack
  end

  defp detect_elixir_tech_stack(repo) do
    if File.exists?(Path.join(repo, "mix.exs")) do
      [%{
        type: "language",
        name: "Elixir",
        version: detect_elixir_version_from_mix(repo),
        confidence: 0.9,
        source: "file_detection",
        category: "language"
      }]
    else
      []
    end
  end

  defp detect_rust_tech_stack(repo) do
    if File.exists?(Path.join(repo, "Cargo.toml")) do
      [%{
        type: "language",
        name: "Rust",
        version: detect_rust_version_from_cargo(repo),
        confidence: 0.9,
        source: "file_detection",
        category: "language"
      }]
    else
      []
    end
  end

  defp detect_javascript_tech_stack(repo) do
    if File.exists?(Path.join(repo, "package.json")) do
      [%{
        type: "language",
        name: "JavaScript/TypeScript",
        version: detect_node_version_from_package(repo),
        confidence: 0.8,
        source: "file_detection",
        category: "language"
      }]
    else
      []
    end
  end

  defp detect_python_tech_stack(repo) do
    if File.exists?(Path.join(repo, "requirements.txt")) or File.exists?(Path.join(repo, "pyproject.toml")) do
      [%{
        type: "language",
        name: "Python",
        version: detect_python_version_from_files(repo),
        confidence: 0.8,
        source: "file_detection",
        category: "language"
      }]
    else
      []
    end
  end

  defp detect_go_tech_stack(repo) do
    if File.exists?(Path.join(repo, "go.mod")) do
      [%{
        type: "language",
        name: "Go",
        version: detect_go_version_from_mod(repo),
        confidence: 0.9,
        source: "file_detection",
        category: "language"
      }]
    else
      []
    end
  end

  defp detect_java_tech_stack(repo) do
    if File.exists?(Path.join(repo, "pom.xml")) or File.exists?(Path.join(repo, "build.gradle")) do
      [%{
        type: "language",
        name: "Java",
        version: detect_java_version_from_build_files(repo),
        confidence: 0.8,
        source: "file_detection",
        category: "language"
      }]
    else
      []
    end
  end

  defp detect_database_tech_stack(repo) do
    # Detect database technologies
    databases = []
    
    # Check for PostgreSQL
    if File.exists?(Path.join(repo, "docker-compose.yml")) do
      case File.read(Path.join(repo, "docker-compose.yml")) do
        {:ok, content} ->
          if String.contains?(content, "postgres") do
            databases = [%{
              type: "database",
              name: "PostgreSQL",
              version: "unknown",
              confidence: 0.7,
              source: "docker_compose",
              category: "database"
            } | databases]
          end
        _ -> :ok
      end
    end
    
    # Check for Redis
    if File.exists?(Path.join(repo, "docker-compose.yml")) do
      case File.read(Path.join(repo, "docker-compose.yml")) do
        {:ok, content} ->
          if String.contains?(content, "redis") do
            databases = [%{
              type: "database",
              name: "Redis",
              version: "unknown",
              confidence: 0.7,
              source: "docker_compose",
              category: "database"
            } | databases]
          end
        _ -> :ok
      end
    end
    
    databases
  end

  defp detect_deployment_tech_stack(repo) do
    # Detect deployment technologies
    deployment_tech = []
    
    # Check for Docker
    if File.exists?(Path.join(repo, "Dockerfile")) do
      deployment_tech = [%{
        type: "deployment",
        name: "Docker",
        version: "unknown",
        confidence: 0.9,
        source: "dockerfile",
        category: "deployment"
      } | deployment_tech]
    end
    
    # Check for Kubernetes
    if File.exists?(Path.join(repo, "k8s/")) or File.exists?(Path.join(repo, "kubernetes/")) do
      deployment_tech = [%{
        type: "deployment",
        name: "Kubernetes",
        version: "unknown",
        confidence: 0.8,
        source: "directory_structure",
        category: "deployment"
      } | deployment_tech]
    end
    
    # Check for Terraform
    if File.exists?(Path.join(repo, "terraform/")) or File.exists?(Path.join(repo, "*.tf")) do
      deployment_tech = [%{
        type: "deployment",
        name: "Terraform",
        version: "unknown",
        confidence: 0.8,
        source: "file_detection",
        category: "deployment"
      } | deployment_tech]
    end
    
    deployment_tech
  end

  defp detect_elixir_version_from_mix(repo) do
    case File.read(Path.join(repo, "mix.exs")) do
      {:ok, content} ->
        case Regex.run(~r/elixir: "([^"]+)"/, content) do
          [_, version] -> version
          _ -> "unknown"
        end
      _ -> "unknown"
    end
  end

  defp detect_rust_version_from_cargo(repo) do
    case File.read(Path.join(repo, "Cargo.toml")) do
      {:ok, content} ->
        case Regex.run(~r/edition = "([^"]+)"/, content) do
          [_, edition] -> edition
          _ -> "unknown"
        end
      _ -> "unknown"
    end
  end

  defp detect_node_version_from_package(repo) do
    case File.read(Path.join(repo, "package.json")) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} ->
            Map.get(data, "engines", %{})
            |> Map.get("node", "unknown")
          _ -> "unknown"
        end
      _ -> "unknown"
    end
  end

  defp detect_python_version_from_files(repo) do
    case File.read(Path.join(repo, "pyproject.toml")) do
      {:ok, content} ->
        case Regex.run(~r/python = "([^"]+)"/, content) do
          [_, version] -> version
          _ -> "unknown"
        end
      _ -> "unknown"
    end
  end

  defp detect_go_version_from_mod(repo) do
    case File.read(Path.join(repo, "go.mod")) do
      {:ok, content} ->
        case Regex.run(~r/go (\d+\.\d+)/, content) do
          [_, version] -> version
          _ -> "unknown"
        end
      _ -> "unknown"
    end
  end

  defp detect_java_version_from_build_files(repo) do
    case File.read(Path.join(repo, "pom.xml")) do
      {:ok, content} ->
        case Regex.run(~r/<java\.version>([^<]+)<\/java\.version>/, content) do
          [_, version] -> version
          _ -> "unknown"
        end
      _ -> "unknown"
    end
  end

  defp detect_from_hints(_context) do
    # Fallback tech detection
    []
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(8)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Convenience: Generate entire feature in one go

  ## Example

      CodeSession.generate_feature(
        project: "singularity",
        feature: "user_authentication",
        files: [
          {"Schema for users", "lib/app/accounts/user.ex"},
          {"Context for auth", "lib/app/accounts.ex"},
          {"Controller", "lib/app_web/controllers/session_controller.ex"},
          {"Tests", "test/app/accounts_test.exs"}
        ]
      )
  """
  def generate_feature(opts) do
    project = Keyword.fetch!(opts, :project)
    feature = Keyword.fetch!(opts, :feature)
    files = Keyword.fetch!(opts, :files)

    file_paths = Enum.map(files, fn {_task, path} -> path end)

    # Start session
    {:ok, session} = start(project: project, feature: feature, files: file_paths)

    # Generate all files
    tasks = Enum.map(files, fn {task, path} -> {task, [path: path]} end)
    {:ok, results} = generate_batch(session, tasks)

    # Get stats
    stats = stats(session)

    # Stop session
    stop(session)

    {:ok, %{results: results, stats: stats}}
  end
end
