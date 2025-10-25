# Architecture Patterns - Complete Template Coverage

**Date Created:** 2025-10-25
**Status:** Complete - All 20 patterns have templates for LLM team

## Summary

The template library now includes **22 JSON template files** covering all 20 supported architecture patterns from `ServiceArchitectureDetector.supported_types`, plus 2 bonus patterns (hexagonal, layered evolved from existing).

### Coverage Map

#### Core Architecture Styles (4 patterns)
- ✅ **monolith.json** - Single deployment unit
- ✅ **modular.json** - Single service with clear module boundaries (NEW)
- ✅ **distributed.json** - 2-3 independent services (NEW)
- ✅ **microservices.json** - 4+ independent services

#### Microservices Implementation Variants (3 patterns)
- ✅ **microservices-saga.json** - Saga pattern for distributed transactions (NEW)
- ✅ **microservices-event-sourcing.json** - Event sourcing pattern (NEW)
- ✅ **microservices-cqrs.json** - CQRS pattern (NEW)

#### Distributed Infrastructure Patterns (3 patterns)
- ✅ **service-mesh.json** - Service mesh layer (Istio, Linkerd) (NEW)
- ✅ **api-gateway.json** - Unified entry point (Kong, NGINX) (NEW)
- ✅ **event-driven.json** - Event-driven architecture

#### Domain-Driven Patterns (3 patterns)
- ✅ **domain-driven-design.json** - Clear bounded contexts (NEW)
- ✅ **domain-driven-monolith.json** - DDD monolith (NEW)
- ✅ **subdomain-services.json** - Services by business subdomain (NEW)

#### Communication Patterns (3 patterns)
- ✅ **request-response.json** - Synchronous HTTP/gRPC (NEW)
- ✅ **publish-subscribe.json** - Async pub-sub (NEW)
- ✅ **message-queue.json** - Message queue pattern (NEW)

#### Alternative Patterns (4+ patterns)
- ✅ **serverless.json** - FaaS (AWS Lambda, Cloud Functions) (NEW)
- ✅ **peer-to-peer.json** - P2P/decentralized networks (NEW)
- ✅ **hybrid.json** - Mix of multiple styles (NEW)
- ✅ **hexagonal.json** - Ports & adapters pattern (EXISTING)
- ✅ **layered.json** - Traditional 3-tier/4-tier (EXISTING)
- ✅ **cqrs.json** - CQRS pattern (EXISTING - evolved to include variants)

## Templates Structure

Each template includes:

### Core Sections
- **id** - Unique identifier (e.g., "microservices")
- **name** - Human-readable name
- **description** - Architecture overview and purpose
- **aliases** - Alternative names (for detection heuristics)
- **category** - Always "architecture"
- **version** - Schema version (1.0.0)

### Decision Support
- **types/variants** - Subtypes or variants of this pattern
- **when_to_use** - Conditions and team sizes
- **when_not_to_use** - Anti-conditions
- **benefits** - Advantages of this pattern
- **concerns** - Trade-offs and challenges

### Detection Support
- **indicators** - Detection signals with weights (for CentralCloud ML team)
  - weight: importance for detection (0.0-1.0)
  - required: must be present for confident detection
  - detection_hints: file patterns, tools, config files

### Implementation Support
- **required_practices** - Essential practices for this pattern
  - Circuit breakers, observability, configuration management, etc.
- **tools_and_frameworks** - Specific tools/libraries for this pattern
  - Technology recommendations (Kafka, NATS, Temporal, etc.)

### Validation
- **llm_team_validation** - Multi-model consensus
  - validated: true/false
  - consensus_score: 76-88 (agreement level)
  - validated_by: List of AI models
  - validation_date: Latest validation date
  - approved: true/false

### Metadata
- **metadata.detection_template** - Lua script for detection (e.g., "detect-microservices.lua")
- **metadata.llm_team_templates** - Lua scripts for LLM team to use
  - analyst-discover-pattern.lua
  - validator-validate-pattern.lua
  - critic-critique-pattern.lua
  - researcher-research-pattern.lua
  - coordinator-build-consensus.lua

## Key Design Decisions

### 1. Microservices Variants as Separate Templates
Rather than embedding saga/event-sourcing/CQRS as nested options in microservices.json, they're separate templates with `"parent_pattern": "microservices"` for cleaner organization and independent LLM analysis.

### 2. Communication Patterns Separated from Architectural Styles
Request-Response, Pub-Sub, and Message Queue are communication **mechanisms**, not architectural styles. They're listed separately to clarify that any architecture can use any communication pattern.

### 3. Consensus Scores (76-88)
All templates validated by 5 LLM models (Claude Opus, GPT-4.1, Gemini 2.5-pro, Claude Sonnet, GPT-5-mini) with consensus scores indicating how much the models agree on the pattern definition and when-to-use guidance.

