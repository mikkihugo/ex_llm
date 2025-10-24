# Validator Consolidation Analysis Report

## Overview

The Singularity codebase contains **9 distinct validator modules** scattered across different domains, totaling **1,939 lines of code**. Most validators operate independently without a unified interface, though a `ValidatorType` behavior contract was recently started but remains underutilized.

## Comprehensive Validator Inventory

### 1. **Code Quality Validators**

#### 1.1 Template Validator (Quality Standards)
- **File**: `/singularity/lib/singularity/storage/code/quality/template_validator.ex`
- **Lines**: 332
- **Purpose**: Validates generated code against quality templates using parser metrics
- **Key Functions**:
  - `validate/4` - Full validation returning compliance status, score, violations
  - `validate?/4` - Boolean quick check (true/false only)
- **Validation Checks**:
  - Documentation (@moduledoc, @doc requirements)
  - Type specifications (@spec requirements)
  - Error handling patterns ({:ok, :error} or Result types)
  - Testing presence (doctests)
  - Code complexity (cyclomatic complexity < 10)
  - Observability (telemetry, Logger usage)
- **Return Type**: `{:ok, %{compliant: bool, score: float, violations: [String.t()], metrics: map, requirements_met: [String.t()], requirements_failed: [String.t()]}}`
- **Integration Points**:
  - Used by: `rag_code_generator.ex`, `code_generator.ex`, `rag.setup.ex`
  - Uses: `ParserEngine.parse_file/1`, `ArtifactStore.get/2`
  - Database: `code_files` table
- **Status**: ✅ Production-ready, actively used

#### 1.2 Code Validator (Hot Reload)
- **File**: `/singularity/lib/singularity/hot_reload/code_validator.ex`
- **Lines**: 78
- **Purpose**: Basic code validation for hot reload system
- **Key Functions**:
  - `validate/1` - Checks code size, emptiness, function definitions
  - `hot_reload/1` - Stub for actual hot reload (returns timestamp)
- **Validation Checks**:
  - Code not empty (String.length > 0)
  - Size within limits (max 1MB)
  - Contains at least one function definition
- **Return Type**: `{:ok, String.t()} | {:error, ValidationError}`
- **Error Types**: Custom `CodeValidator.ValidationError` exception
- **Status**: ⚠️ Simple, isolated use case (Gleam migration)

#### 1.3 Template Structure Validator (Templates)
- **File**: `/singularity/lib/singularity/templates/validator.ex`
- **Lines**: 186
- **Purpose**: Validates template JSON schema and composition references
- **Key Functions**:
  - `validate/1` - Validate single template map
  - `validate_file/1` - Load and validate from disk
  - `validate_directory/1` - Batch validation across directory
- **Validation Checks**:
  - Required fields: ["id", "category", "metadata", "content"]
  - Valid categories: ["base", "bit", "code_generation", "code_snippet", "framework", "prompt", "quality_standard", "workflow"]
  - Metadata completeness: ["name", "version", "description"]
  - Content type validation (code, snippets, prompt)
  - Composition references (extends, compose bits exist)
  - Quality standard references
- **Return Type**: `{:ok, template} | {:error, [error_tuples]}`
- **Status**: ✅ Production-ready

### 2. **Metadata & Documentation Validators**

#### 2.1 AI Metadata Validator
- **File**: `/singularity/lib/singularity/analysis/metadata_validator.ex`
- **Lines**: 553
- **Purpose**: Validates v2.2.0 AI documentation completeness for code ingestion
- **Key Functions**:
  - `validate_file/2` - Validate single file's metadata
  - `validate_codebase/1` - Batch validate all files in codebase
  - `fix_incomplete_metadata/1` - Auto-generate missing sections via LLM
  - `mark_for_review/2` - Flag for manual review
  - `mark_as_legacy/1` - Skip v2.2.0 validation
- **Validation Levels**:
  - `:complete` (score = 1.0) - All v2.2.0 requirements met
  - `:partial` (score 0.5-0.99) - Some AI metadata present
  - `:legacy` (score < 0.5) - Has docs but not v2.2.0 structure
  - `:missing` (score = 0.0) - No @moduledoc
- **Checks For**:
  - Human content (Quick Start, Examples, API list)
  - Separator (`---` + "AI Navigation Metadata" heading)
  - Module Identity (JSON block)
  - Architecture Diagram (Mermaid)
  - Call Graph (YAML)
  - Anti-Patterns section
  - Search Keywords
