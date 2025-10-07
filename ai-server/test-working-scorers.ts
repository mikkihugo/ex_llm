#!/usr/bin/env bun

/**
 * Test Consensus Scoring with Working Providers Only
 * (Gemini, Copilot, Claude)
 */

import { consensusScoringWithCache } from './src/tools/consensus-scorer-with-cache';

const testModel = {
  id: 'test-gpt-4o',
  name: 'GPT-4o Test',
  description: 'Test model for consensus scoring',
  context_length: 128000,
  pricing: {
    prompt: '$5/1M tokens',
    completion: '$15/1M tokens'
  }
};

async function main() {
  console.log('🧪 Testing Consensus Scoring with Working Providers\n');
  console.log('Scorers: Gemini (2), Copilot (4), Claude (2) = 8 total\n');

  try {
    const scores = await consensusScoringWithCache([testModel], {
      strategy: 'diversity',
      forceRescore: true,
      batchSize: 1
    });

    const score = scores[testModel.id];
    if (score) {
      console.log('\n✅ Scoring Results:\n');
      console.log(`   Code:       ${score.code}/10`);
      console.log(`   Reasoning:  ${score.reasoning}/10`);
      console.log(`   Creativity: ${score.creativity}/10`);
      console.log(`   Speed:      ${score.speed}/10`);
      console.log(`   Cost:       ${score.cost}/10`);
      console.log(`   Confidence: ${score.confidence}`);

      if (score.consensus_metadata) {
        console.log(`\n   Scored by:  ${score.consensus_metadata.scored_by.join(', ')}`);
        console.log(`   Variance:   ${score.consensus_metadata.variance.toFixed(3)}`);
        console.log(`\n   Individual Scores:`);
        score.consensus_metadata.individual_scores.forEach(s => {
          console.log(`     ${s.scorer}: code=${s.code}, reasoning=${s.reasoning}, creativity=${s.creativity}`);
        });
      }
      console.log('\n✨ Success! Consensus scoring is working.\n');
    }
  } catch (error) {
    console.error('\n❌ Test failed:', error);
    process.exit(1);
  }
}

main();
