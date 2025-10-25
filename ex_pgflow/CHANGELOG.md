# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-01-10

### Added

#### Core Features
- Database-driven DAG workflow execution matching pgflow.dev architecture
- PostgreSQL + pgmq extension for reliable task coordination
- Parallel step execution with explicit dependency management (`depends_on:` syntax)
- Map steps for bulk processing with configurable task counts (`initial_tasks: N`)
- Automatic dependency output merging for convergence points
- Multi-instance horizontal scaling with PostgreSQL row-level locking

#### Workflow Definitions
- Static workflows via Elixir modules with `__workflow_steps__/0` callback
- Dynamic workflows via `Pgflow.FlowBuilder` API (perfect for AI/LLM generation)
- Per-step configuration: timeout, max_attempts, initial_tasks
- Automatic cycle detection and dependency validation

#### Execution Engine
- `Pgflow.Executor` for synchronous workflow execution
- `Pgflow.Worker` macro for Oban integration (background jobs)
- pgmq-based task polling with configurable intervals
- Automatic retry with exponential backoff
- Worker registration and heartbeat tracking
- Graceful timeout handling

#### Database Schema
- 11 PostgreSQL functions matching pgflow.dev API
- 5 core tables: workflow_runs, workflow_step_states, workflow_step_tasks, workflow_step_dependencies, workflow_workers
- Dynamic workflow storage: workflows, workflow_steps, workflow_step_dependencies_def
- Complete pgmq integration (v1.4.4+)

#### Documentation
- Comprehensive README with quick start guide
- Dynamic workflows guide for AI/LLM integration
- Feature parity comparison with pgflow.dev
- Security audit documentation
- Timeout configuration guide
- Input validation patterns

#### Quality
- Zero security vulnerabilities (Sobelow scan)
- Zero type errors (Dialyzer with warnings-as-errors)
- Elixir 1.14+ compatibility
- PostgreSQL 12+ compatibility
- Production-ready error handling

### Technical Details

#### pgmq Integration
- Backported `read_with_poll()` function from pgmq 1.5.0
- `ensure_workflow_queue()` for idempotent queue creation
- `set_vt_batch()` for efficient visibility timeout updates
- Automatic message archiving on task completion

#### Execution Flow
1. Parse workflow definition (static module or dynamic from DB)
2. Initialize run with all database records (run, step_states, dependencies, tasks)
3. Call `start_ready_steps()` to mark roots and send to pgmq
4. Poll pgmq for messages
5. Call `start_tasks()` to claim and build task inputs
6. Execute step functions concurrently
7. Call `complete_task()` or `fail_task()` to cascade completion
8. Repeat until workflow completes or fails

#### Performance
- <1ms latency per workflow step (direct function calls)
- Configurable concurrent task execution (default: 10 tasks/batch)
- Zero network overhead (pure Elixir execution)
- Efficient PostgreSQL coordination via counter-based DAG

### Breaking Changes
None (initial release)

### Migration Guide
None (initial release)

### Known Limitations
- Map step output aggregation returns full dependency outputs (not aggregated by task)
- Dynamic workflows require function map at execution time (not stored in DB)
- No workflow versioning (planned for v0.2.0)
- No conditional step execution (planned for v0.2.0)

### Acknowledgments
- pgflow.dev team for the original TypeScript implementation and architecture
- Tembo for the pgmq PostgreSQL extension
- Elixir community for excellent libraries (Ecto, Postgrex, Jason)

[Unreleased]: https://github.com/yourusername/ex_pgflow/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/yourusername/ex_pgflow/releases/tag/v0.1.0
