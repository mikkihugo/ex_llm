/**
 * Prototype Deployment Readiness - Minimal Viable Setup
 *
 * What's needed to run Singularity as a working prototype (not production-hardened)?
 */

import { createGeminiProvider } from './src/providers/gemini-code';
import { generateText } from 'ai';
import { readFileSync } from 'fs';

const gemini = createGeminiProvider({ authType: 'oauth-personal' });

async function assessPrototypeReadiness() {
  console.log('🔍 Loading BEAM codebase for prototype assessment...\n');

  const packedCode = readFileSync('./beam-codebase-packed.txt', 'utf-8');

  const question = `
CONTEXT: This is INTERNAL TOOLING for a single developer, NOT a production SaaS product.

GOAL: Get a working PROTOTYPE running ASAP to demonstrate capabilities.

You just reviewed this codebase for full production readiness. Now reassess for a PROTOTYPE:

**Prototype Requirements:**
- Single developer usage (no multi-tenancy, no scale concerns)
- Nix development environment (all tools available)
- PostgreSQL + NATS already running locally
- Can tolerate bugs, just needs to WORK for demos
- Security is "good enough" for localhost (not internet-facing)
- Performance can be slow, just needs to complete tasks

**Key Questions:**

1. **Minimal Setup - What's actually REQUIRED to run?**
   - Which env vars are critical vs optional?
   - Which services must be running (PostgreSQL, NATS, anything else)?
   - Any build steps beyond \`mix deps.get && mix compile\`?

2. **Critical Bugs/Blockers - What will PREVENT it from running?**
   - Not "best practices" or "should fix"
   - Only issues that cause immediate crashes or data corruption
   - Missing dependencies, broken configs, circular deps

3. **Configuration - What needs to be configured BEFORE first run?**
   - Database setup (migrations to run?)
   - API keys that are absolutely required
   - Files that must exist

4. **Startup Sequence - How to actually start this?**
   - Correct order of commands
   - What to run in background vs foreground
   - How to verify it's working

5. **Quick Wins - Easy fixes that enable basic functionality?**
   - Comment out problematic features if needed
   - Skip non-essential modules
   - Workarounds for known issues

**Output Format:**

# Prototype Deployment Guide

## 🚀 Quick Start (5 minutes)
[Exact commands to run, in order]

## ⚠️ ACTUAL Blockers (Will Crash)
[Only critical issues that prevent startup]

## 🔧 Required Configuration
[Env vars, files, setup needed BEFORE running]

## ✅ Optional (Can Skip for Prototype)
[Nice-to-have features that can be disabled]

## 🐛 Known Issues (Workarounds)
[Problems you'll hit and how to bypass them]

## 📝 Verification Checklist
[How to confirm it's working]

Be pragmatic - this is a developer tool, not a bank. What's the FASTEST path to "it runs"?
`;

  console.log(`📊 Codebase: ${(packedCode.length / 1024 / 1024).toFixed(2)} MB, ~470K tokens\n`);
  console.log('🚀 Asking Gemini: "What do we need to get a prototype running?"\n');

  const startTime = Date.now();

  try {
    const result = await generateText({
      model: gemini.languageModel('gemini-2.5-pro'),
      prompt: packedCode + '\n\n' + question,
      maxTokens: 16000,
    });

    const duration = ((Date.now() - startTime) / 1000).toFixed(1);

    console.log('✅ PROTOTYPE GUIDE READY!\n');
    console.log('═'.repeat(120));
    console.log('PROTOTYPE DEPLOYMENT GUIDE:');
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

console.log('🧪 PROTOTYPE READINESS ASSESSMENT\n');
console.log('═'.repeat(120) + '\n');

assessPrototypeReadiness().catch(console.error);
