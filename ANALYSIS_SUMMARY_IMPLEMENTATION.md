# Analysis Summary Persistence Implementation

## Overview

This implementation adds complete database persistence for `Analysis.Summary` with automatic storage during codebase analysis and refactoring detection integration.

## Components Implemented

### 1. Database Schema (`Analysis.Summary`)

**File**: `/home/mhugo/code/singularity/singularity_app/lib/singularity/analysis/summary.ex`

Added Ecto schema with:
- Primary key: UUID (`binary_id`)
- Fields:
  - `codebase_id` (string, indexed) - Identifies the codebase
  - `analysis_data` (JSONB) - Full analysis including file reports
  - `analyzed_at` (datetime, indexed) - Timestamp of analysis
  - `total_files`, `total_lines`, `total_functions`, `total_classes` (integers) - Aggregate counts
  - `quality_score`, `technical_debt_ratio` (floats) - Quality metrics
  - `average_complexity`, `average_maintainability` (floats) - Code health metrics
  - `languages` (JSONB) - Language distribution map
  - Virtual field `files` - In-memory representation of file reports

### 2. Migration

**File**: `/home/mhugo/code/singularity/singularity_app/priv/repo/migrations/20240101000007_create_analysis_summaries.exs`

Creates `analysis_summaries` table with:
- Indexes on:
  - `(codebase_id, analyzed_at)` - Time-series queries
  - `analyzed_at` - Chronological queries
  - `codebase_id` - Per-codebase queries
  - `quality_score`, `technical_debt_ratio` - Quality-based queries
- Unique constraint: `(codebase_id, analyzed_at)` - Prevents duplicate analyses

### 3. Persistence Functions

#### `Summary.store/2`
```elixir
Summary.store(summary, codebase_id: "my-project")
# => {:ok, %Summary{}} | {:error, changeset}
```
Stores analysis summary with automatic calculation of aggregate metrics.

#### `Summary.fetch_latest/1`
```elixir
Summary.fetch_latest(codebase_id: "my-project")
# => %Summary{} | nil
```
Fetches most recent analysis for a codebase. Automatically hydrates file reports from JSONB.

#### `Summary.fetch_history/1`
```elixir
Summary.fetch_history(codebase_id: "my-project", limit: 10, offset: 0)
# => [%Summary{}, ...]
```
Fetches analysis history with pagination support.

#### `Summary.cleanup_old/1`
```elixir
Summary.cleanup_old(days_to_keep: 30, codebase_id: "my-project")
# => {count, nil}
```
Implements retention policy - deletes analyses older than N days.

#### `Summary.get_stats/1`
```elixir
Summary.get_stats(codebase_id: "my-project")
# => %{total_analyses: 15, avg_quality_score: 78.5, ...}
```
Returns aggregate statistics across all stored analyses.

### 4. Automatic Storage Integration

**File**: `/home/mhugo/code/singularity/singularity_app/lib/singularity/code/parsers/polyglot_code_parser.ex`

Added `store_analysis_summary/2` to automatically persist analysis results when codebase analysis completes:

```elixir
def handle_call({:analyze_codebase, codebase_path, opts}, _from, state) do
  codebase_result = run_codebase_analysis(codebase_path, state.rust_parser, opts)
  store_codebase_analysis(codebase_result, state.db_conn)

  # NEW: Automatic storage for refactoring detection
  store_analysis_summary(codebase_result, opts)

  {:reply, {:ok, codebase_result}, state}
end
```

Helper functions:
- `convert_file_results_to_files_map/1` - Converts parser results to FileReport structs
- `convert_result_to_metadata/1` - Maps parser metrics to Metadata struct
- `calculate_quality_score/1` - Computes quality score from maintainability/complexity
- `generate_content_hash/1` - Creates hash for change detection
- `count_total_functions/1`, `count_total_classes/1` - Aggregate counters
- `build_language_map/1` - Builds language distribution

### 5. Refactoring Analyzer Integration

**File**: `/home/mhugo/code/singularity/singularity_app/lib/singularity/code/quality/refactoring_analyzer.ex`

Updated to use new persistence API:

```elixir
# OLD: Analysis.Summary.fetch_latest()  # MISSING FUNCTION
# NEW:
def analyze_refactoring_need(opts \\ []) do
  codebase_id = Keyword.get(opts, :codebase_id, "default")

  case Analysis.Summary.fetch_latest(codebase_id: codebase_id) do
    nil -> []
    analysis -> detect_refactoring_needs(analysis)
  end
end
```

## Data Flow

### Analysis Storage Flow

