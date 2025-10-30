# Singularity Ecosystem: Products & Multi-Channel Distribution Roadmap

## Vision

**Singularity Ecosystem** = Customer acquisition flywheel where free/freemium products drive users into the core autonomous code generation system.

```
Products (Free/Freemium)
├─ Smart Package Context (Docs + Examples + Patterns)
├─ Scanner (Code Quality Analysis)
├─ GitHub App (PR Automation)
└─ CentralCloud (Pattern Insights)
    ↓
Network Effects (Multi-instance Learning)
    ↓
Singularity Core (Automatic Code Generation)
    ↓
Lock-in (Can't live without it)
```

---

## Distribution Strategy: Multi-Channel

Each product available in **4 channels** with ONE shared backend:

| Channel | User | Example | Setup Effort |
|---------|------|---------|--------------|
| **MCP Server** | Claude/Cursor users | `@smart-package-context next.js auth` | Low (4-5 days) |
| **VS Code Extension** | IDE power users | Hover docs, sidebar patterns | Medium (1-2 weeks) |
| **CLI Tool** | Terminal users, scripts, CI/CD | `smart-packages search react` | Low (1 week) |
| **HTTP API** | Integrations, custom tools, SDKs | `POST /api/packages/search` | Medium (2 weeks) |

**Key:** One backend implementation, wrapped 4 ways = 0 duplication.

---

## Product Roadmap (6 Months)

### Phase 1: Core Products (Months 1-2)

#### Week 1-2: Prepare & Polish
- [ ] Audit package_intelligence (Rust NIF) - production ready?
- [ ] Audit code_quality_engine (Scanner) - production ready?
- [ ] Finalize CentralCloud schema & API
- [ ] Review GitHub App for bugs & edge cases

#### Week 3-4: Smart Package Context Backend
**Goal:** One unified service combining:
- Package docs (npm, cargo, hex, pypi)
- GitHub real-world examples
- Community consensus patterns
- Semantic search (embeddings + pgvector)

```
products/smart-package-context/
├── backend/
│   ├── src/api/
│   │   ├── package_info.rs (fetch + cache)
│   │   ├── examples.rs (GitHub extraction)
│   │   ├── patterns.rs (CentralCloud queries)
│   │   └── search.rs (semantic via embeddings)
│   └── Cargo.toml
├── server/ (MCP wrapper)
├── cli/ (CLI wrapper)
├── extension/ (VS Code wrapper)
└── api/ (HTTP wrapper)
```

**Status:** ✅ Ready for all 3 layers (package_intelligence + patterns + embeddings)

#### Week 5-6: MCP Servers (Easiest Channel)
- [ ] Smart Package Context → MCP server (2 days)
- [ ] Scanner → MCP server (1 day)
- [ ] GitHub App → MCP suggestions (1 day)
- [ ] CentralCloud → MCP patterns (1 day)
- [ ] Publish to MCP marketplace (1 day)

**By end of Month 1:** 4 MCP servers live on marketplace

---

### Phase 2: VS Code Extensions (Weeks 7-10)

#### Week 7-8: Smart Package Context Extension
- [ ] TypeScript extension scaffold (1 day)
- [ ] Hover provider for package docs (3 days)
- [ ] Sidebar: Pattern explorer (2 days)
- [ ] Package file analyzer (2 days)
- [ ] Testing + polish (2 days)

#### Week 9-10: Scanner + GitHub App Extensions
- [ ] Scanner real-time linting (3 days)
- [ ] Quick fixes + auto-apply (2 days)
- [ ] GitHub App PR inline comments (3 days)
- [ ] All testing + marketplace submission (3 days)

**By end of Month 2:** 3 VS Code extensions live on marketplace

---

### Phase 3: CLI Tools (Weeks 11-14)

#### Week 11: Smart Package Context CLI
```bash
$ smart-package-context search "react authentication"
$ smart-package-context info next.js
$ smart-package-context examples express --language typescript
$ smart-package-context suggest-patterns --file package.json
```

- [ ] CLI scaffold (Rust) (1 day)
- [ ] Command implementations (2 days)
- [ ] Help + docs (1 day)
- [ ] Package: Homebrew, npm, Cargo (2 days)

#### Week 12: Scanner CLI
```bash
$ smart-scanner lib/ --fix
$ smart-scanner analyze ./src --format json
$ smart-scanner compare before.json after.json
```

- [ ] CLI for Scanner (2 days)
- [ ] Output formats (JSON, HTML, etc.) (1 day)
- [ ] Distribution (1 day)

#### Week 13-14: Other CLIs + Cross-CLI Features
- [ ] CentralCloud CLI for pattern queries (2 days)
- [ ] GitHub App CLI for PR analysis (2 days)
- [ ] Unified config file: `~/.singularity/config.toml` (2 days)
- [ ] Cross-tool integration (patterns + scanner) (2 days)

**By end of Month 3:** All 4 tools on Homebrew, npm, Cargo registries

---

### Phase 4: HTTP APIs (Weeks 15-18)

