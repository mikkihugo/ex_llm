-- Architecture: Framework Version Detection
-- Detects specific framework version by analyzing lock files and code patterns

-- Extract context
local framework_name = context.framework_name
local known_versions = context.known_versions or {}
local project_root = context.project_root or "."

-- Build the detection prompt
local prompt = Prompt.new()

prompt:section("TASK", string.format([[
You are detecting the specific version of %s in this codebase.
Analyze lock files, dependencies, and code patterns.
Return JSON with version and confidence.
]], framework_name))

prompt:section("FRAMEWORK", "Framework: " .. framework_name)

if #known_versions > 0 then
  prompt:section("KNOWN_VERSIONS", "Known versions in database:\n" .. table.concat(known_versions, ", "))
end

-- Read lock files for exact versions (MOST ACCURATE)
local lock_files = {
  {file = "package-lock.json", extract = function(content)
    -- Extract framework version from package-lock.json
    local pattern = '"' .. framework_name:lower() .. '":%s*{[^}]*"version":%s*"([^"]+)"'
    return content:match(pattern)
  end},
  {file = "yarn.lock", extract = function(content)
    local pattern = framework_name:lower() .. '@[^:]*:\n%s*version%s+"([^"]+)"'
    return content:match(pattern)
  end},
  {file = "pnpm-lock.yaml", extract = function(content)
    local pattern = framework_name:lower() .. "%(([^%)]+)%)"
    return content:match(pattern)
  end},
  {file = "mix.lock", extract = function(content)
    local pattern = '":' .. framework_name:lower() .. '"[^}]*{:hex,%s*:' .. framework_name:lower() .. ',%s*"([^"]+)"'
    return content:match(pattern)
  end},
  {file = "Cargo.lock", extract = function(content)
    local pattern = 'name%s*=%s*"' .. framework_name:lower() .. '"%s*version%s*=%s*"([^"]+)"'
    return content:match(pattern)
  end},
  {file = "poetry.lock", extract = function(content)
    local pattern = '%[%[package%]%][^%[]*name%s*=%s*"' .. framework_name:lower() .. '"[^%[]*version%s*=%s*"([^"]+)"'
    return content:match(pattern)
  end}
}

local found_version_in_lock = nil
local lock_file_used = nil

for _, lock_info in ipairs(lock_files) do
  local full_path = project_root .. "/" .. lock_info.file
  if workspace.file_exists(full_path) then
    local content = workspace.read_file(full_path)
    if content then
      local version = lock_info.extract(content)
      if version then
        found_version_in_lock = version
        lock_file_used = lock_info.file
        prompt:section("LOCK_FILE_VERSION", string.format([[
Found in %s:
Version: %s
(MOST RELIABLE - This is the exact installed version)
]], lock_file_used, found_version_in_lock))
        break
      end
    end
  end
end

if not found_version_in_lock then
  prompt:section("LOCK_FILE_VERSION", "No lock file found or version not extracted")
end

-- Read package manager manifest for version constraint
local manifests = {
  {file = "package.json", field = "dependencies"},
  {file = "mix.exs", pattern = '{:' .. framework_name:lower() .. ',%s*"([^"]+)"}'},
  {file = "Cargo.toml", pattern = framework_name:lower() .. '%s*=%s*"([^"]+)"'},
  {file = "pyproject.toml", pattern = framework_name:lower() .. '%s*=%s*"([^"]+)"'}
}

local version_constraint = nil
for _, manifest_info in ipairs(manifests) do
  local full_path = project_root .. "/" .. manifest_info.file
  if workspace.file_exists(full_path) then
    local content = workspace.read_file(full_path)
    if content then
      if manifest_info.pattern then
        version_constraint = content:match(manifest_info.pattern)
      elseif manifest_info.field and content:find('"' .. framework_name:lower() .. '"') then
        -- JSON parsing for package.json
        local pattern = '"' .. framework_name:lower() .. '"%s*:%s*"([^"]+)"'
        version_constraint = content:match(pattern)
      end

      if version_constraint then
        prompt:section("VERSION_CONSTRAINT", string.format([[
From %s:
Constraint: %s
(This is the requested version range)
]], manifest_info.file, version_constraint))
        break
      end
    end
  end
