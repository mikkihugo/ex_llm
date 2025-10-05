# Singularity Work Plan Seeds
# SAFe 6.0 Essential Portfolio Backlog

alias Singularity.Repo
alias Singularity.Planning.Schemas.{StrategicTheme, Epic, Capability, Feature, CapabilityDependency}

# Clear existing data
Repo.delete_all(Feature)
Repo.delete_all(CapabilityDependency)
Repo.delete_all(Capability)
Repo.delete_all(Epic)
Repo.delete_all(StrategicTheme)

IO.puts("Seeding Singularity Work Plan...")

# Strategic Theme 1: Autonomous Code Generation (3 BLOC)
theme1 =
  Repo.insert!(%StrategicTheme{
    name: "Autonomous Code Generation",
    description: "Build world-class autonomous code generation platform capable of learning from codebases and generating production-quality code (3 BLOC)",
    target_bloc: 3.0,
    priority: 1,
    status: "active",
    approved_by: "system"
  })

IO.puts("Created Strategic Theme: #{theme1.name}")

# Epic 1.1: Self-Improving Agent System (Enabler)
epic1_1 =
  Repo.insert!(%Epic{
    theme_id: theme1.id,
    name: "Self-Improving Agent System",
    description: "Agents that learn from experience, improve code quality over time, and adapt to project patterns through HTDAG-based learning",
    type: "enabler",
    status: "implementation",
    business_value: 9,
    time_criticality: 8,
    risk_reduction: 9,
    job_size: 13,
    approved_by: "system"
  })

IO.puts("  Created Epic: #{epic1_1.name} (WSJF: #{epic1_1.wsjf_score})")

# Capability 1.1.1: Vision-Driven Code Generation
cap1_1_1 =
  Repo.insert!(%Capability{
    epic_id: epic1_1.id,
    name: "Vision-Driven Code Generation",
    description: "Generate code from natural language vision chunks, analyzing existing codebase patterns and quality standards",
    status: "implementing",
    approved_by: "system"
  })

IO.puts("    Created Capability: #{cap1_1_1.name}")

# Features under Vision-Driven Code Generation
Repo.insert!(%Feature{
  capability_id: cap1_1_1.id,
  name: "Pattern-Based Code Synthesis",
  description: "Synthesize code by learning from existing codebase patterns using semantic search and template extraction",
  status: "in_progress",
  acceptance_criteria: [
    "Can extract patterns from 10+ file types",
    "Generates code matching project style 90%+ accuracy",
    "Validates against quality rules before generation"
  ],
  approved_by: "system"
})

Repo.insert!(%Feature{
  capability_id: cap1_1_1.id,
  name: "Quality-Assured Generation",
  description: "Ensure all generated code passes quality checks (format, credo, dialyzer, sobelow) before commit",
  status: "backlog",
  acceptance_criteria: [
    "Runs all quality checks automatically",
    "Fixes or escalates quality issues",
    "Maintains 100% quality gate pass rate"
  ],
  approved_by: "system"
})

# Capability 1.1.2: HTDAG Learning System
cap1_1_2 =
  Repo.insert!(%Capability{
    epic_id: epic1_1.id,
    name: "HTDAG Learning System",
    description: "Hierarchical Temporal Directed Acyclic Graph for learning from task execution history and improving over time",
    status: "analyzing",
    approved_by: "system"
  })

IO.puts("    Created Capability: #{cap1_1_2.name}")

# Features under HTDAG Learning
Repo.insert!(%Feature{
  capability_id: cap1_1_2.id,
  name: "Task Outcome Tracking",
  description: "Track outcomes of all executed tasks in HTDAG structure for learning",
  status: "backlog",
  acceptance_criteria: [
    "Records success/failure of all tasks",
    "Captures performance metrics (time, quality)",
    "Links outcomes to decision patterns"
  ],
  approved_by: "system"
})

