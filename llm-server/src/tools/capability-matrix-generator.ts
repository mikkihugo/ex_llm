/**
 * Auto-generates MODEL_CAPABILITIES matrix by analyzing model documentation
 *
 * 🤝 Multi-Model Consensus (AutoGen-style meeting) - IN PROGRESS
 *
 * Currently uses Gemini Flash (FREE unlimited) for analysis.
 * TODO: Add consensus from:
 * - cursor-agent CLI (cheetah model)
 * - gh copilot (gpt-4o model)
 *
 * Planned consensus algorithm:
 * - Averages scores from multiple models
 * - Calculates variance to measure agreement
 * - High confidence if variance < 0.5 (strong consensus)
 * - Medium confidence if variance < 2.0 (some disagreement)
 * - Low confidence if variance >= 2.0 (significant disagreement)
 *
 * Scores 5 capability dimensions (1-10):
 * - code: Code generation quality
 * - reasoning: Analysis and planning
 * - creativity: Novel solutions
 * - speed: Response time
 * - cost: FREE=10, quota=5, paid=1
 */

import { buildModelCatalog } from '../model-registry.js';
import { createGeminiProvider } from '../providers/gemini-code.js';
import { claudeCode } from 'ai-sdk-provider-claude-code';
import { codex } from '../providers/codex.js';
import { copilot } from '../providers/copilot.js';
import { githubModels } from '../providers/github-models.js';
import { cursor } from '../providers/cursor.js';
import { scoreModelByHeuristics } from './heuristic-capability-scorer.js';
import { enhanceAllModelsWithOpenRouter } from './openrouter-capability-enhancer.js';

interface ModelCapability {
  code: number;        // 1-10
  reasoning: number;   // 1-10
  creativity: number;  // 1-10
  speed: number;       // 1-10
  cost: number;        // 10=FREE, 5=quota, 1=expensive
}

// const CAPABILITY_PROMPT = `Analyze this AI model and score it on 5 dimensions (1-10 scale).`;

async function analyzeModelCapabilities(model: any): Promise<ModelCapability & { confidence: string; reasoning_text: string }> {
  // Use fast heuristic-based scoring for all models
  console.log(`  🎯 Scoring with heuristics...`);

  try {
    const score = scoreModelByHeuristics(model);
    console.log(`  ✅ ${score.confidence.toUpperCase()} confidence: ${score.reasoning_text}`);

    return score;
  } catch (error) {
    console.error(`Failed to score ${model.id}:`, error);

    // Fallback: reasonable defaults
    return {
      code: 7,
      reasoning: 7,
      creativity: 6,
      speed: 7,
      cost: 5,
      confidence: 'low',
      reasoning_text: 'Heuristic scoring failed, using defaults'
    };
  }
}

async function generateCapabilityMatrix() {
  console.log('🔍 Building model catalog...\n');

  // Build model catalog dynamically
  const geminiCode = createGeminiProvider({ authType: 'oauth-personal' });

  const MODELS = await buildModelCatalog({
    'gemini-code': geminiCode as any,
    'claude-code': claudeCode as any,
    'codex': codex as any,
    'github-copilot': copilot as any,
    'github-models': githubModels as any,
    'cursor': cursor as any
    // openrouter models are fetched separately via API for enhancement
  });

  console.log(`✅ Found ${MODELS.length} models\n`);

  const capabilities: Record<string, ModelCapability & { confidence: string; reasoning_text: string }> = {};

  for (const model of MODELS) {
    console.log(`Analyzing: ${model.displayName} (${model.id})...`);

    const capability = await analyzeModelCapabilities(model);
    capabilities[model.id] = capability;

    console.log(`  ✓ Code: ${capability.code}, Reasoning: ${capability.reasoning}, Speed: ${capability.speed}, Cost: ${capability.cost}`);
    console.log(`    Confidence: ${capability.confidence} - ${capability.reasoning_text}\n`);
  }

  // Enhance with OpenRouter real data
  console.log('\n🌐 Enhancing scores with OpenRouter real data...\n');
  const enhanced = await enhanceAllModelsWithOpenRouter(capabilities);

  return enhanced;
}

function generateTypeScriptCode(capabilities: Record<string, any>): string {
  let code = `const MODEL_CAPABILITIES: Record<string, {
  code: number;        // 1-10
  reasoning: number;   // 1-10
  creativity: number;  // 1-10
  speed: number;       // 1-10
  cost: number;        // 10=FREE, 5=quota, 1=expensive
}> = {\n`;

  for (const [modelId, cap] of Object.entries(capabilities)) {
    code += `  '${modelId}': {\n`;
    code += `    code: ${cap.code},\n`;
    code += `    reasoning: ${cap.reasoning},\n`;
    code += `    creativity: ${cap.creativity},\n`;
    code += `    speed: ${cap.speed},\n`;
    code += `    cost: ${cap.cost}  // ${cap.confidence} confidence: ${cap.reasoning_text}\n`;
    code += `  },\n`;
  }

  code += `};\n`;
  return code;
}

async function saveCapabilitiesToDisk(capabilities: Record<string, any>, outputPath: string) {
  const json = JSON.stringify(capabilities, null, 2);
  await Bun.write(outputPath, json);
  console.log(`\n💾 Saved capability scores to: ${outputPath}`);
}

// CLI usage
if (import.meta.main) {
  console.log('🤖 Auto-generating MODEL_CAPABILITIES matrix...\n');

  const capabilities = await generateCapabilityMatrix();

  // Save to disk (JSON for easy editing + git versioning)
  const outputPath = new URL('../data/model-capabilities.json', import.meta.url).pathname;
  await saveCapabilitiesToDisk(capabilities, outputPath);

  // Also generate TypeScript code for reference
  const tsCode = generateTypeScriptCode(capabilities);

  console.log('\n📝 Generated TypeScript (for reference):\n');
  console.log(tsCode);

  console.log('\n✅ Capability scores saved to llm-server/src/data/model-capabilities.json');
  console.log('⚠️  Review and adjust scores based on your experience!');
  console.log('💡 Scores are loaded automatically by nats-handler.ts');
}

/**
 * Generate and save capability scores for models (used by auto-regeneration)
 */
async function generateAndSaveCapabilities(models: any[]) {
  console.log('🔍 Generating capability scores...\n');

  const capabilities: Record<string, any> = {};

  for (const model of models) {
    const capability = await analyzeModelCapabilities(model);
    capabilities[model.id] = capability;
  }

  // Enhance with OpenRouter real data
  console.log('\n🌐 Enhancing scores with OpenRouter real data...\n');
  const enhanced = await enhanceAllModelsWithOpenRouter(capabilities);

  // Save to disk
  const outputPath = new URL('../data/model-capabilities.json', import.meta.url).pathname;
  await saveCapabilitiesToDisk(enhanced, outputPath);

  console.log(`✅ Auto-generated capability scores for ${models.length} models`);
  return enhanced;
}

export { analyzeModelCapabilities, generateCapabilityMatrix, saveCapabilitiesToDisk, generateAndSaveCapabilities };
