defmodule Singularity.Bootstrap.Vision do
  @moduledoc """
  Defines what Singularity should become at each bootstrap stage.

  This is Singularity's "DNA" - the vision that guides its self-development.
  Each stage has specific goals, capabilities to develop, and success criteria.

  ## Philosophy

  Singularity develops itself according to a staged vision:
  1. **Stage 1 (Embryonic)**: Understand what I am
  2. **Stage 2 (Larval)**: Fix my own problems
  3. **Stage 3 (Juvenile)**: Evolve autonomously
  4. **Stage 4 (Adult)**: Help humans develop

  ## Integration Points

  - `Singularity.Bootstrap.EvolutionStageController` - Current stage tracking
  - `Singularity.Execution.Planning.SafeWorkPlanner` - SAFe hierarchical planning system
  - `Singularity.Code.StartupCodeIngestion` - Executes vision-driven tasks

  ## Usage

      # Get vision for current stage
      vision = Vision.get_stage_vision(1)
      # => %{goals: [...], capabilities: [...], success_criteria: [...]}

      # Initialize vision hierarchy in planning system
      Vision.initialize_bootstrap_vision!()

      # Get next improvement task based on vision
      task = Vision.get_next_improvement()
      # => %{description: "Ingest Singularity source code", ...}
  """

  require Logger
  alias Singularity.Execution.Planning.SafeWorkPlanner
  alias Singularity.Bootstrap.EvolutionStageController

  @portfolio_vision %{
    statement: """
    Build a self-improving AI development environment that:
    1. Develops itself first (understands, fixes, evolves its own code)
    2. Learns from its own improvements (pattern mining)
    3. Helps humans develop better software (knowledge transfer)
    4. Operates autonomously with human oversight (trust through validation)
    """,
    target_year: 2026,
    success_metrics: [
      %{metric: "self_improvements_applied", target: 500.0},
      %{metric: "pattern_success_rate", target: 0.90},
      %{metric: "user_project_velocity_increase", target: 2.0},
      %{metric: "autonomous_decision_accuracy", target: 0.95}
    ]
  }

  @stage_1_vision %{
    stage: 1,
    name: "Embryonic - Self-Discovery",
    duration_days: 7,
    goals: [
      "Understand complete Singularity architecture",
      "Map all modules, functions, and dependencies",
      "Identify integration points and data flows",
      "Build comprehensive self-knowledge graph"
    ],
    capabilities_to_develop: [
      %{
        name: "Self-Introspection",
        description: "Ability to analyze own source code and understand architecture",
        success_criteria: [
          "100% of Singularity source ingested into PostgreSQL",
          "Dependency graph complete (module → module)",
          "Integration points documented",
          "Self-knowledge score >= 0.9"
        ]
      },
      %{
        name: "Static Analysis",
        description: "Detect issues without running code",
        success_criteria: [
          "Broken dependencies detected",
          "Missing @moduledocs identified",
          "Unused modules found",
          "Code quality issues cataloged"
        ]
      },
      %{
        name: "Knowledge Organization",
        description: "Structure learnings in queryable format",
        success_criteria: [
          "code_chunks table populated",
          "Semantic embeddings generated",
          "Search works for own codebase",
          "Can answer: 'How does hot reload work?'"
        ]
      }
    ],
    features: [
      %{
        name: "Ingest Singularity Source",
        description: "Parse and store all Singularity source code",
        acceptance_criteria: [
          "All .ex, .exs, .gleam, .rs files parsed",
          "Stored in code_chunks with codebase_type='meta_system'",
          "Embeddings generated for semantic search",
          "Zero crashes during ingestion"
        ],
        estimated_hours: 4
      },
      %{
        name: "Build Module Dependency Graph",
        description: "Map all alias/import/use relationships",
        acceptance_criteria: [
          "Graph stored in PostgreSQL",
          "Can query: 'What depends on Agent?'",
          "Circular dependencies identified",
          "Isolated modules detected"
        ],
        estimated_hours: 6
      },
      %{
        name: "TaskGraph Self-Scan",
        description: "Run StartupCodeIngestion in discovery mode",
        acceptance_criteria: [
          "All issues cataloged (broken deps, missing docs)",
          "Severity scores assigned",
          "Dry-run mode (no fixes applied)",
          "Report generated"
        ],
        estimated_hours: 2
      },
      %{
        name: "Self-Knowledge Queries",
        description: "Answer questions about own architecture",
        acceptance_criteria: [
          "Semantic search works: 'How does NATS work?'",
          "Can find related modules",
          "Integration points discoverable",
          "Example code retrievable"
        ],
        estimated_hours: 8
      }
    ],
    metrics: %{
      codebase_ingestion_complete: true,
      self_knowledge_score: 0.9,
      zero_crashes: true,
      issues_found: {:greater_than, 10}
    }
  }

  @stage_2_vision %{
    stage: 2,
    name: "Larval - Supervised Self-Improvement",
    duration_days: 14,
    goals: [
      "Fix Singularity's own bugs (with human approval)",
      "Improve code quality (docs, types, tests)",
      "Establish validation patterns",
      "Learn from successful fixes"
    ],
    capabilities_to_develop: [
      %{
        name: "Supervised Code Generation",
        description: "Generate fixes that humans review",
        success_criteria: [
          "Approval UI functional",
          "Fixes compiled before showing to user",
          "Rollback mechanism works",
          "Approval rate >= 80%"
        ]
      },
      %{
        name: "Pattern Extraction",
        description: "Learn from successful fixes",
        success_criteria: [
          "Patterns stored after each success",
          "Can retrieve similar fixes",
          "Pattern success rate tracked",
          "Reusable templates created"
        ]
      },
      %{
        name: "Validation & Rollback",
        description: "Ensure fixes don't break things",
        success_criteria: [
          "Compilation verified",
          "Tests run after fix",
          "Metrics monitored (memory, latency)",
          "Auto-rollback on regression"
        ]
      }
    ],
    features: [
      %{
        name: "Fix Missing @moduledocs",
        description: "Generate documentation for all modules",
        acceptance_criteria: [
          "50+ modules documented",
          "Quality >= human-written",
          "Includes integration points",
          "User approves 90%+"
        ],
        estimated_hours: 10
      },
      %{
        name: "Fix Broken Dependencies",
        description: "Add missing or remove invalid aliases",
        acceptance_criteria: [
          "20+ dependency issues fixed",
          "Compilation succeeds",
          "No new dependencies introduced",
          "Tests pass"
        ],
        estimated_hours: 8
      },
      %{
        name: "Agent Self-Improvement Loop",
        description: "Agents improve their own code",
        acceptance_criteria: [
          "10+ agent improvements applied",
          "Metrics improve (cost, latency)",
          "No regressions",
          "Patterns learned"
        ],
        estimated_hours: 16
      },
      %{
        name: "Approval Workflow UI",
        description: "Terminal interface for reviewing fixes",
        acceptance_criteria: [
          "Shows diff, impact, rationale",
          "Approve/reject/defer options",
          "Tracks approval rate",
          "Notifies on completion"
        ],
        estimated_hours: 12
      }
    ],
    metrics: %{
      bugs_fixed: 50,
      agent_improvements: 10,
      approval_rate: 0.8,
      zero_regressions: true,
      patterns_learned: {:greater_than, 10}
    }
  }

  @stage_3_vision %{
    stage: 3,
    name: "Juvenile - Autonomous Self-Development",
    duration_days: 30,
    goals: [
      "Autonomous improvement (no approval needed)",
      "Rich pattern library (50+ patterns)",
      "Proactive evolution (detect stagnation)",
      "Circuit breakers (stop on failure)"
    ],
    capabilities_to_develop: [
      %{
        name: "Autonomous Decision Making",
        description: "Decide when and what to improve",
        success_criteria: [
          "Metrics-based triggers work",
          "WSJF prioritization applied",
          "Confidence thresholds respected",
          "Regression rate < 5%"
        ]
      },
      %{
        name: "Pattern-Driven Development",
        description: "Reuse learned successful patterns",
        success_criteria: [
          "50+ patterns in library",
          "Pattern matching works",
          "Pattern success rate >= 0.9",
          "Can combine multiple patterns"
        ]
      },
      %{
        name: "Circuit Breakers",
        description: "Stop runaway improvements",
        success_criteria: [
          "Stops after 3 consecutive failures",
          "Human notified when tripped",
          "Auto-resumes after manual review",
          "Zero infinite loops"
        ]
      }
    ],
    features: [
      %{
        name: "Autonomous Improvement Loop",
        description: "Full autonomy with guardrails",
        acceptance_criteria: [
          "100+ improvements applied",
          "No human approval required",
          "Validation catches regressions",
          "Circuit breaker works"
        ],
        estimated_hours: 20
      },
      %{
        name: "Pattern Library",
        description: "Comprehensive pattern collection",
        acceptance_criteria: [
          "50+ patterns learned",
          "Patterns exportable to Git",
          "Success rate tracked",
          "Searchable by context"
        ],
        estimated_hours: 12
      },
      %{
        name: "Proactive Evolution",
        description: "Add features before being asked",
        acceptance_criteria: [
          "Stagnation detection works",
          "New features proposed",
          "Based on vision + patterns",
          "Value validated post-deployment"
        ],
        estimated_hours: 16
      },
      %{
        name: "Health Monitoring",
        description: "Real-time metrics and alerts",
        acceptance_criteria: [
          "Memory, CPU, latency tracked",
          "Regression detection < 1 min",
          "Auto-rollback on anomaly",
          "Alert on circuit breaker trip"
        ],
        estimated_hours: 10
      }
    ],
    metrics: %{
      autonomous_improvements: 100,
      patterns_learned: 50,
      regression_rate_below: 0.05,
      circuit_breaker_trips: 0,
      proactive_features_added: {:greater_than, 5}
    }
  }

  @stage_4_vision %{
    stage: 4,
    name: "Adult - Multi-Project Development",
    duration_days: 60,
    goals: [
      "Help develop user projects",
      "Transfer learned patterns",
      "Dual-mode operation (self + user)",
      "Continuous self-maintenance"
    ],
    capabilities_to_develop: [
      %{
        name: "Cross-Project Pattern Transfer",
        description: "Apply Singularity patterns to user code",
        success_criteria: [
          "Pattern transfer success >= 85%",
          "Works across languages",
          "Adapts to user conventions",
          "User satisfaction high"
        ]
      },
      %{
        name: "Multi-Codebase Management",
        description: "Track both Singularity and user projects",
        success_criteria: [
          "10+ user projects ingested",
          "Separate embeddings/patterns",
          "No cross-contamination",
          "Fast context switching"
        ]
      },
      %{
        name: "Self-Maintenance Mode",
        description: "Singularity maintains itself in background",
        success_criteria: [
          "1-2 self-improvements per week",
          "Focus on user projects (80% time)",
          "Self-health score >= 0.95",
          "Zero downtime"
        ]
      }
    ],
    features: [
      %{
        name: "User Project Ingestion",
        description: "Analyze external codebases",
        acceptance_criteria: [
          "10+ user projects ingested",
          "codebase_type='user_project'",
          "Embeddings generated",
          "Searchable alongside Singularity"
        ],
        estimated_hours: 8
      },
      %{
        name: "Pattern Transfer Engine",
        description: "Apply learned patterns to user code",
        acceptance_criteria: [
          "100+ pattern applications",
          "Success rate >= 85%",
          "Language-agnostic",
          "User can override"
        ],
        estimated_hours: 20
      },
      %{
        name: "Dual-Mode Scheduler",
        description: "Balance self-improvement vs user help",
        acceptance_criteria: [
          "80% time on user projects",
          "20% time on self-maintenance",
          "Priority-based scheduling",
          "Human can adjust ratio"
        ],
        estimated_hours: 12
      },
      %{
        name: "Knowledge Transfer Reports",
        description: "Explain what was learned and applied",
        acceptance_criteria: [
          "Weekly reports generated",
          "Shows patterns used",
          "Impact measured",
          "User feedback captured"
        ],
        estimated_hours: 10
      }
    ],
    metrics: %{
      user_projects_ingested: 10,
      pattern_transfer_success: 0.85,
      codebase_health_score: 0.95,
      user_satisfaction: {:greater_than, 0.80},
      # per week
      self_improvement_rate: {:between, 1, 2}
    }
  }

  @stage_visions %{
    1 => @stage_1_vision,
    2 => @stage_2_vision,
    3 => @stage_3_vision,
    4 => @stage_4_vision
  }

  ## Public API

  @doc """
  Get the vision for a specific bootstrap stage.
  """
  def get_stage_vision(stage) when stage in 1..4 do
    @stage_visions[stage]
  end

  @doc """
  Get the vision for the current bootstrap stage.
  """
  def get_current_vision do
    stage = EvolutionStageController.get_current_stage()
    get_stage_vision(stage)
  end

  @doc """
  Initialize the full bootstrap vision in SafeWorkPlanner.

  Creates strategic themes, epics, capabilities, and features for all 4 stages.
  This gives Singularity a complete roadmap for self-development.
  """
  def initialize_bootstrap_vision! do
    Logger.info("Initializing Bootstrap Vision in planning system...")

    # Note: SafeWorkPlanner manages work items via add_chunk/2
    # Portfolio vision can be set via a high-level chunk
    SafeWorkPlanner.add_chunk(@portfolio_vision.statement)

    # Create strategic theme for each stage
    Enum.each(@stage_visions, fn {stage_num, vision} ->
      create_stage_theme(stage_num, vision)
    end)

    Logger.info("✓ Bootstrap vision initialized with 4 stages")
    :ok
  end

  @doc """
  Get the next improvement task based on current stage vision.
  """
  def get_next_improvement do
    vision = get_current_vision()
    # Get highest priority feature that's not started
    vision.features
    |> Enum.find(fn feature ->
      # Check if feature is done (would query SingularityVision)
      not feature_completed?(feature.name)
    end)
  end

  @doc """
  Check if current stage vision is complete.
  """
  def stage_vision_complete? do
    vision = get_current_vision()
    metrics = EvolutionStageController.status().metrics

    Enum.all?(vision.metrics, fn {key, required_value} ->
      actual = Map.get(metrics, key)
      meets_requirement?(actual, required_value)
    end)
  end

  ## Private Functions

  defp create_stage_theme(stage_num, vision) do
    # Add stage vision as a chunk to SafeWorkPlanner
    # SafeWorkPlanner will classify and create appropriate work items
    stage_description = """
    Bootstrap Stage #{stage_num}: #{vision.name}

    Goals:
    #{Enum.map_join(vision.goals, "\n", fn goal -> "- #{goal}" end)}

    Duration: #{vision.duration_days} days

    Capabilities to develop:
    #{Enum.map_join(vision.capabilities_to_develop, "\n", fn cap -> "- #{cap.name}: #{cap.description}" end)}
    """

    SafeWorkPlanner.add_chunk(stage_description)

    # Add each feature as a separate work item
    Enum.each(vision.features, fn feature ->
      create_feature_chunk(feature)
    end)
  end

  defp create_feature_chunk(feature_def) do
    feature_description = """
    #{feature_def.name}

    #{feature_def.description}

    Acceptance Criteria:
    #{Enum.map_join(feature_def.acceptance_criteria, "\n", fn criteria -> "- #{criteria}" end)}
    """

    SafeWorkPlanner.add_chunk(feature_description)
  end

  defp feature_completed?(_feature_name) do
    # Would query SafeWorkPlanner for feature status
    # For now, assume not completed
    false
  end

  defp meets_requirement?(actual, required) when is_boolean(required) do
    actual == required
  end

  defp meets_requirement?(actual, required) when is_number(required) do
    is_number(actual) and actual >= required
  end

  defp meets_requirement?(actual, {:greater_than, min}) do
    is_number(actual) and actual > min
  end

  defp meets_requirement?(actual, {:less_than, max}) do
    is_number(actual) and actual < max
  end

  defp meets_requirement?(actual, {:between, min, max}) do
    is_number(actual) and actual >= min and actual <= max
  end

  defp meets_requirement?(_actual, _required), do: false
end
