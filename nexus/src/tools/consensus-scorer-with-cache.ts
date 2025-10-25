/**
 * @file Consensus Scoring with Intelligent Caching
 * @description This module provides a system for scoring AI models based on a consensus
 * from a pool of other AI models. It includes features for caching scores, rotating
 * scorer models, and scheduling re-scoring based on confidence levels.
 */

import { generateText } from 'ai';
import { createGeminiProvider } from '../providers/gemini-code.js';
import { claudeCode } from 'ai-sdk-provider-claude-code';
import { codex } from '../providers/codex.js';
import { cursor } from '../providers/cursor.js';
import { openrouter } from '../providers/openrouter.js';

/**
 * @interface ConsensusMeta
 * @description Metadata about the consensus scoring process for a single model.
 */
export interface ConsensusMeta {
  scored_by: string[];
  scored_at: string;
  individual_scores: Array<{
    scorer: string;
    code: number;
    reasoning: number;
    creativity: number;
    speed: number;
    cost: number;
  }>;
  variance: number;
  next_rescore?: string;
}

/**
 * @interface CachedScore
 * @description The structure of a cached score for a model, including consensus metadata.
 */
export interface CachedScore {
  code: number;
  reasoning: number;
  creativity: number;
  speed: number;
  cost: number;
  confidence: 'high' | 'medium' | 'low';
  reasoning_text: string;
  data_sources: string[];
  consensus_metadata?: ConsensusMeta;
}

type ProviderKey = 'gemini' | 'cursor' | 'copilot' | 'claude' | 'codex' | 'openrouter';

/**
 * @const {Array<object>} FREE_SCORER_POOL
 * @description A pool of free and subscription-based AI models used for scoring other models.
 * @note Some providers are disabled due to API issues or the need for SDK upgrades.
 */
const FREE_SCORER_POOL = [
  { id: 'gemini-2.5-flash', provider: 'gemini' as ProviderKey, cost: 'free' },
  { id: 'gemini-2.5-pro', provider: 'gemini' as ProviderKey, cost: 'free' },
  { id: 'sonnet', provider: 'claude' as ProviderKey, cost: 'subscription' },
];

/**
 * @typedef {'weekly' | 'random' | 'round-robin' | 'diversity'} RotationStrategy
 * @description The strategy for rotating the scorer models to ensure diverse perspectives.
 */
export type RotationStrategy = 'weekly' | 'random' | 'round-robin' | 'diversity';

/**
 * Selects a set of three scorer models from the pool based on a rotation strategy.
 * @param {RotationStrategy} [strategy='diversity'] The rotation strategy to use.
 * @returns {typeof FREE_SCORER_POOL} An array of three selected scorer models.
 */
export function selectScorers(
  strategy: RotationStrategy = 'diversity'
): typeof FREE_SCORER_POOL {
  const now = new Date();
  switch (strategy) {
    case 'weekly': {
      const weekNum = Math.floor((now.getTime() - new Date(now.getFullYear(), 0, 1).getTime()) / (7 * 24 * 60 * 60 * 1000));
      const offset = (weekNum * 3) % FREE_SCORER_POOL.length;
      return FREE_SCORER_POOL.slice(offset, offset + 3);
    }
    case 'random': {
      const shuffled = [...FREE_SCORER_POOL].sort(() => Math.random() - 0.5);
      return shuffled.slice(0, 3);
    }
    case 'round-robin': {
      const offset = Math.floor(now.getTime() / (24 * 60 * 60 * 1000)) % FREE_SCORER_POOL.length;
      return FREE_SCORER_POOL.slice(offset, offset + 3);
    }
    case 'diversity':
    default: {
      const gemini = FREE_SCORER_POOL.filter(s => s.provider === 'gemini')[0];
      const gemini2 = FREE_SCORER_POOL.filter(s => s.provider === 'gemini')[1];
      const claude = FREE_SCORER_POOL.filter(s => s.provider === 'claude')[0];
      return [gemini, gemini2, claude].filter(Boolean);
    }
  }
}

