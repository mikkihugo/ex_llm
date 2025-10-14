-- Epic WSJF Validation Rule
-- Autonomous decision making for epic prioritization based on WSJF scoring
--
-- This Lua script demonstrates hot-reload business logic stored in the database.
-- Update this rule without recompiling Elixir!
--
-- Context provided:
-- - context.epic_id: string
-- - context.metrics.wsjf_score: number (0-100)
-- - context.metrics.business_value: number (0-100)
-- - context.metrics.job_size: number (0-100)
--
-- Must return:
-- - decision: "autonomous" | "collaborative" | "escalated"
-- - confidence: 0.0-1.0
-- - reasoning: string

function validate_epic(ctx)
  local wsjf = ctx.metrics.wsjf_score or 0
  local business_value = ctx.metrics.business_value or 0
  local job_size = ctx.metrics.job_size or 0

  -- High WSJF + High Business Value = Autonomous
  if wsjf > 50 and business_value > 70 then
    return {
      decision = "autonomous",
      confidence = 0.95,
      reasoning = string.format(
        "High WSJF (%d) and business value (%d) - Execute automatically",
        wsjf, business_value
      )
    }
  end

  -- Medium WSJF + Small Job = Collaborative
  if wsjf > 30 and job_size < 50 then
    return {
      decision = "collaborative",
      confidence = 0.75,
      reasoning = string.format(
        "Medium WSJF (%d) with small job size (%d) - Request human input",
        wsjf, job_size
      )
    }
  end

  -- Low scores = Escalate
  return {
    decision = "escalated",
    confidence = 0.5,
    reasoning = string.format(
      "Low WSJF (%d) and business value (%d) - Human decision required",
      wsjf, business_value
    )
  }
end

-- Execute validation
return validate_epic(context)
