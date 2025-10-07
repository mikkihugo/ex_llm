#!/usr/bin/env bun

import { loadCachedScores } from './src/tools/consensus-scorer-with-cache';

async function main() {
  try {
    const scores = await loadCachedScores();
    const modelIds = Object.keys(scores);

    console.log(`📊 Cached scores: ${modelIds.length} total\n`);

    // Check for duplicates
    const idCounts: Record<string, number> = {};
    modelIds.forEach(id => {
      idCounts[id] = (idCounts[id] || 0) + 1;
    });

    const duplicates = Object.entries(idCounts).filter(([_, count]) => count > 1);

    if (duplicates.length > 0) {
      console.log('❌ DUPLICATES FOUND:');
      duplicates.forEach(([id, count]) => {
        console.log(`  - ${id}: ${count} entries`);
      });
    } else {
      console.log('✅ No duplicates - all model IDs are unique');
    }

    console.log('\n📋 All cached models:');
    modelIds.forEach(id => {
      const score = scores[id];
      console.log(`  - ${id}: code=${score.code}, confidence=${score.confidence}`);
    });

  } catch (error) {
    console.log('ℹ️  No cache file exists yet');
  }
}

main();
