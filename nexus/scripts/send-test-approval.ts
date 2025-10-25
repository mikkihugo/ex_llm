#!/usr/bin/env bun
/**
 * Send Test Approval - Quick test to send a single approval request via NATS
 *
 * Usage: bun run scripts/send-test-approval.ts [approved|rejected|timeout]
 *
 * Examples:
 *   bun run scripts/send-test-approval.ts approved
 *   bun run scripts/send-test-approval.ts rejected
 *   bun run scripts/send-test-approval.ts timeout
 */

import { connect } from 'nats';
import { randomUUID } from 'crypto';

const NATS_URL = process.env.NATS_URL || 'nats://127.0.0.1:4222';
const action = process.argv[2] || 'timeout';

async function main() {
  console.log(`📝 Sending test approval request (will ${action} in browser)`);
  console.log(`📍 NATS URL: ${NATS_URL}`);
  console.log('');

  try {
    const nc = await connect({ servers: NATS_URL });
    console.log('✅ Connected to NATS');

    const approvalId = randomUUID();
    const request = {
      id: approvalId,
      agent_id: 'test-agent',
      type: 'approval',
      timestamp: new Date().toISOString(),
      file_path: 'lib/test/example.ex',
      diff: `- # Old code
- defmodule Test do
-   def hello, do: :world
- end
+ # New code
+ defmodule Test do
+   def hello, do: :hello
+ end`,
      description: 'Test approval request - please click ' + action.toUpperCase(),
    };

    console.log('');
    console.log('📤 Sending request:');
    console.log(`   ID: ${approvalId}`);
    console.log(`   File: ${request.file_path}`);
    console.log(`   Description: ${request.description}`);
    console.log('');
    console.log('⏳ Waiting for response from browser (30s timeout)...');
    console.log('   (In browser, click "Approve" or "Reject" button)');
    console.log('');

    try {
      const response = await nc.request('approval.request', JSON.stringify(request), {
        timeout: 30000,
      });

      const result = JSON.parse(new TextDecoder().decode(response.data));
      console.log('✅ Received response:');
      console.log(`   ${JSON.stringify(result)}`);

      if (result.approved === true && action === 'approved') {
        console.log('   ✅ Correct response!');
      } else if (result.approved === false && action === 'rejected') {
        console.log('   ✅ Correct response!');
      } else {
        console.log('   ⚠️  Response mismatch (expected: ' + action + ')');
      }
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
        console.error('   Make sure to click ' + action.toUpperCase() + ' in the browser');
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
