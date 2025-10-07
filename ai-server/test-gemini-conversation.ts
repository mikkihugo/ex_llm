/**
 * Multi-Turn Conversation with Gemini (Context Preserved)
 *
 * Load codebase ONCE, then ask multiple questions with preserved context
 */

import { createGeminiProvider } from './src/providers/gemini-code';
import { streamText } from 'ai';
import { readFileSync } from 'fs';

const gemini = createGeminiProvider({ authType: 'oauth-personal' });

async function conversationalAnalysis() {
  console.log('🔍 Loading BEAM codebase into conversation context...\n');

  const packedCode = readFileSync('./beam-codebase-packed.txt', 'utf-8');
  const stubPlan = readFileSync('../STUB_IMPLEMENTATION_PLAN.md', 'utf-8');

  // Build conversation history
  const messages: Array<{ role: 'user' | 'assistant'; content: string }> = [
    {
      role: 'user',
      content: `I'm going to send you the full Singularity BEAM codebase. Keep it in context for multiple questions.

# CODEBASE (478K tokens)

${packedCode}

# STUB IMPLEMENTATION PLAN

${stubPlan}

---

Acknowledge that you've loaded the codebase and are ready for questions.`,
    },
  ];

  console.log('📤 Sending codebase to Gemini (first message)...\n');

  // First message: Load codebase
  const initialResult = await streamText({
    model: gemini.languageModel('gemini-2.5-pro'),
    messages,
  });

  let response = '';
  for await (const chunk of initialResult.textStream) {
    response += chunk;
    process.stdout.write(chunk);
  }
  console.log('\n\n' + '═'.repeat(120) + '\n');

  // Add assistant response to conversation
  messages.push({ role: 'assistant', content: response });

  // Now we can ask follow-up questions with full context!

  const questions = [
    'Based on the codebase, what is the ONE critical stub (file:line) I must implement for a working prototype?',
    'Show me the exact code to implement that stub using LLM.Service via NATS.',
    'What would break if I skip the other stubs? Be specific about which features fail.',
  ];

  for (const question of questions) {
    console.log(`\n🤔 Question: ${question}\n`);
    console.log('─'.repeat(120) + '\n');

    messages.push({ role: 'user', content: question });

    const result = await streamText({
      model: gemini.languageModel('gemini-2.5-pro'),
      messages,
    });

    let answer = '';
    for await (const chunk of result.textStream) {
      answer += chunk;
      process.stdout.write(chunk);
    }

    messages.push({ role: 'assistant', content: answer });
    console.log('\n\n' + '═'.repeat(120) + '\n');
  }

  console.log(`\n📊 Conversation Stats:
  - Total messages: ${messages.length}
  - Codebase sent: ONCE (first message only)
  - Follow-ups: ${questions.length} with full context preserved
`);
}

console.log('💬 CONVERSATIONAL ANALYSIS WITH GEMINI 2.5 PRO\n');
console.log('═'.repeat(120) + '\n');

conversationalAnalysis().catch(console.error);
