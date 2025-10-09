# Template Merge Analysis Report

Generated: Thu Oct  9 18:09:13 CEST 2025

## 1. IDENTICAL Files (Skip - Already in templates_data/)

These files are byte-for-byte identical and should NOT be copied:

- **workflows/sparc/1-specification.json**
  - Exists at: `workflows/sparc/1-specification.json`

- **workflows/sparc/2-pseudocode.json**
  - Exists at: `workflows/sparc/2-pseudocode.json`


**Total Identical:** 2

## 2. DIFFERENT Files (Manual Review Required)

These files exist in both locations but have different content:

- **elixir-nats-consumer.json**
  - Exists at: `code_generation/patterns/messaging/elixir-nats-consumer.json`
  - Source size: 6307 bytes
  - Target size: 6619 bytes
  - **Action:** Manual review needed to determine which version to keep

- **schema.json**
  - Exists at: `schema.json`
  - Source size: 4900 bytes
  - Target size: 6192 bytes
  - **Action:** Manual review needed to determine which version to keep

- **workflows/sparc/3-architecture.json**
  - Exists at: `workflows/sparc/3-architecture.json`
  - Source size: 2117 bytes
  - Target size: 653 bytes
  - **Action:** Manual review needed to determine which version to keep


**Total Different:** 3

## 3. UNIQUE Files (Need to Copy)

These files are only in rust/package/templates/ and should be copied:

### Security Templates

- **security/falco.json**
  - Size: 321 bytes
  - Target: `templates_data/code_generation/patterns/security/falco.json`

- **security/opa.json**
  - Size: 331 bytes
  - Target: `templates_data/code_generation/patterns/security/opa.json`


### Messaging Templates

- **messaging/kafka.json**
  - Size: 383 bytes
  - Target: `templates_data/code_generation/patterns/messaging/kafka.json`

- **messaging/nats.json**
  - Size: 364 bytes
  - Target: `templates_data/code_generation/patterns/messaging/nats.json`

- **messaging/rabbitmq.json**
  - Size: 413 bytes
  - Target: `templates_data/code_generation/patterns/messaging/rabbitmq.json`

- **messaging/redis.json**
  - Size: 384 bytes
  - Target: `templates_data/code_generation/patterns/messaging/redis.json`


### Language Templates (Single)

- **language/elixir.json**
  - Size: 2359 bytes
  - Target: `templates_data/code_generation/patterns/languages/elixir.json`

- **language/go.json**
  - Size: 1351 bytes
  - Target: `templates_data/code_generation/patterns/languages/go.json`

- **language/javascript.json**
  - Size: 1783 bytes
  - Target: `templates_data/code_generation/patterns/languages/javascript.json`

- **language/python.json**
  - Size: 1660 bytes
  - Target: `templates_data/code_generation/patterns/languages/python.json`

- **language/rust.json**
  - Size: 5144 bytes
  - Target: `templates_data/code_generation/patterns/languages/rust.json`

- **language/typescript.json**
  - Size: 1364 bytes
  - Target: `templates_data/code_generation/patterns/languages/typescript.json`


### Root Level Templates

- **UNIFIED_SCHEMA.json**
  - Size: 8031 bytes
  - Target: `templates_data/code_generation/patterns/UNIFIED_SCHEMA.json`

- **gleam-nats-consumer.json**
  - Size: 4836 bytes
  - Target: `templates_data/code_generation/patterns/gleam-nats-consumer.json`

- **python-django.json**
  - Size: 5078 bytes
  - Target: `templates_data/code_generation/patterns/python-django.json`

- **python-fastapi.json**
  - Size: 10929 bytes
  - Target: `templates_data/code_generation/patterns/python-fastapi.json`

- **rust-api-endpoint.json**
  - Size: 7390 bytes
  - Target: `templates_data/code_generation/patterns/rust-api-endpoint.json`

- **rust-microservice.json**
  - Size: 6298 bytes
  - Target: `templates_data/code_generation/patterns/rust-microservice.json`

- **rust-nats-consumer.json**
  - Size: 7673 bytes
  - Target: `templates_data/code_generation/patterns/rust-nats-consumer.json`

- **sparc-implementation.json**
  - Size: 2100 bytes
  - Target: `templates_data/code_generation/patterns/sparc-implementation.json`

- **typescript-api-endpoint.json**
  - Size: 11394 bytes
  - Target: `templates_data/code_generation/patterns/typescript-api-endpoint.json`