Repo.insert!(%Feature{
  capability_id: cap1_1_2.id,
  name: "Pattern Improvement Loop",
  description: "Automatically improve code generation patterns based on HTDAG learnings",
  status: "backlog",
  acceptance_criteria: [
    "Identifies low-performing patterns",
    "Suggests improvements based on successful patterns",
    "Updates pattern library autonomously"
  ],
  approved_by: "system"
})

# Epic 1.2: Semantic Code Search & RAG (Enabler)
epic1_2 =
  Repo.insert!(%Epic{
    theme_id: theme1.id,
    name: "Semantic Code Search & RAG",
    description: "GPU-accelerated semantic search across codebases using pgvector and embeddings for intelligent code retrieval",
    type: "enabler",
    status: "implementation",
    business_value: 8,
    time_criticality: 9,
    risk_reduction: 7,
    job_size: 8,
    approved_by: "system"
  })

IO.puts("  Created Epic: #{epic1_2.name} (WSJF: #{epic1_2.wsjf_score})")

# Capability 1.2.1: Multi-Codebase Search
cap1_2_1 =
  Repo.insert!(%Capability{
    epic_id: epic1_2.id,
    name: "Multi-Codebase Search",
    description: "Search across multiple codebases (singularity, learning codebases, package registries) with unified interface",
    status: "implementing",
    approved_by: "system"
  })

IO.puts("    Created Capability: #{cap1_2_1.name}")

Repo.insert!(%Feature{
  capability_id: cap1_2_1.id,
  name: "Unified Search API",
  description: "Single API to search across all registered codebases and package registries",
  status: "in_progress",
  acceptance_criteria: [
    "Searches all codebases in parallel",
    "Returns results sorted by relevance",
    "Supports filtering by codebase, language, file type"
  ],
  approved_by: "system"
})

# Strategic Theme 2: Distributed Agent Orchestration (2 BLOC)
theme2 =
  Repo.insert!(%StrategicTheme{
    name: "Distributed Agent Orchestration",
    description: "Build scalable, fault-tolerant agent orchestration using NATS JetStream and SAFe methodologies (2 BLOC)",
    target_bloc: 2.0,
    priority: 2,
    status: "active",
    approved_by: "system"
  })

IO.puts("Created Strategic Theme: #{theme2.name}")

# Epic 2.1: NATS-Based Messaging (Enabler)
epic2_1 =
  Repo.insert!(%Epic{
    theme_id: theme2.id,
    name: "NATS-Based Messaging",
    description: "Implement comprehensive NATS JetStream messaging for agent coordination, work distribution, and event streaming",
    type: "enabler",
    status: "implementation",
    business_value: 7,
    time_criticality: 8,
    risk_reduction: 9,
    job_size: 10,
    approved_by: "system"
  })

IO.puts("  Created Epic: #{epic2_1.name} (WSJF: #{epic2_1.wsjf_score})")

# Capability 2.1.1: Work Queue Management
cap2_1_1 =
  Repo.insert!(%Capability{
    epic_id: epic2_1.id,
    name: "Work Queue Management",
    description: "JetStream-based work queues for distributing tasks to agents with persistence and replay",
    status: "implementing",
    approved_by: "system"
  })

IO.puts("    Created Capability: #{cap2_1_1.name}")

Repo.insert!(%Feature{
  capability_id: cap2_1_1.id,
  name: "JetStream Work Queues",
  description: "Create persistent work queues using JetStream streams and consumers",
  status: "in_progress",
  acceptance_criteria: [
    "Supports multiple priority levels",
    "Persists work across restarts",
    "Handles backpressure automatically"
  ],
  approved_by: "system"
})

# Epic 2.2: SAFe Portfolio Management (Business)
epic2_2 =
  Repo.insert!(%Epic{
    theme_id: theme2.id,
    name: "SAFe Portfolio Management",
    description: "Complete SAFe 6.0 Essential portfolio management with WSJF prioritization, epics, capabilities, and features",
    type: "business",
    status: "implementation",
    business_value: 8,
    time_criticality: 7,
    risk_reduction: 8,
    job_size: 12,
    approved_by: "system"
  })

IO.puts("  Created Epic: #{epic2_2.name} (WSJF: #{epic2_2.wsjf_score})")

