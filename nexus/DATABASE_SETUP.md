# Nexus Database Setup

## Overview

Nexus uses PostgreSQL to store:
- **Approval requests** - Code changes awaiting human approval
- **Approval decisions** - Human responses (approved/rejected)
- **Question requests** - Questions asked by agents
- **Question responses** - Human answers
- **HITL metrics** - Response times and performance data

All tables are automatically created on first connection.

## Database Configuration

**Default database name:** `nexus`

Can be customized via environment variables:
```bash
# PostgreSQL connection
DB_HOST=localhost       # default: localhost
DB_PORT=5432           # default: 5432
DB_USER=postgres       # default: postgres
DB_PASSWORD=           # optional
NEXUS_DB=nexus         # database name (default: nexus)
```

## Creating the Database

### Option 1: Automatic (Recommended)

The database schema is created automatically on first server startup:

```bash
cd nexus
bun run dev
# Server will create 'nexus' database and schema if it doesn't exist
```

### Option 2: Manual Setup

Create the database manually:

```bash
# Create database
createdb -U postgres nexus

# Or with psql
psql -U postgres -c "CREATE DATABASE nexus;"
```

The schema will be initialized on first server connection.

## Database Schema

### approval_requests Table

```sql
CREATE TABLE approval_requests (
  id UUID PRIMARY KEY,                    -- Request ID
  file_path TEXT NOT NULL,                -- File being modified
  diff TEXT NOT NULL,                     -- Code changes (unified diff)
  description TEXT,                       -- Change description
  agent_id TEXT NOT NULL,                 -- Requesting agent (e.g., "self-improving-agent")
  timestamp TIMESTAMP DEFAULT NOW(),      -- When request was made
  approved BOOLEAN,                       -- Null=pending, true=approved, false=rejected
  approved_at TIMESTAMP,                  -- When decision was made
  created_at TIMESTAMP DEFAULT NOW()      -- Record creation time
);

CREATE INDEX idx_approval_requests_agent_id ON approval_requests(agent_id);
CREATE INDEX idx_approval_requests_timestamp ON approval_requests(timestamp);
```

**Example Query:**
```sql
-- Find all approved changes
SELECT * FROM approval_requests WHERE approved = true ORDER BY approved_at DESC;

-- Find pending approvals
SELECT * FROM approval_requests WHERE approved IS NULL ORDER BY timestamp DESC;

-- Stats by agent
SELECT agent_id, COUNT(*) as total, SUM(CASE WHEN approved THEN 1 ELSE 0 END) as approved
FROM approval_requests
GROUP BY agent_id;
```

### question_requests Table

```sql
CREATE TABLE question_requests (
  id UUID PRIMARY KEY,                    -- Request ID
  question TEXT NOT NULL,                 -- The question
  context JSONB,                          -- Additional context (JSON)
  agent_id TEXT NOT NULL,                 -- Asking agent
  timestamp TIMESTAMP DEFAULT NOW(),      -- When question was asked
  response TEXT,                          -- Human's answer
  response_at TIMESTAMP,                  -- When response was provided
  created_at TIMESTAMP DEFAULT NOW()      -- Record creation time
);

CREATE INDEX idx_question_requests_agent_id ON question_requests(agent_id);
CREATE INDEX idx_question_requests_timestamp ON question_requests(timestamp);
```

**Example Query:**
```sql
-- Find all answered questions
SELECT * FROM question_requests WHERE response IS NOT NULL ORDER BY response_at DESC;

-- Find unanswered questions
SELECT * FROM question_requests WHERE response IS NULL ORDER BY timestamp DESC;

-- Questions asked by agent
SELECT question, COUNT(*) FROM question_requests
WHERE agent_id = 'architect-agent'
GROUP BY question;
```

### hitl_metrics Table

