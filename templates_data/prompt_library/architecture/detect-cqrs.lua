-- Architecture Pattern Detection: CQRS (Command Query Responsibility Segregation)
-- Analyzes codebase to detect CQRS architecture pattern
--
-- Version: 1.0.0
-- Used by: Centralcloud.ArchitectureLLMTeam (Pattern Analyst agent)
-- Model: Claude Opus (best for deep analysis)
--
-- Input variables:
--   codebase_id: string - Project identifier
--   project_root: string - Root directory path
--
-- Returns: Lua prompt string for LLM

local Prompt = require("prompt")
local prompt = Prompt.new()

-- Extract input
local codebase_id = variables.codebase_id or "unknown"
local project_root = variables.project_root or "."

prompt:add("# Architecture Pattern Detection: CQRS")
prompt:add("")

prompt:section("ROLE", [[
You are the Pattern Analyst on the Architecture LLM Team.
Your specialty is discovering architecture patterns through deep code analysis.
Focus: Identifying CQRS (Command Query Responsibility Segregation) patterns.
]])

prompt:section("TASK", [[
Analyze this codebase and determine if it uses CQRS (Command Query Responsibility Segregation).

CQRS indicators:
1. **Commands** - Operations that change state (write side)
2. **Queries** - Operations that return data without changing state (read side)
3. **Separate Models** - Different models for read and write
4. **Command Handlers** - Process commands and modify state
5. **Query Handlers** - Process queries and return data
6. **Optional: Separate Databases** - Read DB and write DB (extreme CQRS)

CQRS Principle (Bertrand Meyer):
> "A method should either change state OR return data, never both."

CQRS Variants:

**Simple CQRS** - Separate commands/queries, same database
- Commands modify state
- Queries read state
- Same data model

**CQRS with Read Models** - Separate read/write models, same database
- Write model: Normalized for consistency
- Read model: Denormalized for performance

**CQRS with Event Sourcing** - Commands create events, read models built from events
- Write side: Event store (append-only)
- Read side: Projections from events

**Full CQRS** - Separate databases for read and write
- Write DB: Optimized for transactions (PostgreSQL)
- Read DB: Optimized for queries (Elasticsearch, Redis)
- Eventual consistency between read/write sides
]])

-- Check for command definitions
local command_patterns = {
  "**/commands/**/*.{ex,rs,ts,js,py}",
  "**/*Command.{ex,rs,ts,js,py}",
  "**/*Cmd.{ex,rs,ts,js,py}"
}

local command_files = {}
for _, pattern in ipairs(command_patterns) do
  local files = workspace.glob(project_root .. "/" .. pattern)
  if files and #files > 0 then
    for _, file in ipairs(files) do
      table.insert(command_files, file)
    end
  end
end

