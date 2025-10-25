#!/usr/bin/env bun
/**
 * List ALL models from ALL providers in model registry
 *
 * Shows complete model catalog with categories, capabilities, and costs
 *
 * Usage:
 *   bun run scripts/list-all-models.ts
 *   bun run scripts/list-all-models.ts --provider openrouter
 *   bun run scripts/list-all-models.ts --cost free
 */

import { claudeCode } from 'ai-sdk-provider-claude-code';
import { codex } from '../src/providers/codex.js';
import { createGeminiProvider } from '../src/providers/gemini-code.js';
import { copilot } from '../src/providers/copilot.js';
import { cursor } from '../src/providers/cursor.js';
import { openrouter } from '../src/providers/openrouter.js';

async function main() {
  const args = process.argv.slice(2);
  const providerFilter = args.find(a => a.startsWith('--provider='))?.split('=')[1];
  const costFilter = args.find(a => a.startsWith('--cost='))?.split('=')[1] as 'free' | 'subscription' | 'limited';

  console.log('🔍 Loading models from ALL providers...\n');

  const allModels: Array<{
    provider: string;
    models: any[];
  }> = [];

  // Claude Code
  if (!providerFilter || providerFilter === 'claude') {
    const claudeModels = [
      {
        id: 'claude-sonnet-4.5',
        displayName: 'Claude Sonnet 4.5',
        cost: 'subscription' as const,
        contextWindow: 200000,
        capabilities: { reasoning: true, vision: true, tools: true },
      },
      {
        id: 'claude-3-5-sonnet-20241022',
        displayName: 'Claude 3.5 Sonnet',
        cost: 'subscription' as const,
        contextWindow: 200000,
        capabilities: { reasoning: true, vision: true, tools: true },
      },
    ];
    allModels.push({ provider: 'claude-code', models: claudeModels });
  }

  // Codex (ChatGPT Plus)
  if (!providerFilter || providerFilter === 'codex') {
    const codexModels = [
      {
        id: 'gpt-5-codex',
        displayName: 'GPT-5 Codex',
        cost: 'subscription' as const,
        contextWindow: 128000,
        capabilities: { reasoning: true, code: true, tools: true },
      },
      {
        id: 'o3-mini-codex',
        displayName: 'O3 Mini Codex',
        cost: 'subscription' as const,
        contextWindow: 128000,
        capabilities: { reasoning: true, code: true, tools: true },
      },
    ];
    allModels.push({ provider: 'codex', models: codexModels });
  }

  // Gemini
  if (!providerFilter || providerFilter === 'gemini') {
    const geminiModels = [
      {
        id: 'gemini-2.5-pro',
        displayName: 'Gemini 2.5 Pro',
        cost: 'free' as const,
        contextWindow: 1048576,
        capabilities: { reasoning: true, vision: true, tools: true },
      },
      {
        id: 'gemini-2.5-flash',
        displayName: 'Gemini 2.5 Flash',
        cost: 'free' as const,
        contextWindow: 1048576,
        capabilities: { reasoning: true, vision: true, tools: true },
      },
    ];
    allModels.push({ provider: 'gemini', models: geminiModels });
  }

  // Copilot (GitHub Copilot)
  if (!providerFilter || providerFilter === 'copilot') {
    const copilotModels = copilot.listModels();
    allModels.push({ provider: 'copilot', models: copilotModels });
  }

  // Cursor
  if (!providerFilter || providerFilter === 'cursor') {
    const cursorModels = cursor.listModels();
    allModels.push({ provider: 'cursor', models: cursorModels });
  }

  // OpenRouter (dynamic from API)
  if (!providerFilter || providerFilter === 'openrouter') {
    try {
      const openrouterModels = await openrouter.listModels();
      allModels.push({ provider: 'openrouter', models: openrouterModels });
    } catch (error) {
      console.warn('⚠️  OpenRouter API failed, skipping...\n');
    }
  }

  // Filter by cost if specified
  let totalModels = 0;
  for (const { provider, models } of allModels) {
    const filtered = costFilter
      ? models.filter(m => m.cost === costFilter)
      : models;

    if (filtered.length === 0) continue;

    totalModels += filtered.length;

    console.log(`\n📦 ${provider.toUpperCase()} (${filtered.length} models)`);
    console.log('─'.repeat(120));

    for (const model of filtered) {
      const costBadge = model.cost === 'free' ? '🆓' : model.cost === 'subscription' ? '💳' : '⚡';
      const contextStr = `${(model.contextWindow / 1024).toFixed(0)}K`.padStart(8);
      const capabilities = [];
      if (model.capabilities?.reasoning) capabilities.push('reasoning');
      if (model.capabilities?.code || model.capabilities?.completion) capabilities.push('code');
      if (model.capabilities?.vision) capabilities.push('vision');
      const capsStr = capabilities.join(', ').padEnd(30);

      console.log(
        `  ${costBadge} ${model.id.padEnd(50)} ${contextStr}  ${capsStr}  ${model.displayName}`
      );
    }
  }

  // Summary
  console.log(`\n\n📊 TOTAL: ${totalModels} models across ${allModels.length} providers`);

  // Count by cost
  const byCost = { free: 0, subscription: 0, limited: 0 };
  for (const { models } of allModels) {
    for (const model of models) {
      if (model.cost in byCost) byCost[model.cost as keyof typeof byCost]++;
    }
  }

  console.log('\n💰 By Cost:');
  console.log(`  🆓 FREE:         ${byCost.free} models`);
  console.log(`  💳 Subscription: ${byCost.subscription} models`);
  console.log(`  ⚡ Limited:      ${byCost.limited} models`);

  console.log(`\n💡 Usage:`);
  console.log(`  bun run scripts/list-all-models.ts --provider openrouter`);
  console.log(`  bun run scripts/list-all-models.ts --cost free`);
}

main().catch(console.error);
