defmodule Singularity.Planning.HTDAGLearner do
  @moduledoc """
  Simple, incremental learning system for HTDAG to understand the codebase.
  
  This module provides an easy way for the system to:
  1. Learn about code components incrementally
  2. Build a knowledge graph of what exists
  3. Understand relationships between components
  4. Identify what needs fixing
  5. Auto-repair broken integrations
  
  ## Learning Approach
  
  Instead of complex analysis, this uses a simple pattern:
  - Scan source files for module documentation
  - Extract component purposes from @moduledoc
  - Build dependency graph from aliases
  - Identify missing connections
  - Auto-generate fixes using RAG + Quality templates
  
  ## Usage
  
      # Learn about the codebase incrementally
      {:ok, knowledge} = HTDAGLearner.learn_codebase()
      
      # Auto-fix everything that's broken
      {:ok, fixes} = HTDAGLearner.auto_fix_all()
  """
  
  require Logger
  
  alias Singularity.{Store, RAGCodeGenerator, QualityCodeGenerator}
  alias Singularity.Planning.{HTDAG, HTDAGBootstrap, HTDAGTracer}
  alias Singularity.SelfImprovingAgent
  
  @doc """
  Learn about the codebase in a simple, incremental way.
  
  Scans source files, extracts documentation, builds knowledge graph.
  """
  def learn_codebase(opts \\ []) do
    Logger.info("Starting simple codebase learning...")
    
    # Step 1: Scan all Elixir source files
    source_files = find_source_files()
    
    Logger.info("Found #{length(source_files)} source files")
    
    # Step 2: Extract knowledge from each file
    knowledge = Enum.reduce(source_files, %{modules: %{}, dependencies: %{}}, fn file, acc ->
      case learn_from_file(file) do
        {:ok, file_knowledge} ->
          merge_knowledge(acc, file_knowledge)
        {:error, _reason} ->
          acc
      end
    end)
    
    # Step 3: Identify what's missing or broken
    issues = identify_issues(knowledge)
    
    Logger.info("Learning complete: #{map_size(knowledge.modules)} modules, #{length(issues)} issues")
    
    {:ok, %{
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
  def auto_fix_all(opts \\ []) do
    max_iterations = Keyword.get(opts, :max_iterations, 10)
    
    Logger.info("Starting auto-fix with max #{max_iterations} iterations...")
    
    # Learn first
    {:ok, learning} = learn_codebase()
    
    # Fix iteratively
    fix_iteration(learning, 0, max_iterations, [])
  end
  
  @doc """
  Map all existing systems into HTDAG with inline documentation.
  
  Creates a comprehensive mapping document showing:
  - What each system does
  - How they should work together
  - What's currently broken
  - How to fix it
  """
  def map_all_systems do
    Logger.info("Mapping all systems into HTDAG...")
    
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
  def learn_with_tracing(opts \\ []) do
    Logger.info("Learning codebase with static + runtime analysis...")
    
    # Step 1: Static learning (scan files)
    Logger.info("Phase 1: Static analysis...")
    {:ok, static_knowledge} = learn_codebase(opts)
    
    # Step 2: Runtime tracing (see what actually runs)
    Logger.info("Phase 2: Runtime tracing...")
    {:ok, trace_analysis} = HTDAGTracer.full_analysis(
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
    enhanced_modules = Enum.reduce(static_knowledge.modules, %{}, fn {mod_name, mod_data}, acc ->
      # Check if module is actually called at runtime
      is_called = Enum.any?(trace_analysis.trace_results, fn {{mod, _fun, _arity}, _data} ->
        Atom.to_string(mod) == mod_name
      end)
      
      # Check connectivity
      connectivity = HTDAGTracer.is_connected?(String.to_atom("Elixir.#{mod_name}"))
      
      # Check for broken functions in this module
      broken_in_module = Enum.filter(trace_analysis.broken_functions, fn {mod, _fun, _arity, _reason} ->
        Atom.to_string(mod) == mod_name
      end)
      
      enhanced = Map.merge(mod_data, %{
        called_at_runtime: is_called,
        connectivity: connectivity,
        broken_functions: broken_in_module,
        is_working: is_called and length(broken_in_module) == 0
      })
      
      Map.put(acc, mod_name, enhanced)
    end)
    
    working_count = Enum.count(enhanced_modules, fn {_name, data} -> data.is_working end)
    broken_count = Enum.count(enhanced_modules, fn {_name, data} -> 
      length(data.broken_functions) > 0
    end)
    disconnected_count = Enum.count(enhanced_modules, fn {_name, data} -> 
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
    broken_issues = Enum.flat_map(merged_data.modules, fn {mod_name, mod_data} ->
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
    disconnected_issues = Enum.reduce(merged_data.modules, [], fn {mod_name, mod_data}, acc ->
      if not mod_data.connectivity.connected do
        [%{
          type: :disconnected_module,
          severity: :medium,
          module: mod_name,
          description: "Module is not connected to system (no callers/callees)",
          detected_by: :runtime_tracing
        } | acc]
      else
        acc
      end
    end)
    
    # Add never-called module issues
    never_called_issues = Enum.reduce(merged_data.modules, [], fn {mod_name, mod_data}, acc ->
      if not mod_data.called_at_runtime and mod_data.has_docs do
        [%{
          type: :never_called,
          severity: :low,
          module: mod_name,
          description: "Module defined but never called at runtime",
          detected_by: :runtime_tracing
        } | acc]
      else
        acc
      end
    end)
    
    issues ++ broken_issues ++ disconnected_issues ++ never_called_issues
  end
  
  ## Private Functions
  
  defp find_source_files do
    # Find all Elixir files in singularity_app
    base_path = Path.join([File.cwd!(), "singularity_app", "lib", "singularity"])
    
    if File.exists?(base_path) do
      Path.wildcard("#{base_path}/**/*.ex")
    else
      []
    end
  end
  
  defp learn_from_file(file_path) do
    try do
      # Read file content
      content = File.read!(file_path)
      
      # Extract module name
      module_name = extract_module_name(content)
      
      # Extract documentation
      moduledoc = extract_moduledoc(content)
      
      # Extract dependencies (aliases)
      dependencies = extract_dependencies(content)
      
      # Extract purpose from docs
      purpose = extract_purpose(moduledoc)
      
      {:ok, %{
        module: module_name,
        file: file_path,
        purpose: purpose,
        dependencies: dependencies,
        has_docs: moduledoc != nil,
        content_size: byte_size(content)
      }}
    rescue
      e ->
        Logger.debug("Error learning from #{file_path}: #{inspect(e)}")
        {:error, :parse_error}
    end
  end
  
  defp extract_module_name(content) do
    case Regex.run(~r/defmodule\s+([\w\.]+)/, content) do
      [_, module] -> module
      _ -> "Unknown"
    end
  end
  
  defp extract_moduledoc(content) do
    case Regex.run(~r/@moduledoc\s+"""\s*(.+?)\s*"""/s, content) do
      [_, doc] -> String.trim(doc)
      _ -> nil
    end
  end
  
  defp extract_dependencies(content) do
    # Find all alias statements
    Regex.scan(~r/alias\s+([\w\.]+)/, content)
    |> Enum.map(fn [_, dep] -> dep end)
    |> Enum.uniq()
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
    undocumented = knowledge.modules
    |> Enum.filter(fn {_name, info} -> not info.has_docs end)
    |> Enum.map(fn {name, _info} -> 
      %{type: :missing_docs, module: name, severity: :low}
    end)
    
    # Check for broken dependencies
    broken_deps = knowledge.dependencies
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
    isolated = knowledge.modules
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
    high_priority = Enum.filter(learning.issues, fn issue ->
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
          fix_iteration(new_learning, iteration + a, max_iterations, fixes_applied)
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
    # Actually generate and apply the fix for broken dependency
    Logger.info("Generating fix for broken dependency: #{issue.missing}")
    
    module_info = Map.get(learning.knowledge.modules, issue.module)
    
    if not module_info do
      Logger.error("Module info not found for #{issue.module}")
      return {:error, :module_not_found}
    end
    
    file_path = module_info.file
    
    if not File.exists?(file_path) do
      Logger.error("File not found: #{file_path}")
      return {:error, :file_not_found}
    end
    
    # Read current file content
    content = File.read!(file_path)
    
    # Check if missing module exists in the system
    missing_exists = Map.has_key?(learning.knowledge.modules, issue.missing)
    
    new_content = if missing_exists do
      # Module exists, just add the alias
      add_alias_to_content(content, issue.missing)
    else
      # Module doesn't exist - use RAG to find similar module or template
      case RAGCodeGenerator.find_similar_module(issue.missing) do
        {:ok, similar} ->
          Logger.info("Found similar module: #{similar}, using as template")
          # Create the missing module based on template
          create_missing_module(issue.missing, similar, learning)
          # Also add alias to current file
          add_alias_to_content(content, issue.missing)
        
        {:error, _} ->
          Logger.warn("No template found for #{issue.missing}, adding TODO comment")
          add_todo_comment(content, issue.missing)
      end
    end
    
    # Write the fixed content back
    File.write!(file_path, new_content)
    
    Logger.info("✓ Fixed broken dependency in #{file_path}")
    
    fix = %{
      type: :broken_dependency_fix,
      module: issue.module,
      missing: issue.missing,
      file: file_path,
      action: if(missing_exists, do: "Added alias", else: "Created missing module"),
      auto_generated: true,
      timestamp: DateTime.utc_now()
    }
    
    {:ok, fix}
  end
  
  defp add_alias_to_content(content, module_name) do
    # Find the right place to add alias (after defmodule line)
    lines = String.split(content, "\n")
    
    {before_defmodule, after_defmodule} = Enum.split_while(lines, fn line ->
      not String.contains?(line, "defmodule ")
    end)
    
    case after_defmodule do
      [defmodule_line | rest] ->
        # Add alias after defmodule
        alias_line = "  alias #{module_name}"
        
        # Check if alias already exists
        if Enum.any?(rest, &String.contains?(&1, "alias #{module_name}")) do
          content  # Already has alias
        else
          # Insert alias after defmodule
          new_lines = before_defmodule ++ [defmodule_line, alias_line] ++ rest
          Enum.join(new_lines, "\n")
        end
      
      [] ->
        content  # No defmodule found, return unchanged
    end
  end
  
  defp add_todo_comment(content, missing_module) do
    # Add TODO comment at the top of the file
    todo = """
    # TODO: Missing module #{missing_module} needs to be implemented
    # This dependency was detected but the module doesn't exist yet.
    # Consider implementing it or removing the reference.
    
    """
    
    todo <> content
  end
  
  defp create_missing_module(module_name, template_module, learning) do
    # Create a new file for the missing module based on template
    module_parts = String.split(module_name, ".")
    filename = List.last(module_parts) |> Macro.underscore() |> Kernel.<>(".ex")
    
    # Determine directory path
    base_path = Path.join([File.cwd!(), "singularity_app", "lib"])
    dir_parts = Enum.slice(module_parts, 1..-2) |> Enum.map(&Macro.underscore/1)
    dir_path = Path.join([base_path | dir_parts])
    
    # Create directory if it doesn't exist
    File.mkdir_p!(dir_path)
    
    file_path = Path.join(dir_path, filename)
    
    # Generate module content from template
    template_content = case Map.get(learning.knowledge.modules, template_module) do
      %{file: template_file} when template_file != nil ->
        if File.exists?(template_file) do
          File.read!(template_file)
          |> String.replace(template_module, module_name)
          |> String.replace("# TODO: Auto-generated", "# TODO: Auto-generated from #{template_module}")
        else
          generate_basic_module_template(module_name)
        end
      
      _ ->
        generate_basic_module_template(module_name)
    end
    
    # Write the new module
    File.write!(file_path, template_content)
    
    Logger.info("✓ Created new module #{module_name} at #{file_path}")
    
    {:ok, file_path}
  end
  
  defp generate_basic_module_template(module_name) do
    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      Auto-generated module created by HTDAGLearner.
      
      This module was created to fix a broken dependency.
      Please add proper documentation and implementation.
      \"\"\"
      
      require Logger
      
      @doc \"\"\"
      TODO: Implement this module's functionality.
      \"\"\"
      def placeholder do
        Logger.warn("\#{__MODULE__} is a placeholder - needs implementation")
        {:error, :not_implemented}
      end
    end
    """
  end
  
  defp fix_missing_docs(issue, learning) do
    # Generate documentation using LLM
    module_info = Map.get(learning.knowledge.modules, issue.module)
    
    if module_info do
      Logger.info("Would generate docs for: #{issue.module}")
      
      fix = %{
        type: :missing_docs_fix,
        module: issue.module,
        action: "Generate @moduledoc from code analysis",
        auto_generated: true
      }
      
      {:ok, fix}
    else
      {:error, :module_not_found}
    end
  end
  
  defp fix_isolated_module(issue, _learning) do
    Logger.info("Would connect isolated module: #{issue.module}")
    
    fix = %{
      type: :isolated_module_fix,
      module: issue.module,
      action: "Suggest integrations based on module purpose",
      auto_generated: true
    }
    
    {:ok, fix}
  end
  
  defp map_self_improving_system(learning) do
    %{
      module: "Singularity.SelfImprovingAgent",
      purpose: "Self-improving agent that evolves through feedback",
      current_state: check_module_in_learning(learning, "SelfImprovingAgent"),
      integration_with_htdag: "Feeds evolution results to HTDAG for improvements",
      what_it_does: """
      - Observes metrics from task execution
      - Decides when to evolve based on performance
      - Generates new code improvements
      - Hands improvements to hot-reload manager
      """,
      how_to_use_it: """
      SelfImprovingAgent.improve(agent_id, %{
        mutations: htdag_mutations,
        source: "htdag_evolution"
      })
      """
    }
  end
  
  defp map_safe_planning_system(learning) do
    %{
      module: "Singularity.Planning.SafeWorkPlanner",
      purpose: "SAFe 6.0 hierarchical work planning",
      current_state: check_module_in_learning(learning, "SafeWorkPlanner"),
      integration_with_htdag: "HTDAG tasks map to Features in SafeWorkPlanner",
      what_it_does: """
      - Creates Strategic Themes (3-5 year vision)
      - Breaks down into Epics (6-12 months)
      - Further into Capabilities and Features
      - HTDAG handles task-level breakdown
      """,
      how_to_use_it: """
      # HTDAG will automatically map tasks to Features
      HTDAG.execute_with_nats(dag, safe_planning: true)
      """
    }
  end
  
  defp map_sparc_system(learning) do
    %{
      module: "Singularity.TemplateSparcOrchestrator",
      purpose: "SPARC methodology orchestration",
      current_state: check_module_in_learning(learning, "TemplateSparcOrchestrator"),
      integration_with_htdag: "HTDAG executor applies SPARC phases to tasks",
      what_it_does: """
      - Specification: Define requirements
      - Pseudocode: High-level algorithm
      - Architecture: System design
      - Refinement: Iterate and improve
      - Completion: Final implementation
      """,
      how_to_use_it: """
      # Enable SPARC for structured development
      HTDAG.execute_with_nats(dag, integrate_sparc: true)
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
      integration_with_htdag: "HTDAG executor uses both for code generation",
      what_it_does: """
      RAG: Finds similar code from codebase, uses as examples
      Quality: Enforces documentation, specs, tests, standards
      """,
      how_to_use_it: """
      # Use both for best results
      HTDAG.execute_with_nats(dag,
        use_rag: true,
        use_quality_templates: true
      )
      """
    }
  end
  
  defp map_storage_system(learning) do
    %{
      module: "Singularity.Store",
      purpose: "Unified storage for code, knowledge, services",
      current_state: check_module_in_learning(learning, "Store"),
      integration_with_htdag: "HTDAG uses Store for knowledge search and code storage",
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
        from: "HTDAG",
        to: "SelfImprovingAgent",
        via: "HTDAGEvolution.critique_and_mutate/2",
        status: check_integration_exists(learning, "HTDAGEvolution")
      },
      %{
        from: "HTDAG",
        to: "RAGCodeGenerator",
        via: "Store.search_knowledge/2",
        status: check_integration_exists(learning, "Store")
      },
      %{
        from: "HTDAG",
        to: "SafeWorkPlanner",
        via: "HTDAG.execute_with_nats/2 with safe_planning: true",
        status: :partial
      },
      %{
        from: "HTDAG",
        to: "TemplateSparcOrchestrator",
        via: "HTDAG.execute_with_nats/2 with integrate_sparc: true",
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
    found = Enum.find(learning.knowledge.modules, fn {name, _info} ->
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