if #command_files > 0 then
  prompt:section("COMMANDS", string.format([[
Found %d command definitions:
%s

Commands represent write operations that change system state.
]], #command_files, table.concat(command_files, function(f) return "  - " .. f end)))
end

-- Check for query definitions
local query_patterns = {
  "**/queries/**/*.{ex,rs,ts,js,py}",
  "**/*Query.{ex,rs,ts,js,py}",
  "**/*Qry.{ex,rs,ts,js,py}"
}

local query_files = {}
for _, pattern in ipairs(query_patterns) do
  local files = workspace.glob(project_root .. "/" .. pattern)
  if files and #files > 0 then
    for _, file in ipairs(files) do
      table.insert(query_files, file)
    end
  end
end

if #query_files > 0 then
  prompt:section("QUERIES", string.format([[
Found %d query definitions:
%s

Queries represent read operations that return data without side effects.
]], #query_files, table.concat(query_files, function(f) return "  - " .. f end)))
end

-- Check for command handlers
local command_handler_patterns = {
  "CommandHandler",
  "handle_command",
  "execute_command",
  "process_command"
}

local command_handler_files = {}
for _, pattern in ipairs(command_handler_patterns) do
  local files = workspace.grep(pattern, {
    path = project_root,
    file_pattern = "*.{ex,rs,ts,js,py}",
    max_results = 10
  })
  if files and #files > 0 then
    for _, file in ipairs(files) do
      if not command_handler_files[file.path] then
        command_handler_files[file.path] = true
      end
    end
  end
end

local handler_count = 0
for _ in pairs(command_handler_files) do
  handler_count = handler_count + 1
end

if handler_count > 0 then
  prompt:section("COMMAND_HANDLERS", string.format([[
Found %d files with command handlers.

Command handlers execute business logic to process commands and change state.
]], handler_count))
end

-- Check for query handlers
local query_handler_patterns = {
  "QueryHandler",
  "handle_query",
  "execute_query",
  "process_query"
}

local query_handler_files = {}
for _, pattern in ipairs(query_handler_patterns) do
  local files = workspace.grep(pattern, {
    path = project_root,
    file_pattern = "*.{ex,rs,ts,js,py}",
    max_results = 10
  })
  if files and #files > 0 then
    for _, file in ipairs(files) do
      if not query_handler_files[file.path] then
        query_handler_files[file.path] = true
      end
    end
  end
end

local query_handler_count = 0
for _ in pairs(query_handler_files) do
  query_handler_count = query_handler_count + 1
end

if query_handler_count > 0 then
  prompt:section("QUERY_HANDLERS", string.format([[
Found %d files with query handlers.

Query handlers fetch data and return it without modifying state.
]], query_handler_count))
end

-- Check for separate read models
local read_model_patterns = {
  "**/read_models/**/*.{ex,rs,ts,js,py}",
  "**/projections/**/*.{ex,rs,ts,js,py}",
  "**/*ReadModel.{ex,rs,ts,js,py}",
  "**/*Projection.{ex,rs,ts,js,py}"
}

local read_model_files = {}
for _, pattern in ipairs(read_model_patterns) do
  local files = workspace.glob(project_root .. "/" .. pattern)
  if files and #files > 0 then
    for _, file in ipairs(files) do
      table.insert(read_model_files, file)
    end
  end
end

if #read_model_files > 0 then
  prompt:section("READ_MODELS", string.format([[
Found %d read model/projection definitions:
%s

Read models are optimized for queries (often denormalized).
Separate from write models (which are optimized for consistency).
]], #read_model_files, table.concat(read_model_files, function(f) return "  - " .. f end)))
end

-- Check for event sourcing (common with CQRS)
local event_sourcing_patterns = {
  "event_store",
  "EventStore",
  "aggregate",
  "apply_event"
}

local event_sourcing_found = false
for _, pattern in ipairs(event_sourcing_patterns) do
  local files = workspace.grep(pattern, {
    path = project_root,
    file_pattern = "*.{ex,rs,ts,js,py}",
    max_results = 1
  })
  if files and #files > 0 then
    event_sourcing_found = true
    break
  end
end

if event_sourcing_found then
  prompt:section("EVENT_SOURCING", [[
Event Sourcing detected!

CQRS + Event Sourcing is a common combination:
- Commands create events (write side)
- Events stored in event store
- Read models built from events (projections)
]])
end

-- Check for separate databases
local read_db_patterns = {
  "elasticsearch",
  "redis",
  "memcached",
  "read_repo",
  "ReadRepo",
  "query_db"
}

local write_db_patterns = {
  "write_repo",
  "WriteRepo",
  "command_db"
}

local separate_dbs = false
for _, pattern in ipairs(read_db_patterns) do
  local files = workspace.grep(pattern, {
    path = project_root,
    file_pattern = "*.{ex,rs,ts,js,py}",
    max_results = 1
  })
  if files and #files > 0 then
    for _, write_pattern in ipairs(write_db_patterns) do
      local write_files = workspace.grep(write_pattern, {
        path = project_root,
        file_pattern = "*.{ex,rs,ts,js,py}",
        max_results = 1
      })
      if write_files and #write_files > 0 then
        separate_dbs = true
        break
      end
    end
  end
end

if separate_dbs then
  prompt:section("SEPARATE_DATABASES", [[
Separate databases detected!

This is "Full CQRS" with different databases for read and write:
- Write DB: Optimized for transactions and consistency
- Read DB: Optimized for queries and performance
- Eventual consistency between the two
]])
end

prompt:section("ANALYSIS_CRITERIA", [[
Analyze the evidence above and determine:

1. Is this CQRS architecture? (true/false)
2. What variant? (simple, read_models, event_sourcing, full_separation)
3. Are commands and queries clearly separated?
4. What evidence supports CQRS pattern?
5. What's the confidence level? (0.0-1.0)
6. Quality assessment - is CQRS well-implemented?

CQRS Maturity Levels:

**Level 1: Simple CQRS**
- Separate command/query methods
- Same database
- Same models
- Benefits: Clear intent (command vs query)

**Level 2: Read Models**
- Separate read/write models
- Write model: Normalized
- Read model: Denormalized
- Same database
- Benefits: Performance (optimized queries)

**Level 3: Event Sourcing**
- Commands create events
- Event store (write side)
- Read models from projections
- Benefits: Audit trail, time travel, replay

**Level 4: Full Separation**
- Separate databases
- Eventual consistency
- Write DB: PostgreSQL (ACID)
- Read DB: Elasticsearch (fast queries)
- Benefits: Independent scaling, optimization

When to use CQRS:
- ✅ Complex domains with different read/write patterns
- ✅ High read-to-write ratio (optimize reads separately)
- ✅ Event-driven architecture
- ✅ Need audit trail (event sourcing variant)
- ❌ Simple CRUD applications (overkill)
- ❌ Strong consistency required everywhere

Benefits:
- Performance (optimize read and write independently)
- Scalability (scale read/write separately)
- Flexibility (different models for different needs)
- Security (separate read/write permissions)

Challenges:
- Complexity (more moving parts)
- Eventual consistency (read side may lag behind write side)
- Code duplication (separate models)
- Learning curve (unfamiliar pattern)
]])

prompt:section("OUTPUT_FORMAT", [[
Return ONLY valid JSON in this exact format:

{
  "pattern_detected": true,
  "pattern_name": "cqrs",
  "pattern_type": "architecture",
  "cqrs_variant": "simple" | "read_models" | "event_sourcing" | "full_separation",
  "confidence": 0.90,
  "indicators_found": [
    {
      "indicator": "separate_commands_queries",
      "evidence": "18 command files, 25 query files in separate directories",
      "weight": 0.95,
      "required": true
    },
    {
      "indicator": "command_handlers",
      "evidence": "Command handlers process commands and modify state",
      "weight": 0.85,
      "required": true
    },
    {
      "indicator": "query_handlers",
      "evidence": "Query handlers fetch data without side effects",
      "weight": 0.85,
      "required": true
    },
    {
      "indicator": "read_models",
      "evidence": "12 read model projections optimized for queries",
      "weight": 0.8,
      "required": false
    },
    {
      "indicator": "event_sourcing",
      "evidence": "EventStore used, events are source of truth",
      "weight": 0.75,
      "required": false
    }
  ],
  "cqrs_structure": {
    "command_count": 18,
    "query_count": 25,
    "command_handlers": 18,
    "query_handlers": 25,
    "read_models": 12,
    "write_models": 18
  },
  "architecture_quality": {
    "overall_score": 87,
    "separation_clarity": 92,
    "handler_quality": 85,
    "read_model_optimization": 88,
    "consistency_handling": 80,
    "performance": 90
  },
  "cqrs_maturity": {
    "level": 3,
    "description": "CQRS with Event Sourcing",
    "capabilities": [
      "Clear command/query separation",
      "Separate read models (denormalized)",
      "Event sourcing for write side",
      "Event projections for read side"
    ]
  },
  "separate_databases": {
    "detected": false,
    "write_database": "PostgreSQL",
    "read_database": "PostgreSQL (same as write)",
    "eventual_consistency": false
  },
  "event_sourcing_integration": {
    "detected": true,
    "event_store": "EventStore library",
    "commands_create_events": true,
    "read_models_from_projections": true,
    "event_replay_supported": true
  },
  "benefits": [
    "Performance: Read models optimized for fast queries",
    "Scalability: Can scale read/write sides independently",
    "Audit trail: Event sourcing provides complete history",
    "Flexibility: Different read models for different use cases"
  ],
  "concerns": [
    "Eventual consistency: Read models may lag behind write side",
    "Complexity: More code and moving parts than simple CRUD",
    "No synchronization mechanism documented (how to keep read models current?)",
    "Missing monitoring for projection lag"
  ],
  "recommendations": [
    "Add monitoring for read model projection lag",
    "Document eventual consistency behavior for each read model",
    "Implement projection rebuild capability (for corrupted read models)",
    "Add integration tests validating command → event → read model flow",
    "Consider caching layer for frequently-queried read models",
    "Document when to use commands vs direct writes (if any)"
  ],
  "consistency_handling": {
    "write_consistency": "strong (event store is ACID)",
    "read_consistency": "eventual (read models updated asynchronously)",
    "consistency_guarantees_documented": false,
    "lag_monitoring": false
  },
  "performance_characteristics": {
    "read_performance": "excellent (denormalized read models)",
    "write_performance": "good (append-only event store)",
    "read_write_ratio": "80:20 (read-heavy)",
    "bottlenecks": ["Projection updates can lag under high write load"]
  },
  "llm_reasoning": "Strong CQRS pattern detected. Clear separation: 18 commands, 25 queries. Command and query handlers present. 12 read models optimized for queries. Event sourcing integrated (commands create events, read models from projections). Same database (PostgreSQL) but separate models. CQRS maturity level 3 (Event Sourcing). Quality score: 87/100. Confidence: 90% based on clear command/query structure and event sourcing integration."
}

Do NOT include markdown code fences or explanations.
Just raw JSON.
]])

return prompt:render()
