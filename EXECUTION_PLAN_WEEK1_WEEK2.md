# Singularity Products Execution: Week 1-2

## Goal: Backend Architecture for Smart Package Context

Get the shared backend ready so all 4 channels (MCP, VS Code, CLI, API) can wrap it.

---

## Week 1: Backend Architecture Design & Setup

### Day 1-2: Design Backend Interface

Create a **unified backend interface** that all 4 channels will call:

```rust
// packages/singularity-smart-package-context/backend/src/api/mod.rs

pub struct SmartPackageContext {
    package_intel: PackageIntelligence,
    patterns: PatternIntelligence,
    embeddings: EmbeddingService,
}

impl SmartPackageContext {
    // Core functions that all channels will call
    pub async fn get_package_info(
        &self,
        name: &str,
        ecosystem: &str,
    ) -> Result<PackageInfo>;

    pub async fn get_package_examples(
        &self,
        name: &str,
        ecosystem: &str,
        limit: usize,
    ) -> Result<Vec<CodeExample>>;

    pub async fn get_package_patterns(
        &self,
        name: &str,
    ) -> Result<Vec<PatternConsensus>>;

    pub async fn search_patterns(
        &self,
        query: &str,
        limit: usize,
    ) -> Result<Vec<PatternMatch>>;

    pub async fn analyze_file(
        &self,
        content: &str,
        file_type: FileType,
    ) -> Result<Vec<Suggestion>>;
}
```

**Tasks:**
- [ ] Design return types (PackageInfo, CodeExample, PatternConsensus, etc.)
- [ ] Define error types
- [ ] Create trait boundaries for pluggable components
- [ ] File: `packages/singularity-smart-package-context/backend/src/api/mod.rs`

### Day 3: Set Up Elixir Wrapper

Create thin Elixir wrapper around Rust NIF:

```elixir
# nexus/central_services/lib/singularity_smart_package_context/backend.ex

defmodule SingularitySmartPackageContext.Backend do
  @moduledoc """
  Elixir wrapper around Rust NIF backend.
  All 4 channels (MCP, VS Code, CLI, API) call this.
  """

  def get_package_info(name, ecosystem \\ "npm") do
    SmartPackageContext.get_package_info(name, ecosystem)
  end

  def get_package_examples(name, ecosystem \\ "npm", limit \\ 5) do
    SmartPackageContext.get_package_examples(name, ecosystem, limit)
  end

  # ... other functions

  def health_check do
    SmartPackageContext.health()
  end
end
```

**Tasks:**
- [ ] Create `nexus/central_services/lib/singularity_smart_package_context/backend.ex`
- [ ] Define error handling & logging
- [ ] Add caching layer (optional for Week 2+)
- [ ] Write tests for wrapper

### Day 4-5: Integration Points

Integrate the 3 existing systems:

```elixir
# nexus/central_services/lib/singularity_smart_package_context/integrations.ex

defmodule SingularitySmartPackageContext.Integrations do
  alias PackageIntelligence  # Rust NIF - docs + examples
  alias CentralCloud.Evolution.Patterns  # Pattern aggregation
  alias Singularity.Embedding.EmbeddingGenerator  # Semantic search

  def get_package_with_patterns(package_name) do
    with {:ok, pkg_info} <- PackageIntelligence.fetch(package_name),
         {:ok, examples} <- PackageIntelligence.extract_examples(package_name),
         {:ok, patterns} <- CentralCloud.Evolution.Patterns.get_for_package(package_name),
         {:ok, embedding} <- EmbeddingGenerator.embed(package_name)
    do
      {:ok, {pkg_info, examples, patterns, embedding}}
    end
  end
end
```

**Tasks:**
- [ ] Review package_intelligence Rust API
- [ ] Review CentralCloud pattern aggregation API
- [ ] Review Embedding service interface
- [ ] Create integration module
- [ ] Write integration tests

---

## Week 2: Channel Infrastructure & First MCP Server

### Day 1-2: Shared Client Protocol

Create a **client abstraction** that MCP/CLI/API all use:

```rust
// packages/singularity-smart-package-context/backend/src/client.rs

pub trait SmartPackageContextClient {
    async fn call_tool(
        &self,
        tool_name: &str,
        args: serde_json::Value,
    ) -> Result<serde_json::Value>;
}

// HTTP client (for CLI/API to communicate with backend)
pub struct HttpClient {
    base_url: String,
}

// In-process client (for MCP server in same process)
pub struct InProcessClient {
    backend: Arc<SmartPackageContext>,
}

impl SmartPackageContextClient for HttpClient { ... }
impl SmartPackageContextClient for InProcessClient { ... }
```

**Tasks:**
- [ ] Design client trait
- [ ] Implement HTTP client
- [ ] Implement in-process client
- [ ] Create client factory
- [ ] File: `packages/singularity-smart-package-context/backend/src/client.rs`

### Day 3: MCP Server Template

Create a generic MCP server wrapper:

```rust
// packages/singularity-smart-package-context/server/src/main.rs

use mcp_sdk::{Server, Tool};

#[tokio::main]
async fn main() -> Result<()> {
    let backend = SmartPackageContext::new().await?;
    let mut server = Server::new("singularity-smart-package-context");

    // Register tools dynamically
    let tools = [
        Tool {
            name: "get_package_info".to_string(),
            description: "Get package information from npm, cargo, hex, pypi".to_string(),
            handler: Box::new(|args| {
                let name = args.get("name")?.as_str()?;
                let ecosystem = args.get("ecosystem").and_then(|e| e.as_str()).unwrap_or("npm");
                backend.get_package_info(name, ecosystem).await
            }),
        },
        // ... other tools
    ];

    for tool in tools {
        server.register_tool(tool)?;
    }

    server.run_stdio().await
}
```

