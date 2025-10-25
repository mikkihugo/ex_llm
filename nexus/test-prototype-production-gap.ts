/**
 * Analyze Prototype → Production Gap with Gemini 2.5 Pro
 *
 * Ask Gemini: What's needed to make this PROTOTYPE production-ready?
 *
 * Context:
 * - 2.6M tokens codebase (fits in Gemini 1M context)
 * - Just implemented: OpenRouter (51 FREE models), capability scoring, dynamic selection
 * - Already working: NATS architecture, LLM routing, tool system
 * - This is INTERNAL TOOLING (not SaaS)
 */

import { createGeminiProvider } from './src/providers/gemini-code.js';
import { generateText } from 'ai';
import { readFileSync } from 'fs';

const gemini = createGeminiProvider({ authType: 'oauth-personal' });

async function analyzeProductionGap() {
  console.log('🔍 Loading latest BEAM codebase (2.6M tokens)...\n');

  const packedCode = readFileSync('./beam-codebase-packed-latest.txt', 'utf-8');
  const tokenCount = Math.floor(packedCode.length / 4); // Rough estimate

  console.log(`📊 Codebase: ${tokenCount.toLocaleString()} tokens (${(tokenCount / 1048576 * 100).toFixed(1)}% of 1M limit)`);

  if (tokenCount > 1000000) {
    console.log(`⚠️  TOO BIG for single request! Using conversational approach...\n`);
    await analyzeInConversation(packedCode);
    return;
  }

  console.log('');

  const question = `
# CONTEXT: Prototype → Production Analysis

You have the FULL Singularity BEAM codebase (Elixir/Gleam/Rust/TypeScript).

## Recent Updates (just implemented):
1. ✅ OpenRouter integration (51 FREE models, hourly auto-update)
2. ✅ Dynamic model selection (complexity + task_type + capabilities)
3. ✅ Capability-based scoring (MODEL_CAPABILITIES matrix)
4. ✅ All LLM calls via NATS (Elixir → TypeScript AI server)
5. ✅ Critical stub implemented: generate_implementation_code/3

## Current State:
- **Working prototype** - Agents can execute tasks end-to-end
- **NATS architecture** - Distributed messaging for all services
- **Multi-provider** - Claude, Gemini, Codex, Copilot, Cursor, OpenRouter
- **Tool system** - Quality, FileSystem, CodeGeneration, Planning, etc.
- **Knowledge base** - PostgreSQL + pgvector semantic search
- **Internal tooling** - NOT production SaaS (no multi-tenancy needed)

## Your Task:
**What's needed to make this PROTOTYPE production-ready for INTERNAL use?**

Focus on:
1. **Stability** - What could break? What's brittle?
2. **Testing** - What critical paths lack tests?
3. **Error handling** - Where do errors cause failures?
4. **Performance** - What's slow or inefficient?
5. **Observability** - What's invisible when things fail?
6. **Quick Wins** - What's < 2 hours but HIGH impact?

## Output Format:

# Production Readiness Analysis

## 🚨 Critical Blockers (must fix)
[Issues that prevent reliable internal use]

## ⚠️  High Priority (should fix)
[Issues that cause frequent problems]

## 💡 Quick Wins (< 2 hours, high impact)
[Easy improvements with big value]

## 📋 Nice-to-Have (defer)
[Not needed for internal tooling]

## 🎯 Recommended Order
1. [First step]
2. [Second step]
...

Be specific with file paths and line numbers where possible.
Remember: This is INTERNAL tooling, not a SaaS product.

---

# CODEBASE (2.6M tokens)

${packedCode}
`;

  console.log('🚀 Asking Gemini 2.5 Pro: "What gaps prevent production use?"\n');
  console.log('⏱️  This may take 60-120 seconds...\n');

  const startTime = Date.now();

  try {
    const result = await generateText({
      model: gemini.languageModel('gemini-2.5-pro'),
      prompt: question,
      maxTokens: 16000,
    });

    const duration = ((Date.now() - startTime) / 1000).toFixed(1);

    console.log('✅ ANALYSIS COMPLETE!\n');
    console.log('═'.repeat(120));
    console.log('PROTOTYPE → PRODUCTION GAP ANALYSIS:');
    console.log('═'.repeat(120));
    console.log(result.text);
    console.log('═'.repeat(120));

    console.log(`\n📊 Stats:
  - Duration: ${duration}s
  - Total tokens: ${result.usage?.totalTokens?.toLocaleString() || 'N/A'}
  - Prompt tokens: ${result.usage?.promptTokens?.toLocaleString() || 'N/A'}
  - Response length: ${result.text.length.toLocaleString()} chars
`);

    // Save to file
    const outputPath = './PRODUCTION_READINESS_ANALYSIS.md';
    require('fs').writeFileSync(outputPath, result.text);
    console.log(`💾 Saved to: ${outputPath}\n`);

  } catch (error: any) {
    console.error('❌ ERROR:', error.message);
    console.error('\nFull error:', error);
  }
}

