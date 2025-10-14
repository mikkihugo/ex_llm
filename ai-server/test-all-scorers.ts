#!/usr/bin/env bun

/**
 * Test All Scorers - Verify each provider works independently
 */

import { generateText } from 'ai';
import { createGeminiProvider } from './src/providers/gemini-code.js';
import { claudeCode } from 'ai-sdk-provider-claude-code';
import { codex } from './src/providers/codex.js';
import { copilot } from './src/providers/copilot.js';
import { cursor } from './src/providers/cursor.js';

const testPrompt = 'Say "OK" if you can read this.';

async function testScorer(name: string, modelFn: () => any) {
  try {
    console.log(`⏳ Testing ${name}...`);
    const result = await generateText({
      model: modelFn(),
      messages: [{ role: 'user', content: testPrompt }],
      maxTokens: 50,
      temperature: 0.3
    });
    console.log(`✅ ${name}: ${result.text.substring(0, 50)}`);
    return true;
  } catch (error: any) {
    console.log(`❌ ${name}: ${error.message}`);
    return false;
  }
}

async function main() {
  console.log('🧪 Testing All Scorer Providers\n');

  const geminiCode = createGeminiProvider({ authType: 'oauth-personal' });

  const tests = [
    { name: 'Gemini 2.5 Flash', fn: () => geminiCode.languageModel('gemini-2.5-flash') },
    { name: 'Cursor Auto', fn: () => cursor.languageModel('auto', { approvalPolicy: 'read-only' }) },
    { name: 'Copilot GPT-4o', fn: () => copilot.languageModel('gpt-4o') },
    { name: 'Claude Sonnet', fn: () => claudeCode.languageModel('sonnet') },
    { name: 'Codex GPT-5', fn: () => codex.languageModel('gpt-5-codex') },
  ];

  let passed = 0;
  let failed = 0;

  for (const test of tests) {
    const success = await testScorer(test.name, test.fn);
    if (success) passed++;
    else failed++;
    console.log();
  }

  console.log(`\n📊 Results: ${passed}/${tests.length} passed, ${failed} failed\n`);

  if (failed === 0) {
    console.log('✨ All scorers working! Ready for consensus scoring.\n');
  } else {
    console.log('⚠️  Some scorers failed. Consensus will use working ones only.\n');
  }
}

main();
