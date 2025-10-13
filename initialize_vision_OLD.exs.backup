#!/usr/bin/env elixir

# Singularity Vision Initialization Script
# This script sets up the complete vision hierarchy for Singularity
# Designed for Nix-based development environment

IO.puts("🚀 Initializing Singularity Vision System in Nix Environment...")

# Verify Nix environment
IO.puts("🔧 Verifying Nix environment...")
case System.cmd("nix", ["--version"]) do
  {version, 0} ->
    IO.puts("✅ Nix version: #{String.trim(version)}")
  {error, _} ->
    IO.puts("❌ Nix not found: #{error}")
    System.halt(1)
end

# Check if we're in a Nix shell
case System.get_env("IN_NIX_SHELL") do
  "1" ->
    IO.puts("✅ Running in Nix shell")
  _ ->
    IO.puts("⚠️  Not in Nix shell - some tools may not be available")
end

# Verify required tools are available
required_tools = ["elixir", "mix", "postgresql", "nats-server", "cargo", "rustc"]
IO.puts("🔍 Checking required tools...")
Enum.each(required_tools, fn tool ->
  case System.find_executable(tool) do
    nil ->
      IO.puts("❌ #{tool} not found in PATH")
    path ->
      IO.puts("✅ #{tool} found at #{path}")
  end
end)

# Start the application
IO.puts("🚀 Starting Singularity application...")
Application.ensure_all_started(:singularity)

# Import required modules
alias Singularity.Planning.{Vision, SingularityVision, AgiPortfolio, SafeWorkPlanner}
alias Singularity.Planning.HTDAGLearner

IO.puts("📋 Setting up Portfolio Vision...")

# 1. Set the high-level portfolio vision
portfolio_vision = %{
  statement: "Build AGI-powered autonomous development platform for personal AI development",
  target_year: 2029,
  success_metrics: [
    %{metric: "autonomous_features", target: 100.0, description: "Number of fully autonomous features"},
    %{metric: "code_quality_score", target: 95.0, description: "Average code quality score"},
    %{metric: "self_improvement_rate", target: 80.0, description: "Percentage of issues auto-fixed"},
    %{metric: "developer_productivity", target: 300.0, description: "Productivity multiplier"},
    %{metric: "system_uptime", target: 99.9, description: "System availability percentage"}
  ],
  approved_by: "system",
  approved_at: DateTime.utc_now()
}

# Set portfolio vision
case AgiPortfolio.set_portfolio_vision(
  portfolio_vision.statement,
  portfolio_vision.target_year,
  portfolio_vision.success_metrics,
  portfolio_vision.approved_by
) do
  {:ok, vision} ->
    IO.puts("✅ Portfolio vision set: #{vision.statement}")
  {:error, reason} ->
    IO.puts("❌ Failed to set portfolio vision: #{inspect(reason)}")
end

IO.puts("🎯 Adding Strategic Themes...")

# 2. Add Strategic Themes (3-5 year vision areas)
strategic_themes = [
  %{
    name: "Autonomous Development Platform",
    description: "Build a fully autonomous AI development environment that can understand, analyze, and improve codebases without human intervention",
    target_bloc: 4.0,
    business_value: 10,
    time_criticality: 9,
    risk_reduction: 8
  },
  %{
    name: "Self-Improving Codebase",
    description: "Create a self-evolving codebase that continuously learns, fixes issues, and improves itself through HTDAG and agent systems",
    target_bloc: 3.5,
    business_value: 9,
    time_criticality: 8,
    risk_reduction: 9
  },
  %{
    name: "Multi-AI Orchestration",
    description: "Integrate multiple AI providers (Claude, Gemini, OpenAI, Copilot) through NATS for optimal task routing and cost optimization",
    target_bloc: 2.5,
    business_value: 8,
    time_criticality: 7,
    risk_reduction: 7
  },
  %{
    name: "Living Knowledge Base",
    description: "Build a bidirectional learning system between Git and PostgreSQL that captures and applies development patterns",
    target_bloc: 3.0,
    business_value: 9,
    time_criticality: 6,
    risk_reduction: 8
  },
  %{
    name: "Semantic Code Intelligence",
    description: "Implement GPU-accelerated semantic search and code analysis using RTX 4080 and pgvector for intelligent code understanding",
    target_bloc: 2.0,
    business_value: 7,
    time_criticality: 8,
    risk_reduction: 6
  },
  %{
    name: "Nix Development Environment",
    description: "Build comprehensive Nix-based development environment with reproducible builds, tool management, and seamless integration",
    target_bloc: 2.5,
    business_value: 9,
    time_criticality: 7,
    risk_reduction: 8
  },
  %{
    name: "Rust NIF Integration",
    description: "Integrate 8 Rust NIF engines via Rustler for high-performance code analysis, parsing, and quality assessment",
    target_bloc: 3.0,
    business_value: 8,
    time_criticality: 8,
    risk_reduction: 7
  }
]

