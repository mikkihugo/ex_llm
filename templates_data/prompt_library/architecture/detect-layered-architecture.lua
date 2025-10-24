-- Architecture Pattern Detection: Layered Architecture
-- Analyzes codebase to detect layered (n-tier) architecture pattern
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

prompt:add("# Architecture Pattern Detection: Layered Architecture")
prompt:add("")

prompt:section("ROLE", [[
You are the Pattern Analyst on the Architecture LLM Team.
Your specialty is discovering architecture patterns through deep code analysis.
Focus: Identifying layered (n-tier) architecture patterns.
]])

prompt:section("TASK", [[
Analyze this codebase and determine if it uses Layered Architecture.

Layered Architecture indicators:
1. Clear separation into horizontal layers (presentation, business, data)
2. Each layer has specific responsibility
3. Dependencies flow downward (upper layers depend on lower, not vice versa)
4. Layers are replaceable (can swap data layer without changing business layer)
5. Common layers:
   - **Presentation Layer** (UI, API controllers, web layer)
   - **Business/Domain Layer** (business logic, domain models)
   - **Data Access Layer** (repositories, ORM, database access)
   - **Infrastructure Layer** (logging, caching, external services)

Classic patterns:
- **3-Tier**: Presentation → Business → Data
- **4-Tier**: Presentation → Application → Domain → Data
- **N-Tier**: Multiple layers with clear separation of concerns

Key principle: **Separation of Concerns** - each layer handles ONE aspect of the application.
]])

-- Check for presentation layer
local presentation_patterns = {
  "**/controllers/**/*.{ex,rs,ts,js,py}",
  "**/web/**/*.{ex,rs,ts,js,py}",
  "**/api/**/*.{ex,rs,ts,js,py}",
  "**/views/**/*.{ex,rs,ts,js,py}",
  "**/handlers/**/*.{ex,rs,ts,js,py}",
  "**/routes/**/*.{ex,rs,ts,js,py}"
}

local presentation_files = {}
for _, pattern in ipairs(presentation_patterns) do
  local files = workspace.glob(project_root .. "/" .. pattern)
  if files and #files > 0 then
    for _, file in ipairs(files) do
      table.insert(presentation_files, file)
    end
  end
end

