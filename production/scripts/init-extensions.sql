-- Initialize PostgreSQL extensions for all databases
-- This script is automatically executed by PostgreSQL container on first start

-- Extensions for singularity database
\c singularity
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "timescaledb" WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "postgis" WITH SCHEMA public;

-- Verify extensions
SELECT * FROM pg_extension WHERE extname IN ('uuid-ossp', 'pg_trgm', 'pgcrypto', 'vector', 'timescaledb', 'postgis');

-- Extensions for centralcloud database
\c centralcloud
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA public;

-- Extensions for genesis database
\c genesis
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA public;

-- Switch back to postgres
\c postgres
