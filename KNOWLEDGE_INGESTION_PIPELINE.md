# Knowledge Ingestion Pipeline - Unified External Source Processing

**Goal:** One pipeline to ingest, analyze, and extract knowledge from ALL external sources.

## Architecture

```
External Sources
    ↓
Collectors (fetch raw data)
    ↓
Analyzers (LLM-powered analysis)
    ↓
Extractors (generate artifacts)
    ↓
PostgreSQL (unified storage)
    ↓
Search (semantic + structured)
```

## External Sources

### 1. Code Repositories

#### GitHub
**What:** Open source repositories
**APIs:**
- GraphQL API (metadata, file contents)
- REST API (releases, commits)
- Git clone (full source)

**Extract:**
- Code examples from `/examples/`, `/docs/`, `/guides/`
- Framework patterns from `/src/`
- Best practices from `/README.md`
- Architecture explanations from code structure
- Version-specific patterns from releases

**Storage:**
- `repositories` table - Metadata
- `microsnippets` table - Code examples
- `framework_versions` table - Detected patterns
- `knowledge_artifacts` table - Learnings

#### GitLab
**What:** Self-hosted + GitLab.com repos
**APIs:**
- GraphQL API
- REST API
- Git clone

**Extract:**
- Same as GitHub
- CI/CD patterns from `.gitlab-ci.yml`

#### Bitbucket
**What:** Atlassian repositories
**APIs:**
- REST API
- Git clone

**Extract:**
- Same as GitHub
- Jira integration patterns

#### Gitea/Forgejo
**What:** Self-hosted git services
**APIs:**
- REST API
- Git clone

**Extract:**
- Internal company patterns
- Enterprise examples

### 2. Package Registries

#### npm
**What:** JavaScript/TypeScript packages
**API:** npm registry API

**Extract:**
- Package metadata (downloads, versions)
- Dependencies
- README examples
- TypeScript types
- Package source code analysis

#### cargo/crates.io
**What:** Rust crates
**API:** crates.io API

**Extract:**
- Crate metadata
- Dependencies
- Examples from `/examples/`
- docs.rs documentation
- Source code patterns

#### hex.pm
**What:** Elixir/Erlang packages
**API:** Hex API

**Extract:**
- Package metadata
- ExDoc documentation
- Code examples
- Mix patterns

#### PyPI
**What:** Python packages
**API:** PyPI JSON API

**Extract:**
- Package metadata
- Dependencies
- README/docs
- Type hints
- Common patterns

#### RubyGems
**What:** Ruby gems
**API:** RubyGems API

**Extract:**
- Gem metadata
- YARD documentation
- Examples

#### Maven Central
**What:** Java/Kotlin/Scala libraries
**API:** Maven Central API

**Extract:**
- Artifact metadata
- Javadoc
- Examples

#### NuGet
**What:** .NET packages
**API:** NuGet API

**Extract:**
- Package metadata
- XML docs
- Examples

### 3. Security Databases

#### GitHub Advisory Database
**What:** CVE vulnerabilities across ecosystems
**API:** GraphQL API

**Extract:**
- CVE IDs
- Affected packages/versions
- Severity scores
- Patches/fixes
- Vulnerable code patterns (to avoid)

**Storage:**
- `security_advisories` table
- Link to `packages` and `framework_versions`

#### NVD (National Vulnerability Database)
**What:** Official CVE database
**API:** NVD API

**Extract:**
- CVE details
- CWE categories
- CVSS scores
- References

#### OSV (Open Source Vulnerabilities)
**What:** Unified vulnerability database
**API:** OSV API

**Extract:**
- Cross-ecosystem vulnerabilities
- Affected version ranges
- Fix commits

#### RustSec
**What:** Rust-specific security advisories
**Source:** GitHub repo

**Extract:**
- Rust crate vulnerabilities
- Unmaintained crates
- Soundness issues

#### npm Audit
**What:** npm package vulnerabilities
**API:** npm audit API

**Extract:**
- npm-specific vulns
- Dependency trees
- Fix recommendations

#### Snyk Database
**What:** Commercial vuln database (if accessible)
**API:** Snyk API

**Extract:**
- Detailed vulnerability info
- Exploit maturity
- Fix PRs

