/**
 * Test Gemini 2.5 Pro with full BEAM codebase (via repomix)
 */

import { createGeminiProvider } from './src/providers/gemini-code';
import { generateText } from 'ai';
import { readFileSync } from 'fs';

const gemini = createGeminiProvider({ authType: 'oauth-personal' });

async function testGeminiBEAMContext() {
  console.log('📦 Loading packed BEAM codebase...\n');

  const packedCode = readFileSync('./beam-codebase-packed.txt', 'utf-8');

  console.log(`📊 Loaded:
  - Size: ${(packedCode.length / 1024 / 1024).toFixed(2)} MB
  - Characters: ${packedCode.length.toLocaleString()}
  - Est. tokens: ~470K (repomix calculation)
  - Context usage: ~45% of 1M
`);

  // Ask a complex cross-codebase question
  const question = `
IMPORTANT: You are in READ-ONLY mode. DO NOT suggest code changes, edits, or improvements.
Only ANALYZE and EXPLAIN the existing codebase.

Based on the ENTIRE BEAM codebase you just read:

**Question: How does Singularity handle AI provider routing and agent lifecycle?**

Please explain:

1. When an AI request arrives via NATS, which modules handle it first?
2. How does NatsOrchestrator coordinate between Elixir and Gleam code?
3. What is the full flow from "AI request" → "Agent spawned" → "Response returned"?
4. Which GenServers manage the agent lifecycle and supervision?
5. How does the Living Knowledge Base integrate with semantic code search?

Provide specific:
- File paths (e.g., lib/singularity/foo.ex:123)
- Module names
- Function names
- GenServer/Supervisor relationships

Be comprehensive - you have the FULL codebase context!

REMINDER: READ-ONLY mode - only explain what exists, don't suggest changes.
`;

  console.log(`❓ Question:\n${question.trim()}\n`);
  console.log('🚀 Sending to Gemini 2.5 Pro (1M context)...\n');

  const startTime = Date.now();

  try {
    const result = await generateText({
      model: gemini.languageModel('gemini-2.5-pro'),
      prompt: packedCode + '\n\n' + question,
      maxTokens: 8000,
    });

    const duration = ((Date.now() - startTime) / 1000).toFixed(1);

    console.log('✅ SUCCESS!\n');
    console.log('═'.repeat(100));
    console.log('GEMINI 2.5 PRO RESPONSE:');
    console.log('═'.repeat(100));
    console.log(result.text);
    console.log('═'.repeat(100));

    console.log(`\n📊 Stats:
  - Duration: ${duration}s
  - Prompt tokens: ${result.usage?.promptTokens?.toLocaleString() || 'N/A'}
  - Completion tokens: ${result.usage?.completionTokens?.toLocaleString() || 'N/A'}
  - Total tokens: ${result.usage?.totalTokens?.toLocaleString() || 'N/A'}
  - Context usage: ${result.usage?.promptTokens ? ((result.usage.promptTokens/1048576)*100).toFixed(1) : 'N/A'}% of 1M
`);

    if (result.usage?.promptTokens) {
      const remaining = 1048576 - result.usage.promptTokens;
      console.log(`\n✅ Remaining context: ${remaining.toLocaleString()} tokens (${((remaining/1048576)*100).toFixed(1)}%)`);
      console.log(`💡 You could fit ${Math.floor(remaining / 1000)}K more tokens (documentation, test output, etc.)\n`);
    }

    // Validate response quality
    const hasFilePaths = /lib\/singularity\/[a-z_\/]+\.ex/.test(result.text);
    const hasModuleNames = /defmodule/.test(result.text) || /module Singularity/.test(result.text);
    const hasFunctionNames = /def [a-z_]+/.test(result.text);

    console.log(`🔍 Response Quality Check:
  - Contains file paths: ${hasFilePaths ? '✅' : '❌'}
  - Contains module names: ${hasModuleNames ? '✅' : '❌'}
  - Contains function names: ${hasFunctionNames ? '✅' : '❌'}
  - Response length: ${result.text.length.toLocaleString()} chars
`);

  } catch (error: any) {
    console.error('❌ ERROR:', error.message);

    if (error.message?.includes('context_length_exceeded')) {
      console.error('\n⚠️  CONTEXT OVERFLOW! The codebase is too large for 1M tokens.');
      console.error('   Try reducing with: --ignore "test/**" or limiting files.');
    } else {
      console.error('\nFull error:', error);
    }
  }
}

// Run test
console.log('🧪 Testing Gemini 2.5 Pro with Full BEAM Codebase\n');
console.log('═'.repeat(100) + '\n');

testGeminiBEAMContext().catch(console.error);
