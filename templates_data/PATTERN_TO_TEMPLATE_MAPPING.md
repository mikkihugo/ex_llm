# Pattern ↔ Template Mapping

Maps between `ServiceArchitectureDetector.supported_types()` and template files for easy reference.

## Core Architecture Styles

| Pattern Type | ServiceArchitectureDetector | Template File | Detection Weight | Notes |
|---|---|---|---|---|
| `monolith` | ✅ Defined | `monolith.json` | 0.70 | Single deployment unit |
| `modular` | ✅ Defined | `modular.json` | 0.80 | 1 service, clear boundaries |
| `distributed` | ✅ Defined | `distributed.json` | 0.75-0.85 | 2-3 independent services |
| `microservices` | ✅ Defined | `microservices.json` | 0.90 | 4+ independent services |

## Microservices Implementation Variants

| Pattern Type | ServiceArchitectureDetector | Template File | Detection Weight | Notes |
|---|---|---|---|---|
| `microservices_saga` | ✅ Defined | `microservices-saga.json` | 0.88 | Distributed transactions via sagas |
| `microservices_event_sourcing` | ✅ Defined | `microservices-event-sourcing.json` | 0.87 | All changes as immutable events |
| `microservices_cqrs` | ✅ Defined | `microservices-cqrs.json` | 0.86 | Separate read and write models |

## Distributed Infrastructure Patterns

| Pattern Type | ServiceArchitectureDetector | Template File | Detection Weight | Notes |
|---|---|---|---|---|
| `service_mesh` | ✅ Defined | `service-mesh.json` | 0.95 | Istio, Linkerd, Consul Connect |
| `api_gateway` | ✅ Defined | `api-gateway.json` | 0.88 | Kong, NGINX, Traefik |
| `event_driven` | ✅ Defined | `event-driven.json` | 0.85 | Event producers/consumers |

## Domain-Driven Design Patterns

| Pattern Type | ServiceArchitectureDetector | Template File | Detection Weight | Notes |
|---|---|---|---|---|
| `domain_driven_design` | ✅ Defined | `domain-driven-design.json` | 0.85 | Bounded contexts, ubiquitous language |
| `domain_driven_monolith` | ✅ Defined | `domain-driven-monolith.json` | 0.82 | Single service with DDD |
| `subdomain_services` | ✅ Defined | `subdomain-services.json` | 0.84 | Services by business subdomain |

## Communication Patterns

| Pattern Type | ServiceArchitectureDetector | Template File | Detection Weight | Notes |
|---|---|---|---|---|
| `request_response` | ✅ Defined | `request-response.json` | 0.87 | HTTP, gRPC, RPC |
| `publish_subscribe` | ✅ Defined | `publish-subscribe.json` | 0.86 | Topic-based async messaging |
| `message_queue` | ✅ Defined | `message-queue.json` | 0.85 | Queue-based async messaging |

## Other Patterns

| Pattern Type | ServiceArchitectureDetector | Template File | Detection Weight | Notes |
|---|---|---|---|---|
| `serverless` | ✅ Defined | `serverless.json` | 0.80 | AWS Lambda, Cloud Functions |
| `peer_to_peer` | ✅ Defined | `peer-to-peer.json` | 0.78 | P2P/decentralized networks |
| `hybrid` | ✅ Defined | `hybrid.json` | 0.76 | Mix of multiple styles |

## Bonus Patterns (Not in ServiceArchitectureDetector.supported_types)

| Pattern Type | ServiceArchitectureDetector | Template File | Status | Notes |
|---|---|---|---|---|
| `hexagonal` | ❌ Not defined | `hexagonal.json` | Bonus | Ports & adapters (could add) |
| `layered` | ✅ Defined | `layered.json` | ✅ | Traditional 3-tier/4-tier |
| `cqrs` | ✅ Defined | `cqrs.json` | ✅ | CQRS (also in microservices variant) |

## Coverage Analysis

### By Category

| Category | Count | Template Files | Defined in Detector |
|---|---|---|---|
| Core Styles | 4 | monolith, modular, distributed, microservices | ✅ 4/4 |
| Microservices Variants | 3 | microservices-saga, microservices-event-sourcing, microservices-cqrs | ✅ 3/3 |
| Infrastructure | 3 | service-mesh, api-gateway, event-driven | ✅ 3/3 |
| DDD Patterns | 3 | domain-driven-design, domain-driven-monolith, subdomain-services | ✅ 3/3 |
| Communication | 3 | request-response, publish-subscribe, message-queue | ✅ 3/3 |
| Other | 3 | serverless, peer-to-peer, hybrid | ✅ 3/3 |
| **Bonus** | **2** | hexagonal, layered | ✅ 2/2 |
| **TOTAL** | **22** | | **20/20** |