```
1. PolyglotCodeParser.analyze_codebase(path, opts)
   ↓
2. run_codebase_analysis() - Rust parser execution
   ↓
3. store_codebase_analysis() - Store in universal_analysis_results
   ↓
4. store_analysis_summary() - NEW: Store in analysis_summaries
   ↓
5. Summary.store() - Ecto persistence
```

### Refactoring Detection Flow

```
1. Refactoring.Analyzer.analyze_refactoring_need(codebase_id: "foo")
   ↓
2. Summary.fetch_latest(codebase_id: "foo")
   ↓
3. Hydrate files from JSONB (analysis_data)
   ↓
4. Run detection functions (duplication, technical debt, etc.)
   ↓
5. Return refactoring triggers
```

## Database Schema

```sql
CREATE TABLE analysis_summaries (
  id UUID PRIMARY KEY,
  codebase_id VARCHAR NOT NULL,
  analysis_data JSONB NOT NULL DEFAULT '{}',
  analyzed_at TIMESTAMP NOT NULL,

  -- Aggregate metrics
  total_files INTEGER DEFAULT 0,
  total_lines INTEGER DEFAULT 0,
  total_functions INTEGER DEFAULT 0,
  total_classes INTEGER DEFAULT 0,

  -- Quality metrics
  quality_score FLOAT DEFAULT 0.0,
  technical_debt_ratio FLOAT DEFAULT 0.0,
  average_complexity FLOAT DEFAULT 0.0,
  average_maintainability FLOAT DEFAULT 0.0,

  -- Language distribution
  languages JSONB DEFAULT '{}',

  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,

  UNIQUE (codebase_id, analyzed_at)
);

-- Indexes
CREATE INDEX idx_analysis_summaries_codebase_analyzed
  ON analysis_summaries(codebase_id, analyzed_at);

CREATE INDEX idx_analysis_summaries_analyzed
  ON analysis_summaries(analyzed_at);

CREATE INDEX idx_analysis_summaries_codebase
  ON analysis_summaries(codebase_id);

CREATE INDEX idx_analysis_summaries_quality
  ON analysis_summaries(quality_score);

CREATE INDEX idx_analysis_summaries_debt
  ON analysis_summaries(technical_debt_ratio);
```

## Usage Examples

### Store Analysis Results

```elixir
# From Rust parser output
analysis_data = %{
  total_files: 150,
  total_lines: 25000,
  files: %{
    "lib/my_module.ex" => %{
      path: "lib/my_module.ex",
      metadata: %{
        cyclomatic_complexity: 8.5,
        quality_score: 85.0,
        # ... other metrics
      }
    }
  },
  languages: %{"elixir" => 100, "rust" => 50}
}

{:ok, summary} = Analysis.Summary.store(
  analysis_data,
  codebase_id: "singularity"
)
```

### Query Latest Analysis

```elixir
# Get latest analysis
summary = Analysis.Summary.fetch_latest(codebase_id: "singularity")

# Access data
summary.total_files        # => 150
summary.quality_score      # => 82.5
summary.technical_debt_ratio  # => 0.15
summary.files["lib/my_module.ex"].metadata.cyclomatic_complexity  # => 8.5
```

### Track Analysis History

```elixir
# Get last 30 days of analyses
history = Analysis.Summary.fetch_history(
  codebase_id: "singularity",
  limit: 30
)

# Plot quality trend
quality_trend = Enum.map(history, fn s ->
  {s.analyzed_at, s.quality_score}
end)
```

### Cleanup Old Data

```elixir
# Delete analyses older than 90 days
{deleted_count, _} = Analysis.Summary.cleanup_old(
  days_to_keep: 90,
  codebase_id: "singularity"
)

Logger.info("Cleaned up #{deleted_count} old analyses")
```

### Get Analysis Statistics

```elixir
stats = Analysis.Summary.get_stats(codebase_id: "singularity")

# => %{
#   total_analyses: 47,
#   first_analysis: ~U[2024-01-15 10:30:00Z],
#   last_analysis: ~U[2024-10-05 15:45:00Z],
#   avg_quality_score: 78.5,
#   avg_technical_debt: 0.18,
#   avg_complexity: 9.2,
#   avg_maintainability: 72.3
# }
```

### Trigger Refactoring Analysis

```elixir
# Analyze refactoring needs for current codebase
triggers = Singularity.Refactoring.Analyzer.analyze_refactoring_need(
  codebase_id: "singularity"
)

# => [
#   %{
#     type: :code_duplication,
#     severity: :high,
#     affected_files: [...],
#     suggested_goal: "Extract 15 duplicated patterns...",
#     business_impact: "Reduces maintenance burden",
#     estimated_hours: 7.5
#   }
# ]
```

