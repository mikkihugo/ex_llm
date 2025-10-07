-- ============================================================================
-- Singularity Unified Database Schema
-- Complete AI Development Environment Knowledge Base
-- No existing data - clean slate design
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS vector; -- pgvector for embeddings
CREATE EXTENSION IF NOT EXISTS timescaledb; -- For time-series metrics

-- ============================================================================
-- CORE SYSTEM ENTITIES
-- ============================================================================

-- Users/Projects (Multi-tenant support)
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    owner_id TEXT, -- Could be email, GitHub ID, system, etc.
    repository_url TEXT,
    primary_language TEXT, -- rust, elixir, typescript, etc.
    framework TEXT, -- phoenix, react, custom, etc.
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    metadata JSONB, -- Flexible project metadata

    UNIQUE(owner_id, name)
);

-- File system tracking
CREATE TABLE project_files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    file_path TEXT NOT NULL,
    detected_language TEXT,
    framework_context TEXT,
    size_bytes BIGINT,
    line_count INTEGER,
    content_hash TEXT, -- SHA256 for change detection
    last_modified TIMESTAMPTZ,
    last_analyzed TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(project_id, file_path)
);

-- ============================================================================
-- CODE ANALYSIS (source-code-parser + analysis_suite)
-- ============================================================================

-- Unified code analysis results
CREATE TABLE code_analyses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    file_id UUID REFERENCES project_files(id) ON DELETE CASCADE,

    -- Analysis metadata
    analyzer_version TEXT,
    analysis_timestamp TIMESTAMPTZ DEFAULT NOW(),

    -- Basic code metrics
    language TEXT,
    lines_of_code INTEGER,
    lines_of_comments INTEGER,
    blank_lines INTEGER,
    total_lines INTEGER,
    functions_count INTEGER,
    classes_count INTEGER,
    complexity_score FLOAT,

    -- Mozilla RCA metrics
    cyclomatic_complexity FLOAT,
    halstead_volume FLOAT,
    maintainability_index FLOAT,
    source_lines_of_code INTEGER,
    comment_lines_of_code INTEGER,

    -- Tree-sitter AST results
    ast_functions JSONB,
    ast_classes JSONB,
    ast_imports JSONB,
    ast_exports JSONB,

    -- Dependency analysis
    internal_dependencies JSONB,
    external_dependencies JSONB,

    -- Quality analysis results
    quality_score FLOAT,
    code_smells JSONB,
    technical_debt_ratio FLOAT,
    duplication_percentage FLOAT,

    -- Security analysis
    security_issues JSONB,
    security_score FLOAT,

    -- Performance analysis
    performance_metrics JSONB,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(project_id, file_id, analysis_timestamp)
);

-- Code patterns and insights
CREATE TABLE code_patterns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    pattern_name TEXT NOT NULL,
    pattern_type TEXT NOT NULL, -- design_pattern, anti_pattern, framework_usage, etc.
    confidence_score FLOAT,
    description TEXT,
    affected_files JSONB,
    code_examples JSONB,
    recommendations JSONB,
    metadata JSONB,

    discovered_at TIMESTAMPTZ DEFAULT NOW(),
    last_seen TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(project_id, pattern_name, pattern_type)
);

-- Semantic code chunks for search
CREATE TABLE code_chunks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    file_id UUID REFERENCES project_files(id) ON DELETE CASCADE,

    -- Code location
    start_line INTEGER NOT NULL,
    end_line INTEGER NOT NULL,
    chunk_type TEXT, -- function, class, method, etc.
    name TEXT, -- Function/class name
    content TEXT NOT NULL,

    -- Analysis
    summary TEXT,
    language TEXT,
    complexity INTEGER,
    quality_score FLOAT,

    -- Embeddings for semantic search
    semantic_embedding vector(384),
    code_embedding vector(384),

    -- Relationships
    tags TEXT[],
    depends_on JSONB,
    depended_by JSONB,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Code relationships (call graphs, inheritance, etc.)
