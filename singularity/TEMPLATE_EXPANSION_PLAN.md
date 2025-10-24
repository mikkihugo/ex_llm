# Template Expansion Plan for Architecture Patterns

**Expand existing high-quality templates (JSON 2.3.0 + Lua/Handlebars) for CentralCloud Architecture LLM Team** 📝

---

## ✅ Existing High-Quality Templates

### Template System Structure

```
templates_data/
├── prompt_library/                  # Lua-based prompts
│   ├── architecture/
│   │   ├── discover-framework.lua   # ✅ Framework detection
│   │   └── detect-version.lua
│   ├── patterns/
│   │   └── extract-design-patterns.lua  # ✅ Design pattern extraction
│   └── quality/
│       └── extract-patterns.lua
├── code_generation/patterns/        # JSON templates for code gen
│   ├── UNIFIED_SCHEMA.json          # ✅ Technology detection schema
│   ├── rust-microservice.json
│   ├── typescript-microservice.json
│   └── messaging/, ai/, cloud/...
└── workflows/sparc/
    └── 3-architecture.json          # ✅ SPARC architecture workflow
```

### Template Quality Standards (Already Implemented!)

1. **JSON 2.3.0 format** ✅
   - Structured, validated schemas
   - Version tracking
   - LLM-aware metadata

2. **Lua-based prompts** ✅
   - Dynamic context injection
   - Workspace file access
   - Git integration

3. **Handlebars templates** ✅
   - Template variables
   - Conditional logic
   - Reusable components

---

## 🎯 What Needs to be Added

### Architecture Pattern Detection Templates

**Location:** `templates_data/prompt_library/architecture/`

**New templates needed:**

1. **`detect-microservices.lua`**
   - Detects microservices architecture
   - Indicators: Multiple services, API contracts, separate DBs
   - Used by: Architecture LLM Team (Analyst agent)

2. **`detect-monolith.lua`**
   - Detects monolithic architecture
   - Indicators: Single deployment unit, shared DB
   - Used by: Architecture LLM Team (Analyst agent)

3. **`detect-layered-architecture.lua`**
   - Detects layered/n-tier architecture
   - Indicators: Clear presentation/business/data layers
   - Used by: Architecture LLM Team (Analyst agent)

4. **`detect-event-driven.lua`**
   - Detects event-driven architecture
   - Indicators: Event bus, pub/sub, message queue
   - Used by: Architecture LLM Team (Analyst agent)

### Code Quality Pattern Templates

**Location:** `templates_data/prompt_library/quality/`

**New templates needed:**

1. **`detect-dry-violations.lua`**
   - Detects code duplication (DRY violations)
   - Indicators: Duplicate code blocks, repeated logic
   - Used by: Architecture LLM Team (Critic agent)

2. **`detect-solid-violations.lua`**
   - Detects SOLID principle violations
   - Indicators: SRP, OCP, LSP, ISP, DIP violations
   - Used by: Architecture LLM Team (Validator agent)

3. **`detect-code-smells.lua`**
   - Detects anti-patterns and code smells
   - Indicators: Long methods, god classes, feature envy
   - Used by: Architecture LLM Team (Critic agent)

### Pattern Validation Templates (for LLM Team)

**Location:** `templates_data/prompt_library/architecture/llm_team/`

**New templates for multi-agent collaboration:**

1. **`analyst-discover-pattern.lua`**
   - Prompt for Pattern Analyst (Claude Opus)
   - Input: Code samples
   - Output: Pattern analysis with confidence score

2. **`validator-validate-pattern.lua`**
   - Prompt for Pattern Validator (GPT-4 Turbo)
   - Input: Discovered pattern
   - Output: Technical validation score

3. **`critic-critique-pattern.lua`**
   - Prompt for Pattern Critic (Gemini Pro)
   - Input: Discovered pattern + validation
   - Output: Critique with weaknesses identified

4. **`researcher-research-pattern.lua`**
   - Prompt for Pattern Researcher (Claude Sonnet)
   - Input: Pattern name
   - Output: External validation (GitHub, papers, blogs)

