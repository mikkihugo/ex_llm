# Code Ingestion Guide

## Overview

This guide explains how to ingest your codebase into PostgreSQL for **semantic code search** using:

- **Rust Parser** (NIF) - Fast AST parsing with Tree-sitter
- **Google AI Embeddings** - FREE text-embedding-004 (768 dims, 1500/day)
- **PostgreSQL + pgvector** - Vector database for similarity search

## Architecture

```
┌─────────────────┐
│  Your Codebase  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  ParserEngine   │  ← Rust NIF (Tree-sitter)
│  (Rust NIF)     │
└────────┬────────┘
         │ Parses AST
         ▼
┌─────────────────┐
│  code_files     │  ← Ecto schema
│  (PostgreSQL)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│EmbeddingGenerator│ ← Google AI (FREE)
└────────┬────────┘
         │ Generates 768-dim vectors
         ▼
┌─────────────────┐
│codebase_metadata│  ← Unified search schema
│  (PostgreSQL)   │     50+ metrics per file
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  CodeSearch     │  ← Semantic search API
│  (Pgvector)     │
└─────────────────┘
```

## Quick Start

### 1. Setup Database

```bash
# Option A: Run test script (creates schema if needed)
elixir test_ingestion.exs

# Option B: Manual setup
cd singularity_app
mix ecto.migrate
```

### 2. Ingest Your Codebase

```bash
cd singularity_app

# Ingest current repo (singularity)
mix code.ingest

# Ingest specific repo
mix code.ingest --path /path/to/repo --id my-project

# Skip embeddings (faster, but no semantic search)
mix code.ingest --skip-embeddings

# Filter by languages
mix code.ingest --languages elixir,rust
```

### 3. Search Your Code

```elixir
# In IEx
iex> alias Singularity.{CodeSearch, EmbeddingGenerator, Repo}

# Generate query embedding
iex> {:ok, query_vector} = EmbeddingGenerator.embed("async worker pattern")

# Search
iex> results = CodeSearch.semantic_search(Repo, "singularity", query_vector, 10)

# Print results
iex> Enum.each(results, fn r ->
...>   IO.puts("#{r.path} (#{r.similarity_score})")
...> end)
```

## Database Schema

### `codebase_registry`
Tracks registered codebases.

```sql
CREATE TABLE codebase_registry (
  codebase_id VARCHAR(255) PRIMARY KEY,
  codebase_path VARCHAR(500),
  codebase_name VARCHAR(255),
  description TEXT,
  language VARCHAR(50),
  analysis_status VARCHAR(50),  -- 'pending' | 'analyzing' | 'ready'
  metadata JSONB,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### `code_files`
Raw parsed files (from ParserEngine).

```sql
CREATE TABLE code_files (
  id UUID PRIMARY KEY,
  codebase_id VARCHAR(255),
  file_path VARCHAR(500),
  language VARCHAR(50),
  content TEXT,
  ast_json JSONB,              -- Raw AST from Tree-sitter
  functions JSONB,             -- Extracted functions
  classes JSONB,               -- Extracted classes
  imports JSONB,               -- Import statements
  exports JSONB,               -- Export statements
  symbols JSONB,               -- All symbols
  metadata JSONB,
  parsed_at TIMESTAMP,
  UNIQUE(codebase_id, file_path)
);
```

### `codebase_metadata`
Unified schema with 50+ metrics + embeddings.

```sql
CREATE TABLE codebase_metadata (
  id SERIAL PRIMARY KEY,
  codebase_id VARCHAR(255),
  path VARCHAR(500),

  -- Basic metrics
  size BIGINT,
  lines INTEGER,
  language VARCHAR(50),

  -- Complexity metrics
  cyclomatic_complexity FLOAT,
  cognitive_complexity FLOAT,
  maintainability_index FLOAT,

  -- Code metrics
  function_count INTEGER,
  class_count INTEGER,

  -- Line metrics
  code_lines INTEGER,
  comment_lines INTEGER,
  blank_lines INTEGER,

  -- Halstead metrics
  halstead_volume FLOAT,
  halstead_difficulty FLOAT,

  -- Quality metrics
  quality_score FLOAT,
  test_coverage FLOAT,

  -- Semantic features (JSONB)
  domains JSONB,
  patterns JSONB,
  functions JSONB,
  classes JSONB,
  imports JSONB,
  exports JSONB,

  -- Vector embedding (768 dims)
  vector_embedding VECTOR(768),

  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  UNIQUE(codebase_id, path)
);

CREATE INDEX idx_codebase_metadata_vector
ON codebase_metadata USING ivfflat (vector_embedding vector_cosine_ops);
```

## API Reference

### ParserEngine

Parse files and store in `code_files` table.

```elixir
# Parse single file
{:ok, %{document: doc, record: record}} =
  ParserEngine.parse_and_store_file("/path/to/file.ex", codebase_id: "my-project")

# Parse entire tree
{:ok, results} =
  ParserEngine.parse_and_store_tree(
    "/path/to/repo",
    codebase_id: "my-project",
    max_concurrency: 8
  )

# Just parse (no DB storage)
{:ok, document} = ParserEngine.parse_file("/path/to/file.ex")
# => %{path: ..., language: ..., ast: ..., functions: [...], classes: [...]}
```

### EmbeddingGenerator

Generate embeddings using Google AI (FREE, 1500/day).

```elixir
# Single embedding
{:ok, embedding} = EmbeddingGenerator.embed("async worker pattern")
# => %Pgvector{} (768 dimensions)
```

### CodeSearch

Semantic search across codebases.

```elixir
# Create schema
{:ok, conn} = Postgrex.start_link(...)
CodeSearch.create_unified_schema(conn)

