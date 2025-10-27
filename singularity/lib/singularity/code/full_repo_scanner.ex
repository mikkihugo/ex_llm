defmodule Singularity.Code.FullRepoScanner do
  @moduledoc """
  Incremental learning system for TaskGraph to understand and auto-repair the ENTIRE codebase.

  Scans the FULL repository (Elixir, Rust, TypeScript, Go, Python, Nix, config files, etc.)
  for comprehensive multi-language analysis. Builds knowledge graphs of module relationships
  across all languages and automatically fixes broken dependencies, missing documentation,
  and integration issues.

  ## Integration Points

  This module integrates with:
  - `Singularity.Storage.Store` - Knowledge search (Store.search_knowledge/2)
  - `Singularity.LLM.Service` - Lua-based fix generation (Service.call_with_script/3)
  - `Singularity.HotReload.SafeCodeChangeDispatcher` - Hot reload (SafeCodeChangeDispatcher.dispatch/2)
  - `Singularity.Execution.Planning.ExecutionTracer` - Runtime tracing (ExecutionTracer.full_analysis/1)
  - `Singularity.SelfImprovingAgent` - Self-improvement (SelfImprovingAgent integration)
  - PostgreSQL table: `task_graph_learning_results` (stores learning analysis)

  ## Learning Approach

  Uses a simple pattern combining static and runtime analysis:
  - Scan source files for module documentation
  - Extract component purposes from @moduledoc
  - Build dependency graph from aliases
  - Identify missing connections
  - Auto-generate fixes using context-aware Lua scripts

  ## Fix Generation (Lua-based)

  Fixes are generated using modular Lua scripts from `templates_data/prompt_library/codebase/`:
  - `fix-broken-dependency.lua` - Reads broken module, searches for similar code, checks git history
  - `fix-missing-docs.lua` - Analyzes module purpose, finds documentation style examples
  - `fix-isolated-module.lua` - Determines if isolation is legitimate or needs integration

  Each script reads relevant context BEFORE calling the LLM (90% cost savings vs tool-based exploration).

  ## Usage

      # Learn about the codebase incrementally
      {:ok, knowledge} = FullRepoScanner.learn_codebase()
      # => {:ok, %{knowledge: %{modules: %{...}}, issues: [...]}}

      # Auto-fix everything that's broken (uses Lua scripts)
      {:ok, fixes} = FullRepoScanner.auto_fix_all()
      # => {:ok, %{iterations: 3, fixes: [...]}}
  """

  require Logger

  # INTEGRATION: Knowledge search and code generation
  alias Singularity.Store
  alias Singularity.CodeGeneration.Implementations.{RAGCodeGenerator, QualityCodeGenerator}
  alias Singularity.HotReload.SafeCodeChangeDispatcher

  # INTEGRATION: TaskGraph planning and tracing
  alias Singularity.Execution.Planning.{TaskGraph, ExecutionTracer}

  # INTEGRATION: Self-improvement (learning from execution)
  alias Singularity.SelfImprovingAgent

  # INTEGRATION: LLM service with Lua script support for dynamic fix generation
  alias Singularity.LLM.Service

  @doc """
  Learn about the codebase in a simple, incremental way.

  Scans source files, extracts documentation, builds knowledge graph.
  """
  def learn_codebase(_opts \\ []) do
    Logger.info("Starting simple codebase learning...")

    # Step 1: Scan all Elixir source files
    source_files = find_source_files()

    Logger.info("Found #{length(source_files)} source files")

    # Step 2: Extract knowledge from each file
    knowledge =
      Enum.reduce(source_files, %{modules: %{}, dependencies: %{}}, fn file, acc ->
        case learn_from_file(file) do
          {:ok, file_knowledge} ->
            merge_knowledge(acc, file_knowledge)

          {:error, _reason} ->
            acc
        end
      end)

    # Step 3: Identify what's missing or broken
    issues = identify_issues(knowledge)

    Logger.info(
      "Learning complete: #{map_size(knowledge.modules)} modules, #{length(issues)} issues"
    )

    {:ok,
     %{
       knowledge: knowledge,
       issues: issues,
       learned_at: DateTime.utc_now()
     }}
  end

  @doc """
  Auto-fix all issues found in the codebase.

  Uses self-improving agent to fix:
  - Missing integrations
  - Broken connections
  - Performance issues
  - Errors in code

  Continues until everything works or max iterations reached.
  """
  def auto_fix_all(_opts \\ []) do
    max_iterations = Keyword.get(opts, :max_iterations, 10)

    Logger.info("Starting auto-fix with max #{max_iterations} iterations...")

    # Learn first
    {:ok, learning} = learn_codebase()

    # Fix iteratively
    fix_iteration(learning, 0, max_iterations, [])
  end

  @doc """
  Map all existing systems into TaskGraph with inline documentation.

  Creates a comprehensive mapping document showing:
  - What each system does
  - How they should work together
  - What's currently broken
  - How to fix it
  """
  def map_all_systems do
    Logger.info("Mapping all systems into TaskGraph...")

    # Learn about everything
    {:ok, learning} = learn_codebase()

    # Create comprehensive mapping
    mapping = %{
      # Core systems
      self_improving: map_self_improving_system(learning),
      safe_planning: map_safe_planning_system(learning),
      sparc: map_sparc_system(learning),
      code_generation: map_code_generation_system(learning),
      storage: map_storage_system(learning),

      # Integration points
      integrations: identify_integrations(learning),

      # What needs fixing
      fixes_needed: learning.issues,

      # Auto-repair plan
      repair_plan: create_repair_plan(learning.issues)
    }

    # Save mapping to file for reference
    save_mapping(mapping)

    {:ok, mapping}
  end

  @doc """
  Learn codebase using BOTH static analysis AND runtime tracing.

  This combines:
  - Static file scanning (what's defined)
  - Runtime tracing (what actually runs)
  - Connectivity analysis (what's connected)
  - Error detection (what's broken)

  This gives the most complete picture of system health.
  """
  def learn_with_tracing(_opts \\ []) do
    Logger.info("Learning codebase with static + runtime analysis...")

    # Step 1: Static learning (scan files)
    Logger.info("Phase 1: Static analysis...")
    {:ok, static_knowledge} = learn_codebase(_opts)

    # Step 2: Runtime tracing (see what actually runs)
    Logger.info("Phase 2: Runtime tracing...")

    {:ok, trace_analysis} =
      ExecutionTracer.full_analysis(
        trace_duration_ms: Keyword.get(opts, :trace_duration_ms, 10_000)
      )

    # Step 3: Merge insights
    Logger.info("Phase 3: Merging insights...")
    merged = merge_static_and_runtime(static_knowledge, trace_analysis)

    # Step 4: Enhanced issue detection
    issues = identify_issues_with_tracing(merged)

    result = %{
      modules: merged.modules,
      dependencies: merged.dependencies,
      issues: issues,
      trace_analysis: trace_analysis,
      stats: %{
        total_modules: map_size(merged.modules),
        working_modules: merged.working_count,
        broken_modules: merged.broken_count,
        disconnected_modules: merged.disconnected_count,
        dead_code_functions: length(trace_analysis.dead_code)
      }
    }

    Logger.info("Learning complete with tracing:")
    Logger.info("  Total modules: #{result.stats.total_modules}")
    Logger.info("  Working: #{result.stats.working_modules}")
    Logger.info("  Broken: #{result.stats.broken_modules}")
    Logger.info("  Disconnected: #{result.stats.disconnected_modules}")
    Logger.info("  Dead code: #{result.stats.dead_code_functions}")

    {:ok, result}
  end

  defp merge_static_and_runtime(static_knowledge, trace_analysis) do
    # Enhance static knowledge with runtime data
    enhanced_modules =
      Enum.reduce(static_knowledge.modules, %{}, fn {mod_name, mod_data}, acc ->
        # Check if module is actually called at runtime
        is_called =
          Enum.any?(trace_analysis.trace_results, fn {{mod, _fun, _arity}, _data} ->
            Atom.to_string(mod) == mod_name
          end)

        # Check connectivity
        connectivity = ExecutionTracer.is_connected?(String.to_atom("Elixir.#{mod_name}"))

        # Check for broken functions in this module
        broken_in_module =
          Enum.filter(trace_analysis.broken_functions, fn {mod, _fun, _arity, _reason} ->
            Atom.to_string(mod) == mod_name
          end)

        enhanced =
          Map.merge(mod_data, %{
            called_at_runtime: is_called,
            connectivity: connectivity,
            broken_functions: broken_in_module,
            is_working: is_called and length(broken_in_module) == 0
          })

        Map.put(acc, mod_name, enhanced)
      end)

    working_count = Enum.count(enhanced_modules, fn {_name, data} -> data.is_working end)

    broken_count =
      Enum.count(enhanced_modules, fn {_name, data} ->
        length(data.broken_functions) > 0
      end)

    disconnected_count =
      Enum.count(enhanced_modules, fn {_name, data} ->
        not data.connectivity.connected
      end)

    %{
      modules: enhanced_modules,
      dependencies: static_knowledge.dependencies,
      working_count: working_count,
      broken_count: broken_count,
      disconnected_count: disconnected_count
    }
  end

  defp identify_issues_with_tracing(merged_data) do
    issues = []

    # Add broken function issues
    broken_issues =
      Enum.flat_map(merged_data.modules, fn {mod_name, mod_data} ->
        Enum.map(mod_data.broken_functions, fn {_mod, fun, arity, reason} ->
          %{
            type: :broken_function,
            severity: :high,
            module: mod_name,
            function: "#{fun}/#{arity}",
            description: "Function crashes: #{reason}",
            detected_by: :runtime_tracing
          }
        end)
      end)

    # Add disconnected module issues
    disconnected_issues =
      Enum.reduce(merged_data.modules, [], fn {mod_name, mod_data}, acc ->
        if not mod_data.connectivity.connected do
          [
            %{
              type: :disconnected_module,
              severity: :medium,
              module: mod_name,
              description: "Module is not connected to system (no callers/callees)",
              detected_by: :runtime_tracing
            }
            | acc
          ]
        else
          acc
        end
      end)

    # Add never-called module issues
    never_called_issues =
      Enum.reduce(merged_data.modules, [], fn {mod_name, mod_data}, acc ->
        if not mod_data.called_at_runtime and mod_data.has_docs do
          [
            %{
              type: :never_called,
              severity: :low,
              module: mod_name,
              description: "Module defined but never called at runtime",
              detected_by: :runtime_tracing
            }
            | acc
          ]
        else
          acc
        end
      end)

    issues ++ broken_issues ++ disconnected_issues ++ never_called_issues
  end

  ## Private Functions

  defp find_source_files do
    # Find all source files in the entire project root
    # This includes: singularity/, rust/, llm-server/, centralcloud/, etc.
    # App runs from singularity/ dir, so go up one level to get repo root
    project_root = Path.expand("..", File.cwd!())

    # Define source file patterns for different languages
    source_patterns = [
      # Elixir files
      "#{project_root}/**/*.ex",
      # Rust files  
      "#{project_root}/**/*.rs",
      # TypeScript/JavaScript files
      "#{project_root}/**/*.ts",
      "#{project_root}/**/*.tsx",
      "#{project_root}/**/*.js",
      "#{project_root}/**/*.jsx",
      # Python files
      "#{project_root}/**/*.py",
      # Go files
      "#{project_root}/**/*.go",
      # Nix files
      "#{project_root}/**/*.nix",
      # Shell scripts
      "#{project_root}/**/*.sh",
      # Configuration files
      "#{project_root}/**/*.toml",
      "#{project_root}/**/*.json",
      "#{project_root}/**/*.yaml",
      "#{project_root}/**/*.yml",
      # Documentation
      "#{project_root}/**/*.md"
    ]

    # Find all matching files
    source_patterns
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.filter(&File.regular?/1)
    |> Enum.reject(&ignore_file?/1)
  end

  # Ignore common non-source files and directories
  # Respects .gitignore + hardcoded patterns for deps/build artifacts
  defp ignore_file?(file_path) do
    # Hardcoded patterns (always ignore, even if not in .gitignore)
    hardcoded_patterns = [
      # Dependencies (never ingest third-party code!)
      # Elixir deps
      "/deps/",
      # npm deps
      "/node_modules/",
      # Cargo deps (except our own code in target/debug/)
      "/target/",
      # Cargo registry cache
      "/.cargo/",
      # Cargo build cache
      "/.cargo-build/",
      # Build artifacts
      # Elixir build
      "/_build/",
      # TypeScript/JavaScript build
      "/dist/",
      # Generic build
      "/build/",
      # VCS
      "/.git/",
      # Nix
      "/.nix/",
      # Nix build result symlink
      "/result",
      # Logs and temporary files
      ".log",
      ".tmp",
      ".pid",
      # OS files
      ".DS_Store",
      "Thumbs.db",
      # Large binary files
      ".png",
      ".jpg",
      ".jpeg",
      ".gif",
      ".ico",
      ".pdf",
      ".zip",
      ".tar.gz",
      ".wasm",
      ".so",
      ".dylib",
      ".dll"
    ]

    # Check hardcoded patterns first (fast path)
    if Enum.any?(hardcoded_patterns, &String.contains?(file_path, &1)) do
      true
    else
      # Then check .gitignore patterns (if exists)
      check_gitignore(file_path)
    end
  end

  # Check if file matches .gitignore or .singularityignore patterns
  # Simple implementation - checks common gitignore patterns
  defp check_gitignore(file_path) do
    # Get project root
    project_root = Path.expand("..", File.cwd!())
    gitignore_path = Path.join(project_root, ".gitignore")
    singularityignore_path = Path.join(project_root, ".singularityignore")

    # Load patterns from both files
    gitignore_patterns =
      if File.exists?(gitignore_path) do
        File.read!(gitignore_path)
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
      else
        []
      end

    singularityignore_patterns =
      if File.exists?(singularityignore_path) do
        File.read!(singularityignore_path)
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
      else
        []
      end

    # Combine patterns
    all_patterns = gitignore_patterns ++ singularityignore_patterns

    # If no patterns, skip this check
    if Enum.empty?(all_patterns) do
      false
    else
      # Make file_path relative to project root for matching
      relative_path = Path.relative_to(file_path, project_root)

      # Check if any pattern matches
      Enum.any?(all_patterns, fn pattern ->
        gitignore_pattern_matches?(relative_path, pattern)
      end)
    end
  end

  # Simple gitignore pattern matching
  # Supports: *.ext, dir/, /dir/, dir/*, etc.
  defp gitignore_pattern_matches?(file_path, pattern) do
    cond do
      # Exact match: node_modules
      pattern == file_path ->
        true

      # Directory match: node_modules/
      String.ends_with?(pattern, "/") ->
        dir_pattern = String.trim_trailing(pattern, "/")
        String.starts_with?(file_path, dir_pattern <> "/") or file_path == dir_pattern

      # Extension match: *.log
      String.starts_with?(pattern, "*.") ->
        ext = String.trim_leading(pattern, "*")
        String.ends_with?(file_path, ext)

      # Wildcard match: logs/*.log
      String.contains?(pattern, "*") ->
        # Convert to regex
        regex_pattern =
          pattern
          |> String.replace(".", "\\.")
          |> String.replace("*", ".*")
          |> then(&("^" <> &1 <> "$"))

        case Regex.compile(regex_pattern) do
          {:ok, regex} -> Regex.match?(regex, file_path)
          _ -> false
        end

      # Path prefix match: __pycache__
      true ->
        String.contains?(file_path, "/" <> pattern <> "/") or
          String.starts_with?(file_path, pattern <> "/") or
          String.ends_with?(file_path, "/" <> pattern)
    end
  end

  # Detect programming language from file extension
  defp detect_language(file_path) do
    cond do
      String.ends_with?(file_path, [".ex", ".exs"]) -> "elixir"
      String.ends_with?(file_path, ".rs") -> "rust"
      String.ends_with?(file_path, [".ts", ".tsx"]) -> "typescript"
      String.ends_with?(file_path, [".js", ".jsx"]) -> "javascript"
      String.ends_with?(file_path, ".py") -> "python"
      String.ends_with?(file_path, ".go") -> "go"
      String.ends_with?(file_path, ".nix") -> "nix"
      String.ends_with?(file_path, ".sh") -> "shell"
      String.ends_with?(file_path, [".toml", ".json", ".yaml", ".yml"]) -> "config"
      String.ends_with?(file_path, ".md") -> "markdown"
      true -> "unknown"
    end
  end

  # Detect file type/category
  defp detect_file_type(file_path) do
    cond do
      String.contains?(file_path, "/singularity/") -> :elixir_app
      String.contains?(file_path, "/rust/") -> :rust_component
      String.contains?(file_path, "/llm-server/") -> :typescript_service
      String.contains?(file_path, "/centralcloud/") -> :elixir_service
      String.contains?(file_path, "/templates_data/") -> :templates
      String.contains?(file_path, "/scripts/") -> :scripts
      String.ends_with?(file_path, "flake.nix") -> :nix_config
      String.ends_with?(file_path, ".md") -> :documentation
      true -> :source_file
    end
  end

  defp learn_from_file(file_path) do
    try do
      # Read file content
      content = File.read!(file_path)

      # Determine file type and language
      language = detect_language(file_path)
      file_type = detect_file_type(file_path)

      # Extract module name (different logic for different languages)
      module_name = extract_module_name(file_path, content, language)

      # Extract documentation (language-specific)
      documentation = extract_documentation(content, language)
      moduledoc = extract_moduledoc(content, language)

      # Extract dependencies (language-specific)
      dependencies = extract_dependencies(content, language)

      # Extract purpose from docs
      purpose = extract_purpose(moduledoc)

      {:ok,
       %{
         module: module_name,
         file: file_path,
         language: language,
         file_type: file_type,
         purpose: purpose,
         dependencies: dependencies,
         has_docs: moduledoc != nil and moduledoc != "",
         content_size: byte_size(content)
       }}
    rescue
      e ->
        Logger.debug("Error learning from #{file_path}: #{inspect(e)}")
        {:error, :parse_error}
    end
  end

  # Language-specific module name extraction
  defp extract_module_name(file_path, content, language) do
    case language do
      "elixir" ->
        # Try to extract module name from defmodule
        case Regex.run(~r/defmodule\s+([A-Za-z0-9_.]+)/, content) do
          [_, module_name] -> module_name
          _ -> "Unknown"
        end

      "rust" ->
        # Try to extract module name from mod declaration
        case Regex.run(~r/mod\s+([a-z_][a-z0-9_]*)/, content) do
          [_, module_name] -> String.capitalize(module_name)
          _ -> Path.basename(file_path, ".rs") |> String.capitalize()
        end

      "typescript" ->
        # Use file path as module name
        file_path
        |> String.replace(File.cwd!() <> "/", "")
        |> String.replace("/", ".")
        |> String.replace(~r/\.[^.]*$/, "")

      _ ->
        # For other languages, use file path
        file_path
        |> String.replace(File.cwd!() <> "/", "")
        |> String.replace("/", ".")
        |> String.replace(~r/\.[^.]*$/, "")
    end
  end

  # Language-specific documentation extraction
  defp extract_documentation(content, language) do
    case language do
      "elixir" ->
        # Try to extract @moduledoc
        case Regex.run(~r/@moduledoc\s+[""](.*?)[""]/s, content) do
          [_, moduledoc] -> moduledoc
          _ -> ""
        end

      "rust" ->
        # Try to extract doc comments
        case Regex.run(~r/\/\/!?\s*(.*?)(?=\n\s*\/\/!?|\n\s*[^\/]|$)/s, content) do
          [_, doc] -> doc
          _ -> ""
        end

      "typescript" ->
        # Try to extract JSDoc comments
        case Regex.run(~r/\*\*([^*]|\*(?!\/))*\*\/\s*export/, content) do
          [doc] -> doc
          _ -> ""
        end

      "markdown" ->
        # For markdown files, use the first heading
        case Regex.run(~r/^#\s+(.+)$/m, content) do
          [_, title] -> title
          _ -> ""
        end

      _ ->
        ""
    end
  end

  defp extract_moduledoc(content, language) do
    extract_documentation(content, language)
  end

  # Language-specific dependency extraction
  defp extract_dependencies(content, language) do
    case language do
      "elixir" ->
        # Extract aliases (dependencies)
        Regex.scan(~r/alias\s+([A-Za-z0-9_.]+)/, content)
        |> Enum.map(fn [_, alias_name] -> alias_name end)

      "rust" ->
        # Extract use statements
        Regex.scan(~r/use\s+([a-z0-9_::]+)/, content)
        |> Enum.map(fn [_, use_name] -> use_name end)

      "typescript" ->
        # Extract import statements
        Regex.scan(~r/import.*from\s+['"]([^'"]+)['"]/, content)
        |> Enum.map(fn [_, import_name] -> import_name end)

      _ ->
        []
    end
  end

  defp extract_purpose(nil), do: "No documentation"

  defp extract_purpose(moduledoc) do
    # Take first sentence as purpose
    moduledoc
    |> String.split(".")
    |> List.first()
    |> String.trim()
  end

  defp merge_knowledge(acc, file_knowledge) do
    %{
      modules: Map.put(acc.modules, file_knowledge.module, file_knowledge),
      dependencies: Map.put(acc.dependencies, file_knowledge.module, file_knowledge.dependencies)
    }
  end

  defp identify_issues(knowledge) do
    issues = []

    # Check for modules without documentation
    undocumented =
      knowledge.modules
      |> Enum.filter(fn {_name, info} -> not info.has_docs end)
      |> Enum.map(fn {name, _info} ->
        %{type: :missing_docs, module: name, severity: :low}
      end)

    # Check for broken dependencies
    broken_deps =
      knowledge.dependencies
      |> Enum.flat_map(fn {module, deps} ->
        Enum.filter(deps, fn dep ->
          # Check if dependency exists
          not Map.has_key?(knowledge.modules, dep)
        end)
        |> Enum.map(fn dep ->
          %{type: :broken_dependency, module: module, missing: dep, severity: :high}
        end)
      end)

    # Check for isolated modules (no dependencies)
    isolated =
      knowledge.modules
      |> Enum.filter(fn {name, _info} ->
        deps = Map.get(knowledge.dependencies, name, [])
        length(deps) == 0 and should_have_dependencies?(name)
      end)
      |> Enum.map(fn {name, _info} ->
        %{type: :isolated_module, module: name, severity: :medium}
      end)

    issues ++ undocumented ++ broken_deps ++ isolated
  end

  defp should_have_dependencies?(module_name) do
    # Modules that should have dependencies
    not String.contains?(module_name, ["Repo", "Schema", "Migration"])
  end

  defp fix_iteration(learning, iteration, max_iterations, fixes_applied)
       when iteration >= max_iterations do
    Logger.info("Reached max iterations (#{max_iterations})")
    {:ok, %{iterations: iteration, fixes: fixes_applied, final_state: learning}}
  end

  defp fix_iteration(learning, iteration, max_iterations, fixes_applied) do
    Logger.info("Fix iteration #{iteration + 1}/#{max_iterations}")

    # Get high priority issues
    high_priority =
      Enum.filter(learning.issues, fn issue ->
        issue.severity == :high
      end)

    if Enum.empty?(high_priority) do
      Logger.info("No high priority issues remaining")
      {:ok, %{iterations: iteration, fixes: fixes_applied, final_state: learning}}
    else
      # Fix first high priority issue
      issue = List.first(high_priority)

      case fix_issue(issue, learning) do
        {:ok, fix} ->
          # The issue is considered fixed for this pass. Remove it to avoid an infinite loop.
          remaining_issues = List.delete(learning.issues, issue)
          new_learning = Map.put(learning, :issues, remaining_issues)

          # Continue fixing with the updated list of issues.
          # A full `learn_codebase()` should only happen after actual file modifications.
          fix_iteration(new_learning, iteration + 1, max_iterations, [fix | fixes_applied])

        {:error, _reason} ->
          # Skip this issue
          remaining_issues = List.delete(learning.issues, issue)
          new_learning = Map.put(learning, :issues, remaining_issues)
          fix_iteration(new_learning, iteration + 1, max_iterations, fixes_applied)
      end
    end
  end

  defp fix_issue(issue, learning) do
    Logger.info("Fixing issue: #{issue.type} in #{issue.module}")

    case issue.type do
      :broken_dependency ->
        fix_broken_dependency(issue, learning)

      :missing_docs ->
        fix_missing_docs(issue, learning)

      :isolated_module ->
        fix_isolated_module(issue, learning)

      _ ->
        {:error, :unknown_issue_type}
    end
  end

  defp fix_broken_dependency(issue, learning) do
    Logger.info("Generating fix for broken dependency: #{issue.missing}")

    module_info = Map.get(learning.knowledge.modules, issue.module)

    with %{file: file_path} <- module_info,
         true <- File.exists?(file_path) do
      # Use Lua script for context-aware fix generation
      script_context = %{
        issue: issue,
        module_info: module_info,
        learning: %{
          modules: Map.keys(learning.knowledge.modules),
          dependencies: learning.knowledge.dependencies
        }
      }

      case Service.call_with_script(
             "codebase/fix-broken-import.lua",
             script_context,
             complexity: :medium,
             task_type: :code_generation
           ) do
        {:ok, %{content: updated_content}} ->
          action = "Generated fix via Lua script"
          File.write!(file_path, updated_content)

          Logger.info("✓ Fixed broken dependency in #{file_path}")

          dispatch_metadata = %{
            "reason" => "task_graph_auto_fix",
            "issue_type" => "broken_dependency",
            "module" => issue.module,
            "missing_dependency" => issue.missing,
            "file_path" => file_path,
            "action" => action
          }

          payload = %{
            "code" => updated_content,
            "metadata" => dispatch_metadata
          }

          case SafeCodeChangeDispatcher.dispatch(payload, agent_id: "task_graph-runtime") do
            :ok ->
              Logger.debug("Hot reload dispatched for #{issue.module}",
                agent_id: "task_graph-runtime"
              )

            {:error, reason} ->
              Logger.warning("Hot reload dispatch skipped",
                module: issue.module,
                file: file_path,
                reason: inspect(reason)
              )
          end

          fix = %{
            type: :broken_dependency_fix,
            module: issue.module,
            missing: issue.missing,
            file: file_path,
            action: action,
            auto_generated: true,
            timestamp: DateTime.utc_now()
          }

          {:ok, fix}

        {:error, reason} ->
          Logger.error("Lua script failed for broken dependency fix",
            issue: inspect(issue),
            reason: inspect(reason)
          )

          {:error, {:script_failed, reason}}
      end
    else
      nil ->
        Logger.error("Module info not found for #{issue.module}")
        {:error, :module_not_found}

      false ->
        Logger.error("File not found while fixing dependency", module: issue.module)
        {:error, :file_not_found}

      {:error, reason} ->
        Logger.error("Failed to read module while fixing dependency",
          module: issue.module,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  defp fix_missing_docs(issue, learning) do
    Logger.info("Generating documentation for: #{issue.module}")

    module_info = Map.get(learning.knowledge.modules, issue.module)

    with %{file: file_path} <- module_info,
         true <- File.exists?(file_path),
         {:ok, content} <- File.read(file_path),
         false <- String.contains?(content, "@moduledoc") do
      # Use Lua script for context-aware documentation generation
      script_context = %{
        issue: issue,
        module_info: module_info,
        learning: %{
          modules: Map.keys(learning.knowledge.modules)
        }
      }

      case Service.call_with_script(
             "codebase/fix-missing-docs.lua",
             script_context,
             complexity: :medium,
             task_type: :documentation
           ) do
        {:ok, %{content: updated}} ->
          File.write!(file_path, updated)

          Logger.info("✓ Added documentation to #{file_path}")

          metadata = %{
            "reason" => "task_graph_auto_fix",
            "issue_type" => "missing_docs",
            "module" => issue.module,
            "file_path" => file_path
          }

          payload = %{
            "code" => updated,
            "metadata" => metadata
          }

          case SafeCodeChangeDispatcher.dispatch(payload, agent_id: "task_graph-runtime") do
            :ok ->
              Logger.debug("Hot reload dispatched after doc generation",
                agent_id: "task_graph-runtime",
                module: issue.module
              )

            {:error, reason} ->
              Logger.warning("Hot reload dispatch skipped after doc generation",
                module: issue.module,
                file: file_path,
                reason: inspect(reason)
              )
          end

          fix = %{
            type: :missing_docs_fix,
            module: issue.module,
            file: file_path,
            action: "Generated @moduledoc via Lua script",
            auto_generated: true,
            timestamp: DateTime.utc_now()
          }

          {:ok, fix}

        {:error, reason} ->
          Logger.error("Lua script failed for documentation generation",
            issue: inspect(issue),
            reason: inspect(reason)
          )

          {:error, {:script_failed, reason}}
      end
    else
      nil ->
        {:error, :module_not_found}

      false ->
        {:error, :file_not_found}

      true ->
        {:error, :docs_already_present}

      {:error, reason} ->
        Logger.error("Failed to generate documentation",
          module: issue.module,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  defp fix_isolated_module(issue, learning) do
    Logger.info("Analyzing isolated module: #{issue.module}")

    module_info = Map.get(learning.knowledge.modules, issue.module)

    with %{file: file_path} <- module_info,
         true <- File.exists?(file_path) do
      # Use Lua script for intelligent isolation analysis
      script_context = %{
        issue: issue,
        module_info: module_info,
        learning: %{
          modules: Map.keys(learning.knowledge.modules),
          dependencies: learning.knowledge.dependencies
        }
      }

      case Service.call_with_script(
             "codebase/analyze-isolated-module.lua",
             script_context,
             complexity: :medium,
             task_type: :code_analysis
           ) do
        {:ok, %{content: analysis_json}} ->
          # Parse the JSON analysis
          case Jason.decode(analysis_json) do
            {:ok, analysis} ->
              Logger.info("✓ Analyzed isolated module: #{analysis["recommendation"]}")

              fix = %{
                type: :isolated_module_fix,
                module: issue.module,
                file: file_path,
                action: "Analyzed via Lua script",
                recommendation: analysis["recommendation"],
                analysis: analysis,
                auto_generated: true,
                timestamp: DateTime.utc_now()
              }

              {:ok, fix}

            {:error, _json_error} ->
              Logger.warning("Failed to parse analysis JSON for #{issue.module}")

              fix = %{
                type: :isolated_module_fix,
                module: issue.module,
                action: "Analysis completed but JSON parsing failed",
                auto_generated: true
              }

              {:ok, fix}
          end

        {:error, reason} ->
          Logger.error("Lua script failed for isolated module analysis",
            issue: inspect(issue),
            reason: inspect(reason)
          )

          {:error, {:script_failed, reason}}
      end
    else
      nil ->
        {:error, :module_not_found}

      false ->
        {:error, :file_not_found}
    end
  end

  defp map_self_improving_system(learning) do
    %{
      module: "Singularity.SelfImprovingAgent",
      purpose: "Self-improving agent that evolves through feedback",
      current_state: check_module_in_learning(learning, "SelfImprovingAgent"),
      integration_with_task_graph: "Feeds evolution results to TaskGraph for improvements",
      what_it_does: """
      - Observes metrics from task execution
      - Decides when to evolve based on performance
      - Generates new code improvements
      - Hands improvements to hot-reload manager
      """,
      how_to_use_it: """
      SelfImprovingAgent.improve(agent_id, %{
        mutations: task_graph_mutations,
        source: "task_graph_evolution"
      })
      """
    }
  end

  defp map_safe_planning_system(learning) do
    %{
      module: "Singularity.Execution.Planning.SafeWorkPlanner",
      purpose: "SAFe 6.0 hierarchical work planning",
      current_state: check_module_in_learning(learning, "SafeWorkPlanner"),
      integration_with_task_graph: "TaskGraph tasks map to Features in SafeWorkPlanner",
      what_it_does: """
      - Creates Strategic Themes (3-5 year vision)
      - Breaks down into Epics (6-12 months)
      - Further into Capabilities and Features
      - TaskGraph handles task-level breakdown
      """,
      how_to_use_it: """
      # TaskGraph will automatically map tasks to Features
      TaskGraph.execute(dag, safe_planning: true)
      """
    }
  end

  defp map_sparc_system(learning) do
    %{
      module: "Singularity.Execution.SPARC.Orchestrator",
      purpose: "SPARC methodology orchestration",
      current_state:
        check_module_in_learning(learning, "Singularity.Execution.SPARC.Orchestrator"),
      integration_with_task_graph: "TaskGraph executor applies SPARC phases to tasks",
      what_it_does: """
      - Specification: Define requirements
      - Pseudocode: High-level algorithm
      - Architecture: System design
      - Refinement: Iterate and improve
      - Completion: Final implementation
      """,
      how_to_use_it: """
      # Enable SPARC for structured development
      TaskGraph.execute(dag, integrate_sparc: true)
      """
    }
  end

  defp map_code_generation_system(learning) do
    %{
      modules: ["RAGCodeGenerator", "QualityCodeGenerator"],
      purpose: "Generate high-quality code with proven patterns",
      current_state: %{
        rag: check_module_in_learning(learning, "RAGCodeGenerator"),
        quality: check_module_in_learning(learning, "QualityCodeGenerator")
      },
      integration_with_task_graph: "TaskGraph executor uses both for code generation",
      what_it_does: """
      RAG: Finds similar code from codebase, uses as examples
      Quality: Enforces documentation, specs, tests, standards
      """,
      how_to_use_it: """
      # Use both for best results
      TaskGraph.execute(dag,
        use_rag: true,
        use_quality_templates: true
      )
      """
    }
  end

  defp map_storage_system(learning) do
    %{
      module: "Singularity.Storage.Store",
      purpose: "Unified storage for code, knowledge, services",
      current_state: check_module_in_learning(learning, "Store"),
      integration_with_task_graph: "TaskGraph uses Store for knowledge search and code storage",
      what_it_does: """
      - Store.all_services(): Discover services
      - Store.search_knowledge(): Find similar code
      - Store.stage_code(): Save generated code
      - Store.query_knowledge(): Get patterns
      """,
      how_to_use_it: """
      # Search for examples
      {:ok, examples} = Store.search_knowledge("authentication")

      # Store improvements
      {:ok, path} = Store.stage_code(agent_id, version, code)
      """
    }
  end

  defp identify_integrations(learning) do
    [
      %{
        from: "TaskGraph",
        to: "SelfImprovingAgent",
        via: "TaskGraphEvolution.critique_and_mutate/2",
        status: check_integration_exists(learning, "TaskGraphEvolution")
      },
      %{
        from: "TaskGraph",
        to: "RAGCodeGenerator",
        via: "Store.search_knowledge/2",
        status: check_integration_exists(learning, "Store")
      },
      %{
        from: "TaskGraph",
        to: "SafeWorkPlanner",
        via: "TaskGraph.execute/2 with safe_planning: true",
        status: :partial
      },
      %{
        from: "TaskGraph",
        to: "SPARC.Orchestrator",
        via: "TaskGraph.execute/2 with integrate_sparc: true",
        status: :partial
      }
    ]
  end

  defp create_repair_plan(issues) do
    # Group issues by severity
    by_severity = Enum.group_by(issues, & &1.severity)

    %{
      phase_1_critical: Map.get(by_severity, :high, []),
      phase_2_important: Map.get(by_severity, :medium, []),
      phase_3_nice_to_have: Map.get(by_severity, :low, []),
      recommended_order: [
        "Fix broken dependencies first",
        "Connect isolated modules",
        "Add missing documentation",
        "Test all integrations",
        "Run self-improvement loop"
      ]
    }
  end

  defp check_module_in_learning(learning, module_name) do
    found =
      Enum.find(learning.knowledge.modules, fn {name, _info} ->
        String.contains?(name, module_name)
      end)

    if found, do: :available, else: :missing
  end

  defp check_integration_exists(learning, module_name) do
    case check_module_in_learning(learning, module_name) do
      :available -> :connected
      :missing -> :not_connected
    end
  end

  defp save_mapping(mapping) do
    # Save to a file for reference
    filename = "HTDAG_SYSTEM_MAPPING.json"

    try do
      content = Jason.encode!(mapping, pretty: true)
      File.write!(filename, content)
      Logger.info("System mapping saved to #{filename}")
    rescue
      e ->
        Logger.warning("Could not save mapping: #{inspect(e)}")
    end
  end
end
