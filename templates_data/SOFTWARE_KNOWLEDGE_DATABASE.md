# Software Knowledge Database

**Package registries, GitHub repos, frameworks, and version-aware code snippets.**

*Note: QA/quality templates are in a separate database. This covers software artifacts only.*

## Overview

All knowledge lives in PostgreSQL and syncs bidirectionally with Git (`templates_data/`).

```
┌─────────────────────────────────────────────────────────────────┐
│  PostgreSQL: Software Knowledge Database                         │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  Packages    │  │  Frameworks  │  │  Repositories│         │
│  │              │  │              │  │              │         │
│  │ - npm        │  │ - Phoenix    │  │ - GitHub     │         │
│  │ - cargo      │  │ - FastAPI    │  │ - GitLab     │         │
│  │ - hex        │  │ - Next.js    │  │              │         │
│  │ - pypi       │  │              │  │              │         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
│         │                 │                  │                  │
│         └─────────────────┼──────────────────┘                  │
│                           │                                     │
│                  ┌────────▼────────┐                            │
│                  │  Microsnippets  │                            │
│                  │  (version-aware)│                            │
│                  └─────────────────┘                            │
└─────────────────────────────────────────────────────────────────┘
```

## Core Tables

### 1. `packages`
**External package registry data (npm, cargo, hex, pypi)**

```sql
CREATE TABLE packages (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  ecosystem TEXT NOT NULL, -- npm, cargo, hex, pypi
  version TEXT NOT NULL, -- Semver: 1.7.14, 2.0.0-beta
  description TEXT,
  homepage TEXT,
  repository_url TEXT, -- Links to repositories table

  -- Metadata
  downloads BIGINT,
  github_stars INT,
  quality_score FLOAT,

  -- Dependencies (JSONB for flexibility)
  dependencies JSONB, -- {phoenix: "~> 1.7", ecto: "~> 3.11"}
  dev_dependencies JSONB,

  -- Search
  keywords TEXT[],
  embedding VECTOR(1536), -- For semantic search

  -- Timestamps
  published_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(ecosystem, name, version)
);

-- Example rows
-- {ecosystem: "hex", name: "phoenix", version: "1.7.14", dependencies: {ecto: "~> 3.11"}}
-- {ecosystem: "npm", name: "next", version: "14.0.4", dependencies: {react: "^18.2.0"}}
```

### 2. `frameworks`
**Framework detection patterns and metadata**

```sql
CREATE TABLE frameworks (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL UNIQUE, -- Phoenix, FastAPI, Next.js
  category TEXT, -- web, mobile, desktop, cli
  ecosystem TEXT, -- hex, pypi, npm (primary package manager)

  -- Detection patterns (from JSON templates)
  config_files TEXT[], -- mix.exs, next.config.js
  import_patterns TEXT[], -- "use Phoenix.Controller"
  file_patterns TEXT[], -- lib/**/router.ex

  -- Version support
  supported_versions JSONB, -- ["1.6", "1.7", "1.8"]
  latest_version TEXT, -- 1.8.0

  -- Links
  homepage TEXT,
  documentation_url TEXT,
  repository_id UUID REFERENCES repositories(id),

  -- Search
  embedding VECTOR(1536),

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- Example rows
-- {name: "Phoenix", ecosystem: "hex", config_files: ["mix.exs"], latest_version: "1.8.0"}
-- {name: "FastAPI", ecosystem: "pypi", config_files: ["main.py"], latest_version: "0.110.0"}
```

### 3. `framework_versions`
**Version-specific framework information**

