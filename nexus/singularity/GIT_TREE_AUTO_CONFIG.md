# Git Tree Auto-Upgrade Configuration Template

This configuration enables git tree coordination to be automatically wired into
the auto-upgrade system. Add to `config/config.exs`:

```elixir
# Git Tree Coordination - Isolated branches for agent work
config :singularity, :git_coordinator,
  enabled: true,
  repo_path: System.get_env("GIT_COORDINATOR_REPO", "~/.singularity/git-coordinator"),
  base_branch: "main",
  remote: "origin"
```

## What This Enables

When `enabled: true`:

1. **Automatic Branch Isolation**
   - Each agent (LLM-powered) gets isolated git branch
   - Agent work doesn't touch main codebase
   - Rule-based agents work directly on main (no conflicts)

2. **PR-Based Tracking**
   - All LLM changes auto-tracked as PRs
   - Full audit trail of who changed what and when
   - Easy review before merging

3. **Epic Coordination**
   - All 6 agents' PRs coordinated together
   - Single merge commit for entire upgrade
   - All-or-nothing consistency

4. **Automatic Management**
   - Git tree created on first startup
   - Branches created/deleted automatically
   - PRs created/merged automatically
   - No manual git commands needed

## Directory Structure

```
~/.singularity/git-coordinator/
├── .git/                    (git repo)
├── .gitignore
└── [agent workspaces]
    ├── agent_self_improving/
    ├── agent_architecture/
    ├── agent_technology/
    ├── agent_refactoring/
    ├── agent_cost_optimized/
    └── agent_chat_conversation/
```

## Environment Variables

Override config via environment:

```bash
# Change git coordinator repo path
export GIT_COORDINATOR_REPO="/home/user/git-work"

# Then start Singularity
iex -S mix
```

## How It Works

### On Startup

1. `Singularity.Application.start/2` starts Git.Supervisor
2. `DocumentationBootstrap.bootstrap_documentation_system()`
   - Calls `GitTreeBootstrap.bootstrap_git_tree_coordination()`
   - Verifies Git.Supervisor running
   - Creates git repo if needed
3. Ready for auto-upgrade with git tracking

### During Auto-Upgrade

1. `DocumentationPipeline.run_full_pipeline()` starts (every 60 min)
2. For each agent:
   - `GitTreeSyncProxy.assign_task(agent_id, task, use_llm: true)`
     - Creates isolated git branch for agent
     - Creates workspace directory
   - Agent processes task in branch
   - `GitTreeSyncProxy.submit_work(agent_id, result)`
     - Creates PR from agent's branch
     - PR ready for merge
3. All PRs collected
4. `GitTreeSyncProxy.merge_all_for_epic(correlation_id)`
   - Merges all PRs into single commit
   - Epic marked complete

### On Completion

- All changes in main codebase
- Full git history preserved
- Easy rollback via `git revert`
- Ready for next 60-minute cycle

## Integration Points

### In DocumentationPipeline

Use `DocumentationPipelineGitIntegration` instead of direct agent calls:

```elixir
# Old (direct):
{:ok, result} = SelfImprovingAgent.process(task)

# New (git-tracked):
{:ok, task_with_git} = GitIntegration.assign_agent_task(:self_improving, task)
{:ok, result} = SelfImprovingAgent.process(task_with_git)
{:ok, pr_info} = GitIntegration.submit_agent_work(:self_improving, result)
```

### With Genesis Sandboxing

Git branches sync with Genesis sandboxes:

1. Agent work in git branch
2. QualityEnforcer validates branch
3. Genesis.SandboxMaintenance mirrors branch
4. Easy rollback: delete branch or revert commit

### With QualityEnforcer

Quality checks run in git branch context:

1. Agent creates changes in branch
2. QualityEnforcer.validate_files() checks branch
3. 2.6.0 standards enforced
4. Only validated changes pass to PR

## Monitoring

Check git tree status:

```bash
# In iex
iex> Singularity.Git.GitTreeSyncProxy.merge_status(correlation_id)
{:ok, %{pending_merges: 3, branches_active: 6, ...}}

# Check git directly
cd ~/.singularity/git-coordinator
git log --oneline
git branch -a
```

## Disabling Git Tree

To disable git coordination (work directly on main):

```elixir
config :singularity, :git_coordinator,
  enabled: false
```

All code still works - just without git branch isolation.
Changes applied directly to main codebase.

## Troubleshooting

### Git repo not initialized

If you see "fatal: not a git repository":

```bash
rm -rf ~/.singularity/git-coordinator
# Restart Singularity - will reinitialize
```

### Merge conflicts

If PRs have conflicts:

1. Manual resolution in git repo
2. `git add` resolved files
3. `git commit` resolution
4. Merge coordinator detects resolution
5. Continues

### Branches not cleaning up

If old branches accumulate:

```bash
cd ~/.singularity/git-coordinator
git branch -D branch_name  # Delete local
git push origin --delete branch_name  # Delete remote
```

## Performance

- **Branch creation**: ~10ms
- **PR creation**: ~50ms
- **Merge all agents**: ~500ms (all 6 merged together)
- **Total overhead**: ~1% of upgrade time

No noticeable impact on auto-upgrade performance.

## Security

- **Isolation**: Each agent's changes in separate branch (no conflicts)
- **Audit**: Full git history of all changes
- **Rollback**: Easy revert to any commit
- **Access**: Controlled via git permissions
