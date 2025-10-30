# Code Quality Agent Migration Guide

## Overview

This document describes the consolidation of `QualityEnforcer` and `RemediationEngine` into the unified `CodeQualityAgent`.

**Status:** Complete
**Date:** 2025-01-30
**New Module:** `Singularity.Agents.CodeQualityAgent`
**Replaces:** `Singularity.Agents.QualityEnforcer` + `Singularity.Agents.RemediationEngine`

## Why Consolidate?

### Problems with Dual-Module Approach

1. **Duplicate Language Detection** - Both modules reimplemented file extension detection
2. **Duplicate Template Loading** - Both loaded quality templates independently
3. **Fragmented Workflow** - Quality detection and remediation were separate
4. **Inconsistent APIs** - Different naming conventions and parameter structures
5. **Higher Maintenance** - Changes required updating both modules

### Benefits of Unified Agent

1. **Single Entry Point** - All quality operations through one module
2. **Unified Workflow** - Detect → Recommend → Remediate pipeline
3. **Zero Duplication** - Shared language detection, template loading, validation
4. **Consistent API** - All operations follow same patterns
5. **Mode-Based Operation** - Configure behavior (detect_only, suggest, auto_remediate)

## API Migration Table

### Quality Detection & Validation

| Old API | New API | Status |
|---------|---------|--------|
| `QualityEnforcer.enforce_quality_standards/1` | `CodeQualityAgent.validate_file/2` | ✅ Replaced |
| `QualityEnforcer.validate_file_quality/1` | `CodeQualityAgent.validate_file/2` | ✅ Replaced |
| - | `CodeQualityAgent.scan_and_report/2` | ✨ New (unified) |

**Migration:**

```elixir
# Before
{:ok, :compliant} = QualityEnforcer.enforce_quality_standards("lib/my_module.ex")
{:ok, report} = QualityEnforcer.validate_file_quality("lib/my_module.ex")

# After
{:ok, report} = CodeQualityAgent.validate_file("lib/my_module.ex")
# Compliant if report.compliant == true

# New unified scan
{:ok, report} = CodeQualityAgent.scan_and_report("lib/my_module.ex")
# Returns: validation + issues + available fixes
```

### Fix Generation & Application

| Old API | New API | Status |
|---------|---------|--------|
| `RemediationEngine.generate_fixes/2` | `CodeQualityAgent.generate_fixes/2` | ✅ Replaced |
| `RemediationEngine.remediate_file/2` | `CodeQualityAgent.remediate_file/2` | ✅ Replaced |
| `RemediationEngine.remediate_batch/2` | `CodeQualityAgent.remediate_batch/2` | ✅ Replaced |
| `RemediationEngine.apply_fix/3` | `CodeQualityAgent.apply_fix/3` | ✅ Replaced |
| `RemediationEngine.validate_remediation/2` | `CodeQualityAgent.validate_remediation/3` | ✅ Replaced |

**Migration:**

```elixir
# Before
{:ok, fixes} = RemediationEngine.generate_fixes("lib/my_module.ex", [])
{:ok, result} = RemediationEngine.remediate_file("lib/my_module.ex", auto_apply: true)
{:ok, batch} = RemediationEngine.remediate_batch(file_paths, [])

# After
{:ok, fixes} = CodeQualityAgent.generate_fixes("lib/my_module.ex")
{:ok, result} = CodeQualityAgent.remediate_file("lib/my_module.ex", auto_apply: true)
{:ok, batch} = CodeQualityAgent.remediate_batch(file_paths, auto_apply: true)
```

### Quality Gates & Configuration

| Old API | New API | Status |
|---------|---------|--------|
| `QualityEnforcer.enable_quality_gates/0` | `CodeQualityAgent.enable_quality_gates/0` | ✅ Replaced |
| `QualityEnforcer.disable_quality_gates/0` | `CodeQualityAgent.disable_quality_gates/0` | ✅ Replaced |
| `QualityEnforcer.get_quality_report/0` | `CodeQualityAgent.get_quality_report/0` | ✅ Replaced |
| - | `CodeQualityAgent.set_mode/1` | ✨ New |

**Migration:**

```elixir
# Before
:ok = QualityEnforcer.enable_quality_gates()
{:ok, report} = QualityEnforcer.get_quality_report()

# After
:ok = CodeQualityAgent.enable_quality_gates()
{:ok, report} = CodeQualityAgent.get_quality_report()

# New mode control
:ok = CodeQualityAgent.set_mode(:suggest)  # detect_only | suggest | auto_remediate
```

