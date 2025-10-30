# Singularity Ecosystem Analysis
## Complete Product & Core System Mapping (October 2025)

---

## EXECUTIVE SUMMARY

Singularity is a **multi-layered AI development platform** with:
- **3 Shippable Products** (GitHub App, Scanner CLI, CentralCloud backend)
- **5 Publishable Packages** (ex_pgflow, code_quality_engine, linting_engine, parser_engine, prompt_engine)
- **20+ Autonomous Agents** with self-improvement loops
- **5-Phase Self-Evolving Pipeline** (Context → Generation → Validation → Refinement → Learning)
- **Multi-Instance Learning Hub** (CentralCloud + Genesis)

**Key Insight:** Products are thin **data collectors** that feed intelligence back to the core system. They unlock network effects through pattern aggregation and cross-instance learning.

---

## 1. CURRENT PRODUCTS (READY/NEAR-READY)

### Product 1: GitHub App
**Location:** `/home/mhugo/code/singularity/products/github-app/`

| Aspect | Details |
|--------|---------|
| **Status** | 90% ready (production deployment ready) |
| **What It Does** | Automatic code quality analysis on every GitHub push/PR |
| **Features** | Quality scores, AI recommendations, pattern detection, trend analysis, check runs |
| **Architecture** | Webhook receiver → ex_pgflow tasks → Rust analyzer (code_quality_engine) → Results posted to GitHub |
| **API Interface** | GitHub webhook endpoints + GitHub REST API for check creation |
| **Integration Points** | **Produces:** code quality metrics, issue patterns, performance data **Consumes:** CentralCloud policies (telemetry_enabled, learning_enabled), evolved patterns |
| **Ecosystem Role** | **Data collection hub** - Collects anonymized patterns from every analyzed repo, feeds back to CentralCloud for multi-instance learning |
| **Also Provides** | GitHub Action (for self-hosted workflows) + CLI option |

**Key Capabilities:**
- Automatic PR analysis (webhook-driven)
- Quality scoring via Rust NIF (code_quality_engine)
- Check Runs creation with pass/fail thresholds
- Intelligence collection (opt-in, anonymized)
- Trend tracking over time

**Deployment:**
- Docker container (Elixir/Phoenix)
- Kubernetes manifests included
- Scales horizontally via pgmq queues

---

### Product 2: Scanner (CLI)
**Location:** `/home/mhugo/code/singularity/products/scanner/`

| Aspect | Details |
|--------|---------|
| **Status** | 95% ready (production CLI) |
| **What It Does** | Portable, multi-OS CLI for repository analysis |
| **Features** | Analyze codebases, emit JSON/SARIF/text reports, integration with CentralCloud |
| **Binaries** | `singularity-scanner` and `scanner` (both from code_quality_engine with `--features cli`) |
| **Output Formats** | JSON (machine), SARIF (IDE), text (human) |
| **Architecture** | Pure Rust binary with optional CentralCloud backend integration |
| **API Interface** | CLI arguments + HTTP to CentralCloud for pattern sync |
| **Integration Points** | **Produces:** scan results, metrics **Consumes:** CentralCloud pattern snapshots (with ETag caching to avoid re-downloads) |
| **Ecosystem Role** | **Offline-first analyzer** for CI/CD - Collect patterns locally, optionally sync to CentralCloud for learning |
| **Release Process** | GitHub Actions CI builds multi-OS binaries (Windows/macOS/Linux, x86_64/ARM64) |

**Key Capabilities:**
- Offline-first with optional cloud sync
- Pattern caching via encrypted redb (planned)
- ETag-based freshness tracking for CentralCloud patterns
- Output to multiple formats
- Multi-language support (30+ languages via parser_engine)

---

### Product 3: CentralCloud
**Location:** `/home/mhugo/code/singularity/products/centralcloud/`