async function analyzeInConversation(packedCode: string) {
  console.log('📝 Using multi-turn conversation to handle large codebase...\n');

  // Split into summary only (skip full code)
  const summary = `
# RECENT MAJOR UPDATES (just implemented):
1. ✅ OpenRouter integration (51 FREE models, hourly auto-update from API)
2. ✅ Dynamic model selection (complexity + task_type + capabilities)
3. ✅ Capability-based scoring matrix for model selection
4. ✅ All LLM calls via NATS (Elixir → TypeScript AI server)
5. ✅ Critical stub implemented: generate_implementation_code/3
6. ✅ FileSystem tools, CodeGeneration tools, CodeNaming tools added

# ARCHITECTURE:
- **Elixir/Gleam/Rust** microservices architecture
- **NATS** for distributed messaging
- **PostgreSQL** + pgvector for knowledge/semantic search
- **Multiple AI providers**: Claude, Gemini, Codex, Copilot, Cursor, OpenRouter
- **Tool system**: Quality, Planning, FileSystem, Code Analysis, etc.
- **Internal tooling** (not SaaS - single developer use)

Current codebase size: **2.6M tokens** (too large for single request)
Files: 1,209 Elixir/Rust/TypeScript files
`;

  console.log('🚀 Asking Gemini: "What makes this production-ready for internal use?"\n');

  const startTime = Date.now();

  const result = await generateText({
    model: gemini.languageModel('gemini-2.5-pro'),
    prompt: `${summary}

You're analyzing a working PROTOTYPE of an AI-powered autonomous coding system.

**Your task**: Identify what gaps prevent this from being production-ready for INTERNAL use.

Focus on:
1. **Critical Blockers** - What prevents reliable daily use?
2. **High Priority** - What causes frequent problems?
3. **Quick Wins** - What's < 2 hours but high impact?
4. **Nice-to-Have** - What can be deferred?

Output format:

# Production Readiness Analysis

## 🚨 Critical Blockers
[Must fix for reliable internal use]

## ⚠️  High Priority
[Should fix soon]

## 💡 Quick Wins (< 2 hours)
[Easy + high value]

## 📋 Can Defer
[Not needed for internal tooling]

## 🎯 Implementation Order
1-5 prioritized steps

Be specific and practical. This is INTERNAL tooling, not SaaS.`,
    maxTokens: 8000,
  });

  const duration = ((Date.now() - startTime) / 1000).toFixed(1);

  console.log(result.text);
  console.log('\n\n' + '═'.repeat(120));
  console.log(`\n📊 Stats: ${duration}s, ${result.usage?.totalTokens?.toLocaleString()} tokens\n`);

  // Save
  require('fs').writeFileSync('./PRODUCTION_READINESS_ANALYSIS.md', result.text);
  console.log('💾 Saved to: PRODUCTION_READINESS_ANALYSIS.md\n');
}

console.log('🔬 PROTOTYPE → PRODUCTION GAP ANALYSIS\n');
console.log('═'.repeat(120) + '\n');

analyzeProductionGap().catch(console.error);