/**
 * Determines if a cached score needs to be re-scored based on its age and metadata.
 * @param {CachedScore} cached The cached score to check.
 * @returns {boolean} True if the score needs to be updated, false otherwise.
 */
export function needsRescoring(cached: CachedScore): boolean {
  if (!cached.consensus_metadata) return true;
  const meta = cached.consensus_metadata;
  if (meta.next_rescore && new Date() > new Date(meta.next_rescore)) return true;
  const ageInDays = (Date.now() - new Date(meta.scored_at).getTime()) / (24 * 60 * 60 * 1000);
  if (ageInDays > 90) return true;
  return false;
}

/**
 * Schedules the next re-scoring date based on the confidence level of the current score.
 * @param {'high' | 'medium' | 'low'} confidence The confidence level of the score.
 * @returns {string} An ISO string representing the next re-score date.
 */
export function scheduleNextRescore(confidence: 'high' | 'medium' | 'low'): string {
  const now = new Date();
  let daysUntilRescore: number;
  switch (confidence) {
    case 'high': daysUntilRescore = 90; break;
    case 'medium': daysUntilRescore = 30; break;
    case 'low': daysUntilRescore = 7; break;
  }
  const nextRescore = new Date(now.getTime() + daysUntilRescore * 24 * 60 * 60 * 1000);
  return nextRescore.toISOString();
}

/**
 * Loads cached scores from the local disk.
 * @returns {Promise<Record<string, CachedScore>>} A promise that resolves to a map of model IDs to their cached scores.
 */
export async function loadCachedScores(): Promise<Record<string, CachedScore>> {
  try {
    const path = new URL('../data/model-capabilities.json', import.meta.url).pathname;
    const data = await Bun.file(path).text();
    return JSON.parse(data);
  } catch (error) {
    console.warn('[ConsensusScorer] No cached scores found, will generate fresh scores.');
    return {};
  }
}

/**
 * Saves the provided scores to the local disk.
 * @param {Record<string, CachedScore>} scores A map of model IDs to their scores.
 */
export async function saveCachedScores(scores: Record<string, CachedScore>): Promise<void> {
  const path = new URL('../data/model-capabilities.json', import.meta.url).pathname;
  await Bun.write(path, JSON.stringify(scores, null, 2));
  console.log(`[ConsensusScorer] Saved ${Object.keys(scores).length} cached scores to disk.`);
}

/**
 * Performs consensus scoring on a list of models, using caching to avoid redundant work.
 * @param {any[]} models An array of models to score.
 * @param {object} [options={}] Configuration options for the scoring process.
 * @returns {Promise<Record<string, CachedScore>>} A promise that resolves to the updated cache of scores.
 */
export async function consensusScoringWithCache(
  models: any[],
  options: {
    strategy?: RotationStrategy;
    forceRescore?: boolean;
    batchSize?: number;
  } = {}
) {
  const { strategy = 'diversity', forceRescore = false, batchSize = 10 } = options;
  console.log('[ConsensusScorer] Starting consensus scoring with intelligent caching...');
  const cached = await loadCachedScores();
  const scorers = selectScorers(strategy);
  console.log(`[ConsensusScorer] Selected scorers: ${scorers.map(s => s.id).join(', ')}`);
  const modelsToScore = models.filter(m => forceRescore || !cached[m.id] || needsRescoring(cached[m.id]));
  console.log(`[ConsensusScorer] Cached models: ${models.length - modelsToScore.length}, Models to score: ${modelsToScore.length}`);
  if (modelsToScore.length === 0) {
    console.log('[ConsensusScorer] All models have fresh scores.');
    return cached;
  }
  const batches = [];
  for (let i = 0; i < modelsToScore.length; i += batchSize) {
    batches.push(modelsToScore.slice(i, i + batchSize));
  }
  console.log(`[ConsensusScorer] Processing ${batches.length} batches of up to ${batchSize} models...`);
  for (let i = 0; i < batches.length; i++) {
    const batch = batches[i];
    console.log(`[ConsensusScorer] Batch ${i + 1}/${batches.length}: Scoring ${batch.length} models...`);
    await Promise.all(batch.map(async (model) => {
      try {
        const score = await consensusScore(model, scorers);
        cached[model.id] = score;
      } catch (error) {
        console.error(`[ConsensusScorer] Failed to score ${model.id}:`, error);
      }
    }));
    console.log(`[ConsensusScorer] Batch ${i + 1} complete.`);
  }
  await saveCachedScores(cached);
  return cached;
}

