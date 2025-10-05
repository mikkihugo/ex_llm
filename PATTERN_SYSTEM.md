# Technology & Pattern System (October 2025)

Singularity maintains a single, production-ready pattern system that spans
technology detection, architectural pattern indexing, and microservice
classification. This document replaces the previous collection of draft notes
(`MICROSERVICE_DETECTION.md`, `PATTERN_EXTRACTION_DEMO.md`, `PATTERN_SYSTEM_SUMMARY.md`,
etc.) with an authoritative overview of what actually ships in the repo today.

---

## High-Level Flow

```
   JSON Templates                      Rust Layered Detector               Elixir Runtime
┌────────────────────┐        ┌────────────────────────────────────┐   ┌──────────────────────────────┐
│ rust/tool_doc_index │        │ tool_doc_index/src/detection/      │   │ Singularity.Technology*      │
│ priv/technology_*   │──load→ │ 1-4: static rules (AST, deps)      │──→│  • TechnologyDetector         │
│ code_quality_templates│      │ 5: optional LLM via NATS (llm.analyze)│  • TechnologyTemplateLoader    │
└────────────────────┘        │ emits LayeredDetectionResult        │   │  • FrameworkPatternStore      │
                              └────────────────────────────────────┘   │  • CodeLocationIndex          │
                                                                        │  • PatternIndexer             │
                                                                        └──────────────────────────────┘
```

1. **Templates**: All technology heuristics and semantic patterns live in JSON
   (git-tracked). There are no hard-coded SQL inserts or hand-edited data files.
2. **Rust Layered Detector**: `tool_doc_index` consumes the templates, runs
   layered detection (fast heuristics → AST → LLM fallback) and writes results
   to STDOUT.
3. **Elixir Orchestration**: `Singularity.TechnologyDetector` launches the Rust
   detector, persists normalized snapshots with Ecto, and keeps caches up to
   date for code navigation and code generation.

---

## Template Sources

| Location | Purpose | Notes |
|----------|---------|-------|
| `rust/tool_doc_index/templates/` | Primary technology & framework definitions | Shared across Rust + Elixir |
| `singularity_app/priv/technology_patterns/` | Overrides/local templates | Optional per-deployment overrides |
| `singularity_app/priv/code_quality_templates/` | Semantic patterns for RAG/pattern indexer | Indexed by `PatternIndexer` |
| `singularity_app/priv/patterns/default_patterns.json` | Seed vocabulary for DomainVocabularyTrainer | Loaded at runtime; edit to adjust agent prompt vocabulary |

Each template file follows the schema in `rust/tool_doc_index/templates/schema.json`
(the same schema is mirrored in `TechnologyTemplateLoader` for validation).
Detector signatures are grouped by category (framework, messaging, security,
etc.) and can include regex patterns, config filenames, dependency markers and
optional LLM prompts.

Adding a new technology:
1. Drop a JSON file in `rust/tool_doc_index/templates/<category>/<name>.json`.
2. Run `mix singularity.templates.sync` (coming soon) or restart the app to
   refresh caches.
3. If you need a one-off override, place a file in
   `singularity_app/priv/technology_patterns/` with the same relative path; the
   Elixir loader prefers local overrides over shared templates.

---

## Database Schema (Ecto Migrations)

All pattern-related tables live in the consolidated migrations shipped on
2025-01-01:

1. **`technology_patterns`** – normalized detection hints (file patterns,
   directory patterns, commands, success metrics).
2. **`framework_patterns`** – learned framework profiles with success rate and
   optional embeddings.
3. **`semantic_patterns`** – language-specific semantic snippets used by the
   RAG/pattern indexer.
4. **`code_location_index`** – per-file index combining extracted keywords,
   frameworks, and microservice metadata.
5. **`code_embeddings` / `code_fingerprints`** – vector + hash storage used by
   duplication detection and semantic search.

See `MIGRATION_CONSOLIDATION.md` and `DATABASE_MIGRATIONS_GUIDE.md` for the full
DDL. There are **no** remaining SQL migrations in `rust/db_service/`.

---

## Core Elixir Modules

