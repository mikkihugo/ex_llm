# Template Centralization Design

## Goal
Create ONE central template library (`rust/template/`) that provides ALL templates to parsers, analyzers, code generation, and LLM prompts throughout Singularity.

## Principles
1. **Single Source of Truth**: All templates accessible via `rust/template` API
2. **Every Default Has Original**: All default prompts include base/original version for reference
3. **Dual Storage**: Git ([templates_data/](templates_data/)) ←→ Runtime (Rust structs)
4. **Type Safety**: Strongly-typed template definitions
5. **Universal Access**: Used by parsers, analyzers, generators, prompts everywhere

## Architecture

```
rust/template/                    (Central Template Library)
├── src/
│   ├── lib.rs                   (Public API - main entry point)
│   ├── types.rs                 (Template type definitions)
│   ├── loader.rs                (Load from templates_data/)
│   ├── registry.rs              (In-memory template registry)
│   ├── code/                    (Code generation templates)
│   │   ├── mod.rs
│   │   ├── languages.rs         (rust-api-endpoint, python-fastapi, etc.)
│   │   └── microservices.rs     (Service templates)
│   ├── prompt/                  (LLM prompt templates)
│   │   ├── mod.rs
│   │   ├── sparc.rs             (SPARC workflow prompts)
│   │   ├── system.rs            (System prompts with originals)
│   │   └── enrichment.rs        (Enrichment prompts)
│   ├── framework/               (Framework patterns)
│   │   ├── mod.rs
│   │   ├── react.rs
│   │   ├── phoenix.rs
│   │   └── django.rs
│   ├── workflow/                (Workflow definitions)
│   │   ├── mod.rs
│   │   └── sparc.rs             (SPARC 8-phase workflow)
│   └── quality/                 (Quality standards)
│       ├── mod.rs
│       └── standards.rs
└── Cargo.toml

templates_data/                   (Git source - unchanged)
├── code_generation/
├── frameworks/
├── workflows/
├── microsnippets/
└── enrichment_prompts/
```

## Template Types (Unified)

```rust
// rust/template/src/types.rs

/// Central template type - covers ALL template use cases
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Template {
    /// Template identifier (e.g., "rust-api-endpoint", "sparc-research")
    pub id: String,

    /// Template category
    pub category: TemplateCategory,

    /// Template content (may be code, prompt, or structured data)
    pub content: TemplateContent,

    /// Metadata
    pub metadata: TemplateMetadata,

    /// Original/base version (for prompts)
    pub original: Option<Box<Template>>,

    /// Parent template (inheritance)
    pub extends: Option<String>,

    /// Composable bits
    pub compose: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TemplateCategory {
    /// Code generation (rust-api-endpoint, python-fastapi)
    CodeGeneration,

    /// LLM prompts (SPARC, system prompts, enrichment)
    Prompt,

    /// Framework patterns (React, Phoenix, Django)
    Framework,

    /// Workflow definitions (SPARC 8-phase)
    Workflow,

    /// Quality standards
    Quality,

    /// Microsnippets (reusable bits)
    Snippet,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TemplateContent {
    /// Plain text (code, markdown)
    Text(String),

    /// Structured JSON
    Json(serde_json::Value),

    /// SPARC workflow phases
    Workflow(Vec<WorkflowPhase>),

    /// LLM prompt with variables
    Prompt {
        system: String,
        user: String,
        variables: HashMap<String, String>,
        /// Original base prompt (before customization)
        original: Option<String>,
    },
}
```

## Public API

```rust
// rust/template/src/lib.rs

use anyhow::Result;

/// Central template registry - load once, use everywhere
pub struct TemplateRegistry {
    templates: HashMap<String, Template>,
}

impl TemplateRegistry {
    /// Load all templates from templates_data/
    pub fn new() -> Result<Self>;

    /// Get template by ID
    pub fn get(&self, id: &str) -> Option<&Template>;

    /// Search templates by category
    pub fn by_category(&self, category: TemplateCategory) -> Vec<&Template>;

    /// Search templates by tag
    pub fn search(&self, query: &str) -> Vec<&Template>;

    /// Get code generation template
    pub fn code_template(&self, language: &str, template: &str) -> Option<&Template>;

    /// Get prompt template (includes original)
    pub fn prompt_template(&self, name: &str) -> Option<&Template>;

    /// Get framework pattern
    pub fn framework_pattern(&self, framework: &str) -> Option<&Template>;

    /// Get SPARC workflow phase
    pub fn sparc_phase(&self, phase: usize) -> Option<&Template>;
}

/// Global template registry (lazy-loaded)
pub fn templates() -> &'static TemplateRegistry;

/// Convenience functions
pub fn get_template(id: &str) -> Option<&'static Template>;
pub fn code_template(language: &str, template: &str) -> Option<&'static Template>;
pub fn prompt_template(name: &str) -> Option<&'static Template>;
```