# Register codebase
CodeSearch.register_codebase(
  conn,
  "my-project",
  "/path/to/repo",
  "My Project",
  description: "Example codebase",
  language: "elixir"
)

# Insert file metadata (from Rust analysis)
CodeSearch.insert_codebase_metadata(conn, "my-project", "/path/to/repo", metadata)

# Semantic search
results = CodeSearch.semantic_search(Repo, "my-project", query_vector, 10)

# Multi-codebase search
results = CodeSearch.multi_codebase_search(
  conn,
  ["singularity", "my-project"],
  query_vector,
  20
)
```

## Performance

### Parsing
- **Rust NIF**: ~5000 files/minute
- **Tree-sitter**: Full AST with 50+ metrics
- **Concurrent**: 8 threads by default

### Embeddings
- **Google AI**: ~100 embeddings/minute
- **FREE tier**: 1500 requests/day
- **Dimensions**: 768 (good quality)

### Search
- **IVFFlat index**: <100ms for 10k files
- **Cosine similarity**: Optimized with pgvector
- **Connection pooling**: Ecto.Repo

## Workflow Examples

### Example 1: Ingest and Search

```bash
# 1. Ingest
cd singularity_app
mix code.ingest --path ~/code/my-project --id my-project

# 2. Search in IEx
iex -S mix
```

```elixir
alias Singularity.{CodeSearch, EmbeddingGenerator, Repo}

# Search for async patterns
{:ok, query} = EmbeddingGenerator.embed("async worker with error handling")
results = CodeSearch.semantic_search(Repo, "my-project", query, 10)

# Print results
Enum.each(results, fn r ->
  IO.puts("\n#{r.path}")
  IO.puts("  Language: #{r.language}")
  IO.puts("  Quality: #{r.quality_score}")
  IO.puts("  Similarity: #{Float.round(r.similarity_score * 100, 2)}%")
end)
```

### Example 2: Incremental Updates

```elixir
# Parse new/modified files only
files_to_update = [
  "/path/to/modified_file1.ex",
  "/path/to/modified_file2.ex"
]

results = ParserEngine.parse_files(files_to_update)

# Generate embeddings for new files
Enum.each(files_to_update, fn file ->
  {:ok, content} = File.read(file)
  {:ok, embedding} = EmbeddingGenerator.embed(content)

  # Update in database...
end)
```

### Example 3: Compare Codebases

```elixir
# Ingest two repos
mix code.ingest --path ~/old-app --id old-app
mix code.ingest --path ~/new-app --id new-app

# Search across both
{:ok, query} = EmbeddingGenerator.embed("authentication logic")
results = CodeSearch.multi_codebase_search(
  conn,
  ["old-app", "new-app"],
  query,
  20
)

# Group by codebase
results
|> Enum.group_by(& &1.codebase_id)
|> Enum.each(fn {codebase, files} ->
  IO.puts("\n#{codebase}:")
  Enum.each(files, fn f -> IO.puts("  - #{f.path}") end)
end)
```

## Troubleshooting

### Error: `codebase_metadata` table not found

```bash
# Run test script to create schema
elixir test_ingestion.exs

# Or manually
cd singularity_app
iex -S mix
```

```elixir
{:ok, conn} = Postgrex.start_link(
  hostname: "localhost",
  database: "singularity",
  username: "postgres"
)

Singularity.CodeSearch.create_unified_schema(conn)
```

### Error: Rust NIF not loaded

The parser uses Rust NIF which needs to be compiled:

```bash
cd rust/parser/polyglot
cargo build --release

# Copy .so to priv/native/
mkdir -p ../../../singularity_app/priv/native
cp target/release/libparser_engine.so ../../../singularity_app/priv/native/
```

### Error: Google AI rate limit exceeded

Free tier: 1500 requests/day.

**Solutions:**
1. Skip embeddings initially: `mix code.ingest --skip-embeddings`
2. Generate embeddings in batches over multiple days
3. Use local embeddings (slower): EmbeddingEngine Rust NIF

### Slow ingestion

**Optimize:**
- Use `--languages` to filter: `mix code.ingest --languages elixir,rust`
- Skip embeddings first: `--skip-embeddings`
- Increase concurrency in code (default: 8 threads)

## Next Steps

### 1. Build Search UI
```elixir
defmodule MyAppWeb.CodeSearchLive do
  use Phoenix.LiveView

  def handle_event("search", %{"query" => query}, socket) do
    {:ok, embedding} = EmbeddingGenerator.embed(query)
    results = CodeSearch.semantic_search(Repo, "my-project", embedding, 20)
    {:noreply, assign(socket, results: results)}
  end
end
```

### 2. Auto-update on Git commits
```bash
#!/bin/bash
# .git/hooks/post-commit

cd singularity_app
mix code.ingest --id my-project
```

### 3. Graph-based search
```elixir
# Find dependencies
CodeSearch.get_dependencies(conn, node_id)

# Find circular dependencies
CodeSearch.detect_circular_dependencies(conn)

# PageRank scores
CodeSearch.calculate_pagerank(conn)
```

## References

- [ParserEngine](singularity_app/lib/singularity/parser_engine.ex)
- [CodeSearch](singularity_app/lib/singularity/search/code_search.ex)
- [EmbeddingGenerator](singularity_app/lib/singularity/llm/embedding_generator.ex)
- [Mix Task](singularity_app/lib/mix/tasks/code.ingest.ex)
- [Test Script](test_ingestion.exs)
