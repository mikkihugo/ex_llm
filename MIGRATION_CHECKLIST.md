# Schema Alignment Migration - Deployment Checklist

Use this checklist when deploying migration `20250101000014_align_schema_table_names.exs`

---

## Pre-Migration Checklist

### Planning & Preparation
- [ ] Read `SCHEMA_MIGRATION_REPORT.md` for full context
- [ ] Read `QUICK_REFERENCE.md` for overview
- [ ] Understand what tables are being renamed/split
- [ ] Identify affected systems (detection, git, templates)
- [ ] Schedule maintenance window (5-10 minutes recommended)
- [ ] Notify team of planned migration

### Environment Preparation
- [ ] Verify database exists: `psql -l | grep singularity`
- [ ] Check disk space: `df -h` (ensure enough space for backup)
- [ ] Stop application services: `./stop-all.sh`
- [ ] Verify no active connections: `psql singularity_dev -c "SELECT count(*) FROM pg_stat_activity WHERE datname = 'singularity_dev'"`

### Backup & Safety
- [ ] **CRITICAL:** Create database backup
  ```bash
  pg_dump singularity_dev > backup_$(date +%Y%m%d_%H%M%S).sql
  ```
- [ ] Verify backup file created and non-zero size: `ls -lh backup_*.sql`
- [ ] Test backup is valid: `pg_restore --list backup_*.sql > /dev/null && echo "Backup OK"`
- [ ] Store backup in safe location (copy to external storage)
- [ ] Document backup location: `echo "Backup at: $(pwd)/backup_*.sql" >> migration_log.txt`

### Pre-Migration State Recording
- [ ] Record current table names:
  ```bash
  psql singularity_dev -c "\dt" | grep -E "(detection_events|git_sessions|technology_knowledge)" > pre_migration_tables.txt
  ```
- [ ] Record row counts (IMPORTANT for verification):
  ```bash
  psql singularity_dev -c "
    SELECT 'detection_events' AS table_name, COUNT(*) FROM detection_events
    UNION ALL
    SELECT 'git_sessions', COUNT(*) FROM git_sessions
    UNION ALL
    SELECT 'technology_knowledge', COUNT(*) FROM technology_knowledge;
  " > pre_migration_counts.txt
  ```
- [ ] Record migration status:
  ```bash
  cd singularity_app && mix ecto.migrations > pre_migration_status.txt
  ```
- [ ] Check for any pending migrations: `mix ecto.migrations | grep "down"`

---

## Migration Execution Checklist

### Run Migration
- [ ] Navigate to app directory: `cd singularity_app`
- [ ] Verify Elixir environment: `mix --version`
- [ ] Run migration:
  ```bash
  mix ecto.migrate
  ```
- [ ] **WATCH OUTPUT CAREFULLY** for errors or warnings
- [ ] Record start time: `date >> migration_log.txt`
- [ ] Migration completes successfully (no errors)
- [ ] Record end time: `date >> migration_log.txt`

### Expected Output
Look for these messages (all should appear):
- [ ] "Renamed detection_events to codebase_snapshots"
- [ ] "Renamed git_sessions to git_agent_sessions"
- [ ] "Created git_pending_merges table"
- [ ] "Created git_merge_history table"
- [ ] "Created and populated technology_templates table"
- [ ] "Created and populated technology_patterns table"
- [ ] "Dropped technology_knowledge table after successful migration"
- [ ] "== Migrated in X.Xs" (completion message)

### Error Handling During Migration
If migration fails:
- [ ] **DO NOT PANIC** - Database backup exists
- [ ] Note exact error message
- [ ] Check `ROLLBACK_PROCEDURE.md` for guidance
- [ ] Consider rollback: `mix ecto.rollback --step 1`
- [ ] Restore from backup if needed: See "Emergency Rollback" section below

---

## Post-Migration Verification Checklist

### Table Existence Verification
- [ ] Verify new tables exist:
  ```bash
  psql singularity_dev -c "\dt" | grep -E "(codebase_snapshots|git_agent_sessions|git_pending_merges|git_merge_history|technology_templates|technology_patterns)"
  ```
  **Expected:** All 6 tables should appear

