# Next Steps for ex_pgflow Testing — Quick Reference

**Last Updated**: 2025-10-27
**Status**: Documentation complete, ready for implementation

---

## Quick Start (Copy-Paste Ready)

### Phase 1: TaskExecutor Tests (Highest Priority)

**File**: `packages/ex_pgflow/test/pgflow/dag/task_executor_test.exs`

**What to do**:
1. Open the file
2. Find lines 75-537 (test assertions)
3. Replace `assert true` with real test implementations
4. Focus on:
   - Task polling from pgmq queue
   - Task claiming with FOR UPDATE locks
   - Step function execution with real I/O
   - Database state verification

**Key patterns to follow**:
```elixir
# Chicago-style testing: verify final state, not intermediate steps
test "successfully executes simple workflow" do
  input = %{"test" => "data"}

  # Execute
  {:ok, result} = Executor.execute(TestTaskExecSimpleWorkflow, input, Repo)

  # Verify output
  assert result["test"] == "data"
  assert result["result"] == "done"

  # Verify database state
  run = Repo.one!(WorkflowRun)
  assert run.status == "completed"
end
```

**Time estimate**: 40-50 hours for all 51 tests

---

### Phase 2: DynamicWorkflowLoader Tests

**File**: `packages/ex_pgflow/test/pgflow/dag/dynamic_workflow_loader_test.exs`

**What to do**:
1. Open the file
2. Find lines 24-100+ (test assertions)
3. Replace placeholder tests with real implementations
4. Test:
   - Creating workflows via FlowBuilder
   - Loading via DynamicWorkflowLoader
   - Verifying definitions match
   - Error cases

**Example pattern**:
```elixir
test "loads workflow configuration" do
  # Create workflow
  {:ok, _} = FlowBuilder.create_flow("test_workflow", Repo)
  {:ok, _} = FlowBuilder.add_step("test_workflow", "step1", [], Repo)

  # Load it
  step_functions = %{step1: fn input -> {:ok, input} end}
  {:ok, definition} = DynamicWorkflowLoader.load("test_workflow", step_functions, Repo)

  # Verify
  assert definition.slug == "test_workflow"
  assert definition.steps[:step1] != nil
end
```

**Time estimate**: 20-30 hours for all 57 tests

---

### Phase 3: PostgreSQL 17 Workaround (When Needed)

**When to apply**: If you see errors like `column reference "workflow_slug" is ambiguous`

**File to modify**: Migration file in `packages/ex_pgflow/priv/repo/migrations/`

**Steps**:
1. Create new migration: `20251027_workaround_pg17_create_flow.exs`
2. Update `create_flow()` function:
   ```sql
   -- Remove WHERE clause
   SELECT w.* FROM workflows w;  -- No WHERE - fixes parser bug
   ```
3. Update `add_step()` function the same way
4. Update `lib/pgflow/flow_builder.ex` to filter results in Elixir
5. Run tests: `mix test test/pgflow/flow_builder_test.exs`

**Reference**: See `POSTGRESQL_17_WORKAROUND_STRATEGY.md`

**Time estimate**: 2-3 hours

---

### Phase 4: Concurrency Tests (Future)

**File**: `packages/ex_pgflow/test/pgflow/concurrency_test.exs` (create new)

**What to test**:
- Multiple workers polling same queue
- Lock contention with FOR UPDATE
- Race condition detection
- pgmq visibility timeout coordination

**Time estimate**: 60-80 hours

---

## Reference Documentation

### For Understanding Current Status
- `EXGPFLOW_TEST_STATUS_OCTOBER_2025.md` — Full status snapshot with exact numbers
- `EXGPFLOW_WORK_SUMMARY.md` — Summary of completed work and remaining tasks

### For PostgreSQL 17 Issue
- `POSTGRESQL_17_WORKAROUND_STRATEGY.md` — Implementation guide for workaround
- `packages/ex_pgflow/POSTGRESQL_BUG_REPORT.md` — Full bug report details
- `packages/ex_pgflow/INVESTIGATION_SUMMARY.md` — Investigation results

### For Test Structure
- `packages/ex_pgflow/TEST_ROADMAP.md` — High-level testing strategy
- `packages/ex_pgflow/TEST_SUMMARY.md` — Test structure overview
- `packages/ex_pgflow/TEST_STRUCTURE_ANALYSIS.md` — Detailed test breakdown

---

## Testing Commands