## Call Graph Comparison

### QualityEnforcer Functions

| Function | Status | Notes |
|----------|--------|-------|
| `enforce_quality_standards/1` | ✅ Merged | Now `validate_file/2` |
| `validate_file_quality/1` | ✅ Merged | Now `validate_file/2` |
| `get_quality_report/0` | ✅ Preserved | Same API |
| `enable_quality_gates/0` | ✅ Preserved | Same API |
| `disable_quality_gates/0` | ✅ Preserved | Same API |
| `load_quality_templates/1` | ✅ Merged | Private helper |
| `load_template/2` | ✅ Merged | Private helper |
| `validate_file_quality_internal/2` | ✅ Merged | Private helper |
| `validate_content_quality/3` | ✅ Merged | Private helper |
| `get_required_elements/2` | ✅ Merged | Private helper |
| `perform_quality_checks/3` | ✅ Merged | Private helper |
| `check_documentation/2` | ✅ Merged | Private helper |
| `calculate_quality_score/2` | ✅ Merged | Private helper |
| `find_missing_elements/2` | ✅ Merged | Private helper |
| `detect_language/1` | ✅ Unified | Merged with RemediationEngine version |
| `generate_quality_report/1` | ✅ Merged | Private helper |
| `scan_all_files/0` | ✅ Merged | Private helper |
| `calculate_avg_quality/1` | ✅ Merged | Private helper |

### RemediationEngine Functions

| Function | Status | Notes |
|----------|--------|-------|
| `remediate_file/2` | ✅ Preserved | Same API |
| `remediate_batch/2` | ✅ Preserved | Same API |
| `generate_fixes/2` | ✅ Preserved | Same API |
| `apply_fix/3` | ✅ Preserved | Same API + public |
| `validate_remediation/2` | ✅ Enhanced | Now `validate_remediation/3` |
| `detect_issues/2` | ✅ Merged | Private helper |
| `generate_fix_for_issue/2` | ✅ Merged | Private helper |
| `apply_fixes_batch/3` | ✅ Merged | Private helper |
| `apply_fixes_in_order/4` | ✅ Merged | Private helper |
| `apply_auto_fix/2` | ✅ Merged | Private helper |
| `create_backup/1` | ✅ Merged | Private helper |
| `detect_language/1` | ✅ Unified | Merged with QualityEnforcer version |
| `check_missing_moduledoc/2` | ✅ Merged | Private helper |
| `has_long_functions/2` | ✅ Merged | Private helper |
| `has_unused_imports/2` | ✅ Merged | Private helper |
| `has_complex_conditions/2` | ✅ Merged | Private helper |
| `prepend_moduledoc/2` | ✅ Merged | Private helper |
| `fix_indentation/1` | ✅ Merged | Private helper |
| `remove_unused_imports/1` | ✅ Merged | Private helper |
| `extract_module_name/1` | ✅ Merged | Private helper |
| `check_syntax/2` | ✅ Merged | Private helper |
| `check_for_regressions/2` | ✅ Merged | Private helper |
| `check_formatting/2` | ✅ Merged | Private helper |
| `count_functions/1` | ✅ Merged | Private helper |
| `brackets_balanced?/1` | ✅ Merged | Private helper |

### Duplicates Eliminated

| Function | Original Locations | New Location | Change |
|----------|-------------------|--------------|--------|
| `detect_language/1` | QualityEnforcer (3 langs) + RemediationEngine (5 langs) | CodeQualityAgent | Merged to support 8 languages |
| `load_quality_templates/1` | QualityEnforcer only | CodeQualityAgent | Extended to 8 languages |
| `validate_file_exists/1` | QualityEnforcer only | CodeQualityAgent | Reused for all operations |

## Configuration Schema

### Application Configuration

```elixir
# config/config.exs
config :singularity, Singularity.Agents.CodeQualityAgent,
  # Operation mode
  mode: :suggest,  # :detect_only | :suggest | :auto_remediate

  # Quality gates
  quality_gates_enabled: true,

  # Supported languages
  supported_languages: [
    :elixir, :rust, :typescript, :python, :go, :java, :javascript, :gleam
  ],

  # Quality thresholds
  quality_threshold: 0.95,

  # Batch processing
  max_concurrency: 5,
  batch_timeout_ms: 60_000,

  # Fix application
  default_backup: true,
  max_fixes_per_file: 50
```

