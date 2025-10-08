defmodule Singularity.PromptEngine do
  @moduledoc """
  Prompt Engine (RustNif) - Local prompt optimization with prepared templates
  
  Provides intelligent prompt optimization using:
  - Local DSPy COPRO optimization algorithms
  - Pre-prepared templates from prompt command system
  - Local template processing and caching
  - Microservice-aware prompt generation
  - SPARC methodology templates
  - Template adaptation for specific agents
  
  Architecture:
  - Central Service: Prompt engine + package directory + analysis server + LLM support
  - Prompt Command System: Prepares templates using central research data
  - Local NIF: Uses prepared templates for local optimization
  - Central Learning Loop: Templates evolve based on collective usage
  """

  use Rustler, otp_app: :singularity_app, crate: :singularity_unified

  # Prompt optimization functions
  def optimize_prompt(_prompt), do: :erlang.nif_error(:nif_not_loaded)
  def process_prompt_candidates(_candidates), do: :erlang.nif_error(:nif_not_loaded)
  def get_optimized_sparc_prompt(_prompt_name, _context \\ nil), do: :erlang.nif_error(:nif_not_loaded)
  def generate_microservice_prompt(_context, _file_path, _content, _language), do: :erlang.nif_error(:nif_not_loaded)
  
  # Template management with version context
  def get_template_with_context(_template_name, _context), do: :erlang.nif_error(:nif_not_loaded)
  def get_template_for_versions(_template_name, _language, _framework, _versions), do: :erlang.nif_error(:nif_not_loaded)
  def detect_context_from_codebase(_codebase_path), do: :erlang.nif_error(:nif_not_loaded)
  def get_template_for_architecture(_template_name, _architecture_context), do: :erlang.nif_error(:nif_not_loaded)
  def send_usage_data_to_central(_usage_data), do: :erlang.nif_error(:nif_not_loaded)
  def get_template_performance(_template_name), do: :erlang.nif_error(:nif_not_loaded)
  def request_template_optimization(_template_name, _usage_data), do: :erlang.nif_error(:nif_not_loaded)
  
  # Local prompt storage and version management
  def store_local_prompt(_prompt_name, _prompt, _template_version, _template_name \\ "generic"), do: :erlang.nif_error(:nif_not_loaded)
  def get_local_prompt(_prompt_name), do: :erlang.nif_error(:nif_not_loaded)
  def list_local_prompts(_template_name \\ nil), do: :erlang.nif_error(:nif_not_loaded)
  def check_template_version_updates(_template_name), do: :erlang.nif_error(:nif_not_loaded)
  def migrate_prompt_to_new_version(_prompt_name, _new_template_version), do: :erlang.nif_error(:nif_not_loaded)
  def create_prompt_deviation(_prompt_name, _deviation_reason, _custom_changes), do: :erlang.nif_error(:nif_not_loaded)
  def get_prompt_version_history(_prompt_name), do: :erlang.nif_error(:nif_not_loaded)
  
  # Local template processing functions
  def process_template_locally(_template, _context), do: :erlang.nif_error(:nif_not_loaded)
  def cache_template_locally(_template_name, _template), do: :erlang.nif_error(:nif_not_loaded)
  def get_cached_template(_template_name), do: :erlang.nif_error(:nif_not_loaded)
  
  # Dynamic template functions
  def create_dynamic_template(_context, _requirements), do: :erlang.nif_error(:nif_not_loaded)
  def adapt_template_for_agent(_template, _agent_type), do: :erlang.nif_error(:nif_not_loaded)
  def version_template(_template_name, _version_strategy), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Optimize a prompt using DSPy COPRO algorithms
  
  ## Examples
  
      iex> Singularity.PromptEngine.optimize_prompt("Analyze this code for security issues")
      %{
        optimized_prompt: "🔒 SECURITY ANALYSIS: Examine code for vulnerabilities...",
        optimization_score: 0.87,
        improvement_summary: "Enhanced with security emoji and structured format",
        confidence: 0.92
      }
  """
  def optimize_prompt(prompt) do
    optimize_prompt(prompt)
  end

  @doc """
  Process multiple prompt candidates and select the best
  
  ## Examples
  
      iex> candidates = ["Analyze code", "Review security", "Check performance"]
      iex> Singularity.PromptEngine.process_prompt_candidates(candidates)
      ["Analyze code for security vulnerabilities", "Review security patterns", "Check performance metrics"]
  """
  def process_prompt_candidates(candidates) do
    process_prompt_candidates(candidates)
  end

  @doc """
  Get optimized SPARC methodology prompt
  
  ## Examples
  
      iex> Singularity.PromptEngine.get_optimized_sparc_prompt("code_analysis", %{"language" => "rust"})
      "🏗️ **CODE ANALYSIS** (SPARC Methodology)\n\nAnalyze this Rust code using SPARC principles..."
  """
  def get_optimized_sparc_prompt(prompt_name, context \\ nil) do
    get_optimized_sparc_prompt(prompt_name, context)
  end

  @doc """
  Generate microservice-aware prompt template
  
  ## Examples
  
      iex> context = %{
      ...>   services: ["user-service", "auth-service"],
      ...>   patterns: ["api_gateway", "circuit_breaker"],
      ...>   architecture_type: "microservices"
      ...> }
      iex> Singularity.PromptEngine.generate_microservice_prompt(context, "src/auth.rs", "code", "rust")
      %{
        name: "microservice_auth_analysis",
        template: "🔐 **MICROSERVICE AUTH ANALYSIS**\n\nAnalyze auth service in microservices context...",
        quality_score: 0.94
      }
  """
  def generate_microservice_prompt(context, file_path, content, language) do
    generate_microservice_prompt(context, file_path, content, language)
  end

  @doc """
  Get template with full context (language, framework, versions, architecture)
  
  ## Examples
  
      iex> context = %{
      ...>   language: "elixir",
      ...>   framework: "phoenix",
      ...>   framework_version: "1.7.0",
      ...>   liveview_version: "0.20.0",
      ...>   architecture: "microservices",
      ...>   patterns: ["api_gateway", "circuit_breaker"],
      ...>   dependencies: %{"ecto" => "3.10.0", "phoenix_live_view" => "0.20.0"}
      ...> }
      iex> Singularity.PromptEngine.get_template_with_context("code_analysis", context)
      %{
        template_name: "code_analysis",
        template: "🔍 **CODE ANALYSIS** (Phoenix 1.7.0 + LiveView 0.20.0)\n\nAnalyze this Elixir microservice...",
        version: "2.1.0",
        success_rate: 0.95,
        context_aware: true,
        version_specific: true
      }
  """
  def get_template_with_context(template_name, context) do
    get_template_with_context(template_name, context)
  end

  @doc """
  Get template for specific versions (handles version compatibility)
  
  ## Examples
  
      iex> versions = %{
      ...>   "phoenix" => "1.7.0",
      ...>   "phoenix_live_view" => "0.20.0",
      ...>   "ecto" => "3.10.0"
      ...> }
      iex> Singularity.PromptEngine.get_template_for_versions("code_analysis", "elixir", "phoenix", versions)
      %{
        template_name: "code_analysis",
        template: "🔍 **CODE ANALYSIS** (Phoenix 1.7.0 + LiveView 0.20.0)\n\nAnalyze this Elixir code...",
        version_compatibility: %{
          phoenix: "1.7.0",
          liveview: "0.20.0",
          ecto: "3.10.0"
        },
        compatibility_warnings: []
      }
  """
  def get_template_for_versions(template_name, language, framework, versions) do
    get_template_for_versions(template_name, language, framework, versions)
  end

  @doc """
  Detect context from codebase (auto-detect versions, frameworks, architecture)
  
  ## Examples
  
      iex> Singularity.PromptEngine.detect_context_from_codebase("/path/to/project")
      %{
        language: "elixir",
        framework: "phoenix",
        framework_version: "1.7.0",
        liveview_version: "0.20.0",
        architecture: "microservices",
        patterns: ["api_gateway", "circuit_breaker"],
        dependencies: %{
          "phoenix" => "1.7.0",
          "phoenix_live_view" => "0.20.0",
          "ecto" => "3.10.0"
        },
        confidence: 0.95
      }
  """
  def detect_context_from_codebase(codebase_path) do
    detect_context_from_codebase(codebase_path)
  end

  @doc """
  Get template for specific architecture context
  
  ## Examples
  
      iex> architecture_context = %{
      ...>   architecture_type: "microservices",
      ...>   patterns: ["api_gateway", "circuit_breaker", "event_sourcing"],
      ...>   services: ["user-service", "auth-service", "payment-service"],
      ...>   communication: "event-driven",
      ...>   database: "postgresql"
      ...> }
      iex> Singularity.PromptEngine.get_template_for_architecture("code_analysis", architecture_context)
      %{
        template_name: "code_analysis",
        template: "🔍 **MICROSERVICE CODE ANALYSIS**\n\nAnalyze this microservice code...",
        architecture_aware: true,
        patterns_detected: ["api_gateway", "circuit_breaker"]
      }
  """
  def get_template_for_architecture(template_name, architecture_context) do
    get_template_for_architecture(template_name, architecture_context)
  end

  @doc """
  Send usage data to central for template evolution
  
  ## Examples
  
      iex> usage_data = %{
      ...>   template_name: "code_analysis",
      ...>   prompt_used: "Analyze this code",
      ...>   success: true,
      ...>   response_quality: 0.92,
      ...>   agent_type: "quality_analyzer",
      ...>   processing_time_ms: 150
      ...> }
      iex> Singularity.PromptEngine.send_usage_data_to_central(usage_data)
      :ok
  """
  def send_usage_data_to_central(usage_data) do
    send_usage_data_to_central(usage_data)
  end

  @doc """
  Get central template performance metrics
  
  ## Examples
  
      iex> Singularity.PromptEngine.get_central_template_performance("code_analysis")
      %{
        template_name: "code_analysis",
        success_rate: 0.94,
        average_quality: 0.87,
        usage_count: 1250,
        last_optimized: "2024-01-15T10:30:00Z",
        improvement_trend: "increasing",
        central_insights: [
          "95% success rate with emoji indicators",
          "Structured format improves response quality"
        ]
      }
  """
  def get_central_template_performance(template_name) do
    get_central_template_performance(template_name)
  end

  @doc """
  Request template optimization from central based on usage data
  
  ## Examples
  
      iex> usage_data = %{
      ...>   template_name: "code_analysis",
      ...>   low_performance_areas: ["security_analysis", "performance_metrics"],
      ...>   suggested_improvements: ["Add CVE checking", "Include complexity metrics"]
      ...> }
      iex> Singularity.PromptEngine.request_template_optimization("code_analysis", usage_data)
      %{
        optimization_requested: true,
        estimated_improvement: 0.15,
        central_response: "Template optimization queued for next update"
      }
  """
  def request_template_optimization(template_name, usage_data) do
    request_template_optimization(template_name, usage_data)
  end

  @doc """
  Store local prompt with template version tracking
  
  ## Examples
  
      iex> prompt = "🔍 **CODE ANALYSIS** (Custom)\n\nAnalyze this code for security issues..."
      iex> Singularity.PromptEngine.store_local_prompt("my_security_analysis", prompt, "2.1.0", "code_analysis")
      %{
        stored: true,
        prompt_name: "my_security_analysis",
        template_version: "2.1.0",
        template_name: "code_analysis",
        local_version: "1.0.0"
      }
      
      # Store generic prompt (no known template)
      iex> Singularity.PromptEngine.store_local_prompt("custom_prompt", "My custom prompt", "generic")
      %{
        stored: true,
        prompt_name: "custom_prompt",
        template_version: "generic",
        template_name: "generic",
        local_version: "1.0.0"
      }
  """
  def store_local_prompt(prompt_name, prompt, template_version, template_name \\ "generic") do
    store_local_prompt(prompt_name, prompt, template_version, template_name)
  end

  @doc """
  Get local prompt with version info
  
  ## Examples
  
      iex> Singularity.PromptEngine.get_local_prompt("my_security_analysis")
      %{
        prompt_name: "my_security_analysis",
        prompt: "🔍 **CODE ANALYSIS** (Custom)\n\nAnalyze this code...",
        template_version: "2.1.0",
        template_name: "code_analysis",
        local_version: "1.0.0",
        created_at: "2024-01-15T10:30:00Z",
        last_used: "2024-01-15T14:22:00Z",
        usage_count: 15
      }
  """
  def get_local_prompt(prompt_name) do
    get_local_prompt(prompt_name)
  end

  @doc """
  List local prompts, optionally filtered by template
  
  ## Examples
  
      iex> Singularity.PromptEngine.list_local_prompts()
      %{
        prompts: [
          %{
            prompt_name: "my_security_analysis",
            template_name: "code_analysis",
            template_version: "2.1.0",
            local_version: "1.0.0",
            usage_count: 15
          },
          %{
            prompt_name: "custom_prompt",
            template_name: "generic",
            template_version: "generic",
            local_version: "1.0.0",
            usage_count: 3
          }
        ],
        total_count: 2
      }
      
      iex> Singularity.PromptEngine.list_local_prompts("code_analysis")
      %{
        prompts: [
          %{
            prompt_name: "my_security_analysis",
            template_name: "code_analysis",
            template_version: "2.1.0",
            local_version: "1.0.0",
            usage_count: 15
          }
        ],
        total_count: 1
      }
  """
  def list_local_prompts(template_name \\ nil) do
    list_local_prompts(template_name)
  end

  @doc """
  Check for template version updates from central
  
  ## Examples
  
      iex> Singularity.PromptEngine.check_template_version_updates("code_analysis")
      %{
        template_name: "code_analysis",
        current_version: "2.1.0",
        latest_version: "2.2.0",
        update_available: true,
        changelog: [
          "Added CVE checking section",
          "Improved security analysis structure",
          "Enhanced emoji indicators"
        ],
        breaking_changes: false,
        migration_notes: "Backward compatible - no changes needed"
      }
  """
  def check_template_version_updates(template_name) do
    check_template_version_updates(template_name)
  end

  @doc """
  Migrate local prompt to new template version
  
  ## Examples
  
      iex> Singularity.PromptEngine.migrate_prompt_to_new_version("my_security_analysis", "2.2.0")
      %{
        migrated: true,
        prompt_name: "my_security_analysis",
        old_version: "2.1.0",
        new_version: "2.2.0",
        changes_applied: [
          "Added CVE checking section",
          "Updated security analysis structure"
        ],
        custom_preserved: true,
        migration_notes: "Your custom modifications were preserved"
      }
  """
  def migrate_prompt_to_new_version(prompt_name, new_template_version) do
    migrate_prompt_to_new_version(prompt_name, new_template_version)
  end

  @doc """
  Create a deviation from template (custom modifications)
  
  ## Examples
  
      iex> custom_changes = %{
      ...>   added_sections: ["Custom security checks", "Company-specific compliance"],
      ...>   modified_sections: ["Changed emoji from 🔍 to 🛡️"],
      ...>   removed_sections: ["Generic performance analysis"]
      ...> }
      iex> Singularity.PromptEngine.create_prompt_deviation("my_security_analysis", "Company compliance requirements", custom_changes)
      %{
        deviation_created: true,
        prompt_name: "my_security_analysis",
        deviation_id: "dev_001",
        reason: "Company compliance requirements",
        changes: custom_changes,
        template_version: "2.1.0",
        deviation_version: "1.0.0"
      }
  """
  def create_prompt_deviation(prompt_name, deviation_reason, custom_changes) do
    create_prompt_deviation(prompt_name, deviation_reason, custom_changes)
  end

  @doc """
  Get prompt version history and evolution
  
  ## Examples
  
      iex> Singularity.PromptEngine.get_prompt_version_history("my_security_analysis")
      %{
        prompt_name: "my_security_analysis",
        history: [
          %{
            version: "1.0.0",
            template_version: "2.1.0",
            created_at: "2024-01-15T10:30:00Z",
            changes: ["Initial creation from template"]
          },
          %{
            version: "1.1.0",
            template_version: "2.1.0",
            created_at: "2024-01-15T12:15:00Z",
            changes: ["Added company compliance section", "Custom emoji changes"]
          },
          %{
            version: "2.0.0",
            template_version: "2.2.0",
            created_at: "2024-01-16T09:00:00Z",
            changes: ["Migrated to template 2.2.0", "Preserved custom modifications"]
          }
        ],
        current_version: "2.0.0",
        template_version: "2.2.0"
      }
  """
  def get_prompt_version_history(prompt_name) do
    get_prompt_version_history(prompt_name)
  end

  @doc """
  Process template locally with context
  
  ## Examples
  
      iex> template = "Analyze {language} code: {code}"
      iex> context = %{"language" => "elixir", "code" => "defmodule Test do end"}
      iex> Singularity.PromptEngine.process_template_locally(template, context)
      "Analyze elixir code: defmodule Test do end"
  """
  def process_template_locally(template, context) do
    process_template_locally(template, context)
  end

  @doc """
  Learn from prompt usage and improve templates
  
  ## Examples
  
      iex> usage_data = %{
      ...>   template_name: "code_analysis",
      ...>   prompt: "Analyze this code",
      ...>   success: true,
      ...>   response_quality: 0.92,
      ...>   agent_type: "quality_analyzer"
      ...> }
      iex> Singularity.PromptEngine.learn_from_usage(usage_data)
      :ok
  """
  def learn_from_usage(usage_data) do
    learn_from_usage(usage_data)
  end

  @doc """
  Get template performance metrics
  
  ## Examples
  
      iex> Singularity.PromptEngine.get_template_performance("code_analysis")
      %{
        template_name: "code_analysis",
        success_rate: 0.94,
        average_quality: 0.87,
        usage_count: 1250,
        last_optimized: "2024-01-15T10:30:00Z",
        improvement_trend: "increasing"
      }
  """
  def get_template_performance(template_name) do
    get_template_performance(template_name)
  end

  @doc """
  Suggest template improvements based on usage patterns
  
  ## Examples
  
      iex> Singularity.PromptEngine.suggest_template_improvements("code_analysis")
      [
        %{
          type: "add_structure",
          suggestion: "Add emoji indicators for better visual parsing",
          confidence: 0.89
        },
        %{
          type: "improve_clarity",
          suggestion: "Use more specific language for security analysis",
          confidence: 0.76
        }
      ]
  """
  def suggest_template_improvements(template_name) do
    suggest_template_improvements(template_name)
  end

  @doc """
  Create dynamic template based on context and requirements
  
  ## Examples
  
      iex> context = %{
      ...>   task_type: "security_analysis",
      ...>   language: "rust",
      ...>   complexity: "high",
      ...>   target_audience: "security_experts"
      ...> }
      iex> requirements = %{
      ...>   include_cve_check: true,
      ...>   include_dependency_analysis: true,
      ...>   output_format: "structured"
      ...> }
      iex> Singularity.PromptEngine.create_dynamic_template(context, requirements)
      %{
        template_name: "dynamic_security_analysis_rust_high",
        template: "🔒 **ADVANCED RUST SECURITY ANALYSIS**\n\nComprehensive security review...",
        confidence: 0.91
      }
  """
  def create_dynamic_template(context, requirements) do
    create_dynamic_template(context, requirements)
  end

  @doc """
  Adapt template for specific agent type
  
  ## Examples
  
      iex> template = "Analyze this code for issues"
      iex> Singularity.PromptEngine.adapt_template_for_agent(template, "quality_analyzer")
      "🔍 **QUALITY ANALYSIS**\n\nAnalyze this code for quality issues:\n- Code smells\n- Performance problems\n- Maintainability concerns"
  """
  def adapt_template_for_agent(template, agent_type) do
    adapt_template_for_agent(template, agent_type)
  end

  @doc """
  Version template with specific strategy
  
  ## Examples
  
      iex> Singularity.PromptEngine.version_template("code_analysis", "semantic")
      %{
        template_name: "code_analysis",
        version: "2.1.0",
        changes: ["Added emoji indicators", "Improved structure"],
        backward_compatible: true
      }
  """
  def version_template(template_name, version_strategy) do
    version_template(template_name, version_strategy)
  end
end