# Add each strategic theme
theme_ids = Enum.map(strategic_themes, fn theme ->
  case SingularityVision.add_strategic_theme(
    theme.name,
    theme.description,
    theme.target_bloc,
    theme.business_value,
    theme.time_criticality,
    theme.risk_reduction
  ) do
    {:ok, %{id: id}} ->
      IO.puts("✅ Added theme: #{theme.name} (ID: #{id})")
      id
    {:error, reason} ->
      IO.puts("❌ Failed to add theme #{theme.name}: #{inspect(reason)}")
      nil
  end
end) |> Enum.filter(& &1)

IO.puts("📈 Adding Key Epics...")

# 3. Add Epics under themes
epics = [
  %{
    name: "HTDAG Self-Evolution System",
    description: "Implement hierarchical task decomposition with self-improvement capabilities using LLM feedback and runtime tracing",
    type: :enabler,
    theme_index: 0, # Autonomous Development Platform
    business_value: 9,
    time_criticality: 9,
    risk_reduction: 8,
    estimated_job_size: 12
  },
  %{
    name: "Codebase Learning & Auto-Fix",
    description: "Build comprehensive codebase analysis that learns from static files and runtime tracing to automatically fix issues",
    type: :enabler,
    theme_index: 1, # Self-Improving Codebase
    business_value: 10,
    time_criticality: 8,
    risk_reduction: 9,
    estimated_job_size: 15
  },
  %{
    name: "NATS Multi-AI Integration",
    description: "Create unified NATS-based AI orchestration with complexity-based routing and cost optimization",
    type: :enabler,
    theme_index: 2, # Multi-AI Orchestration
    business_value: 8,
    time_criticality: 7,
    risk_reduction: 7,
    estimated_job_size: 10
  },
  %{
    name: "Git-PostgreSQL Learning Loop",
    description: "Implement bidirectional learning between Git repositories and PostgreSQL knowledge base",
    type: :enabler,
    theme_index: 3, # Living Knowledge Base
    business_value: 9,
    time_criticality: 6,
    risk_reduction: 8,
    estimated_job_size: 8
  },
  %{
    name: "GPU-Accelerated Semantic Search",
    description: "Build RTX 4080-powered semantic code search with pgvector and intelligent code understanding",
    type: :enabler,
    theme_index: 4, # Semantic Code Intelligence
    business_value: 7,
    time_criticality: 8,
    risk_reduction: 6,
    estimated_job_size: 6
  },
  %{
    name: "Nix Flake Management",
    description: "Create comprehensive Nix flake system with all dependencies, tools, and services for reproducible development",
    type: :enabler,
    theme_index: 5, # Nix Development Environment
    business_value: 9,
    time_criticality: 7,
    risk_reduction: 8,
    estimated_job_size: 8
  },
  %{
    name: "Nix Service Orchestration",
    description: "Build Nix-based service orchestration for PostgreSQL, NATS, and all development tools",
    type: :enabler,
    theme_index: 5, # Nix Development Environment
    business_value: 8,
    time_criticality: 6,
    risk_reduction: 9,
    estimated_job_size: 6
  },
  %{
    name: "Rust NIF Compilation",
    description: "Integrate all 8 Rust NIF engines with proper compilation, testing, and hot-reload capabilities",
    type: :enabler,
    theme_index: 6, # Rust NIF Integration
    business_value: 8,
    time_criticality: 8,
    risk_reduction: 7,
    estimated_job_size: 12
  },
  %{
    name: "Rust-Elixir Bridge",
    description: "Create seamless integration between Rust NIFs and Elixir code with proper error handling and type safety",
    type: :enabler,
    theme_index: 6, # Rust NIF Integration
    business_value: 7,
    time_criticality: 7,
    risk_reduction: 6,
    estimated_job_size: 8
  }
]

