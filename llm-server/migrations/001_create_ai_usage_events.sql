-- AI Usage Tracking Table
-- Stores comprehensive usage data for all AI provider requests

CREATE TABLE IF NOT EXISTS ai_usage_events (
  id BIGSERIAL PRIMARY KEY,

  -- Request identification
  request_id TEXT NOT NULL,
  session_id TEXT,
  user_id TEXT,

  -- Model information
  provider TEXT NOT NULL,
  model_id TEXT NOT NULL,
  model_version TEXT,

  -- Usage metrics
  prompt_tokens INTEGER NOT NULL CHECK (prompt_tokens >= 0),
  completion_tokens INTEGER NOT NULL CHECK (completion_tokens >= 0),
  total_tokens INTEGER NOT NULL CHECK (total_tokens >= 0),

  -- Performance metrics
  duration_ms INTEGER NOT NULL CHECK (duration_ms >= 0),
  time_to_first_token INTEGER CHECK (time_to_first_token >= 0),
  tokens_per_second DECIMAL(10, 2) CHECK (tokens_per_second >= 0),

  -- Cost tracking
  cost_tier TEXT NOT NULL CHECK (cost_tier IN ('free', 'limited', 'pay-per-use')),
  estimated_cost DECIMAL(10, 4) CHECK (estimated_cost >= 0),

  -- Request metadata
  task_type TEXT NOT NULL CHECK (task_type IN (
    'chat',           -- General chat/conversation
    'code',           -- Code generation/completion
    'analysis',       -- Code analysis/review
    'debugging',      -- Debugging/error fixing
    'refactoring',    -- Code refactoring
    'documentation',  -- Doc generation
    'testing',        -- Test generation
    'explanation',    -- Code explanation
    'translation',    -- Language/format translation
    'search',         -- Semantic search
    'embedding',      -- Embedding generation
    'other'           -- Other tasks
  )),
  complexity TEXT NOT NULL CHECK (complexity IN ('simple', 'medium', 'complex')),
  had_tools BOOLEAN NOT NULL DEFAULT FALSE,
  had_vision BOOLEAN NOT NULL DEFAULT FALSE,
  had_reasoning BOOLEAN NOT NULL DEFAULT FALSE,

  -- Model selection metadata (for learning optimal choices)
  was_auto_selected BOOLEAN NOT NULL DEFAULT FALSE,
  selection_reason TEXT,  -- Why this model was chosen
  alternative_models TEXT[], -- Other models considered

  -- Success/failure tracking
  success BOOLEAN NOT NULL DEFAULT TRUE,
  error_type TEXT,
  error_message TEXT,

  -- Timestamps
  started_at TIMESTAMPTZ NOT NULL,
  completed_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT duration_valid CHECK (completed_at >= started_at),
  CONSTRAINT tokens_sum_valid CHECK (total_tokens = prompt_tokens + completion_tokens)
);

-- Indexes for common queries

-- Provider + model queries (most common)
CREATE INDEX idx_ai_usage_provider_model ON ai_usage_events(provider, model_id, started_at DESC);

-- Time-based queries
CREATE INDEX idx_ai_usage_started_at ON ai_usage_events(started_at DESC);

-- Session tracking
CREATE INDEX idx_ai_usage_session ON ai_usage_events(session_id, started_at DESC) WHERE session_id IS NOT NULL;

-- User tracking
CREATE INDEX idx_ai_usage_user ON ai_usage_events(user_id, started_at DESC) WHERE user_id IS NOT NULL;

-- Request lookup
CREATE INDEX idx_ai_usage_request ON ai_usage_events(request_id);

-- Cost analysis
CREATE INDEX idx_ai_usage_cost ON ai_usage_events(cost_tier, started_at DESC) WHERE estimated_cost IS NOT NULL;

-- Performance analysis
CREATE INDEX idx_ai_usage_performance ON ai_usage_events(provider, model_id, duration_ms) WHERE success = TRUE;

-- Error tracking
CREATE INDEX idx_ai_usage_errors ON ai_usage_events(error_type, started_at DESC) WHERE success = FALSE;

-- Task-based analytics
CREATE INDEX idx_ai_usage_task_type ON ai_usage_events(task_type, provider, model_id, started_at DESC);

-- Model selection learning
CREATE INDEX idx_ai_usage_auto_selected ON ai_usage_events(task_type, complexity, was_auto_selected, success) WHERE was_auto_selected = TRUE;

-- Comments
COMMENT ON TABLE ai_usage_events IS 'Comprehensive AI provider usage tracking for analytics, cost management, and performance monitoring';
COMMENT ON COLUMN ai_usage_events.request_id IS 'Unique identifier for the request';
COMMENT ON COLUMN ai_usage_events.session_id IS 'Session ID for grouping related requests';
COMMENT ON COLUMN ai_usage_events.user_id IS 'User who initiated the request (if applicable)';
COMMENT ON COLUMN ai_usage_events.provider IS 'AI provider name (gemini, claude, codex, copilot, etc.)';
COMMENT ON COLUMN ai_usage_events.model_id IS 'Specific model used (e.g., gemini-2.0-flash-exp)';
COMMENT ON COLUMN ai_usage_events.tokens_per_second IS 'Throughput metric for streaming responses';
COMMENT ON COLUMN ai_usage_events.cost_tier IS 'Cost model: free (subscription), limited (quota), pay-per-use';
COMMENT ON COLUMN ai_usage_events.estimated_cost IS 'Estimated cost in USD (null for free tier)';
COMMENT ON COLUMN ai_usage_events.had_tools IS 'Whether the request used tool calling';
COMMENT ON COLUMN ai_usage_events.had_vision IS 'Whether the request included image inputs';
COMMENT ON COLUMN ai_usage_events.had_reasoning IS 'Whether the model used extended reasoning (e.g., Claude thinking)';