```sql
CREATE TABLE framework_versions (
  id UUID PRIMARY KEY,
  framework_id UUID REFERENCES frameworks(id),
  version TEXT NOT NULL, -- 1.7, 1.8, 0.100
  semver TEXT NOT NULL, -- Full semver: 1.7.14

  -- Version-specific patterns
  features JSONB, -- {verified_routes: true, live_view: "0.20+"}
  breaking_changes JSONB, -- Migration notes from previous version
  deprecated_patterns TEXT[],
  new_patterns TEXT[],

  -- Package dependencies for this version
  package_dependencies JSONB, -- {phoenix_live_view: "~> 0.20"}

  -- Release info
  release_date DATE,
  release_notes_url TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(framework_id, version)
);

-- Example rows
-- {framework_id: <phoenix-uuid>, version: "1.7", features: {verified_routes: true}}
-- {framework_id: <fastapi-uuid>, version: "0.100", features: {pydantic_v2: true}}
```

### 4. `repositories`
**GitHub/GitLab repository metadata**

```sql
CREATE TABLE repositories (
  id UUID PRIMARY KEY,
  url TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL, -- github, gitlab
  owner TEXT NOT NULL,
  name TEXT NOT NULL,

  -- Stats
  stars INT,
  forks INT,
  open_issues INT,

  -- Content
  readme TEXT,
  topics TEXT[],
  languages JSONB, -- {Elixir: 89.2, Rust: 10.8}

  -- Package links (can have multiple packages per repo)
  packages JSONB, -- [{ecosystem: "hex", name: "phoenix"}, ...]

  -- Detected frameworks
  detected_frameworks JSONB, -- [{name: "Phoenix", version: "1.7", confidence: 0.95}]

  -- Search
  embedding VECTOR(1536),

  last_commit_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- Example rows
-- {url: "github.com/phoenixframework/phoenix", packages: [{ecosystem: "hex", name: "phoenix"}]}
-- {url: "github.com/vercel/next.js", packages: [{ecosystem: "npm", name: "next"}]}
```

### 5. `microsnippets`
**Version-aware code snippets (LLM prompt bits)**

```sql
CREATE TABLE microsnippets (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  pattern TEXT NOT NULL, -- authenticated_api_endpoint, websocket, etc.

  -- Framework/version targeting
  framework_id UUID REFERENCES frameworks(id),
  framework_versions TEXT[], -- ["1.7", "1.8"] or ["0.100+"]

  -- Code snippets (JSONB for flexibility)
  snippets JSONB, -- {router: {code: "...", file: "lib/router.ex"}, ...}

  -- LLM context
  llm_context JSONB, -- {key_features: [...], best_practices: [...], common_mistakes: [...]}

  -- Metadata
  category TEXT, -- api_endpoint, websocket, background_job
  tags TEXT[],
  dependencies JSONB, -- Package requirements

  -- Quality
  usage_count INT DEFAULT 0,
  success_rate FLOAT,

  -- Search
  embedding VECTOR(1536),

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- Example rows
-- {name: "Phoenix Authenticated API", framework_id: <phoenix-uuid>, framework_versions: ["1.7", "1.8"]}
-- {name: "FastAPI Authenticated API", framework_id: <fastapi-uuid>, framework_versions: ["0.100+"]}
```

### 6. `package_framework_map`
**Many-to-many: packages ↔ frameworks**

```sql
CREATE TABLE package_framework_map (
  id UUID PRIMARY KEY,
  package_id UUID REFERENCES packages(id),
  framework_id UUID REFERENCES frameworks(id),
  framework_version_id UUID REFERENCES framework_versions(id),

  -- Relationship type
  relationship TEXT, -- core, plugin, extension, peer_dependency
  is_required BOOLEAN DEFAULT true,

  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(package_id, framework_id, framework_version_id)
);

-- Example rows
-- Phoenix 1.7.14 (package) → Phoenix 1.7 (framework version)
-- phoenix_live_view 0.20.0 (package) → Phoenix 1.7 (framework) [plugin]
```

## Cross-Table Queries

### Query 1: "What packages does Phoenix 1.7 need?"

```sql
SELECT p.name, p.version, pfm.relationship
FROM frameworks f
JOIN framework_versions fv ON f.id = fv.framework_id
JOIN package_framework_map pfm ON fv.id = pfm.framework_version_id
JOIN packages p ON pfm.package_id = p.id
WHERE f.name = 'Phoenix' AND fv.version = '1.7'
AND pfm.is_required = true;

-- Returns: ecto ~> 3.11, phoenix_html ~> 3.3, plug ~> 1.14, etc.
```

