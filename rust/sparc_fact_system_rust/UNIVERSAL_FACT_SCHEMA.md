# Universal FACT Schema - All Knowledge Types

## Core Principle

**Every tool/framework/language gets the SAME comprehensive treatment:**
- Version-aware storage
- GitHub examples
- AI-generated knowledge
- A/B tested prompts
- Learning data

## Universal Knowledge Structure

```rust
struct FactKnowledge<T: ToolType> {
    // === IDENTITY ===
    id: String,                      // "nextjs", "rust", "postgres"
    name: String,                    // "Next.js", "Rust", "PostgreSQL"
    ecosystem: Ecosystem,            // npm, cargo, apt, docker
    category: Category<T>,           // Framework, Language, Database, etc.
    version: String,                 // 👈 ALWAYS version-specific

    // === VERSION TRACKING ===
    version_info: VersionInfo,

    // === COMMANDS ===
    commands: CommandSet,

    // === GITHUB DATA ===
    github: GitHubData,

    // === DEPENDENCIES ===
    dependencies: DependencyGraph,

    // === AI KNOWLEDGE ===
    ai_knowledge: AIKnowledge,

    // === PROMPTS (A/B tested) ===
    prompts: PromptCollection,

    // === LEARNING ===
    learning_data: LearningData,

    // === METADATA ===
    metadata: FactMetadata,
}
```

## Unified Core Types

### 1. Version Info (Same for Everything)
```rust
struct VersionInfo {
    version: String,                 // "14.0.0", "1.75.0", "15.4"
    semver: SemVer,                  // Parsed semantic version
    release_date: DateTime<Utc>,
    is_lts: bool,
    is_stable: bool,
    is_latest: bool,
    is_deprecated: bool,
    end_of_life: Option<DateTime<Utc>>,

    // Version relationships
    previous_version: Option<String>,
    next_version: Option<String>,

    // Changes from previous
    breaking_changes: Vec<BreakingChange>,
    new_features: Vec<Feature>,
    deprecations: Vec<Deprecation>,
    bug_fixes: Vec<BugFix>,

    // Migration
    migration_guide: Option<MigrationGuide>,
    migration_complexity: Complexity, // Easy/Medium/Hard
    estimated_migration_hours: f32,
}
```

### 2. Command Set (Unified)
```rust
struct CommandSet {
    // Development
    install: Vec<String>,            // npm install, cargo add, apt install
    dev: Option<DevCommand>,         // Dev server (frameworks)
    build: Option<BuildCommand>,     // Build (frameworks)
    test: Option<TestCommand>,
    lint: Option<LintCommand>,
    format: Option<FormatCommand>,

    // Operations
    start: Option<String>,           // Start server/service
    stop: Option<String>,
    restart: Option<String>,
    status: Option<String>,

    // Tool-specific
    custom_commands: HashMap<String, Command>,
}

struct DevCommand {
    commands: Vec<String>,
    port: Option<u16>,
    hot_reload: bool,
    environment: HashMap<String, String>,
}
```

### 3. GitHub Data (Same Structure)
```rust
struct GitHubData {
    official_repo: String,
    repo_url: String,
    stars: u32,
    forks: u32,
    open_issues: u32,
    license: String,

    // Version-specific code
    examples: Vec<GitHubSnippet>,
    official_docs_url: Option<String>,
    changelog_url: Option<String>,

    // Community
    awesome_list: Option<String>,    // "awesome-nextjs"
    popular_examples: Vec<PopularRepo>,
}

struct GitHubSnippet {
    title: String,
    description: String,
    code: String,
    language: String,
    file_path: String,
    version: String,                 // Version-specific!
    commit_sha: String,
    github_url: String,
    category: String,                // API route, function, config
    upvotes: u32,                    // User validation
}
```

