# Singularity Branding Guide

## Proper Names & Terminology

### Core System
- **Singularity** or **Singularity Core** - The autonomous code generation and self-improvement system
- *Not:* "The Core", "Central", just "Singularity" alone (confusing with products)

### Products (Customer Acquisition)
- **Singularity Smart Package Context** - Package docs + examples + patterns
- **Singularity Scanner** - Code quality analyzer
- **Singularity GitHub App** - PR automation
- **Singularity Central Cloud** - Pattern aggregation infrastructure

*Shorthand: "Singularity Products" or individually as above*

### Infrastructure
- **Singularity Central Cloud** or **Central Cloud** - Multi-instance pattern aggregation
- *Not:* "CentralCloud", "Singularity CentralCloud"

### Ecosystem
- **Singularity Ecosystem** - Complete system: Core + Products + Central Cloud + Genesis
- **Singularity Products** - The 4 free/freemium customer acquisition tools

### Related Systems
- **Singularity Genesis** - Autonomous rule evolution
- **Singularity Observer** - Real-time observability dashboard

---

## Usage Examples

### ✅ CORRECT

"Singularity Core auto-generates code. Singularity Products acquire customers."

"Singularity Central Cloud aggregates patterns from all instances."

"Singularity Smart Package Context is available on MCP, VS Code, CLI, and HTTP API."

"The Singularity Ecosystem combines Core, Products, Central Cloud, and Genesis."

### ❌ INCORRECT

"CentralCloud is..." (missing "Singularity", sounds like external service)

"Singularity CentralCloud" (redundant if context is clear, but "Central Cloud" works)

"The Core system" (too generic, be explicit: "Singularity Core")

"Smart Package Context is a Singularity product" (awkward - use "Singularity Smart Package Context")

"Singularity products use CentralCloud" (be explicit: "Singularity Central Cloud")

---

## Directory Structure

```
singularity/                          ← Repo name (lowercase)
├── products/                         ← Products directory
│   ├── singularity-smart-package-context/
│   ├── singularity-scanner/
│   ├── singularity-github-app/
│   └── singularity-central-cloud/    ← Part of products for distribution
│
├── nexus/
│   ├── singularity/                  ← Core system
│   ├── central_services/             ← Central Cloud backend
│   └── genesis/                      ← (Optional future)
│
└── packages/                         ← Shared libraries
    ├── quantum_flow/
    ├── ex_llm/
    ├── code_quality_engine/
    ├── parser_engine/
    └── package_intelligence/
```

---

## Marketing Messages

### Singularity Core
"Automatic code generation with autonomous learning"
"Self-improving code generation pipeline"
"The future of development: let AI write your code"

### Singularity Products
"Free tools that make you a better developer"
"Know before you code. Fix before it breaks. Merge with confidence."

### Singularity Smart Package Context
"Package intelligence: docs + examples + what works"
"Know what works before you code"

### Singularity Scanner
"Find issues. Learn from the community. Fix with confidence."
"Code quality that improves over time"

### Singularity GitHub App
"PR quality checks powered by community wisdom"
"Merge better code, every time"

### Singularity Central Cloud
"Collective intelligence. Proven patterns. Network effects."
"What works for them works for you"

### Singularity Ecosystem
"The complete development intelligence platform"
"Free products that lead to Singularity Core"

---

## Naming Conventions

### Product Directories
- Lowercase with hyphens: `singularity-smart-package-context`
- Not: `SingularitySmartPackageContext`, `singularity_smart_package_context`

### Module/Code Names
- PascalCase in code: `SingularitySmartPackageContext` (Elixir/Rust)
- `singularity::smart_package_context` (Rust modules)

### GitHub/npm/Homebrew
- Lowercase with hyphens: `singularity-smart-package-context`
- Company name: "singularity-ai" or "singularityai"

### Documentation
- Title case: "Singularity Smart Package Context"
- Markdown: `# Singularity Smart Package Context`

---

## Avoid Confusion

These all refer to the same thing (use consistently):
- ✅ "Singularity Central Cloud" (preferred)
- ✅ "Central Cloud" (if context is clear)
- ❌ "CentralCloud" (no space, too close to variable names)
- ❌ "Singularity CentralCloud" (awkward double name)

---

## When to Use Each Term

| Situation | Term | Example |
|-----------|------|---------|
| Talking about auto-code-gen | Singularity Core | "Singularity Core generates code automatically" |
| Talking about all 4 tools | Singularity Products | "Try our Singularity Products for free" |
| Talking about one tool | By name | "Singularity Smart Package Context helps you..." |
| Talking about pattern aggregation | Singularity Central Cloud | "Singularity Central Cloud learns from all instances" |
| Talking about everything together | Singularity Ecosystem | "The Singularity Ecosystem combines..." |
| Specific mention, very brief | Short form | "Central Cloud" or "Smart Package Context" |

---

## FAQ

**Q: Can I say "Singularity" alone?**
A: Only in context where it's clear you mean the core system. Better to say "Singularity Core" to avoid confusion with products.

**Q: Is it "Central Cloud" or "Singularity Central Cloud"?**
A: Both work. "Central Cloud" is fine in context. "Singularity Central Cloud" is more explicit. Avoid "CentralCloud".

**Q: How do I refer to all 4 products?**
A: "Singularity Products" or list them individually with "Singularity" prefix.

**Q: What about version numbers?**
A: "Singularity Core v2.0" or "Singularity Smart Package Context v1.0"

**Q: Should products have individual version numbers?**
A: Yes. Each product (and Core) has its own version. They're separate deliverables.

---

## Key Principle

**Singularity = The Umbrella Brand**

Everything is "Singularity *Something*":
- Singularity Core
- Singularity Products
- Singularity Smart Package Context
- Singularity Scanner
- Singularity GitHub App
- Singularity Central Cloud
- Singularity Genesis
- Singularity Observer
- Singularity Ecosystem

This creates a cohesive, recognizable brand ecosystem.
