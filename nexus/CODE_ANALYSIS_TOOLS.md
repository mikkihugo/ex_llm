# Code Analysis & Quality Tools for Nexus

## Overview

This guide covers all tools needed for code analysis, quality checks, type analysis, and testing in the Nexus project.

---

## 1. Testing Tools

### Built-in Elixir Testing
**Tool**: ExUnit (built-in)
**Status**: ✅ Already configured
**Command**: 
```bash
mix test --no-start --exclude integration
# Result: 8 doctests, 120 tests, 0 failures ✅
```

**What it does**:
- Runs all tests with ExUnit framework
- Measures basic execution
- No external dependencies needed

### Code Coverage

**Option A: Built-in (Recommended for now)**
```bash
mix test --no-start --exclude integration --cover
# Shows coverage percentage per module
```

**Option B: ExCoveralls (When needed)**
```bash
# Add to mix.exs deps only:
{:excoveralls, "~> 0.18", only: :test}

# Then run:
mix coveralls
mix coveralls.html
```

---

## 2. Code Quality Tools

### Formatting (Code Style)
**Tool**: mix format (built-in)
**Status**: ✅ Built-in
**Command**:
```bash
mix format
# Formats all .ex and .exs files
```

**What it does**:
- Auto-formats code to Elixir standard
- Configurable via `.formatter.exs`
- Zero setup required

### Linting (Code Issues)
**Tool**: Credo
**Status**: ⚠️ Not configured yet
**Setup**:
```bash
# Add to mix.exs deps:
{:credo, "~> 1.7", only: [:dev, :test], runtime: false}

# Run:
mix credo
mix credo --strict
```

**What it does**:
- Detects code style issues
- Suggests improvements
- Finds potential bugs
- Checks consistency

**Recommended for Nexus**: Yes (would improve code consistency)

### Documentation
**Tool**: ExDoc
**Status**: ⚠️ Not configured yet
**Setup**:
```bash
# Add to mix.exs deps:
{:ex_doc, "~> 0.36", only: :dev, runtime: false}

# Run:
mix docs
```

**What it does**:
- Generates HTML documentation from @moduledoc
- Creates searchable docs
- Shows module relationships

---

## 3. Type Analysis Tools

### Static Type Checking
**Tool**: Dialyzer (built-in via mix)
**Status**: ✅ Available
**Command**:
```bash
mix dialyzer
# First run: creates PLT (takes time)
# Subsequent runs: fast incremental checks
```

**What it does**:
- Analyzes code for type errors
- Finds potential runtime errors
- Uses type annotations (specs)
- Generates warnings for suspicious code

**Example - Adding type specs**:
```elixir
@spec http_client() :: module()
defp http_client do
  Application.get_env(:nexus, :http_client, Req)
end
```

**Recommended for Nexus**: Yes (would catch type mismatches)

---

## 4. Security Analysis Tools

### Security Scanning
**Tool**: Sobelow
**Status**: ⚠️ Not configured yet
**Setup**:
```bash
# Add to mix.exs deps:
{:sobelow, "~> 0.14", only: [:dev, :test], runtime: false}

# Run:
mix sobelow
mix sobelow --exit-on-warning
```

**What it does**:
- Detects security vulnerabilities
- Checks for common mistakes:
  - SQL injection risks
  - Missing CSRF protection
  - Insecure authentication
  - Information disclosure

**Recommended for Nexus**: Yes (OAuth2 code especially)

### Dependency Auditing
**Tool**: mix audit (built-in)
**Status**: ✅ Built-in
**Command**:
```bash
mix deps.audit
# Checks for known vulnerabilities in dependencies
```

**What it does**:
- Scans dependencies for known CVEs
- Downloads vulnerability database
- Reports security issues in libraries

---

## 5. Complete Quality Workflow

