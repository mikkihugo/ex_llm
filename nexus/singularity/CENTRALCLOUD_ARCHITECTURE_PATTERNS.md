# CentralCloud Architecture Patterns System

**Centralized architecture pattern detection, enforcement, and learning** 🏗️

---

## 🎯 What Are Architecture Patterns?

**Architecture patterns** are design principles and structural patterns that define how code is organized:

### Code Quality Patterns
- **DRY** (Don't Repeat Yourself) - No code duplication
- **SOLID** - Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion
- **KISS** (Keep It Simple, Stupid) - Simplicity over complexity
- **YAGNI** (You Aren't Gonna Need It) - Don't build what you don't need

### Architecture Patterns
- **Microservices** - Multiple small services
- **Monolith** - Single large application
- **Modular Monolith** - Monolith with clear module boundaries
- **Layered Architecture** - Presentation → Business → Data layers
- **Hexagonal Architecture** - Ports and adapters
- **Event-Driven** - Message-based communication
- **CQRS** (Command Query Responsibility Segregation) - Separate read/write models

### Framework Patterns
- **Phoenix Contexts** - Elixir domain boundaries
- **Rails MVC** - Model-View-Controller
- **React Hooks** - Functional component patterns
- **Rust Ownership** - Memory safety patterns

---

## 🏗️ Proposed Architecture

### Pattern Types in CentralCloud

```elixir
# centralcloud/lib/centralcloud/architecture_patterns.ex

defmodule Centralcloud.ArchitecturePatterns do
  @moduledoc """
  Architecture pattern detection and enforcement.

  Patterns include:
  - Code Quality: DRY, SOLID, KISS, YAGNI
  - Architecture: Microservices, Monolith, Layered, Hexagonal, Event-Driven, CQRS
  - Framework: Phoenix Contexts, Rails MVC, React Hooks, Rust Ownership
  """

  # Auto-detect patterns from codebase
  def detect_patterns(codebase_id, code_samples)

  # Get enabled patterns for project
  def get_enabled_patterns(codebase_id)

  # Enable pattern for project
  def enable_pattern(codebase_id, pattern_name)

  # Disable pattern for project
  def disable_pattern(codebase_id, pattern_name)

  # Validate code against enabled patterns
  def validate_against_patterns(codebase_id, code, enabled_patterns)
end
```

---

## 📊 Pattern Detection (Auto-Enable)

### System Auto-Detects Patterns

**When you ingest code, CentralCloud automatically detects:**

```elixir
# Singularity sends code sample to CentralCloud
code_sample = """
# rust/
# llm-server/
# singularity/
# centralcloud/
"""

CentralCloud.ArchitecturePatterns.detect_patterns("mikkihugo/singularity", code_sample)

# Returns:
%{
  architecture: [:microservices],           # ✅ Auto-detected: 4 services
  code_quality: [:dry, :solid],            # ✅ Auto-detected: No duplication, SOLID violations
  framework: [:phoenix_contexts, :rust_ownership],  # ✅ Auto-detected: Phoenix & Rust
  suggested_enable: [
    :microservices,          # Detected 4 services → Enable microservices pattern
    :dry,                    # No duplication found → Enable DRY enforcement
    :solid,                  # SOLID principles detected → Enable SOLID enforcement
    :phoenix_contexts,       # Phoenix app detected → Enable context boundaries
    :rust_ownership          # Rust code detected → Enable ownership checks
  ]
}
```

### Auto-Enable Detected Patterns

```elixir
# Option 1: Manual approval
detected = CentralCloud.ArchitecturePatterns.detect_patterns(codebase_id, code)
IO.puts("Detected patterns: #{inspect(detected.suggested_enable)}")
IO.puts("Enable all? (y/n)")

# Option 2: Auto-enable (system decides)
CentralCloud.ArchitecturePatterns.auto_enable_detected_patterns(codebase_id, code)
# => Automatically enables all detected patterns
```

---

## 🎯 Pattern Configuration (Per Project)

### Project-Level Pattern Config

```elixir
# PostgreSQL: project_patterns table
CREATE TABLE project_patterns (
  id UUID PRIMARY KEY,
  codebase_id TEXT NOT NULL,           # "mikkihugo/singularity"
  pattern_name TEXT NOT NULL,           # "dry", "solid", "microservices"
  enabled BOOLEAN DEFAULT true,
  enforcement_level TEXT DEFAULT 'warn', # 'ignore', 'warn', 'error'
  config JSONB,                          # Pattern-specific config
  auto_detected BOOLEAN DEFAULT false,   # Was this auto-detected?
  inserted_at TIMESTAMP
);

# Example rows:
| codebase_id               | pattern_name   | enabled | enforcement | auto_detected |
|--------------------------|----------------|---------|-------------|---------------|
| mikkihugo/singularity    | dry            | true    | error       | true          |
| mikkihugo/singularity    | solid          | true    | warn        | true          |
| mikkihugo/singularity    | microservices  | true    | warn        | true          |
| mikkihugo/singularity    | kiss           | false   | ignore      | false         |
| user/my-project          | monolith       | true    | error       | true          |
| user/my-project          | dry            | true    | warn        | true          |
```

### Pattern-Specific Config

```elixir
# DRY pattern config
%{
  pattern_name: "dry",
  enabled: true,
  enforcement_level: "error",  # Fail on duplication
  config: %{
    max_duplicate_lines: 5,      # Allow up to 5 duplicate lines
    ignore_patterns: ["test/**"],  # Don't check test files
    similarity_threshold: 0.85    # 85% similarity = duplication
  }
}

# SOLID pattern config
%{
  pattern_name: "solid",
  enabled: true,
  enforcement_level: "warn",
  config: %{
    check: [:single_responsibility, :open_closed],  # Only check S and O
    max_methods_per_class: 10,                      # SRP: max 10 methods
    max_lines_per_method: 50                        # SRP: max 50 lines per method
  }
}

# Microservices pattern config
%{
  pattern_name: "microservices",
  enabled: true,
  enforcement_level: "warn",
  config: %{
    max_services: 10,                  # Warn if > 10 services
    enforce_api_contracts: true,       # Validate API schemas
    require_service_boundaries: true   # Enforce clear boundaries
  }
}
```

---

## 📡 NATS API

### Query Patterns

```elixir
# Detect patterns for project
subject: "centralcloud.patterns.detect"
payload: %{
  codebase_id: "mikkihugo/singularity",
  code_samples: [...]
}
response: %{
  detected: [:microservices, :dry, :solid],
  suggested_enable: [:microservices, :dry, :solid],
  confidence: %{microservices: 0.95, dry: 0.88, solid: 0.92}
}

# Get enabled patterns for project
subject: "centralcloud.patterns.enabled.query"
payload: %{codebase_id: "mikkihugo/singularity"}
response: %{
  enabled: [
    %{name: "dry", enforcement: "error", config: {...}},
    %{name: "solid", enforcement: "warn", config: {...}},
    %{name: "microservices", enforcement: "warn", config: {...}}
  ]
}

# Enable pattern
subject: "centralcloud.patterns.enable"
payload: %{
  codebase_id: "mikkihugo/singularity",
  pattern_name: "dry",
  enforcement_level: "error",
  config: %{max_duplicate_lines: 5}
}

# Disable pattern
subject: "centralcloud.patterns.disable"
payload: %{
  codebase_id: "mikkihugo/singularity",
  pattern_name: "kiss"
}

# Validate code against patterns
subject: "centralcloud.patterns.validate"
payload: %{
  codebase_id: "mikkihugo/singularity",
  code: "...",
  file_path: "lib/my_module.ex"
}
response: %{
  violations: [
    %{pattern: "dry", severity: "error", message: "Duplicate code detected", line: 42},
    %{pattern: "solid", severity: "warn", message: "Class has too many methods", line: 10}
  ],
  passed: ["microservices", "phoenix_contexts"]
}
```

---

## 🔄 Workflow

### 1. Code Ingestion (Auto-Detect Patterns)

```elixir
# Singularity ingests code
StartupCodeIngestion.run_now()

# Sends code sample to CentralCloud
NatsClient.request("centralcloud.patterns.detect", %{
  codebase_id: "mikkihugo/singularity",
  code_samples: [
    %{path: "rust/code_engine/", language: "rust"},
    %{path: "llm-server/", language: "typescript"},
    %{path: "singularity/", language: "elixir"}
  ]
})

# CentralCloud detects:
# - Microservices (4 services detected)
# - DRY (no duplication found)
# - SOLID (good class structure)
# - Phoenix Contexts (Phoenix app detected)
# - Rust Ownership (Rust code detected)

# Auto-enables all detected patterns
CentralCloud.ArchitecturePatterns.auto_enable([
  "microservices",
  "dry",
  "solid",
  "phoenix_contexts",
  "rust_ownership"
], codebase_id: "mikkihugo/singularity")
```

### 2. Code Generation (Validate Against Patterns)

```elixir
# Singularity generates new code
generated_code = """
defmodule MyApp.UserService do
  def create_user(attrs) do
    # Implementation
  end

  def create_user(attrs, opts) do
    # DUPLICATE! Violates DRY
    # Same logic as above
  end
end
"""

# Validate against enabled patterns
NatsClient.request("centralcloud.patterns.validate", %{
  codebase_id: "mikkihugo/singularity",
  code: generated_code,
  file_path: "lib/my_app/user_service.ex"
})

# Response:
%{
  violations: [
    %{
      pattern: "dry",
      severity: "error",
      message: "Duplicate function detected: create_user/1 and create_user/2 have 85% similarity",
      line: 6,
      suggestion: "Extract common logic into private function"
    }
  ]
}

# Singularity receives error → Regenerates code without duplication
```

### 3. Manual Pattern Config (Override)

```elixir
# User wants to disable SOLID checks (too strict)
NatsClient.publish("centralcloud.patterns.disable", %{
  codebase_id: "mikkihugo/singularity",
  pattern_name: "solid"
})

# Or change enforcement level
NatsClient.publish("centralcloud.patterns.enable", %{
  codebase_id: "mikkihugo/singularity",
  pattern_name: "solid",
  enforcement_level: "warn",  # Change from "error" to "warn"
  config: %{
    check: [:single_responsibility],  # Only check SRP
    max_methods_per_class: 20         # Relax from 10 to 20
  }
})
```

---

## 🎯 Pattern Detection Logic

### Microservices Pattern

```elixir
def detect_microservices(code_samples) do
  service_indicators = [
    has_multiple_build_files?(code_samples),     # Multiple Cargo.toml, package.json
    has_service_directories?(code_samples),      # rust/, llm-server/, singularity/
    has_api_contracts?(code_samples),            # OpenAPI, gRPC schemas
    has_separate_databases?(code_samples)        # Multiple DB configs
  ]

  service_count = count_services(code_samples)

  cond do
    service_count >= 4 -> {:detected, :microservices, confidence: 0.95}
    service_count >= 2 -> {:detected, :distributed, confidence: 0.85}
    service_count == 1 -> {:detected, :monolith, confidence: 0.90}
    true -> {:not_detected, confidence: 0.0}
  end
end
```

### DRY Pattern

```elixir
def detect_dry_violations(code) do
  # Use Rust engine for fast duplicate detection
  {:ok, duplicates} = RustEngine.detect_duplicates(code)

  violations =
    duplicates
    |> Enum.filter(fn dup -> dup.similarity > 0.85 end)
    |> Enum.map(fn dup ->
      %{
        pattern: "dry",
        severity: "error",
        message: "Duplicate code: #{dup.lines} lines with #{dup.similarity * 100}% similarity",
        line: dup.start_line,
        suggestion: "Extract into function: #{suggest_function_name(dup)}"
      }
    end)

  %{violations: violations, passed: length(violations) == 0}
end
```

### SOLID Pattern

```elixir
def detect_solid_violations(code, language) do
  case language do
    "elixir" ->
      # Check Single Responsibility
      modules = extract_modules(code)

      Enum.flat_map(modules, fn module ->
        violations = []

        # SRP: Max 10 public functions
        if length(module.public_functions) > 10 do
          violations = violations ++ [
            %{
              pattern: "solid:srp",
              severity: "warn",
              message: "Module has #{length(module.public_functions)} public functions (max 10)",
              suggestion: "Split into multiple modules by responsibility"
            }
          ]
        end

        # OCP: Check for if/case on types (use protocols instead)
        if has_type_switching?(module) do
          violations = violations ++ [
            %{
              pattern: "solid:ocp",
              severity: "warn",
              message: "Type switching detected, use Elixir protocols for extensibility",
              suggestion: "Convert to protocol: defprotocol MyBehavior"
            }
          ]
        end

        violations
      end)

    "rust" ->
      # Check ownership violations, trait usage, etc.
      detect_rust_solid_violations(code)
  end
end
```

---

## ✅ Benefits

### 1. Centralized Pattern Authority

**Before:**
```
Singularity Instance 1: Detects DRY violations locally
Singularity Instance 2: Detects DRY violations locally (DUPLICATE!)
Singularity Instance 3: Detects DRY violations locally (DUPLICATE!)
```

**After:**
```
All instances: Query CentralCloud for DRY pattern enforcement
CentralCloud: Single source of truth for pattern detection
All instances: Get consistent pattern validation
```

### 2. Auto-Configuration

**Before:**
```
User: "Should I enable DRY? SOLID? What settings?"
System: "You have to manually configure everything"
```

**After:**
```
System: "Detected microservices, DRY, SOLID in your code"
System: "Auto-enabling all detected patterns with recommended settings"
User: "Great! I can override if needed"
```

### 3. Pattern Learning

**Before:**
```
Each instance: Learns patterns independently
No sharing: Pattern knowledge stays local
```

**After:**
```
Instance 1: Discovers new microservice pattern → Sends to CentralCloud
CentralCloud: Enriches with LLM, stores in shared DB
All instances: Get improved microservice pattern detection immediately
```

### 4. Flexible Enforcement

**Before:**
```
Hard-coded pattern enforcement
Can't customize per project
```

**After:**
```
Per-project configuration:
- Project A: DRY=error, SOLID=warn
- Project B: DRY=warn, SOLID=ignore
- Project C: Microservices=error (enforce strict boundaries)
```

---

## 🎉 Summary

**Architecture Pattern System:**
- ✅ Auto-detects patterns (microservices, DRY, SOLID, etc.)
- ✅ Auto-enables detected patterns (or manual approval)
- ✅ Per-project configuration (enable/disable, enforcement levels)
- ✅ Pattern-specific config (max duplicates, max methods, etc.)
- ✅ Centralized in CentralCloud (shared learning)
- ✅ NATS API for all operations
- ✅ Validates code against enabled patterns
- ✅ Suggests fixes for violations

**Workflow:**
```
1. Ingest code → Auto-detect patterns → Auto-enable
2. Generate code → Validate against patterns → Get violations
3. Fix violations → Re-validate → Pass!
4. Override patterns if needed (disable, change enforcement)
```

**Result:** Consistent, enforceable architecture patterns across all projects!

---

**Next:** Implement CentralCloud pattern detection services
