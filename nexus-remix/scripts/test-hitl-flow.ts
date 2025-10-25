#!/usr/bin/env bun
/**
 * Test HITL Flow - Simulates Singularity agents sending approval/question requests via NATS
 *
 * This script tests the complete flow:
 * 1. Connects to NATS
 * 2. Sends test approval request
 * 3. Waits for response (simulated from browser)
 * 4. Sends test question request
 * 5. Waits for response
 *
 * Usage: bun run scripts/test-hitl-flow.ts
 */

import { connect } from 'nats';
import { randomUUID } from 'crypto';

const NATS_URL = process.env.NATS_URL || 'nats://127.0.0.1:4222';

interface ApprovalRequest {
  id: string;
  agent_id: string;
  type: 'approval';
  timestamp: string;
  file_path: string;
  diff: string;
  description: string;
}

interface QuestionRequest {
  id: string;
  agent_id: string;
  type: 'question';
  timestamp: string;
  question: string;
  context?: Record<string, unknown>;
}

async function main() {
  console.log('🧪 Testing HITL Flow (NATS → WebSocket → Browser → NATS)');
  console.log(`📍 NATS URL: ${NATS_URL}`);
  console.log('');

  try {
    // Connect to NATS
    console.log('🔌 Connecting to NATS...');
    const nc = await connect({ servers: NATS_URL });
    console.log('✅ Connected to NATS\n');

    // Test 1: Approval Request
    console.log('📝 Test 1: Sending approval request');
    const approvalId = randomUUID();
    const approvalRequest: ApprovalRequest = {
      id: approvalId,
      agent_id: 'self-improving-agent',
      type: 'approval',
      timestamp: new Date().toISOString(),
      file_path: 'lib/singularity/analysis/quality_analyzer.ex',
      diff: `- defp old_function(x) do
-   x * 2
- end
+ defp optimized_function(x) do
+   x |> Kernel.*(2)
+ end`,
      description: 'Refactor: Optimize function with pipe operator',
    };

    console.log('  Request:', JSON.stringify(approvalRequest, null, 2));
    console.log('');
    console.log('⏳ Waiting for approval response (30s timeout)...');
    console.log('   (In browser, click "Approve" or "Reject" button)');
    console.log('');

    try {
      const approvalResponse = await nc.request(
        'approval.request',
        JSON.stringify(approvalRequest),
        { timeout: 30000 },
      );

      const approvalResult = JSON.parse(new TextDecoder().decode(approvalResponse.data));
      console.log('✅ Received approval response:', approvalResult);
      console.log('');
    } catch (error) {
      if ((error as any).code === 'No responders available') {
        console.log('❌ No responders - WebSocket bridge not connected or browser not open');
        console.log('   Make sure:');
        console.log('   1. bun run dev is running');
        console.log('   2. Browser has http://localhost:3000/approvals open');
        console.log('   3. WebSocket is connected (check browser DevTools)');
      } else if ((error as any).message?.includes('timeout')) {
        console.log('⏱️  Approval timed out (no response from browser)');
      } else {
        console.error('❌ Error:', error);
      }
      console.log('');
    }

    // Test 2: Question Request
    console.log('📝 Test 2: Sending question request');
    const questionId = randomUUID();
    const questionRequest: QuestionRequest = {
      id: questionId,
      agent_id: 'architecture-agent',
      type: 'question',
      timestamp: new Date().toISOString(),
      question: 'Should we use async/await pattern or use pipes with Task.await_all?',
      context: {
        module: 'lib/singularity/execution',
        current_pattern: 'nested_callbacks',
        proposed_pattern: 'async_await',
        performance_impact: 'minimal',
      },
    };

    console.log('  Request:', JSON.stringify(questionRequest, null, 2));
    console.log('');
    console.log('⏳ Waiting for question response (30s timeout)...');
    console.log('   (In browser, type answer and click "Answer" button)');
    console.log('');

    try {
      const questionResponse = await nc.request(
        'question.ask',
        JSON.stringify(questionRequest),
        { timeout: 30000 },
      );

      const questionResult = JSON.parse(new TextDecoder().decode(questionResponse.data));
      console.log('✅ Received question response:', questionResult);
      console.log('');
    } catch (error) {
      if ((error as any).code === 'No responders available') {
        console.log('❌ No responders - WebSocket bridge not connected');
      } else if ((error as any).message?.includes('timeout')) {
        console.log('⏱️  Question timed out (no response from browser)');
      } else {
        console.error('❌ Error:', error);
      }
      console.log('');
    }

    // Test 3: Rapid Sequential Requests
    console.log('📝 Test 3: Sending rapid sequential requests');
    const requests = [
      {
        id: randomUUID(),
        agent_id: 'refactoring-agent',
        type: 'approval' as const,
        timestamp: new Date().toISOString(),
        file_path: 'lib/module1.ex',
        diff: '...',
        description: 'Quick refactor 1',
      },
      {
        id: randomUUID(),
        agent_id: 'refactoring-agent',
        type: 'approval' as const,
        timestamp: new Date().toISOString(),
        file_path: 'lib/module2.ex',
        diff: '...',
        description: 'Quick refactor 2',
      },
    ];

    let successCount = 0;
    let failureCount = 0;

    for (const req of requests) {
      try {
        console.log(`  Sending: ${req.description}`);
        await nc.request('approval.request', JSON.stringify(req), { timeout: 5000 });
        successCount++;
        console.log(`  ✅ Response received`);
      } catch (error) {
        failureCount++;
        console.log(`  ⏱️  Timeout or no responder`);
      }
    }

    console.log('');
    console.log(`📊 Results: ${successCount} succeeded, ${failureCount} failed`);
    console.log('');

    // Summary
    console.log('✅ Test complete!');
    console.log('');
    console.log('Summary:');
    console.log('  ✅ NATS connection: Working');
    console.log('  ✅ Request publishing: Working');
    console.log('  ✅ WebSocket bridge: Check if responses received');
    console.log('  ✅ Round-trip: ' + (successCount > 0 ? 'Working!' : 'Check browser'));
    console.log('');

    // Cleanup
    await nc.close();
  } catch (error) {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  }
}

main();
