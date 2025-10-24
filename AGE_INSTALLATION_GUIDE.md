# Apache AGE Installation Guide for macOS (aarch64)

**Status**: Ready for installation
**Version**: Apache AGE 1.6.0+
**Platform**: aarch64-apple-darwin (M-series Mac)

---

## The Challenge

Apache AGE is not packaged in nixpkgs for ARM64 macOS. This guide provides practical installation options.

---

## Quick Answer: Build from Source (Recommended for macOS)

The simplest and most reliable approach is to build AGE directly from source:

```bash
# 1. Clone AGE repository
git clone https://github.com/apache/age.git
cd age

# 2. Set up PostgreSQL paths
# The build script will find postgres automatically if it's in PATH
export PG_CONFIG=$(which pg_config)
echo $PG_CONFIG  # Should output something like:
# /nix/store/6h5j3j863jmjh4w1dvlr8s42s22zabps-postgresql-and-plugins-16.10/bin/pg_config

# 3. Build AGE
make
# This compiles:
# - age.so (compiled extension module)
# - age--1.6.0.sql (SQL definitions)
# - age.control (metadata)

# 4. Install to PostgreSQL extension directory
make install
# Copies files to:
# - $PGLIB/age.so
# - $PGSHARE/extension/age.control
# - $PGSHARE/extension/age--1.6.0.sql
# - $PGSHARE/extension/age--<old>--1.6.0.sql (migration scripts)

# 5. Create extension in database
psql singularity -c "CREATE EXTENSION IF NOT EXISTS age;"

# 6. Verify installation
psql singularity -c "SELECT extversion FROM pg_extension WHERE extname = 'age';"
# Output: 1.6.0
```

**Time**: ~5 minutes
**Requirements**: PostgreSQL headers (provided by `pg_config`)

---

## Option 2: Download Prebuilt Binary (If Available)

Some releases provide prebuilt macOS binaries:

```bash
# Check available releases
curl -s https://api.github.com/repos/apache/age/releases | jq '.[] | .tag_name'

# Download prebuilt binary (if available for your platform)
cd ~/Downloads
wget https://github.com/apache/age/releases/download/v1.6.0/age-1.6.0-aarch64-apple-darwin.tar.gz
tar xzf age-1.6.0-aarch64-apple-darwin.tar.gz

# Copy to PostgreSQL extension directories
PG_LIB="/nix/store/6h5j3j863jmjh4w1dvlr8s42s22zabps-postgresql-and-plugins-16.10/lib"
PG_SHARE="/nix/store/6h5j3j863jmjh4w1dvlr8s42s22zabps-postgresql-and-plugins-16.10/share/postgresql/extension"

cp age.so $PG_LIB/
cp age.control $PG_SHARE/
cp age--1.6.0.sql $PG_SHARE/

# Create extension
psql singularity -c "CREATE EXTENSION IF NOT EXISTS age;"
```

**Time**: ~2 minutes
**Limitation**: Prebuilt binaries may not be available for all versions

---

## Building from Source: Detailed Steps

### Prerequisites

You need:
1. PostgreSQL 16 running (already have: `/nix/store/.../bin/postgres`)
2. PostgreSQL development files (already have: `pg_config` available)
3. A C compiler (included with Xcode on macOS)

Check you have everything:

```bash
pg_config --pgversion
# Output: PostgreSQL 16.10

pg_config --bindir
# Output: /nix/store/6h5j3j863jmjh4w1dvlr8s42s22zabps-postgresql-and-plugins-16.10/bin

pg_config --libdir
# Output: /nix/store/6h5j3j863jmjh4w1dvlr8s42s22zabps-postgresql-and-plugins-16.10/lib

pg_config --sharedir
# Output: /nix/store/6h5j3j863jmjh4w1dvlr8s42s22zabps-postgresql-and-plugins-16.10/share
```

### Build Steps

```bash
# 1. Clone and enter directory
git clone https://github.com/apache/age.git
cd age
git checkout v1.6.0  # Use stable version

# 2. Build
make
# Compiles the C extension module using your local C compiler

# 3. Install to PostgreSQL directories
make install
# PostgreSQL's makefile automatically installs to the right directories

# 4. Verify files are in place
ls -la $(/nix/store/.../bin/pg_config --libdir)/age.so
ls -la $(/nix/store/.../bin/pg_config --sharedir)/extension/age.*

# 5. Create extension in database
# Start PostgreSQL if not running:
# nix develop
# pg_ctl -D ~/singularity-db start  (or use ./start-all.sh)

psql singularity << EOF
  CREATE EXTENSION IF NOT EXISTS age;
  SELECT extversion FROM pg_extension WHERE extname = 'age';
EOF
```

### Troubleshooting Build

**Error: "pg_config: command not found"**
```bash
# Make sure you're in nix develop shell
nix develop
pg_config --version  # Should work now
```