# Capability 2.2.1: WSJF Prioritization Engine
cap2_2_1 =
  Repo.insert!(%Capability{
    epic_id: epic2_2.id,
    name: "WSJF Prioritization Engine",
    description: "Automatic WSJF calculation and work prioritization based on business value, time criticality, risk reduction, and job size",
    status: "implementing",
    approved_by: "system"
  })

IO.puts("    Created Capability: #{cap2_2_1.name}")

Repo.insert!(%Feature{
  capability_id: cap2_2_1.id,
  name: "Real-Time WSJF Calculation",
  description: "Calculate and update WSJF scores in real-time as epics/capabilities change",
  status: "in_progress",
  acceptance_criteria: [
    "Recalculates WSJF on every update",
    "Cascades scores to child capabilities",
    "Provides prioritized work queue via get_next_work()"
  ],
  approved_by: "system"
})

# Strategic Theme 3: Production-Grade Infrastructure (1.5 BLOC)
theme3 =
  Repo.insert!(%StrategicTheme{
    name: "Production-Grade Infrastructure",
    description: "Build enterprise-ready infrastructure with monitoring, security, and scalability (1.5 BLOC)",
    target_bloc: 1.5,
    priority: 3,
    status: "active",
    approved_by: "system"
  })

IO.puts("Created Strategic Theme: #{theme3.name}")

# Epic 3.1: Observability Stack (Enabler)
epic3_1 =
  Repo.insert!(%Epic{
    theme_id: theme3.id,
    name: "Observability Stack",
    description: "Comprehensive observability with Prometheus, Grafana, Jaeger, and OpenTelemetry for distributed tracing",
    type: "enabler",
    status: "analysis",
    business_value: 6,
    time_criticality: 6,
    risk_reduction: 8,
    job_size: 15,
    approved_by: "system"
  })

IO.puts("  Created Epic: #{epic3_1.name} (WSJF: #{epic3_1.wsjf_score})")

# Capability 3.1.1: Distributed Tracing
cap3_1_1 =
  Repo.insert!(%Capability{
    epic_id: epic3_1.id,
    name: "Distributed Tracing",
    description: "End-to-end tracing across all services using OpenTelemetry and Jaeger",
    status: "backlog",
    approved_by: "system"
  })

IO.puts("    Created Capability: #{cap3_1_1.name}")

Repo.insert!(%Feature{
  capability_id: cap3_1_1.id,
  name: "OpenTelemetry Integration",
  description: "Integrate OpenTelemetry SDK across all Elixir, Rust, and TypeScript services",
  status: "backlog",
  acceptance_criteria: [
    "Instruments all HTTP/NATS calls",
    "Exports traces to Jaeger",
    "Correlates traces across service boundaries"
  ],
  approved_by: "system"
})

# Epic 3.2: Database Optimization (Enabler)
epic3_2 =
  Repo.insert!(%Epic{
    theme_id: theme3.id,
    name: "Database Optimization",
    description: "Optimize PostgreSQL with pgvector, connection pooling, and query performance tuning",
    type: "enabler",
    status: "ideation",
    business_value: 5,
    time_criticality: 5,
    risk_reduction: 7,
    job_size: 10,
    approved_by: "system"
  })

IO.puts("  Created Epic: #{epic3_2.name} (WSJF: #{epic3_2.wsjf_score})")

# Summary
IO.puts("")
IO.puts("Seed Summary:")
IO.puts("  Strategic Themes: #{Repo.aggregate(StrategicTheme, :count)}")
IO.puts("  Epics: #{Repo.aggregate(Epic, :count)}")
IO.puts("  Capabilities: #{Repo.aggregate(Capability, :count)}")
IO.puts("  Features: #{Repo.aggregate(Feature, :count)}")

total_bloc =
  StrategicTheme
  |> Repo.all()
  |> Enum.map(& &1.target_bloc)
  |> Enum.sum()

IO.puts("  Total BLOC Target: #{total_bloc}")
IO.puts("")
IO.puts("Work plan seeded successfully!")