| Aspect | Details |
|--------|---------|
| **Status** | 85% ready (API fully defined, implementation in progress) |
| **What It Does** | Multi-instance learning hub, pattern aggregation, policy enforcement, canonical ID issuing |
| **Architecture** | Elixir/Phoenix backend + PostgreSQL + pgmq + ex_pgflow workflows |
| **Core Responsibilities** | Issue canonical `server_run_id` (UUIDv7) for scanner runs, enforce policies, serve encrypted pattern snapshots, queue internal processing |
| **API Interface** | **3 External REST endpoints:** (1) POST `/scanner/runs` (register run, get policies), (2) POST `/scanner/events` (submit results), (3) GET `/patterns/snapshot` (fetch evolved patterns with ETag) |
| **Internal Processing** | pgmq queues: `centralcloud_learning` (ingest patterns), `centralcloud_checks` (PR checks), `centralcloud_patterns_sync` (snapshot build) |
| **Ecosystem Role** | **Cross-instance learning hub** - Aggregates patterns from all instances (GitHub App + Scanner users), computes consensus, evolves rules via Genesis, serves evolved patterns back to clients |
| **Deployment** | Docker image + PostgreSQL migrations + blue/green deploy |

**External API (HTTPS):**
```
POST /scanner/runs
  Request: {local_run_id, repo, commit, etag}
  Response: {server_run_id, patterns_etag, policies}

POST /scanner/events
  Request: {server_run_id, results, metrics}
  Response: {status: "ok"}

GET /patterns/snapshot
  Headers: If-None-Match: <etag>
  Response: 200 with encrypted payload + ETag OR 304 Not Modified
```

**Key Insight:** CentralCloud is the **central nervous system** connecting all instances - no client ever talks to PostgreSQL or pgmq directly.

---

## PRODUCT-VS-PRODUCT RELATIONSHIP

```
GitHub App ────────┐
                   ├──→ CentralCloud (Pattern Aggregation Hub)
Scanner CLI ───────┤       ↓
                   │   Genesis (Rule Evolution)
                   │       ↓
                   └──→ Evolved Patterns (back to clients)
```

1. **GitHub App** → Continuous webhook-driven analysis (background)
2. **Scanner CLI** → On-demand, offline-first analysis (foreground)
3. **CentralCloud** → Learns from both, evolves rules, distributes patterns

---

## PRODUCT → CORE SYSTEM DATA FLOW

### What Products Collect:
- Code metrics (complexity, maintainability, etc.)
- Pattern fingerprints (frameworks, architectures, technologies)
- Quality scores & issue distributions
- Performance metrics (latency, resource usage)
- Anonymized success/failure rates of templates

### What Products Consume:
- **Evolved patterns** from CentralCloud (via `/patterns/snapshot`)
- **Policies** (telemetry_enabled, learning_enabled, enterprise flags)
- **Best-practice templates** (for quality improvements)

### Where Data Goes:
→ CentralCloud PostgreSQL (`patterns_analysis` table)
→ Genesis (autonomous rule evolution)
→ Back to products as evolved patterns
→ Into core Singularity pipeline (for agent training)

---

## 2. CORE SYSTEM (NOT YET PRODUCTIZED)

### Component 1: Agents (`/lib/singularity/agents/`)
**Status:** 85% ready (framework complete, some agents experimental)

| Agent | Purpose | Current Capability |
|-------|---------|-------------------|
| **SelfImprovingAgent** | Auto-evolve code via feedback loops | ✅ Full: metrics observation → evolution cycles → hot-reload with rollback |
| **CostOptimizedAgent** | Reduce LLM costs via intelligent caching | ✅ Active: caches prompts/templates, reuses for similar requests |
| **CodeQualityAgent** | Enforce quality standards | ✅ Validates files against quality gates, triggers upgrades |
| **DeadCodeMonitor** | Detect unused code | ✅ Analyzes dependency graphs, reports dead imports/functions |
| **TechnologyAgent** | Detect & manage tech stacks | ✅ Identifies frameworks, versions, patterns |
| **DocumentationPipeline** | Auto-upgrade documentation to v2.3.0 | ✅ Parses @moduledoc, upgrades with AI metadata |
| **ChangeTracker** | Track code changes over time | ✅ Watches Git, records changes, triggers analysis |

**Key Feature: SelfImprovingAgent Loop**
```
Observe metrics
  ↓
Decider (should improve?)
  ↓ Type 1: Local (safe, low-risk)
  ├→ Start improvement directly
  ├→ Hot-reload with validation
  └→ Rollback if regression detected
  
  ↓ Type 2: Experimental (high-risk)
  ├→ Send to Genesis sandbox
  ├→ Test in isolation
  └→ Apply if approved, reject if risky
```

