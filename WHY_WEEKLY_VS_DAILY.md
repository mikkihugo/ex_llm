# Why Weekly vs Daily Dead Code Checks?

## Your Question

> "why so seldom?"

Great question! **Weekly might be too seldom.** Let me explain the tradeoffs:

---

## Frequency Options

| Frequency | Pros | Cons | Best For |
|-----------|------|------|----------|
| **Every Commit** | Immediate feedback | Noisy, slows CI | Critical metrics |
| **Daily** | Catches issues quickly | May alert on WIP | Active development |
| **Weekly** | Less noise, stable trends | Slow to detect issues | Maintenance mode |
| **Monthly** | Minimal overhead | Issues accumulate | Legacy projects |

---

## Current: Weekly (Monday 9am)

**Why I chose weekly:**
- Assumption: Internal tooling in maintenance mode
- Lower noise (developers not interrupted daily)
- Stable baseline (35 annotations)

**But you're right - this might be too slow!**

---

## Recommended: Daily with Smart Alerting

### Better Approach

```
Daily scans → Database → Alert ONLY on significant changes
```

**Schedule:**
- **Scan:** Every day at 9am (7 days/week)
- **Alert:** Only if count increases by 3+ from previous day
- **Report:** Weekly summary (Monday) even if no changes

**Benefits:**
- ✅ Catches new annotations within 24 hours
- ✅ Doesn't spam (only alerts on significant changes)
- ✅ Historical data for trend analysis
- ✅ Weekly summaries for stakeholders

---

## Even Better: Every Commit (Pre-commit Hook)

### Instant Feedback

```bash
# .git/hooks/pre-commit
#!/bin/bash
current=$(./rust/scripts/scan_dead_code.sh | grep "Total" | awk '{print $5}')
baseline=35

if [ $current -gt $((baseline + 2)) ]; then
    echo "⚠️  WARNING: Dead code increased to $current (+$((current - baseline)))"
    echo ""
    echo "New annotations detected. Please:"
    echo "1. Add explanatory comments to #[allow(dead_code)]"
    echo "2. Consider if any can be removed"
    echo ""
    echo "Run: ./rust/scripts/analyze_dead_code.sh to review"
    echo ""
    # Don't block commit, just warn
fi
```

**Benefits:**
- ✅ Immediate feedback (catches at commit time)
- ✅ Developer sees warning before push
- ✅ Doesn't block (just warns)
- ✅ No CI/CD overhead

---

## Comparison: Weekly vs Daily vs Commit

### Scenario: Developer adds 5 annotations on Tuesday

**Weekly (Current):**
```
Tuesday: Developer adds 5 annotations
Wednesday-Sunday: No detection
Monday 9am: Alert fires "Count increased from 35 → 40"
Developer: "What?! When did I add those?"
Time to fix: 6+ days
```

**Daily (Recommended):**
```
Tuesday: Developer adds 5 annotations
Wednesday 9am: Alert fires "Count increased from 35 → 40"
Developer: "Oh yeah, I added those yesterday"
Time to fix: 1 day
```

**Pre-commit (Best):**
```
Tuesday: Developer commits with 5 new annotations
Git hook: "⚠️ Dead code increased to 40 (+5)"
Developer: "Let me add comments now before I forget"
Time to fix: Immediate
```

---

## Updated Recommendation

### 1. Pre-commit Hook (Immediate)
```bash
# Catches at commit time
# Warns but doesn't block
# Developer context is fresh
```

### 2. Daily Scan + Database (Trend Analysis)
```elixir
# Runs at 9am daily
# Stores in database
# Alerts only on significant change (3+)
```

### 3. Weekly Report (Summary)
```elixir
# Every Monday
# Summary of week's changes
# Trend analysis (increasing/decreasing)
```

---

## Why Database is Critical

### Without Database (Current)

**Agent runs weekly:**
- Count: 35 (ok)
- Next week: 37 (+2, warn)
- Next week: 35 (-2, ok)

**You can't see:**
- When did it change? (no history)
- What's the trend? (no data points)
- Is this normal fluctuation? (no baseline)

### With Database (New)

**Agent runs daily, stores results:**
```
2025-01-23: 35 (ok)
2025-01-24: 35 (ok) - no alert
2025-01-25: 38 (+3) - ALERT
2025-01-26: 38 (0) - no alert
2025-01-27: 35 (-3) - good news!
```

