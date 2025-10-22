# Agent System Documentation

Complete documentation for Singularity's autonomous agent system.

## Overview

Singularity implements a sophisticated multi-agent system with **6 agent types**, each specialized for different tasks. All agents share common infrastructure for supervision, flow tracking, and cost optimization.

## Agent Types

### 1. Self-Improving Agent
**Purpose:** Autonomous evolution based on performance metrics

**Lifecycle States:**
- `Idle` → `Observing` → `Evaluating` → `Generating` → `Validating` → `Hot Reload` → `Validation Wait`

**Key Features:**
- Metrics-based decision making
- Autonomy Decider scoring (success rate, task completion, error rate)
- Hot reload validation with fallback
- Flow tracker integration for PostgreSQL audit

**Code:** `lib/singularity/agent.ex`

### 2. Cost-Optimized Agent  
**Purpose:** Minimize LLM costs using rules-first strategy

**Decision Flow:**
1. **Phase 1: Rules** - Check rule engine (Cachex + PostgreSQL) - FREE
2. **Phase 2: Cache** - Check LLM response cache - FREE  
3. **Phase 3: LLM** - Fallback to LLM only if needed - $$

**Cost Tracking:**
- Lifetime cost accumulation
- Per-task cost calculation
- Cost efficiency metrics

**Code:** `lib/singularity/agents/cost_optimized_agent.ex`

### 3. Architecture Agent
**Purpose:** System design analysis and recommendations

**Capabilities:**
- Architecture pattern detection
- Design quality assessment
- Naming convention validation

### 4. Technology Agent
**Purpose:** Tech stack detection and analysis

**Capabilities:**
- Framework detection (30+ frameworks)
- Language identification
- Dependency analysis

### 5. Refactoring Agent
**Purpose:** Code quality improvements

**Capabilities:**
- Code smell detection
- Refactoring suggestions
- Quality metrics calculation

### 6. Chat Conversation Agent
**Purpose:** Interactive AI conversations

**Capabilities:**
- Multi-turn dialogue
- Context management
- Tool execution integration

## Supporting Systems

### Autonomy Decider
**Purpose:** Calculate improvement scores and make evolution decisions

**Metrics:**
- Success rate (successful tasks / total tasks)
- Task completion rate  
- Error rate
- Response time

**Scoring Algorithm:**
```elixir
score = (success_rate * 0.4) + (completion_rate * 0.3) + 
        (1 - error_rate) * 0.2 + (speed_factor * 0.1)
```

**Code:** `lib/singularity/autonomy/decider.ex`

### Autonomy Limiter
**Purpose:** Rate limiting and budget control

**Limits:**
- Max improvements per day (configurable)
- Budget thresholds
- Concurrent operation limits

**Code:** `lib/singularity/autonomy/limiter.ex`

### Rule Engine
**Purpose:** Fast, free rule-based decisions

**Storage:**
- L1: Cachex (in-memory)
- L2: PostgreSQL (persistent)

**Performance:** Sub-millisecond lookups, zero LLM cost

**Code:** `lib/singularity/autonomy/rule_engine.ex`

### Hot Reload Manager
**Purpose:** Dynamic code compilation and activation

**Process:**
1. Generate new code
2. Compile to BEAM
3. Validate functionality
4. Activate or rollback

**Safety:** Always maintains rollback capability

**Code:** `lib/singularity/hot_reload.ex`

### Code Store
**Purpose:** Versioned code storage

**Features:**
- Version control for generated code
- Diff tracking
- Rollback support

### Flow Tracker
**Purpose:** PostgreSQL-based operation tracking

**Data Tracked:**
- Agent operations
- Improvement attempts
- Performance metrics
- Error conditions

**Schema:** `executions` table in PostgreSQL

**Code:** `lib/singularity/flow_tracker.ex`

## Agent Supervision