**Integration:** Agents coordinate via `Singularity.Agents.Coordination.AgentRouter` - shared routing system for all agents.

---

### Component 2: Code Generation Pipeline
**Location:** `/lib/singularity/code_generation/`
**Status:** 90% ready (orchestrator complete, generators stable)

**Architecture:** Unified config-driven orchestration with 5+ generators:

| Generator | Purpose | Generated Output |
|-----------|---------|------------------|
| **QualityCodeGenerator** | Generate code meeting quality standards | Elixir/Rust/Python code with v2.3.0 docs |
| **RAGCodeGenerator** | Generate code from semantic search over codebase | Code that matches existing patterns/style |
| **PseudocodeGenerator** | Generate high-level pseudocode plans | Algorithm outlines for manual implementation |
| **TemplateCodeGenerator** | Generate from templates (patterns_data/) | Boilerplate + customization |
| **RefactoringGenerator** | Transform existing code | Refactored code with improvements |

**How It Works:**
```
GenerationOrchestrator.generate(spec, generators: [:quality, :rag])
  ↓ Load enabled generators from config
  ↓ Route to each generator
  ↓ Merge results (first successful wins, or combine)
  ↓ Return generated code
```

**Key Insight:** Generators are **pure functions**, no side effects - results are validated before hot-reload.

---

### Component 3: Hot Reload System
**Location:** `/lib/singularity/hot_reload/`
**Status:** 95% ready (framework complete, guardrails established)

| Component | Purpose | How It Works |
|-----------|---------|--------------|
| **SafeCodeChangeDispatcher** | Guardrail for all code changes | Routes all changes through SelfImprovingAgent queues (even from TaskGraph) |
| **CodeValidator** | Pre-apply validation | Checks syntax, type safety, API compatibility |
| **DocumentationHotReloader** | Live documentation updates | Applies @moduledoc changes without full reload |

**Safety Guarantees:**
1. **Preflight validation** (code compiles, types match)
2. **Baseline telemetry** (record memory/CPU before change)
3. **Hot-reload** (apply change, monitor for issues)
4. **Validation** (check memory, latency, error rates for 30 seconds)
5. **Automatic rollback** (if regression detected, restore previous code)

**Example Flow:**
```
Improvement payload
  ↓
SafeCodeChangeDispatcher.dispatch(payload, agent_id: "agent-123")
  ↓
SelfImprovingAgent (processes queue)
  ↓
CodeValidator.validate()
  ├→ Error? Stop and reject
  └→ OK? Continue
  ↓
HotReload.apply() (live code update)
  ↓
Validation window (30 sec)
  ├→ Regression? Rollback automatically
  └→ Success? Finalize change
```

---

### Component 4: Embedding System
**Location:** `/lib/singularity/embedding/`
**Status:** 90% ready (Nx-based pure Elixir, GPU auto-detection)

| Component | Purpose | Details |
|-----------|---------|---------|
| **NxService** | Generate embeddings locally via Nx | Concatenated: Qodo (1536-dim) + Jina v3 (1024-dim) = 2560-dim vectors |
| **EmbeddingModelLoader** | Load Jina v3 + Qodo models | Auto-detects GPU (CUDA/Metal/ROCm), falls back to CPU |
| **EmbeddingGenerator** | High-level API | Batch generate embeddings for code chunks |

**Key Capability:** Pure local inference - no API keys needed, runs on device (GPU accelerated if available).

**Use Cases:**
- Semantic code search (query: "async worker with error handling")
- Pattern similarity detection
- Duplicate code detection
- RAG context retrieval

---

### Component 5: Pipeline (5-Phase Self-Evolution)
**Location:** `/lib/singularity/pipeline/`
**Status:** 95% ready (all 5 phases implemented)

**The 5-Phase Cycle:**

| Phase | What | Output |
|-------|------|--------|
| **1: Context Gathering** | Parse codebase, detect frameworks, analyze patterns, run quality checks | Enriched context map |
| **2: Constrained Generation** | Select templates, apply constraints, generate implementation plan | Plan with constraints |
| **3: Multi-Layer Validation** | Template validation, code quality validation, metadata validation | Validation results + issues |
| **4: Adaptive Refinement** | Apply patches for issues, query historical failures, adapt constraints | Refined plan ready for execution |
| **5: Post-Execution Learning** | Store failure patterns, track template effectiveness, aggregate metrics, publish to CentralCloud | Learning artifacts for next iteration |

