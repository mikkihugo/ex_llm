#!/usr/bin/env bun

import { generateText } from 'ai';
import { codex } from './src/providers/codex.js';

async function test() {
  console.log('Testing Codex GPT-5...\n');

  const startTime = Date.now();

  try {
    const result = await generateText({
      model: codex.languageModel('gpt-5-codex'),
      messages: [{ role: 'user', content: 'Say OK' }],
      maxTokens: 10
    });

    const elapsed = Date.now() - startTime;
    console.log(`✅ Success in ${elapsed}ms: ${result.text}\n`);
  } catch (error: any) {
    const elapsed = Date.now() - startTime;
    console.log(`❌ Failed after ${elapsed}ms: ${error.message}\n`);
    console.error(error.stack?.split('\n').slice(0, 5).join('\n'));
  }
}

test();
