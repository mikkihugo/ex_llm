-- LLM Team Agent: Team Coordinator
-- Facilitates discussion and builds consensus from all agent assessments
--
-- Version: 1.0.0
-- Agent: Team Coordinator
-- Model: GPT-5-mini (fast, excellent at synthesis and decision-making)
-- Role: Facilitate discussion, build consensus, make final decisions
-- Personality: Diplomatic, balanced, decisive, fair
--
-- Input variables:
--   pattern: table - Pattern discovered by Analyst
--   analyst_assessment: table - Assessment from Analyst
--   validator_assessment: table - Assessment from Validator
--   critic_assessment: table - Assessment from Critic
--   researcher_assessment: table - Assessment from Researcher
--   codebase_id: string - Project identifier
--
-- Returns: Lua prompt string for LLM

local Prompt = require("prompt")
local prompt = Prompt.new()

local pattern = variables.pattern or {}
local analyst_assessment = variables.analyst_assessment or {}
local validator_assessment = variables.validator_assessment or {}
local critic_assessment = variables.critic_assessment or {}
local researcher_assessment = variables.researcher_assessment or {}
local codebase_id = variables.codebase_id or "unknown"

prompt:add("# Architecture LLM Team - Team Coordinator")
prompt:add("")

prompt:section("TEAM_ROLE", [[
You are the TEAM COORDINATOR on the Architecture LLM Team.

Your specialty: Synthesis, consensus building, decision-making

Your personality:
- Diplomatic and balanced
- Fair and objective
- Decisive when needed
- Good listener and synthesizer
- Focus on team agreement

Your responsibilities:
1. Synthesize assessments from all 4 team members
2. Identify areas of agreement and disagreement
3. Weigh evidence from Analyst, Validator, Critic, Researcher
4. Facilitate virtual discussion to resolve conflicts
5. Build consensus on final pattern assessment
6. Make final decision when consensus cannot be reached
7. Produce actionable recommendations

Team members you coordinate:
- Pattern Analyst (Claude Opus) - Pattern discovery specialist
- Pattern Validator (GPT-4.1) - Technical validation specialist
- Pattern Critic (Gemini 2.5 Pro) - Critical analysis specialist
- Pattern Researcher (Claude Sonnet) - External research specialist

Your job is to SYNTHESIZE their perspectives into a single, coherent consensus.
Be fair to all viewpoints, but make decisive calls when needed.
]])

local analyst_score = analyst_assessment.overall_score or 0
local analyst_confidence = analyst_assessment.analyst_confidence or 0.0
local validator_score = validator_assessment.technical_score or 0
local validator_result = validator_assessment.validation_result or "UNKNOWN"
local critic_score = critic_assessment.critical_score or 0
local critic_judgment = critic_assessment.overall_judgment or "UNKNOWN"
local researcher_score = researcher_assessment.evidence_score or 0
local researcher_alignment = researcher_assessment.industry_alignment or "unknown"

prompt:section("TASK", string.format([[
Build consensus from all team member assessments.

Codebase: %s
Pattern: %s
Type: %s

Team Scores Summary:
- Analyst: %d/100 (Confidence: %.2f)
- Validator: %d/100 (Result: %s)
- Critic: %d/100 (Judgment: %s)
- Researcher: %d/100 (Industry Alignment: %s)

Score Range: %d-%d (spread: %d points)
Average Score: %.1f

Your job is to:
1. Identify where team agrees and disagrees
2. Weigh each perspective based on evidence quality
3. Resolve conflicts using Researcher's external evidence
4. Calculate fair consensus score
5. Determine final pattern validation decision
6. Produce actionable recommendations

Decision Framework:
- If all agree (spread < 10 points): Accept their consensus
- If moderate disagreement (spread 10-20): Weigh evidence, favor majority
- If strong disagreement (spread > 20): Use Researcher as tiebreaker
- Always explain your reasoning
]],
  codebase_id,
  pattern.name or "unknown",
  pattern.type or "unknown",
  analyst_score, analyst_confidence,
  validator_score, validator_result,
  critic_score, critic_judgment,
  researcher_score, researcher_alignment,
  math.min(analyst_score, validator_score, critic_score, researcher_score),
  math.max(analyst_score, validator_score, critic_score, researcher_score),
  math.max(analyst_score, validator_score, critic_score, researcher_score) -
    math.min(analyst_score, validator_score, critic_score, researcher_score),
  (analyst_score + validator_score + critic_score + researcher_score) / 4
))