- **typescript-microservice.json**
  - Size: 9490 bytes
  - Target: `templates_data/code_generation/patterns/typescript-microservice.json`


### Cloud Templates

- **cloud/aws.json**
  - Size: 403 bytes
  - Target: `templates_data/code_generation/patterns/cloud/aws.json`

- **cloud/azure.json**
  - Size: 430 bytes
  - Target: `templates_data/code_generation/patterns/cloud/azure.json`

- **cloud/gcp.json**
  - Size: 446 bytes
  - Target: `templates_data/code_generation/patterns/cloud/gcp.json`


### AI Framework Templates

- **ai/crewai.json**
  - Size: 310 bytes
  - Target: `templates_data/code_generation/patterns/ai/crewai.json`

- **ai/langchain.json**
  - Size: 430 bytes
  - Target: `templates_data/code_generation/patterns/ai/langchain.json`

- **ai/mcp.json**
  - Size: 408 bytes
  - Target: `templates_data/code_generation/patterns/ai/mcp.json`


### SPARC Workflows

- **workflows/sparc/0-research.json**
  - Size: 572 bytes
  - Target: `templates_data/workflows/sparc/0-research.json`

- **workflows/sparc/4-architecture.json**
  - Size: 653 bytes
  - Target: `templates_data/workflows/sparc/4-architecture.json`

- **workflows/sparc/5-security.json**
  - Size: 757 bytes
  - Target: `templates_data/workflows/sparc/5-security.json`

- **workflows/sparc/6-performance.json**
  - Size: 707 bytes
  - Target: `templates_data/workflows/sparc/6-performance.json`

- **workflows/sparc/7-refinement.json**
  - Size: 2026 bytes
  - Target: `templates_data/workflows/sparc/7-refinement.json`

- **workflows/sparc/8-implementation.json**
  - Size: 678 bytes
  - Target: `templates_data/workflows/sparc/8-implementation.json`


### System Prompts

- **system/beast-mode-prompt.json**
  - Size: 2677 bytes
  - Target: `templates_data/prompt_library/beast-mode-prompt.json`

- **system/cli-llm-system-prompt.json**
  - Size: 2518 bytes
  - Target: `templates_data/prompt_library/cli-llm-system-prompt.json`

- **system/initialize-prompt.json**
  - Size: 1931 bytes
  - Target: `templates_data/prompt_library/initialize-prompt.json`

- **system/plan-mode-prompt.json**
  - Size: 2435 bytes
  - Target: `templates_data/prompt_library/plan-mode-prompt.json`

- **system/summarize-prompt.json**
  - Size: 1767 bytes
  - Target: `templates_data/prompt_library/summarize-prompt.json`

- **system/system-prompt.json**
  - Size: 3695 bytes
  - Target: `templates_data/prompt_library/system-prompt.json`

- **system/title-prompt.json**
  - Size: 1699 bytes
  - Target: `templates_data/prompt_library/title-prompt.json`


### Monitoring Templates

- **monitoring/grafana.json**
  - Size: 335 bytes
  - Target: `templates_data/code_generation/patterns/monitoring/grafana.json`

- **monitoring/jaeger.json**
  - Size: 414 bytes
  - Target: `templates_data/code_generation/patterns/monitoring/jaeger.json`

- **monitoring/opentelemetry.json**
  - Size: 447 bytes
  - Target: `templates_data/code_generation/patterns/monitoring/opentelemetry.json`

- **monitoring/prometheus.json**
  - Size: 431 bytes
  - Target: `templates_data/code_generation/patterns/monitoring/prometheus.json`


### Language Templates (Structured)

- **languages/python/_base.json**
  - Size: 989 bytes
  - Target: `templates_data/code_generation/patterns/languages/python/_base.json`

- **languages/python/fastapi/crud.json**
  - Size: 1643 bytes
  - Target: `templates_data/code_generation/patterns/languages/python/fastapi/crud.json`

- **languages/rust/_base.json**
  - Size: 1264 bytes
  - Target: `templates_data/code_generation/patterns/languages/rust/_base.json`

- **languages/rust/microservice.json**
  - Size: 1592 bytes
  - Target: `templates_data/code_generation/patterns/languages/rust/microservice.json`

- **languages/typescript/_base.json**
  - Size: 1096 bytes
  - Target: `templates_data/code_generation/patterns/languages/typescript/_base.json`



**Total Unique:** 50

## Summary

- **Identical files (skip):** 2
- **Different files (manual review):** 3
- **Unique files (copy):** 50
- **Total files analyzed:** 55