5. **`coordinator-build-consensus.lua`**
   - Prompt for Team Coordinator (GPT-4o)
   - Input: All agent assessments
   - Output: Consensus score + approval decision

---

## 📝 Template Format Examples

### Example 1: detect-microservices.lua

```lua
-- Architecture Pattern Detection: Microservices
-- Analyzes codebase to detect microservices architecture pattern
--
-- Used by: Centralcloud.ArchitectureLLMTeam (Pattern Analyst agent)
-- Model: Claude Opus (best for deep analysis)
--
-- Input variables:
--   codebase_id: string - Project identifier
--   code_samples: table - Array of {path, content, language}
--
-- Returns: JSON prompt for LLM

local Prompt = require("prompt")
local prompt = Prompt.new()

-- Extract input
local codebase_id = context.codebase_id or "unknown"
local code_samples = context.code_samples or {}

prompt:section("ROLE", [[
You are the Pattern Analyst on the Architecture LLM Team.
Your specialty is discovering architecture patterns through deep code analysis.
]])

prompt:section("TASK", [[
Analyze this codebase and determine if it uses Microservices architecture.

Microservices indicators:
1. Multiple independent services (each with own repo/directory)
2. Each service has clear API boundaries
3. Services communicate via APIs (REST, gRPC, GraphQL)
4. Each service can be deployed independently
5. May use API gateway or service mesh
6. Often uses containerization (Docker)
7. May use service discovery (Consul, Eureka)
]])

-- Scan for service directories
local service_dirs = {}
local common_service_patterns = {
  "services/*/", "apps/*/", "packages/*/",
  "*/package.json", "*/Cargo.toml", "*/mix.exs"
}

for _, pattern in ipairs(common_service_patterns) do
  local files = workspace.glob(pattern)
  if files and #files > 0 then
    for _, file in ipairs(files) do
      table.insert(service_dirs, file)
    end
  end
end

if #service_dirs > 0 then
  prompt:section("DETECTED_SERVICES", string.format([[
Found %d potential service directories:
%s
]], #service_dirs, table.concat(service_dirs, "\n")))
end

-- Check for API definitions
local api_files = workspace.glob("*.{yaml,yml,json}")
local api_definitions = {}
for _, file in ipairs(api_files or {}) do
  if file:match("api") or file:match("swagger") or file:match("openapi") then
    table.insert(api_definitions, file)
  end
end

if #api_definitions > 0 then
  prompt:section("API_DEFINITIONS", "Found API definition files:\n" .. table.concat(api_definitions, "\n"))
end

-- Check for containerization
local docker_files = workspace.glob("**/Dockerfile")
if docker_files and #docker_files > 1 then
  prompt:section("CONTAINERIZATION", string.format("Found %d Dockerfiles (multiple services)", #docker_files))
end

-- Check for message queue/event bus
local messaging_indicators = {
  "nats", "kafka", "rabbitmq", "redis", "sqs", "pubsub"
}

local messaging_found = false
for _, sample in ipairs(code_samples) do
  for _, indicator in ipairs(messaging_indicators) do
    if sample.content:lower():find(indicator) then
      messaging_found = true
      break
    end
  end
end

if messaging_found then
  prompt:section("MESSAGING", "Message queue/event bus detected (NATS, Kafka, RabbitMQ, etc.)")
end

-- Code samples
prompt:section("CODE_SAMPLES", "Analyzing " .. #code_samples .. " code files")

prompt:section("OUTPUT_FORMAT", [[
Return ONLY valid JSON in this format:

{
  "pattern_detected": true|false,
  "pattern_name": "microservices",
  "confidence": 0.0-1.0,
  "indicators_found": [
    {
      "indicator": "multiple_services",
      "evidence": "4 services detected: rust/, llm-server/, singularity/, centralcloud/",
      "weight": 0.9
    },
    {
      "indicator": "api_contracts",
      "evidence": "OpenAPI specs found in 3 services",
      "weight": 0.8
    },
    {
      "indicator": "independent_deployment",
      "evidence": "Each service has own Dockerfile",
      "weight": 0.85
    },
    {
      "indicator": "messaging",
      "evidence": "NATS used for inter-service communication",
      "weight": 0.75
    }
  ],
  "service_count": 4,
  "services": [
    {
      "name": "rust/code_engine",
      "language": "rust",
      "api_type": "gRPC",
      "deployment": "docker"
    },
    {
      "name": "llm-server",
      "language": "typescript",
      "api_type": "REST",
      "deployment": "docker"
    }
  ],
  "architecture_score": 0.92,
  "production_ready": true,
  "concerns": [
    "No service mesh detected",
    "Missing distributed tracing setup"
  ],
  "recommendations": [
    "Add service mesh (Istio, Linkerd) for better observability",
    "Implement distributed tracing (Jaeger, Zipkin)"
  ],
  "llm_reasoning": "Detailed explanation of why this is/isn't microservices"
}

Do NOT include markdown code fences.
Just raw JSON.
]])

return prompt
```

