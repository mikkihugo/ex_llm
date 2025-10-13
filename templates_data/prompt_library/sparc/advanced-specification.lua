-- SPARC Specification Generator (Advanced with Dynamic Context)
--
-- This Lua script demonstrates dynamic prompt building with:
-- - File reading (README.md, docs)
-- - Git history integration
-- - Conditional context loading
-- - Sub-prompts for analysis
--
-- Usage:
--   LLM.Service.call_with_script("sparc-specification-advanced.lua", %{
--     requirements: "Build distributed chat system",
--     project_root: "/home/user/myproject"
--   })

local prompt = Prompt.new()

-- 1. Always include requirements
prompt:section("REQUIREMENTS", ctx.requirements or "No requirements provided")

-- 2. Dynamically read project README if it exists
if workspace.file_exists("README.md") then
  local readme = workspace.read_file("README.md")
  if readme then
    prompt:section("PROJECT_CONTEXT", readme)
  end
end

-- 3. Check for distributed system patterns
local requirements_lower = string.lower(ctx.requirements or "")
local is_distributed = string.find(requirements_lower, "distributed")
                    or string.find(requirements_lower, "microservice")
                    or string.find(requirements_lower, "nats")

if is_distributed then
  prompt:instruction("🔧 Detected distributed system requirements")

  -- Read architecture docs if available
  if workspace.file_exists("docs/architecture.md") then
    local arch_doc = workspace.read_file("docs/architecture.md")
    if arch_doc then
      prompt:section("EXISTING_ARCHITECTURE", arch_doc)
    end
  end

  -- Read NATS documentation if available
  if workspace.file_exists("NATS_SUBJECTS.md") then
    local nats_doc = workspace.read_file("NATS_SUBJECTS.md")
    if nats_doc then
      prompt:section("NATS_PATTERNS", nats_doc)
    end
  end

  prompt:instruction([[
This is a distributed system. Consider:
- Service boundaries and domain separation
- Message passing patterns (NATS subjects)
- Failure modes and circuit breakers
- Data consistency across services
- Backpressure and rate limiting
  ]])
end

-- 4. Get recent git history for context
local git_commits = git.log({max_count = 5})
if git_commits and #git_commits > 0 then
  local commit_text = table.concat(git_commits, "\n")
  prompt:section("RECENT_WORK", commit_text)
  prompt:instruction("Recent development context shows ongoing work - ensure new design integrates with these changes")
end

-- 5. Find existing Elixir modules (basic pattern matching)
local elixir_files = workspace.glob("lib/**/*.ex")
if elixir_files and #elixir_files > 0 then
  -- Sample a few files for analysis (don't overload context)
  local sample_count = math.min(3, #elixir_files)

  prompt:instruction("Existing codebase modules:")
  for i = 1, sample_count do
    local file_path = elixir_files[i]
    prompt:bullet(file_path)
  end

  prompt:instruction([[
When designing new components:
- Follow existing naming conventions
- Integrate with current architecture
- Avoid duplicating functionality
- Maintain consistency with patterns already in use
  ]])
end

-- 6. Main SPARC specification task
prompt:instruction([[

Generate a detailed SPARC specification with:

## 1. Clear Objectives and Scope

- Primary goals and success criteria
- In-scope features and functionality
- Out-of-scope items (what we're NOT building)
- Stakeholders and their needs

## 2. Functional Requirements

- User-facing features
- System behaviors
- Business logic
- Data flows

## 3. Non-Functional Requirements

- Performance targets (latency, throughput)
- Scalability expectations
- Security requirements
- Reliability and availability (SLOs)

## 4. Constraints and Assumptions

- Technical constraints (languages, frameworks, infrastructure)
- Business constraints (timeline, budget, resources)
- Assumptions about users, data, environment

## 5. Success Criteria

- Measurable outcomes
- Acceptance criteria
- Definition of done

## 6. Risk Assessment

- Technical risks and mitigations
- Integration risks
- Performance risks
- Security risks

Structure your response as:
=== ANALYSIS ===
[Your analysis and reasoning]

=== FILES ===
[File operations if needed - use structured format]

=== SUMMARY ===
[Summary of the specification]
]])

return prompt