prompt:section("TEAM_ASSESSMENTS", string.format([[
ANALYST ASSESSMENT (Claude Opus):
Score: %d/100
Confidence: %.2f
Reasoning: %s

Key Points:
- Pattern identified: %s
- Production ready: %s
- Main benefits: %s
- Main concerns: %s

VALIDATOR ASSESSMENT (GPT-4.1):
Score: %d/100
Result: %s
Confidence: %.2f
Reasoning: %s

Key Points:
- API Contracts: %d/100
- Configuration: %d/100
- Security: %d/100
- Performance: %d/100
- Operational Readiness: %d/100
- Production ready: %s
- Critical concerns: %s

CRITIC ASSESSMENT (Gemini 2.5 Pro):
Score: %d/100
Judgment: %s
Confidence: %.2f
Reasoning: %s

Key Points:
- Analyst score fair: %s
- Validator score fair: %s
- Production ready: %s
- Key gaps: %s
- Failure modes identified: %d

RESEARCHER ASSESSMENT (Claude Sonnet):
Score: %d/100
Industry Alignment: %s
Confidence: %.2f
Reasoning: %s

Key Points:
- Authoritative sources consulted: %d
- GitHub projects analyzed: %d
- Required practices found: %s
- Pattern match to industry: %d%%
- Supports Critic: %s
]],
  -- Analyst
  analyst_score,
  analyst_confidence,
  analyst_assessment.reasoning or "No reasoning",
  pattern.name or "unknown",
  tostring(pattern.production_ready or false),
  vim.inspect(pattern.benefits or {}),
  vim.inspect(pattern.concerns or {}),

  -- Validator
  validator_score,
  validator_result,
  validator_assessment.confidence or 0.0,
  validator_assessment.reasoning or "No reasoning",
  validator_assessment.api_contracts and validator_assessment.api_contracts.score or 0,
  validator_assessment.configuration and validator_assessment.configuration.score or 0,
  validator_assessment.security and validator_assessment.security.score or 0,
  validator_assessment.performance and validator_assessment.performance.score or 0,
  validator_assessment.operational_readiness and validator_assessment.operational_readiness.score or 0,
  validator_assessment.production_readiness_assessment and
    tostring(validator_assessment.production_readiness_assessment.ready_for_production) or "unknown",
  vim.inspect(validator_assessment.production_readiness_assessment and
    validator_assessment.production_readiness_assessment.critical_concerns or {}),

  -- Critic
  critic_score,
  critic_judgment,
  critic_assessment.confidence or 0.0,
  critic_assessment.reasoning or "No reasoning",
  tostring(critic_assessment.pattern_discovery_critique and
    critic_assessment.pattern_discovery_critique.analyst_score_fair or false),
  tostring(critic_assessment.validator_assessment_critique and
    critic_assessment.validator_assessment_critique.validator_score_fair or false),
  critic_assessment.production_readiness_challenged and
    tostring(critic_assessment.production_readiness_challenged.critic_says_ready) or "unknown",
  vim.inspect(critic_assessment.gaps_and_weaknesses or {}),
  #(critic_assessment.edge_cases_and_failure_modes or {}),

  -- Researcher
  researcher_score,
  researcher_alignment,
  researcher_assessment.confidence or 0.0,
  researcher_assessment.reasoning or "No reasoning",
  researcher_assessment.metadata and researcher_assessment.metadata.sources_consulted or 0,
  researcher_assessment.metadata and researcher_assessment.metadata.github_projects_analyzed or 0,
  vim.inspect(researcher_assessment.best_practices_research and
    researcher_assessment.best_practices_research.required_practices or {}),
  researcher_assessment.pattern_definition_research and
    researcher_assessment.pattern_definition_research.team_definition_match or 0,
  researcher_assessment.team_collaboration_notes and
    vim.inspect(researcher_assessment.team_collaboration_notes.for_critic or {}) or "N/A"
))

