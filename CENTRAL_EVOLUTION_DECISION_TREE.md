# CentralCloud Evolution - Decision Tree & Flow Diagrams

**Version**: 1.0
**Date**: 2025-10-30

## Decision Tree: When to Consult Guardian vs Patterns vs Consensus

```mermaid
graph TD
    A[Agent Evolution Triggered] --> B{Pattern Discovery?}
    B -->|Yes| C[Record Pattern<br/>Aggregator.record_pattern/4]
    B -->|No| D{Need Pattern<br/>Suggestion?}
    C --> D
    D -->|Yes| E[Suggest Pattern<br/>Aggregator.suggest_pattern/2]
    D -->|No| F[Register Change<br/>Guardian.register_change/4]
    E --> F

    F --> G{Guardian Auto-Approve?<br/>Guardian.approve_change?/1}

    G -->|Yes, similarity >= 0.90| H[Apply Immediately]
    G -->|No, similarity < 0.90| I{High Risk?}

    I -->|Yes| J[Propose to Consensus<br/>Consensus.propose_change/4]
    I -->|No, but needs validation| J

    J --> K[Instances Vote<br/>Consensus.vote_on_change/4]
    K --> L{Consensus Met?<br/>2/3 votes, 85%+ confidence}

    L -->|Yes| M[Broadcast via ex_quantum_flow<br/>Consensus.execute_if_consensus/1]
    L -->|No| N[Reject Change]

    M --> H
    H --> O[Monitor Metrics<br/>Guardian.report_metrics/3]

    O --> P{Threshold Breach?}
    P -->|Yes| Q[Auto-Rollback<br/>Guardian.auto_rollback_on_threshold_breach/3]
    P -->|No| R[Continue Monitoring]

    Q --> S[Change Rolled Back]
    R --> T{Success After 10 min?}
    T -->|Yes| U[Change Successful]
    T -->|No| Q

    N --> V[Log Rejection]
    S --> W[Update Safety Patterns]
    U --> X[Update Success Patterns]

    style A fill:#e1f5fe
    style C fill:#fff9c4
    style E fill:#fff9c4
    style F fill:#ffccbc
    style G fill:#ffccbc
    style H fill:#c8e6c9
    style J fill:#d1c4e9
    style K fill:#d1c4e9
    style L fill:#d1c4e9
    style O fill:#ffccbc
    style Q fill:#ef9a9a
    style U fill:#a5d6a7
```

## Detailed Flow: Pattern Discovery & Suggestion

```mermaid
sequenceDiagram
    participant A as Agent
    participant PA as Pattern Aggregator
    participant DB as CentralCloud DB
    participant G as Genesis

    Note over A: Agent discovers pattern<br/>during execution

    A->>PA: record_pattern/4<br/>(instance_id, pattern_type,<br/>code_pattern, success_rate)

    PA->>PA: Generate embedding<br/>(2560-dim via Nx/Ortex)
    PA->>DB: Store pattern with embedding

    PA->>PA: Update consensus scores<br/>(semantic similarity search)

    alt Consensus Reached (3+ instances, 95%+ success)
        PA->>DB: Mark as consensus_pattern
        Note over PA: Daily aggregation job
        PA->>PA: aggregate_learnings/0
        PA->>G: Promote to Genesis<br/>(via ex_quantum_flow)
        PA->>DB: Set promoted_to_genesis=true
    end

    Note over A: Later: Agent needs<br/>pattern suggestion

    A->>PA: suggest_pattern/2<br/>(change_type, current_code)
    PA->>PA: Generate code embedding
    PA->>DB: Semantic search<br/>(pgvector cosine similarity)
    DB-->>PA: Top 5 patterns<br/>(similarity > 0.75)
    PA-->>A: Pattern suggestions<br/>(with success_rate, usage_count)

    A->>A: Apply suggested pattern
```

## Detailed Flow: Guardian Safety Coordination

```mermaid
sequenceDiagram
    participant A as Agent
    participant G as Guardian
    participant DB as CentralCloud DB
    participant I as Instance (via ex_quantum_flow)

    Note over A: Before applying change

    A->>G: register_change/4<br/>(instance_id, change_id,<br/>code_changeset, safety_profile)

    G->>G: Validate changeset<br/>& safety_profile
    G->>DB: Store in approved_changes
    G-->>A: {:ok, change_id}

    Note over A: After applying change

    loop Every 30 seconds
        A->>G: report_metrics/3<br/>(instance_id, change_id, metrics)
        G->>DB: Store in change_metrics
        G->>G: Check threshold breach

        alt Threshold Breached
            G->>G: get_rollback_strategy/1<br/>(change_type)
            G->>I: Broadcast rollback command<br/>(via ex_quantum_flow queue)
            G-->>A: {:ok, :threshold_breach_detected}
            Note over A: Agent receives rollback<br/>command and reverts
        else Metrics OK
            G-->>A: {:ok, :monitored}
        end
    end

    Note over A: Before proposing to consensus

    A->>G: approve_change?/1<br/>(change_id)
    G->>DB: Semantic similarity search<br/>(pgvector vs safety_patterns)

    alt Similarity >= 0.90
        G-->>A: {:ok, :auto_approved, 0.94}
        Note over A: Skip consensus,<br/>apply immediately
    else Similarity < 0.90
        G-->>A: {:ok, :requires_consensus, 0.72}
        Note over A: Proceed to<br/>Consensus Engine
    end
```