## Usage Examples

### From Parsers
```rust
// rust/parser/polyglot/src/lib.rs
use template::{templates, TemplateCategory};

pub fn parse_with_template(code: &str, language: &str) -> Result<ParsedCode> {
    // Get language-specific template
    let tmpl = templates().code_template(language, "parser-config")?;
    // Use template...
}
```

### From Code Analysis
```rust
// rust/code_analysis/src/analyzer.rs
use template::prompt_template;

pub fn analyze_quality(code: &str) -> Result<QualityReport> {
    // Get prompt template with original
    let prompt = prompt_template("code-quality-analysis").unwrap();

    // prompt.original contains base prompt before customization
    let system_prompt = prompt.get_system_with_original();

    // Use for LLM call...
}
```

### From Code Generation
```rust
// rust/package/src/generator.rs
use template::code_template;

pub fn generate_api_endpoint(spec: &ApiSpec) -> Result<String> {
    let tmpl = code_template("rust", "api-endpoint").unwrap();
    tmpl.render(spec)
}
```

### From Prompt Service
```rust
// rust/prompt/src/sparc.rs
use template::templates;

pub fn get_sparc_phase(phase: usize) -> Result<Template> {
    templates().sparc_phase(phase)
        .cloned()
        .ok_or_else(|| anyhow!("Invalid SPARC phase"))
}
```

## Migration Plan

### Phase 1: Create Central Library
1. Implement `rust/template/src/` structure
2. Define unified `Template` types
3. Create loader for `templates_data/`
4. Build in-memory registry with lazy_static

### Phase 2: Migrate Existing Templates
1. Move `rust/prompt/src/*_templates.rs` logic to `rust/template/src/prompt/`
2. Consolidate `rust/package/src/template.rs` into central lib
3. Update `rust/parser/formats/template_definitions` to use central types

### Phase 3: Update Consumers
1. Update parsers to use `template::templates()`
2. Update analyzers to use `template::prompt_template()`
3. Update generators to use `template::code_template()`
4. Remove scattered template loading logic

### Phase 4: Add Originals to All Prompts
1. Extract base prompts from all LLM calls
2. Store as `original` field in Template
3. Ensure all prompt templates include base version

## Benefits

1. **Single Import**: `use template::templates;` everywhere
2. **Type Safety**: No more string-based template paths
3. **Discoverability**: IDE autocomplete shows all templates
4. **Consistency**: Same API for code, prompts, frameworks, workflows
5. **Default Originals**: Every prompt has base version for reference
6. **Performance**: Load once, use everywhere (lazy_static)
7. **Testability**: Mock templates easily
8. **Documentation**: Self-documenting via Rust docs

## Example: Every Prompt Has Original

```rust
// rust/template/src/prompt/system.rs

pub fn code_quality_prompt() -> Template {
    Template {
        id: "code-quality-analysis".to_string(),
        category: TemplateCategory::Prompt,
        content: TemplateContent::Prompt {
            system: "You are an expert code reviewer focusing on quality metrics...".to_string(),
            user: "Analyze this code: {code}".to_string(),
            variables: HashMap::from([("code".to_string(), "".to_string())]),
            // ORIGINAL base prompt
            original: Some("Analyze the code quality.".to_string()),
        },
        metadata: TemplateMetadata { /* ... */ },
        original: None,
        extends: None,
        compose: vec![],
    }
}
```

## Next Steps

1. Implement `rust/template/src/types.rs` with unified types
2. Implement `rust/template/src/loader.rs` to read `templates_data/`
3. Implement `rust/template/src/registry.rs` with lazy_static
4. Create domain-specific modules (code/, prompt/, framework/, workflow/)
5. Update all consumers to use central API
6. Add originals to all existing prompts
7. Remove scattered template code

This creates a **true central template library** used by **everything** in Singularity!
