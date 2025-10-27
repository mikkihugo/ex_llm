--
-- PostgreSQL database dump
--

\restrict MPjHn5f06rJKHFWhyrad9Ebj8dTfcuWJWRc5V2cPTfCQErp2SeSVRVDmSSaX3NC

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: btree_gin; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gin WITH SCHEMA public;


--
-- Name: EXTENSION btree_gin; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gin IS 'support for indexing common datatypes in GIN';


--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: fuzzystrmatch; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;


--
-- Name: EXTENSION fuzzystrmatch; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION fuzzystrmatch IS 'determine similarities and distance between strings';


--
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;


--
-- Name: EXTENSION hstore; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';


--
-- Name: ltree; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS ltree WITH SCHEMA public;


--
-- Name: EXTENSION ltree; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION ltree IS 'data type for hierarchical tree-like structures';


--
-- Name: pg_buffercache; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_buffercache WITH SCHEMA public;


--
-- Name: EXTENSION pg_buffercache; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_buffercache IS 'examine the shared buffer cache';


--
-- Name: pg_prewarm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_prewarm WITH SCHEMA public;


--
-- Name: EXTENSION pg_prewarm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_prewarm IS 'prewarm relation data';


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;


--
-- Name: EXTENSION vector; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION vector IS 'vector data type and ivfflat and hnsw access methods';