- [ ] Verify old tables removed:
  ```bash
  psql singularity_dev -c "\dt" | grep -E "(detection_events|git_sessions|^technology_knowledge$)" || echo "Old tables correctly removed"
  ```
  **Expected:** "Old tables correctly removed" message

### Data Integrity Verification
- [ ] Compare row counts (should match pre-migration counts):
  ```bash
  psql singularity_dev -c "
    SELECT 'codebase_snapshots' AS table_name, COUNT(*) FROM codebase_snapshots
    UNION ALL
    SELECT 'git_agent_sessions', COUNT(*) FROM git_agent_sessions
    UNION ALL
    SELECT 'technology_templates', COUNT(*) FROM technology_templates
    UNION ALL
    SELECT 'technology_patterns', COUNT(*) FROM technology_patterns;
  " > post_migration_counts.txt
  ```
- [ ] **CRITICAL:** Verify counts match pre-migration (compare files)
  ```bash
  diff pre_migration_counts.txt post_migration_counts.txt || echo "Row counts differ - investigate!"
  ```

### Index Verification
- [ ] Check indexes created for codebase_snapshots:
  ```bash
  psql singularity_dev -c "\di codebase_snapshots*"
  ```
  **Expected:**
  - `codebase_snapshots_codebase_id_index`
  - `codebase_snapshots_codebase_id_snapshot_id_index` (unique)
  - `codebase_snapshots_inserted_at_index`

- [ ] Check indexes created for git_agent_sessions:
  ```bash
  psql singularity_dev -c "\di git_agent_sessions*"
  ```
  **Expected:**
  - `git_agent_sessions_agent_id_index` (unique)
  - `git_agent_sessions_status_index`
  - `git_agent_sessions_correlation_id_index`

- [ ] Check indexes for git_pending_merges:
  ```bash
  psql singularity_dev -c "\di git_pending_merges*"
  ```
  **Expected:**
  - `git_pending_merges_branch_index` (unique)
  - `git_pending_merges_agent_id_index`

- [ ] Check indexes for git_merge_history:
  ```bash
  psql singularity_dev -c "\di git_merge_history*"
  ```
  **Expected:**
  - `git_merge_history_branch_index`
  - `git_merge_history_status_index`
  - `git_merge_history_inserted_at_index`

- [ ] Check indexes for technology tables:
  ```bash
  psql singularity_dev -c "\di technology_*"
  ```
  **Expected:**
  - `technology_templates_category_index`
  - `technology_templates_identifier_index` (unique)
  - `technology_patterns_name_type_index` (unique)
  - `technology_patterns_technology_type_index`

### Schema Structure Verification
- [ ] Check codebase_snapshots schema:
  ```bash
  psql singularity_dev -c "\d codebase_snapshots"
  ```
  **Expected fields:** id, codebase_id, snapshot_id, summary, detected_technologies, features, metadata, inserted_at, updated_at

- [ ] Check git_agent_sessions schema:
  ```bash
  psql singularity_dev -c "\d git_agent_sessions"
  ```
  **Expected fields:** id, agent_id, branch, workspace_path, correlation_id, status, meta, inserted_at, updated_at

- [ ] Check technology_templates schema:
  ```bash
  psql singularity_dev -c "\d technology_templates"
  ```
  **Expected fields:** id, identifier, category, version, source, template, metadata, checksum, inserted_at, updated_at

- [ ] Check technology_patterns schema:
  ```bash
  psql singularity_dev -c "\d technology_patterns"
  ```
  **Expected fields:** id, technology_name, technology_type, version_pattern, file_patterns, directory_patterns, config_files, build_command, dev_command, install_command, test_command, output_directory, confidence_weight, detection_count, success_rate, last_detected_at, extended_metadata, created_at, updated_at

### Migration Status Verification
- [ ] Check migration recorded:
  ```bash
  cd singularity_app && mix ecto.migrations | grep "20250101000014"
  ```
  **Expected:** Migration shows as "up"

---

## Application Testing Checklist