## Detailed Flow: Consensus Voting & Execution

```mermaid
sequenceDiagram
    participant I1 as Instance 1<br/>(Proposer)
    participant CE as Consensus Engine
    participant PG as ex_quantum_flow Queue
    participant I2 as Instance 2
    participant I3 as Instance 3
    participant DB as CentralCloud DB

    Note over I1: Guardian requires consensus

    I1->>CE: propose_change/4<br/>(instance_id, change_id,<br/>code_change, metadata)

    CE->>DB: Store proposal
    CE->>PG: Broadcast voting request<br/>(evolution_voting_requests)
    CE-->>I1: {:ok, proposal_id}

    PG->>I2: Voting request
    PG->>I3: Voting request

    Note over I2: Analyze proposal

    I2->>CE: vote_on_change/4<br/>(instance_id, change_id,<br/>:approve, reason)
    CE->>DB: Store vote
    CE->>CE: Check consensus<br/>(need 3 votes)
    CE-->>I2: {:ok, :voted}

    Note over I3: Analyze proposal

    I3->>CE: vote_on_change/4<br/>(instance_id, change_id,<br/>:approve, reason)
    CE->>DB: Store vote
    CE->>CE: Check consensus<br/>(3 votes, 2 approves)

    alt Consensus Reached (2/3, 85%+ confidence)
        CE->>PG: Broadcast approved change<br/>(evolution_approved_changes)
        CE-->>I3: {:ok, :consensus_reached}

        PG->>I1: Apply approved change
        PG->>I2: Apply approved change
        PG->>I3: Apply approved change

        Note over I1,I3: All instances apply change<br/>and monitor metrics
    else Consensus Not Reached
        CE-->>I3: {:ok, :voted}
        Note over CE: Wait for more votes<br/>or timeout
    end
```

## Complete System Flow (All 3 Services)

```mermaid
graph TB
    subgraph "Singularity Instance"
        A1[Agent Execution]
        A2[Pattern Discovery]
        A3[Evolution Proposal]
        A4[Metric Collection]
    end

    subgraph "CentralCloud Evolution Services"
        subgraph "Pattern Aggregator"
            P1[record_pattern/4]
            P2[suggest_pattern/2]
            P3[get_consensus_patterns/2]
            P4[aggregate_learnings/0]
        end

        subgraph "Guardian"
            G1[register_change/4]
            G2[report_metrics/3]
            G3[approve_change?/1]
            G4[auto_rollback_on_threshold_breach/3]
        end

        subgraph "Consensus Engine"
            C1[propose_change/4]
            C2[vote_on_change/4]
            C3[execute_if_consensus/1]
        end
    end

    subgraph "Genesis"
        GE1[Rule Evolution]
        GE2[Autonomous Improvement]
    end

    A2 --> P1
    A3 --> P2
    P2 --> A3
    A3 --> G1
    G1 --> G3

    G3 -->|Auto-Approved| A1
    G3 -->|Requires Consensus| C1

    C1 --> C2
    C2 --> C3
    C3 --> A1

    A1 --> A4
    A4 --> G2
    G2 -->|Threshold Breach| G4
    G4 --> A1

    P3 --> P4
    P4 --> GE1
    GE1 --> GE2
    GE2 --> A1

    style P1 fill:#fff9c4
    style P2 fill:#fff9c4
    style P3 fill:#fff9c4
    style P4 fill:#fff9c4
    style G1 fill:#ffccbc
    style G2 fill:#ffccbc
    style G3 fill:#ffccbc
    style G4 fill:#ef9a9a
    style C1 fill:#d1c4e9
    style C2 fill:#d1c4e9
    style C3 fill:#d1c4e9
    style GE1 fill:#c8e6c9
    style GE2 fill:#c8e6c9
```

## Threshold Decision Matrix