```sql
CREATE TABLE hitl_metrics (
  id SERIAL PRIMARY KEY,                  -- Metric ID
  request_type VARCHAR(50) NOT NULL,      -- 'approval' or 'question'
  request_id UUID NOT NULL,               -- Link to approval/question
  response_time_ms INTEGER,               -- Human response time in milliseconds
  user_id TEXT,                           -- Optional: user who responded
  created_at TIMESTAMP DEFAULT NOW()      -- Record creation time
);
```

**Example Query:**
```sql
-- Average response time
SELECT request_type, AVG(response_time_ms) as avg_ms, COUNT(*) as total
FROM hitl_metrics
GROUP BY request_type;

-- Slowest responses
SELECT request_type, response_time_ms, created_at
FROM hitl_metrics
ORDER BY response_time_ms DESC
LIMIT 10;
```

## Environment Variables

In `.env` or shell:

```bash
# PostgreSQL
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=              # Leave empty if no password
NEXUS_DB=nexus

# Nexus Server
PORT=3000
NODE_ENV=development
```

## Database Backup

The Singularity backup worker automatically backs up the `nexus` database:

```bash
# Backup location
.db-backup/hourly/backup_YYYYMMDD_HHMMSS/nexus.sql
.db-backup/daily/backup_YYYYMMDD_HHMMSS/nexus.sql
```

## Querying the Database

### Using psql

```bash
# Connect to nexus database
psql -U postgres -d nexus

# View all approval requests
\d approval_requests
SELECT * FROM approval_requests LIMIT 5;

# View with formatting
\x  -- toggle expanded display
SELECT * FROM approval_requests WHERE id = 'some-uuid';
```

### Using CLI

```bash
# Single query
psql -U postgres -d nexus -c "SELECT COUNT(*) FROM approval_requests;"

# From file
psql -U postgres -d nexus < query.sql
```

## Exporting Data

### CSV Export

```bash
# Export approvals to CSV
psql -U postgres -d nexus -c "COPY approval_requests TO STDOUT WITH CSV HEADER" > approvals.csv

# Export questions to CSV
psql -U postgres -d nexus -c "COPY question_requests TO STDOUT WITH CSV HEADER" > questions.csv
```

### JSON Export

```bash
# Export approvals as JSON
psql -U postgres -d nexus -c "SELECT json_agg(row_to_json(t)) FROM approval_requests t;" > approvals.json
```

## Troubleshooting

### Database doesn't exist

```bash
# Check if database exists
psql -U postgres -l | grep nexus

# Create it manually
createdb -U postgres nexus

# Then restart Nexus server
cd nexus && bun run dev
```

### Connection refused

```bash
# Check if PostgreSQL is running
pg_isready -h localhost -p 5432

# Or start PostgreSQL
brew services start postgresql  # macOS
sudo systemctl start postgresql  # Linux
```

### Permission denied

```bash
# Check user permissions
psql -U postgres -d nexus -c "GRANT ALL ON SCHEMA public TO postgres;"
psql -U postgres -d nexus -c "GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres;"
```

## Monitoring

### Check database size

```bash
psql -U postgres -d nexus -c "SELECT pg_size_pretty(pg_database_size('nexus'));"
```

### Check table sizes

```bash
psql -U postgres -d nexus -c "
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
"
```

### Monitor active connections

```bash
psql -U postgres -d nexus -c "SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;"
```

## Integration with Nexus Server

The `src/db.ts` module automatically:
1. ✅ Connects to PostgreSQL on server startup
2. ✅ Creates schema tables if needed
3. ✅ Logs approval/question requests as they arrive
4. ✅ Records human decisions and responses
5. ✅ Tracks response time metrics
6. ✅ Closes connection gracefully on shutdown

No manual queries needed - the database layer is fully automated!

---

**Next Steps:**
1. Create the `nexus` database (automatic on first server run)
2. Start Nexus server: `bun run dev`
3. Query historical data: `psql -d nexus -c "SELECT * FROM approval_requests LIMIT 5;"`
