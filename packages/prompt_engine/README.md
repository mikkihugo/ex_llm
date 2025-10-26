# Prompt Engine - ML-Based Prompt Optimization

**Purpose**: Generic ML-powered prompt optimization using DSPy/COPRO. Domain-agnostic infrastructure for learning from execution history.

## 🎯 What This Engine Does

1. **ML Optimization** - COPRO algorithm (generate 10 variants, pick best)
2. **Performance Tracking** - Learn from execution history via `prompt_tracking`
3. **Neural Training** - Candle-based ML models predict prompt success
4. **Context Assembly** - Combine templates + context for hyper-specific prompts

## 📊 Prompt Flow Architecture

### The Complete Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 1: TEMPLATE RETRIEVAL (Storage Layer)                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ 1. Central Template Service (central_cloud)                      │
│    Location: central_cloud/lib/central_cloud/template_service.ex │
│    Storage: PostgreSQL (global, shared across instances)         │
│    Purpose: SINGLE SOURCE OF TRUTH for all templates             │
│                                                                   │
│    - Loads from templates_data/ on startup                       │
│    - Serves via NATS: central.template.{get|search|store}       │
│    - Tracks usage analytics for learning                         │
│    - Broadcasts updates to all instances                         │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 2: LOCAL OPTIMIZATION (prompt_engine - THIS CRATE)        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ 2. Template Assembly (prompt_bits/)                              │
│    - Request template from CentralCloud via NATS                 │
│    - Inject context (language, framework, domain)                │
│    - Expand variables: {{language}}, {{framework}}, etc.         │
│    - Output: AssembledPrompt                                     │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ 3. ML Optimization (dspy/)                                       │
│    - COPRO generates 10 candidate variations                     │
│    - Neural net scores candidates (Candle ML)                    │
│    - Selects best based on learned patterns                      │
│    - Uses prompt_tracking historical data                        │
│    - Output: OptimizationResult                                  │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ 4. Caching (caching/)                                            │
│    - Check PromptCache for similar context                       │
│    - Cache key: context_signature hash                           │
│    - Skip optimization if cached (performance)                   │
│    - Output: Cached or optimized prompt                          │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 3: EXECUTION & LEARNING                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ 5. Execution (external - sent to LLM)                            │
│    - Execute optimized prompt                                    │
│    - Measure: timing, success, response quality                  │
│    - Generate context_signature for tracking                     │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ 6. Prompt Tracking (prompt_tracking/)                            │
│    - Store: PromptExecutionEntry (timing, success, confidence)   │
│    - Store: PromptFeedbackEntry (user ratings)                   │
│    - Store: PromptEvolutionEntry (optimization improvements)     │
│    - Store: ABTestResultEntry (A/B test results)                 │
│    - Communication: NATS → PostgreSQL                            │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ 7. Continuous Learning (dspy_learning/)                          │
│    - Query historical execution data                             │
│    - Train Candle neural network                                 │
│    - Update COPRO optimizer parameters                           │
│    - Improve future prompt generation                            │
└──────────────────────────────────────────────────────────────────┘
```

## 🔑 Key Architectural Decisions

### Why Two Template Systems?

**Central Template Service** (central_cloud):
- ✅ **Global storage** - PostgreSQL (one copy, shared)
- ✅ **Source of truth** - All instances fetch from here
- ✅ **Analytics** - Tracks usage across all instances
- ✅ **Distribution** - NATS broadcasts updates
- **Purpose**: Storage & distribution

**Local Templates** (prompt_engine):
- ✅ **Hardcoded defaults** - System prompts, SPARC templates
- ✅ **No network needed** - Works offline for core functionality
- ✅ **Domain-specific** - SPARC methodology, Rust-specific
- ⚠️ **Being phased out** - Move to central_cloud over time
- **Purpose**: Backwards compatibility & offline operation

### Template Types in This Crate

1. **`templates.rs`** (132 lines)
   - `PromptTemplate` struct - Generic template type
   - `RegistryTemplate` - In-memory template registry
   - `TemplateLoader` - Placeholder for loading (should use central_cloud)
   - **Status**: ⚠️ Infrastructure only, move logic to central_cloud

2. **`sparc_templates.rs`** (466 lines)
   - SPARC methodology prompts (Specification, Architecture, etc.)
   - System behavior prompts (plan mode, beast mode, CLI mode)
   - Flow coordination prompts
   - **Status**: ✅ Keep - SPARC-specific, not domain templates

3. **`rust_dspy_templates.rs`** (565 lines)
   - Rust code analysis templates
   - DSPy prompt examples
   - **Status**: ⚠️ Should move to central_cloud or architecture_engine

4. **`template_loader.rs`** (168 lines)
   - Loads templates from files
   - **Status**: ⚠️ Redundant with central_cloud, remove

5. **`template_performance_tracker.rs`** (292 lines)
   - Tracks template performance with HTDAG
   - ML-driven template selection
   - **Status**: ✅ Keep - Performance/learning infrastructure

## 📝 Example Usage

### Basic Flow

```rust
use prompt_engine::{PromptEngine, AssemblyContext};