| Module | Responsibility | Highlights |
|--------|----------------|------------|
| `Singularity.TechnologyDetector` | Orchestrates detection (Rust first, Elixir fallback) | Persists `codebase_snapshots`, flattens results, publishes events |
| `Singularity.TechnologyTemplateLoader` | Loads JSON templates (NATS → DB → filesystem) | Supports overrides, detector signatures, dynamic regex compilation |
| `Singularity.FrameworkPatternStore` | Self-learning framework knowledge | Upserts patterns, tracks success rate, exposes semantic search |
| `Singularity.CodePatternExtractor` | Keyword extraction from code + prose | Shared utility used by detectors, duplication checks, and navigation |
| `Singularity.CodeLocationIndex` | File-level navigation index | Stores patterns, frameworks, microservice classification, metadata |
| `Singularity.PatternIndexer` | Indexes semantic patterns from quality templates | Generates embeddings with `EmbeddingService`, powers RAG codegen |

Additional helpers: `Singularity.TemplateMatcher`, `Singularity.DuplicationDetector`,
`Singularity.EmbeddingService`, and `Singularity.PackageRegistryKnowledge` all
consume the persisted data to drive higher-level automation.

---

## Microservice Detection (Current Logic)

Microservice classification happens inside `CodeLocationIndex.index_file/1`.
The detector combines keyword extraction with simple heuristics:

| Microservice Type | Signals (AND / OR) |
|-------------------|--------------------|
| NATS consumer | `genserver` + (`nats` OR `gnat`) + message handler (`handle_info`, `handle_cast`) |
| HTTP API | `plug` OR `phoenix` + HTTP verbs (`get`, `post`) |
| Broadway pipeline | keyword `broadway` or module usage |
| Phoenix channel | `Phoenix.Channel` + `broadcast/3` or `push/3` |

Example (Elixir NATS consumer):

```elixir
code = """
defmodule MyApp.UserService do
  use GenServer
  def handle_info({:msg, %{topic: "user.create"}}, state), do: {:noreply, state}
end
"""

keywords = Singularity.CodePatternExtractor.extract_from_code(code, :elixir)
# => ["genserver", "handle_info", "nats", "messaging", ...]

Singularity.CodeLocationIndex.index_file("lib/user_service.ex")
# => stores microservice: %{type: "nats_consumer", confidence: 0.92}
```

The full file metadata (imports/exports, summary, lines of code) is persisted so
agents can answer "where is our NATS consumer for X?" without re-scanning the
filesystem.

---

## Query Examples

```elixir
alias Singularity.{CodeLocationIndex, CodePatternExtractor, FrameworkPatternStore,
                   PatternIndexer, TechnologyDetector, TechnologyTemplateLoader}

# 1. Run detection (Rust → Ecto)
{:ok, snapshot} = TechnologyDetector.detect_technologies("/srv/repos/my_app")
IO.inspect(snapshot.detected_technologies)

# 2. Ask for all GenServer microservices
CodeLocationIndex
|> Ecto.Query.where([c], fragment("? @> ARRAY[?]::text[]", c.patterns, "genserver"))
|> Singularity.Repo.all()

# 3. Lookup framework guidance
{:ok, phoenix_pattern} = FrameworkPatternStore.get_pattern("phoenix")

# 4. Semantic pattern search for RAG prompts
{:ok, results} = PatternIndexer.search("cache with ttl", language: "elixir")

# 5. Load detector signatures (regexes) directly
TechnologyTemplateLoader.patterns({:framework, :nextjs})
# => [%Regex{...}, ...]
```

---

## Keeping Data Fresh

| Task | Command |
|------|---------|
| Re-index code navigation after large changes | `mix singularity.index.codebase --path /srv/repos/my_app` (upcoming) |
| Refresh semantic pattern embeddings | `iex> Singularity.PatternIndexer.index_all_templates()` |
| Teach new framework patterns | Call `FrameworkPatternStore.learn_pattern/1` with detection results |
| Verify templates compile | `mix test test/singularity/technology_template_loader_test.exs` |

If you drop new template JSON, run detection or call `TechnologyTemplateLoader.patterns/1`
to warm caches. All modules automatically persist to `technology_patterns` and
related tables; no manual SQL is required.

---

## Frequently Asked

- **Do we still use the old `db_service` NATS pipeline?** No. All writes go
  through `Singularity.Repo` using the consolidated migrations.
- **Where did the duplicated markdown go?** Everything relevant from the older
  docs has been merged into this file. See git history if you need the legacy
  notes.
- **How do I add an LLM-backed detector?** Add `llm.trigger` + `llm.prompts`
  inside the template JSON. The Rust layered detector automatically calls
  `llm.analyze` via NATS when confidence falls below the configured threshold.

---

For deeper implementation details, browse the corresponding modules under
`singuarity_app/lib/singularity/` and the migration sources in
`singularity_app/priv/repo/migrations/20240101000003_create_knowledge_tables.exs`.
