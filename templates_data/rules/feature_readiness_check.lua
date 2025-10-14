-- Feature Readiness Check Rule
-- Validates if a feature is ready for implementation based on acceptance criteria
--
-- Context provided:
-- - context.feature_id: string
-- - context.metrics.acceptance_criteria_count: number
-- - context.metrics.dependencies_met: number (0.0-1.0)
--
-- Must return:
-- - decision: "autonomous" | "collaborative" | "escalated"
-- - confidence: 0.0-1.0
-- - reasoning: string

function check_feature_readiness(ctx)
  local ac_count = ctx.metrics.acceptance_criteria_count or 0
  local deps_met = ctx.metrics.dependencies_met or 0.0

  -- Well-defined feature with all dependencies = Autonomous
  if ac_count >= 3 and deps_met >= 0.9 then
    return {
      decision = "autonomous",
      confidence = 0.92,
      reasoning = string.format(
        "Feature has %d acceptance criteria and %.0f%% dependencies met - Ready for implementation",
        ac_count, deps_met * 100
      )
    }
  end

  -- Some ACs but missing dependencies = Collaborative
  if ac_count >= 2 and deps_met >= 0.5 then
    return {
      decision = "collaborative",
      confidence = 0.70,
      reasoning = string.format(
        "Feature has %d acceptance criteria but only %.0f%% dependencies met - Need dependency review",
        ac_count, deps_met * 100
      )
    }
  end

  -- Poorly defined or blocked = Escalate
  return {
    decision = "escalated",
    confidence = 0.4,
    reasoning = string.format(
      "Feature has only %d acceptance criteria and %.0f%% dependencies met - Not ready",
      ac_count, deps_met * 100
    )
  }
end

-- Execute validation
return check_feature_readiness(context)