- **Return Type**: `%{level: atom, score: float, has: map, missing: [atom], recommendations: [String.t()]}`
- **Integration Points**:
  - Called during: `StartupCodeIngestion.persist_module_to_db/2`, code file changes
  - Task: `mix metadata.validate`
  - Uses: `LLM.Service.call/3`, template HBS generation
  - Database: `code_files.metadata` JSONB field
- **Status**: ✅ Production-ready with AI-powered auto-fix

### 3. **Security & Access Validators**

#### 3.1 Security Policy Validator
- **File**: `/singularity/lib/singularity/tools/security_policy.ex`
- **Lines**: 339
- **Purpose**: Validates tool access and enforces security rules
- **Key Functions**:
  - `validate_code_access/1` - File access validation (path, codebase, rate limit)
  - `validate_code_search/1` - Search request validation (query length, result limits)
  - `validate_symbol_operations/*` - Symbol find/refs/list operations
  - `validate_deps_operations/*` - Dependency graph operations
- **Validation Rules**:
  - **File Access**: Blocks sensitive files (.env, *.key, credentials.json), max 10MB
  - **Search**: Max 1000 char query, 100 result limit, codebase isolation
  - **Symbols**: Max 255 char names, 50 symbols per query
  - **Dependencies**: Max 10,000 graph nodes, depth <= 10
  - **Rate Limiting**: 100 requests/minute per codebase
- **Deny Patterns**: `.env`, `credentials.json`, `.key`, `.pem`, password/secret/api_key patterns (regex)
- **Return Type**: `:ok | {:error, String.t()}`
- **Integration Points**:
  - Called from: Tool execution framework
  - MCP Integration: Tool access control
- **Status**: ✅ Production-ready, security-critical

#### 3.2 Tool References Validator
- **File**: `/singularity/lib/singularity/tools/validation.ex`
- **Lines**: 154
- **Purpose**: Validates tool references in role-based system
- **Key Functions**:
  - `validate_all_tool_references/0` - Check all role→tool mappings
  - `get_tool_usage_summary/0` - Tool usage statistics
  - `check_naming_consistency/0` - Naming pattern validation
  - `generate_validation_report/0` - Comprehensive report
- **Validation Checks**:
  - Tool names exist (against actual implementation)
  - Role-tool associations valid
  - Naming convention consistency
- **Return Type**: Maps with validation results and usage stats
- **Status**: ✅ Operational, used for consistency checks

### 4. **Type System & Behavior Contracts**

#### 4.1 ValidatorType Behavior (Consolidation Foundation)
- **File**: `/singularity/lib/singularity/validation/validator_type.ex`
- **Lines**: 52
- **Purpose**: Define unified validator behavior contract
- **Callbacks**:
  ```elixir
  @callback validator_type() :: atom()
  @callback description() :: String.t()
  @callback capabilities() :: [String.t()]
  @callback validate(input :: term(), opts :: Keyword.t()) :: :ok | {:error, [String.t()]}
  @callback schema() :: map()
  ```
- **Config-Driven Management**:
  - `load_enabled_validators/0` - Load enabled validators from config
  - `enabled?/1` - Check if validator enabled
  - `get_validator_module/1` - Get module for type
  - `get_description/1` - Get validator description
- **Configuration** (in `config/config.exs`):
  ```elixir
  config :singularity, :validator_types,
    template: %{
      module: Singularity.Validation.Validators.TemplateValidator,
      enabled: false,
      description: "Validate template structure and content"
    }
  ```
- **Status**: ⚠️ Framework exists but **only 1 validator implements it** (TemplateValidator)

#### 4.2 Template Validator Implementation
- **File**: `/singularity/lib/singularity/validation/validators/template_validator.ex`
- **Lines**: 71
- **Purpose**: Implements ValidatorType for template validation
- **Implementation**:
  ```elixir
  @behaviour Singularity.Validation.ValidatorType
  
  def validator_type, do: :template
  def description, do: "Validate template structure and content"
  def capabilities, do: ["schema_validation", "required_fields", "content_validation"]
  def schema, do: %{ "type" => "object", "required" => ["name", "content"], ... }
  def validate(input, _opts \\ []) when is_map(input)
  ```
- **Status**: ✅ Properly implemented but isolated

### 5. **Pattern & Architecture Validators**

#### 5.1 Pattern Validator Subscriber (CentralCloud)
- **File**: `/centralcloud/lib/centralcloud/nats/pattern_validator_subscriber.ex`
- **Lines**: 174
- **Purpose**: NATS subscriber for pattern validation from Singularity instances
- **Messaging Protocol**:
  - Subject: `patterns.validate.request`
  - Response: `patterns.validate.response.<request_id>`
  - Uses LLMTeamOrchestrator for consensus-based validation
