# Documentation Audit (October 5, 2025)

File | Action | Notes
---- | ------ | -----
QUICK_REFERENCE.md | Removed | Legacy navigation doc replaced by README + Pattern System
MICROSERVICE_DETECTION.md | Removed | Merged into updated PATTERN_SYSTEM.md
LLM_VIA_NATS.md | Reviewed | Architecture still current (Rust LayeredDetector + ai-server).
QUICKSTART.md | Reviewed | No changes required; already current.
DB_SERVICE_REMOVAL.md | Updated | Document now reflects consolidated migrations and removal status.
PATTERN_EXTRACTION_DEMO.md | Removed | Merged into updated PATTERN_SYSTEM.md
AGENTS.md | Updated | Rewritten to describe current hybrid agent architecture.
IMPLEMENTATION_SUMMARY.md | Removed | Historical SAFe summary no longer applicable
SAFE_LARGE_CHANGE_FLOW.md | Removed | Outdated SafeVision flow
DEPLOYMENT_OPTIONS.md | Reviewed | Still accurate; integrated vs separate deployments.
CLAUDE.md | Reviewed | Instructions remain valid for CLI + SDK.
README_NAVIGATION.md | Removed | Navigation coverage merged into README and Pattern System
PACKAGE_REGISTRY_AND_CODEBASE_SEARCH.md | Updated | Aligned with PackageRegistryKnowledge + hybrid search modules.
RENAME_PLAN.md | Removed | Renaming completed; doc obsolete
DATABASE_MIGRATIONS_GUIDE.md | Reviewed | Already described consolidated migrations.
CODE_GENERATION_FLOW.md | Reviewed | Flow still matches code.
INTEGRATION_GUIDE.md | Removed | Rust interop plan superseded by current architecture
VISION_UPDATE_PATTERNS.md | Removed | Superseded by SingularityVision guide
SAFE_6_FULL_COVERAGE.md | Removed | SafeVision docs consolidated
NAVIGATION_PLAN.md | Removed | Merged into updated Pattern System / Code navigation docs
PRODUCTION_CODE_EXAMPLE.md | Removed | Outdated example replaced by actual modules
E2E_TEST.md | Removed | Replaced by new testing guide
NIX_DEPLOYMENT.md | Reviewed | Remains accurate.
FLY_DEPLOYMENT.md | Removed | Deployment docs consolidated (see Quickstart / Nix Deployment)
DEPLOYMENT.md | Reviewed | Docker workflow still valid.
EMERGENCY_FALLBACK.md | Reviewed | CLI still supported.
README.md | Updated | Removed db_service references and refreshed doc index.
RENAME_COMPLETE.md | Removed | Renaming completed; historical note removed
DEPLOYMENT_GUIDE.md | Removed | Deployment instructions consolidated into Quickstart + Nix documentation
MIGRATION_CONSOLIDATION.md | Reviewed | No changes needed.
CREDENTIALS_ENCRYPTION.md | Reviewed | Workflow current.
lib/singularity/README.md | Reviewed | AIProvider interface still accurate.
SINGULARITY_VISION_GUIDE.md | Reviewed | Already using SingularityVision naming.
TOOL_KNOWLEDGE_SIMPLIFIED.md | Updated | Reflects consolidated tool schema.
RENAMING_COMPLETE.md | Removed | Renaming completed; historical note removed
PATTERN_SYSTEM.md | Updated | Rewritten to document current pattern architecture.
TEST_GUIDE.md | Updated | New instructions without db_service.
tools/deploy-credentials.md | Reviewed | Steps still valid.
CODING_STANDARDS.md | Updated | Adjusted messaging/persistence section.
NATS_SUBJECTS.md | Updated | Consumer names now point to PackageRegistryKnowledge.
ANALYSIS_SCHEMA.md | Updated | Describes Singularity.Analysis structs and Ecto schema.
PATTERN_SYSTEM_SUMMARY.md | Removed | Merged into updated PATTERN_SYSTEM.md
KEYWORD_PATTERN_MATCHING.md | Removed | Merged into updated PATTERN_SYSTEM.md
JSONB_MIGRATION_PLAN.md | Removed | Covered by consolidated migrations docs
rust/analysis_suite/PARSER_COVERAGE_INTEGRATION.md | Removed | Deprecated analysis-suite planning note
rust/analysis_suite/TAVILY_INTEGRATION.md | Removed | Deprecated analysis-suite planning note
rust/analysis_suite/TESTING_STRATEGY.md | Removed | Deprecated analysis-suite planning note
rust/analysis_suite/COMPLETE_ANALYSIS_ARCHITECTURE.md | Removed | Deprecated analysis-suite planning note
rust/analysis_suite/CLEANUP_SUMMARY.md | Removed | Deprecated analysis-suite planning note
rust/analysis_suite/CODEBASE_CAPABILITIES.md | Removed | Deprecated analysis-suite planning note
rust/analysis_suite/UNIVERSAL_PARSER_INTEGRATION.md | Removed | Deprecated analysis-suite planning note
rust/analysis_suite/PARSER_CAPABILITIES_ANALYSIS.md | Removed | Deprecated analysis-suite planning note
rust/prompt_engine/SMART_STORAGE_ARCHITECTURE.md | Reviewed | No changes required.
rust/analysis_suite/MISSING_ITEMS.md | Removed | Deprecated analysis-suite planning note
rust/analysis_suite/GITHUB_INTEGRATION.md | Removed | Deprecated analysis-suite planning note
rust/prompt_engine/REMAINING_ERRORS.md | Reviewed | No changes required.
rust/analysis_suite/ENHANCED_SOURCE_EXTRACTION.md | Removed | Deprecated analysis-suite planning note
rust/analysis_suite/IDEAS.md | Removed | Deprecated analysis-suite planning note
rust/analysis_suite/RUST_FULLTEXT_SEARCH.md | Removed | Deprecated analysis-suite planning note
rust/analysis_suite/SEARCH_COMPARISON.md | Removed | Deprecated analysis-suite planning note
rust/analysis_suite/BUILD_STATUS.md | Removed | Deprecated analysis-suite planning note
rust/analysis_suite/REORGANIZATION.md | Removed | Deprecated analysis-suite planning note
NATS_INTEGRATION_MAP.md | Removed | Replaced by docs/messaging/NATS_SUBJECTS.md
SETUP.md | Updated | Replaced SafeVision references with SingularityVision.
rust/prompt_engine/CURRENT_STATUS.md | Removed | Outdated prompt-engine status note
rust/prompt_engine/CORRECT_ARCHITECTURE.md | Removed | Outdated prompt-engine status note
rust/BUILD_STATUS.md | Removed | Outdated rust build status note
PATTERN_EXTRACTOR_README.md | Removed | Merged into updated PATTERN_SYSTEM.md
SCALE_ANALYSIS.md | Removed | Outdated scaling plan
IMPLEMENTED_TODAY.md | Removed | Daily log removed to reduce noise
CODEBASE_PLAN.md | Removed | Legacy planning document removed
rust/tool_doc_index/MIGRATION_STATUS.md | Removed | Legacy tool_doc_index design note removed
rust/tool_doc_index/UNIVERSAL_FACT_SCHEMA.md | Removed | Legacy tool_doc_index design note removed
rust/tool_doc_index/COLLECTORS_ARCHITECTURE.md | Removed | Legacy tool_doc_index design note removed
rust/tool_doc_index/FRAMEWORK_SCHEMA.md | Removed | Legacy tool_doc_index design note removed
rust/tool_doc_index/STORAGE_ARCHITECTURE.md | Removed | Legacy tool_doc_index design note removed
ai-server/templates/README.md | Reviewed | No changes required.
ai-server/README.md | Reviewed | No changes required.
ai-server/ARCHITECTURE.md | Reviewed | No changes required.
singularity_app/README.md | Reviewed | No changes required.
singularity_app/priv/code_quality_templates/README.md | Reviewed | No changes required.
rust/tool_doc_index/templates/TEMPLATE_INVENTORY.md | Reviewed | No changes required.
rust/tool_doc_index/templates/PROMPT_BITS_INTEGRATION.md | Reviewed | No changes required.
rust/tool_doc_index/templates/README.md | Reviewed | No changes required.
rust/tool_doc_index/templates/bits/security/rate-limiting.md | Reviewed | No changes required.
rust/tool_doc_index/templates/bits/security/oauth2.md | Reviewed | No changes required.
rust/tool_doc_index/templates/bits/security/input-validation.md | Reviewed | No changes required.
rust/tool_doc_index/templates/bits/performance/async-optimization.md | Reviewed | No changes required.
rust/tool_doc_index/templates/bits/performance/caching.md | Reviewed | No changes required.
ai-server/vendor/codex-js-sdk/README.md | Reviewed | No changes required.
rust/tool_doc_index/templates/bits/testing/pytest-async.md | Reviewed | No changes required.
rust/tool_doc_index/templates/bits/architecture/rest-api.md | Reviewed | No changes required.