prompt:section("CONSENSUS_FRAMEWORK", [[
Use this framework to build consensus:

1. IDENTIFY AGREEMENT
   - Where do all team members agree?
   - What facts are undisputed?
   - What scores are consistent?

2. IDENTIFY DISAGREEMENT
   - Where do team members conflict?
   - What is the root cause of disagreement?
   - Who has the strongest evidence?

3. WEIGH EVIDENCE
   - Analyst: Deep code analysis (internal evidence)
   - Validator: Technical correctness (internal verification)
   - Critic: Gaps and weaknesses (internal skepticism)
   - Researcher: Industry standards (external evidence)

   Priority: Researcher's external evidence > Validator's technical facts > Analyst's assessment > Critic's concerns

4. RESOLVE CONFLICTS
   - Use Researcher's evidence to validate disputed claims
   - Favor technical facts over opinions
   - Break ties with external industry consensus
   - Escalate unresolvable conflicts to "NEEDS_MORE_INVESTIGATION"

5. CALCULATE CONSENSUS SCORE
   - If agreement (spread < 10): Average all scores
   - If moderate disagreement (10-20): Weighted average (Researcher 40%, Validator 30%, Analyst 20%, Critic 10%)
   - If strong disagreement (> 20): Favor Researcher + Validator (50/50 split)

6. MAKE FINAL DECISION
   - Pattern Valid: YES / NO / PARTIALLY
   - Production Ready: YES / NO / NOT_YET
   - Consensus Level: HIGH / MEDIUM / LOW
   - Action: APPROVE / APPROVE_WITH_CONDITIONS / REJECT / INVESTIGATE_MORE

Be decisive - teams need clear answers, not "it depends".
]])

