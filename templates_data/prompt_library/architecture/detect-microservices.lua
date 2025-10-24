-- Architecture Pattern Detection: Microservices
-- Analyzes codebase to detect microservices architecture pattern
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

prompt:add("# Architecture Pattern Detection: Microservices")
prompt:add("")

prompt:section("ROLE", [[
You are the Pattern Analyst on the Architecture LLM Team.
Your specialty is discovering architecture patterns through deep code analysis.
Focus: Identifying microservices architecture patterns.
]])

prompt:section("TASK", [[
Analyze this codebase and determine if it uses Microservices architecture.

Microservices indicators:
1. Multiple independent services (each with own directory/repo)
2. Each service has clear API boundaries (REST, gRPC, GraphQL)
3. Services communicate via APIs or message queue
4. Each service can be deployed independently
5. May use API gateway or service mesh
6. Often uses containerization (Docker, Kubernetes)
7. May use service discovery (Consul, Eureka, Kubernetes DNS)
8. Separate databases per service (or shared with clear boundaries)
]])

-- Scan for service directories
local service_patterns = {
  "*/package.json",     -- Node.js services
  "*/Cargo.toml",       -- Rust services
  "*/mix.exs",          -- Elixir services
  "*/pyproject.toml",   -- Python services
  "*/go.mod",           -- Go services
  "services/*/",        -- Explicit service directory
  "apps/*/",            -- Apps directory
  "packages/*/"         -- Packages directory
}

local detected_services = {}
for _, pattern in ipairs(service_patterns) do
  local full_pattern = project_root .. "/" .. pattern
  local files = workspace.glob(full_pattern)
  if files and #files > 0 then
    for _, file in ipairs(files) do
      -- Extract service name from path
      local service_name = file:match("([^/]+)/[^/]+$") or file:match("([^/]+)/$")
      if service_name and not detected_services[service_name] then
        detected_services[service_name] = file
      end
    end
  end
end

local service_count = 0
local service_list = {}
for name, path in pairs(detected_services) do
  service_count = service_count + 1
  table.insert(service_list, string.format("  - %s (%s)", name, path))
end

if service_count > 0 then
  prompt:section("DETECTED_SERVICES", string.format([[
Found %d potential services:
%s
]], service_count, table.concat(service_list, "\n")))
end

-- Check for API definitions
local api_patterns = {
  "**/*openapi*.{yaml,yml,json}",
  "**/*swagger*.{yaml,yml,json}",
  "**/api/*.{yaml,yml,json}",
  "**/*.proto"  -- gRPC proto files
}

local api_files = {}
for _, pattern in ipairs(api_patterns) do
  local files = workspace.glob(project_root .. "/" .. pattern)
  if files and #files > 0 then
    for _, file in ipairs(files) do
      table.insert(api_files, "  - " .. file)
    end
  end
end