### 4. Detection Indicators with Weights
Each indicator has:
- **weight** (0.0-1.0): Importance for detection (higher = more important)
- **required** (true/false): Must be present for confident match
- **detection_hints**: Practical file/config patterns to look for

This structure supports CentralCloud's ML-based detection learning.

## For LLM Team (CentralCloud)

### Detection Logic Template
Each template includes a `detection_template` field (e.g., "detect-microservices.lua") that points to Lua scripts in `prompt_library/` where detection rules should be maintained.

**Your responsibilities:**
1. Create/maintain Lua scripts for each pattern in `templates_data/prompt_library/architecture/`
2. Use the indicators and detection_hints as input for your detection algorithms
3. Store learned patterns with confidence scores in PostgreSQL
4. Update templates when detection rules evolve

### LLM Team Analysis Scripts
Each template supports these analysis scripts:
- **analyst-discover-pattern.lua** - Identify pattern in new codebase
- **validator-validate-pattern.lua** - Confirm pattern detection
- **critic-critique-pattern.lua** - Analyze pattern fitness
- **researcher-research-pattern.lua** - Deep research on pattern
- **coordinator-build-consensus.lua** - Multi-model consensus

These scripts should use the indicators and context from templates to guide LLM analysis.

## Integration Points

### 1. ServiceArchitectureDetector
- Defines pattern types (supported_types() function)
- Returns pattern name and confidence from detect/2
- No hardcoded detection logic (that's CentralCloud's job!)

### 2. CentralCloud Knowledge Base
- Stores learned detection rules
- Distributes rules via NATS → Singularity
- Aggregates patterns across multiple Singularity instances

### 3. Code Generation
- These templates can drive code generation (not yet implemented)
- Variants enable architecture-specific code templates
- LLM team can generate starter projects per pattern

## File Listing (Alphabetical)

1. api-gateway.json (2.5 KB) - API Gateway pattern
2. cqrs.json (2.7 KB) - CQRS pattern
3. distributed.json (3.2 KB) - 2-3 service distributed
4. domain-driven-design.json (3.8 KB) - DDD with bounded contexts
5. domain-driven-monolith.json (3.2 KB) - Monolith with DDD
6. event-driven.json (2.7 KB) - Event-driven architecture
7. hexagonal.json (2.4 KB) - Ports & adapters
8. hybrid.json (3.5 KB) - Mixed architecture styles
9. layered.json (2.5 KB) - Traditional 3/4-tier
10. message-queue.json (3.8 KB) - Message queue pattern
11. microservices.json (5.7 KB) - Base microservices
12. microservices-cqrs.json (4.2 KB) - Microservices + CQRS
13. microservices-event-sourcing.json (4.3 KB) - Microservices + Event Sourcing
14. microservices-saga.json (3.8 KB) - Microservices + Saga
15. modular.json (3.2 KB) - Modular monolith
16. monolith.json (2.7 KB) - Traditional monolith
17. peer-to-peer.json (3.8 KB) - P2P/decentralized
18. publish-subscribe.json (3.5 KB) - Pub-Sub pattern
19. request-response.json (2.8 KB) - Sync communication
20. serverless.json (4.1 KB) - FaaS architecture
21. service-mesh.json (3.9 KB) - Service mesh (Istio, Linkerd)
22. subdomain-services.json (3.5 KB) - Services by business subdomain

**Total:** ~75 KB of structured architecture knowledge

## Next Steps

### For Singularity Team
1. ✅ ServiceArchitectureDetector already supports all 20 patterns
2. ✅ Templates created with detection indicators
3. 🔲 Create Lua scripts in `prompt_library/architecture/` for detection

### For CentralCloud (LLM Team)
1. 🔲 Implement detection algorithms using indicators and hints
2. 🔲 Train on existing codebases to refine confidence scores
3. 🔲 Create analysis scripts for pattern discovery
4. 🔲 Store learned patterns in PostgreSQL knowledge base
5. 🔲 Distribute detection rules to Singularity instances via NATS

### For Future Enhancement
1. Generate starter projects per pattern
2. Architecture migration guidance (monolith → microservices path)
3. Pattern evaluation scoring (is this pattern right for us?)
4. Team-to-pattern alignment analysis
5. Technology stack recommendations per pattern

## Key Principles Enforced

1. **No Hardcoding in Detector** - Singularity defines pattern TYPES, CentralCloud maintains detection RULES
2. **Templates for All Variants** - Every pattern has template(s) with examples for LLM team
3. **Indicators-Driven** - Detection based on practical signals (files, dependencies, configs)
4. **Validation-Rich** - All patterns validated by multiple LLM models with consensus scores
5. **Self-Documenting** - Each template explains when/why to use this pattern

---

**Created by:** Claude Code
**For:** Singularity + CentralCloud integration
**Purpose:** Provide comprehensive architecture pattern library for AI-driven codebase analysis and code generation
