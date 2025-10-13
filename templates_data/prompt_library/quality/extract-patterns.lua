-- extract-patterns.lua
-- Extract reusable patterns from high-quality code
--
-- This script is used by Singularity.Bootstrap.CodeQualityEnforcer.extract_patterns/2
--
-- Input variables (from Elixir):
--   code: string - The code to analyze
--   metadata: table - {quality_score: float, module_name: string, ...}
--
-- Returns: JSON prompt asking LLM to identify patterns

local Prompt = require("prompt")
local prompt = Prompt.new()

-- Extract input variables
local code = variables.code or error("code is required")
local metadata = variables.metadata or {}
local quality_score = metadata.quality_score or 0.0
local module_name = metadata.module_name or "Unknown"

-- Only extract from high-quality code
if quality_score < 0.95 then
  return prompt:render()  -- Empty prompt, won't be called
end

prompt:add("# Extract Reusable Patterns from High-Quality Code")
prompt:add("")
prompt:add(string.format("Analyze this high-quality Elixir code (quality score: %.2f) and extract reusable patterns.", quality_score))
prompt:add("")

if module_name ~= "Unknown" then
  prompt:add(string.format("Module: %s", module_name))
  prompt:add("")
end

prompt:section("CODE TO ANALYZE", string.format([[
```elixir
%s
```
]], code))

prompt:section("ANALYSIS TASK", [[
Identify reusable patterns in this code that can be applied to other modules.

Focus on:
1. Design patterns used (GenServer, Supervisor, Circuit Breaker, Cache, etc.)
2. When this pattern should be used (problem it solves)
3. Key characteristics that make it successful
4. Template/skeleton for reuse
5. Common pitfalls to avoid

Look for:
- OTP patterns (GenServer, Supervisor, Agent, Task)
- Error handling patterns ({:ok, _} | {:error, _})
- Performance patterns (ETS caching, streaming, batching)
- Resilience patterns (circuit breakers, retries, timeouts)
- Observability patterns (telemetry, structured logging)
- Security patterns (input validation, sanitization)
- Testing patterns (mocks, property-based tests)
]])

prompt:section("OUTPUT FORMAT", [[
Return a JSON array of patterns. Each pattern should have:

```json
[
  {
    "pattern_type": "genserver_with_cache",
    "confidence": 0.95,
    "when_to_use": [
      "Stateful caching with TTL",
      "Concurrent access to shared state",
      "Automatic cache invalidation"
    ],
    "key_characteristics": [
      "Uses ETS for fast lookups",
      "GenServer manages TTL timers",
      "Telemetry for cache hits/misses"
    ],
    "skeleton": "defmodule MyCache do\n  use GenServer\n  # ETS table setup in init/1\n  # Cache operations via handle_call/3\n  # TTL cleanup via handle_info/2\nend",
    "pitfalls": [
      "Don't forget to clean up expired entries",
      "Consider memory limits for cache growth"
    ],
    "related_modules": [
      "Singularity.Cache",
      "Singularity.RateLimiter"
    ]
  }
]
```

Return ONLY the JSON array, no markdown, no explanations.
]])

return prompt:render()