### Query 2: "What frameworks are in this repository?"

```sql
SELECT f.name, df->>'version' as detected_version, df->>'confidence' as confidence
FROM repositories r,
LATERAL jsonb_array_elements(r.detected_frameworks) df
JOIN frameworks f ON f.name = df->>'name'
WHERE r.url = 'github.com/my-org/my-project';

-- Returns: Phoenix 1.7 (confidence: 0.95), Tailwind CSS (confidence: 0.88)
```

### Query 3: "Give me code snippets for Phoenix 1.7 authenticated API"

```sql
SELECT ms.name, ms.snippets, ms.llm_context
FROM microsnippets ms
JOIN frameworks f ON ms.framework_id = f.id
WHERE f.name = 'Phoenix'
AND '1.7' = ANY(ms.framework_versions)
AND ms.pattern = 'authenticated_api_endpoint';

-- Returns: Full Phoenix 1.7 snippets with router, controller, context, schema
```

### Query 4: "What repositories use FastAPI but don't have a package on PyPI?"

```sql
SELECT r.url, r.stars, df->>'version' as fastapi_version
FROM repositories r,
LATERAL jsonb_array_elements(r.detected_frameworks) df
WHERE df->>'name' = 'FastAPI'
AND NOT EXISTS (
  SELECT 1 FROM packages p
  WHERE p.repository_url = r.url
  AND p.ecosystem = 'pypi'
);

-- Returns: Private/unreleased projects using FastAPI
```

## Version Format Standards

**All versions use semantic versioning: `MAJOR.MINOR.PATCH`**

- **Packages**: Full semver from registry
  - `phoenix 1.7.14`
  - `fastapi 0.110.0`
  - `next 14.0.4`

- **Framework Versions**: Major.Minor grouping
  - `1.7` (groups 1.7.0-1.7.x)
  - `1.8` (groups 1.8.0-1.8.x)
  - `0.100+` (0.100 and above)

- **Version Ranges** (in dependencies):
  - `~> 1.7` (Elixir: >= 1.7.0 and < 1.8.0)
  - `^1.7.0` (npm: >= 1.7.0 and < 2.0.0)
  - `>= 0.100` (Python: 0.100 or higher)

## Services Using This Database

### 1. **analyze_arch_service**
Queries: `frameworks`, `framework_versions`, `repositories`
Returns: Framework detection results

### 2. **prompt_service**
Queries: `microsnippets`, `framework_versions`, `packages`
Returns: LLM context + code snippets

### 3. **package_service**
Queries: `packages`, `package_framework_map`, `repositories`
Returns: Package metadata + dependencies

### 4. **code_gen_service**
Queries: ALL tables (cross-references everything)
Returns: Generated code using version-aware snippets

## Bidirectional Sync: Git ↔ PostgreSQL

**Git → PostgreSQL**
```bash
mix knowledge.migrate  # Import JSON templates → PostgreSQL
```

**PostgreSQL → Git**
```bash
mix knowledge.export   # Export learned patterns → templates_data/learned/
```

**Auto-sync on LLM enrichment:**
When `analyze_arch_service` discovers a new framework via LLM, it:
1. Saves to PostgreSQL (`frameworks`, `framework_versions`, `microsnippets`)
2. Broadcasts via NATS: `architecture.framework.discovered`
3. Exports to Git: `templates_data/learned/frameworks/new-framework.json`
4. Human reviews and promotes to `templates_data/frameworks/`

## Summary

**One database, multiple views:**
- Package registries (npm, cargo, hex, pypi)
- GitHub/GitLab repositories
- Framework detection patterns
- Version-specific code snippets
- Cross-references for intelligent code generation

**All services query the same data, get different responses based on their needs.**