#### Week 15-16: REST API Infrastructure
- [ ] Express/Actix-web server (2 days)
- [ ] OpenAPI spec (2 days)
- [ ] Authentication (API keys, OAuth) (3 days)
- [ ] Rate limiting + caching (2 days)

#### Week 17: API Endpoints
```
GET /api/packages/{name}
GET /api/packages/{name}/examples
GET /api/packages/{name}/patterns
GET /api/patterns/search?q=...
POST /api/files/analyze
POST /api/scanners/{type}/run
```

- [ ] All endpoints (3 days)
- [ ] SDKs: Python, JavaScript, Rust (3 days)
- [ ] Swagger UI + docs (1 day)

#### Week 18: API Marketplace & Documentation
- [ ] API documentation (1 day)
- [ ] Sample projects (2 days)
- [ ] Community SDK in progress (1 day)

**By end of Month 4:** HTTP APIs available, SDKs for 3 languages

---

### Phase 5: Network Effects & Analytics (Weeks 19-22)

#### Week 19-20: Telemetry & Insights
- [ ] Anonymous usage tracking (what patterns are searched most?)
- [ ] Pattern popularity metrics (trending patterns)
- [ ] Success rate improvements (before/after scanner fixes)
- [ ] Team collaboration analytics

#### Week 21-22: Visualization & Feedback
- [ ] Dashboard showing pattern trends
- [ ] "Your team improved X% using these patterns"
- [ ] Feedback loop: user accepts suggestion → improves consensus
- [ ] Public insights: "Top patterns for React"

**By end of Month 5:** Ecosystem visualization + analytics in place

---

### Phase 6: Monetization & Upgrade Path (Weeks 23-24)

#### Week 23: Free → Premium Tier
```
FREE:
  - MCP/CLI/VS Code: Basic access
  - 5 examples per package
  - Community patterns (read-only)

PREMIUM ($20/mo):
  - Unlimited examples
  - Full pattern consensus data
  - Semantic search
  - Private pattern repo
  - 10k API calls/month

ENTERPRISE (Custom):
  - Self-hosted option
  - Private instances
  - Integration support
  - Custom analytics
```

#### Week 24: Upgrade Funnel to Singularity Core
- [ ] "Get even better? Auto-generate code with Singularity"
- [ ] Singularity core as premium upsell ($100-500/mo)
- [ ] Customer case studies: "How X team cut dev time 50%"
- [ ] Integration guide: products → core

**By end of Month 6:** Free ecosystem + paid premium + enterprise

---

## Distribution Channels: Order of Launch

### Month 1-2: MCP First (Fastest Time-to-Market)
- ✅ Easiest to build
- ✅ Claude/Cursor users are perfect fit
- ✅ Can launch on MCP marketplace immediately
- ✅ Builds user base before other channels

### Month 2-3: VS Code Extensions (Second Wave)
- ✅ 15M monthly VS Code users
- ✅ Can bundle with CLI (auto-updates)
- ✅ Visual UX makes products visible

### Month 3-4: CLI Tools (Ubiquitous Access)
- ✅ Developers expect CLI for tools
- ✅ CI/CD integration opportunity
- ✅ Can be installed on dev machines globally

### Month 4-5: HTTP APIs (Enterprise & Integrations)
- ✅ Custom integrations
- ✅ Internal tool builders
- ✅ Platform plays

---

## Product Details

### 1. Smart Package Context

**What it does:**
- Search any npm/cargo/hex/pypi package docs
- Get real GitHub code examples for that package
- Learn what community consensus is (95% use OAuth, 60% use Prisma)
- Find similar packages/patterns by semantic search

**Channels:**
- **MCP:** `@smart-package-context next.js authentication`
- **VS Code:** Hover on imports → docs + examples
- **CLI:** `smart-packages search react --language javascript`
- **API:** `GET /api/packages/next.js/examples`

**Backend:**
- Reuses: `packages/package_intelligence` (Rust NIF) + `CentralCloud` + `Embeddings`
- Status: 95% ready
- Effort: 4-5 weeks (all channels)

---

### 2. Scanner

**What it does:**
- Analyzes code quality (performance, security, style)
- Shows issues with explanations
- Suggests fixes (manual or auto-apply)
- Learns patterns from CentralCloud (what similar teams fixed)

**Channels:**
- **MCP:** `@scanner check this code`
- **VS Code:** Real-time red squiggles + quick fixes
- **CLI:** `smart-scanner lib/ --fix`
- **API:** `POST /api/scan`

**Backend:**
- Reuses: `packages/code_quality_engine` (Rust NIF)
- Status: 95% ready
- Effort: 2-3 weeks (all channels)

---

### 3. GitHub App

**What it does:**
- Analyzes PRs for quality issues
- Comments with suggestions
- Checks commit messages for standards
- Blocks merges below quality threshold (configurable)
- Feeds patterns back to CentralCloud