### 4. Dependency Graph (Universal)
```rust
struct DependencyGraph {
    // Required dependencies
    peer_dependencies: Vec<Dependency>,

    // Recommendations
    works_well_with: Vec<ToolPairing>,
    commonly_used_with: Vec<ToolPairing>,

    // Conflicts
    incompatible_with: Vec<Incompatibility>,
    known_issues_with: Vec<KnownIssue>,

    // Integrations
    integrations: Vec<Integration>,
}

struct ToolPairing {
    tool_id: String,
    tool_name: String,
    reason: String,
    usage_percentage: f64,           // % who use together
    success_rate: f64,
    setup_guide: String,
}

struct Integration {
    name: String,
    version: String,
    description: String,
    setup_steps: Vec<String>,
    code_template: String,
    files_to_create: Vec<FileTemplate>,
    env_variables: Vec<EnvVar>,
    success_rate: f64,
    tested: bool,                    // A/B tested
}
```

### 5. AI Knowledge (Generated + Validated)
```rust
struct AIKnowledge {
    // Practices
    best_practices: Vec<BestPractice>,
    common_patterns: Vec<Pattern>,
    anti_patterns: Vec<AntiPattern>,

    // Guides
    quick_start: QuickStart,
    tutorials: Vec<Tutorial>,

    // Problems
    common_mistakes: Vec<Mistake>,
    gotchas: Vec<Gotcha>,
    troubleshooting: Vec<Troubleshooting>,

    // Architecture
    recommended_architecture: Vec<ArchPattern>,
    scalability_tips: Vec<Tip>,
}

struct BestPractice {
    id: String,
    title: String,
    description: String,
    rationale: String,
    code_example: Option<String>,

    // Version applicability
    applies_to_versions: Vec<String>,

    // Validation
    source: Source,
    validation_count: u32,
    success_rate: f64,
    user_rating: f64,                // 1-5 stars
}

enum Source {
    AIGenerated { model: String, confidence: f64 },
    OfficialDocs { url: String },
    CommunityValidated { votes: u32 },
    ExpertReview { expert: String },
    RealUsage { sample_size: u32 },
}
```

### 6. Prompt Collection (A/B Tested)
```rust
struct PromptCollection {
    command_prompts: Vec<AIPrompt>,      // "How to install X"
    integration_prompts: Vec<AIPrompt>,  // "Add Y to X"
    troubleshooting_prompts: Vec<AIPrompt>,
    migration_prompts: Vec<AIPrompt>,
    architecture_prompts: Vec<AIPrompt>,
}

struct AIPrompt {
    id: String,
    prompt_text: String,
    category: PromptCategory,
    tool_version: String,            // Version-specific!

    // Context
    prerequisites: Vec<String>,
    expected_outcome: String,
    validation_steps: Vec<String>,

    // A/B Testing
    variant: String,                 // "concise", "detailed", "visual"
    usage_count: u32,
    success_rate: f64,
    avg_completion_time_ms: u64,
    user_satisfaction: f64,          // 1-5

    // Learning
    works_best_for: Vec<String>,     // User personas
    common_followup: Vec<String>,    // Next prompts
}
```

### 7. Learning Data (Metrics)
```rust
struct LearningData {
    // Usage
    usage_stats: UsageStats,

    // Success metrics
    success_metrics: SuccessMetrics,

    // Feedback
    feedback: FeedbackData,

    // A/B tests
    ab_tests: Vec<ABTest>,
}

struct UsageStats {
    total_usage_count: u32,
    last_30_days: u32,
    unique_users: u32,
    avg_session_duration_minutes: f32,
    repeat_usage_rate: f64,
}

struct SuccessMetrics {
    overall_success_rate: f64,
    avg_setup_time_minutes: f32,
    first_time_success_rate: f64,
    error_rate: f64,

    // By user type
    beginner_success_rate: f64,
    intermediate_success_rate: f64,
    expert_success_rate: f64,
}

struct FeedbackData {
    total_feedback_count: u32,
    avg_rating: f64,                 // 1-5
    positive_feedback_percentage: f64,

    // Sentiment
    common_praise: Vec<String>,
    common_complaints: Vec<String>,
    improvement_suggestions: Vec<String>,
}

struct ABTest {
    test_id: String,
    variant_a: String,
    variant_b: String,
    a_success_rate: f64,
    b_success_rate: f64,
    winner: Option<String>,
    statistical_significance: f64,
    sample_size: u32,
}
```

