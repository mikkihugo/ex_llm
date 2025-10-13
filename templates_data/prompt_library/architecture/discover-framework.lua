-- Architecture: Framework Discovery
-- Context-aware framework detection by analyzing codebase files

-- Extract context
local suspected_framework = context.framework_name or "unknown"
local project_root = context.project_root or "."

-- Build the discovery prompt
local prompt = Prompt.new()

prompt:section("TASK", [[
You are analyzing a codebase to identify the framework being used.
Return your findings in JSON format with detection patterns and metadata.
]])

prompt:section("SUSPECTED_FRAMEWORK", "Framework name (suspected): " .. suspected_framework)

-- Read package manager files
local package_files = {
  {path = "package.json", ecosystem = "npm"},
  {path = "mix.exs", ecosystem = "hex"},
  {path = "Cargo.toml", ecosystem = "cargo"},
  {path = "pyproject.toml", ecosystem = "pypi"},
  {path = "pom.xml", ecosystem = "maven"},
  {path = "build.gradle", ecosystem = "gradle"}
}

local found_packages = {}
for _, pkg in ipairs(package_files) do
  local full_path = project_root .. "/" .. pkg.path
  if workspace.file_exists(full_path) then
    local content = workspace.read_file(full_path)
    if content then
      table.insert(found_packages, string.format([[
Package Manager: %s
File: %s
Content (first 1000 chars):
%s
]], pkg.ecosystem, pkg.path, content:sub(1, 1000)))
    end
  end
end

if #found_packages > 0 then
  prompt:section("PACKAGE_MANAGER_FILES", table.concat(found_packages, "\n---\n"))
else
  prompt:section("PACKAGE_MANAGER_FILES", "No package manager files found")
end

-- Read lock files for exact versions
local lock_files = {
  "package-lock.json", "yarn.lock", "pnpm-lock.yaml",
  "mix.lock", "Cargo.lock", "poetry.lock", "Pipfile.lock"
}

local found_locks = {}
for _, lock_file in ipairs(lock_files) do
  local full_path = project_root .. "/" .. lock_file
  if workspace.file_exists(full_path) then
    local content = workspace.read_file(full_path)
    if content then
      table.insert(found_locks, string.format([[
Lock file: %s
Content (first 500 chars):
%s
]], lock_file, content:sub(1, 500)))
    end
  end
end

if #found_locks > 0 then
  prompt:section("LOCK_FILES", table.concat(found_locks, "\n---\n"))
end

-- Check for framework-specific config files
local config_patterns = {
  -- JavaScript/TypeScript
  "next.config.*", "vite.config.*", "svelte.config.*", "nuxt.config.*",
  "remix.config.*", "astro.config.*",
  -- Python
  "manage.py", "wsgi.py", "asgi.py", "settings.py",
  -- Elixir
  "config/config.exs", "mix.exs", "lib/*_web/*",
  -- Rust
  "Rocket.toml", "actix.toml",
  -- Ruby
  "config.ru", "Gemfile"
}

local found_configs = {}
for _, pattern in ipairs(config_patterns) do
  local files = workspace.glob(project_root .. "/" .. pattern)
  if files and #files > 0 then
    for _, file in ipairs(files) do
      if #found_configs < 10 then  -- Limit to avoid overwhelming
        table.insert(found_configs, file)
      end
    end
  end
end

if #found_configs > 0 then
  prompt:section("CONFIG_FILES_FOUND", table.concat(found_configs, "\n"))
end

-- Read key source files for import analysis
local source_patterns = {
  "*.js", "*.ts", "*.jsx", "*.tsx",  -- JavaScript/TypeScript
  "*.ex", "*.exs",                    -- Elixir
  "*.rs",                             -- Rust
  "*.py",                             -- Python
  "*.rb"                              -- Ruby
}

local sample_imports = {}
for _, pattern in ipairs(source_patterns) do
  local files = workspace.glob(project_root .. "/" .. pattern)
  if files and #files > 0 and #files <= 5 then  -- Only if manageable number
    for _, file in ipairs(files) do
      local content = workspace.read_file(file)
      if content then
        -- Extract first 20 lines (usually contains imports)
        local lines = {}
        for line in content:gmatch("[^\n]+") do
          table.insert(lines, line)
          if #lines >= 20 then break end
        end

        table.insert(sample_imports, string.format([[
File: %s
Imports/uses:
%s
]], file, table.concat(lines, "\n")))

        if #sample_imports >= 3 then break end  -- Max 3 samples
      end
    end
    if #sample_imports >= 3 then break end
  end