# Add each epic
epic_ids = Enum.map(epics, fn epic ->
  theme_id = Enum.at(theme_ids, epic.theme_index)
  if theme_id do
    case SingularityVision.add_epic(
      epic.name,
      epic.description,
      epic.type,
      theme_id,
      epic.business_value,
      epic.time_criticality,
      epic.risk_reduction,
      epic.estimated_job_size
    ) do
      {:ok, %{id: id, wsjf_score: score}} ->
        IO.puts("✅ Added epic: #{epic.name} (WSJF: #{Float.round(score, 2)})")
        id
      {:error, reason} ->
        IO.puts("❌ Failed to add epic #{epic.name}: #{inspect(reason)}")
        nil
    end
  else
    IO.puts("❌ No theme ID for epic #{epic.name}")
    nil
  end
end) |> Enum.filter(& &1)

IO.puts("🔧 Adding Key Capabilities...")

# 4. Add Capabilities under epics
capabilities = [
  %{
    name: "HTDAG Core Engine",
    description: "Pure Elixir HTDAG implementation with task decomposition and dependency resolution",
    epic_index: 0 # HTDAG Self-Evolution System
  },
  %{
    name: "Runtime Tracing System",
    description: "Advanced runtime analysis for detecting dead code, broken functions, and connectivity issues",
    epic_index: 0
  },
  %{
    name: "Codebase Learning Engine",
    description: "Static file scanning and knowledge graph construction for understanding codebase structure",
    epic_index: 1 # Codebase Learning & Auto-Fix
  },
  %{
    name: "Auto-Fix System",
    description: "RAG-based code generation and quality enforcement for automatic issue resolution",
    epic_index: 1
  },
  %{
    name: "NATS AI Router",
    description: "Intelligent routing of AI requests based on complexity and provider capabilities",
    epic_index: 2 # NATS Multi-AI Integration
  },
  %{
    name: "Cost Optimization Engine",
    description: "Rules-first approach with LLM fallback for minimizing AI costs while maintaining quality",
    epic_index: 2
  },
  %{
    name: "Knowledge Artifact Store",
    description: "PostgreSQL-based storage for templates, patterns, and learned knowledge",
    epic_index: 3 # Git-PostgreSQL Learning Loop
  },
  %{
    name: "Pattern Mining System",
    description: "Extraction and application of development patterns from codebase history",
    epic_index: 3
  },
  %{
    name: "Vector Embedding Engine",
    description: "GPU-accelerated embedding generation for semantic code search",
    epic_index: 4 # GPU-Accelerated Semantic Search
  },
  %{
    name: "Semantic Search API",
    description: "High-performance semantic search with pgvector and intelligent ranking",
    epic_index: 4
  },
  %{
    name: "Nix Flake Configuration",
    description: "Comprehensive Nix flake with all development tools, services, and dependencies",
    epic_index: 5 # Nix Flake Management
  },
  %{
    name: "Nix Development Shell",
    description: "Reproducible development environment with all tools and services pre-configured",
    epic_index: 5 # Nix Flake Management
  },
  %{
    name: "Nix Service Management",
    description: "Automated startup and management of PostgreSQL, NATS, and other services",
    epic_index: 6 # Nix Service Orchestration
  },
  %{
    name: "Nix Build Integration",
    description: "Seamless integration between Nix builds and Elixir/Rust compilation",
    epic_index: 6 # Nix Service Orchestration
  },
  %{
    name: "Rust NIF Compilation Pipeline",
    description: "Automated compilation of all 8 Rust NIF engines with proper dependency management",
    epic_index: 7 # Rust NIF Compilation
  },
  %{
    name: "Rust NIF Testing Framework",
    description: "Comprehensive testing framework for Rust NIFs with integration tests",
    epic_index: 7 # Rust NIF Compilation
  },
  %{
    name: "Rustler Integration Layer",
    description: "Seamless Rust-Elixir integration with proper error handling and type safety",
    epic_index: 8 # Rust-Elixir Bridge
  },
  %{
    name: "NIF Hot Reload System",
    description: "Hot reloading of Rust NIFs during development without restarting Elixir",
    epic_index: 8 # Rust-Elixir Bridge
  }
]

