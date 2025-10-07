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
import { generateText } from 'ai';
import { createGeminiProvider } from '../providers/gemini-code.js';
import { claudeCode } from 'ai-sdk-provider-claude-code';
import { codex } from 'ai-sdk-provider-codex';
import { copilot } from '../providers/copilot.js';
import { githubModels } from '../providers/github-models.js';
import { openrouter } from '../providers/openrouter.js';
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

const CAPABILITY_PROMPT = `Analyze this AI model and score it on 5 dimensions (1-10 scale).

Model: {MODEL_NAME}
Provider: {PROVIDER}
Description: {DESCRIPTION}
Context Window: {CONTEXT_WINDOW}
Cost Structure: {COST_STRUCTURE}

Scoring Guidelines:

**Code (1-10)**: Code generation quality
- 10: Production-ready, idiomatic, handles edge cases (e.g., GPT-4, Claude Sonnet 4.5)
- 7-9: Good code, may need minor tweaks (e.g., Gemini 2.5 Pro)
- 4-6: Basic functionality, often needs refactoring (e.g., smaller models)
- 1-3: Struggles with code structure

**Reasoning (1-10)**: Analysis, planning, architecture
- 10: Deep analysis, multi-step reasoning (e.g., Claude Sonnet 4.5, O3)
- 7-9: Solid reasoning, good for architecture (e.g., Gemini 2.5 Pro)
- 4-6: Basic reasoning (e.g., Flash models)
- 1-3: Struggles with complex analysis

**Creativity (1-10)**: Novel solutions, design thinking
- 10: Highly creative, explores alternatives (e.g., Claude models)
- 7-9: Good at novel approaches (e.g., GPT-4)
- 4-6: Conventional solutions (e.g., code-focused models)
- 1-3: Rigid, follows patterns only

**Speed (1-10)**: Response latency
- 10: Sub-second responses (e.g., Gemini Flash, Cursor Cheetah)
- 7-9: Fast (2-5 seconds)
- 4-6: Moderate (5-10 seconds)
- 1-3: Slow (10+ seconds)

**Cost (scale)**: Financial accessibility
- 10: FREE unlimited (e.g., Copilot GPT-4o, Gemini via ADC, Cursor auto/cheetah)
- 5: Quota-limited subscription (e.g., Claude Pro ~500/day, Cursor quota models)
- 1: Pay-per-token (expensive, avoid if possible)

Return ONLY valid JSON:
{
  "code": <number>,
  "reasoning": <number>,
  "creativity": <number>,
  "speed": <number>,
  "cost": <number>,
  "confidence": <"high" | "medium" | "low">,
  "reasoning_text": "<brief explanation>"
}`;

interface ModelAnalysis {
  code: number;
  reasoning: number;
  creativity: number;
  speed: number;
  cost: number;
  confidence: string;
  reasoning_text: string;
  analyzer: string;  // Which model did the analysis
}

async function askModel(modelFn: any, modelName: string, prompt: string): Promise<ModelAnalysis | null> {
  try {
    const result = await generateText({
      model: modelFn,
      messages: [{ role: 'user', content: prompt }],
      maxTokens: 500,
      temperature: 0.3
    });

    // Strip markdown code blocks if present
    let jsonText = result.text.trim();
    jsonText = jsonText.replace(/^```json\n/, '').replace(/^```\n/, '').replace(/\n```$/, '');

    const analysis = JSON.parse(jsonText);

    return {
      code: Math.min(10, Math.max(1, analysis.code)),
      reasoning: Math.min(10, Math.max(1, analysis.reasoning)),
      creativity: Math.min(10, Math.max(1, analysis.creativity)),
      speed: Math.min(10, Math.max(1, analysis.speed)),
      cost: Math.min(10, Math.max(1, analysis.cost)),
      confidence: analysis.confidence,
      reasoning_text: analysis.reasoning_text,
      analyzer: modelName
    };
  } catch (error) {
    console.warn(`  ${modelName} failed:`, error instanceof Error ? error.message : error);
    return null;
  }
}

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

  console.log('\n✅ Capability scores saved to ai-server/src/data/model-capabilities.json');
  console.log('⚠️  Review and adjust scores based on your experience!');
  console.log('💡 Scores are loaded automatically by nats-handler.ts');
}

/**
 * Generate and save capability scores for models (used by auto-regeneration)
 */
export async function generateAndSaveCapabilities(models: any[]) {
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
