# CentralCloud Evolution Services - Quick Reference Card

**Version**: 1.0 | **Date**: 2025-10-30

## 🎯 TL;DR

**3 Services** for centralized evolution coordination:
1. **Guardian** - Safety monitoring & rollback
2. **Pattern Aggregator** - Cross-instance learning
3. **Consensus Engine** - Distributed voting

---

## 📊 Service Quick Reference

| Service | When to Use | Key Function | Returns |
|---------|-------------|--------------|---------|
| **Guardian** | Before ANY change | `register_change/4` | `{:ok, change_id}` |
| **Guardian** | After applying | `report_metrics/3` | `{:ok, :monitored}` |
| **Guardian** | Check safety | `approve_change?/1` | `{:ok, :auto_approved, 0.94}` |
| **Patterns** | Pattern found | `record_pattern/4` | `{:ok, pattern_id}` |
| **Patterns** | Need suggestion | `suggest_pattern/2` | `{:ok, [suggestions]}` |
| **Consensus** | High-risk change | `propose_change/4` | `{:ok, proposal_id}` |
| **Consensus** | Vote on proposal | `vote_on_change/4` | `{:ok, :consensus_reached}` |

---

## 🔄 Complete Flow (Copy-Paste)

```elixir
alias CentralCloud.Evolution.Guardian.RollbackService
alias CentralCloud.Evolution.Patterns.Aggregator
alias CentralCloud.Evolution.Consensus.Engine

# 1. Get pattern suggestion
{:ok, suggestions} = Aggregator.suggest_pattern(:code_refactoring, current_code)

# 2. Register with Guardian
{:ok, change_id} = RollbackService.register_change(
  "instance-1",
  Ecto.UUID.generate(),
  %{change_type: :pattern_enhancement, before_code: "old", after_code: "new", agent_id: "agent-1"},
  %{risk_level: :low, blast_radius: :single_agent, reversibility: :automatic}
)

# 3. Check auto-approval
case RollbackService.approve_change?(change_id) do
  {:ok, :auto_approved, _} ->
    apply_change()
    monitor_metrics(change_id)

  {:ok, :requires_consensus, _} ->
    # 4. Propose to consensus
    {:ok, proposal_id} = Engine.propose_change("instance-1", change_id, code_change, metadata)

    # 5. Vote (from other instances)
    {:ok, :consensus_reached} = Engine.vote_on_change("instance-2", change_id, :approve, "Looks good")

    apply_change()
    monitor_metrics(change_id)
end

# 6. Monitor metrics (loop)
defp monitor_metrics(change_id) do
  metrics = collect_metrics()
  case RollbackService.report_metrics("instance-1", change_id, metrics) do
    {:ok, :threshold_breach_detected} -> Logger.warning("Auto-rolled back!")
    {:ok, :monitored} -> Logger.debug("OK")
  end
end
```

---

## 🚨 Thresholds (Auto-Rollback)

| Metric | Threshold | Severity | Action |
|--------|-----------|----------|--------|
| `success_rate < 0.90` | 90% | 🔴 Critical | Rollback immediately |
| `error_rate > 0.10` | 10% | 🔴 Critical | Rollback immediately |
| `latency_p95_ms > 3000` | 3000ms | 🟠 High | Rollback after 2 breaches |
| `cost_cents > 10.0` | $0.10 | 🟡 Medium | Alert, rollback after 5 breaches |

---

## 🗳️ Consensus Rules

**Consensus reached when ALL true**:
- ✅ `votes >= 3` (minimum votes)
- ✅ `approve_rate >= 67%` (2/3 majority)
- ✅ `avg_confidence >= 0.85` (quality threshold)
- ✅ No strong rejections (confidence > 0.90 + reject)

**Examples**:
```
3 votes: [approve/0.95, approve/0.90, approve/0.85]
→ 100% approval, 0.90 avg confidence → ✅ CONSENSUS

3 votes: [approve/0.95, approve/0.88, reject/0.92]
→ 67% approval, BUT strong rejection → ❌ REJECTED
```

---

## 📦 Pattern Promotion (to Genesis)

**Criteria**:
- ✅ `consensus_score >= 0.95`
- ✅ `success_rate >= 0.95`
- ✅ `source_instances >= 3`
- ✅ `usage_count >= 100`
- ✅ `promoted_to_genesis == false`

**Daily Job**: `Aggregator.aggregate_learnings/0` (automated)

---

## 🗂️ Database Tables

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `approved_changes` | Guardian tracking | change_id, instance_id, code_changeset, safety_profile, status |
| `change_metrics` | Guardian metrics | change_id, success_rate, error_rate, latency_p95_ms, reported_at |
| `patterns` | Pattern storage | pattern_id, code_pattern, consensus_score, embedding (vector) |
| `pattern_usage` | Usage tracking | pattern_id, instance_id, usage_count, success_rate |
| `consensus_votes` | Vote records | change_id, instance_id, vote, confidence, reason |