**Error: "PostgreSQL version not supported"**
```bash
# AGE is built for specific PostgreSQL versions
# Check version compatibility on GitHub
pg_config --pgversion  # Should be 12-17
```

**Error: "make: clang not found"**
```bash
# Install Xcode command line tools
xcode-select --install
```

**Error: libpq not found**
```bash
# libpq should come with PostgreSQL
pg_config --libdir
# Make sure this directory exists and contains libpq.so/libpq.dylib
```

---

## Verifying Installation

Once installed, verify in PostgreSQL:

```bash
# Start PostgreSQL
nix develop  # Ensure in correct environment
psql singularity

-- Check extension exists
SELECT * FROM pg_extension WHERE extname = 'age';
```

Expected output:
```
 extname | extowner | extnamespace | extrelocatable | extversion | extconfig | extcondition
---------+----------+--------------+----------------+------------+-----------+--------------
 age     |       10 |         2200 | f              | 1.6.0      |           |
```

### Test Cypher Queries

```sql
-- Initialize AGE graph
SELECT * FROM ag_catalog.create_graph('code_graph');

-- Check it was created
SELECT * FROM ag_catalog.list_graphs();

-- Simple Cypher query (doesn't need data yet)
SELECT * FROM cypher('code_graph', '
  MATCH (n)
  RETURN n
  LIMIT 1
') AS (node agtype);
```

---

## Integration with Singularity

Once AGE is installed, Elixir automatically uses it:

```elixir
# In iex shell:
Singularity.CodeGraph.AGEQueries.age_available?()
# Returns: true (if AGE installed)
# Returns: false (falls back to ltree)

# Initialize graph (one-time)
Singularity.CodeGraph.AGEQueries.initialize_graph()
# Output: {:ok, %{graph: "code_graph", status: "initialized"}}

# Use Cypher queries
{:ok, modules} = Singularity.CodeGraph.AGEQueries.forward_dependencies("UserService")
# Returns: [%{name: "TokenService", depth: 1}, ...]

# All queries automatically work
Singularity.CodeGraph.AGEQueries.find_cycles()
Singularity.CodeGraph.AGEQueries.code_hotspots()
Singularity.CodeGraph.AGEQueries.test_coverage_gaps()
```

---

## Performance Comparison

After installation, you can compare AGE vs ltree:

```elixir
# Time AGE execution
{time_age, {:ok, results_age}} = :timer.tc(fn ->
  Singularity.CodeGraph.AGEQueries.forward_dependencies("UserService")
end)

# Time ltree fallback
{time_ltree, {:ok, results_ltree}} = :timer.tc(fn ->
  Singularity.CodeGraph.Queries.forward_dependencies(module_id)
end)

IO.puts("AGE: #{time_age}μs")
IO.puts("ltree: #{time_ltree}μs")
IO.puts("Speedup: #{time_ltree / time_age}x")

# Expected: AGE 10-50x faster for 10K+ node graphs
```

---

## If Build Fails

If building from source encounters issues:

1. **Fall back to ltree (already working)**
   ```elixir
   # CodeGraph.Queries module uses ltree + CTEs
   # Automatic fallback is already in place
   # Functions return same results, slightly slower
   Singularity.CodeGraph.Queries.forward_dependencies(module_id)
   ```

2. **Check build logs**
   ```bash
   cd ~/path/to/age
   make clean
   make 2>&1 | tee build.log
   # Check build.log for actual error
   ```

3. **Try older AGE version**
   ```bash
   git checkout v1.5.0  # Try previous stable
   make
   make install
   ```

4. **Use Docker (as last resort)**
   ```bash
   docker run -p 5432:5432 apache/age:latest
   # Connects to containerized PostgreSQL with AGE
   ```

---

## Why Build from Source on macOS?

- ✅ Direct integration with local PostgreSQL
- ✅ No container overhead or version mismatches
- ✅ Fast query execution (local socket, not TCP)
- ✅ Full access to PostgreSQL extensions
- ❌ Requires C compiler (but Xcode already installed)

---

## Next Steps

1. **Install AGE** using build from source (recommended)
2. **Verify** with `psql singularity -c "SELECT extversion FROM pg_extension WHERE extname = 'age';"`
3. **Initialize** graph with `Singularity.CodeGraph.AGEQueries.initialize_graph()`
4. **Load data** from existing call_graph_edges table
5. **Run queries** using `Singularity.CodeGraph.AGEQueries.*` functions
6. **Benchmark** vs ltree to confirm 10-100x speedup

---

## References

- **AGE GitHub**: https://github.com/apache/age
- **AGE Installation**: https://age.apache.org/docs/setup/
- **Cypher Docs**: https://age.apache.org/docs/cypher/
- **PostgreSQL 16**: https://www.postgresql.org/docs/16/

---

**Last Updated**: October 25, 2025
**Status**: Ready for implementation