if #presentation_files > 0 then
  prompt:section("PRESENTATION_LAYER", string.format([[
Found %d files in presentation layer (controllers, web, API, handlers):
%s

Presentation layer handles HTTP requests, user input, response formatting.
]], #presentation_files, table.concat(presentation_files, function(f) return "  - " .. f end)))
end

-- Check for business/domain layer
local business_patterns = {
  "**/services/**/*.{ex,rs,ts,js,py}",
  "**/domain/**/*.{ex,rs,ts,js,py}",
  "**/business/**/*.{ex,rs,ts,js,py}",
  "**/core/**/*.{ex,rs,ts,js,py}",
  "**/use_cases/**/*.{ex,rs,ts,js,py}",
  "**/application/**/*.{ex,rs,ts,js,py}"
}

local business_files = {}
for _, pattern in ipairs(business_patterns) do
  local files = workspace.glob(project_root .. "/" .. pattern)
  if files and #files > 0 then
    for _, file in ipairs(files) do
      table.insert(business_files, file)
    end
  end
end

if #business_files > 0 then
  prompt:section("BUSINESS_LAYER", string.format([[
Found %d files in business/domain layer (services, domain, use cases):
%s

Business layer contains core business logic, domain models, use cases.
]], #business_files, table.concat(business_files, function(f) return "  - " .. f end)))
end

-- Check for data access layer
local data_patterns = {
  "**/repositories/**/*.{ex,rs,ts,js,py}",
  "**/repo/**/*.{ex,rs,ts,js,py}",
  "**/data/**/*.{ex,rs,ts,js,py}",
  "**/persistence/**/*.{ex,rs,ts,js,py}",
  "**/dao/**/*.{ex,rs,ts,js,py}",
  "**/models/**/*.{ex,rs,ts,js,py}",
  "**/schemas/**/*.{ex,rs,ts,js,py}"
}

local data_files = {}
for _, pattern in ipairs(data_patterns) do
  local files = workspace.glob(project_root .. "/" .. pattern)
  if files and #files > 0 then
    for _, file in ipairs(files) do
      table.insert(data_files, file)
    end
  end
end

if #data_files > 0 then
  prompt:section("DATA_ACCESS_LAYER", string.format([[
Found %d files in data access layer (repositories, models, schemas):
%s

Data access layer handles database operations, data persistence, ORM.
]], #data_files, table.concat(data_files, function(f) return "  - " .. f end)))
end

-- Check for infrastructure layer
local infra_patterns = {
  "**/infrastructure/**/*.{ex,rs,ts,js,py}",
  "**/lib/**/*.{ex,rs,ts,js,py}",
  "**/utils/**/*.{ex,rs,ts,js,py}",
  "**/config/**/*.{ex,rs,ts,js,py}",
  "**/middleware/**/*.{ex,rs,ts,js,py}"
}

local infra_files = {}
for _, pattern in ipairs(infra_patterns) do
  local files = workspace.glob(project_root .. "/" .. pattern)
  if files and #files > 0 then
    for _, file in ipairs(files) do
      table.insert(infra_files, file)
    end
  end
end

if #infra_files > 0 then
  prompt:section("INFRASTRUCTURE_LAYER", string.format([[
Found %d files in infrastructure layer (utils, config, middleware):
%s

Infrastructure layer provides cross-cutting concerns: logging, caching, auth.
]], #infra_files, table.concat(infra_files, function(f) return "  - " .. f end)))
end

-- Check for dependency direction violations
local controller_to_repo = workspace.grep("Repo\\.", {
  path = project_root .. "/controllers",
  file_pattern = "*.{ex,rs,ts,js}",
  max_results = 5
})

local violation_count = 0
if controller_to_repo and #controller_to_repo > 0 then
  violation_count = #controller_to_repo
end

if violation_count > 0 then
  prompt:section("LAYERING_VIOLATIONS", string.format([[
WARNING: Found %d potential layering violations!

Controllers directly accessing Repo/Database bypasses business layer.
This violates layered architecture (controller should call service, service calls repo).
]], violation_count))
end

prompt:section("ANALYSIS_CRITERIA", [[
Analyze the evidence above and determine:

1. Is this a layered architecture? (true/false)
2. How many layers are present? (3-tier, 4-tier, n-tier)
3. Are layer boundaries respected? (dependencies flow downward)
4. What evidence supports layered pattern?
5. What's the confidence level? (0.0-1.0)
6. Quality assessment - is layering clean or violated?

Layer Dependency Rules:
- Presentation → Business → Data (✅ CORRECT)
- Presentation → Data (❌ VIOLATION - bypasses business layer)
- Data → Business (❌ VIOLATION - upward dependency)
- Business ↔ Data (❌ VIOLATION - circular dependency)

Benefits of Layered Architecture:
- Clear separation of concerns
- Easy to understand and maintain
- Layers are replaceable (swap UI, swap database)
- Good for team organization (UI team, backend team, data team)

Drawbacks:
- Can become "lasagna architecture" (too many layers)
- Business logic can leak into presentation or data layers
- Not suitable for complex domains (consider Hexagonal/Clean Architecture instead)
]])

prompt:section("OUTPUT_FORMAT", [[
Return ONLY valid JSON in this exact format:

{
  "pattern_detected": true,
  "pattern_name": "layered_architecture",
  "pattern_type": "architecture",
  "tier_count": 3,
  "tier_type": "3-tier" | "4-tier" | "n-tier",
  "confidence": 0.85,
  "layers_identified": [
    {
      "layer_name": "presentation",
      "file_count": 24,
      "directories": ["controllers/", "web/"],
      "responsibilities": ["HTTP handling", "Request validation", "Response formatting"],
      "quality": "good"
    },
    {
      "layer_name": "business",
      "file_count": 45,
      "directories": ["services/", "domain/"],
      "responsibilities": ["Business logic", "Domain models", "Use cases"],
      "quality": "excellent"
    },
    {
      "layer_name": "data",
      "file_count": 18,
      "directories": ["repositories/", "schemas/"],
      "responsibilities": ["Database access", "Data persistence", "ORM"],
      "quality": "good"
    }
  ],
  "indicators_found": [
    {
      "indicator": "clear_layer_separation",
      "evidence": "3 distinct layers with separate directories: controllers/, services/, repositories/",
      "weight": 0.9,
      "required": true
    },
    {
      "indicator": "downward_dependencies",
      "evidence": "Controllers call Services, Services call Repositories - proper dependency flow",
      "weight": 0.85,
      "required": true
    },
    {
      "indicator": "layer_isolation",
      "evidence": "Each layer has distinct responsibilities, no business logic in controllers",
      "weight": 0.8,
      "required": false
    }
  ],
  "architecture_quality": {
    "overall_score": 82,
    "layer_separation": 90,
    "dependency_direction": 85,
    "cohesion": 80,
    "coupling": 75,
    "maintainability": 85
  },
  "layering_violations": [
    {
      "violation": "controller_bypasses_service",
      "severity": "error",
      "location": "controllers/user_controller.ex:45",
      "description": "Controller directly calls Repo.insert() - should call UserService instead",
      "impact": "Business logic leaks into presentation layer"
    }
  ],
  "benefits": [
    "Clear separation of concerns (UI, business, data)",
    "Easy to understand (developers immediately know where to find code)",
    "Replaceable layers (can swap database without touching UI)",
    "Good for team organization (frontend team, backend team, DBA team)"
  ],
  "concerns": [
    "Found 5 layering violations (controllers accessing database directly)",
    "Some business logic in presentation layer (validation in controllers)",
    "Tight coupling between layers (hard to test in isolation)",
    "May become rigid as complexity grows"
  ],
  "recommendations": [
    "Fix layering violations: Controllers should only call Services",
    "Move validation logic from Controllers to Services (business concern)",
    "Add interfaces/protocols between layers for loose coupling",
    "Consider dependency injection for better testability",
    "If domain complexity grows, consider Hexagonal or Clean Architecture"
  ],
  "best_practices_followed": [
    "Presentation layer handles only HTTP concerns",
    "Business layer is isolated from HTTP and database details",
    "Repository pattern used for data access abstraction"
  ],
  "anti_patterns_detected": [
    "Anemic Domain Model (domain objects with no behavior, just data)",
    "Business logic scattered across services (not cohesive)"
  ],
  "llm_reasoning": "Strong layered architecture detected. Clear 3-tier structure: Presentation (controllers/), Business (services/), Data (repositories/). Dependency flow is mostly correct (downward). Found 5 layering violations where controllers bypass business layer. Quality score: 82/100 - good architecture but needs violation cleanup. Confidence: 85% based on clear directory structure and layer separation."
}

Do NOT include markdown code fences or explanations.
Just raw JSON.
]])

return prompt:render()
