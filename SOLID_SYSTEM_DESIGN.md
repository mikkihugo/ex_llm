# Solid Template System - Real-World Design

## How Singularity Actually Uses Templates

Based on code analysis, Singularity uses templates in **5 distinct workflows**:

### 1. **Agent Code Generation** (Cost-Optimized Agent)
**Current Flow**:
```
User Request → Agent → Rules (90% free)
                     ↓ (if low confidence)
                  Template Lookup → Fill Variables → Generated Code
                     ↓ (if no template)
                  LLM Call ($$$) → Generated Code
```

**Template Needs**:
- **Fast**: Rule-based generation needs <1ms templates
- **Composable**: Combine base + domain-specific patterns
- **Cacheable**: Same template used 1000s of times
- **Learning**: Track which templates work (success_rate)

### 2. **Quality Code Generator** (Production Quality)
**Current Flow**:
```
Task → Load Quality Template → RAG Search for Examples
    → Generate Code + Docs + Specs + Tests
    → Quality Score → Store in Learning Loop
```

**Template Needs**:
- **Multi-part**: Code + docs + specs + tests in ONE template
- **Quality-aware**: Production vs. Standard vs. Draft variants
- **Language-specific**: Elixir, Rust, TypeScript, etc.
- **Example-aware**: RAG embeddings find similar past code

### 3. **Framework Detection & Enrichment** (Architecture Engine)
**Current Flow**:
```
Unknown Code → Framework Detector → Confidence < 0.7
    → LLM Enrichment (uses framework_discovery.json prompt)
    → Extract Patterns → Store in FrameworkPatternStore
```

**Template Needs**:
- **Prompt templates**: LLM prompts for framework analysis
- **Pattern extraction**: Structured JSON schemas
- **Detection rules**: Regex patterns, file patterns

### 4. **SPARC Orchestration** (5-Step Methodology)
**Current Flow**:
```
Goal → Specification → Pseudocode → Architecture → Refinement → Implementation
       ↓ Each step uses a workflow template
```

**Template Needs**:
- **Workflow chains**: Step 1 output → Step 2 input
- **Contextual**: Each step builds on previous
- **Structured**: Specific schema for each phase

### 5. **Template Evolution** (Learning Loop)
**Current Flow**:
```
Template Used → Track Usage → Success/Failure
    → After 100+ uses at 95%+ success
    → Auto-export to templates_data/learned/
    → Human Review → Promote to Production
```

**Template Needs**:
- **Version tracking**: Know when template improved
- **Usage metrics**: success_count, failure_count, avg_performance_ms
- **Diff tracking**: What changed between versions
- **A/B testing**: Compare v1.0 vs. v1.1

## The Real Problem: Templates Are Static, Workflows Are Dynamic

### Current Limitations

**Problem 1: Templates Don't Compose Well**
```elixir
# Agent wants: GenServer + NATS Consumer + Error Handling
# Current: Must have ONE mega-template for "elixir-nats-genserver"
# Reality: Should compose 3 partials!
```

**Problem 2: No Context Awareness**
```elixir
# Quality level should affect template selection
quality_code_generator.ex:157  # Hardcoded logic!
# Should be: Template system knows production != draft
```

**Problem 3: Templates Don't Learn**
```elixir
# Usage tracked in PostgreSQL, but template never evolves
# Should be: High-success templates auto-upgrade
```

**Problem 4: No Agent Integration**
```elixir
cost_optimized_agent.ex:339  # get_template_for_task → returns nil
# Templates not connected to agent decision-making
```

## Solution: Context-Aware Template Composition with Solid

### Design Principles

