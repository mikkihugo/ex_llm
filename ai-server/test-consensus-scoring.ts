#!/usr/bin/env bun

/**
 * Test Consensus Scoring with Real LLMs
 *
 * This script tests the consensus-based model capability scoring system
 * by scoring a small set of sample models with real LLM calls.
 */

import { consensusScoringWithCache, type RotationStrategy } from './src/tools/consensus-scorer-with-cache';

// Sample models to test scoring
const testModels = [
  {
    id: 'gemini-2.5-flash',
    name: 'Gemini 2.5 Flash',
    description: 'Fast, efficient model for quick tasks',
    context_length: 1048576,
    pricing: {
      prompt: '$0 (FREE)',
      completion: '$0 (FREE)'
    }
  },
  {
    id: 'gpt-4o',
    name: 'GPT-4o',
    description: 'GPT-4o via GitHub Copilot - multimodal, high quality',
    context_length: 131072,
    pricing: {
      prompt: '$0 (subscription)',
      completion: '$0 (subscription)'
    }
  },
  {
    id: 'claude-sonnet-4.5',
    name: 'Claude Sonnet 4.5',
    description: 'Best for coding, 64K output, extended thinking',
    context_length: 200000,
    pricing: {
      prompt: '$0 (subscription)',
      completion: '$0 (subscription)'
    }
  }
];

async function main() {
  console.log('🧪 Testing Consensus-Based Model Scoring\n');

  // Test different rotation strategies
  const strategies: RotationStrategy[] = ['diversity', 'random'];

  for (const strategy of strategies) {
    console.log(`\n${'='.repeat(60)}`);
    console.log(`📊 Testing strategy: ${strategy.toUpperCase()}`);
    console.log('='.repeat(60));

    try {
      const scores = await consensusScoringWithCache(testModels, {
        strategy,
        forceRescore: true,  // Force re-score for testing
        batchSize: 2
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
          }
        }
      }

    } catch (error) {
      console.error(`\n❌ Error testing ${strategy} strategy:`, error);
    }
  }

  console.log('\n\n✨ Test complete!\n');
}

main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