CREATE TABLE code_relationships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    from_chunk_id UUID REFERENCES code_chunks(id) ON DELETE CASCADE,
    to_chunk_id UUID REFERENCES code_chunks(id) ON DELETE CASCADE,
    relationship_type TEXT, -- calls, inherits, implements, imports, etc.
    confidence_score FLOAT,
    metadata JSONB,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(from_chunk_id, to_chunk_id, relationship_type)
);

-- ============================================================================
-- PACKAGE REGISTRY (package_registry_indexer)
-- ============================================================================

-- Unified package ecosystem
CREATE TABLE packages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ecosystem TEXT NOT NULL, -- npm, cargo, hex, pypi, etc.
    package_name TEXT NOT NULL,
    version TEXT NOT NULL,
    description TEXT,
    homepage TEXT,
    repository_url TEXT,
    license TEXT,
    maintainers JSONB,

    -- Package statistics
    downloads_total BIGINT,
    stars INTEGER,
    forks INTEGER,
    last_commit TIMESTAMPTZ,
    last_updated TIMESTAMPTZ,

    -- Dependencies
    dependencies JSONB,
    dev_dependencies JSONB,
    peer_dependencies JSONB,

    -- Content analysis
    documentation TEXT,
    readme_content TEXT,
    has_types BOOLEAN,
    framework_tags JSONB,

    -- Extracted knowledge
    code_snippets JSONB,
    usage_examples JSONB,
    best_practices JSONB,
    troubleshooting JSONB,

    -- Embeddings
    semantic_embedding vector(384),
    code_embedding vector(384),

    -- Quality & Security
    quality_score FLOAT,
    security_score FLOAT,
    vulnerabilities JSONB,
    deprecation_warnings JSONB,

    -- Learning data
    usage_stats JSONB,
    success_patterns JSONB,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(ecosystem, package_name, version)
);

-- Package relationships and alternatives
CREATE TABLE package_relationships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_package_id UUID REFERENCES packages(id) ON DELETE CASCADE,
    target_package_id UUID REFERENCES packages(id) ON DELETE CASCADE,
    relationship_type TEXT, -- depends_on, alternative_to, commonly_used_with, etc.
    confidence_score FLOAT,
    context TEXT, -- web_dev, data_science, etc.
    metadata JSONB,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(source_package_id, target_package_id, relationship_type)
);

-- ============================================================================
-- PROMPT ENGINE & AI LEARNING
-- ============================================================================

-- AI Prompt templates
CREATE TABLE prompt_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    category TEXT NOT NULL, -- code_generation, analysis, refactoring, etc.
    language TEXT,
    framework TEXT,
    template_content TEXT NOT NULL,
    variables JSONB,
    prerequisites JSONB,
    metadata JSONB,

    -- Performance tracking
    usage_count INTEGER DEFAULT 0,
    success_rate FLOAT DEFAULT 0,
    avg_quality_score FLOAT DEFAULT 0,
    avg_response_time_ms FLOAT,
    avg_token_usage INTEGER,

    -- Learning & optimization
    improvement_history JSONB,
    ab_test_results JSONB,
    dspy_optimized BOOLEAN DEFAULT false,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(name, category, language, framework)
);

-- Prompt execution tracking
CREATE TABLE prompt_executions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    template_id UUID REFERENCES prompt_templates(id) ON DELETE SET NULL,
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,

    -- Execution context
    prompt_text TEXT NOT NULL,
    variables_used JSONB,
    full_context JSONB,

    -- AI model details
    model_used TEXT, -- gpt-4, claude-3, gemini-pro, etc.
    provider_used TEXT, -- openai, anthropic, google, etc.
    temperature FLOAT,
    max_tokens INTEGER,

    -- Results
    response_text TEXT,
    response_length INTEGER,
    token_usage INTEGER,
    execution_time_ms INTEGER,
    success BOOLEAN DEFAULT true,
    error_message TEXT,

    -- Quality assessment
    quality_score FLOAT, -- 0-1 automated rating
    usefulness_rating INTEGER, -- 1-5 user rating
    feedback_comments TEXT,

    -- Context for learning
    task_type TEXT, -- code_gen, analysis, refactor, etc.
    complexity_level TEXT, -- simple, medium, complex
    domain_context TEXT, -- web_dev, api_design, etc.
    applied_successfully BOOLEAN,

    executed_at TIMESTAMPTZ DEFAULT NOW()
);