## Testing

### Run Migration

```bash
cd singularity_app
mix ecto.migrate
```

### Verify Schema

```elixir
# In IEx
iex> Singularity.Analysis.Summary.__schema__(:fields)
[:id, :codebase_id, :analysis_data, :analyzed_at, :total_files,
 :total_lines, :total_functions, :total_classes, :quality_score,
 :technical_debt_ratio, :average_complexity, :average_maintainability,
 :languages, :files, :inserted_at, :updated_at]
```

### Test Storage

```elixir
# Create test summary
test_summary = %{
  total_files: 10,
  total_lines: 1000,
  files: %{},
  languages: %{"elixir" => 10}
}

{:ok, stored} = Singularity.Analysis.Summary.store(
  test_summary,
  codebase_id: "test-project"
)

# Verify retrieval
retrieved = Singularity.Analysis.Summary.fetch_latest(
  codebase_id: "test-project"
)

assert retrieved.id == stored.id
assert retrieved.total_files == 10
```

## Production Considerations

### Performance
- JSONB indexes for `analysis_data` field (consider GIN index for complex queries)
- Partition table by `analyzed_at` for large datasets (time-series optimization)
- Consider materialized views for aggregate statistics

### Retention Policy
- Default: 30 days retention
- Production recommendation: 90 days for trend analysis
- Critical codebases: 365 days for year-over-year comparison
- Run cleanup as scheduled job (e.g., weekly cron)

### Monitoring
- Track analysis frequency per codebase
- Alert on quality score degradation
- Monitor technical debt ratio trends
- Dashboard for visualizing metrics over time

### Backup
- JSONB `analysis_data` contains full snapshot
- Can reconstruct all metrics from stored data
- Consider archiving old analyses to S3/blob storage

## Integration Points

### Current
- ✅ PolyglotCodeParser - Automatic storage on codebase analysis
- ✅ Refactoring.Analyzer - Reads latest for refactoring detection
- ✅ CodebaseRegistry - Can coexist with existing snapshot system

### Future
- 📋 NATS subject `analysis.summary.stored` - Broadcast on new analysis
- 📋 LiveView dashboard - Real-time quality metrics visualization
- 📋 GitHub Actions integration - Store analysis on CI runs
- 📋 Slack notifications - Alert on quality threshold violations
- 📋 API endpoint - Expose analysis history via Phoenix

## Migration Path

1. ✅ Run migration: `mix ecto.migrate`
2. ✅ Verify schema exists: `psql -c "\d analysis_summaries"`
3. ✅ Test with sample data
4. ✅ Update existing analysis flows to use new API
5. 📋 Backfill historical data (if needed)
6. 📋 Set up retention policy cron job
7. 📋 Add monitoring/alerting

## Files Modified

1. `/home/mhugo/code/singularity/singularity_app/lib/singularity/analysis/summary.ex`
   - Added Ecto schema
   - Added persistence functions (store, fetch_latest, fetch_history, cleanup_old, get_stats)
   - Added aggregate metric calculation
   - Added file hydration from JSONB

2. `/home/mhugo/code/singularity/singularity_app/priv/repo/migrations/20240101000007_create_analysis_summaries.exs`
   - Created analysis_summaries table
   - Added indexes for performance
   - Added unique constraint

3. `/home/mhugo/code/singularity/singularity_app/lib/singularity/code/parsers/polyglot_code_parser.ex`
   - Added automatic storage on codebase analysis
   - Added helper functions for data conversion
   - Integrated with Analysis.Summary.store/2

4. `/home/mhugo/code/singularity/singularity_app/lib/singularity/code/quality/refactoring_analyzer.ex`
   - Updated to use Analysis.Summary.fetch_latest/1 with codebase_id
   - Added codebase_id parameter support

## Architecture Compliance

This implementation follows Singularity's naming conventions:

✅ **Self-Documenting Names**
- `Analysis.Summary` - What: Analysis data, What it does: Summarize
- `fetch_latest/1` - Clear action: fetch most recent
- `store_analysis_summary/2` - What: analysis summary, How: store

✅ **Clear Separation**
- Analysis struct (in-memory) vs Schema (persistence)
- Virtual `files` field for in-memory representation
- JSONB `analysis_data` for database storage

✅ **Production Quality**
- Proper Ecto changesets with validation
- Error handling with pattern matching
- Comprehensive documentation
- Indexed queries for performance
- Data retention policy

✅ **Persistence Layer Complete**
- Create (store)
- Read (fetch_latest, fetch_history)
- Update (N/A - immutable time-series)
- Delete (cleanup_old)
- Aggregate (get_stats)