### Application Startup
- [ ] Start application services: `./start-all.sh`
- [ ] Application starts without errors
- [ ] Check startup logs: `tail -f singularity_app/log/dev.log`
- [ ] **CRITICAL:** No Ecto schema errors in logs
- [ ] **CRITICAL:** No "table does not exist" errors
- [ ] **CRITICAL:** No "column does not exist" errors

### Compilation & Type Checking
- [ ] Code compiles: `cd singularity_app && mix compile`
- [ ] No compilation warnings about schemas
- [ ] Dialyzer passes (optional): `mix dialyzer`

### Test Suite
- [ ] Run full test suite: `mix test`
- [ ] All tests pass (or same failures as before migration)
- [ ] No new Ecto-related test failures
- [ ] Check test output for deprecation warnings

### Feature Testing

#### Technology Detection
- [ ] Technology detection module loads:
  ```bash
  iex -S mix
  iex> Singularity.CodebaseSnapshots.__info__(:functions)
  ```
- [ ] Test upsert function works:
  ```elixir
  # In iex:
  Singularity.CodebaseSnapshots.upsert(%{
    codebase_id: "test",
    snapshot_id: 1,
    detected_technologies: ["elixir", "gleam"]
  })
  ```
- [ ] No errors returned

#### Git Coordination
- [ ] Git state store module loads:
  ```bash
  iex -S mix
  iex> Singularity.Git.GitStateStore.__info__(:functions)
  ```
- [ ] Test session upsert:
  ```elixir
  # In iex:
  Singularity.Git.GitStateStore.upsert_session(%{
    agent_id: "test_agent",
    workspace_path: "/tmp/test",
    status: "active"
  })
  ```
- [ ] No errors returned

#### Technology Templates
- [ ] Template store module loads:
  ```bash
  iex -S mix
  iex> Singularity.TechnologyTemplateStore.__info__(:functions)
  ```
- [ ] Test template operations:
  ```elixir
  # In iex:
  Singularity.TechnologyTemplateStore.upsert(:test_template, %{
    "category" => "test",
    "name" => "Test Template"
  })
  ```
- [ ] No errors returned

### Performance Testing
- [ ] Check query performance (should be same or better):
  ```sql
  EXPLAIN ANALYZE SELECT * FROM codebase_snapshots WHERE codebase_id = 'test';
  EXPLAIN ANALYZE SELECT * FROM git_agent_sessions WHERE agent_id = 'test_agent';
  EXPLAIN ANALYZE SELECT * FROM technology_templates WHERE identifier = 'test';
  ```
- [ ] No significant performance degradation (< 10% slower acceptable)
- [ ] Indexes being used (check EXPLAIN output)

---

## Production Deployment (if applicable)

### Additional Production Checks
- [ ] Test on staging environment first
- [ ] Full staging test suite passes
- [ ] Performance tests on staging acceptable
- [ ] Rollback tested on staging
- [ ] Production backup completed
- [ ] Maintenance window announced
- [ ] Rollback plan documented and ready
- [ ] Team on standby during deployment

### Production Deployment
- [ ] Stop production services
- [ ] Run migration on production
- [ ] Verify all post-migration checks pass
- [ ] Start production services
- [ ] Monitor error rates for 1 hour
- [ ] Check application metrics
- [ ] Verify affected features working in production
- [ ] Monitor database performance
- [ ] Team confirms system stable

---

## Rollback Checklist (if needed)

### When to Rollback
Rollback immediately if:
- [ ] Migration fails with errors
- [ ] Row counts don't match (data loss)
- [ ] Application won't start after migration
- [ ] Critical Ecto schema errors in logs
- [ ] Test suite has new failures
- [ ] Performance degradation > 50%
- [ ] Core features broken

### Rollback Execution
- [ ] Stop application: `./stop-all.sh`
- [ ] Run rollback: `cd singularity_app && mix ecto.rollback --step 1`
- [ ] Verify old tables restored:
  ```bash
  psql singularity_dev -c "\dt" | grep -E "(detection_events|git_sessions|technology_knowledge)"
  ```
