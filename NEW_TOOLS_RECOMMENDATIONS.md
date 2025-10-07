# New Tool Recommendations

## Existing Tools Analysis

### Current Tool Categories

**1. Codebase Understanding** (6 tools)
- ✅ `codebase_search` - Semantic code search
- ✅ `codebase_analyze` - Full analysis
- ✅ `codebase_technologies` - Tech stack detection
- ✅ `codebase_dependencies` - Dependency analysis
- ✅ `codebase_services` - Service structure
- ✅ `codebase_architecture` - Architecture overview

**2. Knowledge Discovery** (6 tools)
- ✅ `knowledge_packages` - Package registry search
- ✅ `knowledge_patterns` - Code pattern search
- ✅ `knowledge_frameworks` - Framework patterns
- ✅ `knowledge_examples` - Usage examples
- ✅ `knowledge_duplicates` - Duplicate detection
- ✅ `knowledge_documentation` - Doc search

**3. Code Analysis** (6 tools)
- ✅ `code_refactor` - Refactoring opportunities
- ✅ `code_complexity` - Complexity analysis
- ✅ `code_todos` - TODO/FIXME detection
- ✅ `code_consolidate` - Code consolidation
- ✅ `code_language_analyze` - Language-specific analysis
- ✅ `code_quality` - Quality assessment

**4. Planning** (3 tools)
- ✅ `planning_breakdown` - Task breakdown
- ✅ `planning_estimate` - Effort estimation
- ✅ `planning_execute` - Task execution

**5. Quality** (2 tools)
- ✅ Quality checks (sobelow, mix audit)

**6. Web Search** (1 tool)
- ✅ `web_search` - Internet search

**7. Emergency LLM** (1 tool)
- ✅ `emergency_llm` - Fallback LLM access

---

## Gap Analysis: What's Missing?

### 🔥 High-Value Gaps

#### 1. **Git/Version Control Tools** ❌ MISSING!
**Why:** You have a meta-registry for YOUR code, but no tools to interact with git!

**Needed Tools:**
- `git_diff` - Show changes in working directory
- `git_log` - View commit history with filters
- `git_blame` - Find who changed a line/file
- `git_branches` - List/switch branches
- `git_commit_create` - Stage and commit changes
- `git_stash` - Stash/unstash changes
- `git_conflicts` - Detect merge conflicts

**Value:** 🔥🔥🔥 Essential for code evolution tracking + meta-registry integration

---

#### 2. **Database/Schema Tools** ❌ MISSING!
**Why:** You use Postgres heavily, but have no tools to query schema!

**Needed Tools:**
- `db_schema` - Show current database schema
- `db_query` - Execute safe read-only queries
- `db_migrations` - List/status of migrations
- `db_stats` - Database statistics (NOW IMPLEMENTED via Store.stats!)
- `db_indexes` - Show missing/unused indexes
- `db_explain` - Explain query plans

**Value:** 🔥🔥🔥 Critical for understanding data model + optimization

---

#### 3. **Test/Coverage Tools** ❌ MISSING!
**Why:** You mention test coverage in meta-registry design, but no tools!

**Needed Tools:**
- `test_run` - Run specific tests
- `test_coverage` - Generate coverage report
- `test_find` - Find tests for a module/function
- `test_create` - Generate test skeleton
- `test_quality` - Assess test quality (assertions, mocks, etc.)

**Value:** 🔥🔥🔥 Essential for quality tracking

---

#### 4. **File System Tools** ❌ MISSING!
**Why:** Agents need to read/write files!

**Needed Tools:**
- `file_read` - Read file contents
- `file_write` - Write to file (with safety checks)
- `file_list` - List files in directory
- `file_search` - Find files by name/pattern
- `file_stats` - File size, modified date, etc.

**Value:** 🔥🔥🔥 Basic but essential for autonomy

---

#### 5. **Process/System Tools** ❌ MISSING!
**Why:** Agents need to run commands, check status!

**Needed Tools:**
- `shell_run` - Execute shell command (with timeout)
- `process_list` - List running processes
- `process_kill` - Kill process by PID
- `system_stats` - CPU/RAM/disk usage
- `env_vars` - List environment variables

**Value:** 🔥🔥 Useful for DevOps automation

---

#### 6. **NATS/Messaging Tools** ❌ MISSING!
**Why:** You use NATS extensively, but no tools to inspect it!

**Needed Tools:**
- `nats_subjects` - List all NATS subjects
- `nats_publish` - Publish message to subject
- `nats_subscribe` - Subscribe and read messages
- `nats_stats` - Stream/consumer statistics
- `nats_kv` - Read/write KV store

**Value:** 🔥🔥 Critical for debugging distributed system

---

#### 7. **Dependency Management Tools** ❌ PARTIALLY MISSING
**Why:** You detect dependencies, but can't manage them!

**Needed Tools:**
- `deps_outdated` - List outdated dependencies
- `deps_update` - Update specific dependency
- `deps_add` - Add new dependency
- `deps_remove` - Remove dependency
- `deps_audit` - Security audit (exists for mix, extend to all!)
- `deps_graph` - Visualize dependency tree

