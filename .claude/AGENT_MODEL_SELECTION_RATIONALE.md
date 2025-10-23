# Agent Model Selection Rationale

**Date**: 2025-10-23
**Final Configuration**: 4 Sonnet + 2 Haiku = 85% average cost reduction

## Cost Breakdown

| Model | Cost per 1M tokens | Use Case |
|-------|-------------------|----------|
| **Opus** | $15/1M | Complex reasoning, architecture (NOT USED) |
| **Sonnet 4.5** | $3/1M | Balanced work, implementation, technical analysis |
| **Haiku 4.5** | $1/1M | Simple tasks, scanning, automated checks |

## Final Agent Configuration

### Sonnet 4.5 Agents (4 agents) - $3/1M tokens

#### 1. elixir-specialist
**Why Sonnet**: Requires understanding of complex OTP patterns, supervision trees, and distributed systems architecture.
- Needs to reason about process lifecycle, restart strategies
- Must analyze layered supervision patterns
- Should understand NATS messaging architecture
- **Task complexity**: Medium-High

#### 2. rust-nif-specialist
**Why Sonnet**: Requires understanding of Rustler FFI, memory safety, and Elixir integration.
- Needs to reason about unsafe code, memory layout
- Must understand Rust ownership + Elixir BEAM integration
- Should handle GPU acceleration patterns (CUDA/Metal)
- **Task complexity**: High

#### 3. typescript-bun-specialist
**Why Sonnet**: Requires understanding of modern AI SDK patterns and async/distributed systems.
- Needs to reason about AI SDK v5 tool definitions
- Must understand NATS streaming patterns
- Should handle provider abstractions across 8 different LLMs
- **Task complexity**: Medium-High

#### 4. agent-system-expert
**Why Sonnet**: Requires deep architectural reasoning about agent lifecycle and orchestration.
- Needs to design supervision trees for dynamic agents
- Must reason about cost optimization strategies
- Should understand feedback loops and self-improvement
- **Task complexity**: High (architecture & planning)

### Haiku 4.5 Agents (2 agents) - $1/1M tokens ⚡

#### 5. technical-debt-analyzer
**Why Haiku**: Primarily scanning and categorizing - straightforward pattern matching.
- **Main task**: Scan files for TODO/FIXME/HACK markers
- **Categorization**: Simple classification (missing feature, deprecated, optimization)
- **Prioritization**: Rule-based (critical → high → medium → low)
- **Output**: Structured lists and matrices
- **Task complexity**: Low-Medium (scanning + simple reasoning)
- **Benefit**: 93% cost reduction, faster execution

#### 6. strict-code-checker
**Why Haiku**: Runs automated quality checks and verifies against checklists.
- **Main task**: Execute automated skills (elixir-quality, rust-check, typescript-check)
- **Verification**: Check against known patterns and rules
- **Output**: Pass/fail results with specific error messages
- **Task complexity**: Low-Medium (automated checks + pattern matching)
- **Benefit**: 93% cost reduction, faster feedback loop

## Cost Impact Analysis

### Before (All Opus)
```
6 agents × $15/1M tokens = $90/1M tokens total
```

### After (4 Sonnet + 2 Haiku)
```
4 agents × $3/1M tokens  = $12/1M tokens (elixir, rust, typescript, agent-system)
2 agents × $1/1M tokens  = $2/1M tokens (debt-analyzer, code-checker)
Total: $14/1M tokens
```

**Savings**: $90 → $14 = **84.4% cost reduction** 🎉

### Per-Agent Savings

| Agent | Before | After | Savings |
|-------|--------|-------|---------|
| elixir-specialist | $15 | $3 | 80% |
| rust-nif-specialist | $15 | $3 | 80% |
| typescript-bun-specialist | $15 | $3 | 80% |
| technical-debt-analyzer | $15 | **$1** | **93%** ⚡ |
| agent-system-expert | $15 | $3 | 80% |
| strict-code-checker | $15 | **$1** | **93%** ⚡ |

## Haiku 4.5 Decision Criteria

**Use Haiku when agent primarily does**:
- ✅ File scanning and pattern matching
- ✅ Simple categorization/classification
- ✅ Running automated tools/scripts
- ✅ Checklist-based verification
- ✅ Structured output generation (lists, tables)

**Use Sonnet when agent needs**:
- ❌ Architectural reasoning
- ❌ Complex code understanding
- ❌ Multi-system integration analysis
- ❌ Deep technical expertise
- ❌ Design pattern recommendations

**Use Opus when agent requires** (currently: none):
- ❌ Highest-stakes decisions (security audits, production releases)
- ❌ Novel problem solving with no prior patterns
- ❌ Cross-domain reasoning with many dependencies

## Performance Considerations

### Haiku Benefits
- **Speed**: 3-5x faster than Sonnet for simple tasks
- **Cost**: $1/1M vs $3/1M (Sonnet) or $15/1M (Opus)
- **Best for**: Repetitive tasks, scanning, automated verification

### When Haiku Might Struggle
- Complex architecture decisions → Use Sonnet
- Novel pattern detection → Use Sonnet
- Deep reasoning chains → Use Sonnet

## Real-World Usage Patterns

### technical-debt-analyzer (Haiku ✅)
**Typical workflow**:
1. Scan codebase for TODO markers (simple grep-like operation)
2. Categorize each TODO by type (classification: 7 categories)
3. Assign priority (rule-based: critical/high/medium/low)
4. Generate roadmap (template-based output)

**Why Haiku works**: All steps are pattern-matching or rule-based classification. Haiku excels at this.

### strict-code-checker (Haiku ✅)
**Typical workflow**:
1. Run `elixir-quality` skill → Parse output for errors
2. Run `rust-check` skill → Parse clippy warnings
3. Run `typescript-check` skill → Parse tsc errors
4. Verify against checklist (security patterns, naming conventions)
5. Generate pass/fail report

**Why Haiku works**: Executing commands and parsing structured output. Fast feedback loop is more valuable than deep reasoning.

### elixir-specialist (Sonnet ✅)
**Typical workflow**:
1. Analyze supervision tree architecture (requires understanding OTP)
2. Identify restart strategy issues (requires reasoning about dependencies)
3. Suggest architectural improvements (requires design thinking)

**Why Sonnet needed**: Requires understanding of distributed systems, OTP patterns, and architectural trade-offs.

## Monitoring & Optimization

### Metrics to Track
1. **Cost per agent invocation**
2. **Task success rate** (Haiku vs Sonnet)
3. **Average response time** (Haiku should be faster)
4. **User satisfaction** (quality of output)

### Adjustment Triggers

**Upgrade Haiku → Sonnet if**:
- Task success rate drops below 85%
- User reports quality issues
- Agent struggles with edge cases

**Keep Haiku if**:
- Task success rate above 90%
- Fast feedback is valuable
- Tasks remain straightforward

## Conclusion

**Final configuration achieves**:
- ✅ 84.4% average cost reduction
- ✅ Faster execution for simple tasks (Haiku)
- ✅ High-quality output for complex tasks (Sonnet)
- ✅ No agents using expensive Opus unnecessarily

**Smart optimization**: Right tool for the job - Haiku for speed and cost, Sonnet for reasoning.
