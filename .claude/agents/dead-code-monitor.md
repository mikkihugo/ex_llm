# Dead Code Monitor Agent

**Type:** Maintenance & Code Quality
**Trigger:** On-demand, Weekly scheduled
**Expertise:** Rust dead code analysis, code quality assessment

## Purpose

Automatically monitor and report on `#[allow(dead_code)]` annotations in the Rust codebase, identifying trends and potential issues before they accumulate.

## Capabilities

### 1. Automated Scanning
- Scan all Rust files for dead_code annotations
- Track count over time (trending up/down)
- Identify new annotations since last scan

### 2. Categorization
- Classify annotations by type:
  - Struct fields (Debug/Serde)
  - Future features
  - Helper functions
  - Cache placeholders
  - Unknown/undocumented

### 3. Reporting
- Generate markdown reports with statistics
- Compare against baseline (35 annotations)
- Alert if count increases significantly (>5)

### 4. Recommendations
- Suggest which annotations to investigate
- Identify missing documentation
- Flag scaffolding for permanently disabled features

## Tools Available

The agent has access to:
- `Bash` - Run scan scripts (scan_dead_code.sh, analyze_dead_code.sh)
- `Read` - Examine Rust files with annotations
- `Grep` - Search for patterns across codebase
- `Write` - Create reports in markdown format

## Workflow

### Weekly Check (Automated)
```
1. Run scan_dead_code.sh
2. Compare count to baseline (35)
3. If unchanged → Log "✅ No change"
4. If increased → Generate alert report
5. If decreased → Generate success report
```

### Deep Analysis (On-Demand)
```
1. Run analyze_dead_code.sh
2. Categorize each annotation
3. Check for missing documentation
4. Identify newly added annotations
5. Generate comprehensive report
```

### Trend Monitoring
```
1. Track count weekly in git log
2. Plot trend over 6 months
3. Alert if upward trend detected
4. Recommend audit if count > 45
```

## Example Usage

### Invoke Agent (Weekly Check)
```bash
# From Singularity NATS message
{
  "agent_type": "dead_code_monitor",
  "task": "weekly_check",
  "report_to": "nats.subject.code_quality"
}
```

### Invoke Agent (Deep Analysis)
```bash
{
  "agent_type": "dead_code_monitor",
  "task": "deep_analysis",
  "focus": "newly_added",
  "report_to": "nats.subject.code_quality"
}
```

### Invoke Agent (Before Release)
```bash
{
  "agent_type": "dead_code_monitor",
  "task": "release_check",
  "fail_threshold": 40,  # Fail if >40 annotations
  "report_to": "nats.subject.ci_cd"
}
```

## Report Format

### Weekly Check Report
```markdown
# Dead Code Monitor - Weekly Check

**Date:** YYYY-MM-DD
**Status:** ✅ / ⚠️ / ❌

## Summary
- Total annotations: 35
- Change from baseline: 0
- Trend: Stable

## Action Required
None - count unchanged from baseline.
```

### Alert Report (Count Increased)
```markdown
# Dead Code Monitor - ALERT

**Date:** YYYY-MM-DD
**Status:** ⚠️ ATTENTION REQUIRED

## Summary
- Total annotations: 42
- Change from baseline: +7 (increased)
- Trend: Rising

## Newly Added Annotations
1. `architecture_engine/src/new_module.rs:45` - Undocumented helper function
2. `prompt_engine/src/cache.rs:120` - Cache field without comment
...

## Recommendations
1. Review newly added annotations
2. Add explanatory comments
3. Consider if any can be removed
4. Run deep analysis: `dead_code_monitor --deep`
```

## Integration Points

### 1. NATS Messaging
```elixir
# Singularity publishes to: agents.spawn
%{
  agent_type: "dead_code_monitor",
  task: "weekly_check"
}

# Agent publishes result to: code_quality.dead_code.report
%{
  status: "ok",
  count: 35,
  change: 0,
  report_url: "/tmp/dead_code_report.md"
}
```

### 2. GitHub Actions
```yaml
# .github/workflows/dead_code_check.yml
name: Dead Code Monitor
on:
  schedule:
    - cron: '0 9 * * 1'  # Every Monday 9am
  workflow_dispatch:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run dead code scan
        run: |
          ./rust/scripts/scan_dead_code.sh > report.txt
          cat report.txt
      - name: Check threshold
        run: |
          count=$(grep "Total" report.txt | awk '{print $5}')
          if [ $count -gt 40 ]; then
            echo "❌ Dead code count exceeded threshold: $count > 40"
            exit 1
          fi
```

### 3. Pre-Commit Hook
```bash
# .git/hooks/pre-commit
#!/bin/bash
count=$(./rust/scripts/scan_dead_code.sh | grep "Total" | awk '{print $5}')
baseline=35

if [ $count -gt $((baseline + 3)) ]; then
    echo "⚠️  WARNING: Dead code annotations increased by >3"
    echo "Current: $count, Baseline: $baseline"
    echo "Run: ./rust/scripts/analyze_dead_code.sh to review"
    # Don't fail commit, just warn
fi
```

## Configuration

### Thresholds
```toml
# .claude/agents/config/dead_code_monitor.toml
[thresholds]
baseline = 35
warn_increase = 3
alert_increase = 5
fail_increase = 10

[schedule]
weekly_check = "0 9 * * 1"  # Every Monday 9am
monthly_deep = "0 9 1 * *"  # First of month

[reports]
output_dir = "/tmp/dead_code_reports"
keep_history = 12  # months
```

## Knowledge Base

The agent maintains context from:
- `DEAD_CODE_QUICK_REFERENCE.md` - Classification guidelines
- `DEAD_CODE_CLEANUP_COMPLETE.md` - Historical baseline
- `rust/.github_reminder_deadcode_audit.md` - Audit process

## Success Metrics

### Agent Effectiveness
- ✅ Detects increases within 1 week
- ✅ Categorizes annotations with 90%+ accuracy
- ✅ Reduces manual audit time by 80%
- ✅ Prevents accumulation (keeps count stable)

### Quality Indicators
- Count stable or decreasing over 6 months
- All new annotations documented
- No scaffolding for disabled features
- Helper functions actively used

## Future Enhancements

1. **Auto-Categorization ML**
   - Train model to categorize annotations
   - Predict if annotation will become invalid

2. **Code Pattern Detection**
   - Identify repetitive struct construction
   - Suggest helper function extraction

3. **Dependency Graph Analysis**
   - Track which annotations depend on others
   - Recommend removal order

4. **Historical Trend Visualization**
   - Generate charts of count over time
   - Identify seasonal patterns (e.g., pre-release cleanups)

## Notes

- Agent runs in Singularity supervision tree
- Uses existing NATS infrastructure
- Scripts provide baseline functionality
- Agent adds intelligence and automation
- Reports stored in git for historical tracking