### 4. Documentation Sites

#### docs.rs
**What:** Rust crate documentation
**Scraping:** HTML + search

**Extract:**
- API documentation
- Code examples
- Version-specific docs

#### hexdocs.pm
**What:** Elixir/Erlang docs
**Scraping:** HTML

**Extract:**
- ExDoc pages
- Guides
- Examples

#### Read the Docs
**What:** Python project docs
**API:** readthedocs.org API

**Extract:**
- Sphinx documentation
- Tutorials
- API references

#### DevDocs
**What:** Unified API documentation
**Scraping:** devdocs.io

**Extract:**
- Multi-language API docs
- Quick references

### 5. Learning Platforms

#### Stack Overflow
**What:** Q&A with code examples
**API:** Stack Exchange API

**Extract:**
- High-voted answers
- Code snippets
- Common problems/solutions
- Anti-patterns (from questions)

**Storage:**
- `knowledge_artifacts` (type: qa_example)
- Link to frameworks/packages

#### GitHub Discussions
**What:** Community Q&A
**API:** GraphQL

**Extract:**
- Best practices discussions
- Migration guides
- Performance tips

#### Reddit (r/rust, r/elixir, etc.)
**What:** Community knowledge
**API:** Reddit API

**Extract:**
- Community consensus
- Real-world experiences
- Tool recommendations

### 6. Official Docs & Guides

#### MDN (Mozilla Developer Network)
**What:** Web platform docs
**Scraping:** HTML

**Extract:**
- JavaScript/CSS/HTML references
- Browser APIs
- Best practices

#### Microsoft Docs
**What:** .NET, TypeScript, Azure docs
**API/Scraping:** docs.microsoft.com

**Extract:**
- Language references
- Framework guides
- Examples

#### Official Framework Sites
**Sources:**
- react.dev
- nextjs.org
- phoenix-framework.org
- fastapi.tiangolo.com

**Extract:**
- Official guides
- Migration docs
- Version differences
- Best practices

### 7. Package Metadata Services

#### Libraries.io
**What:** Cross-ecosystem package search
**API:** Libraries.io API

**Extract:**
- Package popularity
- Dependency graphs
- Alternatives/equivalents
- Unmaintained projects

#### pkg.go.dev
**What:** Go package docs
**Scraping:** HTML

**Extract:**
- Go module docs
- Examples
- Version history

### 8. Code Search Engines

#### GitHub Code Search
**What:** Search across all GitHub code
**API:** GitHub Search API

**Extract:**
- Real-world usage patterns
- Common implementations
- Framework adoption

#### Sourcegraph
**What:** Universal code search
**API:** Sourcegraph API (if accessible)

**Extract:**
- Cross-repo patterns
- API usage examples

## Unified Ingestion Pipeline

### Stage 1: Collection (Fetch)

```rust
// Collector trait (already exists)
trait SourceCollector {
  fn source_type(&self) -> SourceType;  // GitHub, npm, CVE, etc.
  async fn collect(&self, identifier: &str) -> Result<RawData>;
}

// Examples
GitHubCollector.collect("facebook/react")
NpmCollector.collect("react@18.2.0")
CVECollector.collect("CVE-2024-1234")
```

### Stage 2: Analysis (LLM)

```rust
struct KnowledgeAnalyzer {
  llm_client: LLMClient,
}

impl KnowledgeAnalyzer {
  async fn analyze(&self, raw_data: RawData) -> Result<AnalysisResult> {
    // LLM prompts based on source type
    match raw_data.source_type {
      SourceType::GitHubRepo => self.analyze_repo(raw_data),
      SourceType::Package => self.analyze_package(raw_data),
      SourceType::CVE => self.analyze_vulnerability(raw_data),
      SourceType::Documentation => self.analyze_docs(raw_data),
    }
  }

  async fn analyze_repo(&self, repo: GitHubRepo) -> Result<RepoAnalysis> {
    // Prompt: "Analyze this repo, extract patterns, generate snippets"
    // Returns: frameworks detected, code examples, architecture notes
  }

  async fn analyze_vulnerability(&self, cve: CVEData) -> Result<VulnAnalysis> {
    // Prompt: "Explain vulnerability, extract vulnerable patterns, find fixes"
    // Returns: explanation, code patterns to avoid, fixes
  }
}
```

