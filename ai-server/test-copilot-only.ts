#!/usr/bin/env bun

/**
 * Quick Copilot Test - Does it work at all?
 */

import { generateText } from 'ai';
import { copilot } from './src/providers/copilot.js';

async function main() {
  console.log('🧪 Testing Copilot GPT-4o\n');

  try {
    console.log('⏳ Calling copilot.languageModel("gpt-4o")...');

    const result = await generateText({
      model: copilot.languageModel('gpt-4o'),
      messages: [{ role: 'user', content: 'Say OK' }],
      maxTokens: 50,
      temperature: 0.3
    });

    console.log(`✅ Response: ${result.text}`);
    console.log(`   Tokens: ${result.usage?.totalTokens || 'unknown'}\n`);
    console.log('✨ Copilot works!\n');
  } catch (error: any) {
    console.error(`❌ Copilot failed: ${error.message}\n`);
    process.exit(1);
  }
}

main();
