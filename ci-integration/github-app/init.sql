-- Singularity GitHub App Database Initialization
-- This script sets up the initial database schema for the GitHub App

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create custom types
DO $$ BEGIN
    CREATE TYPE analysis_status AS ENUM ('pending', 'running', 'completed', 'failed');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE webhook_event_type AS ENUM ('push', 'pull_request', 'pull_request_review', 'check_suite', 'check_run');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Installments table for tracking user subscriptions
CREATE TABLE IF NOT EXISTS installments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    github_installation_id BIGINT NOT NULL UNIQUE,
    account_login VARCHAR(255) NOT NULL,
    account_id BIGINT NOT NULL,
    account_type VARCHAR(50) NOT NULL, -- 'User' or 'Organization'
    permissions JSONB NOT NULL DEFAULT '{}',
    events TEXT[] NOT NULL DEFAULT '{}',
    repository_selection VARCHAR(50) NOT NULL DEFAULT 'all',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Repositories table
CREATE TABLE IF NOT EXISTS repositories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    github_id BIGINT NOT NULL,
    name VARCHAR(255) NOT NULL,
    full_name VARCHAR(500) NOT NULL,
    owner_login VARCHAR(255) NOT NULL,
    owner_id BIGINT NOT NULL,
    private BOOLEAN NOT NULL DEFAULT false,
    html_url TEXT NOT NULL,
    description TEXT,
    language VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(github_id)
);

-- Installation repositories junction table
CREATE TABLE IF NOT EXISTS installation_repositories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    installation_id UUID NOT NULL REFERENCES installments(id) ON DELETE CASCADE,
    repository_id UUID NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(installation_id, repository_id)
);

-- Webhook events table
CREATE TABLE IF NOT EXISTS webhook_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    github_delivery_id VARCHAR(255) UNIQUE NOT NULL,
    event_type webhook_event_type NOT NULL,
    payload JSONB NOT NULL,
    signature VARCHAR(255),
    processed BOOLEAN NOT NULL DEFAULT false,
    processed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Analysis runs table
CREATE TABLE IF NOT EXISTS analysis_runs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    repository_id UUID NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
    installation_id UUID NOT NULL REFERENCES installments(id) ON DELETE CASCADE,
    commit_sha VARCHAR(40) NOT NULL,
    branch VARCHAR(255),
    pull_request_number INTEGER,
    check_run_id BIGINT,
    status analysis_status NOT NULL DEFAULT 'pending',
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    results JSONB,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Analysis results table (detailed findings)
CREATE TABLE IF NOT EXISTS analysis_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    analysis_run_id UUID NOT NULL REFERENCES analysis_runs(id) ON DELETE CASCADE,
    file_path TEXT NOT NULL,
    line_number INTEGER,
    column_number INTEGER,
    rule_id VARCHAR(255) NOT NULL,
    severity VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    suggestion TEXT,
    category VARCHAR(100),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Intelligence data table (anonymized)
CREATE TABLE IF NOT EXISTS intelligence_data (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    analysis_run_id UUID REFERENCES analysis_runs(id) ON DELETE SET NULL,
    repository_hash VARCHAR(64) NOT NULL, -- SHA256 hash of repo identifier
    language VARCHAR(100),
    framework VARCHAR(100),
    pattern_type VARCHAR(100),
    pattern_data JSONB NOT NULL,
    confidence_score DECIMAL(3,2),
    collected_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- Ensure anonymity
    CHECK (repository_hash != ''),
    CHECK (char_length(repository_hash) = 64)
);

-- Usage metrics table
CREATE TABLE IF NOT EXISTS usage_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    installation_id UUID NOT NULL REFERENCES installments(id) ON DELETE CASCADE,
    metric_type VARCHAR(100) NOT NULL,
    metric_value BIGINT NOT NULL,
    period_start TIMESTAMP WITH TIME ZONE NOT NULL,
    period_end TIMESTAMP WITH TIME ZONE NOT NULL,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(installation_id, metric_type, period_start, period_end)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_installments_github_id ON installments(github_installation_id);
CREATE INDEX IF NOT EXISTS idx_repositories_github_id ON repositories(github_id);
CREATE INDEX IF NOT EXISTS idx_repositories_owner ON repositories(owner_login);
CREATE INDEX IF NOT EXISTS idx_webhook_events_delivery_id ON webhook_events(github_delivery_id);
CREATE INDEX IF NOT EXISTS idx_webhook_events_processed ON webhook_events(processed);
CREATE INDEX IF NOT EXISTS idx_analysis_runs_repository ON analysis_runs(repository_id);
CREATE INDEX IF NOT EXISTS idx_analysis_runs_status ON analysis_runs(status);
CREATE INDEX IF NOT EXISTS idx_analysis_runs_check_run ON analysis_runs(check_run_id);
CREATE INDEX IF NOT EXISTS idx_analysis_results_run ON analysis_results(analysis_run_id);
CREATE INDEX IF NOT EXISTS idx_intelligence_repo_hash ON intelligence_data(repository_hash);
CREATE INDEX IF NOT EXISTS idx_intelligence_collected ON intelligence_data(collected_at);
CREATE INDEX IF NOT EXISTS idx_usage_metrics_installation ON usage_metrics(installation_id);
CREATE INDEX IF NOT EXISTS idx_usage_metrics_period ON usage_metrics(period_start, period_end);

-- Updated at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add updated_at triggers
DROP TRIGGER IF EXISTS update_installments_updated_at ON installments;
CREATE TRIGGER update_installments_updated_at
    BEFORE UPDATE ON installments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_repositories_updated_at ON repositories;
CREATE TRIGGER update_repositories_updated_at
    BEFORE UPDATE ON repositories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_analysis_runs_updated_at ON analysis_runs;
CREATE TRIGGER update_analysis_runs_updated_at
    BEFORE UPDATE ON analysis_runs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();