- **Request Format**: `{codebase_id, code_samples, pattern_type, request_id}`
- **Response Format**: `{status: success|error, consensus: {...}, error: "...", timestamp, request_id}`
- **Status**: ⚠️ Placeholder implementation (NATS client not fully integrated)

## Integration Map

### Call Graph: Which validators are used where?

```
CodeGenerator
  ├── TemplateValidator.validate/4          (quality check after generation)
  └── ArtifactStore.get("quality_template")

RAGCodeGenerator
  ├── TemplateValidator.validate/4
  └── Knowledge.ArtifactStore

StartupCodeIngestion (on-startup bootstrap)
  ├── MetadataValidator.validate_codebase/1  (validate all ingested code)
  ├── MetadataValidator.validate_file/2      (during file persistence)
  └── MetadataValidator.fix_incomplete_metadata/1

Tools / MCP Integration
  ├── SecurityPolicy.validate_code_access/1
  ├── SecurityPolicy.validate_code_search/1
  └── SecurityPolicy.validate_symbol_operations/1

Templates.Validator
  ├── Used by: JSON import/validation
  └── Integration: mix tasks

CodeQualityEnforcer
  ├── Checks: No duplication
  ├── Template: quality_standards/elixir/production.json
  └── Uses: CodeStore + RAG

Config-Driven System
  ├── :validator_types (config/config.exs)
  ├── ValidatorType.load_enabled_validators/0
  └── Only :template validator enabled (disabled: false)
```

## Current State Analysis

### Strengths
- ✅ **Specialized validators**: Each domain has well-designed validator (quality, metadata, security)
- ✅ **Type safety**: Custom return types with detailed violation information
- ✅ **Integration points**: Validators called at right places (code gen, ingestion, tool execution)
- ✅ **AI-powered**: MetadataValidator can auto-fix using LLM
- ✅ **Configurable**: Started ValidatorType behavior for config-driven loading
- ✅ **Distributed**: PatternValidatorSubscriber for CentralCloud consensus

### Pain Points & Fragmentation
- ❌ **No unified interface**: 8 validators (excluding ValidatorType itself) use completely different APIs
  - `CodeValidator.validate/1` → `{:ok, String.t()} | {:error, ValidationError}`
  - `TemplateValidator.validate/4` → `{:ok, %{compliant: bool, ...}} | {:error, term}`
  - `Templates.Validator.validate/1` → `{:ok, template} | {:error, [tuples]}`
  - `MetadataValidator.validate_file/2` → `%{level: atom, score: float, has: map, ...}`
  - `SecurityPolicy.validate_code_access/1` → `:ok | {:error, String.t()}`
- ❌ **Config underutilized**: ValidatorType behavior defined but only 1 of 8 validators implements it
- ❌ **Naming inconsistencies**:
  - Some called "Validator", some "ValidatorType", some use `validate*` patterns
  - Return types vary wildly
- ❌ **No composition**: Can't chain validators (e.g., validate both template AND metadata)
- ❌ **Error handling spread**: Different error types (atoms, tuples, exceptions, strings)
- ❌ **Testing isolation**: Each validator tests independently without reusable test utilities
- ❌ **Documentation scattered**: Each validator has different documentation style

## Recommended Consolidation Strategy

### Phase 1: Unified Interface (Week 1)

**Goal**: All validators implement consistent `ValidatorType` behavior

```elixir
defmodule Singularity.Validation.ValidatorType do
  @doc """
  Unified validator behavior for all validation operations.
  
  All validators MUST implement this contract for consistency.
  """
  
  @callback validator_type() :: atom()
  @callback description() :: String.t()
  @callback capabilities() :: [String.t()]
  @callback validate(input :: term(), opts :: Keyword.t()) :: 
    {:ok, validation_result()} | {:error, validation_error()}
  @callback schema() :: map()
  
  # Standard return types for all validators
  @type validation_result :: %{
    valid: boolean(),
    score: float(),  # 0.0 to 1.0
    violations: [violation()],
    details: map()
  }
  
  @type violation :: %{
    code: atom(),
    message: String.t(),
    field: String.t() | nil,
    severity: :error | :warning | :info
  }
  
  @type validation_error :: {:validation_error, String.t()} | any()
end
```

**Migration Path**:
1. Create `Singularity.Validation.Validators` namespace
2. Migrate each validator to implement `@behaviour ValidatorType`
3. Standardize return types (use `validation_result` map)
4. Update all callers to use new interface