### Stage 3: Extraction (Artifact Generation)

```rust
struct KnowledgeExtractor;

impl KnowledgeExtractor {
  fn extract(&self, analysis: AnalysisResult) -> Vec<KnowledgeArtifact> {
    vec![
      // Code snippets
      KnowledgeArtifact {
        type: ArtifactType::Microsnippet,
        framework: "React",
        version: "18",
        content: "const [state, setState] = useState(0);",
        source: "github.com/facebook/react/examples/...",
        quality_score: 0.95,
      },

      // Framework patterns
      KnowledgeArtifact {
        type: ArtifactType::FrameworkPattern,
        framework: "Phoenix",
        version: "1.7",
        content: "verified_routes: ~p\"/users/#{user}\"",
        source: "github.com/phoenixframework/phoenix",
        quality_score: 1.0,
      },

      // Vulnerabilities
      KnowledgeArtifact {
        type: ArtifactType::SecurityPattern,
        framework: "React",
        version: "16.13.0",
        content: "Avoid: dangerouslySetInnerHTML without sanitization",
        source: "CVE-2024-1234",
        quality_score: 0.98,
      },

      // Best practices
      KnowledgeArtifact {
        type: ArtifactType::BestPractice,
        framework: "FastAPI",
        content: "Use Pydantic v2 for validation in FastAPI 0.100+",
        source: "github.com/tiangolo/fastapi/docs",
        quality_score: 0.92,
      },
    ]
  }
}
```

### Stage 4: Storage (PostgreSQL)

```sql
-- Unified artifacts table
CREATE TABLE knowledge_artifacts (
  id UUID PRIMARY KEY,
  artifact_type TEXT NOT NULL, -- microsnippet, pattern, vulnerability, best_practice
  source_type TEXT NOT NULL,   -- github, npm, cve, docs
  source_url TEXT,

  -- Content
  content_raw TEXT,            -- Original
  content JSONB,               -- Parsed
  embedding VECTOR(1536),      -- Semantic search

  -- Metadata
  framework TEXT,
  framework_version TEXT,
  language TEXT,
  ecosystem TEXT,

  -- Quality
  quality_score FLOAT,
  confidence FLOAT,
  priority INT,                -- GitHub=100, Package=80, Registry=50, LLM=20

  -- Security
  is_vulnerable BOOLEAN,
  cve_ids TEXT[],
  severity TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  source_updated_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX idx_artifacts_type ON knowledge_artifacts(artifact_type);
CREATE INDEX idx_artifacts_framework ON knowledge_artifacts(framework, framework_version);
CREATE INDEX idx_artifacts_source ON knowledge_artifacts(source_type);
CREATE INDEX idx_artifacts_quality ON knowledge_artifacts(quality_score DESC);
CREATE INDEX idx_artifacts_embedding ON knowledge_artifacts USING ivfflat(embedding);
```

### Stage 5: Search (Query)

```elixir
# User searches "react hooks"
Search.query("react hooks")
  ↓
# Query knowledge_artifacts with semantic search
SELECT * FROM knowledge_artifacts
WHERE embedding <=> $embedding
  AND framework = 'React'
  AND artifact_type IN ('microsnippet', 'best_practice')
ORDER BY
  quality_score DESC,
  priority DESC,
  similarity DESC
LIMIT 10
```

## LLM Analysis Prompts

### For GitHub Repos

```
Analyze this GitHub repository: {repo_url}

Context:
- Language: {primary_language}
- Stars: {stars}
- Topics: {topics}

Files provided:
{file_tree}

Your task:
1. Identify frameworks and versions used
2. Extract code examples from /examples/, /docs/, /guides/
3. Find best practices from well-written code
4. Detect patterns (architecture, testing, error handling)
5. Generate microsnippets for common use cases

Output JSON:
{
  "frameworks": [{"name": "...", "version": "...", "confidence": 0.95}],
  "microsnippets": [{...}],
  "best_practices": [{...}],
  "architecture_patterns": [{...}]
}
```

### For CVEs