**Channels:**
- **MCP:** Pattern suggestions during code review
- **VS Code:** Inline PR comments
- **CLI:** `smart-app check-pr https://github.com/...`
- **API:** Webhook integration

**Backend:**
- Already 90% complete in `products/github-app/`
- Status: Near ship-ready
- Effort: 1-2 weeks (polish + channels)

---

### 4. CentralCloud

**What it does:**
- Aggregates patterns from all users/instances
- Computes consensus (what works across teams)
- Ranks patterns by success rate
- Suggests best practices specific to your tech stack
- Feeds improved patterns back to Genesis

**Channels:**
- **MCP:** `@patterns what does our team use for X?`
- **VS Code:** Sidebar showing team patterns
- **CLI:** `smart-patterns list --team engineering`
- **API:** `GET /api/patterns/team`

**Backend:**
- Already exists in `nexus/central_services/`
- Status: 85% ready (embedding integration done)
- Effort: 2-3 weeks (productize + expose)

---

## Customer Acquisition Funnel

```
Month 1: Awareness
  User discovers Smart Package Context (MCP on Claude)
  "Wow, I can search packages without leaving Claude!"

Month 2-3: Habit Formation
  User installs VS Code extension
  Saves 10 mins/day on package research
  "This is my new workflow"

Month 4-5: Network Effects
  User's team all use same tool
  See consensus patterns from community
  "Why don't we use this pattern like 95% of teams?"

Month 6+: Lock-in - Upsell to Singularity Core
  User: "Can you auto-apply these patterns?"
  Company: "How about we auto-generate code?"
  → Upgrade to Singularity core system ($100-500/mo)
  → Now we own the customer
```

**Metrics to Track:**
- DAU/MAU per channel
- Patterns discovered per user
- Community consensus improvements
- Premium conversion rate
- Singularity core upsell rate

---

## Technology Stack: Unified

```
Backend (ONE codebase, reused by all frontends):
  ├─ Rust NIF: Package Intelligence + Scanner
  ├─ Elixir: CentralCloud + Embeddings
  ├─ PostgreSQL: Storage + pgvector
  └─ Nx: Model inference (on-device)

Frontends:
  ├─ MCP: Stdio protocol (works everywhere)
  ├─ VS Code: TypeScript extension SDK
  ├─ CLI: Rust binary
  └─ HTTP: Express/Actix-web
```

**Key Advantage:** Update backend once → all frontends get the fix.

---

## Deployment Options

### Option 1: Hosted SaaS (Default)
```
singularity.ai/
├─ Backend service (us-east-1)
├─ PostgreSQL + pgvector (RDS)
├─ Cache layer (Redis)
├─ Kubernetes cluster
```

### Option 2: Self-Hosted (Enterprise)
```
docker run smart-package-context:latest \
  -e DATABASE_URL=postgresql://your-db \
  -e PRIVATE_MODE=true
```

### Option 3: Hybrid
- Free tier on our servers
- Premium self-hosted option

---

## Success Metrics (Month 6)

| Metric | Target | Status |
|--------|--------|--------|
| MCP downloads | 10k | 🟡 Ambitious |
| VS Code extension installs | 5k | 🟡 Ambitious |
| CLI tool downloads | 20k | 🟡 Conservative |
| API requests/day | 100k | 🟡 Ambitious |
| Pattern consensus accuracy | 85%+ | 🟢 Achievable |
| Premium users | 500+ | 🟡 Ambitious |
| Singularity core trials | 100+ | 🟡 Ambitious |

---

## Next Steps

1. **Week 1:** Finalize backend architecture for Smart Package Context
2. **Week 2-4:** Build & test Smart Package Context backend
3. **Week 5-6:** Implement MCP, CLI wrappers
4. **Week 7-8:** VS Code extension
5. **Week 9-10:** HTTP API
6. **Week 11+:** Iterate on adoption, analytics, upsells

---

## Questions to Resolve

1. **Pricing:** Free tier unlimited or with limits?
2. **Self-hosting:** Allow enterprise to run on-premises?
3. **Genesis feedback:** How do Genesis improvements feed back to products?
4. **Team collaboration:** Multi-user patterns/orgs from day 1?
5. **Analytics:** What usage data do we track (keep privacy)?

---

## Revenue Model

```
Year 1:
  - Free tier: Build user base (10k+ users)
  - Premium: $20/mo × 500 users = $120k/yr
  - Enterprise: $5k-50k/deal × 2-3 = $50k/yr
  - Total: ~$170k MRR potential

Year 2+:
  - Network effects drive conversions
  - Singularity core upsells
  - Data insights (anonymized) to package authors
  - Potential: $1M+ ARR
```

---

## The Lock-in Play

**Why this works:**

1. **Free products** get developers using your infrastructure
2. **Patterns** are aggregated from ALL users (network effects)
3. **Consensus** becomes valuable (trust signal)
4. **Singularity core** promises "auto-apply these patterns"
5. **Once locked in** → hard to leave (all your code is in it)

→ **Ecosystem = Customer acquisition machine**
→ **Core system = Retention lock-in**