// 1. Create engine
let mut engine = PromptEngine::new()?;

// 2. Fetch template from central_cloud (via NATS)
// This happens internally when you call optimize_prompt

// 3. Optimize with COPRO
let result = engine.optimize_prompt("Analyze this Rust code for bugs")?;

println!("Optimized: {}", result.optimized_prompt);
println!("Score: {}", result.optimization_score);
```

### With Context Assembly

```rust
// 1. Assemble with context
let context = AssemblyContext {
    language: "rust".to_string(),
    domain: "web_backend".to_string(),
    templates: vec!["axum_api".to_string()],
};

// 2. Get SPARC-specific prompt
let sparc_prompt = engine.get_optimized_sparc_prompt(
    "sparc_implementation",
    Some(hashmap!{
        "language" => "rust",
        "framework" => "axum"
    })
)?;
```

### With Tracking

```rust
use prompt_engine::prompt_tracking::{
    PromptTrackingStorage,
    PromptExecutionEntry,
    PromptExecutionData
};

// 1. Execute prompt
let start = Instant::now();
let response = llm.execute(&optimized_prompt).await?;
let duration = start.elapsed();

// 2. Track execution
let storage = PromptTrackingStorage::new_global().await?;
let entry = PromptExecutionEntry {
    prompt_id: "rust_analysis".to_string(),
    execution_time_ms: duration.as_millis() as u64,
    success: response.success,
    confidence_score: 0.9,
    context_signature: hash_context(&context),
    response_length: response.text.len(),
    timestamp: Utc::now(),
    metadata: HashMap::new(),
};

storage.store(PromptExecutionData::PromptExecution(entry)).await?;
```

## 🚀 What Makes It "An Engine"

1. **Self-improving** - Learns from every execution via neural training
2. **ML-powered** - Candle neural networks + DSPy optimizers
3. **Data-driven** - Queries historical patterns for decisions
4. **Adaptive** - Adjusts based on context (framework, domain, language)
5. **Distributed** - Learns across all instances via central_cloud

## 🔄 Migration Path (TODOs)

### Short Term
- [ ] Move `rust_dspy_templates.rs` content to `central_cloud` PostgreSQL
- [ ] Remove `template_loader.rs` (use central_cloud NATS API instead)
- [ ] Update `RegistryTemplate` to fetch from NATS, not hardcoded

### Long Term
- [ ] Keep only `sparc_templates.rs` (SPARC methodology-specific)
- [ ] Keep `template_performance_tracker.rs` (learning infrastructure)
- [ ] Keep `templates.rs` types (generic structs)
- [ ] Remove all hardcoded domain templates

### Why Keep SPARC Templates Local?
- **Methodology-specific** - Not domain knowledge like "microservices"
- **Offline operation** - SPARC can work without central_cloud
- **Versioning** - SPARC templates version with prompt_engine code

## 📚 Related Documentation

- **[UNIFIED_NIF_LOADING.md](../../UNIFIED_NIF_LOADING.md)** - How NIFs load
- **[RUST_ENGINES_INVENTORY.md](../../RUST_ENGINES_INVENTORY.md)** - All Rust engines
- **Prompt Tracking**: [prompt_tracking/mod.rs](src/prompt_tracking/mod.rs)
- **Central Template Service**: [central_cloud/lib/central_cloud/template_service.ex](../../central_cloud/lib/central_cloud/template_service.ex)

## 🎯 Summary

**prompt_engine** = Generic ML optimization infrastructure
**central_cloud** = Global template storage & distribution
**architecture_engine** = Domain-specific templates (microservices, etc.)

Clean separation: Infrastructure vs Storage vs Domain Knowledge! 🎉