```
Analyze this vulnerability: {cve_id}

CVE Data:
{cve_json}

Affected package: {package}
Versions: {affected_versions}

Your task:
1. Explain the vulnerability in simple terms
2. Extract vulnerable code patterns
3. Provide fixed code patterns
4. Recommend safe alternatives

Output JSON:
{
  "explanation": "...",
  "vulnerable_patterns": [{code: "...", why_bad: "..."}],
  "fixed_patterns": [{code: "...", why_good: "..."}],
  "recommendations": [...]
}
```

### For Package Source Code

```
Analyze this package: {package_name}@{version}

Source code:
{source_files}

README:
{readme}

Your task:
1. Extract usage examples
2. Find common patterns
3. Identify best practices
4. Detect anti-patterns from issues/tests

Output JSON:
{
  "examples": [{...}],
  "patterns": [{...}],
  "best_practices": [{...}],
  "anti_patterns": [{...}]
}
```

## Ingestion Strategies

### Continuous (Background)

**Sources:** CVE databases, popular packages
**Schedule:** Daily/weekly
**Process:**
1. Fetch new CVEs
2. Fetch updated packages (with high download counts)
3. Analyze changes
4. Update knowledge base

### On-Demand (User-Triggered)

**Sources:** Specific repos, packages user is interested in
**Trigger:** User request or first search
**Process:**
1. User searches "fastapi authentication"
2. If no good results, trigger ingestion:
   - Fetch FastAPI repo
   - Analyze authentication examples
   - Extract snippets
   - Return results

### Bulk (One-Time)

**Sources:** Top N packages/repos in each ecosystem
**Run:** Initial setup
**Process:**
1. Identify top 1000 npm packages
2. Identify top 500 cargo crates
3. Identify top 100 hex packages
4. Fetch + analyze + extract
5. Populate knowledge base

## Implementation

### Service: `knowledge_ingestion_service`

```rust
// rust/service/knowledge_ingestion_service/

struct IngestionPipeline {
  collectors: Vec<Box<dyn SourceCollector>>,
  analyzer: KnowledgeAnalyzer,
  extractor: KnowledgeExtractor,
  storage: PostgresStorage,
}

impl IngestionPipeline {
  async fn ingest(&self, source: Source) -> Result<IngestResult> {
    // 1. Collect
    let raw_data = self.collectors
      .find(source.type)
      .collect(source.identifier)
      .await?;

    // 2. Analyze (LLM)
    let analysis = self.analyzer
      .analyze(raw_data)
      .await?;

    // 3. Extract
    let artifacts = self.extractor
      .extract(analysis);

    // 4. Store
    self.storage
      .save_artifacts(artifacts)
      .await?;

    // 5. Broadcast
    self.nats.publish("knowledge.artifact.discovered", artifacts);

    Ok(IngestResult { artifacts_created: artifacts.len() })
  }
}
```

### NATS Subjects

```
knowledge.ingest.github.{owner}/{repo}
knowledge.ingest.npm.{package}@{version}
knowledge.ingest.cve.{cve_id}
knowledge.ingest.docs.{url_hash}

knowledge.artifact.discovered  # Broadcast when new artifacts created
knowledge.update.framework     # Framework pattern updated
knowledge.update.vulnerability # New CVE affecting packages
```

## Benefits

**Unified Pipeline:**
- ✅ One system for ALL external sources
- ✅ Consistent quality scoring
- ✅ LLM-powered analysis
- ✅ Single storage schema
- ✅ Automatic learning

**Knowledge Growth:**
- 🔄 Continuous ingestion from CVEs
- 🔄 On-demand from repos/packages
- 🔄 LLM discovers patterns
- 🔄 Auto-exports to templates_data/

**Search Improvement:**
- 🎯 Rich, curated knowledge base
- 🎯 Version-specific examples
- 🎯 Security-aware (avoids vulnerable patterns)
- 🎯 Real-world validated (from popular repos)

## Next Steps

1. **Create `knowledge_ingestion_service`**
2. **Add GitLab collector** (similar to GitHub)
3. **Add CVE collectors** (NVD, OSV, RustSec)
4. **Implement LLM analysis prompts**
5. **Schedule background ingestion**
6. **Add on-demand triggers from search**

**One pipeline to rule them all!** 🚀
