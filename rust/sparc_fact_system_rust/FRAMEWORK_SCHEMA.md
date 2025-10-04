# Framework Knowledge Schema - Complete Design

## From Netlify (Detection Layer)

```rust
// What Netlify framework-info provides
struct NetlifyFramework {
    id: String,                // "nextjs"
    name: String,              // "Next.js"
    category: String,          // "frontend_framework"
    dev: DevCommand,           // { commands: ["npm run dev"], port: 3000 }
    build: BuildCommand,       // { commands: ["npm run build"], directory: ".next" }
    staticAssetsDirectory: Option<String>,
    env: HashMap<String, String>,
    plugins: Vec<String>,      // Recommended Netlify plugins
}
```

## Our Enhanced Schema (AI Knowledge Layer)

```rust
// What we ADD on top for AI development
struct FrameworkKnowledge {
    // === DETECTION (from Netlify) ===
    framework_id: String,
    framework_name: String,
    version: String,               // 👈 VERSION-SPECIFIC!
    category: FrameworkCategory,

    // === BUILD/DEV ===
    dev_command: Vec<String>,
    dev_port: Option<u16>,
    build_command: Vec<String>,
    output_directory: String,
    install_command: String,
    test_command: Option<String>,
    lint_command: Option<String>,

    // === VERSION TRACKING ===
    release_date: DateTime<Utc>,
    is_lts: bool,
    end_of_life: Option<DateTime<Utc>>,

    // === GITHUB DATA (version-specific) ===
    official_repo: String,
    github_examples: Vec<GitHubSnippet>,    // Real code from official repo @ this version
    github_stars: u32,
    github_issues: u32,

    // === DEPENDENCIES ===
    peer_dependencies: Vec<Dependency>,     // Required: "react": "^18.0.0"
    recommended_tools: Vec<Tool>,           // Works well with: "prisma", "tailwind"
    common_integrations: Vec<Integration>,  // How to add: Prisma, Auth, etc.
    incompatible_with: Vec<String>,         // Known conflicts

    // === AI-GENERATED KNOWLEDGE ===
    best_practices: Vec<BestPractice>,      // AI-curated + user feedback
    common_patterns: Vec<CodePattern>,       // API routes, middleware, etc.
    anti_patterns: Vec<AntiPattern>,         // What NOT to do
    quick_start: QuickStartGuide,            // 5-minute setup
    common_mistakes: Vec<CommonMistake>,     // "Forgot to add 'use client'"

    // === VERSION CHANGES ===
    breaking_changes: Vec<BreakingChange>,   // vs previous version
    new_features: Vec<NewFeature>,
    deprecations: Vec<Deprecation>,
    migration_guide: Option<MigrationGuide>,

    // === PROMPTS (A/B tested) ===
    command_prompts: Vec<AIPrompt>,          // "How to run Next.js 14"
    integration_prompts: Vec<AIPrompt>,      // "Add Prisma to Next.js 14"
    troubleshooting_prompts: Vec<AIPrompt>,  // "Fix Next.js build errors"

    // === LEARNING DATA ===
    usage_stats: UsageStats,
    success_rate: f64,
    avg_setup_time_minutes: u32,
    feedback_count: u32,

    // === METADATA ===
    detected_at: DateTime<Utc>,
    last_updated: DateTime<Utc>,
    confidence_score: f64,
    data_sources: Vec<DataSource>,
}
```

## Detailed Field Definitions

### Version Tracking
```rust
struct VersionInfo {
    version: String,                 // "14.0.0"
    release_date: DateTime<Utc>,     // When released
    is_lts: bool,                    // Long-term support?
    is_latest: bool,                 // Current latest?
    is_stable: bool,                 // Production-ready?
    end_of_life: Option<DateTime<Utc>>, // Support ends
    previous_version: Option<String>, // "13.5.0"
    next_version: Option<String>,    // "14.1.0"
}
```

### Breaking Changes (Critical for Version Awareness)
```rust
struct BreakingChange {
    id: String,
    title: String,                   // "Removed default export from next/image"
    description: String,
    affected_api: String,            // "next/image"
    migration_steps: Vec<String>,    // How to fix
    severity: Severity,              // Major/Minor/Patch
    affects_percentage: f64,         // % of users affected
    github_issue: Option<String>,
    examples: Vec<CodeExample>,      // Before/after code
}
```

### GitHub Snippets (Version-Specific!)
```rust
struct GitHubSnippet {
    id: String,
    title: String,
    description: String,
    code: String,
    language: String,
    file_path: String,               // In official repo
    version: String,                 // "14.0.0"
    commit_sha: String,
    github_url: String,
    stars: u32,                      // If from community
    category: SnippetCategory,       // API route, component, config
}

enum SnippetCategory {
    APIRoute,
    ServerComponent,
    ClientComponent,
    Middleware,
    Configuration,
    Layout,
    ErrorHandling,
}
```

