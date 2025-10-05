# JSONB Migration Plan - Extensible Self-Learning System

## Why JSONB?

1. **Flexible schema** - Add new fields without migrations
2. **Query power** - PostgreSQL can index and search JSONB
3. **Self-learning** - Store arbitrary patterns discovered at runtime
4. **Version agnostic** - Different framework versions, different patterns
5. **Fast** - GIN indexes make JSONB queries fast

---

## What Should Be JSONB?

### ✅ Already JSONB (Good!)
- `framework_patterns.file_patterns`
- `framework_patterns.directory_patterns`
- `framework_patterns.config_files`

### 🔄 Should Convert to JSONB

#### 1. **Code Quality Templates**
**Current:** Separate columns
```sql
quality_requirements TEXT,
documentation_rules TEXT,
test_requirements TEXT
```

**Better:** One JSONB column
```sql
quality_rules JSONB DEFAULT '{
  "documentation": {
    "required": true,
    "formats": ["moduledoc", "doc", "spec"]
  },
  "testing": {
    "coverage_target": 0.9,
    "types": ["unit", "integration"]
  },
  "style": {
    "max_function_length": 30,
    "naming": "snake_case"
  }
}'
```

#### 2. **Semantic Patterns**
**Current:** Hard to extend
```sql
pattern_name TEXT,
pseudocode TEXT,
relationships TEXT[]
```

**Better:** Nested JSONB
```sql
pattern JSONB DEFAULT '{
  "name": "GenServer cache",
  "pseudocode": "GenServer → state → get/put",
  "relationships": ["ETS", "TTL", "cleanup"],
  "code_hints": {
    "elixir": "use GenServer, init: ETS.new",
    "rust": "struct + impl with Arc<Mutex>"
  },
  "variations": [
    {"name": "distributed", "hint": "add NATS pub/sub"},
    {"name": "persistent", "hint": "add disk backing"}
  ]
}'
```

#### 3. **Detection Results**
**Current:** Limited structure
```sql
framework_name TEXT,
version TEXT,
confidence FLOAT
```

**Better:** Rich metadata
```sql
detection_result JSONB DEFAULT '{
  "framework": {
    "name": "phoenix",
    "version": "1.7.0",
    "confidence": 0.95
  },
  "evidence": {
    "files": ["mix.exs", "lib/app_web/endpoint.ex"],
    "dependencies": ["phoenix", "phoenix_live_view"],
    "patterns_matched": ["endpoint", "router", "channels"]
  },
  "tech_stack": {
    "language": "elixir",
    "database": "postgresql",
    "frontend": "liveview",
    "deployment": "fly.io"
  },
  "recommendations": [
    {"type": "upgrade", "message": "Phoenix 1.7.10 available"},
    {"type": "pattern", "message": "Consider adding PubSub"}
  ]
}'
```

#### 4. **Tool Knowledge** (from existing migration)
**Current:** Already good!
```sql
CREATE TABLE tool_knowledge (
  tool_name TEXT,
  metadata JSONB  -- ✅ Already JSONB!
)
```

**Enhance:**
```sql
ALTER TABLE tool_knowledge
ADD COLUMN IF NOT EXISTS usage_patterns JSONB DEFAULT '[]',
ADD COLUMN IF NOT EXISTS error_patterns JSONB DEFAULT '[]',
ADD COLUMN IF NOT EXISTS optimization_hints JSONB DEFAULT '{}';
```

#### 5. **Code Fingerprints**
**Current:** Multiple columns
```sql
exact_hash TEXT,
normalized_hash TEXT,
ast_hash TEXT,
keywords TEXT[]
```

**Better:** All in JSONB
```sql
fingerprints JSONB DEFAULT '{
  "hashes": {
    "exact": "sha256_here",
    "normalized": "sha256_here",
    "ast": "sha256_here",
    "semantic": "sha256_here"
  },
  "keywords": ["genserver", "cache", "ttl"],
  "metrics": {
    "length": 1234,
    "lines": 50,
    "complexity": 8,
    "functions": 5
  },
  "language_features": {
    "pattern_matching": true,
    "async": false,
    "macros": ["use", "import"]
  }
}'
```

---

## Migration Strategy

### Phase 1: Add JSONB Columns (No Breaking Changes)
```sql
-- Add JSONB alongside existing columns
ALTER TABLE framework_patterns
ADD COLUMN IF NOT EXISTS extended_metadata JSONB DEFAULT '{}';

ALTER TABLE semantic_patterns
ADD COLUMN IF NOT EXISTS pattern_metadata JSONB DEFAULT '{}';

ALTER TABLE code_fingerprints
ADD COLUMN IF NOT EXISTS fingerprint_data JSONB DEFAULT '{}';
```