-- DSPy learning and optimization
CREATE TABLE prompt_optimizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    template_id UUID REFERENCES prompt_templates(id) ON DELETE CASCADE,

    -- Optimization metadata
    optimization_run_id TEXT,
    optimizer_used TEXT, -- BootstrapFinetune, MIPROv2, COPRO
    training_examples_count INTEGER,
    validation_examples_count INTEGER,

    -- Performance comparison
    baseline_success_rate FLOAT,
    optimized_success_rate FLOAT,
    improvement_percentage FLOAT,

    -- Learned parameters
    dspy_weights JSONB,
    prompt_modifications JSONB,
    instruction_improvements JSONB,

    -- Results
    optimized_template_id UUID, -- Reference to new optimized template
    validation_results JSONB,

    optimized_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- AI AGENT SESSIONS & TOOL USAGE
-- ============================================================================

-- AI Agent sessions
CREATE TABLE agent_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    session_type TEXT, -- analysis, code_generation, refactoring, etc.
    agent_name TEXT, -- CodeAnalyzer, PromptOptimizer, etc.
    goal TEXT,
    context JSONB,

    -- AI model used
    model_used TEXT,
    provider_used TEXT,
    total_tokens_used INTEGER,

    -- Session lifecycle
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    duration_ms INTEGER,
    success BOOLEAN DEFAULT false,
    error_message TEXT,

    -- Results summary
    actions_taken JSONB,
    files_analyzed JSONB,
    files_modified JSONB,
    suggestions_made JSONB,
    quality_improvements JSONB,

    -- Learning data
    user_feedback JSONB,
    lessons_learned JSONB,
    effectiveness_rating INTEGER, -- 1-5

    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tool usage tracking for learning
CREATE TABLE tool_usages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    session_id UUID REFERENCES agent_sessions(id) ON DELETE CASCADE,

    -- Tool details
    tool_name TEXT NOT NULL,
    tool_category TEXT, -- analysis, generation, search, refactor, etc.
    tool_version TEXT,

    -- Usage context
    file_path TEXT,
    user_intent TEXT,
    code_selection TEXT,
    cursor_position JSONB,

    -- Execution details
    parameters JSONB,
    execution_time_ms INTEGER,
    success BOOLEAN DEFAULT true,
    error_details JSONB,

    -- Results assessment
    output_quality_score FLOAT, -- 0-1
    user_satisfaction_rating INTEGER, -- 1-5
    usefulness_rating INTEGER, -- 1-5
    feedback_comments TEXT,

    -- Learning insights
    improvement_suggestions JSONB,
    alternative_approaches JSONB,
    best_practices_applied JSONB,

    used_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- UNIFIED SEARCH & DISCOVERY
-- ============================================================================