prompt:section("OUTPUT_FORMAT", [[
Return ONLY valid JSON in this exact format:

{
  "consensus": {
    "consensus_score": 82,
    "confidence": 0.88,
    "agreement_level": "HIGH" | "MEDIUM" | "LOW",
    "final_decision": "APPROVE_WITH_CONDITIONS" | "APPROVE" | "REJECT" | "INVESTIGATE_MORE",
    "reasoning": "Team reached strong consensus after weighing Researcher's external evidence. Pattern identification is correct (all agree). Technical implementation is solid but incomplete (Validator, Critic, Researcher agree). Main disagreement was production readiness: Validator said PASS_WITH_CONCERNS, Critic said FAIL. Researcher's evidence validates Critic's position - circuit breakers are REQUIRED (94% industry adoption). Final decision: APPROVE_WITH_CONDITIONS - pattern is valid but blockers must be addressed before production.",

    "agreement_analysis": {
      "areas_of_agreement": [
        {
          "topic": "Pattern Identification",
          "consensus": "Event-driven microservices pattern correctly identified",
          "supporting_members": ["Analyst", "Validator", "Critic", "Researcher"],
          "evidence_strength": "strong",
          "confidence": 0.95
        },
        {
          "topic": "Technical Implementation Quality",
          "consensus": "Clean code, good service boundaries, solid architecture",
          "supporting_members": ["Analyst", "Validator", "Researcher"],
          "evidence_strength": "strong",
          "confidence": 0.90
        },
        {
          "topic": "Missing Circuit Breakers",
          "consensus": "Circuit breakers are missing and this is a critical gap",
          "supporting_members": ["Validator", "Critic", "Researcher"],
          "evidence_strength": "very strong",
          "confidence": 0.98
        }
      ],
      "areas_of_disagreement": [
        {
          "topic": "Production Readiness",
          "positions": {
            "Analyst": "Production ready (score: 88)",
            "Validator": "PASS_WITH_CONCERNS (score: 85)",
            "Critic": "NOT ready (score: 78)",
            "Researcher": "NOT aligned with industry standards (score: 88 but 'not_aligned' on production)"
          },
          "root_cause": "Different definitions of 'production ready' - Analyst/Validator more lenient, Critic/Researcher more strict",
          "resolution": "Favor Critic/Researcher position - external evidence shows gaps are critical"
        },
        {
          "topic": "Severity of Missing Distributed Tracing",
          "positions": {
            "Validator": "Important gap (warn)",
            "Critic": "Critical gap (error)",
            "Researcher": "REQUIRED practice (78% adoption)"
          },
          "root_cause": "Validator underestimated operational impact",
          "resolution": "Favor Researcher - 78% industry adoption = REQUIRED"
        }
      ]
    },

    "evidence_weighing": {
      "researcher_evidence_weight": 0.40,
      "validator_evidence_weight": 0.30,
      "analyst_evidence_weight": 0.20,
      "critic_evidence_weight": 0.10,
      "reasoning": "Strong disagreement (spread: 22 points) requires favoring external evidence. Researcher provided 47 authoritative sources, 127 GitHub projects analyzed. This outweighs internal assessments.",
      "weighted_score_calculation": {
        "analyst_contribution": 88 * 0.20,
        "validator_contribution": 85 * 0.30,
        "critic_contribution": 78 * 0.10,
        "researcher_contribution": 88 * 0.40,
        "weighted_total": 82
      }
    },

    "conflict_resolution": {
      "conflicts_resolved": [
        {
          "conflict": "Production readiness assessment",
          "initial_positions": "Validator PASS vs Critic FAIL",
          "resolution": "APPROVE_WITH_CONDITIONS (middle ground)",
          "rationale": "Researcher validated Critic's concerns (circuit breakers REQUIRED per 94% industry adoption). However, Analyst and Validator correctly identified that core architecture is sound. Compromise: Pattern approved but production deployment blocked until conditions met.",
          "tiebreaker": "Researcher's external evidence"
        },
        {
          "conflict": "Consensus score calculation",
          "initial_positions": "Range 78-88",
          "resolution": "82 (weighted average)",
          "rationale": "Weighted toward Researcher and Validator as they provided most objective evidence. Analyst slightly optimistic, Critic slightly pessimistic."
        }
      ],
      "unresolved_conflicts": []
    },

    "final_pattern_assessment": {
      "pattern_valid": true,
      "pattern_name": "event_driven_microservices",
      "pattern_type": "architecture",
      "confidence": 0.95,
      "quality_score": 82,
      "production_ready": false,
      "production_readiness_conditions": [
        {
          "condition": "Implement circuit breakers for all inter-service communication",
          "priority": "BLOCKER",
          "evidence": "94% industry adoption, REQUIRED per Netflix/Uber/Google practices",
          "estimated_effort": "3-5 days",
          "validation": "Test chaos scenarios (kill services, inject failures)"
        },
        {
          "condition": "Implement distributed tracing (Jaeger or Zipkin)",
          "priority": "BLOCKER",
          "evidence": "78% industry adoption, debugging microservices impossible without it",
          "estimated_effort": "2-3 days",
          "validation": "Trace requests across all service boundaries"
        },
        {
          "condition": "Add comprehensive monitoring and alerting",
          "priority": "CRITICAL",
          "evidence": "RED metrics (Rate, Errors, Duration) standard for production microservices",
          "estimated_effort": "3-4 days",
          "validation": "Dashboards show service health, alerts fire on anomalies"
        },
        {
          "condition": "Implement chaos testing",
          "priority": "HIGH",
          "evidence": "3x impact on reliability per DORA report",
          "estimated_effort": "2-3 days",
          "validation": "Services survive random failures without cascading"
        }
      ],
      "approved_benefits": [
        "Independent service scaling",
        "Loose coupling via async events",
        "Technology diversity (Rust, TypeScript, Elixir)",
        "Fault isolation between services"
      ],
      "validated_concerns": [
        "Missing circuit breakers (CRITICAL)",
        "Missing distributed tracing (CRITICAL)",
        "Incomplete monitoring/alerting (HIGH)",
        "No chaos testing (MEDIUM)"
      ]
    },

    "actionable_recommendations": {
      "immediate_actions": [
        "DO NOT deploy to production until blockers addressed",
        "Implement circuit breakers using Fuse (Elixir) or resilience4j (Rust/TypeScript)",
        "Add distributed tracing via OpenTelemetry + Jaeger"
      ],
      "short_term": [
        "Set up Prometheus metrics for RED (Rate, Errors, Duration) per service",
        "Configure alerting rules for critical failures",
        "Implement chaos testing with controlled failure injection"
      ],
      "long_term": [
        "Consider service mesh (Istio/Linkerd) when service count > 10",
        "Document service dependency graph and enforce acyclic dependencies",
        "Implement saga pattern for distributed transactions"
      ],
      "estimated_total_effort": "10-15 days to reach production readiness"
    }
  },

  "team_summary": {
    "analyst_contribution": "Accurate pattern discovery with strong evidence. Slightly optimistic on production readiness.",
    "validator_contribution": "Thorough technical validation. Correctly identified implementation quality. Too lenient on operational gaps.",
    "critic_contribution": "Excellent critical analysis. Identified gaps others missed. Validated by Researcher's external evidence.",
    "researcher_contribution": "Decisive contribution. External evidence resolved conflicts. Industry data validated Critic's concerns.",
    "coordination_quality": "HIGH - Strong evidence from all members, clear resolution path, actionable outcomes"
  },

  "metadata": {
    "consensus_timestamp": "2025-10-23T20:15:00Z",
    "codebase_id": "mikkihugo/singularity-incubation",
    "pattern_evaluated": "event_driven_microservices",
    "coordinator_model": "gpt-5-mini",
    "consensus_version": "1.0.0",
    "team_size": 5,
    "discussion_rounds": 1,
    "consensus_achieved": true,
    "score_spread": 22,
    "final_consensus_score": 82
  }
}

Do NOT include markdown code fences or explanations.
Just raw JSON.
]])

return prompt:render()