**Value:** 🔥🔥 Important for maintenance

---

#### 8. **Documentation Tools** ❌ MISSING!
**Why:** Meta-registry tracks code, but not docs!

**Needed Tools:**
- `docs_generate` - Generate docs from code
- `docs_search` - Search existing docs
- `docs_missing` - Find undocumented code
- `docs_quality` - Assess doc quality
- `docs_examples` - Find code examples

**Value:** 🔥🔥 Good for code comprehension

---

### 🟡 Medium-Value Additions

#### 9. **Metrics/Observability Tools**
- `metrics_collect` - Collect custom metrics
- `metrics_query` - Query metrics
- `logs_search` - Search application logs
- `logs_tail` - Tail logs in real-time
- `alerts_list` - List active alerts

**Value:** 🔥 Nice for monitoring

---

#### 10. **CI/CD Tools**
- `ci_status` - Check CI pipeline status
- `ci_logs` - Fetch CI logs
- `ci_retry` - Retry failed job
- `deploy_status` - Check deployment status
- `deploy_rollback` - Rollback deployment

**Value:** 🔥 Useful for DevOps

---

## Recommended Implementation Order

### Phase 1: Essential Tools (Do Now!)

**1. Git Tools** (2-3 hours)
```elixir
defmodule Singularity.Tools.Git do
  def register(provider) do
    Catalog.add_tools(provider, [
      git_diff_tool(),
      git_log_tool(),
      git_blame_tool(),
      git_commit_create_tool(),
      git_branches_tool()
    ])
  end
end
```

**2. File System Tools** (1-2 hours)
```elixir
defmodule Singularity.Tools.FileSystem do
  def register(provider) do
    Catalog.add_tools(provider, [
      file_read_tool(),
      file_write_tool(),   # With safety: ask before overwrite!
      file_list_tool(),
      file_search_tool()
    ])
  end
end
```

**3. Database Tools** (2-3 hours)
```elixir
defmodule Singularity.Tools.Database do
  def register(provider) do
    Catalog.add_tools(provider, [
      db_schema_tool(),
      db_query_tool(),      # Read-only!
      db_migrations_tool(),
      db_explain_tool()
    ])
  end
end
```

---

### Phase 2: Quality Tools (Do Next)

**4. Test Tools** (3-4 hours)
```elixir
defmodule Singularity.Tools.Testing do
  def register(provider) do
    Catalog.add_tools(provider, [
      test_run_tool(),
      test_coverage_tool(),
      test_find_tool(),
      test_create_tool()   # Generate test skeletons!
    ])
  end
end
```

**5. NATS Tools** (2 hours)
```elixir
defmodule Singularity.Tools.Messaging do
  def register(provider) do
    Catalog.add_tools(provider, [
      nats_subjects_tool(),
      nats_publish_tool(),
      nats_stats_tool(),
      nats_kv_tool()
    ])
  end
end
```

---

### Phase 3: Nice-to-Have

**6. Documentation Tools** (2-3 hours)
**7. Dependency Management** (extend existing)
**8. Process/System Tools** (1-2 hours)

---

## Quick Win: File System Tools (Start Here!)

**Why Start Here:**
- ✅ Easy to implement (just wrap File module)
- ✅ Immediately useful for agents
- ✅ Foundation for other tools (git, docs, etc.)

**Implementation:**

```elixir
# lib/singularity/tools/file_system.ex
defmodule Singularity.Tools.FileSystem do
  alias Singularity.Tools.{Tool, Catalog}

  def register(provider) do
    Catalog.add_tools(provider, [
      file_read_tool(),
      file_write_tool(),
      file_list_tool(),
      file_search_tool(),
      file_stats_tool()
    ])
  end

  defp file_read_tool do
    Tool.new!(%{
      name: "file_read",
      description: "Read contents of a file",
      parameters: [
        %{name: "path", type: :string, required: true, description: "Relative file path"}
      ],
      function: &file_read/2
    })
  end

  def file_read(%{"path" => path}, _ctx) do
    case File.read(path) do
      {:ok, content} -> {:ok, %{path: path, content: content, size: byte_size(content)}}
      {:error, reason} -> {:error, "Failed to read file: #{reason}"}
    end
  end

  # ... more tools
end
```

---

## Impact Summary

**Current:** ~25 tools across 7 categories

**After Phase 1:** ~40 tools (15 new high-value tools)

**After Phase 2:** ~50 tools (10 more quality/messaging tools)

**After Phase 3:** ~60 tools (comprehensive toolkit!)

---

## Next Steps

1. ✅ **Implement File System Tools** (1-2 hours) - Quick win!
2. ✅ **Implement Git Tools** (2-3 hours) - High value for meta-registry
3. ✅ **Implement Database Tools** (2-3 hours) - Essential for data-driven agents
4. ⏳ **Implement Test Tools** (3-4 hours) - Quality tracking
5. ⏳ **Implement NATS Tools** (2 hours) - Distributed system observability

**Total Effort:** ~10-15 hours for comprehensive toolkit

**ROI:** Massive - transforms Singularity into a true autonomous coding assistant! 🚀