--
-- Name: refresh_cache_stats(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_cache_stats() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Refresh cache statistics for optimization
  ANALYZE rag_documents;
  ANALYZE semantic_cache;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: analysis_summaries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analysis_summaries (
    id uuid NOT NULL,
    codebase_id character varying(255) NOT NULL,
    analysis_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    analyzed_at timestamp(0) without time zone NOT NULL,
    total_files integer DEFAULT 0,
    total_lines integer DEFAULT 0,
    total_functions integer DEFAULT 0,
    total_classes integer DEFAULT 0,
    quality_score double precision DEFAULT 0.0,
    technical_debt_ratio double precision DEFAULT 0.0,
    average_complexity double precision DEFAULT 0.0,
    average_maintainability double precision DEFAULT 0.0,
    languages jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: capabilities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.capabilities (
    id uuid NOT NULL,
    epic_id uuid,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    status character varying(255) DEFAULT 'backlog'::character varying,
    wsjf_score double precision DEFAULT 0.0,
    approved_by character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: capability_dependencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.capability_dependencies (
    id uuid NOT NULL,
    capability_id uuid NOT NULL,
    depends_on_capability_id uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: code_embeddings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.code_embeddings (
    id uuid NOT NULL,
    code_file_id uuid,
    chunk_index integer NOT NULL,
    chunk_text text NOT NULL,
    embedding public.vector(768),
    metadata jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: code_files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.code_files (
    id uuid NOT NULL,
    codebase_id character varying(255) NOT NULL,
    file_path character varying(255) NOT NULL,
    language character varying(255),
    content text,
    file_size integer,
    line_count integer,
    hash character varying(255),
    ast_json jsonb,
    functions jsonb DEFAULT '[]'::jsonb,
    classes jsonb DEFAULT '[]'::jsonb,
    imports jsonb DEFAULT '[]'::jsonb,
    exports jsonb DEFAULT '[]'::jsonb,
    symbols jsonb DEFAULT '[]'::jsonb,
    metadata jsonb DEFAULT '{}'::jsonb,
    parsed_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: code_fingerprints; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.code_fingerprints (
    id uuid NOT NULL,
    file_path character varying(255) NOT NULL,
    content_hash character varying(255) NOT NULL,
    structural_hash character varying(255) NOT NULL,
    semantic_hash character varying(255),
    language character varying(255),
    tokens character varying(255)[] DEFAULT ARRAY[]::character varying[],
    ast_signature text,
    complexity_score integer,
    metadata jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: code_locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.code_locations (
    id uuid NOT NULL,
    project character varying(255) NOT NULL,
    file_path character varying(255) NOT NULL,
    line_start integer NOT NULL,
    line_end integer NOT NULL,
    column_start integer,
    column_end integer,
    symbol_type character varying(255) NOT NULL,
    symbol_name character varying(255) NOT NULL,
    parent_symbol character varying(255),
    signature text,
    documentation text,
    metadata jsonb DEFAULT '{}'::jsonb,
    embedding public.vector(768),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: codebase_chunk_embeddings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.codebase_chunk_embeddings (
    id uuid NOT NULL,
    chunk_id uuid,
    embedding public.vector(768),
    model_name character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: codebase_chunks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.codebase_chunks (
    id uuid NOT NULL,
    code_file_id uuid,
    chunk_index integer NOT NULL,
    chunk_text text NOT NULL,
    chunk_type character varying(255),
    start_line integer,
    end_line integer,
    metadata jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: codebase_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.codebase_metadata (
    id bigint NOT NULL,
    codebase_id character varying(255) NOT NULL,
    codebase_path character varying(500) NOT NULL,
    path character varying(500) NOT NULL,
    size bigint DEFAULT 0 NOT NULL,
    lines integer DEFAULT 0 NOT NULL,
    language character varying(50) DEFAULT 'unknown'::character varying NOT NULL,
    last_modified bigint DEFAULT 0 NOT NULL,
    file_type character varying(50) DEFAULT 'source'::character varying NOT NULL,
    cyclomatic_complexity double precision DEFAULT 0.0 NOT NULL,
    cognitive_complexity double precision DEFAULT 0.0 NOT NULL,
    maintainability_index double precision DEFAULT 0.0 NOT NULL,
    nesting_depth integer DEFAULT 0 NOT NULL,
    function_count integer DEFAULT 0 NOT NULL,
    class_count integer DEFAULT 0 NOT NULL,
    struct_count integer DEFAULT 0 NOT NULL,
    enum_count integer DEFAULT 0 NOT NULL,
    trait_count integer DEFAULT 0 NOT NULL,
    interface_count integer DEFAULT 0 NOT NULL,
    total_lines integer DEFAULT 0 NOT NULL,
    code_lines integer DEFAULT 0 NOT NULL,
    comment_lines integer DEFAULT 0 NOT NULL,
    blank_lines integer DEFAULT 0 NOT NULL,
    halstead_vocabulary integer DEFAULT 0 NOT NULL,
    halstead_length integer DEFAULT 0 NOT NULL,
    halstead_volume double precision DEFAULT 0.0 NOT NULL,
    halstead_difficulty double precision DEFAULT 0.0 NOT NULL,
    halstead_effort double precision DEFAULT 0.0 NOT NULL,
    pagerank_score double precision DEFAULT 0.0 NOT NULL,
    centrality_score double precision DEFAULT 0.0 NOT NULL,
    dependency_count integer DEFAULT 0 NOT NULL,
    dependent_count integer DEFAULT 0 NOT NULL,
    technical_debt_ratio double precision DEFAULT 0.0 NOT NULL,
    code_smells_count integer DEFAULT 0 NOT NULL,
    duplication_percentage double precision DEFAULT 0.0 NOT NULL,
    security_score double precision DEFAULT 0.0 NOT NULL,
    vulnerability_count integer DEFAULT 0 NOT NULL,
    quality_score double precision DEFAULT 0.0 NOT NULL,
    test_coverage double precision DEFAULT 0.0 NOT NULL,
    documentation_coverage double precision DEFAULT 0.0 NOT NULL,
    domains jsonb DEFAULT '[]'::jsonb,
    patterns jsonb DEFAULT '[]'::jsonb,
    features jsonb DEFAULT '[]'::jsonb,
    business_context jsonb DEFAULT '[]'::jsonb,
    performance_characteristics jsonb DEFAULT '[]'::jsonb,
    security_characteristics jsonb DEFAULT '[]'::jsonb,
    dependencies jsonb DEFAULT '[]'::jsonb,
    related_files jsonb DEFAULT '[]'::jsonb,
    imports jsonb DEFAULT '[]'::jsonb,
    exports jsonb DEFAULT '[]'::jsonb,
    functions jsonb DEFAULT '[]'::jsonb,
    classes jsonb DEFAULT '[]'::jsonb,
    structs jsonb DEFAULT '[]'::jsonb,
    enums jsonb DEFAULT '[]'::jsonb,
    traits jsonb DEFAULT '[]'::jsonb,
    vector_embedding public.vector(1536),
    inserted_at timestamp(0) without time zone DEFAULT now() NOT NULL,
    updated_at timestamp(0) without time zone DEFAULT now() NOT NULL
);


--
-- Name: codebase_metadata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.codebase_metadata_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: codebase_metadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.codebase_metadata_id_seq OWNED BY public.codebase_metadata.id;


--
-- Name: codebase_registry; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.codebase_registry (
    id bigint NOT NULL,
    codebase_id character varying(255) NOT NULL,
    codebase_path character varying(500) NOT NULL,
    codebase_name character varying(255) NOT NULL,
    description text,
    language character varying(50),
    framework character varying(100),
    last_analyzed timestamp(0) without time zone,
    analysis_status character varying(50) DEFAULT 'pending'::character varying,
    metadata jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone DEFAULT now() NOT NULL,
    updated_at timestamp(0) without time zone DEFAULT now() NOT NULL
);


--
-- Name: codebase_registry_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.codebase_registry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: codebase_registry_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.codebase_registry_id_seq OWNED BY public.codebase_registry.id;


--
-- Name: codebase_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.codebase_snapshots (
    id bigint NOT NULL,
    codebase_id character varying(255) NOT NULL,
    snapshot_id integer NOT NULL,
    metadata jsonb,
    summary jsonb,
    detected_technologies character varying(255)[] DEFAULT ARRAY[]::character varying[],
    features jsonb,
    inserted_at timestamp(0) without time zone DEFAULT now()
);


--
-- Name: codebase_snapshots_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.codebase_snapshots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: codebase_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.codebase_snapshots_id_seq OWNED BY public.codebase_snapshots.id;


--
-- Name: epics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.epics (
    id uuid NOT NULL,
    theme_id uuid,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    type character varying(255) NOT NULL,
    status character varying(255) DEFAULT 'ideation'::character varying,
    wsjf_score double precision DEFAULT 0.0,
    business_value integer DEFAULT 5,
    time_criticality integer DEFAULT 5,
    risk_reduction integer DEFAULT 5,
    job_size integer DEFAULT 8,
    approved_by character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: features; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.features (
    id uuid NOT NULL,
    capability_id uuid,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    status character varying(255) DEFAULT 'backlog'::character varying,
    htdag_id character varying(255),
    acceptance_criteria character varying(255)[] DEFAULT ARRAY[]::character varying[],
    approved_by character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: framework_patterns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.framework_patterns (
    id uuid NOT NULL,
    framework character varying(255) NOT NULL,
    pattern_type character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    code_template text,
    file_path_pattern character varying(255),
    dependencies character varying(255)[] DEFAULT ARRAY[]::character varying[],
    metadata jsonb DEFAULT '{}'::jsonb,
    embedding public.vector(768),
    active boolean DEFAULT true,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: git_agent_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.git_agent_sessions (
    id bigint NOT NULL,
    agent_id character varying(255) NOT NULL,
    branch character varying(255),
    workspace_path character varying(255) NOT NULL,
    correlation_id character varying(255),
    status character varying(255) DEFAULT 'active'::character varying NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: git_agent_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.git_agent_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: git_agent_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.git_agent_sessions_id_seq OWNED BY public.git_agent_sessions.id;


--
-- Name: git_merge_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.git_merge_history (
    id bigint NOT NULL,
    branch character varying(255) NOT NULL,
    agent_id character varying(255),
    task_id character varying(255),
    correlation_id character varying(255),
    merge_commit character varying(255),
    status character varying(255) NOT NULL,
    details jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: git_merge_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.git_merge_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: git_merge_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.git_merge_history_id_seq OWNED BY public.git_merge_history.id;


--
-- Name: git_pending_merges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.git_pending_merges (
    id bigint NOT NULL,
    branch character varying(255) NOT NULL,
    pr_number integer,
    agent_id character varying(255) NOT NULL,
    task_id character varying(255),
    correlation_id character varying(255),
    meta jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: git_pending_merges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.git_pending_merges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: git_pending_merges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.git_pending_merges_id_seq OWNED BY public.git_pending_merges.id;


--
-- Name: graph_edges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.graph_edges (
    id bigint NOT NULL,
    codebase_id character varying(255) NOT NULL,
    edge_id character varying(255) NOT NULL,
    from_node_id character varying(255) NOT NULL,
    to_node_id character varying(255) NOT NULL,
    edge_type character varying(100) NOT NULL,
    weight double precision DEFAULT 1.0 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(0) without time zone DEFAULT now()
);


--
-- Name: graph_edges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.graph_edges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: graph_edges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.graph_edges_id_seq OWNED BY public.graph_edges.id;


--
-- Name: graph_nodes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.graph_nodes (
    id bigint NOT NULL,
    codebase_id character varying(255) NOT NULL,
    node_id character varying(255) NOT NULL,
    node_type character varying(100) NOT NULL,
    name character varying(255) NOT NULL,
    file_path character varying(500) NOT NULL,
    line_number integer,
    vector_embedding public.vector(1536),
    vector_magnitude double precision,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(0) without time zone DEFAULT now()
);


--
-- Name: graph_nodes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.graph_nodes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: graph_nodes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.graph_nodes_id_seq OWNED BY public.graph_nodes.id;


--
-- Name: graph_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.graph_types (
    id bigint NOT NULL,
    graph_type character varying(100) NOT NULL,
    description text,
    created_at timestamp(0) without time zone DEFAULT now()
);


--
-- Name: graph_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.graph_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: graph_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.graph_types_id_seq OWNED BY public.graph_types.id;


--
-- Name: llm_calls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.llm_calls (
    id uuid NOT NULL,
    provider character varying(255) NOT NULL,
    model character varying(255) NOT NULL,
    prompt text,
    response text,
    tokens_used integer,
    cost_cents integer,
    latency_ms integer,
    metadata jsonb DEFAULT '{}'::jsonb,
    error text,
    success boolean DEFAULT true,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: quality_metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_metrics (
    id uuid NOT NULL,
    entity_type character varying(255) NOT NULL,
    entity_id character varying(255) NOT NULL,
    metric_type character varying(255) NOT NULL,
    value double precision NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: rag_documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rag_documents (
    id uuid NOT NULL,
    source_type character varying(255) NOT NULL,
    source_id character varying(255) NOT NULL,
    content text NOT NULL,
    embedding public.vector(768),
    metadata jsonb DEFAULT '{}'::jsonb,
    token_count integer,
    last_accessed timestamp(0) without time zone,
    access_count integer DEFAULT 0,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: rag_feedback; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rag_feedback (
    id uuid NOT NULL,
    query_id uuid,
    document_id uuid,
    relevance_score double precision,
    user_rating integer,
    metadata jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: rag_queries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rag_queries (
    id uuid NOT NULL,
    query_text text NOT NULL,
    query_embedding public.vector(768),
    result_ids uuid[] DEFAULT ARRAY[]::uuid[],
    response text,
    model_used character varying(255),
    tokens_used integer,
    latency_ms integer,
    metadata jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: rule_evolution_proposals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rule_evolution_proposals (
    id uuid NOT NULL,
    rule_id uuid NOT NULL,
    proposer_agent_id character varying(255) NOT NULL,
    proposed_patterns jsonb[] NOT NULL,
    proposed_threshold double precision,
    evolution_reasoning character varying(255) NOT NULL,
    trial_results jsonb,
    trial_confidence double precision,
    votes jsonb DEFAULT '{}'::jsonb,
    consensus_reached boolean DEFAULT false,
    status character varying(255) DEFAULT 'proposed'::character varying,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: rule_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rule_executions (
    id uuid NOT NULL,
    rule_id uuid NOT NULL,
    correlation_id uuid NOT NULL,
    confidence double precision NOT NULL,
    decision character varying(255) NOT NULL,
    reasoning character varying(255),
    execution_time_ms integer NOT NULL,
    context jsonb DEFAULT '{}'::jsonb NOT NULL,
    outcome character varying(255),
    outcome_recorded_at timestamp without time zone,
    executed_at timestamp without time zone NOT NULL
);


--
-- Name: rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rules (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    category character varying(255),
    condition jsonb DEFAULT '{}'::jsonb,
    action jsonb DEFAULT '{}'::jsonb,
    metadata jsonb DEFAULT '{}'::jsonb,
    priority integer DEFAULT 0,
    active boolean DEFAULT true,
    version integer DEFAULT 1,
    parent_id uuid,
    embedding public.vector(768),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: semantic_cache; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.semantic_cache (
    id uuid NOT NULL,
    cache_key character varying(255) NOT NULL,
    query text NOT NULL,
    query_embedding public.vector(768),
    response text NOT NULL,
    model character varying(255),
    template_id character varying(255),
    tokens_used integer,
    cost_cents integer,
    hit_count integer DEFAULT 0,
    last_accessed timestamp(0) without time zone,
    ttl_seconds integer,
    metadata jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: semantic_patterns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.semantic_patterns (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    pattern_type character varying(255) NOT NULL,
    description text,
    code_template text,
    language character varying(255),
    embedding public.vector(768),
    usage_count integer DEFAULT 0,
    quality_score double precision,
    metadata jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: strategic_themes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.strategic_themes (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    target_bloc double precision DEFAULT 0.0,
    priority integer DEFAULT 0,
    status character varying(255) DEFAULT 'active'::character varying,
    approved_by character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: t5_evaluation_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.t5_evaluation_results (
    id uuid NOT NULL,
    model_version_id uuid,
    test_dataset_id uuid,
    bleu_score double precision,
    rouge_score double precision,
    exact_match double precision,
    code_quality_score double precision,
    syntax_correctness double precision,
    semantic_similarity double precision,
    evaluation_metrics jsonb DEFAULT '{}'::jsonb,
    sample_predictions jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: t5_model_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.t5_model_versions (
    id uuid NOT NULL,
    training_session_id uuid,
    version character varying(255) NOT NULL,
    model_path character varying(255) NOT NULL,
    base_model character varying(255) NOT NULL,
    config jsonb DEFAULT '{}'::jsonb,
    performance_metrics jsonb DEFAULT '{}'::jsonb,
    is_deployed boolean DEFAULT false,
    is_active boolean DEFAULT false,
    deployed_at timestamp(0) without time zone,
    file_size_mb double precision DEFAULT 0.0,
    training_time_seconds integer DEFAULT 0,
    evaluation_results jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: t5_training_examples; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.t5_training_examples (
    id uuid NOT NULL,
    training_session_id uuid,
    code_chunk_id uuid,
    instruction text NOT NULL,
    input text NOT NULL,
    output text NOT NULL,
    language character varying(255) NOT NULL,
    file_path character varying(255),
    repo character varying(255),
    quality_score double precision DEFAULT 0.0,
    is_validation boolean DEFAULT false,
    metadata jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: t5_training_progress; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.t5_training_progress (
    id uuid NOT NULL,
    training_session_id uuid,
    epoch integer NOT NULL,
    step integer NOT NULL,
    loss double precision,
    learning_rate double precision,
    gradient_norm double precision,
    training_time_seconds integer,
    memory_usage_mb double precision,
    gpu_utilization_percent double precision,
    metrics jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: t5_training_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.t5_training_sessions (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    language character varying(255) NOT NULL,
    base_model character varying(255) DEFAULT 'Salesforce/codet5p-770m'::character varying,
    status character varying(255) DEFAULT 'pending'::character varying,
    config jsonb DEFAULT '{}'::jsonb,
    training_data_query text,
    training_examples_count integer DEFAULT 0,
    validation_examples_count integer DEFAULT 0,
    started_at timestamp(0) without time zone,
    completed_at timestamp(0) without time zone,
    error_message text,
    model_path character varying(255),
    performance_metrics jsonb DEFAULT '{}'::jsonb,
    is_deployed boolean DEFAULT false,
    is_active boolean DEFAULT false,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: technology_knowledge; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.technology_knowledge (
    id uuid NOT NULL,
    technology character varying(255) NOT NULL,
    category character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    template text,
    examples text[] DEFAULT ARRAY[]::text[],
    best_practices text,
    antipatterns character varying(255)[] DEFAULT ARRAY[]::character varying[],
    metadata jsonb DEFAULT '{}'::jsonb,
    embedding public.vector(768),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: technology_patterns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.technology_patterns (
    id bigint NOT NULL,
    technology_name character varying(255) NOT NULL,
    technology_type character varying(255) NOT NULL,
    version_pattern character varying(255),
    file_patterns text[] DEFAULT ARRAY[]::text[],
    directory_patterns text[] DEFAULT ARRAY[]::text[],
    config_files text[] DEFAULT ARRAY[]::text[],
    build_command text,
    dev_command text,
    install_command text,
    test_command text,
    output_directory text,
    confidence_weight double precision DEFAULT 1.0,
    detection_count integer DEFAULT 0,
    success_rate double precision DEFAULT 1.0,
    last_detected_at timestamp without time zone,
    extended_metadata jsonb,
    created_at timestamp(6) without time zone DEFAULT now() NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT now() NOT NULL
);


--
-- Name: technology_patterns_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.technology_patterns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: technology_patterns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.technology_patterns_id_seq OWNED BY public.technology_patterns.id;


--
-- Name: technology_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.technology_templates (
    id bigint NOT NULL,
    identifier character varying(255) NOT NULL,
    category character varying(255) NOT NULL,
    version character varying(255),
    source character varying(255),
    template jsonb NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    checksum character varying(64),
    inserted_at timestamp(6) without time zone DEFAULT now() NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT now() NOT NULL
);


--
-- Name: technology_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.technology_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: technology_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.technology_templates_id_seq OWNED BY public.technology_templates.id;


--
-- Name: tool_dependencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tool_dependencies (
    id uuid NOT NULL,
    tool_id uuid NOT NULL,
    dependency_name character varying(255) NOT NULL,
    dependency_version character varying(255),
    dependency_type character varying(255),
    is_optional boolean DEFAULT false,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: tool_examples; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tool_examples (
    id uuid NOT NULL,
    tool_id uuid NOT NULL,
    title character varying(255) NOT NULL,
    code text NOT NULL,
    language character varying(255),
    explanation text,
    tags character varying(255)[] DEFAULT ARRAY[]::character varying[],
    code_embedding public.vector(768),
    example_order integer DEFAULT 0,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: tool_knowledge; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tool_knowledge (
    id uuid NOT NULL,
    tool_name character varying(255) NOT NULL,
    category character varying(255) NOT NULL,
    subcategory character varying(255),
    description text,
    version character varying(255),
    language character varying(255),
    package_manager character varying(255),
    install_command text,
    usage_examples text[] DEFAULT ARRAY[]::text[],
    common_flags jsonb DEFAULT '{}'::jsonb,
    integrations character varying(255)[] DEFAULT ARRAY[]::character varying[],
    alternatives character varying(255)[] DEFAULT ARRAY[]::character varying[],
    performance_tips text,
    troubleshooting jsonb DEFAULT '{}'::jsonb,
    documentation_url character varying(255),
    source_url character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb,
    embeddings public.vector(768),
    search_vector tsvector,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: tool_patterns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tool_patterns (
    id uuid NOT NULL,
    tool_id uuid NOT NULL,
    pattern_type character varying(255),
    title character varying(255) NOT NULL,
    description text,
    code_example text,
    tags character varying(255)[] DEFAULT ARRAY[]::character varying[],
    pattern_embedding public.vector(768),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: tools; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tools (
    id uuid NOT NULL,
    package_name character varying(255) NOT NULL,
    version character varying(255) NOT NULL,
    ecosystem character varying(255) NOT NULL,
    description text,
    documentation text,
    homepage_url character varying(255),
    repository_url character varying(255),
    license character varying(255),
    tags character varying(255)[] DEFAULT ARRAY[]::character varying[],
    categories character varying(255)[] DEFAULT ARRAY[]::character varying[],
    keywords character varying(255)[] DEFAULT ARRAY[]::character varying[],
    semantic_embedding public.vector(768),
    description_embedding public.vector(768),
    download_count integer DEFAULT 0,
    github_stars integer DEFAULT 0,
    last_release_date timestamp(0) without time zone,
    source_url character varying(255),
    collected_at timestamp(0) without time zone,
    last_updated_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: vector_search; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vector_search (
    id bigint NOT NULL,
    codebase_id character varying(255) NOT NULL,
    file_path character varying(500) NOT NULL,
    content_type character varying(100) NOT NULL,
    content text NOT NULL,
    vector_embedding public.vector(1536) NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(0) without time zone DEFAULT now()
);


--
-- Name: vector_search_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.vector_search_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: vector_search_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.vector_search_id_seq OWNED BY public.vector_search.id;


--
-- Name: vector_similarity_cache; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vector_similarity_cache (
    id bigint NOT NULL,
    codebase_id character varying(255) NOT NULL,
    query_vector_hash character varying(64) NOT NULL,
    target_file_path character varying(500) NOT NULL,
    similarity_score double precision NOT NULL,
    created_at timestamp(0) without time zone DEFAULT now()
);


--
-- Name: vector_similarity_cache_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.vector_similarity_cache_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: vector_similarity_cache_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.vector_similarity_cache_id_seq OWNED BY public.vector_similarity_cache.id;


--
-- Name: codebase_metadata id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.codebase_metadata ALTER COLUMN id SET DEFAULT nextval('public.codebase_metadata_id_seq'::regclass);


--
-- Name: codebase_registry id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.codebase_registry ALTER COLUMN id SET DEFAULT nextval('public.codebase_registry_id_seq'::regclass);


--
-- Name: codebase_snapshots id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.codebase_snapshots ALTER COLUMN id SET DEFAULT nextval('public.codebase_snapshots_id_seq'::regclass);


--
-- Name: git_agent_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.git_agent_sessions ALTER COLUMN id SET DEFAULT nextval('public.git_agent_sessions_id_seq'::regclass);


--
-- Name: git_merge_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.git_merge_history ALTER COLUMN id SET DEFAULT nextval('public.git_merge_history_id_seq'::regclass);


--
-- Name: git_pending_merges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.git_pending_merges ALTER COLUMN id SET DEFAULT nextval('public.git_pending_merges_id_seq'::regclass);


--
-- Name: graph_edges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.graph_edges ALTER COLUMN id SET DEFAULT nextval('public.graph_edges_id_seq'::regclass);


--
-- Name: graph_nodes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.graph_nodes ALTER COLUMN id SET DEFAULT nextval('public.graph_nodes_id_seq'::regclass);


--
-- Name: graph_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.graph_types ALTER COLUMN id SET DEFAULT nextval('public.graph_types_id_seq'::regclass);


--
-- Name: technology_patterns id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.technology_patterns ALTER COLUMN id SET DEFAULT nextval('public.technology_patterns_id_seq'::regclass);


--
-- Name: technology_templates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.technology_templates ALTER COLUMN id SET DEFAULT nextval('public.technology_templates_id_seq'::regclass);


--
-- Name: vector_search id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vector_search ALTER COLUMN id SET DEFAULT nextval('public.vector_search_id_seq'::regclass);


--
-- Name: vector_similarity_cache id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vector_similarity_cache ALTER COLUMN id SET DEFAULT nextval('public.vector_similarity_cache_id_seq'::regclass);


--
-- Name: analysis_summaries analysis_summaries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_summaries
    ADD CONSTRAINT analysis_summaries_pkey PRIMARY KEY (id);


--
-- Name: capabilities capabilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capabilities
    ADD CONSTRAINT capabilities_pkey PRIMARY KEY (id);


--
-- Name: capability_dependencies capability_dependencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capability_dependencies
    ADD CONSTRAINT capability_dependencies_pkey PRIMARY KEY (id);


--
-- Name: code_embeddings code_embeddings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.code_embeddings
    ADD CONSTRAINT code_embeddings_pkey PRIMARY KEY (id);


--
-- Name: code_files code_files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.code_files
    ADD CONSTRAINT code_files_pkey PRIMARY KEY (id);


--
-- Name: code_fingerprints code_fingerprints_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.code_fingerprints
    ADD CONSTRAINT code_fingerprints_pkey PRIMARY KEY (id);


--
-- Name: code_locations code_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.code_locations
    ADD CONSTRAINT code_locations_pkey PRIMARY KEY (id);


--
-- Name: codebase_chunk_embeddings codebase_chunk_embeddings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.codebase_chunk_embeddings
    ADD CONSTRAINT codebase_chunk_embeddings_pkey PRIMARY KEY (id);


--
-- Name: codebase_chunks codebase_chunks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.codebase_chunks
    ADD CONSTRAINT codebase_chunks_pkey PRIMARY KEY (id);


--
-- Name: codebase_metadata codebase_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.codebase_metadata
    ADD CONSTRAINT codebase_metadata_pkey PRIMARY KEY (id);


--
-- Name: codebase_registry codebase_registry_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.codebase_registry
    ADD CONSTRAINT codebase_registry_pkey PRIMARY KEY (id);


--
-- Name: codebase_snapshots codebase_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.codebase_snapshots
    ADD CONSTRAINT codebase_snapshots_pkey PRIMARY KEY (id);


--
-- Name: epics epics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.epics
    ADD CONSTRAINT epics_pkey PRIMARY KEY (id);


--
-- Name: features features_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.features
    ADD CONSTRAINT features_pkey PRIMARY KEY (id);


--
-- Name: framework_patterns framework_patterns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.framework_patterns
    ADD CONSTRAINT framework_patterns_pkey PRIMARY KEY (id);


--
-- Name: git_agent_sessions git_agent_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.git_agent_sessions
    ADD CONSTRAINT git_agent_sessions_pkey PRIMARY KEY (id);


--
-- Name: git_merge_history git_merge_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.git_merge_history
    ADD CONSTRAINT git_merge_history_pkey PRIMARY KEY (id);


--
-- Name: git_pending_merges git_pending_merges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.git_pending_merges
    ADD CONSTRAINT git_pending_merges_pkey PRIMARY KEY (id);


--
-- Name: graph_edges graph_edges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.graph_edges
    ADD CONSTRAINT graph_edges_pkey PRIMARY KEY (id);


--
-- Name: graph_nodes graph_nodes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.graph_nodes
    ADD CONSTRAINT graph_nodes_pkey PRIMARY KEY (id);


--
-- Name: graph_types graph_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.graph_types
    ADD CONSTRAINT graph_types_pkey PRIMARY KEY (id);


--
-- Name: llm_calls llm_calls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_calls
    ADD CONSTRAINT llm_calls_pkey PRIMARY KEY (id);


--
-- Name: quality_metrics quality_metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_metrics
    ADD CONSTRAINT quality_metrics_pkey PRIMARY KEY (id);


--
-- Name: rag_documents rag_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rag_documents
    ADD CONSTRAINT rag_documents_pkey PRIMARY KEY (id);


--
-- Name: rag_feedback rag_feedback_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rag_feedback
    ADD CONSTRAINT rag_feedback_pkey PRIMARY KEY (id);


--
-- Name: rag_queries rag_queries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rag_queries
    ADD CONSTRAINT rag_queries_pkey PRIMARY KEY (id);


--
-- Name: rule_evolution_proposals rule_evolution_proposals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_evolution_proposals
    ADD CONSTRAINT rule_evolution_proposals_pkey PRIMARY KEY (id);


--
-- Name: rule_executions rule_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_executions
    ADD CONSTRAINT rule_executions_pkey PRIMARY KEY (id);


--
-- Name: rules rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rules
    ADD CONSTRAINT rules_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: semantic_cache semantic_cache_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.semantic_cache
    ADD CONSTRAINT semantic_cache_pkey PRIMARY KEY (id);


--
-- Name: semantic_patterns semantic_patterns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.semantic_patterns
    ADD CONSTRAINT semantic_patterns_pkey PRIMARY KEY (id);


--
-- Name: strategic_themes strategic_themes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategic_themes
    ADD CONSTRAINT strategic_themes_pkey PRIMARY KEY (id);


--
-- Name: t5_evaluation_results t5_evaluation_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.t5_evaluation_results
    ADD CONSTRAINT t5_evaluation_results_pkey PRIMARY KEY (id);


--
-- Name: t5_model_versions t5_model_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.t5_model_versions
    ADD CONSTRAINT t5_model_versions_pkey PRIMARY KEY (id);


--
-- Name: t5_training_examples t5_training_examples_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.t5_training_examples
    ADD CONSTRAINT t5_training_examples_pkey PRIMARY KEY (id);


--
-- Name: t5_training_progress t5_training_progress_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.t5_training_progress
    ADD CONSTRAINT t5_training_progress_pkey PRIMARY KEY (id);


--
-- Name: t5_training_sessions t5_training_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.t5_training_sessions
    ADD CONSTRAINT t5_training_sessions_pkey PRIMARY KEY (id);


--
-- Name: technology_knowledge technology_knowledge_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.technology_knowledge
    ADD CONSTRAINT technology_knowledge_pkey PRIMARY KEY (id);


--
-- Name: technology_patterns technology_patterns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.technology_patterns
    ADD CONSTRAINT technology_patterns_pkey PRIMARY KEY (id);


--
-- Name: technology_templates technology_templates_identifier_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.technology_templates
    ADD CONSTRAINT technology_templates_identifier_key UNIQUE (identifier);


--
-- Name: technology_templates technology_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.technology_templates
    ADD CONSTRAINT technology_templates_pkey PRIMARY KEY (id);


--
-- Name: tool_dependencies tool_dependencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tool_dependencies
    ADD CONSTRAINT tool_dependencies_pkey PRIMARY KEY (id);


--
-- Name: tool_examples tool_examples_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tool_examples
    ADD CONSTRAINT tool_examples_pkey PRIMARY KEY (id);


--
-- Name: tool_knowledge tool_knowledge_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tool_knowledge
    ADD CONSTRAINT tool_knowledge_pkey PRIMARY KEY (id);


--
-- Name: tool_patterns tool_patterns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tool_patterns
    ADD CONSTRAINT tool_patterns_pkey PRIMARY KEY (id);


--
-- Name: tools tools_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tools
    ADD CONSTRAINT tools_pkey PRIMARY KEY (id);


--
-- Name: vector_search vector_search_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vector_search
    ADD CONSTRAINT vector_search_pkey PRIMARY KEY (id);


--
-- Name: vector_similarity_cache vector_similarity_cache_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vector_similarity_cache
    ADD CONSTRAINT vector_similarity_cache_pkey PRIMARY KEY (id);


--
-- Name: analysis_summaries_analyzed_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX analysis_summaries_analyzed_at_index ON public.analysis_summaries USING btree (analyzed_at);


--
-- Name: analysis_summaries_codebase_id_analyzed_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX analysis_summaries_codebase_id_analyzed_at_index ON public.analysis_summaries USING btree (codebase_id, analyzed_at);


--
-- Name: analysis_summaries_codebase_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX analysis_summaries_codebase_id_index ON public.analysis_summaries USING btree (codebase_id);


--
-- Name: analysis_summaries_quality_score_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX analysis_summaries_quality_score_index ON public.analysis_summaries USING btree (quality_score);


--
-- Name: analysis_summaries_technical_debt_ratio_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX analysis_summaries_technical_debt_ratio_index ON public.analysis_summaries USING btree (technical_debt_ratio);


--
-- Name: capabilities_epic_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX capabilities_epic_id_index ON public.capabilities USING btree (epic_id);


--
-- Name: capabilities_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX capabilities_status_index ON public.capabilities USING btree (status);


--
-- Name: capabilities_wsjf_score_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX capabilities_wsjf_score_index ON public.capabilities USING btree (wsjf_score);


--
-- Name: capability_dependencies_capability_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX capability_dependencies_capability_id_index ON public.capability_dependencies USING btree (capability_id);


--
-- Name: capability_dependencies_depends_on_capability_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX capability_dependencies_depends_on_capability_id_index ON public.capability_dependencies USING btree (depends_on_capability_id);


--
-- Name: capability_dependencies_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX capability_dependencies_unique ON public.capability_dependencies USING btree (capability_id, depends_on_capability_id);


--
-- Name: code_embeddings_chunk_index_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX code_embeddings_chunk_index_index ON public.code_embeddings USING btree (chunk_index);


--
-- Name: code_embeddings_code_file_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX code_embeddings_code_file_id_index ON public.code_embeddings USING btree (code_file_id);


--
-- Name: code_files_ast_json_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX code_files_ast_json_index ON public.code_files USING gin (ast_json);


--
-- Name: code_files_classes_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX code_files_classes_index ON public.code_files USING gin (classes);


--
-- Name: code_files_codebase_id_file_path_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX code_files_codebase_id_file_path_index ON public.code_files USING btree (codebase_id, file_path);


--
-- Name: code_files_codebase_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX code_files_codebase_id_index ON public.code_files USING btree (codebase_id);


--
-- Name: code_files_exports_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX code_files_exports_index ON public.code_files USING gin (exports);


--
-- Name: code_files_functions_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX code_files_functions_index ON public.code_files USING gin (functions);


--
-- Name: code_files_hash_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX code_files_hash_index ON public.code_files USING btree (hash);


--
-- Name: code_files_imports_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX code_files_imports_index ON public.code_files USING gin (imports);


--
-- Name: code_files_language_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX code_files_language_index ON public.code_files USING btree (language);


--
-- Name: code_files_metadata_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX code_files_metadata_index ON public.code_files USING gin (metadata);


--
-- Name: code_files_symbols_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX code_files_symbols_index ON public.code_files USING gin (symbols);


--
-- Name: code_fingerprints_content_hash_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX code_fingerprints_content_hash_index ON public.code_fingerprints USING btree (content_hash);


--
-- Name: code_fingerprints_file_path_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX code_fingerprints_file_path_index ON public.code_fingerprints USING btree (file_path);


--
-- Name: code_fingerprints_language_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX code_fingerprints_language_index ON public.code_fingerprints USING btree (language);


--
-- Name: code_fingerprints_structural_hash_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX code_fingerprints_structural_hash_index ON public.code_fingerprints USING btree (structural_hash);


--
-- Name: code_locations_parent_symbol_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX code_locations_parent_symbol_index ON public.code_locations USING btree (parent_symbol);


--
-- Name: code_locations_project_file_path_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX code_locations_project_file_path_index ON public.code_locations USING btree (project, file_path);


--
-- Name: code_locations_symbol_type_symbol_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX code_locations_symbol_type_symbol_name_index ON public.code_locations USING btree (symbol_type, symbol_name);


--
-- Name: codebase_chunk_embeddings_chunk_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_chunk_embeddings_chunk_id_index ON public.codebase_chunk_embeddings USING btree (chunk_id);


--
-- Name: codebase_chunk_embeddings_embedding_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_chunk_embeddings_embedding_idx ON public.codebase_chunk_embeddings USING ivfflat (embedding public.vector_cosine_ops) WITH (lists='100');


--
-- Name: codebase_chunk_embeddings_model_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_chunk_embeddings_model_name_index ON public.codebase_chunk_embeddings USING btree (model_name);


--
-- Name: codebase_chunks_chunk_index_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_chunks_chunk_index_index ON public.codebase_chunks USING btree (chunk_index);


--
-- Name: codebase_chunks_chunk_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_chunks_chunk_type_index ON public.codebase_chunks USING btree (chunk_type);


--
-- Name: codebase_chunks_code_file_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_chunks_code_file_id_index ON public.codebase_chunks USING btree (code_file_id);


--
-- Name: codebase_metadata_codebase_id_cyclomatic_complexity_cognitive_c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_metadata_codebase_id_cyclomatic_complexity_cognitive_c ON public.codebase_metadata USING btree (codebase_id, cyclomatic_complexity, cognitive_complexity);


--
-- Name: codebase_metadata_codebase_id_file_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_metadata_codebase_id_file_type_index ON public.codebase_metadata USING btree (codebase_id, file_type);


--
-- Name: codebase_metadata_codebase_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_metadata_codebase_id_index ON public.codebase_metadata USING btree (codebase_id);


--
-- Name: codebase_metadata_codebase_id_language_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_metadata_codebase_id_language_index ON public.codebase_metadata USING btree (codebase_id, language);


--
-- Name: codebase_metadata_codebase_id_pagerank_score_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_metadata_codebase_id_pagerank_score_index ON public.codebase_metadata USING btree (codebase_id, pagerank_score);


--
-- Name: codebase_metadata_codebase_id_path_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX codebase_metadata_codebase_id_path_index ON public.codebase_metadata USING btree (codebase_id, path);


--
-- Name: codebase_metadata_codebase_id_quality_score_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_metadata_codebase_id_quality_score_index ON public.codebase_metadata USING btree (codebase_id, quality_score);


--
-- Name: codebase_metadata_codebase_path_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_metadata_codebase_path_index ON public.codebase_metadata USING btree (codebase_path);


--
-- Name: codebase_registry_analysis_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_registry_analysis_status_index ON public.codebase_registry USING btree (analysis_status);


--
-- Name: codebase_registry_codebase_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX codebase_registry_codebase_id_index ON public.codebase_registry USING btree (codebase_id);


--
-- Name: codebase_registry_codebase_path_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_registry_codebase_path_index ON public.codebase_registry USING btree (codebase_path);


--
-- Name: codebase_snapshots_codebase_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_snapshots_codebase_id_index ON public.codebase_snapshots USING btree (codebase_id);


--
-- Name: codebase_snapshots_codebase_id_snapshot_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX codebase_snapshots_codebase_id_snapshot_id_index ON public.codebase_snapshots USING btree (codebase_id, snapshot_id);


--
-- Name: codebase_snapshots_detected_technologies_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_snapshots_detected_technologies_index ON public.codebase_snapshots USING gin (detected_technologies);


--
-- Name: codebase_snapshots_features_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_snapshots_features_index ON public.codebase_snapshots USING gin (features);


--
-- Name: codebase_snapshots_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_snapshots_inserted_at_index ON public.codebase_snapshots USING btree (inserted_at);


--
-- Name: codebase_snapshots_metadata_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_snapshots_metadata_index ON public.codebase_snapshots USING gin (metadata);


--
-- Name: codebase_snapshots_snapshot_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX codebase_snapshots_snapshot_id_index ON public.codebase_snapshots USING btree (snapshot_id);


--
-- Name: epics_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX epics_status_index ON public.epics USING btree (status);


--
-- Name: epics_theme_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX epics_theme_id_index ON public.epics USING btree (theme_id);


--
-- Name: epics_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX epics_type_index ON public.epics USING btree (type);


--
-- Name: epics_wsjf_score_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX epics_wsjf_score_index ON public.epics USING btree (wsjf_score);


--
-- Name: features_capability_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX features_capability_id_index ON public.features USING btree (capability_id);


--
-- Name: features_htdag_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX features_htdag_id_index ON public.features USING btree (htdag_id);


--
-- Name: features_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX features_status_index ON public.features USING btree (status);


--
-- Name: framework_patterns_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX framework_patterns_active_index ON public.framework_patterns USING btree (active);


--
-- Name: framework_patterns_framework_pattern_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX framework_patterns_framework_pattern_type_index ON public.framework_patterns USING btree (framework, pattern_type);


--
-- Name: git_agent_sessions_agent_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX git_agent_sessions_agent_id_index ON public.git_agent_sessions USING btree (agent_id);


--
-- Name: git_agent_sessions_branch_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX git_agent_sessions_branch_index ON public.git_agent_sessions USING btree (branch);


--
-- Name: git_agent_sessions_correlation_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX git_agent_sessions_correlation_id_index ON public.git_agent_sessions USING btree (correlation_id);


--
-- Name: git_agent_sessions_meta_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX git_agent_sessions_meta_index ON public.git_agent_sessions USING gin (meta);


--
-- Name: git_agent_sessions_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX git_agent_sessions_status_index ON public.git_agent_sessions USING btree (status);


--
-- Name: git_merge_history_agent_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX git_merge_history_agent_id_index ON public.git_merge_history USING btree (agent_id);


--
-- Name: git_merge_history_agent_id_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX git_merge_history_agent_id_inserted_at_index ON public.git_merge_history USING btree (agent_id, inserted_at);


--
-- Name: git_merge_history_branch_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX git_merge_history_branch_index ON public.git_merge_history USING btree (branch);


--
-- Name: git_merge_history_branch_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX git_merge_history_branch_status_index ON public.git_merge_history USING btree (branch, status);


--
-- Name: git_merge_history_details_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX git_merge_history_details_index ON public.git_merge_history USING gin (details);


--
-- Name: git_merge_history_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX git_merge_history_inserted_at_index ON public.git_merge_history USING btree (inserted_at);


--
-- Name: git_merge_history_merge_commit_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX git_merge_history_merge_commit_index ON public.git_merge_history USING btree (merge_commit);


--
-- Name: git_merge_history_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX git_merge_history_status_index ON public.git_merge_history USING btree (status);


--
-- Name: git_pending_merges_agent_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX git_pending_merges_agent_id_index ON public.git_pending_merges USING btree (agent_id);


--
-- Name: git_pending_merges_branch_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX git_pending_merges_branch_index ON public.git_pending_merges USING btree (branch);


--
-- Name: git_pending_merges_correlation_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX git_pending_merges_correlation_id_index ON public.git_pending_merges USING btree (correlation_id);


--
-- Name: git_pending_merges_meta_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX git_pending_merges_meta_index ON public.git_pending_merges USING gin (meta);


--
-- Name: git_pending_merges_pr_number_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX git_pending_merges_pr_number_index ON public.git_pending_merges USING btree (pr_number);


--
-- Name: git_pending_merges_task_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX git_pending_merges_task_id_index ON public.git_pending_merges USING btree (task_id);


--
-- Name: graph_edges_codebase_id_edge_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX graph_edges_codebase_id_edge_id_index ON public.graph_edges USING btree (codebase_id, edge_id);


--
-- Name: graph_edges_codebase_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX graph_edges_codebase_id_index ON public.graph_edges USING btree (codebase_id);


--
-- Name: graph_edges_edge_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX graph_edges_edge_type_index ON public.graph_edges USING btree (edge_type);


--
-- Name: graph_edges_from_node_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX graph_edges_from_node_id_index ON public.graph_edges USING btree (from_node_id);


--
-- Name: graph_edges_to_node_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX graph_edges_to_node_id_index ON public.graph_edges USING btree (to_node_id);


--
-- Name: graph_nodes_codebase_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX graph_nodes_codebase_id_index ON public.graph_nodes USING btree (codebase_id);


--
-- Name: graph_nodes_codebase_id_node_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX graph_nodes_codebase_id_node_id_index ON public.graph_nodes USING btree (codebase_id, node_id);


--
-- Name: graph_nodes_codebase_id_node_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX graph_nodes_codebase_id_node_type_index ON public.graph_nodes USING btree (codebase_id, node_type);


--
-- Name: graph_types_graph_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX graph_types_graph_type_index ON public.graph_types USING btree (graph_type);


--
-- Name: idx_code_embeddings_embedding_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_code_embeddings_embedding_vector ON public.code_embeddings USING ivfflat (embedding public.vector_cosine_ops) WITH (lists='100');


--
-- Name: idx_code_locations_embedding_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_code_locations_embedding_vector ON public.code_locations USING ivfflat (embedding public.vector_cosine_ops) WITH (lists='100');


--
-- Name: idx_codebase_metadata_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_codebase_metadata_vector ON public.codebase_metadata USING ivfflat (vector_embedding public.vector_cosine_ops) WITH (lists='100');


--
-- Name: idx_graph_nodes_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_graph_nodes_vector ON public.graph_nodes USING ivfflat (vector_embedding public.vector_cosine_ops) WITH (lists='100');


--
-- Name: idx_rag_documents_embedding_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rag_documents_embedding_vector ON public.rag_documents USING ivfflat (embedding public.vector_cosine_ops) WITH (lists='100');


--
-- Name: idx_rag_queries_query_embedding_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rag_queries_query_embedding_vector ON public.rag_queries USING ivfflat (query_embedding public.vector_cosine_ops) WITH (lists='100');


--
-- Name: idx_rules_embedding_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rules_embedding_vector ON public.rules USING ivfflat (embedding public.vector_cosine_ops) WITH (lists='100');


--
-- Name: idx_semantic_cache_query_embedding_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_semantic_cache_query_embedding_vector ON public.semantic_cache USING ivfflat (query_embedding public.vector_cosine_ops) WITH (lists='100');


--
-- Name: idx_vector_search_embedding; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vector_search_embedding ON public.vector_search USING ivfflat (vector_embedding public.vector_cosine_ops) WITH (lists='100');


--
-- Name: llm_calls_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX llm_calls_inserted_at_index ON public.llm_calls USING btree (inserted_at);


--
-- Name: llm_calls_metadata_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX llm_calls_metadata_index ON public.llm_calls USING gin (metadata);


--
-- Name: llm_calls_provider_model_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX llm_calls_provider_model_index ON public.llm_calls USING btree (provider, model);


--
-- Name: llm_calls_success_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX llm_calls_success_index ON public.llm_calls USING btree (success);


--
-- Name: quality_metrics_entity_type_entity_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX quality_metrics_entity_type_entity_id_index ON public.quality_metrics USING btree (entity_type, entity_id);


--
-- Name: quality_metrics_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX quality_metrics_inserted_at_index ON public.quality_metrics USING btree (inserted_at);


--
-- Name: quality_metrics_metric_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX quality_metrics_metric_type_index ON public.quality_metrics USING btree (metric_type);


--
-- Name: rag_documents_access_count_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rag_documents_access_count_index ON public.rag_documents USING btree (access_count);


--
-- Name: rag_documents_last_accessed_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rag_documents_last_accessed_index ON public.rag_documents USING btree (last_accessed);


--
-- Name: rag_documents_source_type_source_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX rag_documents_source_type_source_id_index ON public.rag_documents USING btree (source_type, source_id);


--
-- Name: rag_feedback_document_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rag_feedback_document_id_index ON public.rag_feedback USING btree (document_id);


--
-- Name: rag_feedback_query_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rag_feedback_query_id_index ON public.rag_feedback USING btree (query_id);


--
-- Name: rag_queries_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rag_queries_inserted_at_index ON public.rag_queries USING btree (inserted_at);


--
-- Name: rule_evolution_proposals_consensus_reached_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_evolution_proposals_consensus_reached_index ON public.rule_evolution_proposals USING btree (consensus_reached);


--
-- Name: rule_evolution_proposals_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_evolution_proposals_inserted_at_index ON public.rule_evolution_proposals USING btree (inserted_at);


--
-- Name: rule_evolution_proposals_proposer_agent_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_evolution_proposals_proposer_agent_id_index ON public.rule_evolution_proposals USING btree (proposer_agent_id);


--
-- Name: rule_evolution_proposals_rule_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_evolution_proposals_rule_id_index ON public.rule_evolution_proposals USING btree (rule_id);


--
-- Name: rule_evolution_proposals_rule_id_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_evolution_proposals_rule_id_status_index ON public.rule_evolution_proposals USING btree (rule_id, status);


--
-- Name: rule_evolution_proposals_status_consensus_reached_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_evolution_proposals_status_consensus_reached_index ON public.rule_evolution_proposals USING btree (status, consensus_reached);


--
-- Name: rule_evolution_proposals_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_evolution_proposals_status_index ON public.rule_evolution_proposals USING btree (status);


--
-- Name: rule_evolution_proposals_votes_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_evolution_proposals_votes_index ON public.rule_evolution_proposals USING gin (votes);


--
-- Name: rule_executions_context_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_executions_context_index ON public.rule_executions USING gin (context);


--
-- Name: rule_executions_correlation_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_executions_correlation_id_index ON public.rule_executions USING btree (correlation_id);


--
-- Name: rule_executions_decision_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_executions_decision_index ON public.rule_executions USING btree (decision);


--
-- Name: rule_executions_executed_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_executions_executed_at_index ON public.rule_executions USING btree (executed_at);


--
-- Name: rule_executions_outcome_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_executions_outcome_index ON public.rule_executions USING btree (outcome);


--
-- Name: rule_executions_rule_id_executed_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_executions_rule_id_executed_at_index ON public.rule_executions USING btree (rule_id, executed_at);


--
-- Name: rule_executions_rule_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_executions_rule_id_index ON public.rule_executions USING btree (rule_id);


--
-- Name: rules_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rules_active_index ON public.rules USING btree (active);


--
-- Name: rules_category_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rules_category_index ON public.rules USING btree (category);


--
-- Name: rules_condition_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rules_condition_index ON public.rules USING gin (condition);


--
-- Name: rules_metadata_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rules_metadata_index ON public.rules USING gin (metadata);


--
-- Name: rules_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rules_name_index ON public.rules USING btree (name);


--
-- Name: rules_parent_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rules_parent_id_index ON public.rules USING btree (parent_id);


--
-- Name: rules_priority_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rules_priority_index ON public.rules USING btree (priority);


--
-- Name: semantic_cache_cache_key_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX semantic_cache_cache_key_index ON public.semantic_cache USING btree (cache_key);


--
-- Name: semantic_cache_hit_count_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX semantic_cache_hit_count_index ON public.semantic_cache USING btree (hit_count);


--
-- Name: semantic_cache_last_accessed_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX semantic_cache_last_accessed_index ON public.semantic_cache USING btree (last_accessed);


--
-- Name: semantic_patterns_language_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX semantic_patterns_language_index ON public.semantic_patterns USING btree (language);


--
-- Name: semantic_patterns_pattern_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX semantic_patterns_pattern_type_index ON public.semantic_patterns USING btree (pattern_type);


--
-- Name: semantic_patterns_usage_count_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX semantic_patterns_usage_count_index ON public.semantic_patterns USING btree (usage_count);


--
-- Name: strategic_themes_priority_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX strategic_themes_priority_index ON public.strategic_themes USING btree (priority);


--
-- Name: strategic_themes_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX strategic_themes_status_index ON public.strategic_themes USING btree (status);


--
-- Name: t5_evaluation_results_bleu_score_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX t5_evaluation_results_bleu_score_index ON public.t5_evaluation_results USING btree (bleu_score);


--
-- Name: t5_evaluation_results_code_quality_score_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX t5_evaluation_results_code_quality_score_index ON public.t5_evaluation_results USING btree (code_quality_score);


--
-- Name: t5_evaluation_results_model_version_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX t5_evaluation_results_model_version_id_index ON public.t5_evaluation_results USING btree (model_version_id);


--
-- Name: t5_model_versions_is_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX t5_model_versions_is_active_index ON public.t5_model_versions USING btree (is_active);


--
-- Name: t5_model_versions_is_deployed_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX t5_model_versions_is_deployed_index ON public.t5_model_versions USING btree (is_deployed);


--
-- Name: t5_model_versions_training_session_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX t5_model_versions_training_session_id_index ON public.t5_model_versions USING btree (training_session_id);


--
-- Name: t5_model_versions_version_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX t5_model_versions_version_index ON public.t5_model_versions USING btree (version);


--
-- Name: t5_training_examples_is_validation_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX t5_training_examples_is_validation_index ON public.t5_training_examples USING btree (is_validation);


--
-- Name: t5_training_examples_language_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX t5_training_examples_language_index ON public.t5_training_examples USING btree (language);


--
-- Name: t5_training_examples_quality_score_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX t5_training_examples_quality_score_index ON public.t5_training_examples USING btree (quality_score);


--
-- Name: t5_training_examples_training_session_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX t5_training_examples_training_session_id_index ON public.t5_training_examples USING btree (training_session_id);


--
-- Name: t5_training_progress_epoch_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX t5_training_progress_epoch_index ON public.t5_training_progress USING btree (epoch);


--
-- Name: t5_training_progress_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX t5_training_progress_inserted_at_index ON public.t5_training_progress USING btree (inserted_at);


--
-- Name: t5_training_progress_training_session_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX t5_training_progress_training_session_id_index ON public.t5_training_progress USING btree (training_session_id);


--
-- Name: t5_training_sessions_is_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX t5_training_sessions_is_active_index ON public.t5_training_sessions USING btree (is_active);


--
-- Name: t5_training_sessions_language_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX t5_training_sessions_language_index ON public.t5_training_sessions USING btree (language);


--
-- Name: t5_training_sessions_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX t5_training_sessions_status_index ON public.t5_training_sessions USING btree (status);


--
-- Name: technology_knowledge_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX technology_knowledge_name_index ON public.technology_knowledge USING btree (name);


--
-- Name: technology_knowledge_technology_category_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX technology_knowledge_technology_category_index ON public.technology_knowledge USING btree (technology, category);


--
-- Name: technology_patterns_name_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX technology_patterns_name_type_index ON public.technology_patterns USING btree (technology_name, technology_type);


--
-- Name: technology_patterns_technology_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX technology_patterns_technology_type_index ON public.technology_patterns USING btree (technology_type);


--
-- Name: technology_templates_category_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX technology_templates_category_index ON public.technology_templates USING btree (category);


--
-- Name: technology_templates_identifier_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX technology_templates_identifier_index ON public.technology_templates USING btree (identifier);


--
-- Name: tool_dependencies_dependency_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tool_dependencies_dependency_name_index ON public.tool_dependencies USING btree (dependency_name);


--
-- Name: tool_dependencies_dependency_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tool_dependencies_dependency_type_index ON public.tool_dependencies USING btree (dependency_type);


--
-- Name: tool_dependencies_tool_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tool_dependencies_tool_id_index ON public.tool_dependencies USING btree (tool_id);


--
-- Name: tool_examples_code_embedding_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tool_examples_code_embedding_idx ON public.tool_examples USING ivfflat (code_embedding public.vector_cosine_ops) WITH (lists='100');


--
-- Name: tool_examples_example_order_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tool_examples_example_order_index ON public.tool_examples USING btree (example_order);


--
-- Name: tool_examples_language_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tool_examples_language_index ON public.tool_examples USING btree (language);


--
-- Name: tool_examples_tool_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tool_examples_tool_id_index ON public.tool_examples USING btree (tool_id);


--
-- Name: tool_knowledge_category_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tool_knowledge_category_index ON public.tool_knowledge USING btree (category);


--
-- Name: tool_knowledge_language_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tool_knowledge_language_index ON public.tool_knowledge USING btree (language);


--
-- Name: tool_knowledge_search_vector_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tool_knowledge_search_vector_index ON public.tool_knowledge USING gin (search_vector);


--
-- Name: tool_knowledge_tool_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX tool_knowledge_tool_name_index ON public.tool_knowledge USING btree (tool_name);


--
-- Name: tool_patterns_pattern_embedding_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tool_patterns_pattern_embedding_idx ON public.tool_patterns USING ivfflat (pattern_embedding public.vector_cosine_ops) WITH (lists='100');


--
-- Name: tool_patterns_pattern_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tool_patterns_pattern_type_index ON public.tool_patterns USING btree (pattern_type);


--
-- Name: tool_patterns_tool_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tool_patterns_tool_id_index ON public.tool_patterns USING btree (tool_id);


--
-- Name: tools_download_count_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tools_download_count_index ON public.tools USING btree (download_count);


--
-- Name: tools_ecosystem_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tools_ecosystem_index ON public.tools USING btree (ecosystem);


--
-- Name: tools_github_stars_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tools_github_stars_index ON public.tools USING btree (github_stars);


--
-- Name: tools_last_release_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tools_last_release_date_index ON public.tools USING btree (last_release_date);


--
-- Name: tools_package_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tools_package_name_index ON public.tools USING btree (package_name);


--
-- Name: tools_semantic_embedding_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tools_semantic_embedding_idx ON public.tools USING ivfflat (semantic_embedding public.vector_cosine_ops) WITH (lists='100');


--
-- Name: tools_unique_identifier; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX tools_unique_identifier ON public.tools USING btree (package_name, version, ecosystem);


--
-- Name: vector_search_codebase_id_file_path_content_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX vector_search_codebase_id_file_path_content_type_index ON public.vector_search USING btree (codebase_id, file_path, content_type);


--
-- Name: vector_search_codebase_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX vector_search_codebase_id_index ON public.vector_search USING btree (codebase_id);


--
-- Name: vector_similarity_cache_codebase_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX vector_similarity_cache_codebase_id_index ON public.vector_similarity_cache USING btree (codebase_id);


--
-- Name: vector_similarity_cache_codebase_id_query_vector_hash_target_fi; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX vector_similarity_cache_codebase_id_query_vector_hash_target_fi ON public.vector_similarity_cache USING btree (codebase_id, query_vector_hash, target_file_path);


--
-- Name: vector_similarity_cache_query_vector_hash_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX vector_similarity_cache_query_vector_hash_index ON public.vector_similarity_cache USING btree (query_vector_hash);


--
-- Name: capabilities capabilities_epic_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capabilities
    ADD CONSTRAINT capabilities_epic_id_fkey FOREIGN KEY (epic_id) REFERENCES public.epics(id) ON DELETE SET NULL;


--
-- Name: capability_dependencies capability_dependencies_capability_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capability_dependencies
    ADD CONSTRAINT capability_dependencies_capability_id_fkey FOREIGN KEY (capability_id) REFERENCES public.capabilities(id) ON DELETE CASCADE;


--
-- Name: capability_dependencies capability_dependencies_depends_on_capability_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capability_dependencies
    ADD CONSTRAINT capability_dependencies_depends_on_capability_id_fkey FOREIGN KEY (depends_on_capability_id) REFERENCES public.capabilities(id) ON DELETE CASCADE;


--
-- Name: codebase_chunk_embeddings codebase_chunk_embeddings_chunk_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.codebase_chunk_embeddings
    ADD CONSTRAINT codebase_chunk_embeddings_chunk_id_fkey FOREIGN KEY (chunk_id) REFERENCES public.codebase_chunks(id) ON DELETE CASCADE;


--
-- Name: codebase_chunks codebase_chunks_code_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.codebase_chunks
    ADD CONSTRAINT codebase_chunks_code_file_id_fkey FOREIGN KEY (code_file_id) REFERENCES public.code_files(id) ON DELETE CASCADE;


--
-- Name: epics epics_theme_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.epics
    ADD CONSTRAINT epics_theme_id_fkey FOREIGN KEY (theme_id) REFERENCES public.strategic_themes(id) ON DELETE SET NULL;


--
-- Name: features features_capability_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.features
    ADD CONSTRAINT features_capability_id_fkey FOREIGN KEY (capability_id) REFERENCES public.capabilities(id) ON DELETE SET NULL;


--
-- Name: rag_feedback rag_feedback_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rag_feedback
    ADD CONSTRAINT rag_feedback_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.rag_documents(id) ON DELETE CASCADE;


--
-- Name: rag_feedback rag_feedback_query_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rag_feedback
    ADD CONSTRAINT rag_feedback_query_id_fkey FOREIGN KEY (query_id) REFERENCES public.rag_queries(id) ON DELETE CASCADE;


--
-- Name: rule_evolution_proposals rule_evolution_proposals_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_evolution_proposals
    ADD CONSTRAINT rule_evolution_proposals_rule_id_fkey FOREIGN KEY (rule_id) REFERENCES public.rules(id) ON DELETE CASCADE;


--
-- Name: rule_executions rule_executions_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_executions
    ADD CONSTRAINT rule_executions_rule_id_fkey FOREIGN KEY (rule_id) REFERENCES public.rules(id) ON DELETE CASCADE;


--
-- Name: rules rules_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rules
    ADD CONSTRAINT rules_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.rules(id) ON DELETE SET NULL;


--
-- Name: t5_evaluation_results t5_evaluation_results_model_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.t5_evaluation_results
    ADD CONSTRAINT t5_evaluation_results_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES public.t5_model_versions(id) ON DELETE CASCADE;


--
-- Name: t5_model_versions t5_model_versions_training_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.t5_model_versions
    ADD CONSTRAINT t5_model_versions_training_session_id_fkey FOREIGN KEY (training_session_id) REFERENCES public.t5_training_sessions(id) ON DELETE CASCADE;


--
-- Name: t5_training_examples t5_training_examples_code_chunk_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.t5_training_examples
    ADD CONSTRAINT t5_training_examples_code_chunk_id_fkey FOREIGN KEY (code_chunk_id) REFERENCES public.codebase_chunks(id) ON DELETE SET NULL;


--
-- Name: t5_training_examples t5_training_examples_training_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.t5_training_examples
    ADD CONSTRAINT t5_training_examples_training_session_id_fkey FOREIGN KEY (training_session_id) REFERENCES public.t5_training_sessions(id) ON DELETE CASCADE;


--
-- Name: t5_training_progress t5_training_progress_training_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.t5_training_progress
    ADD CONSTRAINT t5_training_progress_training_session_id_fkey FOREIGN KEY (training_session_id) REFERENCES public.t5_training_sessions(id) ON DELETE CASCADE;


--
-- Name: tool_dependencies tool_dependencies_tool_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tool_dependencies
    ADD CONSTRAINT tool_dependencies_tool_id_fkey FOREIGN KEY (tool_id) REFERENCES public.tools(id) ON DELETE CASCADE;


--
-- Name: tool_examples tool_examples_tool_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tool_examples
    ADD CONSTRAINT tool_examples_tool_id_fkey FOREIGN KEY (tool_id) REFERENCES public.tools(id) ON DELETE CASCADE;


--
-- Name: tool_patterns tool_patterns_tool_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tool_patterns
    ADD CONSTRAINT tool_patterns_tool_id_fkey FOREIGN KEY (tool_id) REFERENCES public.tools(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict MPjHn5f06rJKHFWhyrad9Ebj8dTfcuWJWRc5V2cPTfCQErp2SeSVRVDmSSaX3NC

INSERT INTO public."schema_migrations" (version) VALUES (20240101000001);
INSERT INTO public."schema_migrations" (version) VALUES (20240101000002);
INSERT INTO public."schema_migrations" (version) VALUES (20240101000003);
INSERT INTO public."schema_migrations" (version) VALUES (20240101000004);
INSERT INTO public."schema_migrations" (version) VALUES (20240101000005);
INSERT INTO public."schema_migrations" (version) VALUES (20240101000006);
INSERT INTO public."schema_migrations" (version) VALUES (20240101000007);
INSERT INTO public."schema_migrations" (version) VALUES (20240101000008);
INSERT INTO public."schema_migrations" (version) VALUES (20250101000007);
INSERT INTO public."schema_migrations" (version) VALUES (20250101000008);
INSERT INTO public."schema_migrations" (version) VALUES (20250101000009);
INSERT INTO public."schema_migrations" (version) VALUES (20250101000010);
INSERT INTO public."schema_migrations" (version) VALUES (20250101000011);
INSERT INTO public."schema_migrations" (version) VALUES (20250101000012);
INSERT INTO public."schema_migrations" (version) VALUES (20250101000013);
INSERT INTO public."schema_migrations" (version) VALUES (20250101000014);
