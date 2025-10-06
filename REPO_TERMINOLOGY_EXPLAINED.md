# "Repo" Terminology Explained - Two Different Meanings!

## The Confusion

"Repo" appears throughout the codebase with **TWO completely different meanings**:

## 1. `Repo` = Ecto Database Interface (Capital R)

**What it is**: The database ORM layer (like ActiveRecord in Rails, SQLAlchemy in Python)

```elixir
# File: lib/singularity/repo.ex
defmodule Singularity.Repo do
  @moduledoc """
  Primary Ecto repository for Singularity telemetry, quality signals, and analysis metadata.
  """
  use Ecto.Repo,
    otp_app: :singularity,
    adapter: Ecto.Adapters.Postgres
end
```

**Usage**: All database queries go through `Repo`:

```elixir
alias Singularity.Repo

# Query database
Repo.all(from p in "external_package_registry", where: p.ecosystem == "npm")
Repo.query("SELECT * FROM codebase_chunks WHERE language = $1", ["elixir"])
Repo.insert(%KnowledgeArtifact{...})
```

**Think of it as**: Database connection pool/query interface
**NOT**: A Git repository!

## 2. `repo_name` / `project_name` = Your Git Repository Name (lowercase)

**What it is**: The name of YOUR codebase project (Git repository)

**Examples**:
- `"singularity"` - This project
- `"sparc_fact_system"` - Another project
- `"my-frontend-app"` - Your React app
- `"api-server"` - Your backend API

**Where it appears**:

```elixir
# Database schema (migration shows project_name)
create table(:codebase_chunks) do
  add :project_name, :string, null: false  # <-- Git repo name!
  add :file_path, :string
  add :content, :text
end

# But code often uses repo_name (INCONSISTENT!)
query = """
SELECT file_path, content
FROM codebase_chunks
WHERE repo_name = $1  # <-- Should be project_name?
"""
```

**Usage**: Filtering YOUR code by which Git repository it came from

```elixir
# Get code only from "singularity" repo
Repo.all(
  from c in "codebase_chunks",
  where: c.project_name == "singularity"
)

# Get code from multiple repos
Repo.all(
  from c in "codebase_chunks",
  where: c.project_name in ["singularity", "sparc_fact_system"]
)
```

## The Problem: Inconsistent Naming!

### In Migrations (Table Schema)
```elixir
# migration: 20240101000004_create_code_analysis_tables.exs
create table(:code_files) do
  add :project_name, :string, null: false  # ✅ Uses project_name
end
```

### In Application Code (Queries)
```elixir
# lib/singularity/code/training/code_model_trainer.ex
query = """
SELECT file_path, content, language, repo_name  # ❌ Uses repo_name!
FROM code_files
WHERE repo_name = $1  # ❌ Column doesn't exist!
"""
```

**Result**: Code will fail at runtime! 💥

## Solution: Pick ONE Term and Stick to It

### Option 1: Use `codebase_name` (Recommended)

**Why**: More specific than "project" or "repo"

```elixir
# Migration
create table(:codebase_chunks) do
  add :codebase_name, :string, null: false  # Clear: name of YOUR codebase
  add :file_path, :string
end

# Usage
query = """
SELECT * FROM codebase_chunks
WHERE codebase_name = $1
"""
```

**Benefits**:
- Distinguishes from `Repo` (Ecto database interface)
- Clear: YOUR codebase, not external packages
- Self-documenting: `codebase_name` = "singularity", "my-app", etc.

### Option 2: Use `project_name` (Current Schema)

**Why**: Already in migrations, just fix the queries

```elixir
# Keep migration as-is
create table(:codebase_chunks) do
  add :project_name, :string, null: false  # ✅ Already exists
end

# Fix queries to match
query = """
SELECT * FROM codebase_chunks
WHERE project_name = $1  # ✅ Match schema
"""
```

**Benefits**:
- No migration needed
- Just fix application code

### Option 3: Use `repository_name` (Most Explicit)

**Why**: Full word, no abbreviation confusion

```elixir
create table(:codebase_chunks) do
  add :repository_name, :string, null: false  # Very clear!
end
```

**Benefits**:
- Zero ambiguity
- No confusion with `Repo` module

## Recommended Fix

**Use `codebase_name`** throughout:

1. **Migration**: Rename `project_name` → `codebase_name`
2. **Code**: Change all `repo_name` → `codebase_name`
3. **Consistency**: One term everywhere!

```elixir
# Migration
execute "ALTER TABLE codebase_chunks RENAME COLUMN project_name TO codebase_name"

# Application code
query = """
SELECT file_path, content, language, codebase_name
FROM codebase_chunks
WHERE codebase_name = $1
"""
```

## Summary Table

| Term | Meaning | Type | Example |
|------|---------|------|---------|
| **`Repo`** (capital) | Database interface (Ecto) | Module | `Repo.all(...)` |
| **`repo_name`** (lowercase) | ❌ INCONSISTENT - avoid | Field | `WHERE repo_name = 'singularity'` |
| **`project_name`** (lowercase) | ✅ In schema (but generic) | Field | `WHERE project_name = 'singularity'` |
| **`codebase_name`** (lowercase) | ✅ RECOMMENDED | Field | `WHERE codebase_name = 'singularity'` |
| **`repository_name`** (lowercase) | ✅ Also good (more explicit) | Field | `WHERE repository_name = 'singularity'` |

## Action Items

1. ✅ **Understand**: `Repo` ≠ `repo_name` (completely different!)
2. ⚠️ **Choose**: Pick `codebase_name`, `project_name`, or `repository_name`
3. 🔧 **Migrate**: Rename column if needed
4. 📝 **Update**: Fix all queries to use consistent name
5. ✅ **Document**: Add to CLAUDE.md naming conventions

**Bottom line**: For internal tooling, favor **longer, self-explanatory names**!

Use `codebase_name` - it's clear, unambiguous, and matches the `codebase_chunks` table naming pattern.