### Best Practices (AI-Generated + Validated)
```rust
struct BestPractice {
    id: String,
    title: String,
    description: String,
    rationale: String,               // Why this is important
    code_example: Option<String>,
    applies_to_versions: Vec<String>, // ["14.0.0", "14.1.0"]
    source: Source,                  // AI-generated, Official docs, Community
    validation_count: u32,           // How many users validated
    success_rate: f64,               // 0.95 = 95% success
}

enum Source {
    AIGenerated { model: String, prompt: String },
    OfficialDocs { url: String },
    CommunityValidated { votes: u32 },
    ExpertReview { expert: String },
}
```

### Common Patterns
```rust
struct CodePattern {
    id: String,
    name: String,                    // "Dynamic API Routes"
    description: String,
    use_case: String,                // "RESTful endpoints with params"
    code_example: String,
    file_structure: Vec<String>,     // ["app/api/users/[id]/route.ts"]
    frequency: Frequency,            // How common
    difficulty: Difficulty,
    related_patterns: Vec<String>,
}
```

### Common Integrations
```rust
struct Integration {
    name: String,                    // "Prisma"
    version: String,                 // Compatible version
    description: String,
    installation_steps: Vec<String>,
    configuration: String,           // Code to add
    files_to_create: Vec<FileTemplate>,
    env_variables: Vec<EnvVar>,
    gotchas: Vec<String>,            // Common issues
    works_with_version: Vec<String>, // Next.js versions
    tested: bool,                    // A/B tested
    success_rate: f64,
}
```

### AI Prompts (A/B Tested)
```rust
struct AIPrompt {
    id: String,
    prompt_text: String,
    category: PromptCategory,
    framework_version: String,       // Version-specific!

    // A/B testing
    variant: String,                 // "concise" vs "detailed"
    usage_count: u32,
    success_rate: f64,
    avg_completion_time_ms: u64,

    // Context
    prerequisites: Vec<String>,
    expected_outcome: String,
    validation_command: Option<String>,
}
```

## Storage Examples

### Next.js 14.0.0
```json
{
  "framework_id": "nextjs",
  "framework_name": "Next.js",
  "version": "14.0.0",
  "release_date": "2023-10-26T00:00:00Z",
  "is_lts": false,
  "is_latest": false,

  "dev_command": ["npm run dev"],
  "dev_port": 3000,
  "build_command": ["npm run build"],

  "official_repo": "vercel/next.js",
  "github_stars": 125000,

  "breaking_changes": [
    {
      "title": "Removed next/image default export",
      "severity": "Major",
      "affects_percentage": 0.65,
      "migration_steps": [
        "Change: import Image from 'next/image'",
        "To: import { Image } from 'next/image'"
      ]
    }
  ],

  "best_practices": [
    {
      "title": "Use App Router for new projects",
      "rationale": "Better performance, more features",
      "applies_to_versions": ["14.0.0", "14.1.0", "14.2.0"],
      "validation_count": 523,
      "success_rate": 0.92
    }
  ],

  "common_integrations": [
    {
      "name": "Prisma",
      "version": "5.0.0",
      "installation_steps": [...],
      "success_rate": 0.95,
      "tested": true
    }
  ],

  "usage_stats": {
    "usage_count": 1523,
    "success_rate": 0.94,
    "avg_setup_time_minutes": 8,
    "feedback_count": 342
  }
}
```

## Data Sources

```rust
enum DataSource {
    Netlify,                // Detection
    GitHub,                 // Official code
    AI { model: String },   // Generated knowledge
    UserFeedback,           // Real usage data
    ABTest { test_id: String },
}
```

## Comparison: Ours vs Netlify

| Feature | Netlify | Our Enhanced |
|---------|---------|--------------|
| **Detection** | ✅ | ✅ (use Netlify) |
| **Commands** | ✅ | ✅ (use Netlify) |
| **Version tracking** | ❌ | ✅ Each version |
| **GitHub examples** | ❌ | ✅ Version-specific |
| **Breaking changes** | ❌ | ✅ Tracked |
| **Best practices** | ❌ | ✅ AI-generated |
| **Common patterns** | ❌ | ✅ Validated |
| **Integrations** | ❌ | ✅ Tested |
| **A/B testing** | ❌ | ✅ Full system |
| **Learning data** | ❌ | ✅ Usage stats |
| **Migration guides** | ❌ | ✅ Version diffs |

## Implementation Priority

### Phase 1 (Now)
- ✅ Version-aware storage (redb + JSON)
- ✅ Basic framework info from Netlify
- ⏳ GitHub code fetching

### Phase 2
- AI-generated best practices
- Common patterns extraction
- Basic A/B testing

### Phase 3
- Integration guides
- Migration automation
- Full learning system

**This gives us a MASSIVE competitive advantage over just using Netlify!**