```bash
# In packages/ex_pgflow directory

# All tests
mix test

# Specific test file
mix test test/pgflow/dag/task_executor_test.exs
mix test test/pgflow/dag/dynamic_workflow_loader_test.exs

# Specific test (by name)
mix test test/pgflow/dag/task_executor_test.exs --only "test polls pgmq queue for task messages"

# With verbose output
mix test --trace

# Skip integration tests (faster)
mix test --exclude integration

# Show which tests run (dry run)
mix test --dry-run
```

---

## Current Test Status (Quick Facts)

| Metric | Value |
|--------|-------|
| Tests passing | 330+ |
| Placeholder tests | 108 |
| PostgreSQL 17 blocked | 74 |
| Total test code | 5,639 lines |
| Overall coverage | ~65% |
| **Target coverage** | **100%** |
| **Est. effort remaining** | **2-3 weeks** |

---

## Key Files to Know

### Implementation Files (to modify)
- `packages/ex_pgflow/lib/pgflow/flow_builder.ex` — API for creating workflows
- `packages/ex_pgflow/lib/pgflow/executor.ex` — Task execution orchestration
- `packages/ex_pgflow/lib/pgflow/dynamic_workflow_loader.ex` — Load workflows from DB

### Test Files (to enhance)
- `test/pgflow/dag/task_executor_test.exs` — 51 tests to implement
- `test/pgflow/dag/dynamic_workflow_loader_test.exs` — 57 tests to implement
- `test/pgflow/dag/workflow_definition_test.exs` — Reference (already complete)
- `test/pgflow/dag/run_initializer_test.exs` — Reference (already complete)

### Database/SQL Files
- `priv/repo/migrations/` — SQL functions and schema (28 migrations)
- Key functions: `create_flow()`, `add_step()`, `start_tasks()`, `complete_task()`, `fail_task()`

---

## Success Metrics

You'll know you're done when:
- ✅ All 51 TaskExecutor assertions are real tests
- ✅ All 57 DynamicWorkflowLoader assertions are real tests
- ✅ No more `assert true` placeholder assertions
- ✅ All 394+ tests passing
- ✅ Concurrency tests implemented and passing
- ✅ `mix test` shows green across the board

---

## Tips for Success

1. **Start with TaskExecutor** — Highest impact, good reference point for patterns
2. **Use existing tests as templates** — `workflow_definition_test.exs` and `run_initializer_test.exs` show the pattern
3. **Verify database state** — Chicago-style TDD: focus on final state, not intermediate steps
4. **Work in small increments** — Implement 5-10 tests, run, commit, repeat
5. **Keep PostgreSQL 17 workaround in mind** — If you hit ambiguous column errors, apply workaround

---

## Common Issues & Solutions

### Issue: "mix test" hangs or times out
**Solution**: You're likely in the Executor polling loop. Test components individually instead.

### Issue: "column reference is ambiguous" error in flow_builder_test.exs
**Solution**: Apply PostgreSQL 17 workaround (see Phase 3 above).

### Issue: "Failed to complete task" in test output
**Solution**: Already fixed (migration 20251025210500). Ensure database is migrated.

### Issue: Cannot connect to database
**Solution**: Ensure PostgreSQL is running and database exists: `mix ecto.create`

---

## Next Session Checklist

- [ ] Read `EXGPFLOW_WORK_SUMMARY.md` for full context
- [ ] Read `EXGPFLOW_TEST_STATUS_OCTOBER_2025.md` for current numbers
- [ ] Open `test/pgflow/dag/task_executor_test.exs`
- [ ] Start implementing TaskExecutor tests (begin with lines 75-115)
- [ ] After first 5 tests, run `mix test` to verify approach
- [ ] Continue with remaining tests
- [ ] Move to DynamicWorkflowLoader tests once TaskExecutor is ~90% complete
- [ ] Apply PostgreSQL 17 workaround if/when needed
- [ ] Commit progress regularly

---

## Questions?

Refer to:
1. **Status**: `EXGPFLOW_TEST_STATUS_OCTOBER_2025.md`
2. **How to proceed**: This file (you're reading it!)
3. **PostgreSQL 17 issue**: `POSTGRESQL_17_WORKAROUND_STRATEGY.md`
4. **Test patterns**: Look at `test/pgflow/dag/workflow_definition_test.exs` (complete example)
5. **Previous work**: `EXGPFLOW_WORK_SUMMARY.md`

---

**You've got this! 🚀**

The foundation is solid, the patterns are clear, and the next steps are well-documented.

Estimated path to 100% test coverage: **2-3 weeks of focused work**.