/**
 * Creates the prompt used to ask an AI model to evaluate another model.
 * @private
 * @param {any} model The model to be evaluated.
 * @returns {string} The scoring prompt.
 */
function createScoringPrompt(model: any): string {
  return `You are an expert AI model evaluator. Score this AI model on 5 dimensions (1-10 scale):
**Model to Evaluate:**
- ID: ${model.id}
- Name: ${model.name || model.displayName || model.id}
- Description: ${model.description || 'No description'}
- Context Window: ${model.context_length || model.contextWindow || 'Unknown'} tokens
- Pricing: ${model.pricing?.prompt || 'Unknown'} (prompt), ${model.pricing?.completion || 'Unknown'} (completion)
**Scoring Criteria:**
1. **CODE (1-10)**: Code generation quality, syntax correctness, best practices.
2. **REASONING (1-10)**: Logical thinking, problem decomposition, planning.
3. **CREATIVITY (1-10)**: Novel solutions, flexibility, edge case handling.
4. **SPEED (1-10)**: Response latency (tokens/second).
5. **COST (1-10)**: Value for money (higher = better value).
**IMPORTANT:** Respond with ONLY a JSON object (no markdown, no explanation):
{
  "code": <number>,
  "reasoning": <number>,
  "creativity": <number>,
  "speed": <number>,
  "cost": <number>,
  "rationale": "<brief 1-2 sentence explanation>"
}`;
}

/**
 * Calls a scorer model to evaluate another model.
 * @private
 * @param {object} scorer The scorer model to use.
 * @param {string} prompt The scoring prompt.
 * @returns {Promise<any>} A promise that resolves to the parsed scoring response.
 */
async function callScorer(scorer: typeof FREE_SCORER_POOL[0], prompt: string): Promise<any> {
  const geminiCode = createGeminiProvider({ authType: 'oauth-personal' });
  try {
    let result;
    switch (scorer.provider) {
      case 'gemini': {
        const model = geminiCode.languageModel?.(scorer.id) || geminiCode(scorer.id);
        if (!model) throw new Error(`Gemini model ${scorer.id} not found`);
        result = await generateText({ model, messages: [{ role: 'user', content: prompt }], temperature: 0.3 });
        break;
      }
      case 'cursor': result = await generateText({ model: cursor.languageModel(scorer.id), messages: [{ role: 'user', content: prompt }], temperature: 0.3 }); break;
      case 'copilot': throw new Error('Copilot provider not compatible with AI SDK v5'); // result = await generateText({ model: copilot.languageModel(scorer.id), messages: [{ role: 'user', content: prompt }], temperature: 0.3 }); break;
      case 'claude': result = await generateText({ model: claudeCode.languageModel(scorer.id), messages: [{ role: 'user', content: prompt }], temperature: 0.3 }); break;
      case 'codex': result = await generateText({ model: codex.languageModel(scorer.id), messages: [{ role: 'user', content: prompt }], temperature: 0.3 }); break;
      case 'openrouter': result = await generateText({ model: openrouter.languageModel(scorer.id), messages: [{ role: 'user', content: prompt }], temperature: 0.3 }); break;
      default: throw new Error(`Unknown provider: ${scorer.provider}`);
    }
    return parseScoreResponse(result.text);
  } catch (error) {
    console.error(`[ConsensusScorer] Failed to call scorer ${scorer.id}:`, error);
    throw error;
  }
}

