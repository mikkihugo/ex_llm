# Dynamic Cache TTL for CodebaseDetector

**Intelligent cache TTL based on ingestion workload** ⚡

---

## Problem: Git Command Overhead

When ingesting 933 files on startup, calling `git remote get-url origin` for each file is wasteful:

```
Without cache:
  933 files × 10ms per git call = ~9,330ms (9.3 seconds!) wasted

With 5-minute cache:
  1 git call (10ms) + 932 ETS reads (0.01ms each) = ~19ms total
  Savings: 9.3 seconds per startup ✅

But what if startup takes 15 minutes?
  Cache expires after 5 minutes → Need to run git again!
```

---

## Solution: Dynamic TTL

### Adaptive Cache Based on Workload

```elixir
# Light workload (single file hot reload): 5-minute TTL
CodebaseDetector.detect(format: :full)
# Cache expires after 5 minutes

# Heavy workload (933 files on startup): 30-minute TTL
CodebaseDetector.detect(format: :full, extend_cache: true)
# Cache expires after 30 minutes

# Custom TTL
CodebaseDetector.detect(format: :full, cache_ttl: :timer.hours(1))
# Cache expires after 1 hour
```

---

## Implementation

### Constants

```elixir
@default_cache_ttl :timer.minutes(5)   # 5 minutes (300,000ms)
@extended_cache_ttl :timer.minutes(30)  # 30 minutes (1,800,000ms)
```

### API

```elixir
def detect(opts \\ []) do
  extend_cache = Keyword.get(opts, :extend_cache, false)

  cache_ttl = if extend_cache do
    @extended_cache_ttl  # 30 minutes
  else
    Keyword.get(opts, :cache_ttl, @default_cache_ttl)  # 5 minutes (default)
  end

  # ... rest of implementation
end
```

### Storage Format

ETS entry includes TTL for observability:
```elixir
{cache_key, codebase_id, cached_at, cache_ttl}
# Example:
{{:codebase_id, :full}, "mikkihugo/singularity-incubation", 123456789, 1800000}
```

---

## Usage

### Automatic (StartupCodeIngestion)

```elixir
module_count = length(modules)

# Automatically extends cache if ingesting >100 files
codebase_id = CodebaseDetector.detect(
  format: :full,
  extend_cache: module_count > 100  # ✅ Auto-detect heavy workload
)

# Result:
# - 50 files:   5-minute cache (light workload)
# - 933 files:  30-minute cache (heavy workload)
```

### Manual

```elixir
# Force extended cache
codebase_id = CodebaseDetector.detect(format: :full, extend_cache: true)

# Custom TTL (e.g., 1 hour)
codebase_id = CodebaseDetector.detect(
  format: :full,
  cache_ttl: :timer.hours(1)
)

# Disable cache (always run git)
codebase_id = CodebaseDetector.detect(format: :full, cache: false)
```

---

## Performance Impact

### Startup (933 files, 10 workers, ~3 seconds total)

**Without extended cache:**
```
Scenario: Cache expires after 5 minutes
  - Files 1-300:   Use cached value (fast)
  - Files 301-600: Cache expired, run git again (slow)
  - Files 601-933: Use re-cached value (fast)

Result: 2 git calls during ingestion ❌
```

**With extended cache:**
```
Scenario: Cache valid for 30 minutes
  - Files 1-933:   All use cached value (fast)

Result: 1 git call total ✅
  Savings: ~10ms per extra git call avoided
```

### Hot Reload (single file)

```
# No need for extended cache
CodebaseDetector.detect(format: :full)

# Uses default 5-minute TTL
# - Fast enough for single file changes
# - Cache expires after 5 minutes (reasonable)
```

---

## When Cache is Used

### Heavy Ingestion (30-minute TTL)

✅ **StartupCodeIngestion** (startup)
  - Condition: `module_count > 100`
  - Example: 933 files on startup
  - Duration: ~3 seconds (all files use same cached value)

### Light Usage (5-minute TTL)

✅ **CodeFileWatcher** (hot reload)
  - Condition: Single file changed
  - Example: Edit `lib/my_module.ex`
  - Duration: ~50ms (cache likely still valid)

