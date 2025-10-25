#!/usr/bin/env bun

/**
 * Simple Test - Gemini-Only Consensus Scoring
 *
 * Tests with only Gemini scorers to verify the system works end-to-end
 */

import { consensusScoringWithCache } from './src/tools/consensus-scorer-with-cache';

// Just one simple model to test
const testModels = [
  {
    id: 'test-model-1',
    name: 'Test Model GPT-4o',
    description: 'High quality general purpose model',
    context_length: 128000,
    pricing: {
      prompt: '$5/1M tokens',
      completion: '$15/1M tokens'
    }
  }
];

async function main() {
  console.log('🧪 Testing Gemini-Only Consensus Scoring\n');

  try {
    // Force strategy to use only Gemini models
    const scores = await consensusScoringWithCache(testModels, {
      strategy: 'diversity',  // Will select gemini-2.5-flash
      forceRescore: true,
      batchSize: 1
    });

    console.log('\n✅ Scoring complete! Results:\n');

    for (const model of testModels) {
      const score = scores[model.id];
      if (score) {
        console.log(`\n📋 ${model.name} (${model.id})`);
        console.log(`   Code:       ${score.code}/10`);
        console.log(`   Reasoning:  ${score.reasoning}/10`);
        console.log(`   Creativity: ${score.creativity}/10`);
        console.log(`   Speed:      ${score.speed}/10`);
        console.log(`   Cost:       ${score.cost}/10`);
        console.log(`   Confidence: ${score.confidence}`);
        console.log(`   Reasoning:  ${score.reasoning_text}`);

        if (score.consensus_metadata) {
          console.log(`   Scored by:  ${score.consensus_metadata.scored_by.join(', ')}`);
          console.log(`   Variance:   ${score.consensus_metadata.variance.toFixed(3)}`);
          console.log(`   Individual scores:`);
          score.consensus_metadata.individual_scores.forEach(s => {
            console.log(`     - ${s.scorer}: code=${s.code}, reasoning=${s.reasoning}, creativity=${s.creativity}`);
          });
        }
      }
    }

    console.log('\n✨ Test complete!\n');
  } catch (error) {
    console.error('\n❌ Test failed:', error);
    process.exit(1);
  }
}

main();