-- Materialized view for daily statistics (refreshed periodically)
CREATE MATERIALIZED VIEW ai_usage_daily_stats AS
SELECT
  DATE_TRUNC('day', started_at) AS day,
  provider,
  model_id,

  -- Request counts
  COUNT(*) AS total_requests,
  COUNT(*) FILTER (WHERE success = TRUE) AS successful_requests,
  COUNT(*) FILTER (WHERE success = FALSE) AS failed_requests,
  ROUND(COUNT(*) FILTER (WHERE success = TRUE)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 2) AS success_rate,

  -- Token usage
  SUM(total_tokens) AS total_tokens,
  ROUND(AVG(total_tokens)) AS avg_tokens,
  MAX(total_tokens) AS max_tokens,

  -- Performance
  ROUND(AVG(duration_ms)) AS avg_duration_ms,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY duration_ms) AS p50_duration_ms,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) AS p95_duration_ms,
  PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration_ms) AS p99_duration_ms,
  ROUND(AVG(tokens_per_second), 2) AS avg_tokens_per_second,

  -- Cost
  SUM(estimated_cost) AS total_cost,
  ROUND(AVG(estimated_cost), 4) AS avg_cost

FROM ai_usage_events
GROUP BY DATE_TRUNC('day', started_at), provider, model_id;

-- Index on materialized view
CREATE UNIQUE INDEX idx_ai_usage_daily_stats_unique ON ai_usage_daily_stats(day, provider, model_id);

-- Comments on materialized view
COMMENT ON MATERIALIZED VIEW ai_usage_daily_stats IS 'Pre-computed daily statistics for faster analytics queries';

-- Function to refresh the materialized view (call via cron or manually)
CREATE OR REPLACE FUNCTION refresh_ai_usage_daily_stats()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY ai_usage_daily_stats;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION refresh_ai_usage_daily_stats IS 'Refresh daily usage statistics (run via cron)';

-- ============================================================================
-- HELPFUL ANALYTICS QUERIES (for learning optimal model selection)
-- ============================================================================

-- Query: Best model for each task type (by success rate + performance)
COMMENT ON MATERIALIZED VIEW ai_usage_daily_stats IS $$
Pre-computed daily statistics for faster analytics queries.

Example queries:

-- Best model for code generation:
SELECT provider, model_id,
       success_rate, avg_duration_ms, avg_tokens, total_requests
FROM ai_usage_events
WHERE task_type = 'code' AND started_at >= NOW() - INTERVAL '7 days'
GROUP BY provider, model_id
HAVING COUNT(*) >= 10  -- Minimum sample size
ORDER BY success_rate DESC, avg_duration_ms ASC
LIMIT 5;

-- Compare Codex vs GPT vs Claude for coding:
SELECT
  CASE
    WHEN provider = 'codex' THEN 'Codex'
    WHEN model_id LIKE '%gpt%' THEN 'GPT'
    WHEN model_id LIKE '%claude%' THEN 'Claude'
    ELSE provider
  END AS model_family,
  COUNT(*) as requests,
  ROUND(AVG(CASE WHEN success THEN 1.0 ELSE 0.0 END) * 100, 2) as success_rate,
  ROUND(AVG(duration_ms)) as avg_ms,
  ROUND(AVG(total_tokens)) as avg_tokens,
  SUM(estimated_cost) as total_cost
FROM ai_usage_events
WHERE task_type = 'code'
  AND started_at >= NOW() - INTERVAL '30 days'
GROUP BY model_family
ORDER BY success_rate DESC, avg_ms ASC;

-- Model selection learning (which auto-selections worked best):
SELECT
  task_type,
  complexity,
  provider,
  model_id,
  COUNT(*) as auto_selections,
  ROUND(AVG(CASE WHEN success THEN 1.0 ELSE 0.0 END) * 100, 2) as success_rate,
  ROUND(AVG(duration_ms)) as avg_duration_ms,
  ROUND(AVG(total_tokens)) as avg_tokens
FROM ai_usage_events
WHERE was_auto_selected = TRUE
  AND started_at >= NOW() - INTERVAL '7 days'
GROUP BY task_type, complexity, provider, model_id
HAVING COUNT(*) >= 5
ORDER BY task_type, complexity, success_rate DESC, avg_duration_ms ASC;

-- Task type distribution:
SELECT
  task_type,
  COUNT(*) as total_requests,
  ROUND(AVG(total_tokens)) as avg_tokens,
  ROUND(AVG(duration_ms)) as avg_duration_ms,
  STRING_AGG(DISTINCT provider || ':' || model_id, ', ' ORDER BY provider || ':' || model_id) as models_used
FROM ai_usage_events
WHERE started_at >= NOW() - INTERVAL '7 days'
GROUP BY task_type
ORDER BY total_requests DESC;

$$;