-- Universal search index
CREATE TABLE search_index (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    content_type TEXT NOT NULL, -- code_chunk, package, template, pattern, etc.
    content_id UUID NOT NULL,   -- Foreign key to the actual content
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,

    -- Searchable content
    title TEXT,
    description TEXT,
    full_content TEXT,
    tags TEXT[],
    category TEXT,
    language TEXT,
    framework TEXT,

    -- Embeddings for semantic search
    semantic_embedding vector(384),
    code_embedding vector(384),

    -- Search optimization
    search_vector tsvector,     -- PostgreSQL full-text search
    trgm_vector TEXT,           -- Trigram search
    popularity_score FLOAT DEFAULT 0,
    quality_score FLOAT DEFAULT 0,
    last_accessed TIMESTAMPTZ DEFAULT NOW(),

    -- Metadata
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Search queries and results tracking
CREATE TABLE search_queries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    user_query TEXT NOT NULL,
    query_type TEXT, -- semantic, keyword, code, package, etc.
    filters JSONB,

    -- Results
    results_count INTEGER,
    top_result_id UUID, -- Reference to search_index
    execution_time_ms INTEGER,

    -- User feedback
    satisfaction_rating INTEGER, -- 1-5
    was_helpful BOOLEAN,
    selected_result_id UUID,

    -- Learning
    improved_query_suggestions JSONB,

    queried_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- LEARNING & EVOLUTION SYSTEM
-- ============================================================================

-- System learning observations
CREATE TABLE learning_observations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    observation_type TEXT NOT NULL, -- success_pattern, failure_pattern, user_preference, etc.
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,

    -- What was observed
    context JSONB,        -- Situation/context where it happened
    action_taken JSONB,   -- What was done
    outcome JSONB,        -- What happened
    success BOOLEAN,

    -- Learning insights
    patterns_identified JSONB,
    lessons_learned JSONB,
    recommendations JSONB,

    -- Confidence and validation
    confidence_score FLOAT,
    validation_count INTEGER DEFAULT 0,
    last_validated TIMESTAMPTZ,

    observed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Evolution suggestions
CREATE TABLE evolution_suggestions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    suggestion_type TEXT NOT NULL, -- code_improvement, architecture_change, tool_recommendation, etc.

    -- Suggestion details
    title TEXT NOT NULL,
    description TEXT,
    priority TEXT, -- critical, high, medium, low
    category TEXT, -- quality, performance, security, maintainability, etc.

    -- Technical details
    affected_files JSONB,
    code_changes JSONB,
    implementation_steps JSONB,
    prerequisites JSONB,

    -- Evidence and reasoning
    evidence JSONB,
    reasoning TEXT,
    expected_benefits JSONB,
    potential_risks JSONB,

    -- Status tracking
    status TEXT DEFAULT 'proposed', -- proposed, approved, implemented, rejected
    implemented_at TIMESTAMPTZ,
    implemented_by TEXT,
    success_rating INTEGER, -- 1-5 if implemented

    -- Learning
    confidence_score FLOAT,
    source_observations JSONB,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- SYSTEM MONITORING & METRICS
-- ============================================================================

-- System performance metrics (TimescaleDB hypertable)
CREATE TABLE system_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    metric_type TEXT NOT NULL, -- response_time, memory_usage, cpu_usage, etc.
    component TEXT NOT NULL, -- source_code_parser, analysis_suite, prompt_engine, etc.
    project_id UUID REFERENCES projects(id) ON DELETE SET NULL,

    -- Metric data
    value FLOAT NOT NULL,
    unit TEXT, -- ms, percent, bytes, count, etc.
    labels JSONB,

    recorded_at TIMESTAMPTZ DEFAULT NOW()
) PARTITION BY RANGE (recorded_at);

-- Create TimescaleDB hypertable for efficient time-series queries
SELECT create_hypertable('system_metrics', 'recorded_at', if_not_exists => TRUE);

-- Error tracking and debugging
CREATE TABLE system_errors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    component TEXT NOT NULL,
    project_id UUID REFERENCES projects(id) ON DELETE SET NULL,

    -- Error details
    error_type TEXT, -- compilation, runtime, network, api, etc.
    error_message TEXT NOT NULL,
    stack_trace TEXT,
    context JSONB,

    -- Impact assessment
    severity TEXT, -- critical, high, medium, low
    user_impacted BOOLEAN DEFAULT false,
    affected_functionality JSONB,

    -- Resolution tracking
    status TEXT DEFAULT 'open', -- open, investigating, fixed, wont_fix
    resolution TEXT,
    resolved_at TIMESTAMPTZ,
    resolved_by TEXT,

    occurred_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- CONFIGURATION & SETTINGS
