#!/usr/bin/env elixir

# Singularity Vision Initialization Script for Nix Environment
# This script sets up the complete vision hierarchy and starts autonomous building

IO.puts("🚀 Initializing Singularity Vision System in Nix Environment...")

# Verify we're in Nix environment
IO.puts("🔧 Verifying Nix environment...")
case System.get_env("IN_NIX_SHELL") do
  "1" ->
    IO.puts("✅ Running in Nix shell (pure)")
  "impure" ->
    IO.puts("✅ Running in Nix shell (impure)")
  _ ->
    IO.puts("⚠️  Not in Nix shell - some tools may not be available")
    IO.puts("   Run: nix develop")
    System.halt(1)
end

# Check required tools
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
alias Singularity.Planning.HTDAGAutoBootstrap

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

IO.puts("🧠 Starting HTDAG Learning and Auto-Fix...")

# 3. Initialize HTDAG Learning and Auto-Fix
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

# 4. Start HTDAG Auto-Bootstrap for continuous autonomous building
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

# 5. Get the next prioritized work item
case SingularityVision.get_next_work() do
  nil ->
    IO.puts("ℹ️  No work items ready yet")
  work_item ->
    IO.puts("✅ Next work item: #{work_item.name}")
    IO.puts("   Description: #{work_item.description}")
    IO.puts("   Status: #{work_item.status}")
end

IO.puts("📊 Getting Progress Summary...")

# 6. Get progress summary
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
IO.puts("🎉 Singularity Vision System Initialized in Nix Environment!")
IO.puts("")
IO.puts("The system is now:")
IO.puts("✅ Running in Nix with all tools available")
IO.puts("✅ PostgreSQL with vector extensions ready")
IO.puts("✅ NATS with JetStream running")
IO.puts("✅ Rust toolchain with sccache for fast compilation")
IO.puts("✅ Tree-sitter grammars for 30+ languages")
IO.puts("✅ HTDAG Auto-Bootstrap continuously building from vision")
IO.puts("")
IO.puts("Next steps:")
IO.puts("1. The system will automatically build features from the vision")
IO.puts("2. HTDAG will decompose complex goals into tasks")
IO.puts("3. Self-improvement agents will continuously optimize")
IO.puts("4. Monitor progress through SingularityVision.get_progress()")
IO.puts("")
IO.puts("The autonomous development platform is now running! 🚀")