### Comprehensive Quality Checks
**Recommended setup in mix.exs**:
```elixir
defp aliases do
  [
    # Testing
    "test.unit": ["test --no-start --exclude integration"],
    "test.coverage": ["test --no-start --exclude integration --cover"],
    "test.ci": ["test --no-start --exclude integration"],
    
    # Code Quality
    quality: ["format --check-formatted", "credo --strict"],
    
    # Type Analysis
    "type.check": ["dialyzer"],
    
    # Security
    "security.check": ["sobelow --exit-on-warning", "deps.audit"],
    
    # Complete Pipeline
    "quality.full": [
      "format",           # Auto-format
      "test --no-start",  # Run tests
      "credo",           # Lint
      "dialyzer",        # Type check
      "sobelow",         # Security
      "deps.audit"       # Dependency scan
    ]
  ]
end
```

### Running Complete Quality Checks
```bash
# Just format and lint
mix quality

# Check types
mix type.check

# Security checks
mix security.check

# Everything (comprehensive)
mix quality.full
```

---

## 6. For Nexus Specifically - Recommended Setup

### Priority 1 (Most Important)
✅ Already have:
- ExUnit (testing)
- Mix format (formatting)

Should add:
- **Credo** (linting) - Would catch style issues
- **Dialyzer** (type analysis) - OAuth2 code needs type safety

### Priority 2 (Security)
Should add:
- **Sobelow** (security) - Important for OAuth2/token handling
- **mix deps.audit** - Already have this

### Priority 3 (Nice to Have)
- ExDoc (documentation)
- ExCoveralls (detailed coverage reports)

---

## 7. Quick Setup for Nexus

### Step 1: Update mix.exs

Add to deps:
```elixir
# Code Quality
{:credo, "~> 1.7", only: [:dev, :test], runtime: false},
{:sobelow, "~> 0.14", only: [:dev, :test], runtime: false},
{:ex_doc, "~> 0.36", only: :dev, runtime: false},
```

Add aliases function if not present:
```elixir
def project do
  [
    # ... existing config ...
    aliases: aliases()
  ]
end

defp aliases do
  [
    quality: ["format --check-formatted", "credo --strict"],
    "security.check": ["sobelow --exit-on-warning", "deps.audit"],
    "type.check": ["dialyzer"]
  ]
end
```

### Step 2: Install
```bash
mix deps.get
mix dialyzer --plt  # Creates type analysis database (first run only)
```

### Step 3: Run Checks
```bash
# Check code quality
mix quality

# Type analysis
mix type.check

# Security checks
mix security.check
```

---

## 8. CI/CD Integration

### GitHub Actions Example
```yaml
name: Tests & Quality

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: erlef/setup-elixir@v1
        with:
          otp-version: 27
          elixir-version: 1.19
      
      - name: Install dependencies
        run: cd nexus && mix deps.get
      
      - name: Run tests
        run: cd nexus && mix test --no-start --exclude integration
      
      - name: Check code formatting
        run: cd nexus && mix format --check-formatted
      
      - name: Run linter
        run: cd nexus && mix credo --strict
      
      - name: Type analysis
        run: cd nexus && mix dialyzer
      
      - name: Security check
        run: cd nexus && mix sobelow --exit-on-warning
      
      - name: Dependency audit
        run: cd nexus && mix deps.audit
```

---

## 9. Command Reference

| Tool | Command | Purpose | Setup |
|------|---------|---------|-------|
| **ExUnit** | `mix test --no-start` | Run tests | Built-in ✅ |
| **Format** | `mix format` | Auto-format code | Built-in ✅ |
| **Coverage** | `mix test --cover` | Code coverage | Built-in ✅ |
| **Credo** | `mix credo` | Code linting | Needs setup |
| **Dialyzer** | `mix dialyzer` | Type analysis | Needs setup |
| **Sobelow** | `mix sobelow` | Security check | Needs setup |
| **Audit** | `mix deps.audit` | Dependency scan | Built-in ✅ |
| **Docs** | `mix docs` | Generate docs | Needs setup |

---

## 10. Summary

### Current Status
✅ Testing: 120 unit tests passing
✅ Formatting: Ready (mix format)
❌ Linting: Not configured
❌ Type Analysis: Not configured
❌ Security Scanning: Not configured

### Recommended Next Steps
1. Add Credo (linting)
2. Add Dialyzer configuration (type analysis)
3. Add Sobelow (security)
4. Create CI/CD workflow
5. Run comprehensive quality checks before commits

### For This Session
No immediate action needed - the testing infrastructure is complete and working.

Coverage tools can be added later when detailed metrics are needed.