if #api_files > 0 then
  prompt:section("API_DEFINITIONS", string.format([[
Found %d API definition files:
%s
]], #api_files, table.concat(api_files, "\n")))
end

-- Check for containerization
local docker_files = {}
local dockerfile_pattern = project_root .. "/**/Dockerfile*"
local files = workspace.glob(dockerfile_pattern)
if files and #files > 0 then
  for _, file in ipairs(files) do
    table.insert(docker_files, "  - " .. file)
  end
end

if #docker_files > 0 then
  prompt:section("CONTAINERIZATION", string.format([[
Found %d Dockerfile(s):
%s
]], #docker_files, table.concat(docker_files, "\n")))
end

-- Check for kubernetes
local k8s_files = workspace.glob(project_root .. "/**/k8s/**/*.{yaml,yml}")
if k8s_files and #k8s_files > 0 then
  prompt:section("KUBERNETES", string.format("Found %d Kubernetes manifest files", #k8s_files))
end

-- Check for message queue/event bus
local messaging_patterns = {
  "nats", "kafka", "rabbitmq", "redis", "sqs", "pubsub",
  "event.bus", "message.queue"
}

local messaging_files = {}
for _, pattern in ipairs(messaging_patterns) do
  local files = workspace.grep(pattern, {
    path = project_root,
    file_pattern = "*.{ex,rs,ts,js,py,go}",
    max_results = 5
  })
  if files and #files > 0 then
    for _, file in ipairs(files) do
      table.insert(messaging_files, "  - " .. file.path)
    end
  end
end

if #messaging_files > 0 then
  prompt:section("MESSAGING", string.format([[
Message queue/event bus usage detected:
%s
]], table.concat(messaging_files, "\n")))
end

-- Check for API gateway
local gateway_patterns = {"nginx", "traefik", "kong", "api.gateway"}
local gateway_found = false
for _, pattern in ipairs(gateway_patterns) do
  local files = workspace.grep(pattern, {
    path = project_root,
    file_pattern = "*.{conf,yaml,yml,json}",
    max_results = 3
  })
  if files and #files > 0 then
    gateway_found = true
    break
  end
end

if gateway_found then
  prompt:section("API_GATEWAY", "API Gateway configuration detected (nginx, traefik, kong, etc.)")
end

prompt:section("ANALYSIS_CRITERIA", [[
Analyze the evidence above and determine:

1. Is this a microservices architecture? (true/false)
2. How many services are there?
3. What evidence supports microservices?
4. What's the confidence level? (0.0-1.0)
5. Is it production-ready?
6. What concerns or gaps exist?
]])

prompt:section("OUTPUT_FORMAT", [[
Return ONLY valid JSON in this exact format:

{
  "pattern_detected": true,
  "pattern_name": "microservices",
  "confidence": 0.92,
  "service_count": 4,
  "services": [
    {
      "name": "rust/code_engine",
      "language": "rust",
      "api_type": "gRPC",
      "has_dockerfile": true,
      "has_api_spec": true
    },
    {
      "name": "llm-server",
      "language": "typescript",
      "api_type": "REST",
      "has_dockerfile": true,
      "has_api_spec": false
    }
  ],
  "indicators_found": [
    {
      "indicator": "multiple_services",
      "evidence": "4 services detected with separate build configs",
      "weight": 0.9,
      "required": true
    },
    {
      "indicator": "api_boundaries",
      "evidence": "OpenAPI specs found, gRPC proto files",
      "weight": 0.85,
      "required": true
    },
    {
      "indicator": "independent_deployment",
      "evidence": "Each service has own Dockerfile",
      "weight": 0.8,
      "required": false
    },
    {
      "indicator": "inter_service_communication",
      "evidence": "NATS used for async messaging between services",
      "weight": 0.75,
      "required": false
    },
    {
      "indicator": "containerization",
      "evidence": "Docker, Kubernetes manifests found",
      "weight": 0.7,
      "required": false
    }
  ],
  "architecture_quality": {
    "overall_score": 88,
    "service_boundaries": 92,
    "api_design": 85,
    "deployment_independence": 90,
    "observability": 75,
    "resilience": 70
  },
  "production_ready": true,
  "concerns": [
    "No service mesh detected (consider Istio, Linkerd)",
    "Missing distributed tracing setup (Jaeger, Zipkin)",
    "Circuit breaker pattern not clearly implemented"
  ],
  "recommendations": [
    "Add service mesh for better traffic management and observability",
    "Implement distributed tracing for debugging across services",
    "Add circuit breakers using libraries like Fuse (Elixir) or resilience4j",
    "Consider API gateway if not already using one"
  ],
  "benefits": [
    "Independent scaling of services",
    "Technology diversity (Rust, TypeScript, Elixir)",
    "Fault isolation between services",
    "Independent deployment and release cycles"
  ],
  "llm_reasoning": "Strong microservices pattern detected. Multiple independent services (4 detected), clear API boundaries with OpenAPI/gRPC, containerization with Docker, and inter-service communication via NATS. Missing some production hardening (service mesh, distributed tracing, circuit breakers) but overall well-architected. Confidence: 92% based on clear evidence of core microservices characteristics."
}

Do NOT include markdown code fences or explanations.
Just raw JSON.
]])

return prompt:render()