end

if #sample_imports > 0 then
  prompt:section("IMPORT_PATTERNS", table.concat(sample_imports, "\n---\n"))
end

-- Check directory structure
local common_dirs = {
  "src/", "lib/", "app/", "pages/", "components/",
  "config/", "public/", "static/", "assets/",
  "test/", "tests/", "spec/"
}

local found_dirs = {}
for _, dir in ipairs(common_dirs) do
  local test_file = project_root .. "/" .. dir .. "README.md"
  -- Check if directory exists by trying to list it
  local files = workspace.glob(project_root .. "/" .. dir .. "*")
  if files and #files > 0 then
    table.insert(found_dirs, dir)
  end
end

if #found_dirs > 0 then
  prompt:section("DIRECTORY_STRUCTURE", "Directories found:\n" .. table.concat(found_dirs, "\n"))
end

-- Check git history for framework mentions
local git_commits = git.log({max_count = 10, grep = "upgrade|update|add|install"})
if git_commits and #git_commits > 0 then
  prompt:section("RECENT_CHANGES", table.concat(git_commits, "\n\n"))
end

-- Provide analysis instructions
prompt:instruction("Analyze the provided codebase information to identify the framework")
prompt:instruction("Consider:")
prompt:bullet("Package manager dependencies")
prompt:bullet("Lock file versions (most accurate)")
prompt:bullet("Config file patterns")
prompt:bullet("Import patterns in source files")
prompt:bullet("Directory structure")
prompt:bullet("Recent changes in git history")

prompt:section("OUTPUT_FORMAT", [[
Return ONLY valid JSON in this exact format:
{
  "framework": {
    "name": "string (e.g., 'Phoenix', 'Next.js', 'FastAPI')",
    "version": "string or null (e.g., '1.7.10', '13.4.0')",
    "category": "web|mobile|desktop|cli|library",
    "ecosystem": "npm|hex|cargo|pypi|maven",
    "confidence": 0.95
  },
  "detection": {
    "config_files": [
      {"file": "mix.exs", "weight": 0.9, "required": true}
    ],
    "import_patterns": [
      {"pattern": "use Phoenix.Controller", "weight": 0.8, "example": "use Phoenix.Controller, ...."}
    ],
    "code_patterns": [
      {"pattern": "Phoenix.Router usage", "weight": 0.7, "example": "get /users/:id, ..."}
    ],
    "directory_structure": [
      {"path": "lib/*_web/", "weight": 0.6, "optional": false}
    ]
  },
  "dependencies": {
    "required": [
      {"name": "phoenix", "version_constraint": "~> 1.7", "ecosystem": "hex"}
    ],
    "optional": [
      {"name": "phoenix_live_view", "version_constraint": "~> 0.20", "purpose": "LiveView support"}
    ]
  },
  "version_features": {
    "major_version": "1.7",
    "breaking_changes": ["Verified routes", "Components API"],
    "new_features": ["Streams", "Async assigns"],
    "deprecated_patterns": ["Old live_render syntax"]
  },
  "code_snippets": [
    {
      "name": "Basic Controller",
      "description": "Standard Phoenix 1.7 controller",
      "code": "defmodule MyAppWeb.UserController do ...",
      "file_path": "lib/my_app_web/controllers/user_controller.ex",
      "is_best_practice": true
    }
  ],
  "metadata": {
    "homepage": "https://www.phoenixframework.org",
    "documentation": "https://hexdocs.pm/phoenix",
    "repository": "https://github.com/phoenixframework/phoenix",
    "license": "MIT"
  },
  "llm_notes": {
    "confidence_reasoning": "Why this confidence score?",
    "version_detection_method": "How did you determine the version?",
    "ambiguities": ["What was unclear or could use human review?"]
  }
}

Do NOT include markdown code fences or explanations.
Just raw JSON.
]])

return prompt