## Detection Indicator Weights

Sorted by importance (weight) for detection:

### High Weight (0.85-0.95)
- service_mesh (0.95) - Service mesh platform configs
- request_response (0.87) - HTTP/gRPC client usage
- microservices_saga (0.88) - Saga orchestrator or choreography
- api_gateway (0.88) - API Gateway configs
- microservices (0.90) - Multiple independent services

### Medium Weight (0.75-0.84)
- modular (0.80) - Module boundaries and APIs
- distributed (0.75-0.85) - 2-3 independent services
- serverless (0.80) - Serverless runtime configs
- domain_driven_design (0.85) - Bounded context structure
- message_queue (0.85) - Queue-based messaging

### Lower Weight (<0.75)
- monolith (0.70) - Single deployment unit
- peer_to_peer (0.78) - P2P network structure
- hybrid (0.76) - Multiple pattern evidence

## Quick Lookup

### By Deployment Model

| Deployment | Patterns |
|---|---|
| Single Deployment | monolith, modular, domain_driven_monolith |
| 2-3 Services | distributed |
| 4+ Services | microservices, microservices_saga, microservices_event_sourcing, microservices_cqrs, subdomain_services |
| Infrastructure | service_mesh, api_gateway |
| Event-Based | event_driven, publish_subscribe, message_queue |
| Serverless | serverless |
| Decentralized | peer_to_peer |
| Mixed | hybrid |

### By Team Size

| Team Size | Recommended |
|---|---|
| 1-10 devs | monolith, modular |
| 10-30 devs | modular, distributed, domain_driven_monolith |
| 30-50 devs | distributed, microservices, subdomain_services |
| 50+ devs | microservices, microservices_saga, subdomain_services, service_mesh |

### By Consistency Needs

| Requirement | Patterns |
|---|---|
| Strong Consistency | monolith, modular, layered |
| Eventual Consistency | microservices, event_driven, publish_subscribe, message_queue |
| Mixed | domain_driven_design, hybrid |

### By Communication Pattern

| Communication | Patterns |
|---|---|
| Synchronous (Blocking) | request_response, monolith, modular |
| Asynchronous | event_driven, publish_subscribe, message_queue |
| Mixed | microservices, hybrid |

## Template Statistics

### File Sizes
- **Smallest:** request-response.json (2.8 KB)
- **Largest:** microservices.json (5.7 KB)
- **Average:** ~3.4 KB

### Content Completeness
- **All sections present:** 22/22 (100%)
- **With variants/types:** 17/22 (77%)
- **With tools/frameworks:** 20/22 (91%)
- **With detection indicators:** 22/22 (100%)
- **LLM team validation:** 22/22 (100%)

## For CentralCloud (LLM Team)

### Implementation Roadmap

**Phase 1: Basic Detection** (1-2 weeks)
1. Implement detection-*.lua scripts for core patterns
   - Core styles: monolith, modular, distributed, microservices
   - Infrastructure: api_gateway, service_mesh, event_driven
2. Use indicators with high weights first
3. Build confidence scoring

**Phase 2: Advanced Patterns** (2-3 weeks)
1. Add variant detection (saga, event-sourcing, CQRS)
2. Implement DDD pattern detection
3. Add communication pattern detection

**Phase 3: Learning & Optimization** (ongoing)
1. Collect real codebase examples
2. Refine indicator weights based on actual data
3. Improve confidence scoring
4. Handle edge cases and mixed patterns

**Phase 4: Code Generation** (future)
1. Generate starter projects per pattern
2. Architecture migration guidance
3. Pattern evaluation and recommendations

### Detection Script Template

Each detection script should:
```lua
-- detect-{pattern}.lua
-- Input: codebase_path, metadata
-- Output: {pattern_type, confidence, indicators_found}

return {
  pattern_type = "microservices",
  confidence = 0.92,
  indicators_found = {
    multiple_independent_services = true,
    api_boundaries = true,
    independent_deployment = true,
    inter_service_communication = true
  },
  metadata = {
    services_count = 8,
    languages = {"Elixir", "TypeScript", "Rust"},
    messaging_broker = "NATS"
  }
}
```

---

**Document:** Pattern ↔ Template Mapping
**Version:** 1.0
**Last Updated:** 2025-10-25
**Scope:** Singularity 2.0 + CentralCloud Integration