# Add each capability
capability_ids = Enum.map(capabilities, fn capability ->
  epic_id = Enum.at(epic_ids, capability.epic_index)
  if epic_id do
    case SingularityVision.add_capability(
      capability.name,
      capability.description,
      epic_id
    ) do
      {:ok, %{id: id}} ->
        IO.puts("✅ Added capability: #{capability.name}")
        id
      {:error, reason} ->
        IO.puts("❌ Failed to add capability #{capability.name}: #{inspect(reason)}")
        nil
    end
  else
    IO.puts("❌ No epic ID for capability #{capability.name}")
    nil
  end
end) |> Enum.filter(& &1)

IO.puts("🎯 Adding Priority Features...")

# 5. Add Features under capabilities
features = [
  %{
    name: "HTDAG Task Decomposition",
    description: "Implement hierarchical task breakdown with LLM integration for complex goal decomposition",
    capability_index: 0, # HTDAG Core Engine
    acceptance_criteria: [
      "Can decompose complex goals into hierarchical task graphs",
      "Integrates with LLM for intelligent task breakdown",
      "Supports dependency resolution and status tracking"
    ]
  },
  %{
    name: "Runtime Function Tracing",
    description: "Detect which functions are actually called and identify dead code",
    capability_index: 1, # Runtime Tracing System
    acceptance_criteria: [
      "Traces function calls in real-time",
      "Identifies dead code and unused functions",
      "Detects broken function calls and errors"
    ]
  },
  %{
    name: "Codebase Knowledge Graph",
    description: "Build comprehensive knowledge graph of module relationships and dependencies",
    capability_index: 2, # Codebase Learning Engine
    acceptance_criteria: [
      "Scans all source files for module documentation",
      "Extracts dependency relationships from aliases",
      "Builds searchable knowledge graph"
    ]
  },
  %{
    name: "RAG Code Generation",
    description: "Generate code fixes using similar examples from the knowledge base",
    capability_index: 3, # Auto-Fix System
    acceptance_criteria: [
      "Finds similar code examples using semantic search",
      "Generates fixes based on quality templates",
      "Applies fixes automatically with validation"
    ]
  },
  %{
    name: "NATS AI Request Router",
    description: "Route AI requests to optimal providers based on complexity and cost",
    capability_index: 4, # NATS AI Router
    acceptance_criteria: [
      "Routes simple tasks to cost-effective providers",
      "Routes complex tasks to high-capability providers",
      "Implements circuit breaking and fallback logic"
    ]
  },
  %{
    name: "Rules Engine Integration",
    description: "Implement rules-first approach to minimize LLM usage and costs",
    capability_index: 5, # Cost Optimization Engine
    acceptance_criteria: [
      "Checks rules before calling LLM",
      "Caches LLM responses for reuse",
      "Tracks and optimizes costs per task"
    ]
  }
]

# Add each feature
feature_ids = Enum.map(features, fn feature ->
  capability_id = Enum.at(capability_ids, feature.capability_index)
  if capability_id do
    case SingularityVision.add_feature(
      feature.name,
      feature.description,
      capability_id,
      feature.acceptance_criteria
    ) do
      {:ok, %{id: id}} ->
        IO.puts("✅ Added feature: #{feature.name}")
        id
      {:error, reason} ->
        IO.puts("❌ Failed to add feature #{feature.name}: #{inspect(reason)}")
        nil
    end
  else
    IO.puts("❌ No capability ID for feature #{feature.name}")
    nil
  end
end) |> Enum.filter(& &1)

