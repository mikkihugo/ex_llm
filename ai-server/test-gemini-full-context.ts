/**
 * Test Gemini 2.5 Pro with full BEAM codebase
 *
 * This script:
 * 1. Gathers all Elixir + Gleam code (~477K tokens)
 * 2. Sends to Gemini 2.5 Pro (1M context)
 * 3. Asks a cross-codebase question
 * 4. Reports token usage and response quality
 */

import { createGeminiProvider } from './src/providers/gemini-code';
import { generateText } from 'ai';
import { readFileSync, readdirSync, statSync } from 'fs';
import { join } from 'path';

const gemini = createGeminiProvider({ authType: 'oauth-personal' });

// Recursively find all files matching extensions
function findFiles(dir: string, extensions: string[]): string[] {
  const files: string[] = [];

  try {
    const entries = readdirSync(dir);

    for (const entry of entries) {
      const fullPath = join(dir, entry);
      const stat = statSync(fullPath);

      if (stat.isDirectory()) {
        // Skip build/deps directories
        if (['_build', 'deps', 'node_modules', '.elixir_ls'].includes(entry)) {
          continue;
        }
        files.push(...findFiles(fullPath, extensions));
      } else if (stat.isFile()) {
        const ext = entry.split('.').pop();
        if (ext && extensions.includes(ext)) {
          files.push(fullPath);
        }
      }
    }
  } catch (err) {
    // Skip permission errors
  }

  return files;
}

// Main test
async function testGeminiFullContext() {
  console.log('🔍 Gathering BEAM codebase...\n');

  const rootDir = '../singularity_app';
  const elixirFiles = findFiles(join(rootDir, 'lib'), ['ex', 'exs']);
  const gleamFiles = findFiles(join(rootDir, 'src'), ['gleam']);

  console.log(`📊 Found:
  - ${elixirFiles.length} Elixir files
  - ${gleamFiles.length} Gleam files
  - ${elixirFiles.length + gleamFiles.length} total files
`);

  // Build context
  let context = `# SINGULARITY BEAM CODEBASE

## Project Overview:
- Autonomous AI agents (Elixir/Gleam/Rust)
- GPU-accelerated semantic code search (RTX 4080 + pgvector)
- Living knowledge base (Git ←→ PostgreSQL bidirectional learning)
- Multi-AI provider orchestration (Claude, Gemini, OpenAI, Copilot)
- Distributed messaging (NATS with JetStream)

## Architecture:
- Elixir: OTP supervision trees, GenServers, Phoenix
- Gleam: Type-safe BEAM modules
- PostgreSQL: Vector search, graph queries (Apache AGE)
- NATS: Distributed messaging

---

`;

  // Add Elixir files
  for (const file of elixirFiles.slice(0, 100)) { // Limit for safety
    const relativePath = file.replace('../singularity_app/', '');
    try {
      const content = readFileSync(file, 'utf-8');
      context += `\n# FILE: ${relativePath}\n\`\`\`elixir\n${content}\n\`\`\`\n`;
    } catch (err) {
      console.log(`⚠️  Skipped ${relativePath}: ${err}`);
    }
  }

  // Add Gleam files
  for (const file of gleamFiles) {
    const relativePath = file.replace('../singularity_app/', '');
    try {
      const content = readFileSync(file, 'utf-8');
      context += `\n# FILE: ${relativePath}\n\`\`\`gleam\n${content}\n\`\`\`\n`;
    } catch (err) {
      console.log(`⚠️  Skipped ${relativePath}: ${err}`);
    }
  }

  const contextChars = context.length;
  const estimatedTokens = Math.ceil(contextChars / 4);

  console.log(`📦 Context prepared:
  - Characters: ${contextChars.toLocaleString()}
  - Estimated tokens: ${estimatedTokens.toLocaleString()} (~${((estimatedTokens/1048576)*100).toFixed(1)}% of 1M)
`);

  // Ask a cross-codebase question
  const question = `
Based on the ENTIRE codebase you just read:

1. How does the NatsOrchestrator (Elixir) coordinate with Gleam modules?
2. What is the flow when an AI request comes in via NATS?
3. Which GenServers handle the Agent lifecycle?
4. How does the Living Knowledge Base sync between Git and PostgreSQL?

Please give specific file paths and function names in your answer.
`;

  console.log('🚀 Sending to Gemini 2.5 Pro...\n');
  console.log(`❓ Question: ${question.trim()}\n`);

  const startTime = Date.now();

  try {
    const result = await generateText({
      model: gemini.languageModel('gemini-2.5-pro'),
      prompt: context + '\n\n' + question,
      maxTokens: 4000,
    });

    const duration = ((Date.now() - startTime) / 1000).toFixed(1);

    console.log('✅ SUCCESS!\n');
    console.log('═'.repeat(80));
    console.log('GEMINI 2.5 PRO RESPONSE:');
    console.log('═'.repeat(80));
    console.log(result.text);
    console.log('═'.repeat(80));

    console.log(`\n📊 Stats:
  - Duration: ${duration}s
  - Prompt tokens: ${result.usage?.promptTokens?.toLocaleString() || 'N/A'}
  - Completion tokens: ${result.usage?.completionTokens?.toLocaleString() || 'N/A'}
  - Total tokens: ${result.usage?.totalTokens?.toLocaleString() || 'N/A'}
  - Context usage: ${result.usage?.promptTokens ? ((result.usage.promptTokens/1048576)*100).toFixed(1) : 'N/A'}%
`);

    if (result.usage?.promptTokens) {
      const remaining = 1048576 - result.usage.promptTokens;
      console.log(`✅ Remaining context: ${remaining.toLocaleString()} tokens (${((remaining/1048576)*100).toFixed(1)}%)\n`);
    }

  } catch (error: any) {
    console.error('❌ ERROR:', error.message);
    console.error('\nFull error:', error);
  }
}

// Run test
testGeminiFullContext().catch(console.error);