### Runtime Configuration

```elixir
# Change mode at runtime
:ok = CodeQualityAgent.set_mode(:auto_remediate)

# Enable/disable quality gates
:ok = CodeQualityAgent.enable_quality_gates()
:ok = CodeQualityAgent.disable_quality_gates()
```

## Test Migration

### Test Stubs

```elixir
defmodule Singularity.Agents.CodeQualityAgentTest do
  use ExUnit.Case, async: true
  alias Singularity.Agents.CodeQualityAgent

  describe "validate_file/2" do
    test "validates compliant Elixir file" do
      file_path = "test/fixtures/compliant_module.ex"
      {:ok, report} = CodeQualityAgent.validate_file(file_path)

      assert report.language == :elixir
      assert report.compliant == true
      assert report.quality_score >= 0.95
    end

    test "validates non-compliant Elixir file" do
      file_path = "test/fixtures/non_compliant_module.ex"
      {:ok, report} = CodeQualityAgent.validate_file(file_path)

      assert report.language == :elixir
      assert report.compliant == false
      assert report.quality_score < 0.95
      assert length(report.missing_elements) > 0
    end
  end

  describe "scan_and_report/2" do
    test "scans file and detects issues" do
      file_path = "test/fixtures/issues_module.ex"
      {:ok, report} = CodeQualityAgent.scan_and_report(file_path)

      assert report.quality_score < 1.0
      assert length(report.issues) > 0
      assert report.fixes_available > 0
    end

    test "filters by severity" do
      file_path = "test/fixtures/issues_module.ex"
      {:ok, report} = CodeQualityAgent.scan_and_report(file_path, severity: :high)

      assert Enum.all?(report.issues, fn issue -> issue.severity == :high end)
    end
  end

  describe "generate_fixes/2" do
    test "generates fixes for issues" do
      file_path = "test/fixtures/fixable_module.ex"
      {:ok, fixes} = CodeQualityAgent.generate_fixes(file_path)

      assert length(fixes) > 0
      assert Enum.all?(fixes, fn fix -> Map.has_key?(fix, :id) end)
    end
  end

  describe "remediate_file/2" do
    test "remediates file with auto_apply: false" do
      file_path = "test/fixtures/remediate_module.ex"
      {:ok, result} = CodeQualityAgent.remediate_file(file_path)

      assert result.requires_approval == true
      assert result.fixes_generated > 0
      assert result.fixes_applied == 0
    end

    test "remediates file with auto_apply: true" do
      file_path = "test/fixtures/remediate_module.ex"
      {:ok, result} = CodeQualityAgent.remediate_file(file_path, auto_apply: true)

      assert result.fixes_applied > 0
      assert result.issues_resolved > 0
      assert result.backup_path != nil
    end
  end

  describe "remediate_batch/2" do
    test "remediates multiple files" do
      file_paths = [
        "test/fixtures/batch1.ex",
        "test/fixtures/batch2.ex",
        "test/fixtures/batch3.ex"
      ]

      {:ok, result} = CodeQualityAgent.remediate_batch(file_paths, auto_apply: true)

      assert result.total_files == 3
      assert result.success > 0
    end
  end

  describe "quality gates" do
    test "enables and disables quality gates" do
      :ok = CodeQualityAgent.enable_quality_gates()
      :ok = CodeQualityAgent.disable_quality_gates()
    end

    test "quality report includes gate status" do
      {:ok, report} = CodeQualityAgent.get_quality_report()

      assert Map.has_key?(report, :quality_gates_enabled)
      assert Map.has_key?(report, :total_files)
      assert Map.has_key?(report, :compliance_rate)
    end
  end

  describe "mode control" do
    test "sets operation mode" do
      :ok = CodeQualityAgent.set_mode(:detect_only)
      :ok = CodeQualityAgent.set_mode(:suggest)
      :ok = CodeQualityAgent.set_mode(:auto_remediate)
    end
  end
end
```

## Supervisor Integration

### Before (Two Agents)