**Tasks:**
- [ ] Create `packages/singularity-smart-package-context/server/` directory
- [ ] Set up Cargo.toml for MCP dependencies
- [ ] Implement main.rs with all 5 tools
- [ ] Add error handling
- [ ] Create systemd/launchd service files

### Day 4: Testing Infrastructure

Build test suite for all channels:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_get_package_info() {
        let ctx = SmartPackageContext::test().await;
        let result = ctx.get_package_info("react", "npm").await;
        assert!(result.is_ok());
    }

    #[test]
    fn test_mcp_tool_call() {
        // Test that MCP tool wrapper works
    }
}
```

**Tasks:**
- [ ] Create test suite for backend
- [ ] Create test fixtures
- [ ] Create integration tests
- [ ] Write documentation for testing

### Day 5: Documentation & Handoff

Prepare for Week 3 (other channels):

**Tasks:**
- [ ] Write API documentation for backend
- [ ] Create examples for each tool
- [ ] Document error handling
- [ ] Create architecture diagram
- [ ] Write setup instructions for other teams

---

## Project Structure After Week 2

```
products/
└── singularity-smart-package-context/
    ├── backend/                    ← Weeks 1-2 COMPLETE
    │   ├── src/
    │   │   ├── lib.rs              ← Main entry point
    │   │   ├── api/
    │   │   │   ├── mod.rs          ← Core interface
    │   │   │   ├── package_info.rs
    │   │   │   ├── examples.rs
    │   │   │   ├── patterns.rs
    │   │   │   └── search.rs
    │   │   ├── integrations/
    │   │   │   ├── mod.rs
    │   │   │   ├── package_intel.rs
    │   │   │   ├── patterns.rs
    │   │   │   └── embeddings.rs
    │   │   ├── cache.rs
    │   │   ├── error.rs
    │   │   └── client.rs
    │   ├── tests/
    │   ├── Cargo.toml
    │   └── README.md
    │
    ├── server/                     ← Weeks 3-4 BUILD
    │   ├── src/main.rs             ← MCP wrapper
    │   ├── Cargo.toml
    │   └── README.md
    │
    ├── extension/                  ← Weeks 5-6 BUILD
    │   ├── src/extension.ts        ← VS Code wrapper
    │   ├── package.json
    │   └── tsconfig.json
    │
    ├── cli/                        ← Week 7 BUILD
    │   ├── src/main.rs             ← CLI wrapper
    │   ├── Cargo.toml
    │   └── README.md
    │
    ├── api/                        ← Week 8 BUILD
    │   ├── src/
    │   │   ├── main.rs or routes.ex
    │   │   └── openapi.yaml
    │   └── Dockerfile
    │
    ├── docker-compose.yml          ← Full stack
    └── README.md

nexus/central_services/
├── lib/singularity_smart_package_context/
│   ├── backend.ex               ← Elixir wrapper
│   └── integrations.ex
└── test/
    └── singularity_smart_package_context/
        └── backend_test.exs
```

---

## Success Criteria: End of Week 2

✅ **Backend Complete & Tested**
- [ ] All 5 API functions implemented
- [ ] All 3 integrations working (package_intel + patterns + embeddings)
- [ ] 30+ tests passing
- [ ] Error handling comprehensive
- [ ] Documentation complete

✅ **MCP Server Running**
- [ ] Can call from Claude Code/Cursor
- [ ] All 5 tools available
- [ ] Returns correct data
- [ ] Handles errors gracefully

✅ **Ready for Week 3**
- [ ] Backend API documented
- [ ] Example calls for each tool
- [ ] Testing guide for other teams
- [ ] Known issues documented

---

## Success Metrics

**Week 1 Complete:**
- Backend interface designed
- All integration points identified
- Tests written (before implementation)
- Architecture documented

**Week 2 Complete:**
- Backend fully functional
- MCP server deployed to macOS/Linux
- All 5 tools callable from Claude Code
- 30+ tests passing
- Zero critical bugs

---

## Critical Dependencies

**Must Have (Already Done):**
- ✅ package_intelligence (Rust NIF)
- ✅ CentralCloud pattern aggregation
- ✅ Embedding service

**Must Have (Build Week 1-2):**
- Backend interface
- Elixir wrapper
- Integration module
- MCP server

**Team Assignments:**
- **Backend (Weeks 1-2):** 1 Rust engineer + 1 Elixir engineer
- **MCP (Weeks 3):** 1 Rust engineer (uses backend from Week 1-2)
- **VS Code (Weeks 5-6):** 1 TypeScript engineer (uses backend from Week 1-2)
- **CLI (Week 7):** 1 Rust engineer (uses backend from Week 1-2)
- **API (Week 8):** 1 API engineer (uses backend from Week 1-2)

---

## Next Document

Once Week 1-2 is complete, see: `EXECUTION_PLAN_WEEK3_WEEK4.md` (MCP + VS Code)

---

## Questions/Decisions Needed

Before starting Week 1:

1. **Where does backend live?**
   - Option A: `packages/singularity-smart-package-context/` (separate package)
   - Option B: `nexus/central_services/` (integrated)
   - **Recommended:** Option A (keeps products separate, easier to version/release)

2. **Rust or Elixir for backend?**
   - Option A: Pure Rust (fast, compiles to NIF)
   - Option B: Elixir calling Rust NIFs
   - **Recommended:** Option A (pure Rust, then wrap in Elixir)

3. **Database for caching?**
   - Option A: PostgreSQL (shared with Central Services)
   - Option B: In-memory (simple, but loses data)
   - **Recommended:** PostgreSQL (for persistence + query flexibility)

4. **Docker deployment?**
   - Option A: Docker container for backend
   - Option B: Native binary (no container)
   - **Recommended:** Both (container for cloud, binary for local dev)

