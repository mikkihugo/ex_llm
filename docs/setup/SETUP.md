# Singularity - Autonomous Self-Evolving Agent System

**Complete refactor integrating:**
- ✅ **SAFe 6.0 Essential** hierarchy (Strategic Themes → Epics → Capabilities → Features)
- ✅ **WSJF prioritization** (Weighted Shortest Job First - automatic)
- ✅ **Incremental vision chunks** (send chunks anytime, system self-organizes)
- ✅ Google Chat human interface (mobile + desktop)
- ✅ HTDAG task decomposition (hierarchical DAG)
- ✅ SPARC methodology (Specification → Pseudocode → Architecture → Refinement → Completion)
- ✅ Need-based refactoring (automatic tech debt detection)
- ✅ Pattern mining from trial codebases (learns from history)
- ✅ Multi-language support (Elixir + Gleam hybrid)

**Designed for 750M LOC systems** - no monolithic planning required!

---

## Quick Start

### 1. Prerequisites

```bash
# Elixir 1.20+ and OTP 28+
elixir --version

# Gleam 1.5+
gleam --version

# PostgreSQL with pgvector (for pattern embeddings)
psql --version
```

### 2. Configure Google Chat

1. Go to: https://chat.google.com
2. Create a Space: "Autonomous Agent"
3. Space → Manage webhooks → Add webhook
4. Copy webhook URL
5. Set environment variable:

```bash
export GOOGLE_CHAT_WEBHOOK_URL="https://chat.googleapis.com/v1/spaces/.../messages?key=..."
```

### 3. Install Dependencies

```bash
cd singularity
mix deps.get
mix gleam.deps.get
```

### 4. Run the System

```bash
# Development
iex -S mix

# Production
HTTP_SERVER_ENABLED=true PORT=4000 mix run --no-halt
```

---

## Architecture Overview

### Core Components (Existing - Untouched)

| Module | Purpose |
|--------|---------|
| `Singularity.Agent` | Self-improving agent loop (tick → decide → improve) |
| `Singularity.Autonomy.{Decider, Limiter}` | Evolution triggers and rate limiting |
| `Singularity.HotReload.Manager` | Hot code swap pipeline |
| `Singularity.CodeStore` | Persistence (versions, queues, vision) |
| `Singularity.Analysis.*` | Code metrics (complexity, quality, Halstead) |
| `Singularity.Integration.*` | LLM clients (Claude, Gemini, Copilot) |
| `Singularity.Tools.*` | Tool registry and execution |

### New Components (Added)

| Module | Purpose | Language |
|--------|---------|----------|
| `Singularity.Conversation.Agent` | Human interface manager | Elixir |
| `Singularity.Conversation.GoogleChat` | Google Chat client | Elixir |
| `Singularity.Planning.SingularityVision` | **SAFe 6.0 Essential** hierarchy + WSJF | Elixir |
| `Singularity.Planning.HTDAG` | Hierarchical task DAG | **Gleam** |
| `Singularity.Planning.HTDAG` (wrapper) | Elixir wrapper for Gleam HTDAG | Elixir |
| `Singularity.Planning.StoryDecomposer` | SPARC implementation | Elixir |
| `Singularity.Refactoring.Analyzer` | Tech debt detection → creates refactoring epics | Elixir |
| `Singularity.Learning.PatternMiner` | Pattern extraction from trials | Elixir |
| `Singularity.Autonomy.Planner` | **UPDATED** - uses SingularityVision WSJF prioritization | Elixir |

---

## How It Works (SAFe 6.0 Essential Workflow)

### 1. Send Vision Chunks Incrementally

**You don't need a monolithic vision!** Send chunks anytime - the system self-organizes them into SAFe hierarchy.

```elixir
# Start with Strategic Themes (3-5 year vision areas)
alias Singularity.Planning.SingularityVision

SingularityVision.add_chunk(
  "Build world-class observability platform - target 2.5 BLOC",
  approved_by: "architect@example.com"
)

SingularityVision.add_chunk(
  "Create unified data platform - target 3.0 BLOC",
  approved_by: "architect@example.com"
)

# Later, add Epics under themes
SingularityVision.add_chunk(
  "Implement distributed tracing across all microservices",
  relates_to: "observability",
  approved_by: "lead@example.com"
)

# Then add Capabilities
SingularityVision.add_chunk(
  "Trace collection from Kubernetes pods using OpenTelemetry",
  relates_to: "distributed-tracing",
  approved_by: "team-lead@example.com"
)

# Finally add Features
SingularityVision.add_chunk(
  """
  Implement OpenTelemetry collector sidecar for pods

  Acceptance criteria:
  - Auto-inject collector into all pods
  - Support trace, metrics, and logs
  - < 5% CPU overhead
  """,
  relates_to: "trace-collection-k8s",
  approved_by: "engineer@example.com"
)
```