end

-- Scan code for version-specific patterns
local version_patterns = {
  -- Phoenix
  {pattern = '~p"', indicates = "Phoenix 1.7+ (verified routes)"},
  {pattern = "Phoenix%.VerifiedRoutes", indicates = "Phoenix 1.7+"},
  {pattern = "Routes%.[a-z_]+_path", indicates = "Phoenix 1.6 or earlier"},
  {pattern = "Phoenix%.LiveView%.JS", indicates = "Phoenix 1.7+"},
  {pattern = "Phoenix%.Component", indicates = "Phoenix 1.7+"},
  -- Next.js
  {pattern = "'use client'", indicates = "Next.js 13+ (RSC directives)"},
  {pattern = "'use server'", indicates = "Next.js 13+ (Server Actions)"},
  {pattern = "app/", indicates = "Next.js 13+ (App Router)"},
  {pattern = "pages/", indicates = "Next.js 12 or earlier (Pages Router)"},
  -- FastAPI
  {pattern = "model_config%s*=%s*ConfigDict", indicates = "FastAPI 0.100+ (Pydantic v2)"},
  {pattern = "class%s+Config:", indicates = "FastAPI <0.100 (Pydantic v1)"},
  -- React
  {pattern = "React%.FC", indicates = "React <18"},
  {pattern = "import%s+{%s*useTransition%s*}", indicates = "React 18+"}
}

local found_patterns = {}
local source_files = workspace.glob(project_root .. "/**/*.{ex,exs,js,ts,jsx,tsx,py,rs,rb}")
if source_files and #source_files > 0 then
  local checked = 0
  for _, file in ipairs(source_files) do
    if checked >= 20 then break end  -- Limit search
    local content = workspace.read_file(file)
    if content then
      for _, pattern_info in ipairs(version_patterns) do
        if content:match(pattern_info.pattern) then
          table.insert(found_patterns, string.format(
            "- Pattern: %s → %s (in %s)",
            pattern_info.pattern, pattern_info.indicates, file
          ))
        end
      end
      checked = checked + 1
    end
  end
end

if #found_patterns > 0 then
  prompt:section("CODE_PATTERNS", table.concat(found_patterns, "\n"))
else
  prompt:section("CODE_PATTERNS", "No version-specific code patterns found")
end

-- Check changelog or migration files
local doc_files = {"CHANGELOG.md", "CHANGES.md", "UPGRADING.md", "MIGRATION.md"}
for _, doc_file in ipairs(doc_files) do
  local full_path = project_root .. "/" .. doc_file
  if workspace.file_exists(full_path) then
    local content = workspace.read_file(full_path)
    if content then
      -- Extract first 500 chars (usually has recent version)
      prompt:section("CHANGELOG", string.format([[
From %s (first 500 chars):
%s
]], doc_file, content:sub(1, 500)))
      break
    end
  end
end

-- Provide analysis instructions
prompt:instruction("Determine the specific version of " .. framework_name)
prompt:instruction("Priority order:")
prompt:bullet("Lock file version (MOST RELIABLE if found)")
prompt:bullet("Version constraint from manifest")
prompt:bullet("Code patterns")
prompt:bullet("Changelog/migration guides")

prompt:section("OUTPUT_FORMAT", [[
Return ONLY valid JSON in this format:
{
  "version": "string (e.g., '1.7.10', '2.0', '0.100+') or null",
  "confidence": 0.95,
  "reasoning": "Why this version? What evidence supports it?",
  "indicators": [
    {"pattern": "~p sigil", "indicates_version": "1.7+"},
    {"pattern": "mix.lock shows 1.7.10", "indicates_version": "1.7.10"}
  ],
  "ambiguities": [
    "Cannot distinguish between 0.100-0.109 without more features"
  ]
}

Confidence guidelines:
- 0.95-1.0: Lock file exact version
- 0.85-0.94: Strong patterns + version constraint match
- 0.70-0.84: Some patterns, unclear exact version
- <0.70: Cannot determine (return null)

Do NOT include markdown code fences or explanations.
Just raw JSON.
]])

return prompt