1. **Composability**: Small partials, not mega-templates
2. **Context-Awareness**: Templates adapt to quality, language, task type
3. **Learning**: Templates evolve based on usage
4. **Agent-First**: Templates integrated with rule engine
5. **Performance**: Cached, compiled, <1ms rendering

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│             Template Context (Runtime)                    │
│  - quality_level: :production | :standard | :draft       │
│  - language: "elixir" | "rust" | ...                     │
│  - task_type: :genserver | :nats_consumer | ...          │
│  - agent_specialization: :elixir_developer | ...         │
│  - framework_context: %{phoenix: "1.7", ecto: "3.11"}    │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│        Template Recommendation Engine                     │
│  1. Rule-Based: task_type → base template                │
│  2. Semantic Search: RAG finds similar past uses          │
│  3. Learning Boost: success_rate > 0.95 → prefer         │
│  4. Composition: Combine base + domain partials          │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│           Solid Template Renderer (Enhanced)              │
│  - Auto-select partials based on context                 │
│  - Conditionals: {{#if use_genserver}}                   │
│  - Loops: {{#each error_types}}                          │
│  - Custom helpers: {{module_to_path}}                    │
│  - Compile & cache for <1ms render                       │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│              Generated Code + Metadata                    │
│  - code: String (rendered template)                      │
│  - template_id: "elixir-genserver-nats"                  │
│  - partials_used: ["_genserver", "_nats", "_telemetry"]  │
│  - render_time_ms: 0.8                                   │
│  - cache_hit: true                                       │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│               Learning Loop Feedback                      │
│  Track: template_id, success/failure, context            │
│  After 100+ uses at 95%+ success:                        │
│    → Export to templates_data/learned/                   │
│    → Promote to production templates                     │
└─────────────────────────────────────────────────────────┘
```

### Key Components

## 1. Context-Aware Template Selection

```elixir
defmodule Singularity.Templates.ContextSelector do
  @moduledoc """
  Selects templates based on runtime context.

  Context includes:
  - Quality level (production/standard/draft)
  - Language
  - Task type
  - Agent specialization
  - Framework dependencies
  """

  def select_template(context) do
    # 1. Rule-based selection
    base = rule_based_selection(context)

    # 2. RAG semantic search
    similar = semantic_search(context.task_description)

    # 3. Learning boost
    best_performing = learning_boost(base, similar)

    # 4. Return template + partials to compose
    %{
      base: best_performing,
      partials: select_partials(context),
      layout: select_layout(context)
    }
  end
end
```

## 2. Composable Partials

**Partial Library** (`priv/templates/partials/`):

### Base Patterns
- `_moduledoc.hbs` - Standard @moduledoc structure
- `_function_doc.hbs` - @doc for functions with examples
- `_typespec.hbs` - @spec declarations
- `_error_handling.hbs` - Result tuples, error cases

### OTP Patterns
- `_genserver_base.hbs` - GenServer boilerplate
- `_genserver_callbacks.hbs` - init, handle_call, handle_cast
- `_supervisor.hbs` - Supervisor configuration
- `_application.hbs` - Application module

### Messaging Patterns
- `_nats_consumer.hbs` - NATS subscription & message handling
- `_nats_publisher.hbs` - NATS publish with error handling
- `_broadway_producer.hbs` - Broadway data pipeline
- `_genstage_producer.hbs` - GenStage producer/consumer

### Quality Patterns
- `_telemetry.hbs` - Telemetry instrumentation
- `_logging.hbs` - Structured logging
- `_metrics.hbs` - Prometheus metrics
- `_tests.hbs` - ExUnit test structure

### Framework-Specific
- `_phoenix_controller.hbs` - Phoenix controller actions
- `_phoenix_live_view.hbs` - LiveView module structure
- `_ecto_schema.hbs` - Ecto schema with changesets

## 3. Quality-Aware Templates

**Same template, different quality levels**:

```handlebars
defmodule {{module_name}} do
  {{#if quality.production}}
  @moduledoc """
  {{description}}

  ## Overview
  {{overview}}

  ## Public API
  {{#each api_functions}}
  - `{{name}}({{args}}) :: {{return_type}}`
  {{/each}}

  ## Error Matrix
  {{#each error_types}}
  - `:{{atom}}` - {{description}}
  {{/each}}

  ## Examples
  {{#each examples}}
      # {{comment}}
      {{code}}
  {{/each}}
  """
  {{else if quality.standard}}
  @moduledoc """
  {{description}}

  ## Public API
  {{#each api_functions}}
  - `{{name}}({{args}}) :: {{return_type}}`
  {{/each}}
  """
  {{else}}
  @moduledoc "{{description}}"
  {{/if}}

  {{> _implementation}}
end
```

## 4. Agent-Template Integration

```elixir
defmodule Singularity.Templates.AgentBridge do
  @moduledoc """
  Bridge between agents and template system.

  Agents call this instead of directly rendering templates.
  """

  def generate_for_agent(agent_id, task) do
    # Get agent context
    agent = get_agent_state(agent_id)

    # Build context from agent + task
    context = %{
      quality_level: infer_quality(task),
      language: task.language || agent.preferred_language,
      task_type: classify_task_type(task),
      agent_specialization: agent.specialization,
      framework_context: detect_frameworks(agent.workspace)
    }

    # Select template
    selection = ContextSelector.select_template(context)

    # Render with Solid
    variables = build_variables_from_task(task, context)
    {:ok, code} = Renderer.render_with_solid(selection.base, variables)

    # Track usage for learning
    track_template_usage(selection.base, agent_id, task)

    {:ok, code, metadata: selection}
  end
end
```

## 5. Template Learning & Evolution

```elixir
defmodule Singularity.Templates.Evolution do
  @moduledoc """
  Tracks template usage and evolves templates based on success.

  Learning Loop:
  1. Track every template use (success/failure)
  2. After 100+ uses at 95%+ success → candidate for promotion
  3. Export to templates_data/learned/
  4. Human reviews and promotes to production
  """

  def track_usage(template_id, result) do
    # Update knowledge_artifacts table
    ArtifactStore.record_usage(template_id,
      success: result.success?,
      duration_ms: result.duration_ms,
      context: result.context
    )

    # Check if ready for promotion
    check_promotion_eligibility(template_id)
  end

  defp check_promotion_eligibility(template_id) do
    case ArtifactStore.get(template_id) do
      {:ok, artifact} when artifact.usage_count >= 100 ->
        success_rate = artifact.success_count / artifact.usage_count

        if success_rate >= 0.95 do
          # Candidate for promotion
          export_learned_template(artifact)
        end

      _ ->
        :not_ready
    end
  end
end
```

## Implementation Plan

### Phase 1: Core Infrastructure (4 hours)
- [x] Solid dependency added
- [x] SolidHelpers with domain helpers
- [x] Dual-mode renderer (Solid + legacy)
- [ ] ContextSelector module
- [ ] AgentBridge module
- [ ] Template compilation & caching

### Phase 2: Partial Library (8 hours)
- [ ] Create 20+ reusable partials
  - Base patterns (5 partials)
  - OTP patterns (4 partials)
  - Messaging patterns (4 partials)
  - Quality patterns (4 partials)
  - Framework-specific (3+ partials)
- [ ] Test each partial independently
- [ ] Document partial composition rules

### Phase 3: Quality-Aware System (4 hours)
- [ ] Quality-level context tracking
- [ ] Template variants (production/standard/draft)
- [ ] Quality scoring integration
- [ ] RAG integration for template search

### Phase 4: Agent Integration (6 hours)
- [ ] Update CostOptimizedAgent to use AgentBridge
- [ ] Update QualityCodeGenerator to use context system
- [ ] Add template metrics to agent stats
- [ ] Test end-to-end agent → template → code flow

### Phase 5: Learning System (6 hours)
- [ ] Template usage tracking
- [ ] Success rate calculation
- [ ] Auto-export to learned/
- [ ] Template diff & versioning
- [ ] A/B testing framework

### Phase 6: Migration (8 hours)
- [ ] Migrate remaining 70+ templates
- [ ] Convert to partial-based composition
- [ ] Add quality variants
- [ ] Performance benchmarks

## Expected Benefits

### For Agents
- **90% rule-based generation** (was: template lookup fails → LLM)
- **<1ms template rendering** (was: 50-200ms LLM calls)
- **$0 cost for cached patterns** (was: $0.06 per LLM call)
- **Higher confidence** (template success_rate visible)

### For Quality System
- **Consistent quality** (production templates enforce standards)
- **Multi-part generation** (code + docs + specs + tests)
- **Language-specific best practices** (per-language partials)
- **RAG-powered examples** (semantic search finds similar code)

### For Learning Loop
- **Template evolution** (high-success templates auto-improve)
- **Context-aware learning** (track success by quality/language/task)
- **Human-in-the-loop** (learned templates reviewed before production)
- **Continuous improvement** (templates get better over time)

### Performance Metrics

**Target Performance**:
- Template selection: <5ms (rule-based + RAG)
- Template rendering: <1ms (cached compilation)
- Total generation: <10ms (vs. 50-200ms LLM)

**Cost Savings**:
- Rule-based generation: $0 (was: $0.06 per LLM call)
- 1000 generations/day: Save $60/day = $1,800/month
- Template reuse: 90% of requests = $1,620/month savings

## Next Steps

1. **Finish Core Infrastructure** (this session)
   - ContextSelector
   - AgentBridge
   - Template caching

2. **Create Partial Library** (next session)
   - 20+ reusable partials
   - Test compositions
   - Documentation

3. **Integrate with Agents** (after partials)
   - Update CostOptimizedAgent
   - Update QualityCodeGenerator
   - End-to-end testing

4. **Deploy Learning System** (final phase)
   - Usage tracking
   - Auto-export
   - A/B testing

Let's start with Phase 1!