### Example 2: analyst-discover-pattern.lua (for LLM Team)

```lua
-- LLM Team Agent: Pattern Analyst
-- Deep pattern discovery and analysis
--
-- Agent: Pattern Analyst (Claude Opus)
-- Role: Discover patterns from code samples
-- Personality: Analytical, detail-oriented, thorough
--
-- Input:
--   pattern_type: "architecture"|"code_quality"|"framework"
--   code_samples: table
--
-- Output: Pattern analysis for team discussion

local Prompt = require("prompt")
local prompt = Prompt.new()

local pattern_type = context.pattern_type or "architecture"
local code_samples = context.code_samples or {}

prompt:section("TEAM_ROLE", [[
You are the PATTERN ANALYST on the Architecture LLM Team.

Your specialty: Deep code analysis and pattern discovery

Your personality:
- Analytical and detail-oriented
- Thorough and methodical
- Evidence-based reasoning

Your responsibilities:
1. Discover architecture, code quality, and framework patterns
2. Document pattern indicators and examples
3. Provide confidence scores based on evidence
4. Collaborate with other team members (Validator, Critic, Researcher)

Note: Your analysis will be reviewed by:
- Pattern Validator (checks technical correctness)
- Pattern Critic (finds weaknesses)
- Pattern Researcher (validates against external sources)
]])

prompt:section("TASK", string.format([[
Analyze this codebase and discover %s patterns.

Focus on:
1. Identifying clear, well-defined patterns
2. Providing concrete evidence (code examples)
3. Rating pattern quality and implementation
4. Suggesting improvements if needed

Be thorough - this is your specialty. Other team members rely on your analysis.
]], pattern_type))

-- Add code samples
for i, sample in ipairs(code_samples) do
  prompt:section(string.format("CODE_SAMPLE_%d", i), string.format([[
File: %s
Language: %s
Content:
```%s
%s
```
]], sample.path, sample.language, sample.language, sample.content))
end

prompt:section("OUTPUT_FORMAT", [[
Return ONLY valid JSON:

{
  "analyst_assessment": {
    "patterns_discovered": [
      {
        "name": "event_driven_microservices",
        "type": "architecture",
        "confidence": 0.92,
        "description": "Microservices communicating via NATS event bus",
        "indicators": [
          "4 independent services detected",
          "NATS pub/sub for async communication",
          "Each service has clear API boundaries"
        ],
        "code_examples": [
          {
            "file": "lib/nats_client.ex",
            "snippet": "NatsClient.publish(...)",
            "demonstrates": "Event publishing pattern"
          }
        ],
        "quality_score": 90,
        "production_ready": true,
        "benefits": [
          "Loose coupling between services",
          "Async communication reduces latency",
          "Easy to add new services"
        ],
        "concerns": [
          "No circuit breaker for NATS failures",
          "Missing retry logic"
        ]
      }
    ],
    "overall_score": 90,
    "analyst_confidence": 0.95,
    "reasoning": "Strong evidence for microservices pattern. Multiple services, clear boundaries, event-driven communication. Missing some production hardening (circuit breaker, retry logic)."
  },
  "team_notes": {
    "for_validator": "Please verify NATS configuration and API contracts",
    "for_critic": "Please review missing circuit breaker and retry logic concerns",
    "for_researcher": "Please validate event-driven microservices pattern against external sources"
  }
}
]])

return prompt
```