### Phase 2: Populate JSONB from Existing Data
```sql
-- Migrate existing data
UPDATE framework_patterns
SET extended_metadata = jsonb_build_object(
  'original_detection', jsonb_build_object(
    'file_patterns', file_patterns,
    'directories', directory_patterns,
    'config_files', config_files
  ),
  'commands', jsonb_build_object(
    'build', build_command,
    'dev', dev_command,
    'install', install_command
  ),
  'learned_at', created_at,
  'success_metrics', jsonb_build_object(
    'detection_count', detection_count,
    'success_rate', success_rate
  )
);
```

### Phase 3: Self-Learning Updates
```elixir
# Elixir code learns and extends JSONB
def learn_new_pattern_field(framework_name, field_path, value) do
  query = """
  UPDATE framework_patterns
  SET
    extended_metadata = jsonb_set(
      extended_metadata,
      $2::text[],
      $3::jsonb,
      true
    ),
    updated_at = NOW()
  WHERE framework_name = $1
  """

  Repo.query(query, [framework_name, field_path, Jason.encode!(value)])
end

# Example: Learn that Phoenix uses LiveView
learn_new_pattern_field("phoenix",
  ["frontend", "patterns"],
  ["liveview", "components", "hooks"]
)
```

---

## JSONB Indexes for Performance

```sql
-- GIN index for containment queries
CREATE INDEX framework_patterns_metadata_gin_idx
  ON framework_patterns USING gin (extended_metadata);

-- Specific path indexes for common queries
CREATE INDEX framework_patterns_tech_stack_idx
  ON framework_patterns USING gin ((extended_metadata -> 'tech_stack'));

-- Expression index for nested fields
CREATE INDEX framework_patterns_language_idx
  ON framework_patterns ((extended_metadata -> 'tech_stack' ->> 'language'));
```

---

## Example Queries

### Find all frameworks with specific tech
```sql
SELECT framework_name, extended_metadata
FROM framework_patterns
WHERE extended_metadata @> '{"tech_stack": {"database": "postgresql"}}'::jsonb;
```

### Search by pattern keywords
```sql
SELECT framework_name, pattern_metadata -> 'keywords' as keywords
FROM semantic_patterns
WHERE pattern_metadata -> 'keywords' @> '["cache"]'::jsonb;
```

### Find frameworks needing upgrade
```sql
SELECT
  framework_name,
  extended_metadata -> 'recommendations' as recommendations
FROM framework_patterns
WHERE extended_metadata -> 'recommendations' @> '[{"type": "upgrade"}]'::jsonb;
```

---

## Self-Learning Example

### Discover New Pattern
```elixir
defmodule Singularity.PatternLearner do
  def learn_from_detection(detection_result) do
    # Extract patterns from detected code
    new_patterns = analyze_code_patterns(detection_result)

    # Store in JSONB for future use
    query = """
    UPDATE framework_patterns
    SET extended_metadata = jsonb_set(
      extended_metadata,
      '{discovered_patterns}',
      COALESCE(extended_metadata -> 'discovered_patterns', '[]'::jsonb) || $2::jsonb,
      true
    )
    WHERE framework_name = $1
    """

    Repo.query(query, [
      detection_result.framework,
      Jason.encode!(new_patterns)
    ])
  end

  defp analyze_code_patterns(detection) do
    # AI/ML analysis of code
    # Returns discovered patterns as map
    %{
      "file_organization" => detection.directory_structure,
      "naming_conventions" => extract_naming_patterns(detection),
      "common_imports" => find_common_imports(detection),
      "architecture_style" => detect_architecture(detection)
    }
  end
end
```

---

## Benefits

### 1. **Extensibility**
```elixir
# No migration needed to add new fields!
FrameworkPatternStore.learn_pattern(%{
  framework_name: "phoenix",
  new_field: "deployment_targets",
  value: ["fly.io", "gigalixir", "heroku"]
})
```

### 2. **Version Flexibility**
```jsonb
{
  "framework": "react",
  "versions": {
    "17": {
      "patterns": ["class components", "lifecycle methods"]
    },
    "18": {
      "patterns": ["hooks", "suspense", "concurrent"]
    }
  }
}
```

### 3. **Rich Context**
```jsonb
{
  "pattern": "API client",
  "implementations": [
    {
      "language": "elixir",
      "approach": "GenServer + HTTPoison",
      "example_repos": ["repo1", "repo2"],
      "quality_score": 0.95
    },
    {
      "language": "rust",
      "approach": "async + reqwest",
      "example_repos": ["repo3"],
      "quality_score": 0.92
    }
  ]
}
```

---

## Recommended Immediate Actions

1. ✅ **Keep** current JSONB fields (file_patterns, etc.)
2. ✅ **Add** `extended_metadata JSONB` to all pattern tables
3. ✅ **Migrate** quality templates to JSONB
4. ✅ **Create** GIN indexes on JSONB columns
5. ✅ **Build** self-learning functions to populate JSONB
6. ✅ **Export** to JSON for Rust (already planned)

**Should I implement the JSONB migration?**