- [ ] Verify row counts match original
- [ ] Start application: `./start-all.sh`
- [ ] Application starts successfully
- [ ] Test suite passes
- [ ] Document rollback reason

### Emergency Rollback (if mix rollback fails)
- [ ] Stop all services
- [ ] Restore from backup:
  ```bash
  dropdb singularity_dev
  createdb singularity_dev
  psql singularity_dev < backup_YYYYMMDD_HHMMSS.sql
  ```
- [ ] Verify database restored
- [ ] Start services
- [ ] Verify system working
- [ ] Document what happened

See `ROLLBACK_PROCEDURE.md` for detailed manual rollback steps.

---

## Post-Deployment Checklist

### Documentation
- [ ] Update changelog with migration notes
- [ ] Document any issues encountered
- [ ] Update schema documentation if needed
- [ ] Note migration success in project log

### Cleanup
- [ ] Archive backup after 7 days of stability
- [ ] Remove pre/post migration count files
- [ ] Update any external tools/scripts
- [ ] Close related GitHub issues/tickets

### Monitoring (24-48 hours)
- [ ] Monitor application error rates
- [ ] Monitor database performance metrics
- [ ] Check disk space usage
- [ ] Verify no schema-related errors in logs
- [ ] Monitor affected feature usage

### Team Communication
- [ ] Notify team of successful migration
- [ ] Share migration report
- [ ] Document lessons learned
- [ ] Update team wiki/docs

---

## Troubleshooting

### Common Issues & Solutions

#### "table already exists"
- **Cause:** Migration already partially ran
- **Solution:** Migration is idempotent, safe to re-run
- [ ] Check which tables exist: `psql singularity_dev -c "\dt"`
- [ ] Determine migration state
- [ ] Re-run migration or clean up manually

#### "column does not exist"
- **Cause:** Schema expects new column but migration incomplete
- **Solution:** Complete migration or rollback
- [ ] Check table schema: `psql singularity_dev -c "\d table_name"`
- [ ] Complete migration: `mix ecto.migrate`
- [ ] Or rollback: `mix ecto.rollback --step 1`

#### "relation does not exist"
- **Cause:** Code expects new table but migration not run
- **Solution:** Run migration
- [ ] Verify migration status: `mix ecto.migrations`
- [ ] Run pending migrations: `mix ecto.migrate`

#### Application won't start
- **Cause:** Schema/table mismatch after failed migration
- **Solution:** Check logs and fix or rollback
- [ ] Check application logs for specific error
- [ ] Verify database state matches migration state
- [ ] Rollback if needed: `mix ecto.rollback --step 1`
- [ ] Or restore from backup

#### Tests failing
- **Cause:** Test database not migrated
- **Solution:** Migrate test database
- [ ] Run: `MIX_ENV=test mix ecto.migrate`
- [ ] Re-run tests: `mix test`

---

## Sign-Off

### Pre-Migration Sign-Off
- [ ] **Backup completed and verified**
- [ ] Pre-migration state recorded
- [ ] Team notified
- [ ] Ready to proceed

Signed: _________________ Date: _________

### Post-Migration Sign-Off
- [ ] **Migration successful**
- [ ] All verification checks passed
- [ ] Application running correctly
- [ ] Monitoring in place

Signed: _________________ Date: _________

### Production Sign-Off (if applicable)
- [ ] **Production migration successful**
- [ ] All production checks passed
- [ ] 24-hour stability confirmed
- [ ] Backup can be archived

Signed: _________________ Date: _________

---

## Emergency Contacts

**Database Issues:**
- Check: `ROLLBACK_PROCEDURE.md`
- Restore: Use backup created pre-migration

**Application Issues:**
- Check: Application logs in `singularity_app/log/`
- Reference: `SCHEMA_ALIGNMENT_SUMMARY.md`

**Migration Issues:**
- Reference: `SCHEMA_MIGRATION_REPORT.md`
- Quick help: `QUICK_REFERENCE.md`

---

**Checklist Version:** 1.0
**Migration:** 20250101000014
**Created:** 2025-10-05
**Last Updated:** 2025-10-05