-- ============================================================================

-- Component configurations
CREATE TABLE component_configs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    component_name TEXT NOT NULL, -- source_code_parser, analysis_suite, etc.
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,

    -- Configuration
    config_key TEXT NOT NULL,
    config_value JSONB,
    config_type TEXT, -- user_setting, system_default, learned_preference
    is_active BOOLEAN DEFAULT true,

    -- Metadata
    description TEXT,
    last_modified_by TEXT,
    modified_reason TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(component_name, project_id, config_key)
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Core entity lookups
CREATE INDEX idx_projects_owner_active ON projects(owner_id, is_active);
CREATE INDEX idx_project_files_project_path ON project_files(project_id, file_path);
CREATE INDEX idx_code_analyses_project_file ON code_analyses(project_id, file_id);
CREATE INDEX idx_code_chunks_project_file ON code_chunks(project_id, file_id);
CREATE INDEX idx_packages_ecosystem_name ON packages(ecosystem, package_name);

-- Search and embeddings
CREATE INDEX idx_code_chunks_semantic ON code_chunks USING ivfflat (semantic_embedding vector_cosine_ops);
CREATE INDEX idx_code_chunks_code ON code_chunks USING ivfflat (code_embedding vector_cosine_ops);
CREATE INDEX idx_packages_semantic ON packages USING ivfflat (semantic_embedding vector_cosine_ops);
CREATE INDEX idx_search_semantic ON search_index USING ivfflat (semantic_embedding vector_cosine_ops);

-- Full-text and trigram search
CREATE INDEX idx_search_vector ON search_index USING gin(search_vector);
CREATE INDEX idx_search_trgm ON search_index USING gin(trgm_vector gin_trgm_ops);

-- Time-based queries
CREATE INDEX idx_prompt_executions_time ON prompt_executions(executed_at DESC);
CREATE INDEX idx_agent_sessions_time ON agent_sessions(started_at DESC);
CREATE INDEX idx_tool_usages_time ON tool_usages(used_at DESC);
CREATE INDEX idx_system_metrics_time ON system_metrics(recorded_at DESC);
CREATE INDEX idx_learning_observations_time ON learning_observations(observed_at DESC);

-- Relationship queries
CREATE INDEX idx_code_relationships_from ON code_relationships(from_chunk_id);
CREATE INDEX idx_code_relationships_to ON code_relationships(to_chunk_id);
CREATE INDEX idx_package_relationships_source ON package_relationships(source_package_id);

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- Project health dashboard
CREATE VIEW project_health AS
SELECT
    p.id,
    p.name,
    p.primary_language,
    p.framework,
    COUNT(DISTINCT pf.id) as total_files,
    COUNT(DISTINCT ca.id) as analyzed_files,
    ROUND(AVG(ca.quality_score), 2) as avg_quality_score,
    ROUND(AVG(ca.security_score), 2) as avg_security_score,
    MAX(ca.analysis_timestamp) as last_analysis,
    COUNT(DISTINCT e.id) as recent_errors
FROM projects p
LEFT JOIN project_files pf ON p.id = pf.project_id
LEFT JOIN code_analyses ca ON p.id = ca.project_id
LEFT JOIN system_errors e ON p.id = e.project_id AND e.occurred_at >= NOW() - INTERVAL '24 hours'
WHERE p.is_active = true
GROUP BY p.id, p.name, p.primary_language, p.framework;

-- Code quality trends (last 30 days)
CREATE VIEW code_quality_trends AS
SELECT
    project_id,
    DATE_TRUNC('day', analysis_timestamp) as analysis_date,
    ROUND(AVG(quality_score), 3) as avg_quality,
    ROUND(AVG(security_score), 3) as avg_security,
    ROUND(AVG(complexity_score), 2) as avg_complexity,
    COUNT(*) as files_analyzed