**Now you can:**
- ✅ See exact date of change
- ✅ Calculate trends (increasing 0.5/week)
- ✅ Detect patterns (always increases before releases?)
- ✅ Generate charts (visualize over 6 months)

---

## Database Schema Benefits

```sql
-- Query: When did count first exceed 40?
SELECT check_date, total_count 
FROM dead_code_history 
WHERE total_count > 40 
ORDER BY check_date ASC 
LIMIT 1;

-- Query: What's the average count per month?
SELECT DATE_TRUNC('month', check_date) as month,
       AVG(total_count) as avg_count
FROM dead_code_history
GROUP BY month
ORDER BY month;

-- Query: Trending up or down?
SELECT trend_slope(days => 30);  -- +0.14 = increasing
```

---

## Updated Implementation

### Config Changes

```elixir
# config/config.exs
config :singularity, Singularity.Agents.DeadCodeMonitor,
  # Scan frequency
  schedule: "0 9 * * *",  # Daily at 9am (was: 0 9 * * 1 for weekly)
  
  # Alert thresholds
  alert_on_increase: 3,    # Alert if count increases by 3+
  warn_on_increase: 2,     # Warn if count increases by 2+
  
  # Weekly summary
  weekly_report_day: 1,    # Monday (1-7)
  
  # Database storage
  store_history: true,     # Enable database tracking
  retention_days: 365      # Keep 1 year of history
```

### Cron Schedule Syntax

```
┌───────────── minute (0 - 59)
│ ┌───────────── hour (0 - 23)
│ │ ┌───────────── day of month (1 - 31)
│ │ │ ┌───────────── month (1 - 12)
│ │ │ │ ┌───────────── day of week (0 - 6) (Sunday=0)
│ │ │ │ │
* * * * *

Examples:
"0 9 * * *"   - Daily at 9am
"0 9 * * 1"   - Weekly Monday 9am
"*/15 * * * *" - Every 15 minutes
"0 */6 * * *" - Every 6 hours
```

---

## My Recommendation for Singularity

### Tier 1: Pre-commit Hook (Immediate)
- Instant feedback at commit time
- Developer context is fresh
- Non-blocking (just warns)

### Tier 2: Daily Scan (Detection)
- Runs at 9am daily
- Stores in database
- Alerts ONLY if increase ≥ 3

### Tier 3: Weekly Report (Summary)
- Every Monday
- Includes trend analysis
- Even if no changes (shows stability)

### Result

```
Developer commits
    ↓ (immediate)
Pre-commit hook warns
    ↓ (next day)
Daily scan stores result
    ↓ (if increase ≥ 3)
Alert sent to Slack/NATS
    ↓ (every Monday)
Weekly summary report
```

**This catches issues in 1 day instead of 7 days!**

---

## Statistics

### Weekly Scan
- **Detection time:** 0-7 days (average: 3.5 days)
- **Developer recall:** Low (days later)
- **False positives:** Low (weekly noise)

### Daily Scan
- **Detection time:** 0-1 days (average: 12 hours)
- **Developer recall:** High (yesterday)
- **False positives:** Low (threshold filtering)

### Pre-commit Hook
- **Detection time:** 0 seconds (immediate)
- **Developer recall:** Perfect (right now)
- **False positives:** None (informational only)

---

## Updated Files Needed

1. **Migration:** ✅ Already created
   - `dead_code_history` table

2. **Schema:** ✅ Already created
   - `DeadCodeHistory` with trend analysis

3. **Agent Update:** 🔄 Need to modify
   - Add database storage
   - Change schedule to daily
   - Add weekly summary logic

4. **Pre-commit Hook:** 🔄 Need to create
   - `.git/hooks/pre-commit`
   - Warns on increase

5. **Config:** 🔄 Need to add
   - `config/config.exs`
   - Schedule and thresholds

---

## Conclusion

**You're absolutely right** - weekly is too seldom!

**Better approach:**
1. **Pre-commit hook** - Immediate feedback
2. **Daily scans** - Database tracking
3. **Weekly reports** - Summary + trends
4. **Database** - Historical analysis

**This changes:**
- Detection: 7 days → 1 day (or immediate)
- Context: Lost → Fresh
- Trends: Unknown → Visible
- Alerts: Noisy → Intelligent

**Want me to implement daily scanning + pre-commit hook?**
