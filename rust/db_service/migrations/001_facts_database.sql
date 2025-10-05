-- Tool Documentation Index - PostgreSQL Schema
-- Replaces all redb storage with PostgreSQL + NATS JetStream

-- Enable pgvector for semantic search
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================================
-- Framework Detection Patterns (self-learning)
-- ============================================================================
CREATE TABLE IF NOT EXISTS framework_detection_patterns (
  id BIGSERIAL PRIMARY KEY,
  framework_name TEXT NOT NULL,
  framework_type TEXT NOT NULL,
  version_pattern TEXT,

  -- File patterns for detection
  file_patterns JSONB DEFAULT '[]',
  directory_patterns JSONB DEFAULT '[]',
  config_files JSONB DEFAULT '[]',

  -- Commands
  build_command TEXT,
  dev_command TEXT,
  install_command TEXT,
  test_command TEXT,

  -- Metadata
  output_directory TEXT,
  confidence_weight FLOAT DEFAULT 1.0,

  -- Self-learning metrics
  detection_count INTEGER DEFAULT 0,
  success_rate FLOAT DEFAULT 1.0,
  last_detected_at TIMESTAMPTZ,

  -- Vector for semantic similarity
  pattern_embedding vector(768),

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(framework_name, framework_type)
);

CREATE INDEX IF NOT EXISTS framework_detection_patterns_name_idx ON framework_detection_patterns (framework_name);
CREATE INDEX IF NOT EXISTS framework_detection_patterns_type_idx ON framework_detection_patterns (framework_type);
CREATE INDEX IF NOT EXISTS framework_detection_patterns_embedding_idx ON framework_detection_patterns
  USING hnsw (pattern_embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);

-- ============================================================================
-- Tool Documentation (versioned package/tool docs)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tool_documentation (
  id BIGSERIAL PRIMARY KEY,

  -- Identification
  tool TEXT NOT NULL,
  version TEXT NOT NULL,
  ecosystem TEXT NOT NULL,

  -- Core data
  documentation TEXT,
  source TEXT,

  -- Arrays stored as JSONB
  snippets JSONB DEFAULT '[]',
  examples JSONB DEFAULT '[]',
  best_practices JSONB DEFAULT '[]',
  troubleshooting JSONB DEFAULT '[]',
  github_sources JSONB DEFAULT '[]',
  dependencies JSONB DEFAULT '[]',
  tags JSONB DEFAULT '[]',

  -- Tech profile
  detected_framework JSONB,

  -- Prompt templates
  prompt_templates JSONB DEFAULT '[]',
  quick_starts JSONB DEFAULT '[]',
  migration_guides JSONB DEFAULT '[]',
  usage_patterns JSONB DEFAULT '[]',
  cli_commands JSONB DEFAULT '[]',

  -- Embeddings
  semantic_embedding vector(384),
  code_embedding vector(384),

  -- Graph data
  graph_embedding JSONB,
  relationships JSONB DEFAULT '[]',

  -- Learning data
  usage_stats JSONB,
  execution_history JSONB DEFAULT '[]',
  learning_data JSONB,

  -- Security
  vulnerabilities JSONB DEFAULT '[]',
  security_score FLOAT,
  license_info JSONB,

  last_updated TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(tool, version, ecosystem)
);

CREATE INDEX IF NOT EXISTS tool_documentation_tool_idx ON tool_documentation (tool);
CREATE INDEX IF NOT EXISTS tool_documentation_ecosystem_idx ON tool_documentation (ecosystem);
CREATE INDEX IF NOT EXISTS tool_documentation_tool_version_idx ON tool_documentation (tool, version);
CREATE INDEX IF NOT EXISTS tool_documentation_semantic_embedding_idx ON tool_documentation
  USING hnsw (semantic_embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);