FROM code_analyses
WHERE analysis_timestamp >= NOW() - INTERVAL '30 days'
GROUP BY project_id, DATE_TRUNC('day', analysis_timestamp)
ORDER BY analysis_date;

-- AI performance insights
CREATE VIEW ai_performance_insights AS
SELECT
    pe.model_used,
    pe.provider_used,
    COUNT(*) as total_requests,
    ROUND(AVG(pe.success::int), 3) as success_rate,
    ROUND(AVG(pe.quality_score), 3) as avg_quality,
    ROUND(AVG(pe.execution_time_ms), 0) as avg_response_time_ms,
    ROUND(AVG(pe.token_usage), 0) as avg_tokens_used
FROM prompt_executions pe
WHERE pe.executed_at >= NOW() - INTERVAL '7 days'
GROUP BY pe.model_used, pe.provider_used
ORDER BY total_requests DESC;

-- Learning effectiveness
CREATE VIEW learning_effectiveness AS
SELECT
    observation_type,
    COUNT(*) as total_observations,
    ROUND(AVG(confidence_score), 3) as avg_confidence,
    COUNT(CASE WHEN validation_count > 0 THEN 1 END) as validated_observations,
    MAX(observed_at) as latest_observation
FROM learning_observations
WHERE observed_at >= NOW() - INTERVAL '30 days'
GROUP BY observation_type
ORDER BY total_observations DESC;

-- ============================================================================
-- INITIAL SYSTEM SETUP
-- ============================================================================

-- Insert Singularity itself as the first project
INSERT INTO projects (name, description, owner_id, repository_url, primary_language, framework, metadata)
VALUES (
    'singularity',
    'Self-evolving AI development environment',
    'system',
    'https://github.com/singularity',
    'rust',
    'elixir',
    '{"is_system": true, "auto_analyze": true, "self_evolving": true}'::jsonb
);

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Function to automatically update search index
CREATE OR REPLACE FUNCTION update_search_index()
RETURNS TRIGGER AS $$
DECLARE
    content_title TEXT;
    content_desc TEXT;
    content_tags TEXT[];
    semantic_emb vector(384);
    code_emb vector(384);
BEGIN
    -- Extract content based on type
    CASE TG_TABLE_NAME
        WHEN 'code_chunks' THEN
            content_title := NEW.name;
            content_desc := NEW.summary;
            content_tags := NEW.tags;
            semantic_emb := NEW.semantic_embedding;
            code_emb := NEW.code_embedding;
        WHEN 'packages' THEN
            content_title := NEW.package_name;
            content_desc := NEW.description;
            content_tags := array[NEW.ecosystem];
            semantic_emb := NEW.semantic_embedding;
            code_emb := NEW.code_embedding;
        WHEN 'prompt_templates' THEN
            content_title := NEW.name;
            content_desc := 'Prompt template for ' || NEW.category;
            content_tags := array[NEW.category, NEW.language];
            semantic_emb := NULL;
            code_emb := NULL;
        ELSE
            content_title := 'Unknown';
            content_desc := 'Unknown content type';
            content_tags := NULL;
            semantic_emb := NULL;
            code_emb := NULL;
    END CASE;

    -- Insert or update search index
    INSERT INTO search_index (
        content_type, content_id, project_id, title, description,
        tags, semantic_embedding, code_embedding, category,
        full_content, metadata
    ) VALUES (
        TG_TABLE_NAME, NEW.id, NEW.project_id, content_title, content_desc,
        content_tags, semantic_emb, code_emb, 'auto_indexed',
        CASE
            WHEN TG_TABLE_NAME = 'code_chunks' THEN NEW.content
            WHEN TG_TABLE_NAME = 'packages' THEN NEW.documentation
            ELSE NEW.name
        END,
        jsonb_build_object('indexed_at', NOW(), 'auto_generated', true)
    )
    ON CONFLICT (content_type, content_id) DO UPDATE SET
        title = EXCLUDED.title,
        description = EXCLUDED.description,
        tags = EXCLUDED.tags,
        semantic_embedding = EXCLUDED.semantic_embedding,
        code_embedding = EXCLUDED.code_embedding,
        updated_at = NOW();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers to keep search index synchronized