### Example 3: coordinator-build-consensus.lua

```lua
-- LLM Team Agent: Team Coordinator
-- Facilitates discussion and builds consensus
--
-- Agent: Team Coordinator (GPT-4o)
-- Role: Facilitate discussion, build consensus, make decisions
-- Personality: Diplomatic, balanced, decision-oriented
--
-- Input:
--   analyst_assessment: table
--   validator_assessment: table
--   critic_assessment: table
--   researcher_assessment: table
--
-- Output: Consensus decision

local Prompt = require("prompt")
local prompt = Prompt.new()

local analyst = context.analyst_assessment
local validator = context.validator_assessment
local critic = context.critic_assessment
local researcher = context.researcher_assessment

prompt:section("TEAM_ROLE", [[
You are the TEAM COORDINATOR for the Architecture LLM Team.

Your specialty: Facilitating discussion and building consensus

Your personality:
- Diplomatic and balanced
- Decision-oriented
- Focused on quality outcomes

Your responsibilities:
1. Review all team member assessments
2. Identify areas of agreement and disagreement
3. Facilitate discussion on disagreements
4. Calculate consensus score
5. Make final approval decision (approved/rejected/needs_refinement)

Decision criteria:
- Consensus score >= 85/100
- Agreement level: HIGH or VERY_HIGH (scores within 10 points)
- All major concerns addressed
]])

prompt:section("TEAM_ASSESSMENTS", string.format([[
Pattern Analyst (Claude Opus):
Score: %d/100
Confidence: %.2f
Reasoning: %s

Pattern Validator (GPT-4 Turbo):
Score: %d/100
Validation: %s

Pattern Critic (Gemini Pro):
Score: %d/100
Concerns: %s

Pattern Researcher (Claude Sonnet):
Evidence Score: %d/100
External Sources: %d found
]],
  analyst.overall_score,
  analyst.analyst_confidence,
  analyst.reasoning,
  validator.technical_score,
  validator.validation_summary,
  critic.critical_score,
  table.concat(critic.concerns or {}, ", "),
  researcher.evidence_score,
  #(researcher.sources or {})
))

prompt:section("TASK", [[
Review the team assessments and:

1. Calculate consensus score (average of all scores)
2. Determine agreement level:
   - VERY_HIGH: All scores within 5 points
   - HIGH: All scores within 10 points
   - MEDIUM: All scores within 15 points
   - LOW: Scores diverge by > 15 points

3. Identify disagreements (if any)
4. Suggest refinements to address concerns
5. Make final decision: approved|rejected|needs_refinement

Approval criteria:
- Consensus >= 85
- Agreement >= HIGH
- Major concerns addressed
]])

prompt:section("OUTPUT_FORMAT", [[
Return ONLY valid JSON:

{
  "consensus": {
    "average_score": 89,
    "score_range": 8,
    "agreement_level": "HIGH",
    "individual_scores": {
      "analyst": 92,
      "validator": 90,
      "critic": 84,
      "researcher": 88
    }
  },
  "disagreements": [
    {
      "topic": "Circuit breaker requirement",
      "analyst_view": "Should be recommended, not required",
      "critic_view": "Must be required for production",
      "coordinator_resolution": "Make circuit breaker required based on production-readiness concerns"
    }
  ],
  "refinements_needed": [
    "Add circuit breaker as required component",
    "Document retry logic best practices",
    "Include monitoring/observability requirements"
  ],
  "decision": {
    "status": "approved_with_refinements",
    "final_score": 91,
    "confidence": "very_high",
    "approved_for_knowledge_base": true,
    "reasoning": "Strong consensus (89/100), high agreement (8 point range). All team members agree pattern is valid. Critic's concerns about circuit breaker are valid and will be addressed in refinements."
  },
  "next_steps": [
    "Apply refinements to pattern definition",
    "Re-validate with Validator",
    "Store in knowledge base"
  ]
}
]])

return prompt
```