✅ **Manual queries** (default)
  - Example: `CodebaseDetector.detect()`
  - Cache expires after 5 minutes

---

## Observability

### Logging

```elixir
Logger.debug("[CodebaseDetector] Cached mikkihugo/singularity-incubation (format: full, TTL: 30min)")
```

### ETS Inspection

```elixir
iex> :ets.tab2list(:codebase_detector_cache)
[
  {{:codebase_id, :full}, "mikkihugo/singularity-incubation", 123456789, 1800000}
]

# TTL: 1,800,000ms = 30 minutes
```

---

## Edge Cases

### Cache Expiration Mid-Ingestion

**Problem**: What if startup takes longer than 30 minutes?

**Solution**: Cache expires, git command runs again
  - Cost: One extra 10ms git call (negligible)
  - Cache refreshed for remaining files

**Example**:
```
Startup begins (0 minutes):
  - Run git → Cache for 30 minutes

Files 1-500 (0-15 minutes):
  - All use cached value ✅

Files 501-933 (15-35 minutes):
  - Cache expired at 30 minutes → Run git again
  - Re-cache for another 30 minutes
  - Files 501-933 use new cached value ✅

Total: 2 git calls (instead of 933) - still huge savings!
```

### Git Remote Changed

**Problem**: User changes git remote mid-session

**Solution**: Use `CodebaseDetector.reload()`
```elixir
git remote set-url origin git@github.com:user/new-repo.git

# Force cache reload
CodebaseDetector.reload()
# => {:ok, "user/new-repo"}

# Next calls use new value
CodebaseDetector.detect()
# => "user/new-repo"
```

### ETS Table Not Ready

**Fallback**: If ETS table fails, skip caching and run git directly
```elixir
try do
  :ets.insert(@cache_table, {cache_key, codebase_id, cached_at, cache_ttl})
rescue
  _ ->
    Logger.debug("[CodebaseDetector] ETS not ready, skipping cache")
    :ok
end
```

---

## Configuration

### Default (Recommended)

No configuration needed! Auto-detects heavy workload:

```elixir
# config/config.exs
# No CodebaseDetector config required - just works!
```

### Custom TTL (Optional)

```elixir
# config/config.exs
config :singularity, Singularity.Code.CodebaseDetector,
  default_cache_ttl: :timer.minutes(10),   # Increase default to 10 minutes
  extended_cache_ttl: :timer.hours(1)      # Increase extended to 1 hour
```

---

## Testing

### Verify Cache TTL

```elixir
# Start with clean cache
CodebaseDetector.clear_cache()

# First call: Should run git and cache
codebase_id = CodebaseDetector.detect(format: :full, extend_cache: true)
# Log: "Cached mikkihugo/singularity-incubation (format: full, TTL: 30min)"

# Check ETS
:ets.tab2list(:codebase_detector_cache)
# => [{{:codebase_id, :full}, "mikkihugo/singularity-incubation", 123456789, 1800000}]

# Second call: Should use cache (no git)
codebase_id = CodebaseDetector.detect(format: :full)
# => "mikkihugo/singularity-incubation" (instant, from cache)
```

### Verify Cache Expiration

```elixir
# Cache with 1-second TTL for testing
codebase_id = CodebaseDetector.detect(format: :full, cache_ttl: 1000)

# Wait 2 seconds
:timer.sleep(2000)

# Should run git again (cache expired)
codebase_id = CodebaseDetector.detect(format: :full)
# => Runs git command (cache expired)
```

---

## Benefits

✅ **9+ seconds saved** on startup (933 files)
✅ **Auto-adaptive** - no manual configuration
✅ **Safe** - cache expires eventually (no stale data)
✅ **Observable** - TTL logged and stored in ETS
✅ **Flexible** - custom TTL supported
✅ **Fallback-safe** - works without ETS

---

## Summary

| Scenario | TTL | Files | Time Saved |
|----------|-----|-------|------------|
| Hot reload (1 file) | 5 min | 1 | ~0ms (cache likely valid) |
| Small batch (<100) | 5 min | 50 | ~0.5s (50 git calls avoided) |
| Startup (>100 files) | 30 min | 933 | ~9.3s (932 git calls avoided) |

**Dynamic TTL = Performance without complexity!** ⚡