IO.puts("🧠 Starting HTDAG Learning and Auto-Fix...")

# 6. Initialize HTDAG Learning and Auto-Fix
case HTDAGLearner.learn_codebase() do
  {:ok, learning} ->
    IO.puts("✅ Codebase learning completed:")
    IO.puts("   - Modules found: #{map_size(learning.knowledge.modules)}")
    IO.puts("   - Issues identified: #{length(learning.issues)}")
    
    # Show some issues
    if length(learning.issues) > 0 do
      IO.puts("   - Sample issues:")
      learning.issues
      |> Enum.take(3)
      |> Enum.each(fn issue ->
        IO.puts("     • #{issue.type}: #{issue.description}")
      end)
      
      IO.puts("🔧 Starting auto-fix process...")
      case HTDAGLearner.auto_fix_all() do
        {:ok, fixes} ->
          IO.puts("✅ Auto-fix completed:")
          IO.puts("   - Iterations: #{fixes.iterations}")
          IO.puts("   - Fixes applied: #{length(fixes.fixes)}")
        {:error, reason} ->
          IO.puts("❌ Auto-fix failed: #{inspect(reason)}")
      end
    else
      IO.puts("✅ No issues found - codebase is clean!")
    end
  {:error, reason} ->
    IO.puts("❌ Codebase learning failed: #{inspect(reason)}")
end

IO.puts("🚀 Starting HTDAG Auto-Bootstrap for continuous building...")

# 7. Start HTDAG Auto-Bootstrap for continuous autonomous building
case HTDAGAutoBootstrap.start_link() do
  {:ok, pid} ->
    IO.puts("✅ HTDAG Auto-Bootstrap started (PID: #{inspect(pid)})")
    IO.puts("   - System will now continuously build from vision")
    IO.puts("   - Features will be automatically decomposed and executed")
    IO.puts("   - Self-improvement will run continuously")
  {:error, reason} ->
    IO.puts("❌ Failed to start HTDAG Auto-Bootstrap: #{inspect(reason)}")
end

IO.puts("🎯 Getting Next Work Item...")

# 7. Get the next prioritized work item
case SingularityVision.get_next_work() do
  nil ->
    IO.puts("ℹ️  No work items ready yet")
  work_item ->
    IO.puts("✅ Next work item: #{work_item.name}")
    IO.puts("   Description: #{work_item.description}")
    IO.puts("   Status: #{work_item.status}")
end

IO.puts("📊 Getting Progress Summary...")

# 8. Get progress summary
case SingularityVision.get_progress() do
  progress ->
    IO.puts("📈 Progress Summary:")
    IO.puts("   - Strategic Themes: #{progress.total_themes}")
    IO.puts("   - Epics: #{progress.total_epics}")
    IO.puts("   - Capabilities: #{progress.total_capabilities}")
    IO.puts("   - Features: #{progress.total_features}")
    
    IO.puts("   - Theme Status: #{inspect(progress.themes)}")
    IO.puts("   - Epic Status: #{inspect(progress.epics)}")
    IO.puts("   - Capability Status: #{inspect(progress.capabilities)}")
    IO.puts("   - Feature Status: #{inspect(progress.features)}")
end

IO.puts("")
IO.puts("🎉 Singularity Vision System Initialized!")
IO.puts("")
IO.puts("Next steps:")
IO.puts("1. Run HTDAGLearner.auto_fix_all() to fix identified issues")
IO.puts("2. Start HTDAGAutoBootstrap for continuous self-improvement")
IO.puts("3. Use SafeWorkPlanner to manage work items")
IO.puts("4. Monitor progress through SingularityVision.get_progress()")
IO.puts("")
IO.puts("The system now has a complete vision hierarchy and knows what to build! 🚀")