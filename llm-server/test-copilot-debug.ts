#!/usr/bin/env bun

/**
 * Debug Copilot OAuth and API calls
 */

import { createCopilotWithOAuth } from './vendor/ai-sdk-provider-copilot/dist/index.js';
import { getCopilotAccessToken } from './src/github-copilot-oauth';

async function main() {
  console.log('🔍 Debugging Copilot OAuth\n');

  try {
    console.log('Step 1: Get OAuth token...');
    const token = await getCopilotAccessToken();
    console.log(`✅ Token: ${token.substring(0, 20)}...`);

    console.log('\nStep 2: Create provider...');
    const copilot = createCopilotWithOAuth(getCopilotAccessToken);
    console.log('✅ Provider created');

    console.log('\nStep 3: Create language model...');
    const model = copilot.languageModel('gpt-4o');
    console.log('✅ Model created');

    console.log('\nStep 4: Call generateText (with 30s timeout)...');
    const { generateText } = await import('ai');

    const startTime = Date.now();
    const result = await Promise.race([
      generateText({
        model,
        messages: [{ role: 'user', content: 'Say OK' }],
        maxTokens: 10
      }),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error('30s timeout')), 30000)
      )
    ]);

    const elapsed = Date.now() - startTime;
    console.log(`✅ Response in ${elapsed}ms: ${(result as any).text}\n`);

  } catch (error: any) {
    console.error(`\n❌ Error: ${error.message}`);
    console.error(`Stack: ${error.stack?.split('\n').slice(0, 5).join('\n')}`);
  }
}

main();