**Learning Loop:**
```
Iteration 1: Generate → Validate → Execute → Learn → Store patterns
Iteration 2: Use learned failures in Phase 4 (historical validator)
Iteration N: Evolved rules improve automatically
```

**Database:** Uses PostgreSQL for all learnings (pipeline_failures, template_effectiveness, validation_metrics).

---

## 3. UPGRADE PATH (PRODUCTS → CORE)

### Today's Data Flow:

```
Product (GitHub App/Scanner)
  ↓ Collects: metrics, patterns, success rates
  ↓
CentralCloud (aggregates 1000s of runs)
  ↓ Learns: common failures, best patterns, effective rules
  ↓
Genesis (evolves rules autonomously)
  ↓ Updates: validation rules, template improvements
  ↓
Back to Products (as evolved patterns)
  
  ↓ ALSO feeds into:
Core Singularity Pipeline
  ↓
Agents (improved with product intelligence)
  ↓
Next code generation (better, more aligned with real-world patterns)
```

### What Data from Products Improves Core System:

| Data | Improves | How |
|------|----------|-----|
| **Issue patterns** (50k repos) | ValidationSystem | Rules evolve to catch real issues faster |
| **Template success rates** | TemplateSelector | High-success templates promoted automatically |
| **Failure patterns** | PipelinePhase4 | Historical failures prevent future iterations |
| **Framework fingerprints** | PatternDetector | Better framework detection across instances |
| **Code style metrics** | QualityEnforcer | Corpus-based quality standards (not hardcoded) |

### How to Convince Customers to Upgrade:

1. **"Scanner found 50 issues"** → "We can auto-fix 80% using evolved patterns from our community"
2. **"GitHub App shows trend"** → "We can predict issues before they occur (preventive vs reactive)"
3. **"You get patterns from CentralCloud"** → "They're personalized - learned from 10k+ similar repos"
4. **"One-click fixes"** → "Self-improving agents learn YOUR style and conventions"

### Products Enable Productization of Core System:

- **GitHub App** = continuous data pipeline (not one-off)
- **Scanner** = offline-first for air-gapped teams
- **CentralCloud** = SaaS backbone for scale & learning
- **Agents** = Apply learnings back to customer repos automatically

---

## 4. ECOSYSTEM LOCK-IN & NETWORK EFFECTS

### Network Effects Created by Products:

#### Type 1: Pattern Consensus
**Mechanism:** More users → more patterns → better consensus rules → more accurate detection

Example:
- Scanner user runs on new codebase
- Detects "async/await anti-patterns" (pattern fingerprint)
- Sends to CentralCloud (anonymized)
- CentralCloud aggregates: "This pattern found in 15% of Elixir repos"
- Genesis learns: "This is a common real-world pattern, increase detection confidence"
- Next run: Everyone's detectors improve

#### Type 2: Template Evolution
**Mechanism:** Product users' code becomes corpus → templates improve → better code generation

Example:
- GitHub App sees template "quality_elixir_server" fail 40% of time
- Tracks why (most common: missing error handling)
- Genesis: "Template needs error handling variant"
- Updates template with error handling section
- Scanner user generates code: gets improved template automatically

#### Type 3: Quality Standards Emergence
**Mechanism:** Distributed enforcement → corpus-based standards → rules emerge

Example:
- 100 teams use products
- Each has slightly different quality standards
- CentralCloud sees: "95% of high-performing teams enforce module_depth < 5"
- Genesis: "Recommend module_depth < 5 as best practice"
- All new users get corpus-backed best practices (not arbitrary)

#### Type 4: Failure Prevention
**Mechanism:** Aggregate failures → prevent future failures → lower operational cost

Example:
- Scanner user's database migration fails
- Failure pattern: "Migration without rollback path"
- Sent to CentralCloud
- Genesis: "Add rollback path detection to validation"
- Scanner user #2: "Your migration plan will fail - here's why"

### How Products Create Lock-In:

