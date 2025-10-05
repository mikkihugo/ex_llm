# Singularity Agents (October 2025)

Singularity runs a fleet of BEAM-native agents that combine deterministic rule
execution with selective LLM usage. This write-up replaces the previous grab-bag
of tooling notes with the architecture that is actually wired into
`singuarity_app/lib/singularity/` today.

---

## Runtime Components

| Module | Role |
|--------|------|
| `Singularity.AgentSupervisor` | Dynamic supervisor for long-lived agents (one per domain/specialisation). |
| `Singularity.Agent` | Core self-improving loop. Keeps metrics, triggers evolutions, hands code to the hot-reload pipeline. |
| `Singularity.Agents.HybridAgent` | Task worker used by orchestrators to process individual requests. Executes rule engine first, falls back to cached LLM responses, then to live LLM calls. |
| `Singularity.Autonomy.Decider` | Evaluates metrics (success rate, stagnation, WSJF priorities) to determine when agents should evolve. |
| `Singularity.Autonomy.Planner` | Breaks work into SPARC phases and hands plans to the execution coordinator. |
| `Singularity.ExecutionCoordinator` | Coordinates task queues, Git integration, and downstream quality checks. |
| `Singularity.RuleEngineV2` | Cost-free strategy layer. Rules are persisted in Postgres and cached in ETS/Cachex. |

Every agent process tracks its own history (`improvement_history`), stored
fingerprints (to avoid repeating the same patch) and pending improvements. The
loop is timer-driven (default tick: 5 s) and is resilient to crashes thanks to
the dynamic supervisor.

---

## Lifecycle Summary

```
1. Agent ticks (every 5s) → Autonomy.Decider.decide/1
2. If improvement needed:
   a. Planner.build_plan/2 produces SPARC plan
   b. ExecutionCoordinator dispatches plan to HybridAgent workers
   c. HybridAgent processes tasks:
        • RuleEngineV2.execute_category/3 (90% coverage)
        • Semantic cache lookup (vector similarity)
        • LLM.Provider.call/2 (only if necessary)
   d. Generated code forwarded to HotReload.ModuleReloader
3. Hot reload validates, compiles, and activates new module
4. Agent updates metrics via record_outcome/2 and continues loop
```

Because the HybridAgent reports cost and results back to the caller, the
decider can track lifetime spend per agent and prefer rule-based solutions when
possible.

---

## Creating & Managing Agents

```elixir
# Start an agent under the supervisor (see Application children)
{:ok, pid} = Singularity.AgentSupervisor.start_child(%{specialisation: :architecture})

# Enqueue an improvement payload manually (usually done by Planner/Coordinator)
:ok = Singularity.Agent.improve("architecture", %{description: "Reduce latency"})

# Record outcomes to influence the next decision cycle
:ok = Singularity.Agent.record_outcome("architecture", :success)

# Inspect current metrics/state
:sys.get_state(Singularity.Agent.via_tuple("architecture"))
```

Hybrid workers are addressed by ID. They are cheap to start/stop because they
run under `GenServer` and avoid per-task process churn:

```elixir
{:ok, _} = Singularity.Agents.HybridAgent.start_link(id: "reviewer-1", specialisation: :code_review)

{mode, result, cost: dollars} =
  Singularity.Agents.HybridAgent.process_task("reviewer-1", %{
    id: "PR-1827",
    prompt: "Review auth refactor",
    context: %{repo: "singularity"},
    complexity: :medium
  })

# => {:autonomous, %{diff: ...}, cost: 0.0}    # handled entirely by rules/cache
```

`HybridAgent.process_task/2` returns `:autonomous`, `:cached`, or
`:llm_assisted`. When an LLM call is made it records the exact provider/model,
cost in USD, and latency so higher-level coordinators can reason about budget.

---

## Rule Engine + LLM Cooperation

1. **Rule pass** – `RuleEngineV2.execute_category/3` runs zero-cost heuristics
   (all persisted as JSONB in the `rules` table). Results with ≥0.9 confidence
   are accepted immediately.
2. **Semantic cache** – requests are embedded and compared against prior LLM
   responses stored in `semantic_cache`. Hits are free and carry the original
   instructions/adaptations.
3. **LLM fallback** – only 5% of cases reach `LLM.Provider.call/2`. The worker
   picks the cheapest model that satisfies the requested complexity and logs
   cost statistics through `Singularity.LLM.Telemetry`.

Rule definitions can be added via `RuleEngineV2.load_rules_from_dir/1` or the
upcoming rule authoring UI. Because rules live in Postgres, they persist across
restarts and can be introspected easily:

```elixir
# Inspect cached rules for a category
Singularity.Autonomy.RuleLoader.get_rules_by_category(:code_quality)
```

---

## Integration Points

- **Planning**: `Singularity.Planning.SingularityVision` feeds feature/epic
  priorities into the decider via WSJF scores.
- **Quality**: `Singularity.Quality` surfaces test failures, coverage gaps, and
  static-analysis findings. Agents treat regressions as high-priority triggers.
- **Package Knowledge**: `Singularity.PackageRegistryKnowledge` and
  `Singularity.PatternIndexer` provide context for selecting libraries or code
  patterns before hitting an LLM.
- **Git Coordination**: optionally enable `Singularity.Git.Supervisor` to hand
  each agent an isolated working tree and push branches automatically.
- **NATS**: HybridAgent emits events (`execution.task.started/completed`) via
  `Singularity.ExecutionCoordinator` so external observers can track progress.

---

## Operational Tips

- Toggle tick duration via `AGENT_TICK_MS` (defaults to 5000) to accelerate or
  slow down the evolution loop in development environments.
- Use `Singularity.Agent.force_improvement/2` when you need to trigger a manual
  iteration, e.g. after a human review.
- `Singularity.AgentSupervisor.children/0` returns PIDs for all running agents
  if you need to introspect state or attach a tracer.
- Combine `Singularity.ExecutionCoordinator.pause_queue/1` with the agent API
  to drain queues gracefully during deploys.

---

## Interface Architecture

Agents and tools are accessed via **two interfaces**:

1. **MCP Interface** (`lib/singularity/interfaces/mcp.ex`)
   - For AI assistants (Claude Desktop, Cursor, Continue.dev)
   - Returns MCP-formatted responses

2. **NATS Interface** (`lib/singularity/interfaces/nats.ex`)
   - For distributed microservices
   - Request/Reply and Pub/Sub patterns


**Key Point**: Tools are interface-agnostic. Same tools work across all interfaces without duplication. See [INTERFACE_ARCHITECTURE.md](INTERFACE_ARCHITECTURE.md) for details.

---

For deeper code references, check:
- `singularity_app/lib/singularity/agent*.ex`
- `singularity_app/lib/singularity/autonomy/`
- `singularity_app/lib/singularity/agents/hybrid_agent.ex`
- `singularity_app/lib/singularity/execution_coordinator.ex`
- `singularity_app/lib/singularity/interfaces/` - Interface implementations
- `singularity_app/lib/singularity/tools/` - Core tool definitions

Those modules are the source of truth and should be consulted for contract or
API changes.