**System automatically:**
- Determines hierarchy level (Theme/Epic/Capability/Feature)
- Finds relationships to existing items
- Calculates WSJF priority scores
- Resolves dependencies

**Or via Google Chat:** Send chunks via chat interface (coming soon).

### 2. Agent Loop (Every 5 seconds) - WSJF Prioritized

```
Tick → Decider.decide(state)
  ↓
Check priorities (in order):
  1. Critical refactoring? → Generate fix (creates refactoring epic)
  2. Highest WSJF feature ready? → Decompose with HTDAG + SPARC
  3. Stagnation? → Simple improvement
  ↓
Generate code → Hot reload → Validate → Learn → Mark feature complete
  ↓
Unlock dependent capabilities → Recalculate WSJF → Select next work
```

### 3. SAFe-Driven Execution Flow

```
Strategic Theme: "Observability Platform (2.5 BLOC)"
  ↓
Epic: "Distributed Tracing" (WSJF: 7.5 - high priority)
  ↓
Capability: "Trace Collection from K8s" (depends on: Service Mesh)
  ↓ (waits for dependency)
Capability: "Service Mesh Infrastructure" completes
  ↓ (dependency met)
Feature: "OpenTelemetry Sidecar" (highest WSJF, ready to work)
  ↓
Agent selects this feature → Creates HTDAG
  ↓
HTDAG.decompose() → Recursive task breakdown
  ├─ Story: Design sidecar injection
  │   ├─ Task: Write mutating webhook
  │   └─ Task: Create ConfigMap template
  ├─ Story: Implement collector
  │   ├─ Task: Configure OTLP receiver
  │   └─ Task: Configure exporters
  └─ Story: Test and validate
      ├─ Task: Load testing
      └─ Task: Latency verification
  ↓
Select first task → SPARC decomposition
  ├─ S: Generate specification (webhook API contract)
  ├─ P: Write pseudocode (validation logic)
  ├─ A: Design architecture (admission controller)
  ├─ R: Refine design (security review)
  └─ C: Generate completion tasks
  ↓
Generate code (using learned patterns) → Deploy → Validate
  ↓
All tasks complete → Mark feature done
  ↓
Feature done → Check if capability done
  ↓
Capability done → Unlock dependent capabilities
  ↓
Agent selects next highest WSJF feature
```

### 4. Refactoring Triggers → Automatic Epics

**Automatic detection creates refactoring epics:**

```elixir
Singularity.Refactoring.Analyzer.analyze_refactoring_need()
# Returns:
[
  %{
    type: :code_duplication,
    severity: :critical,  # or :high, :medium
    affected_files: [...],
    suggested_goal: "Extract 15 duplicated patterns",
    business_impact: "Reduces maintenance burden",
    estimated_hours: 7.5
  }
]

# If severity == :critical, system creates a refactoring epic:
SingularityVision.add_chunk(
  "Extract 15 duplicated validation patterns into shared module",
  type: :enabler_epic,
  auto_created: true,
  wsjf_override: 99.0  # Critical refactoring always highest priority
)
```

**Agent automatically prioritizes critical refactorings over all other work.**

### 5. Pattern Learning

```elixir
# Mine patterns from old trials
Singularity.Learning.PatternMiner.mine_patterns_from_trials([
  "trials/2024-01-attempt1",
  "trials/2024-03-attempt2"
])

# Returns:
[
  %{
    pattern: "GenServer with Circuit Breaker",
    success_rate: 0.92,
    from_trials: ["attempt1", "attempt2"],
    code_snippet: "..."
  }
]
```

**Agent retrieves relevant patterns when generating code.**

---

## Human Interface (Google Chat)

### What You'll Receive

**Daily Summary (9am):**
```
☀️ Daily Agent Report

✅ Completed: 12 tasks
⚠️  Failed: 1 task
🚀 Deployed: 8 changes
📈 Avg Confidence: 96%

💡 Top recommendation: Refactor user validation (saves 400 LOC)

[📊 View Dashboard]
```

**Questions:**
```
🤔 Agent Question

Should I optimize the database now or wait until off-hours?

Context: Current load: 45%, estimated downtime: 2 minutes

[💬 Answer]
```