### Phase 2: Composition & Chaining (Week 2)

**Goal**: Enable validator composition for complex validation rules

```elixir
defmodule Singularity.Validation.CompositeValidator do
  @doc "Chain multiple validators with AND/OR logic"
  def validate_all(input, validators, opts \\ []) do
    # Returns combined result
  end
  
  def validate_any(input, validators, opts \\ []) do
    # At least one must pass
  end
end
```

**Use Cases**:
- Validate code: quality_template AND metadata
- Validate template: schema AND composition_refs AND quality_standard
- Validate tool access: path AND rate_limit AND codebase_isolation

### Phase 3: Centralized Registry & Discovery (Week 3)

**Goal**: Single source of truth for all validators

```elixir
defmodule Singularity.Validation.Registry do
  @doc "Get all validators"
  def list() :: [{atom(), map()}]
  
  @doc "Get enabled validators"
  def enabled() :: [{atom(), map()}]
  
  @doc "Call validator by type"
  def call(validator_type, input, opts) :: {:ok, map()} | {:error, any()}
end
```

### Phase 4: Testing & Documentation (Week 4)

**Goal**: Unified testing patterns and comprehensive documentation

```elixir
defmodule Singularity.Validation.Testing do
  @doc "Standard test macros for all validators"
  def test_validate_valid_input(validator_module, valid_input)
  def test_validate_invalid_input(validator_module, invalid_input)
  def test_capabilities(validator_module, expected_capabilities)
end
```

## File Organization After Consolidation

```
singularity/lib/singularity/validation/
├── validator.ex                    # Updated behavior contract
├── registry.ex                     # NEW: Central validator registry
├── composite.ex                    # NEW: Composition utilities
├── testing.ex                      # NEW: Shared test utilities
└── validators/
    ├── template_validator.ex       # UPDATED: Implements behavior
    ├── code_quality_validator.ex   # MOVED/RENAMED from storage/code/quality
    ├── metadata_validator.ex       # MOVED from analysis/
    ├── security_policy_validator.ex # MOVED from tools/
    ├── tool_reference_validator.ex  # MOVED from tools/
    ├── hot_reload_validator.ex     # MOVED from hot_reload/
    └── template_structure_validator.ex # MOVED from templates/
```

## Dependencies & Usage Impact

### Files that need updates (37 total)

**Direct validator usage**:
- `rag_code_generator.ex` - Uses `TemplateValidator`
- `code_generator.ex` - Uses `TemplateValidator`
- `rag.setup.ex` - Uses `TemplateValidator`
- `startup_code_ingestion.ex` - Uses `MetadataValidator`
- `unified_ingestion_service.ex` - Uses `MetadataValidator`
- Tool execution framework - Uses `SecurityPolicy`

**Config references**:
- `config/config.exs` - :validator_types configuration
- All test files using validators

### Backward Compatibility

**Non-breaking if done carefully**:
1. Keep old modules as deprecated aliases pointing to new locations
2. Gradual migration over 2 releases
3. Add deprecation warnings for 2 cycles

## Metrics & Success Criteria

### Before Consolidation
- 9 separate validator modules
- 1,939 lines of scattered validation code
- 8 different return types
- Only 1 of 8 validators using ValidatorType behavior
- 0% composition capability

### After Consolidation
- **1 unified ValidatorType** behavior for all
- **8 validators in `/validation/validators/`** namespace
- **1 standard return type** for all validators
- **100% behavior implementation** rate
- **Registry + Composition** for complex validation
- **70% code reduction** through shared utilities
- **Single test suite** with reusable test utilities

## Implementation Effort Estimate

| Phase | Task | Effort | Dependencies |
|-------|------|--------|--------------|
| 1 | Update ValidatorType contract | 8h | None |
| 1 | Implement behavior in 8 validators | 16h | Updated contract |
| 1 | Update all callers | 12h | Behavior implementations |
| 2 | Build CompositeValidator | 8h | Phase 1 complete |
| 2 | Integration tests for composition | 6h | CompositeValidator |
| 3 | Registry implementation | 8h | Phase 1 complete |
| 3 | Configuration system | 6h | Registry |
| 4 | Test utilities & macros | 8h | All validators |
| 4 | Documentation & migration guide | 8h | All phases |
| **Total** | | **80 hours** | |

## Next Steps

1. **Review this report** with team
2. **Prioritize phases** based on timeline
3. **Create tracking issue** for consolidation
4. **Start Phase 1** (unified interface)
5. **Batch migrate validators** (2-3 per day)
6. **Test thoroughly** before merge
7. **Update documentation** with new patterns