**Supervision Tree:**
```
Singularity.Supervisor
├── Agent Supervisor (one_for_one)
│   ├── Self-Improving Agent
│   ├── Cost-Optimized Agent
│   ├── Architecture Agent
│   ├── Technology Agent
│   ├── Refactoring Agent
│   └── Chat Agent
├── Autonomy Supervisor
│   ├── Decider
│   ├── Limiter
│   └── Rule Engine
└── Infrastructure Supervisor
    ├── Hot Reload Manager
    ├── Code Store
    └── Flow Tracker
```

**Restart Strategy:** `one_for_one` - isolated failure recovery

## Agent Communication

### Synchronous (`:call`)
```elixir
GenServer.call(agent_pid, {:execute_task, task})
```

### Asynchronous (`:cast`)  
```elixir
GenServer.cast(agent_pid, {:record_metric, metric})
```

### NATS Messaging
```elixir
Gnat.request(conn, "agent.execute", payload)
```

## Flow Diagrams

See **SYSTEM_FLOWS.md** for comprehensive Mermaid diagrams:

- **Diagram 19:** Agent Architecture Overview
- **Diagram 20:** Self-Improving Agent Lifecycle
- **Diagram 21:** Self-Improving Agent Sequence
- **Diagram 22:** Cost-Optimized Agent Flow

## Testing

**Comprehensive test suite:** `test/singularity/agent_flow_test.exs`

**23 tests covering:**
- Self-Improving Agent Lifecycle (8 tests)
- Cost-Optimized Agent Flow (4 tests)  
- Agent Supervision & Recovery (3 tests)
- Flow Tracking Integration (2 tests)
- Agent Communication (3 tests)
- Error Handling (3 tests)

**Run tests:**
```bash
cd singularity
mix test test/singularity/agent_flow_test.exs
```

## Agent Process Registry

**Registration:**
```elixir
{:via, Registry, {Singularity.AgentRegistry, agent_id}}
```

**Lookup:**
```elixir
Registry.lookup(Singularity.AgentRegistry, agent_id)
```

**Benefits:**
- Unique agent identification
- Crash recovery with same ID
- Process discovery

## Key Metrics

**Self-Improving Agent:**
- Observation count
- Evaluation score
- Improvement queue length
- Hot reload success rate

**Cost-Optimized Agent:**
- Rule hit rate (% of requests from rules)
- Cache hit rate (% of requests from cache)
- LLM fallback rate
- Lifetime cost ($)
- Average cost per task

## Integration Points

**With NATS:**
- Agent task execution requests
- Result publishing
- Event broadcasting

**With PostgreSQL:**
- Flow tracking (executions table)
- Rule storage (rules table)
- LLM response cache (cache_llm_responses)
- Code embeddings cache (cache_code_embeddings)

**With Rust NIFs:**
- Code quality analysis (QualityEngine NIF)
- Architecture validation (ArchitectureEngine NIF)
- Parsing (ParserEngine NIF)

## Configuration

**Environment Variables:**
```bash
IMP_LIMIT_PER_DAY=100              # Max improvements per day
IMP_VALIDATION_DELAY_MS=30000     # Validation delay before finalizing
MIN_CONFIDENCE_THRESHOLD=95       # Initial deployment confidence threshold
```

**Mix Config:**
```elixir
config :singularity,
  agent_supervisor_strategy: :one_for_one,
  agent_restart_strategy: :permanent,
  max_improvements_per_day: 100
```

## See Also

- **SYSTEM_FLOWS.md** - Visual flow diagrams
- **CLAUDE.md** - Development guide
- **README.md** - Quick start
- **RUST_ENGINES_INVENTORY.md** - NIF engines used by agents
    fn default() -> Self {
        Self::new()
    }
}
```

### 5. Update Main Module

Replace the large file with a clean orchestrator:

```rust
//! Main Module - Orchestrator
//!
//! Coordinates all functionality using modular components.

// Import modular components
use crate::naming_suggestions::NamingSuggestions;
use crate::naming_utilities::NamingUtilities;
use crate::architecture_patterns::ArchitecturePatterns;

