-- Initialize three separate databases for Singularity, CentralCloud, and Genesis
-- This script is automatically executed by PostgreSQL container on first start

-- Create singularity database (Main Application)
CREATE DATABASE singularity
  WITH OWNER postgres
  ENCODING 'UTF8'
  LOCALE 'C'
  TEMPLATE template0;

COMMENT ON DATABASE singularity IS 'Singularity main application database - code analysis, patterns, learning';

-- Create centralcloud database (Knowledge Authority & Aggregation)
CREATE DATABASE centralcloud
  WITH OWNER postgres
  ENCODING 'UTF8'
  LOCALE 'C'
  TEMPLATE template0;

COMMENT ON DATABASE centralcloud IS 'CentralCloud knowledge authority - external facts, aggregated patterns, framework learning';

-- Create genesis database (Isolated Experiment Sandbox)
CREATE DATABASE genesis
  WITH OWNER postgres
  ENCODING 'UTF8'
  LOCALE 'C'
  TEMPLATE template0;

COMMENT ON DATABASE genesis IS 'Genesis sandbox database - isolated experiments, auto-rollback capability';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE singularity TO postgres;
GRANT ALL PRIVILEGES ON DATABASE centralcloud TO postgres;
GRANT ALL PRIVILEGES ON DATABASE genesis TO postgres;