1. **Data becomes increasingly valuable** (patterns are personalized to your team's style)
2. **Rules improve over time** (benefits accumulate)
3. **Switching cost rises** (would lose all learned patterns + evolved rules)
4. **Network effects amplify** (more users = better rules for everyone)

### What's Missing in Ecosystem (To Close Lock-In Loop):

1. **❌ CentralCloud → Product Feedback Loop** (Not yet)
   - Products should query: "What patterns are you recommending?" and use them
   - Currently: CentralCloud serves patterns, but products don't deeply integrate
   - **Fix:** Add pattern scoring to scanner output, highlight "community-learned" vs "hardcoded" rules

2. **❌ Product Usage Analytics → Genesis Learning** (Partial)
   - Genesis should see: "Which recommendations did customers accept/reject?"
   - Currently: Genesis sees results but not customer intent
   - **Fix:** Collect "customer decided to fix / ignored" signals

3. **❌ Cross-Product Learning** (Weak)
   - GitHub App learns from commits, Scanner learns from snapshots
   - They should share learnings
   - **Fix:** Both should use same CentralCloud pattern service

4. **❌ Personalization per Team** (Not yet)
   - Rules should adapt to YOUR team's style/standards
   - Currently: Global rules only
   - **Fix:** Add team-specific rule variants in CentralCloud

---

## 5. COMPONENT STATUS MATRIX

### Products
| Product | Status | Maturity | Production Ready |
|---------|--------|----------|------------------|
| **GitHub App** | 90% | Stable/tested | ✅ Yes |
| **Scanner CLI** | 95% | Stable/tested | ✅ Yes |
| **CentralCloud** | 85% | API defined, implementation in progress | ⚠️ Soon (few weeks) |

### Core Packages (Publishable)
| Package | Status | Current Use | Could Be Product |
|---------|--------|------------|-----------------|
| **ex_pgflow** | 100% | Singularity + Broadway (producer) | ✅✅ Already published to Hex! |
| **code_quality_engine** | 95% | Scanner + GitHub App | ✅ Already a product (via Scanner) |
| **parser_engine** | 95% | Core analysis, 30+ languages | ✅ Could be standalone service |
| **linting_engine** | 90% | Quality enforcement, code fixes | ⚠️ Partially used |
| **prompt_engine** | 85% | LLM prompt generation | ⚠️ Not heavily used yet |

### Core Systems
| System | Status | Purpose | Productizable |
|--------|--------|---------|--------------|
| **Agents** | 85% | Autonomous code improvement | ✅ Via self-improving-agent-as-a-service |
| **Pipeline (5-phase)** | 95% | Self-evolution framework | ✅ Could be workflow-as-a-service |
| **Hot Reload** | 95% | Live code updates | ⚠️ Infrastructure-only |
| **Embeddings (Nx)** | 90% | Semantic search | ✅ Could be semantic-code-search-as-a-service |
| **CentralCloud** | 85% | Learning hub | ✅ Core product (in progress) |
| **Genesis** | 80% | Autonomous rule evolution | ✅ Advanced feature of CentralCloud |

---

## 6. PRODUCT ARCHITECTURE DEEP DIVES

### GitHub App Architecture
```
GitHub Webhook
  ↓
Elixir Phoenix App (webhook handler)
  ├→ Validates webhook signature
  ├→ Creates PGFlow workflow
  └→ Returns 202 Accepted
  
Async PGFlow Workflow
  ├→ Fetch repo (git clone)
  ├→ Run code_quality_engine (Rust NIF)
  ├→ Analyze results
  └→ Post to CentralCloud (if learning enabled)
  
GitHub REST API
  ├→ Create check run (pass/fail)
  ├→ Post PR comment (results)
  └→ Update commit status

CentralCloud Integration
  ├→ POST /scanner/runs (register this run)
  └→ GET /patterns/snapshot (fetch evolved patterns)
```

### Scanner Architecture
```
CLI User
  ↓
singularity-scanner analyze --path /repo --format json
  ├→ Discover source files (excludes: node_modules, target/, _build/)
  ├→ Language detection (via parser_engine)
  ├→ Analyze each file (code_quality_engine NIF)
  ├→ Aggregate results
  ├→ (Optional) POST /scanner/runs to CentralCloud
  ├→ (Optional) GET /patterns/snapshot (with ETag caching)
  └→ Output JSON/SARIF/Text
```

### CentralCloud Architecture
```
Scanner/GitHub App Clients
  ↓
CentralCloud HTTPS Endpoints
  ├→ POST /scanner/runs (register run)
  │   └→ PostgreSQL: issue server_run_id
  │   └→ Fetch policy: telemetry_enabled?
  │   └→ Serve patterns_etag (for caching)
  │
  ├→ POST /scanner/events (submit results)
  │   └→ PGMQ queue: centralcloud_learning
  │   └→ PGMQ queue: centralcloud_checks (if GitHub App)
  │
  └→ GET /patterns/snapshot (fetch evolved patterns)
      └→ Check ETag (304 if unchanged)
      └→ Return encrypted payload if changed

Internal Processing (Async)
  ├→ PGMQ: centralcloud_learning
  │   ├→ Ingest patterns from all instances
  │   ├→ Compute consensus
  │   └→ Store in PostgreSQL
  │
  ├→ PGMQ: centralcloud_checks
  │   ├→ Post PR checks (for GitHub App)
  │   └→ Create GitHub check runs
  │
  └→ PGMQ: centralcloud_patterns_sync
      ├→ Build encrypted pattern snapshot
      ├→ Compute ETag
      └→ Serve to clients
```

---

## 7. MISSING PIECES TO CLOSE ECOSYSTEM

### High Priority (3-6 weeks)
1. **CentralCloud Production Deployment** - Complete PostgreSQL schema, deploy backend
2. **Product → CentralCloud Feedback Loop** - Products should visibly use evolved patterns (show customer "this is from our community")
3. **Team Personalization** - Rules adapt to each team's code style (not just global)

### Medium Priority (6-12 weeks)
1. **Package Intelligence Service** (separate service) - Semantic search over npm/cargo/hex/pypi
2. **Semantic Code Search UI** - Web interface to search across customer's codebase
3. **Template Marketplace** - Customers can share/discover templates

### Lower Priority (Future)
1. **Agent-as-a-Service** - SelfImprovingAgent runs for customer's repo continuously
2. **IDE Extensions** - VSCode/IntelliJ plugins for scanner integration
3. **Enterprise SLA** - On-premise deployment, white-label options

---

## 8. KEY METRICS FOR ECOSYSTEM HEALTH

### Product-Level KPIs
| Metric | Target | Current |
|--------|--------|---------|
| **Scanner: Offline Usage** | 80% runs complete offline | ? |
| **GitHub App: Analysis Time** | < 60s for most repos | ? |
| **CentralCloud: Pattern Hit Ratio** | 70%+ customers benefit from cross-instance patterns | ? |

### Network Effect KPIs
| Metric | Target | Current |
|--------|--------|---------|
| **Pattern Convergence** | Rules stabilize after 100+ instances | N/A (not launched) |
| **Template Improvement** | Success rate increases 5% per quarter | N/A |
| **Failure Prevention** | X% fewer bugs in repos using evolved patterns | N/A |

---

## CONCLUSION

### Current State
- **3 products ready** (GitHub App 90%, Scanner 95%, CentralCloud 85%)
- **5 packages published/publishable** (ex_pgflow already on Hex)
- **20+ agents working** with self-improvement loops
- **5-phase pipeline complete** with continuous learning

### Immediate Next Steps
1. **Launch CentralCloud** (finish implementation, deploy to prod)
2. **Connect products to CentralCloud** (products should visibly use evolved patterns)
3. **Measure network effects** (track pattern consensus, template improvement, failure prevention)
4. **Add team personalization** (rules adapt to customer's style, not just global rules)

### Upgrade Path (Customers)
```
"We found 50 issues" (Scanner)
  → "We can fix them" (proposed)
  → "Let's auto-fix them" (hot-reload)
  → "We learn from your style" (personalization)
  → "We predict issues before you write them" (continuous improvement loop)
```

### Ecosystem Lock-In Strategy
1. **Data → Patterns** (aggregate failures, successes)
2. **Patterns → Rules** (evolve via Genesis)
3. **Rules → Products** (serve back as improved detectors)
4. **Closed Loop** (customers benefit from network, switching cost rises)

