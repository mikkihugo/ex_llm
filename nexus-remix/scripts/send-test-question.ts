#!/usr/bin/env bun
/**
 * Send Test Question - Quick test to send a single question request via NATS
 *
 * Usage: bun run scripts/send-test-question.ts
 *
 * The script will wait for you to type an answer in the browser and click "Answer"
 */

import { connect } from 'nats';
import { randomUUID } from 'crypto';

const NATS_URL = process.env.NATS_URL || 'nats://127.0.0.1:4222';

async function main() {
  console.log('📝 Sending test question request');
  console.log(`📍 NATS URL: ${NATS_URL}`);
  console.log('');

  try {
    const nc = await connect({ servers: NATS_URL });
    console.log('✅ Connected to NATS');

    const questionId = randomUUID();
    const request = {
      id: questionId,
      agent_id: 'test-agent',
      type: 'question',
      timestamp: new Date().toISOString(),
      question: 'Should we implement caching for this operation? (yes/no)',
      context: {
        operation: 'expensive_computation',
        frequency: 'high',
        cache_size: 'unknown',
        performance_impact: 'potentially high',
      },
    };

    console.log('');
    console.log('📤 Sending request:');
    console.log(`   ID: ${questionId}`);
    console.log(`   Question: ${request.question}`);
    console.log(`   Context:`, JSON.stringify(request.context, null, 4));
    console.log('');
    console.log('⏳ Waiting for response from browser (30s timeout)...');
    console.log('   (In browser: type answer and click "Answer" button)');
    console.log('');

    try {
      const response = await nc.request('question.ask', JSON.stringify(request), {
        timeout: 30000,
      });

      const result = JSON.parse(new TextDecoder().decode(response.data));
      console.log('✅ Received response:');
      console.log(`   Response: "${result.response}"`);
      console.log('');
      console.log('✅ Question flow working!');
    } catch (error) {
      if ((error as any).code === 'No responders available') {
        console.error('❌ No responders available');
        console.error('   Make sure:');
        console.error('   1. nats-server -js is running');
        console.error('   2. bun run dev is running (nexus-remix)');
        console.error('   3. Browser has http://localhost:3000/approvals open');
        console.error('   4. WebSocket is connected');
      } else if ((error as any).message?.includes('timeout')) {
        console.error('⏱️  Timed out waiting for response');
        console.error('   Make sure to type answer and click "Answer" in the browser');
      } else {
        console.error('❌ Error:', error);
      }
    }

    await nc.close();
    console.log('');
    console.log('Done!');
  } catch (error) {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  }
}

main();