---

## 🔌 ex_quantum_flow Queues

| Queue | Direction | Purpose |
|-------|-----------|---------|
| `evolution_voting_requests` | CentralCloud → Instances | Broadcast voting requests |
| `evolution_approved_changes` | CentralCloud → Instances | Broadcast approved changes |
| `guardian_rollback_commands` | CentralCloud → Instances | Broadcast rollbacks |
| `pattern_discoveries` | Instances → CentralCloud | Report patterns |
| `genesis_rule_proposals` | CentralCloud → Genesis | Promote patterns |

---

## 🏗️ File Locations

```
nexus/central_services/lib/centralcloud/evolution/
├── guardian/
│   ├── rollback_service.ex              # Guardian GenServer
│   └── schemas/
│       ├── approved_change.ex           # Change tracking
│       └── change_metrics.ex            # Metrics tracking
├── patterns/
│   ├── aggregator.ex                    # Pattern service
│   └── schemas/
│       ├── pattern.ex                   # Pattern storage
│       └── pattern_usage.ex             # Usage tracking
└── consensus/
    ├── engine.ex                        # Consensus GenServer
    └── schemas/
        └── consensus_vote.ex            # Vote tracking

nexus/central_services/priv/repo/migrations/
└── 20251030053818_create_evolution_tables.exs  # Migration

Root:
├── CENTRAL_EVOLUTION_INTEGRATION_GUIDE.md      # Full integration guide
├── CENTRAL_EVOLUTION_DECISION_TREE.md         # Decision trees & diagrams
└── CENTRAL_EVOLUTION_IMPLEMENTATION_SUMMARY.md # Complete summary
```

---

## 🚀 Deployment Steps

### 1. Run Migration (5 min)
```bash
cd nexus/central_services
mix ecto.migrate
```

### 2. Add to Supervision Tree (10 min)
```elixir
# nexus/central_services/lib/centralcloud/application.ex
children = [
  # ... existing ...
  CentralCloud.Evolution.Guardian.RollbackService,
  CentralCloud.Evolution.Consensus.Engine
]
```

### 3. Set Up Queues (15 min)
- Create 5 ex_quantum_flow queues
- Add consumers in Singularity instances
- Add producers in CentralCloud

### 4. Implement Handlers (30 min)
- `VotingHandler` (Singularity)
- `ApprovedChangeHandler` (Singularity)
- `RollbackHandler` (Singularity)

### 5. Test End-to-End (20 min)
- Record pattern → Register → Approve → Vote → Monitor → Rollback

---

## 🧪 Quick Test

```elixir
# Start services
{:ok, _} = RollbackService.start_link([])
{:ok, _} = Engine.start_link([])

# Test Guardian
{:ok, change_id} = RollbackService.register_change(
  "dev-1", Ecto.UUID.generate(),
  %{change_type: :pattern_enhancement, before_code: "a", after_code: "b", agent_id: "test"},
  %{risk_level: :low, blast_radius: :single_agent, reversibility: :automatic}
)

# Test Pattern Aggregator
{:ok, pattern_id} = Aggregator.record_pattern(
  "dev-1", :error_handling,
  %{name: "Test", description: "Test pattern"},
  0.95
)

# Test Consensus
{:ok, proposal_id} = Engine.propose_change(
  "dev-1", change_id,
  %{change_type: :pattern_enhancement, description: "Test", affected_agents: [], before_code: "", after_code: ""},
  %{expected_improvement: "+5%", blast_radius: :single_agent, rollback_time_sec: 10}
)

{:ok, :voted} = Engine.vote_on_change("dev-1", change_id, :approve, "Looks good to me")
{:ok, :voted} = Engine.vote_on_change("dev-2", change_id, :approve, "Agreed")
{:ok, :consensus_reached} = Engine.vote_on_change("dev-3", change_id, :approve, "LGTM")
```

---

## 💡 Best Practices

1. **Always register with Guardian before applying** - Safety first
2. **Report metrics every 30s** - Early detection of issues
3. **Record all discovered patterns** - Cross-instance learning
4. **Vote with clear reasoning** - Transparent governance
5. **Monitor logs** - Guardian, Consensus, Pattern promotion events

---

## 📞 Support

- **Integration Guide**: `CENTRAL_EVOLUTION_INTEGRATION_GUIDE.md`
- **Decision Trees**: `CENTRAL_EVOLUTION_DECISION_TREE.md`
- **Implementation Summary**: `CENTRAL_EVOLUTION_IMPLEMENTATION_SUMMARY.md`
- **Code Location**: `nexus/central_services/lib/centralcloud/evolution/`
- **Migration**: `nexus/central_services/priv/repo/migrations/20251030053818_create_evolution_tables.exs`

---

**🚀 Ready to deploy! Follow the 5 deployment steps above.**
