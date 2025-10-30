# CentralCloud Evolution Services - Navigation Index

**All deliverables complete** ✅

## Quick Navigation

| Document | Purpose | Target |
|----------|---------|--------|
| **[Quick Reference](CENTRAL_EVOLUTION_SERVICES_QUICK_REFERENCE.md)** | API examples, thresholds | Daily use |
| **[Integration Guide](CENTRAL_EVOLUTION_INTEGRATION_GUIDE.md)** | Complete integration flow | Integration |
| **[Decision Trees](CENTRAL_EVOLUTION_DECISION_TREE.md)** | Visual diagrams | Design |
| **[Summary](CENTRAL_EVOLUTION_IMPLEMENTATION_SUMMARY.md)** | Deployment checklist | Deployment |

## Services

1. **Guardian** - Safety monitoring & rollback (`lib/centralcloud/evolution/guardian/`)
2. **Pattern Aggregator** - Cross-instance learning (`lib/centralcloud/evolution/patterns/`)
3. **Consensus Engine** - Distributed voting (`lib/centralcloud/evolution/consensus/`)

## Database

**Migration**: `nexus/central_services/priv/repo/migrations/20251030053818_create_evolution_tables.exs`
**Tables**: 5 (approved_changes, change_metrics, patterns, pattern_usage, consensus_votes)

## Deployment

1. Run migration
2. Add to supervision tree
3. Set up ex_quantum_flow queues
4. Implement handlers
5. Test end-to-end

**See**: CENTRAL_EVOLUTION_IMPLEMENTATION_SUMMARY.md → Top 5 Priority Action Items
