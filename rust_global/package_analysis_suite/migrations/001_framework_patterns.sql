-- Framework detection patterns (self-learning)
CREATE TABLE IF NOT EXISTS framework_patterns (
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

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS framework_patterns_name_idx
  ON framework_patterns (framework_name);

CREATE INDEX IF NOT EXISTS framework_patterns_type_idx
  ON framework_patterns (framework_type);

-- Vector similarity search
CREATE INDEX IF NOT EXISTS framework_patterns_embedding_idx
  ON framework_patterns USING hnsw (pattern_embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

-- Seed initial patterns from hardcoded knowledge
INSERT INTO framework_patterns (
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

-- Angular
('angular', 'frontend',
 '["*.component.ts", "*.module.ts"]'::jsonb,
 '["src/app"]'::jsonb,
 '["angular.json"]'::jsonb,
 'ng build', 'ng serve', 'npm install',
 'dist', 0.8),

-- Next.js
('nextjs', 'fullstack',
 '["*.tsx", "*.jsx"]'::jsonb,
 '["pages", "app"]'::jsonb,
 '["next.config.js", "next.config.mjs"]'::jsonb,
 'next build', 'next dev', 'npm install',
 '.next', 0.7),

-- Nuxt.js
('nuxtjs', 'fullstack',
 '["*.vue"]'::jsonb,
 '["pages", "layouts"]'::jsonb,
 '["nuxt.config.js", "nuxt.config.ts"]'::jsonb,
 'nuxt build', 'nuxt dev', 'npm install',
 '.nuxt', 0.8),

-- Svelte
('svelte', 'frontend',
 '["*.svelte"]'::jsonb,
 '["src"]'::jsonb,
 '["svelte.config.js"]'::jsonb,
 'npm run build', 'npm run dev', 'npm install',
 'public', 0.9),

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