| Metric | Threshold | Severity | Action |
|--------|-----------|----------|--------|
| `success_rate < 0.90` | 90% | Critical | Auto-rollback immediately |
| `error_rate > 0.10` | 10% | Critical | Auto-rollback immediately |
| `latency_p95_ms > 3000` | 3000ms | High | Auto-rollback after 2 breaches |
| `cost_cents > 10.0` | $0.10 | Medium | Alert, rollback after 5 breaches |

## Consensus Scoring Matrix

| Criteria | Requirement | Weight |
|----------|-------------|--------|
| **Minimum Votes** | >= 3 instances | Required |
| **Approval Rate** | >= 67% (2/3) | Required |
| **Average Confidence** | >= 0.85 | Required |
| **No Strong Rejections** | No vote with confidence > 0.90 and vote = reject | Required |

### Consensus Examples

#### Scenario 1: Consensus Reached
```
Votes: 4 total
- Instance 1: approve, confidence 0.92
- Instance 2: approve, confidence 0.88
- Instance 3: approve, confidence 0.90
- Instance 4: reject, confidence 0.60

Approval Rate: 3/4 = 75% ✅ (>= 67%)
Avg Confidence: (0.92 + 0.88 + 0.90 + 0.60) / 4 = 0.825 ❌ (< 0.85)

Result: Consensus NOT reached (avg confidence too low)
```

#### Scenario 2: Consensus Reached
```
Votes: 3 total
- Instance 1: approve, confidence 0.95
- Instance 2: approve, confidence 0.90
- Instance 3: approve, confidence 0.85

Approval Rate: 3/3 = 100% ✅ (>= 67%)
Avg Confidence: (0.95 + 0.90 + 0.85) / 3 = 0.90 ✅ (>= 0.85)
Strong Rejections: None ✅

Result: Consensus REACHED ✅ → Execute change
```

#### Scenario 3: Strong Rejection
```
Votes: 3 total
- Instance 1: approve, confidence 0.95
- Instance 2: approve, confidence 0.90
- Instance 3: reject, confidence 0.92

Approval Rate: 2/3 = 67% ✅ (>= 67%)
Avg Confidence: (0.95 + 0.90 + 0.92) / 3 = 0.92 ✅ (>= 0.85)
Strong Rejections: Instance 3 (reject with 0.92 confidence) ❌

Result: Consensus REJECTED ❌ (strong rejection override)
```

## Pattern Promotion Decision Tree

```mermaid
graph TD
    A[Pattern Recorded] --> B{Usage Count >= 100?}
    B -->|No| C[Continue Monitoring]
    B -->|Yes| D{Success Rate >= 0.95?}

    D -->|No| C
    D -->|Yes| E{Consensus Score >= 0.95?}

    E -->|No| C
    E -->|Yes| F{Source Instances >= 3?}

    F -->|No| C
    F -->|Yes| G{Already Promoted?}

    G -->|Yes| C
    G -->|No| H[Promote to Genesis]

    H --> I[Create Rule Proposal]
    I --> J[Broadcast to All Instances]
    J --> K[Mark as Promoted]

    style A fill:#e1f5fe
    style H fill:#c8e6c9
    style I fill:#c8e6c9
    style J fill:#c8e6c9
    style K fill:#a5d6a7
```

## Service Selection Quick Reference

| Scenario | Service to Use | Function |
|----------|---------------|----------|
| **Pattern discovered** | Pattern Aggregator | `record_pattern/4` |
| **Need pattern for evolution** | Pattern Aggregator | `suggest_pattern/2` |
| **Before applying any change** | Guardian | `register_change/4` |
| **After applying change** | Guardian | `report_metrics/3` (loop) |
| **Check if safe to apply** | Guardian | `approve_change?/1` |
| **High-risk change** | Consensus Engine | `propose_change/4` |
| **Vote on proposal** | Consensus Engine | `vote_on_change/4` |
| **Metrics breach threshold** | Guardian | `auto_rollback_on_threshold_breach/3` (automatic) |
| **Get consensus patterns** | Pattern Aggregator | `get_consensus_patterns/2` |
| **Promote to Genesis** | Pattern Aggregator | `aggregate_learnings/0` (daily) |

## Summary

**Decision Logic:**
1. **Always** register changes with Guardian before applying
2. **If pattern discovered** → Record with Pattern Aggregator
3. **If need suggestion** → Ask Pattern Aggregator for similar patterns
4. **If Guardian auto-approves** → Apply immediately
5. **If Guardian requires consensus** → Propose to Consensus Engine
6. **If consensus reached** → Broadcast to all instances
7. **Always** monitor metrics and report to Guardian
8. **If threshold breached** → Guardian auto-rolls back
9. **Daily** → Pattern Aggregator promotes to Genesis