-- ============================================================================
-- Project Technology Stack (detected frameworks per project)
-- ============================================================================
CREATE TABLE IF NOT EXISTS project_tech_stack (
  id BIGSERIAL PRIMARY KEY,
  project_path TEXT NOT NULL UNIQUE,
  technologies JSONB NOT NULL DEFAULT '[]',
  detected_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS project_tech_stack_project_idx ON project_tech_stack (project_path);

-- ============================================================================
-- Code Generation Templates (SPARC and custom prompts)
-- ============================================================================
CREATE TABLE IF NOT EXISTS code_generation_templates (
  id BIGSERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  category TEXT NOT NULL, -- 'tutorial', 'quickstart', 'migration', etc.
  variables JSONB DEFAULT '[]',
  confidence FLOAT DEFAULT 1.0,
  framework_version TEXT,
  prerequisites JSONB DEFAULT '[]',

  -- Usage tracking
  usage_count INTEGER DEFAULT 0,
  success_rate FLOAT DEFAULT 1.0,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS code_generation_templates_category_idx ON code_generation_templates (category);
CREATE INDEX IF NOT EXISTS code_generation_templates_framework_idx ON code_generation_templates (framework_version);

-- ============================================================================
-- Code Snippets from GitHub Repos
-- ============================================================================
CREATE TABLE IF NOT EXISTS github_code_snippets (
  id BIGSERIAL PRIMARY KEY,
  repo TEXT NOT NULL,
  file_path TEXT NOT NULL,
  snippet TEXT NOT NULL,
  language TEXT,
  description TEXT,
  line_number INTEGER,
  stars INTEGER DEFAULT 0,

  -- Embedding for semantic search
  snippet_embedding vector(384),

  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(repo, file_path, line_number)
);

CREATE INDEX IF NOT EXISTS github_code_snippets_repo_idx ON github_code_snippets (repo);
CREATE INDEX IF NOT EXISTS github_code_snippets_language_idx ON github_code_snippets (language);
CREATE INDEX IF NOT EXISTS github_code_snippets_embedding_idx ON github_code_snippets
  USING hnsw (snippet_embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);

-- ============================================================================
-- Template A/B Tests (prompt optimization experiments)
-- ============================================================================
CREATE TABLE IF NOT EXISTS template_ab_tests (
  id BIGSERIAL PRIMARY KEY,
  test_name TEXT NOT NULL,
  variant_a TEXT NOT NULL,
  variant_b TEXT NOT NULL,

  -- Results
  variant_a_success INTEGER DEFAULT 0,
  variant_a_total INTEGER DEFAULT 0,
  variant_b_success INTEGER DEFAULT 0,
  variant_b_total INTEGER DEFAULT 0,

  -- Metadata
  status TEXT DEFAULT 'running', -- 'running', 'completed', 'paused'
  winner TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,

  UNIQUE(test_name)
);

CREATE INDEX IF NOT EXISTS template_ab_tests_status_idx ON template_ab_tests (status);

-- ============================================================================
-- User Feedback on Code Generation
-- ============================================================================
CREATE TABLE IF NOT EXISTS generation_feedback (
  id BIGSERIAL PRIMARY KEY,

  -- Context
  tool_key TEXT NOT NULL, -- "tool:version:ecosystem"
  template_id BIGINT REFERENCES code_generation_templates(id),

  -- Feedback
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  helpful BOOLEAN,
  comments TEXT,

  -- Generated output
  generated_code TEXT,
  user_modifications TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS generation_feedback_tool_key_idx ON generation_feedback (tool_key);
CREATE INDEX IF NOT EXISTS generation_feedback_rating_idx ON generation_feedback (rating);
CREATE INDEX IF NOT EXISTS generation_feedback_helpful_idx ON generation_feedback (helpful);

-- ============================================================================
-- Seed Data - Framework Detection Patterns
-- ============================================================================
INSERT INTO framework_detection_patterns (
  framework_name, framework_type,
  file_patterns, directory_patterns, config_files,
  build_command, dev_command, install_command,
  output_directory, confidence_weight
) VALUES

-- React
('react', 'frontend',
 '["*.jsx", "*.tsx"]'::jsonb,
 '["src/components", "public"]'::jsonb,
 '["package.json"]'::jsonb,
 'npm run build', 'npm start', 'npm install',
 'build', 0.8),

-- Vue
('vue', 'frontend',
 '["*.vue"]'::jsonb,
 '["src/components"]'::jsonb,
 '["package.json", "vue.config.js"]'::jsonb,
 'npm run build', 'npm run serve', 'npm install',
 'dist', 0.9),

-- Next.js
('nextjs', 'fullstack',
 '["*.tsx", "*.jsx"]'::jsonb,
 '["pages", "app"]'::jsonb,
 '["next.config.js", "next.config.mjs"]'::jsonb,
 'next build', 'next dev', 'npm install',
 '.next', 0.7),

-- Django
('django', 'backend',
 '["*.py"]'::jsonb,
 '["app", "apps"]'::jsonb,
 '["manage.py", "settings.py"]'::jsonb,
 NULL, 'python manage.py runserver', 'pip install -r requirements.txt',
 NULL, 0.8),

-- Flask
('flask', 'backend',
 '["*.py"]'::jsonb,
 '["templates", "static"]'::jsonb,
 '["app.py", "wsgi.py"]'::jsonb,
 NULL, 'flask run', 'pip install -r requirements.txt',
 NULL, 0.6),

-- FastAPI
('fastapi', 'backend',
 '["*.py"]'::jsonb,
 '["app", "api"]'::jsonb,
 '["main.py"]'::jsonb,
 NULL, 'uvicorn main:app --reload', 'pip install -r requirements.txt',
 NULL, 0.5),

-- Rust
('rust', 'backend',
 '["*.rs"]'::jsonb,
 '["src"]'::jsonb,
 '["Cargo.toml"]'::jsonb,
 'cargo build', 'cargo run', 'cargo install',
 'target', 0.9),

-- Phoenix (Elixir)
('phoenix', 'fullstack',
 '["*.ex", "*.exs"]'::jsonb,
 '["lib", "priv", "test"]'::jsonb,
 '["mix.exs", "config/config.exs"]'::jsonb,
 'mix phx.digest', 'mix phx.server', 'mix deps.get',
 'priv/static', 0.8),

-- Go
('go', 'backend',
 '["*.go"]'::jsonb,
 '["cmd", "pkg", "internal"]'::jsonb,
 '["go.mod"]'::jsonb,
 'go build', 'go run .', 'go mod download',
 'bin', 0.9)

ON CONFLICT (framework_name, framework_type) DO NOTHING;