/**
 * Parses the JSON response from a scorer model.
 * @private
 * @param {string} text The raw text response from the model.
 * @returns {any} The parsed JSON object.
 * @throws {Error} If the response is not valid JSON or scores are out of range.
 */
function parseScoreResponse(text: string): any {
  try {
    const cleaned = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
    const parsed = JSON.parse(cleaned);
    const scores = ['code', 'reasoning', 'creativity', 'speed', 'cost'];
    for (const score of scores) {
      if (typeof parsed[score] !== 'number' || parsed[score] < 1 || parsed[score] > 10) {
        throw new Error(`Invalid ${score} score: ${parsed[score]}`);
      }
    }
    return parsed;
  } catch (error) {
    console.error('[ConsensusScorer] Failed to parse score response:', text);
    throw new Error(`Invalid score format: ${error}`);
  }
}

/**
 * Generates a consensus score for a model by averaging the scores from multiple LLMs.
 * @private
 * @param {any} model The model to be scored.
 * @param {typeof FREE_SCORER_POOL} scorers An array of scorer models to use.
 * @returns {Promise<CachedScore>} A promise that resolves to the consensus score.
 */
async function consensusScore(model: any, scorers: typeof FREE_SCORER_POOL): Promise<CachedScore> {
  console.log(`[ConsensusScorer] Scoring ${model.id} with ${scorers.length} LLMs...`);
  const prompt = createScoringPrompt(model);
  const scoringPromises = scorers.map(async (scorer) => {
    try {
      const score = await callScorer(scorer, prompt);
      return { scorer: scorer.id, ...score };
    } catch (error) {
      console.error(`[ConsensusScorer] Scorer ${scorer.id} failed:`, error);
      return null;
    }
  });
  const results = await Promise.all(scoringPromises);
  const individualScores = results.filter(r => r !== null) as Array<{ scorer: string; code: number; reasoning: number; creativity: number; speed: number; cost: number; }>;
  if (individualScores.length === 0) throw new Error('All scorers failed.');
  const avgCode = individualScores.reduce((s, c) => s + c.code, 0) / individualScores.length;
  const avgReasoning = individualScores.reduce((s, c) => s + c.reasoning, 0) / individualScores.length;
  const avgCreativity = individualScores.reduce((s, c) => s + c.creativity, 0) / individualScores.length;
  const avgSpeed = individualScores.reduce((s, c) => s + c.speed, 0) / individualScores.length;
  const avgCost = individualScores.reduce((s, c) => s + c.cost, 0) / individualScores.length;
  const variance = individualScores.reduce((s, c) => s + Math.pow(c.code - avgCode, 2) + Math.pow(c.reasoning - avgReasoning, 2) + Math.pow(c.creativity - avgCreativity, 2), 0) / (individualScores.length * 3);
  const confidence = variance < 0.5 ? 'high' : variance < 2.0 ? 'medium' : 'low';
  return {
    code: Math.round(avgCode),
    reasoning: Math.round(avgReasoning),
    creativity: Math.round(avgCreativity),
    speed: Math.round(avgSpeed),
    cost: Math.round(avgCost),
    confidence,
    reasoning_text: `Consensus from ${individualScores.length}/${scorers.length} scorers. Variance: ${variance.toFixed(2)}`,
    data_sources: ['consensus-llm'],
    consensus_metadata: {
      scored_by: individualScores.map(s => s.scorer),
      scored_at: new Date().toISOString(),
      individual_scores: individualScores,
      variance,
      next_rescore: scheduleNextRescore(confidence)
    }
  };
}

export { FREE_SCORER_POOL };