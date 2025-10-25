#!/usr/bin/env bun

import { loadCachedScores, saveCachedScores } from './src/tools/consensus-scorer-with-cache';

async function main() {
  const scores = await loadCachedScores();
  const modelIds = Object.keys(scores);

  console.log(`📊 Before cleanup: ${modelIds.length} models\n`);

  // Remove test models (no provider prefix or test-model-*)
  const testModels = [
    'test-model-1',
    'gemini-2.5-flash',      // Test run - should be gemini-code:gemini-2.5-flash
    'gpt-4o',                // Test run - should be github-copilot:gpt-4o
    'claude-sonnet-4.5',     // Test run - should use proper provider prefix
  ];

  let removedCount = 0;
  testModels.forEach(id => {
    if (scores[id]) {
      console.log(`🗑️  Removing: ${id}`);
      delete scores[id];
      removedCount++;
    }
  });

  await saveCachedScores(scores);

  console.log(`\n✅ Cleanup complete:`);
  console.log(`   Removed: ${removedCount} test models`);
  console.log(`   Remaining: ${Object.keys(scores).length} real models`);
  console.log(`\n📋 Remaining models by provider:`);

  const byProvider: Record<string, number> = {};
  Object.keys(scores).forEach(id => {
    const provider = id.split(':')[0];
    byProvider[provider] = (byProvider[provider] || 0) + 1;
  });

  Object.entries(byProvider)
    .sort(([, a], [, b]) => b - a)
    .forEach(([provider, count]) => {
      console.log(`   ${provider}: ${count} models`);
    });
}

main();
