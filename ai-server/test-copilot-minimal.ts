#!/usr/bin/env bun

import { generateText } from 'ai';
import { copilot } from './src/providers/copilot.js';

async function test() {
  console.log('Testing Copilot GPT-4o with .languageModel()...\n');

  const startTime = Date.now();

  try {
    const result = await generateText({
      model: copilot.languageModel('gpt-4o'),
      messages: [{ role: 'user', content: 'Say OK' }],
      maxTokens: 10
    });

    const elapsed = Date.now() - startTime;
    console.log(`✅ Success in ${elapsed}ms: ${result.text}\n`);
  } catch (error: any) {
    const elapsed = Date.now() - startTime;
    console.log(`❌ Failed after ${elapsed}ms: ${error.message}\n`);
  }
}

test();
