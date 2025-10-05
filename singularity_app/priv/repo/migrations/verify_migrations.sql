-- Database Migration Verification Script
-- Run this after migrations to verify schema correctness

\echo '\n=== CHECKING SEMANTIC CODE SEARCH TABLES (Migration 7) ==='

-- Check codebase_metadata table
SELECT
  'codebase_metadata' as table_name,
  count(*) as column_count
FROM information_schema.columns
WHERE table_name = 'codebase_metadata';

-- Check vector dimensions
SELECT
  table_name,
  column_name,
  data_type,
  (SELECT atttypmod-4 FROM pg_attribute WHERE attrelid = 'public.codebase_metadata'::regclass AND attname = 'vector_embedding') as vector_dimensions
FROM information_schema.columns
WHERE table_name = 'codebase_metadata' AND column_name = 'vector_embedding';

-- Check all semantic search tables exist
SELECT EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'codebase_metadata') as codebase_metadata,
       EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'codebase_registry') as codebase_registry,
       EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'graph_nodes') as graph_nodes,
       EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'graph_edges') as graph_edges,
       EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'graph_types') as graph_types,
       EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'vector_search') as vector_search,
       EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'vector_similarity_cache') as vector_similarity_cache;

\echo '\n=== CHECKING VECTOR INDEXES (Migration 8) ==='

-- Check all vector indexes exist
SELECT
  indexname,
  tablename,
  indexdef
FROM pg_indexes
WHERE indexname LIKE '%vector%' OR indexname LIKE '%embedding%'
ORDER BY tablename, indexname;

\echo '\n=== CHECKING AUTONOMY TABLES (Migration 9) ==='

-- Check autonomy tables
SELECT EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'rule_executions') as rule_executions,
       EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'rule_evolution_proposals') as rule_evolution_proposals;

-- Check foreign keys
SELECT
  conname as constraint_name,
  conrelid::regclass as table_name,
  confrelid::regclass as referenced_table
FROM pg_constraint
WHERE contype = 'f'
  AND conrelid::regclass::text IN ('rule_executions', 'rule_evolution_proposals');

\echo '\n=== CHECKING QUALITY TABLES (Migration 10) ==='

-- Check quality tables
SELECT EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'quality_runs') as quality_runs,
       EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'quality_findings') as quality_findings;

-- Check quality_findings foreign key
SELECT
  conname,
  conrelid::regclass,
  confrelid::regclass
FROM pg_constraint
WHERE conrelid = 'quality_findings'::regclass AND contype = 'f';

\echo '\n=== CHECKING TECHNOLOGY DETECTION TABLES (Migration 11) ==='

-- Check technology tables
SELECT EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'technology_patterns') as technology_patterns,
       EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'technology_templates') as technology_templates,
       EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'technology_knowledge') as technology_knowledge_old;

-- Check unique constraints
SELECT
  conname,
  conrelid::regclass,
  pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid::regclass::text IN ('technology_patterns', 'technology_templates')
  AND contype = 'u';

\echo '\n=== CHECKING CODEBASE SNAPSHOTS TABLE (Migration 12) ==='

-- Check table exists and old one is dropped
SELECT EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'codebase_snapshots') as codebase_snapshots,
       EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'detection_events') as detection_events_old;

-- Check unique constraint
SELECT
  conname,
  pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'codebase_snapshots'::regclass AND contype = 'u';

\echo '\n=== CHECKING GIT COORDINATION TABLES (Migration 13) ==='

-- Check git tables
SELECT EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'git_agent_sessions') as git_agent_sessions,
       EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'git_pending_merges') as git_pending_merges,
       EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'git_merge_history') as git_merge_history,
       EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'git_sessions') as git_sessions_old,
       EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'git_commits') as git_commits_old;

\echo '\n=== SUMMARY: ALL TABLES ==='

-- List all tables
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

\echo '\n=== SUMMARY: ALL INDEXES ==='

-- List all indexes
SELECT
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

\echo '\n=== SUMMARY: VECTOR EXTENSION ==='

-- Check pgvector extension
SELECT
  extname,
  extversion,
  extrelocatable
FROM pg_extension
WHERE extname = 'vector';

\echo '\n=== SUMMARY: MIGRATION STATUS ==='

-- Check schema_migrations table
SELECT version, inserted_at
FROM schema_migrations
WHERE version::text LIKE '202501%'
ORDER BY version;

\echo '\nVerification complete!'
