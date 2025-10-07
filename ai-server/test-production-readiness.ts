/**
 * Production Readiness Assessment with Gemini 2.5 Pro
 *
 * Feed full BEAM codebase and get production deployment checklist
 */

import { createGeminiProvider } from './src/providers/gemini-code';
import { generateText } from 'ai';
import { readFileSync } from 'fs';

const gemini = createGeminiProvider({ authType: 'oauth-personal' });

async function assessProductionReadiness() {
  console.log('🔍 Loading updated BEAM codebase (470K tokens)...\n');

  const packedCode = readFileSync('./beam-codebase-packed.txt', 'utf-8');

  const question = `
CONTEXT CORRECTION: This codebase does NOT use Gleam in production.
All Gleam code (htdag.gleam, rule_engine.gleam, improver.gleam) was migrated to pure Elixir on Oct 5, 2025.
Only test stubs remain (gleam_tests/). The system is 100% Elixir/OTP now.

TASK: Production Readiness Assessment

You are reviewing this BEAM codebase (Elixir/OTP) for production deployment.

**Critical Questions:**

1. **Missing Components**: What essential production features are missing?
   - Telemetry/observability (metrics, tracing, logging)
   - Error tracking (Sentry, Rollbar, etc.)
   - Rate limiting
   - Circuit breakers
   - Health checks
   - Graceful shutdown

2. **Database Concerns**:
   - Are migrations production-safe?
   - Any N+1 queries or performance issues?
   - Connection pooling configured correctly?
   - Index coverage adequate?

3. **Security Issues**:
   - Secrets management (API keys hardcoded?)
   - Input validation gaps
   - SQL injection risks
   - CORS/authentication concerns

4. **Scalability Bottlenecks**:
   - Single points of failure (GenServers, ETS tables)
   - Memory leaks (process mailbox buildup)
   - Hot code reload risks in production
   - NATS connection reliability

5. **Configuration Management**:
   - Environment-specific configs (dev/staging/prod)
   - Runtime.exs vs config.exs usage
   - Secret externalization (env vars vs hardcoded)

6. **Testing Gaps**:
   - Integration test coverage
   - Load/stress tests missing
   - Critical paths untested

7. **Deployment Checklist**:
   What needs to be done BEFORE deploying to production?
   - Dependencies to audit
   - Config to review
   - Monitoring to set up
   - Backups to configure

**Output Format:**

# Production Readiness Report

## ✅ Ready for Production
[List what's working well]

## ⚠️ Critical Blockers (MUST FIX)
[Issues that will cause outages/data loss]

## 🔧 High Priority (Should Fix)
[Important but not immediately blocking]

## 📋 Pre-Deployment Checklist
[Step-by-step tasks before going live]

## 🔍 Code Locations
[Specific file paths for each issue]

Be brutally honest - this is internal tooling, not shipped software, but we still want reliability.
`;

  console.log(`📊 Codebase: ${(packedCode.length / 1024 / 1024).toFixed(2)} MB, ~470K tokens\n`);
  console.log('🚀 Sending to Gemini 2.5 Pro for production assessment...\n');

  const startTime = Date.now();

  try {
    const result = await generateText({
      model: gemini.languageModel('gemini-2.5-pro'),
      prompt: packedCode + '\n\n' + question,
      maxTokens: 16000, // Allow long, detailed response
    });

    const duration = ((Date.now() - startTime) / 1000).toFixed(1);

    console.log('✅ ASSESSMENT COMPLETE!\n');
    console.log('═'.repeat(120));
    console.log('PRODUCTION READINESS REPORT:');
    console.log('═'.repeat(120));
    console.log(result.text);
    console.log('═'.repeat(120));

    console.log(`\n📊 Stats:
  - Duration: ${duration}s
  - Total tokens: ${result.usage?.totalTokens?.toLocaleString() || 'N/A'}
  - Response length: ${result.text.length.toLocaleString()} chars
`);

  } catch (error: any) {
    console.error('❌ ERROR:', error.message);
    console.error('\nFull error:', error);
  }
}

console.log('🏭 PRODUCTION READINESS ASSESSMENT\n');
console.log('═'.repeat(120) + '\n');

assessProductionReadiness().catch(console.error);