---

## 🎯 Implementation Plan

### Phase 1: Architecture Pattern Detection (Add to templates_data/)

```bash
templates_data/prompt_library/architecture/
├── discover-framework.lua           # ✅ Exists
├── detect-version.lua                # ✅ Exists
├── detect-microservices.lua          # 🆕 Add
├── detect-monolith.lua               # 🆕 Add
├── detect-layered-architecture.lua   # 🆕 Add
├── detect-event-driven.lua           # 🆕 Add
└── detect-hexagonal.lua              # 🆕 Add
```

### Phase 2: Code Quality Pattern Detection

```bash
templates_data/prompt_library/quality/
├── extract-patterns.lua              # ✅ Exists
├── detect-dry-violations.lua         # 🆕 Add
├── detect-solid-violations.lua       # 🆕 Add
├── detect-code-smells.lua            # 🆕 Add
└── detect-anti-patterns.lua          # 🆕 Add
```

### Phase 3: LLM Team Agent Templates

```bash
templates_data/prompt_library/architecture/llm_team/
├── analyst-discover-pattern.lua      # 🆕 Add
├── validator-validate-pattern.lua    # 🆕 Add
├── critic-critique-pattern.lua       # 🆕 Add
├── researcher-research-pattern.lua   # 🆕 Add
└── coordinator-build-consensus.lua   # 🆕 Add
```

### Phase 4: JSON Pattern Definitions (for CentralCloud DB)

```bash
templates_data/architecture_patterns/
├── microservices.json                # 🆕 Add
├── monolith.json                     # 🆕 Add
├── event-driven.json                 # 🆕 Add
├── layered-architecture.json         # 🆕 Add
├── hexagonal-architecture.json       # 🆕 Add
├── dry-pattern.json                  # 🆕 Add
├── solid-pattern.json                # 🆕 Add
└── PATTERN_SCHEMA.json               # 🆕 Add (schema definition)
```

---

## 📊 Benefits

### 1. Reuse Existing High-Quality Template System

**Already have:**
- JSON 2.3.0 validated schemas ✅
- Lua-based dynamic prompts ✅
- Workspace file access ✅
- Git integration ✅
- Template versioning ✅

**Just extend with:**
- Architecture pattern detection templates
- LLM team collaboration templates
- Pattern validation templates

### 2. Consistent Quality Standards

**All templates follow:**
- Structured JSON output
- Version tracking
- LLM-aware metadata
- Evidence-based analysis
- Confidence scoring

### 3. Easy CentralCloud Import

```elixir
# Import templates to CentralCloud knowledge base
moon run templates_data:sync-to-db

# Templates automatically available to:
# - Architecture LLM Team (5 agents)
# - Pattern detection services
# - All Singularity instances (via NATS)
```

---

## ✅ Summary

**We have:**
- ✅ High-quality template system (JSON 2.3.0 + Lua + Handlebars)
- ✅ Framework detection templates
- ✅ Design pattern extraction templates
- ✅ SPARC architecture workflows

**We need to add:**
- 🆕 Architecture pattern detection (microservices, monolith, etc.)
- 🆕 Code quality pattern detection (DRY, SOLID, etc.)
- 🆕 LLM team collaboration templates (5 agents)
- 🆕 Pattern JSON definitions (for CentralCloud DB)

**Total new templates:** ~20-25 templates
**Estimated effort:** 2-3 days
**Quality:** Following existing high standards (JSON 2.3.0, versioned, validated)

---

**Next:** Start creating the architecture pattern detection templates!