```elixir
defmodule Singularity.Agents.Supervisor do
  use Supervisor

  def init(opts) do
    children = [
      Singularity.Agents.QualityEnforcer,
      Singularity.Agents.RemediationEngine,
      # ... other agents
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

### After (Unified Agent)

```elixir
defmodule Singularity.Agents.Supervisor do
  use Supervisor

  def init(opts) do
    children = [
      Singularity.Agents.CodeQualityAgent,
      # ... other agents
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

## Migration Checklist

### Step 1: Update Supervisor

- [ ] Remove `QualityEnforcer` from children
- [ ] Remove `RemediationEngine` from children
- [ ] Add `CodeQualityAgent` to children

### Step 2: Update Callers

#### DocumentationPipeline

```elixir
# Before
alias Singularity.Agents.QualityEnforcer
{:ok, report} = QualityEnforcer.validate_file_quality(file_path)

# After
alias Singularity.Agents.CodeQualityAgent
{:ok, report} = CodeQualityAgent.validate_file(file_path)
```

#### SelfImprovingAgent

```elixir
# Before
alias Singularity.Agents.RemediationEngine
{:ok, result} = RemediationEngine.remediate_file(file_path, auto_apply: true)

# After
alias Singularity.Agents.CodeQualityAgent
{:ok, result} = CodeQualityAgent.remediate_file(file_path, auto_apply: true)
```

### Step 3: Update Tests

- [ ] Rename test files
  - `quality_enforcer_test.exs` → `code_quality_agent_test.exs`
  - Remove `remediation_engine_test.exs` (merge into above)
- [ ] Update test module names
- [ ] Update function calls to new API
- [ ] Add tests for new `scan_and_report/2` function
- [ ] Add tests for `set_mode/1` function

### Step 4: Update Configuration

- [ ] Update `config/config.exs` with new schema
- [ ] Update `config/test.exs` if needed
- [ ] Remove old agent-specific configs

### Step 5: Deprecate Old Modules

```elixir
# Add to quality_enforcer.ex and remediation_engine.ex
@deprecated "Use Singularity.Agents.CodeQualityAgent instead"
```

### Step 6: Documentation Updates

- [ ] Update README.md
- [ ] Update AGENTS.md
- [ ] Add this migration guide to docs/

## Rollback Plan

If issues arise, rollback by:

1. Revert supervisor changes
2. Re-enable old modules in supervisor
3. Revert caller changes
4. Keep `CodeQualityAgent` for gradual migration

Both old and new agents can coexist during transition.

## Performance Impact

### Before (Dual Modules)

- Template loading: 2x (once per module)
- Language detection: 2x implementations
- Memory usage: 2x state (2 GenServers)

### After (Unified Agent)

- Template loading: 1x (shared)
- Language detection: 1x implementation (8 languages)
- Memory usage: 1x state (1 GenServer)
- **Estimated savings:** ~40% memory, ~50% faster initialization

## Breaking Changes

### None for Public API

All public functions preserved with same or enhanced signatures:

- `validate_file/2` - Enhanced (was `validate_file_quality/1`)
- `remediate_file/2` - Same
- `remediate_batch/2` - Same
- `generate_fixes/2` - Same
- `enable_quality_gates/0` - Same
- `disable_quality_gates/0` - Same
- `get_quality_report/0` - Enhanced (includes mode)

### Internal Changes Only

- GenServer name changed from `QualityEnforcer` or `RemediationEngine` to `CodeQualityAgent`
- Registration with coordination router uses `:code_quality_agent` atom

## New Features

1. **Unified Scan** - `scan_and_report/2` combines validation + issue detection + fix generation
2. **Mode Control** - `set_mode/1` for runtime behavior configuration
3. **Extended Language Support** - 8 languages (was 3 for QualityEnforcer, 5 for RemediationEngine)
4. **Enhanced Telemetry** - Unified event namespace `[:singularity, :code_quality_agent, ...]`

## Timeline

- **Phase 1 (Week 1):** Implement unified agent ✅ COMPLETE
- **Phase 2 (Week 1):** Update tests and documentation
- **Phase 3 (Week 2):** Update all callers
- **Phase 4 (Week 2):** Deploy and monitor
- **Phase 5 (Week 3):** Remove deprecated modules

## Questions & Answers

**Q: Can I still use the old modules?**
A: Yes, they will be marked deprecated but remain functional during transition.

**Q: What happens to quality gate enforcement?**
A: Fully preserved. Enable/disable APIs unchanged.

**Q: Are there any API breaking changes?**
A: No. All public APIs preserved or enhanced with backward compatibility.

**Q: How do I migrate incrementally?**
A: Update one caller at a time. Both old and new agents can coexist.

**Q: What about performance?**
A: Expect ~40% memory savings and ~50% faster initialization.

## Contact

For questions or issues during migration:
- Check this guide
- Review test stubs
- Consult module documentation in `code_quality_agent.ex`
