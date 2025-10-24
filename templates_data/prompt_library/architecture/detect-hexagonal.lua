-- Architecture Pattern Detection: Hexagonal Architecture (Ports and Adapters)
-- Analyzes codebase to detect hexagonal architecture pattern
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

prompt:add("# Architecture Pattern Detection: Hexagonal Architecture")
prompt:add("")

prompt:section("ROLE", [[
You are the Pattern Analyst on the Architecture LLM Team.
Your specialty is discovering architecture patterns through deep code analysis.
Focus: Identifying hexagonal architecture (ports and adapters) patterns.
]])

prompt:section("TASK", [[
Analyze this codebase and determine if it uses Hexagonal Architecture (Ports and Adapters).

Hexagonal Architecture indicators:
1. **Core Domain** - Business logic isolated from external concerns (center of hexagon)
2. **Ports** - Interfaces defining how core interacts with outside world
3. **Adapters** - Implementations of ports (database, HTTP, message queue, external APIs)
4. **Dependency Inversion** - Core depends on ports (abstractions), NOT adapters (concretions)
5. **Symmetry** - Input ports (driving) and output ports (driven) treated equally

Key structure:
```
Core Domain (business logic)
    ↕️ depends on
Ports (interfaces/protocols)
    ↕️ implemented by
Adapters (HTTP, DB, Queue, APIs)
```

Aliases for Hexagonal Architecture:
- **Ports and Adapters**
- **Clean Architecture** (Uncle Bob's variant)
- **Onion Architecture** (similar concept)

Key principle: **Protect the Domain** - Business logic should not know about HTTP, databases, or frameworks.
]])

-- Check for domain/core layer
local domain_patterns = {
  "**/domain/**/*.{ex,rs,ts,js,py}",
  "**/core/**/*.{ex,rs,ts,js,py}",
  "**/business/**/*.{ex,rs,ts,js,py}",
  "**/entities/**/*.{ex,rs,ts,js,py}",
  "**/use_cases/**/*.{ex,rs,ts,js,py}"
}

local domain_files = {}
for _, pattern in ipairs(domain_patterns) do
  local files = workspace.glob(project_root .. "/" .. pattern)
  if files and #files > 0 then
    for _, file in ipairs(files) do
      table.insert(domain_files, file)
    end
  end
end

if #domain_files > 0 then
  prompt:section("DOMAIN_CORE", string.format([[
Found %d files in domain/core layer:
%s

This is the heart of hexagonal architecture - pure business logic.
Should have NO dependencies on frameworks, databases, or HTTP.
]], #domain_files, table.concat(domain_files, function(f) return "  - " .. f end)))
end

-- Check for ports (interfaces/protocols)
local port_patterns = {
  "**/ports/**/*.{ex,rs,ts,js,py}",
  "**/interfaces/**/*.{ex,rs,ts,js,py}",
  "**/protocols/**/*.{ex,rs,ts,js,py}",
  "**/*Port.{ex,rs,ts,js,py}",
  "**/*Protocol.{ex,rs,ts,js,py}",
  "**/*Interface.{ex,rs,ts,js,py}"
}

local port_files = {}
for _, pattern in ipairs(port_patterns) do
  local files = workspace.glob(project_root .. "/" .. pattern)
  if files and #files > 0 then
    for _, file in ipairs(files) do
      table.insert(port_files, file)
    end
  end
end

-- Also check for Elixir behaviours (ports)
local behaviour_files = workspace.grep("@callback", {
  path = project_root,
  file_pattern = "*.ex",
  max_results = 10
})

if behaviour_files and #behaviour_files > 0 then
  for _, file in ipairs(behaviour_files) do
    table.insert(port_files, file.path)
  end
end

if #port_files > 0 then
  prompt:section("PORTS", string.format([[
Found %d port definitions (interfaces/protocols/behaviours):
%s

Ports define HOW the core interacts with outside world (contracts).
]], #port_files, table.concat(port_files, function(f) return "  - " .. f end)))
end

-- Check for adapters
local adapter_patterns = {
  "**/adapters/**/*.{ex,rs,ts,js,py}",
  "**/infrastructure/**/*.{ex,rs,ts,js,py}",
  "**/*Adapter.{ex,rs,ts,js,py}",
  "**/*Repository.{ex,rs,ts,js,py}",
  "**/*Controller.{ex,rs,ts,js,py}",
  "**/*Gateway.{ex,rs,ts,js,py}"
}

local adapter_files = {}
for _, pattern in ipairs(adapter_patterns) do
  local files = workspace.glob(project_root .. "/" .. pattern)
  if files and #files > 0 then
    for _, file in ipairs(files) do
      table.insert(adapter_files, file)
    end
  end
end

if #adapter_files > 0 then
  prompt:section("ADAPTERS", string.format([[
Found %d adapter implementations:
%s

Adapters implement ports - they connect core to external systems (DB, HTTP, APIs).
]], #adapter_files, table.concat(adapter_files, function(f) return "  - " .. f end)))
end

-- Check for dependency inversion (core should NOT import HTTP/DB directly)
local core_to_http = workspace.grep("Plug\\.|Phoenix\\.|HTTPoison", {
  path = project_root .. "/domain",
  file_pattern = "*.ex",
  max_results = 5
})

local core_to_db = workspace.grep("Repo\\.|Ecto\\.Query", {
  path = project_root .. "/domain",
  file_pattern = "*.ex",
  max_results = 5
})

local violation_count = 0
if core_to_http and #core_to_http > 0 then
  violation_count = violation_count + #core_to_http
end
if core_to_db and #core_to_db > 0 then
  violation_count = violation_count + #core_to_db
end

if violation_count > 0 then
  prompt:section("DEPENDENCY_VIOLATIONS", string.format([[
WARNING: Found %d dependency inversion violations!

Domain/core imports HTTP or database libraries directly.
This violates hexagonal architecture (core should only depend on ports/interfaces).
]], violation_count))
end

-- Check for driving adapters (input - HTTP, CLI, queue)
local driving_patterns = {
  "controller",
  "handler",
  "endpoint",
  "cli",
  "consumer"
}

local driving_count = 0
for _, pattern in ipairs(driving_patterns) do
  local files = workspace.grep(pattern, {
    path = project_root .. "/adapters",
    file_pattern = "*.{ex,rs,ts,js}",
    max_results = 5
  })
  if files and #files > 0 then
    driving_count = driving_count + #files
  end
end

if driving_count > 0 then
  prompt:section("DRIVING_ADAPTERS", string.format([[
Found %d driving adapters (input side):

Driving adapters call INTO the core (e.g., HTTP controller receives request → calls use case).
]], driving_count))
end

-- Check for driven adapters (output - database, external APIs)
local driven_patterns = {
  "repository",
  "gateway",
  "client",
  "dao"
}

local driven_count = 0
for _, pattern in ipairs(driven_patterns) do
  local files = workspace.grep(pattern, {
    path = project_root .. "/adapters",
    file_pattern = "*.{ex,rs,ts,js}",
    max_results = 5
  })
  if files and #files > 0 then
    driven_count = driven_count + #files
  end
end

if driven_count > 0 then
  prompt:section("DRIVEN_ADAPTERS", string.format([[
Found %d driven adapters (output side):

Driven adapters are called FROM the core (e.g., use case calls repository port → adapter accesses DB).
]], driven_count))
end

prompt:section("ANALYSIS_CRITERIA", [[
Analyze the evidence above and determine:

1. Is this hexagonal architecture? (true/false)
2. Are ports and adapters clearly separated?
3. Is dependency inversion respected? (core → ports, NOT core → adapters)
4. What evidence supports hexagonal pattern?
5. What's the confidence level? (0.0-1.0)
6. Quality assessment - is hexagonal architecture well-implemented?

Hexagonal Architecture Layers (Inside → Outside):

**Layer 1: Domain Core** (center of hexagon)
- Pure business logic
- Domain entities and value objects
- Use cases (application services)
- NO dependencies on frameworks, HTTP, databases

**Layer 2: Ports** (hexagon edges)
- Interfaces/protocols defining contracts
- Input ports (use case interfaces)
- Output ports (repository interfaces, gateway interfaces)

**Layer 3: Adapters** (outside hexagon)
- Implementations of ports
- HTTP adapters (controllers, handlers)
- Database adapters (repositories, DAOs)
- External API adapters (gateways, clients)
- Message queue adapters (consumers, producers)

Dependency Rule:
- Domain → Ports: ✅ ALLOWED (depend on abstractions)
- Domain → Adapters: ❌ FORBIDDEN (would couple to concretions)
- Adapters → Ports: ✅ ALLOWED (implement interfaces)
- Adapters → Domain: ✅ ALLOWED (call use cases)

Benefits:
- Testability (mock ports, test core in isolation)
- Flexibility (swap adapters without changing core)
- Framework independence (core doesn't depend on Phoenix, Django, etc.)
- Database independence (core doesn't depend on Ecto, Active Record, etc.)

Trade-offs:
- More complex than layered architecture
- Requires discipline (developers must resist coupling core to frameworks)
- More files (interfaces + implementations)
]])

prompt:section("OUTPUT_FORMAT", [[
Return ONLY valid JSON in this exact format:

{
  "pattern_detected": true,
  "pattern_name": "hexagonal_architecture",
  "pattern_type": "architecture",
  "variant": "ports_and_adapters" | "clean_architecture" | "onion_architecture",
  "confidence": 0.88,
  "layers_identified": {
    "domain_core": {
      "file_count": 34,
      "directories": ["domain/", "core/", "use_cases/"],
      "purity": "high",
      "external_dependencies": 0
    },
    "ports": {
      "file_count": 12,
      "directories": ["ports/", "interfaces/"],
      "input_ports": 5,
      "output_ports": 7
    },
    "adapters": {
      "file_count": 28,
      "directories": ["adapters/", "infrastructure/"],
      "driving_adapters": 8,
      "driven_adapters": 20
    }
  },
  "indicators_found": [
    {
      "indicator": "isolated_domain_core",
      "evidence": "Domain layer has 34 files with NO framework dependencies",
      "weight": 0.95,
      "required": true
    },
    {
      "indicator": "port_definitions",
      "evidence": "12 port interfaces defined using @callback behaviours (Elixir)",
      "weight": 0.9,
      "required": true
    },
    {
      "indicator": "adapter_implementations",
      "evidence": "28 adapters implement ports: HTTP controllers, DB repositories, external gateways",
      "weight": 0.85,
      "required": true
    },
    {
      "indicator": "dependency_inversion",
      "evidence": "Domain depends on port abstractions, NOT adapter concretions",
      "weight": 0.9,
      "required": true
    },
    {
      "indicator": "symmetry",
      "evidence": "Both input (driving) and output (driven) adapters present",
      "weight": 0.75,
      "required": false
    }
  ],
  "architecture_quality": {
    "overall_score": 88,
    "domain_purity": 95,
    "dependency_inversion": 90,
    "port_quality": 85,
    "adapter_quality": 82,
    "testability": 92
  },
  "dependency_analysis": {
    "dependency_violations": 0,
    "core_depends_on_frameworks": false,
    "core_depends_on_database": false,
    "adapters_depend_on_core": true,
    "adapters_implement_ports": true
  },
  "ports_breakdown": {
    "input_ports": [
      {"name": "CreateUserUseCase", "type": "driving", "file": "ports/create_user_port.ex"},
      {"name": "GetUserUseCase", "type": "driving", "file": "ports/get_user_port.ex"}
    ],
    "output_ports": [
      {"name": "UserRepository", "type": "driven", "file": "ports/user_repository_port.ex"},
      {"name": "EmailGateway", "type": "driven", "file": "ports/email_gateway_port.ex"}
    ]
  },
  "adapters_breakdown": {
    "driving_adapters": [
      {"name": "UserController", "port": "CreateUserUseCase", "tech": "Phoenix"},
      {"name": "CLIHandler", "port": "GetUserUseCase", "tech": "escript"}
    ],
    "driven_adapters": [
      {"name": "EctoUserRepository", "port": "UserRepository", "tech": "Ecto/PostgreSQL"},
      {"name": "SendGridEmailGateway", "port": "EmailGateway", "tech": "SendGrid API"}
    ]
  },
  "benefits": [
    "Testability: Core can be tested in isolation (mock ports)",
    "Framework independence: No coupling to Phoenix or Ecto",
    "Database independence: Can swap PostgreSQL for MongoDB without changing core",
    "Flexibility: Can add CLI adapter alongside HTTP adapter easily"
  ],
  "concerns": [
    "Some adapters are large (>500 lines) - consider splitting",
    "Missing documentation on which adapter implements which port",
    "No integration tests validating adapter→port contracts"
  ],
  "recommendations": [
    "Add adapter-port mapping documentation",
    "Create contract tests for all port implementations",
    "Consider splitting large adapters into smaller focused ones",
    "Add dependency check in CI to prevent core from importing frameworks",
    "Document port versioning strategy (for breaking changes)"
  ],
  "testability_assessment": {
    "core_testable_in_isolation": true,
    "ports_mockable": true,
    "adapters_replaceable": true,
    "test_coverage": "high"
  },
  "llm_reasoning": "Strong hexagonal architecture detected. Clear separation: domain core (34 files), ports (12 interfaces), adapters (28 implementations). Domain has ZERO framework dependencies - excellent purity. Dependency inversion respected (no violations found). Both driving and driven adapters present. Quality score: 88/100. Confidence: 88% based on clear port/adapter structure and dependency inversion."
}

Do NOT include markdown code fences or explanations.
Just raw JSON.
]])

return prompt:render()