/// Main handler
pub struct MainModule {
    pub(crate) suggestions: NamingSuggestions,
    pub(crate) utilities: NamingUtilities,
    pub(crate) patterns: ArchitecturePatterns,
}

impl MainModule {
    /// Create new instance
    pub fn new() -> Self {
        Self {
            suggestions: NamingSuggestions::new(),
            utilities: NamingUtilities::new(),
            patterns: ArchitecturePatterns::new(),
        }
    }
    
    /// Delegate to appropriate module
    pub fn suggest_function_names(&self, description: &str) -> Vec<String> {
        self.suggestions.suggest_function_names(description)
    }
    
    pub fn validate_name(&self, name: &str) -> bool {
        self.utilities.validate_name(name)
    }
}
```

## Advanced Patterns

### Extract by Function Type

```bash
# All public functions
awk '/pub fn /,/^    }/' file.rs > public_functions.rs

# All private functions  
awk '/    fn /,/^    }/' file.rs > private_functions.rs

# All trait implementations
awk '/impl.*for/,/^}/' file.rs > trait_implementations.rs
```

### Extract by Module Section

```bash
# All struct definitions
awk '/^pub struct/,/^}/' file.rs > structs.rs

# All enum definitions
awk '/^pub enum/,/^}/' file.rs > enums.rs

# All type aliases
awk '/^pub type/,/;/' file.rs > type_aliases.rs
```

### Extract with Context

```bash
# Functions with 5 lines of context before/after
awk '/fn function_name/,/^    }/' file.rs | head -n -5 | tail -n +6 > function_with_context.rs
```

## Validation Checklist

Before considering refactoring complete:

- [ ] Function count matches original
- [ ] All dependencies are properly imported
- [ ] Module structure is logical and coherent
- [ ] Main orchestrator delegates correctly
- [ ] No compilation errors
- [ ] All tests still pass
- [ ] Documentation is updated

## Example: Complete Workflow

```bash
# 1. Backup original
cp naming_conventions.rs naming_conventions_old.rs

# 2. Extract by pattern
awk '/fn suggest_/,/^    }/' naming_conventions_old.rs > suggest_functions.rs
awk '/fn generate_/,/^    }/' naming_conventions_old.rs > generate_functions.rs
awk '/fn validate_/,/^    }/' naming_conventions_old.rs > validate_functions.rs
awk '/fn to_/,/^    }/' naming_conventions_old.rs > to_functions.rs

# 3. Validate counts
echo "Original: $(grep -c 'fn ' naming_conventions_old.rs)"
echo "Extracted: $(grep -c 'fn ' *_functions.rs)"

# 4. Organize into modules
cat suggest_functions.rs generate_functions.rs > naming_suggestions.rs
cat validate_functions.rs to_functions.rs > naming_utilities.rs

# 5. Create new main file
# (manually create orchestrator)

# 6. Clean up
rm *_functions.rs
```

## Benefits

- **Preserves Functionality**: No code is lost during refactoring
- **Systematic**: Uses patterns to ensure comprehensive extraction
- **Validatable**: Function counts can verify completeness
- **Maintainable**: Smaller, focused modules are easier to understand
- **Testable**: Individual modules can be tested in isolation

## Anti-Patterns to Avoid

❌ **Manual Copy-Paste**: Error-prone, easy to miss functions
❌ **Extract Individual Functions**: Inefficient, misses related functions
❌ **Skip Validation**: Risk of losing functionality
❌ **Ignore Dependencies**: Functions won't compile without proper imports
❌ **Poor Module Organization**: Functions grouped without logical coherence

## Tools Used

- `awk` - Pattern-based extraction
- `grep -c` - Function counting for validation
- `cat` - Merging related functions
- `head`/`tail` - Context inspection
- `wc -l` - Line counting for size validation

This approach ensures large files are systematically broken down while maintaining 100% functionality preservation.