CREATE TRIGGER sync_code_chunks_search
    AFTER INSERT OR UPDATE ON code_chunks
    FOR EACH ROW EXECUTE FUNCTION update_search_index();

CREATE TRIGGER sync_packages_search
    AFTER INSERT OR UPDATE ON packages
    FOR EACH ROW EXECUTE FUNCTION update_search_index();

CREATE TRIGGER sync_templates_search
    AFTER INSERT OR UPDATE ON prompt_templates
    FOR EACH ROW EXECUTE FUNCTION update_search_index();

-- ============================================================================
-- DATA INTEGRITY CONSTRAINTS
-- ============================================================================

-- Ensure quality scores are within valid ranges
ALTER TABLE code_analyses ADD CONSTRAINT quality_score_range CHECK (quality_score >= 0 AND quality_score <= 1);
ALTER TABLE code_chunks ADD CONSTRAINT chunk_quality_range CHECK (quality_score >= 0 AND quality_score <= 1);
ALTER TABLE packages ADD CONSTRAINT package_quality_range CHECK (quality_score >= 0 AND quality_score <= 1);
ALTER TABLE prompt_executions ADD CONSTRAINT execution_quality_range CHECK (quality_score >= 0 AND quality_score <= 1);

-- Ensure ratings are within valid ranges
ALTER TABLE prompt_executions ADD CONSTRAINT usefulness_rating_range CHECK (usefulness_rating >= 1 AND usefulness_rating <= 5);
ALTER TABLE tool_usages ADD CONSTRAINT satisfaction_rating_range CHECK (user_satisfaction_rating >= 1 AND user_satisfaction_rating <= 5);
ALTER TABLE agent_sessions ADD CONSTRAINT effectiveness_rating_range CHECK (effectiveness_rating >= 1 AND effectiveness_rating <= 5);

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE projects IS 'Multi-tenant project definitions with metadata';
COMMENT ON TABLE code_analyses IS 'Comprehensive code analysis results from all analyzers';
COMMENT ON TABLE code_chunks IS 'Semantic code chunks with embeddings for search and relationships';
COMMENT ON TABLE packages IS 'Unified package registry across all ecosystems with learning data';
COMMENT ON TABLE prompt_templates IS 'AI prompt templates with performance tracking and optimization';
COMMENT ON TABLE prompt_executions IS 'Detailed execution history for learning and optimization';
COMMENT ON TABLE agent_sessions IS 'AI agent sessions with outcome tracking and learning';
COMMENT ON TABLE learning_observations IS 'System learning observations for continuous improvement';
COMMENT ON TABLE evolution_suggestions IS 'AI-generated suggestions for system and code improvement';
COMMENT ON TABLE search_index IS 'Unified search index across all content types with embeddings';
COMMENT ON TABLE system_metrics IS 'Time-series performance and health metrics (TimescaleDB)';
COMMENT ON TABLE system_errors IS 'Comprehensive error tracking and resolution management';

-- ============================================================================
-- SETUP COMPLETE
-- ============================================================================

/*
This schema provides:

1. **Unified Data Model**: All Singularity components share one knowledge base
2. **Learning Foundation**: Tracks successes, failures, and improvements over time
3. **Search Integration**: Semantic search across code, packages, and documentation
4. **Evolution Tracking**: System can observe, learn, and suggest improvements
5. **Performance Monitoring**: Comprehensive metrics for optimization
6. **Multi-tenancy Ready**: Projects are isolated but learning can be shared

Next steps:
1. Run this schema to create the database
2. Update Rust components to use new table names/types
3. Implement the search index synchronization
4. Add learning observation collection
5. Build evolution suggestion generation
*/