**Recommendations:**
```
💡 Agent Recommendation

Extract 15 duplicated validation functions into shared module

📊 Impact: 15 files
⏱️ Time: 2 hours
🎯 Confidence: 94%

[✅ Approve] [❌ Reject]
```

**Deployments:**
```
✅ Deployment success

Optimized database queries for posts table

📦 Version: 1234
⏱️ Time: 2 minutes ago
🎯 Confidence: 97%
```

**Policy Changes:**
```
⚙️ Policy Updated

I adjusted deployment settings

Min Confidence: 95% → 94%

Reason: High success rate (98%) - increasing speed

📈 Recent success rate: 98%
📊 Sample size: 100 tasks
```

### Interacting with the Agent

**Via Google Chat buttons** → Opens web form → Submit

**Via IEx:**
```elixir
# Answer a question
Singularity.Conversation.Agent.human_message("user_id",
  %{conversation_id: "conv-123", answer: "Yes, optimize now"},
  :google_chat
)

# Approve recommendation
Singularity.Conversation.Agent.human_message("user_id",
  %{conversation_id: "rec-456", answer: {:approved, "looks good"}},
  :google_chat
)

# Set new vision
Singularity.Planning.Vision.set_vision("New strategic goal", approved_by: "user_id")

# Pause autonomous actions
Singularity.Conversation.Agent.human_message("user_id",
  %{action: :pause},
  :google_chat
)
```

---

## Configuration

### Environment Variables

```bash
# Required
GOOGLE_CHAT_WEBHOOK_URL="https://chat.googleapis.com/..."

# Optional
WEB_URL="https://yourdomain.com"  # For button links (default: localhost:4000)
HTTP_SERVER_ENABLED="true"         # Enable web UI
PORT="4000"                        # HTTP port

# Agent Behavior
IMP_LIMIT_PER_DAY="100"           # Max improvements per day
IMP_VALIDATION_DELAY_MS="30000"   # Validation delay before finalizing
MIN_CONFIDENCE_THRESHOLD="95"      # Initial deployment confidence threshold

# LLM Providers (at least one required)
CLAUDE_CODE_OAUTH_TOKEN="..."     # Claude API token
GEMINI_API_KEY="..."              # Gemini API key
GITHUB_TOKEN="..."                # For GitHub Copilot

# Database (for pattern embeddings)
DATABASE_URL="postgresql://..."
```

---

## Development Workflow

### Run Tests

```bash
mix test
gleam test
```

### Check Code Quality

```bash
mix format
mix credo --strict
mix dialyzer
```

### Analyze Codebase

```bash
# Run Rust analyzer (if available)
analysis-suite analyze ./singularity

# View analysis in Elixir
iex -S mix
Singularity.Analysis.Summary.fetch_latest()
```

### Mine Patterns from Trials

```bash
iex -S mix
Singularity.Learning.PatternMiner.mine_patterns_from_trials([
  "/path/to/trial1",
  "/path/to/trial2"
])
```

---

## Deployment

### Fly.io (Recommended)

```bash
# Set secrets
fly secrets set GOOGLE_CHAT_WEBHOOK_URL="..."
fly secrets set CLAUDE_CODE_OAUTH_TOKEN="..."
fly secrets set RELEASE_COOKIE="$(openssl rand -base64 32)"

# Deploy
fly deploy
```

### Docker

```bash
docker build -t singularity .
docker run -e GOOGLE_CHAT_WEBHOOK_URL="..." singularity
```

---

## Troubleshooting

### Agent not sending Google Chat messages

Check webhook URL:
```elixir
Application.get_env(:singularity, :google_chat_webhook_url)
```

Test manually:
```elixir
Singularity.Conversation.GoogleChat.notify("Test message")
```

### Vision not loading

Check persistence:
```bash
ls -la code/vision.json
```

Load manually:
```elixir
Singularity.CodeStore.load_vision()
```

### HTDAG Gleam compilation errors

Recompile Gleam:
```bash
mix gleam.build
```

### Pattern mining not finding trials

Ensure `analysis-suite` is installed and in PATH:
```bash
which analysis-suite
```

---

## What's Next

1. **Implement LLM code generation** in `Planner.generate_implementation_code/3`
2. **Add database embeddings** for pattern storage (pgvector)
3. **Implement N+1 query detection** in `Refactoring.Analyzer`
4. **Add more SPARC phases** for architecture design
5. **Create web UI** for dashboard and approvals
6. **Add voice notifications** for critical issues

---

## License

See LICENSE file.

## Contributing

This is an autonomous system - it contributes to itself! 🤖