## Tool-Specific Categories

### Frameworks (Next.js, React, Vue)
```rust
struct FrameworkSpecific {
    framework_type: FrameworkType,   // Frontend/Backend/Fullstack
    rendering: Vec<RenderingMode>,   // SSR, SSG, CSR, ISR
    router_type: RouterType,
    state_management: Vec<String>,
    styling_options: Vec<String>,
}
```

### Languages (Rust, TypeScript, Python)
```rust
struct LanguageSpecific {
    paradigm: Vec<Paradigm>,         // OOP, Functional, Procedural
    type_system: TypeSystem,         // Static, Dynamic, Gradual
    memory_management: MemoryModel,
    compilation: CompilationModel,
    runtime: Runtime,
    package_manager: String,
}
```

### Databases (PostgreSQL, MongoDB, Redis)
```rust
struct DatabaseSpecific {
    db_type: DatabaseType,           // SQL, NoSQL, In-memory
    consistency_model: String,
    scaling_model: ScalingModel,
    query_language: String,
    connection_pooling: bool,
    replication: Vec<ReplicationType>,
}
```

### Build Tools (Vite, Webpack, esbuild)
```rust
struct BuildToolSpecific {
    supported_languages: Vec<String>,
    plugin_system: bool,
    hot_reload: bool,
    code_splitting: bool,
    tree_shaking: bool,
    minification: bool,
    performance_profile: PerformanceProfile,
}
```

## Storage Examples

### Rust 1.75.0
```json
{
  "id": "rust",
  "name": "Rust",
  "ecosystem": "cargo",
  "category": "Language",
  "version": "1.75.0",

  "commands": {
    "install": ["curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"],
    "build": ["cargo build"],
    "test": ["cargo test"],
    "format": ["cargo fmt"]
  },

  "github": {
    "official_repo": "rust-lang/rust",
    "stars": 97000,
    "examples": [...]
  },

  "best_practices": [
    {
      "title": "Use Result<T, E> for error handling",
      "success_rate": 0.98,
      "validation_count": 5234
    }
  ],

  "common_integrations": [
    {"name": "tokio", "version": "1.36.0", "success_rate": 0.97},
    {"name": "serde", "version": "1.0", "success_rate": 0.99}
  ],

  "usage_stats": {
    "usage_count": 45234,
    "success_rate": 0.89,
    "avg_setup_time_minutes": 15
  }
}
```

### PostgreSQL 15.4
```json
{
  "id": "postgres",
  "name": "PostgreSQL",
  "ecosystem": "apt",
  "category": "Database",
  "version": "15.4",

  "commands": {
    "install": ["sudo apt install postgresql-15"],
    "start": ["sudo systemctl start postgresql"],
    "status": ["sudo systemctl status postgresql"]
  },

  "common_integrations": [
    {"name": "prisma", "version": "5.0.0", "success_rate": 0.96},
    {"name": "pgadmin", "version": "4.0", "success_rate": 0.94}
  ]
}
```

## Benefits of Universal Schema

✅ **Consistent:** Same structure for all tools
✅ **Version-aware:** Every tool version tracked
✅ **AI-enhanced:** Knowledge for everything
✅ **Tested:** A/B testing on all prompts
✅ **Learning:** Metrics for all tools
✅ **Searchable:** Query across all types
✅ **Valuable:** Complete dataset for training

**This creates a comprehensive knowledge graph of the entire development ecosystem!**
