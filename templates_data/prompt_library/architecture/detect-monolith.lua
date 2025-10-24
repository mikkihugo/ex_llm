-- Architecture Pattern Detection: Monolith
-- Analyzes codebase to detect monolithic architecture pattern
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

prompt:add("# Architecture Pattern Detection: Monolith")
prompt:add("")

prompt:section("ROLE", [[
You are the Pattern Analyst on the Architecture LLM Team.
Your specialty is discovering architecture patterns through deep code analysis.
Focus: Identifying monolithic architecture patterns.
]])

prompt:section("TASK", [[
Analyze this codebase and determine if it uses Monolithic architecture.

Monolith indicators:
1. Single deployable unit (one main application)
2. All code in one repository/directory structure
3. Tight coupling between components (direct function calls, shared memory)
4. Shared database access across modules
5. Single build/deployment process
6. No clear service boundaries or APIs between components
7. All features scale together (can't scale independently)
8. Usually a single technology stack throughout

Types of monoliths:
- **Traditional Monolith**: Single codebase, no modularity
- **Modular Monolith**: Single codebase but well-organized modules (still one deployment)
- **Distributed Monolith**: Multiple deployables but tightly coupled (worst of both worlds)
]])

-- Check for single application structure
local main_files = {}
local patterns = {
  "main.rs",           -- Rust main
  "main.go",           -- Go main
  "main.ts",           -- TypeScript main
  "main.js",           -- JavaScript main
  "index.ts",          -- TypeScript entry
  "index.js",          -- JavaScript entry
  "app.ex",            -- Elixir application
  "application.ex",    -- Elixir application
  "__main__.py",       -- Python main
  "manage.py"          -- Django main
}

for _, pattern in ipairs(patterns) do
  local files = workspace.glob(project_root .. "/**/" .. pattern)
  if files and #files > 0 then
    for _, file in ipairs(files) do
      table.insert(main_files, "  - " .. file)
    end
  end
end

if #main_files > 0 then
  prompt:section("MAIN_ENTRY_POINTS", string.format([[
Found %d main entry point(s):
%s

Note: Single entry point suggests monolithic deployment.
Multiple entry points may indicate microservices or distributed monolith.
]], #main_files, table.concat(main_files, "\n")))
end

-- Check for modular structure
local module_patterns = {
  "lib/*/*.ex",        -- Elixir modules
  "src/*/*.rs",        -- Rust modules
  "src/*/*.ts",        -- TypeScript modules
  "app/*/",            -- Rails-style modules
  "modules/*/",        -- Explicit modules
  "domains/*/"         -- DDD-style domains
}

local module_count = 0
local modules = {}
for _, pattern in ipairs(module_patterns) do
  local files = workspace.glob(project_root .. "/" .. pattern)
  if files and #files > 0 then
    module_count = module_count + #files
    for _, file in ipairs(files) do
      -- Extract module name
      local module_name = file:match("([^/]+)/[^/]+$") or file:match("([^/]+)/$")
      if module_name and not modules[module_name] then
        modules[module_name] = true
      end
    end
  end
end

local module_list = {}
for name, _ in pairs(modules) do
  table.insert(module_list, "  - " .. name)
end

if #module_list > 0 then
  prompt:section("MODULAR_STRUCTURE", string.format([[
Found %d modules/domains:
%s

Note: Good modular structure suggests "Modular Monolith" - still one deployment but well-organized.
]], #module_list, table.concat(module_list, "\n")))
end

-- Check for shared database access
local db_patterns = {
  "ecto",              -- Elixir Ecto
  "Repo",              -- Generic repository
  "ActiveRecord",      -- Rails
  "sqlx",              -- Rust sqlx
  "diesel",            -- Rust diesel
  "prisma",            -- TypeScript Prisma
  "typeorm",           -- TypeScript TypeORM
  "Database",          -- Generic
  "db.query"           -- Direct queries
}

local db_files = {}
for _, pattern in ipairs(db_patterns) do
  local files = workspace.grep(pattern, {
    path = project_root,
    file_pattern = "*.{ex,rs,ts,js,py,rb}",
    max_results = 10
  })
  if files and #files > 0 then
    for _, file in ipairs(files) do
      table.insert(db_files, "  - " .. file.path)
    end
  end
end

if #db_files > 0 then
  prompt:section("SHARED_DATABASE", string.format([[
Database access patterns found in %d files:
%s

Note: Shared database access across many files suggests monolithic data access pattern.
]], #db_files, table.concat(db_files, "\n")))
end

-- Check for tight coupling indicators
local coupling_patterns = {
  "import.*from.*'./'",     -- Relative imports (tight coupling)
  "alias.*\\.",             -- Elixir aliases
  "use .*::",               -- Rust use statements
  "require\\("              -- Node requires
}

local coupling_count = 0
for _, pattern in ipairs(coupling_patterns) do
  local files = workspace.grep(pattern, {
    path = project_root,
    file_pattern = "*.{ex,rs,ts,js}",
    max_results = 5
  })
  if files and #files > 0 then
    coupling_count = coupling_count + #files
  end
end

if coupling_count > 0 then
  prompt:section("COUPLING_INDICATORS", string.format([[
Found %d files with direct imports/dependencies.

High number of direct imports suggests tight coupling (monolithic characteristic).
]], coupling_count))
end

-- Check for build configuration
local build_files = workspace.glob(project_root .. "/{Cargo.toml,package.json,mix.exs,pom.xml,build.gradle,setup.py}")
if build_files and #build_files > 0 then
  prompt:section("BUILD_CONFIGURATION", string.format([[
Found %d build configuration file(s):
%s

Note: Single build file = single deployment = monolith.
Multiple build files may indicate microservices.
]], #build_files, table.concat(build_files, function(f) return "  - " .. f end)))
end

-- Check for deployment indicators
local deploy_files = workspace.glob(project_root .. "/{Dockerfile,docker-compose.yml,Procfile,*.service}")
local deploy_count = 0
if deploy_files then
  deploy_count = #deploy_files
end

if deploy_count > 0 then
  prompt:section("DEPLOYMENT", string.format([[
Found %d deployment configuration file(s).

Single Dockerfile = likely monolithic deployment.
Multiple Dockerfiles in service directories = likely microservices.
]], deploy_count))
end

prompt:section("ANALYSIS_CRITERIA", [[
Analyze the evidence above and determine:

1. Is this a monolithic architecture? (true/false)
2. What type of monolith? (traditional, modular, distributed, or not_a_monolith)
3. What evidence supports monolithic pattern?
4. What's the confidence level? (0.0-1.0)
5. Quality assessment - is this a well-structured monolith?
6. What concerns or anti-patterns exist?

Monolith Types:

**Traditional Monolith** - Single codebase, poor modularity, tight coupling
- Good for: Small teams, simple domains, rapid prototyping
- Bad for: Large teams, complex domains, independent scaling needs

**Modular Monolith** - Single codebase, excellent modularity, clear boundaries
- Good for: Medium teams, complex domains, don't need independent deployment
- Bad for: When different modules need different scaling or tech stacks

**Distributed Monolith** - Multiple deployables, tight coupling (ANTI-PATTERN!)
- This is the WORST architecture - complexity of microservices without benefits
- Indicators: Many services but shared database, synchronous calls everywhere, deploy together
]])

prompt:section("OUTPUT_FORMAT", [[
Return ONLY valid JSON in this exact format:

{
  "pattern_detected": true,
  "pattern_name": "modular_monolith",
  "pattern_type": "monolith",
  "monolith_type": "modular" | "traditional" | "distributed" | "not_a_monolith",
  "confidence": 0.88,
  "indicators_found": [
    {
      "indicator": "single_deployment_unit",
      "evidence": "One main application entry point, single Dockerfile",
      "weight": 0.9,
      "required": true
    },
    {
      "indicator": "modular_structure",
      "evidence": "12 well-defined modules in lib/ directory with clear boundaries",
      "weight": 0.8,
      "required": false
    },
    {
      "indicator": "shared_database",
      "evidence": "All modules access Ecto.Repo directly - shared database",
      "weight": 0.85,
      "required": true
    },
    {
      "indicator": "tight_coupling",
      "evidence": "Modules call each other directly via aliases - in-process communication",
      "weight": 0.7,
      "required": false
    },
    {
      "indicator": "single_technology_stack",
      "evidence": "Entire codebase is Elixir - no technology diversity",
      "weight": 0.6,
      "required": false
    }
  ],
  "architecture_quality": {
    "overall_score": 78,
    "modularity": 85,
    "coupling": 65,
    "cohesion": 80,
    "maintainability": 75,
    "scalability": 60
  },
  "monolith_assessment": {
    "is_well_structured": true,
    "modular_boundaries": "clear",
    "code_organization": "excellent",
    "technical_debt": "low",
    "refactoring_potential": "high"
  },
  "benefits": [
    "Simple deployment (single unit)",
    "Easy development (no distributed systems complexity)",
    "Strong consistency (shared database, ACID transactions)",
    "Fast in-process communication (no network latency)",
    "Easier debugging (single codebase, single process)"
  ],
  "concerns": [
    "All modules scale together (can't scale independently)",
    "Single point of failure (entire app goes down together)",
    "Technology lock-in (hard to introduce new tech stack)",
    "Large team coordination (all devs work in same codebase)",
    "Long deployment times as codebase grows"
  ],
  "recommendations": [
    "Maintain modular boundaries to enable future extraction to microservices",
    "Consider event-driven architecture within monolith for loose coupling",
    "Add clear API contracts between modules (use behaviours/protocols)",
    "Monitor for signs monolith is outgrowing single deployment (deployment friction, team conflicts)",
    "If migrating to microservices, extract modules one at a time (strangler pattern)"
  ],
  "migration_readiness": {
    "ready_for_microservices": false,
    "reasoning": "Modular structure is good but team size/scale doesn't justify microservices complexity yet",
    "when_to_migrate": "When modules need independent scaling, or team size > 50 developers, or deployment frequency > 10x/day"
  },
  "llm_reasoning": "Strong monolithic pattern detected. Single deployment unit (one main application), shared database (Ecto.Repo used across all modules), tight in-process coupling. However, this is a well-structured 'Modular Monolith' with 12 clear modules and good boundaries. Quality score: 78/100. This is GOOD architecture for current scale - don't rush to microservices without business need. Confidence: 88% based on clear evidence of single deployment and shared database."
}

Do NOT include markdown code fences or explanations.
Just raw JSON.
]])

return prompt:render()
