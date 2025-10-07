/**
 * Consensus Scoring with Intelligent Caching + Rotation
 *
 * Features:
 * - Caches scores to avoid re-scoring same models
 * - Rotates FREE scorers for diverse perspectives
 * - Re-scores on schedule or when new data available
 * - Tracks which models scored what and when
 */

import { generateText } from 'ai';
import { createGeminiProvider } from '../providers/gemini-code.js';
import { claudeCode } from 'ai-sdk-provider-claude-code';
import { codex } from 'ai-sdk-provider-codex';
import { copilot } from '../providers/copilot.js';
import { cursor } from '../providers/cursor.js';
import { openrouter } from '../providers/openrouter.js';

export interface ConsensusMeta {
  scored_by: string[];           // Which models scored this
  scored_at: string;              // ISO timestamp
  individual_scores: Array<{     // Raw scores from each scorer
    scorer: string;
    code: number;
    reasoning: number;
    creativity: number;
    speed: number;
    cost: number;
  }>;
  variance: number;               // Agreement measure
  next_rescore?: string;          // ISO timestamp when to re-score
}

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
 * Pool of FREE + SUBSCRIPTION scorers
 * All approved per AI_PROVIDER_POLICY.md
 *
 * NOTE: Cursor/Codex disabled - need @ai-sdk/provider v2 upgrade
 */
const FREE_SCORER_POOL = [
  // Gemini (FREE via ADC) - WORKING ✅
  { id: 'gemini-2.5-flash', provider: 'gemini' as ProviderKey, cost: 'free' },
  { id: 'gemini-2.5-pro', provider: 'gemini' as ProviderKey, cost: 'free' },

  // Copilot - DISABLED (API times out, not OAuth issue)
  // { id: 'gpt-4o', provider: 'copilot' as ProviderKey, cost: 'free' },
  // { id: 'gpt-4.1', provider: 'copilot' as ProviderKey, cost: 'free' },
  // { id: 'gpt-5-mini', provider: 'copilot' as ProviderKey, cost: 'free' },
  // { id: 'grok-code-fast-1', provider: 'copilot' as ProviderKey, cost: 'free' },

  // Claude (SUBSCRIPTION - Claude Pro/Max) - Enabled with longer timeout
  { id: 'sonnet', provider: 'claude' as ProviderKey, cost: 'subscription' },
  // { id: 'opus', provider: 'claude' as ProviderKey, cost: 'subscription' },

  // OpenRouter (FREE models) - DISABLED (needs API key even for free models)
  // { id: 'deepseek/deepseek-r1', provider: 'openrouter' as ProviderKey, cost: 'free' },
  // { id: 'qwen/qwq-32b-preview', provider: 'openrouter' as ProviderKey, cost: 'free' },

  // Cursor - DISABLED (AI SDK v1, needs v2 upgrade)
  // { id: 'auto', provider: 'cursor' as ProviderKey, cost: 'free' },

  // Copilot - DISABLED (hangs/timeout)
  // { id: 'gpt-4o', provider: 'copilot' as ProviderKey, cost: 'free' },

  // Codex - DISABLED (AI SDK v1, needs v2 upgrade)
  // { id: 'gpt-5-codex', provider: 'codex' as ProviderKey, cost: 'subscription' },
];

/**
 * Rotation strategies
 */
export type RotationStrategy =
  | 'weekly'      // Change scorers each week
  | 'random'      // Random 3 each time
  | 'round-robin' // Cycle through all scorers
  | 'diversity';  // Mix providers (1 Gemini + 1 Cursor + 1 Copilot)

/**
 * Select 3 scorers based on rotation strategy
 */
export function selectScorers(
  strategy: RotationStrategy = 'diversity',
  previousScorers?: string[]
): typeof FREE_SCORER_POOL {
  const now = new Date();

  switch (strategy) {
    case 'weekly': {
      // Week number of year determines rotation
      const weekNum = Math.floor((now.getTime() - new Date(now.getFullYear(), 0, 1).getTime()) / (7 * 24 * 60 * 60 * 1000));
      const offset = (weekNum * 3) % FREE_SCORER_POOL.length;
      return FREE_SCORER_POOL.slice(offset, offset + 3);
    }

    case 'random': {
      const shuffled = [...FREE_SCORER_POOL].sort(() => Math.random() - 0.5);
      return shuffled.slice(0, 3);
    }

    case 'round-robin': {
      // Use timestamp to determine offset
      const offset = Math.floor(now.getTime() / (24 * 60 * 60 * 1000)) % FREE_SCORER_POOL.length;
      return FREE_SCORER_POOL.slice(offset, offset + 3);
    }

    case 'diversity':
    default: {
      // Pick one from each provider for maximum diversity (Gemini 2x + Claude)
      const gemini = FREE_SCORER_POOL.filter(s => s.provider === 'gemini')[0];
      const gemini2 = FREE_SCORER_POOL.filter(s => s.provider === 'gemini')[1];
      const claude = FREE_SCORER_POOL.filter(s => s.provider === 'claude')[0];
      return [gemini, gemini2, claude].filter(Boolean);
    }
  }
}

/**
 * Check if a cached score needs re-scoring
 */
export function needsRescoring(cached: CachedScore): boolean {
  if (!cached.consensus_metadata) {
    return true; // No consensus data = needs scoring
  }

  const meta = cached.consensus_metadata;

  // Check if scheduled re-score time has passed
  if (meta.next_rescore) {
    const rescoreDate = new Date(meta.next_rescore);
    if (new Date() > rescoreDate) {
      return true;
    }
  }

  // Check if score is too old (default: 90 days)
  const scoredAt = new Date(meta.scored_at);
  const ageInDays = (Date.now() - scoredAt.getTime()) / (24 * 60 * 60 * 1000);
  if (ageInDays > 90) {
    return true;
  }

  return false;
}

/**
 * Schedule next re-score based on confidence
 */
export function scheduleNextRescore(confidence: 'high' | 'medium' | 'low'): string {
  const now = new Date();
  let daysUntilRescore: number;

  switch (confidence) {
    case 'high':
      daysUntilRescore = 90;  // 3 months for high confidence
      break;
    case 'medium':
      daysUntilRescore = 30;  // 1 month for medium
      break;
    case 'low':
      daysUntilRescore = 7;   // 1 week for low confidence
      break;
  }

  const nextRescore = new Date(now.getTime() + daysUntilRescore * 24 * 60 * 60 * 1000);
  return nextRescore.toISOString();
}

/**
 * Load cached scores from disk
 */
export async function loadCachedScores(): Promise<Record<string, CachedScore>> {
  try {
    const path = new URL('../data/model-capabilities.json', import.meta.url).pathname;
    const data = await Bun.file(path).text();
    return JSON.parse(data);
  } catch (error) {
    console.warn('No cached scores found, will generate fresh');
    return {};
  }
}

/**
 * Save scores to disk with cache metadata
 */
export async function saveCachedScores(scores: Record<string, CachedScore>): Promise<void> {
  const path = new URL('../data/model-capabilities.json', import.meta.url).pathname;
  await Bun.write(path, JSON.stringify(scores, null, 2));
  console.log(`💾 Saved ${Object.keys(scores).length} cached scores to disk`);
}

/**
 * Main consensus scoring with caching
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

  console.log('📊 Consensus scoring with intelligent caching...\n');

  // Load cached scores
  const cached = await loadCachedScores();

  // Select scorers for this run
  const scorers = selectScorers(strategy);
  console.log(`🎯 Selected scorers: ${scorers.map(s => s.id).join(', ')}\n`);

  // Filter models that need scoring
  const modelsToScore = models.filter(m =>
    forceRescore || !cached[m.id] || needsRescoring(cached[m.id])
  );

  console.log(`✅ Cached: ${models.length - modelsToScore.length} models`);
  console.log(`🔄 Need scoring: ${modelsToScore.length} models\n`);

  if (modelsToScore.length === 0) {
    console.log('✨ All models have fresh scores!');
    return cached;
  }

  // Score in batches (parallel within batch, sequential between batches)
  const batches = [];
  for (let i = 0; i < modelsToScore.length; i += batchSize) {
    batches.push(modelsToScore.slice(i, i + batchSize));
  }

  console.log(`📦 Processing ${batches.length} batches of ${batchSize} models...\n`);

  for (let i = 0; i < batches.length; i++) {
    const batch = batches[i];
    console.log(`Batch ${i + 1}/${batches.length}: Scoring ${batch.length} models...`);

    // Score all models in batch in parallel
    await Promise.all(batch.map(async (model) => {
      try {
        const score = await consensusScore(model, scorers);
        cached[model.id] = score;
      } catch (error) {
        console.error(`❌ Failed to score ${model.id}:`, error);
        // Keep cached score if exists, or skip
      }
    }));

    console.log(`✓ Batch ${i + 1} complete\n`);
  }

  // Save all scores to disk
  await saveCachedScores(cached);

  return cached;
}

/**
 * Generate scoring prompt for LLM evaluation
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

1. **CODE (1-10)**: Code generation quality, syntax correctness, best practices
   - 1-3: Poor/buggy code
   - 4-6: Basic working code
   - 7-8: Production-quality code
   - 9-10: Exceptional, optimized code

2. **REASONING (1-10)**: Logical thinking, problem decomposition, planning
   - 1-3: Flawed logic
   - 4-6: Basic reasoning
   - 7-8: Strong analytical skills
   - 9-10: Deep reasoning, multi-step planning

3. **CREATIVITY (1-10)**: Novel solutions, flexibility, edge case handling
   - 1-3: Rigid, template-only
   - 4-6: Standard solutions
   - 7-8: Creative approaches
   - 9-10: Highly innovative

4. **SPEED (1-10)**: Response latency (tokens/second)
   - 1-3: Very slow (< 10 tok/s)
   - 4-6: Moderate (10-50 tok/s)
   - 7-8: Fast (50-100 tok/s)
   - 9-10: Very fast (> 100 tok/s)

5. **COST (1-10)**: Value for money (higher = better value)
   - 1-3: Very expensive
   - 4-6: Moderate cost
   - 7-8: Good value
   - 9-10: Excellent value (free/cheap)

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
 * Call an LLM to score a model
 */
async function callScorer(scorer: typeof FREE_SCORER_POOL[0], prompt: string): Promise<any> {
  const geminiCode = createGeminiProvider({ authType: 'oauth-personal' });

  try {
    let result;
    switch (scorer.provider) {
      case 'gemini':
        result = await generateText({
          model: geminiCode.languageModel(scorer.id),
          messages: [{ role: 'user', content: prompt }],
          maxTokens: 2000,
          temperature: 0.3  // Low temperature for consistent scoring
        });
        break;

      case 'cursor':
        result = await generateText({
          model: cursor.languageModel(scorer.id, { approvalPolicy: 'read-only' }),
          messages: [{ role: 'user', content: prompt }],
          maxTokens: 2000,
          temperature: 0.3
        });
        break;

      case 'copilot':
        result = await generateText({
          model: copilot(scorer.id),
          messages: [{ role: 'user', content: prompt }],
          maxTokens: 2000,
          temperature: 0.3
        });
        break;

      case 'claude':
        result = await generateText({
          model: claudeCode.languageModel(scorer.id),
          messages: [{ role: 'user', content: prompt }],
          maxTokens: 2000,
          temperature: 0.3
        });
        break;

      case 'codex':
        result = await generateText({
          model: codex.languageModel(scorer.id),
          messages: [{ role: 'user', content: prompt }],
          maxTokens: 2000,
          temperature: 0.3
        });
        break;

      case 'openrouter':
        result = await generateText({
          model: openrouter.languageModel(scorer.id),
          messages: [{ role: 'user', content: prompt }],
          maxTokens: 2000,
          temperature: 0.3
        });
        break;

      default:
        throw new Error(`Unknown provider: ${scorer.provider}`);
    }

    return parseScoreResponse(result.text);
  } catch (error) {
    console.error(`❌ Failed to call scorer ${scorer.id}:`, error);
    throw error;
  }
}

/**
 * Parse LLM response to extract scores
 */
function parseScoreResponse(text: string): any {
  try {
    // Remove markdown code blocks if present
    const cleaned = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
    const parsed = JSON.parse(cleaned);

    // Validate scores are in range 1-10
    const scores = ['code', 'reasoning', 'creativity', 'speed', 'cost'];
    for (const score of scores) {
      if (typeof parsed[score] !== 'number' || parsed[score] < 1 || parsed[score] > 10) {
        throw new Error(`Invalid ${score} score: ${parsed[score]}`);
      }
    }

    return parsed;
  } catch (error) {
    console.error('❌ Failed to parse score response:', text);
    throw new Error(`Invalid score format: ${error}`);
  }
}

/**
 * Real consensus scoring with LLM calls
 */
async function consensusScore(model: any, scorers: typeof FREE_SCORER_POOL): Promise<CachedScore> {
  console.log(`  🎯 Scoring ${model.id} with ${scorers.length} LLMs...`);

  const prompt = createScoringPrompt(model);

  // Call all scorers in parallel
  const scoringPromises = scorers.map(async (scorer) => {
    try {
      console.log(`    ⏳ ${scorer.id} scoring...`);
      const score = await callScorer(scorer, prompt);
      console.log(`    ✓ ${scorer.id}: code=${score.code}, reasoning=${score.reasoning}`);
      return {
        scorer: scorer.id,
        ...score
      };
    } catch (error) {
      console.error(`    ❌ ${scorer.id} failed:`, error);
      // Return null if scorer fails
      return null;
    }
  });

  const results = await Promise.all(scoringPromises);
  const individualScores = results.filter(r => r !== null) as Array<{
    scorer: string;
    code: number;
    reasoning: number;
    creativity: number;
    speed: number;
    cost: number;
  }>;

  if (individualScores.length === 0) {
    throw new Error('All scorers failed - cannot generate consensus');
  }

  // Average scores
  const avgCode = individualScores.reduce((sum, s) => sum + s.code, 0) / individualScores.length;
  const avgReasoning = individualScores.reduce((sum, s) => sum + s.reasoning, 0) / individualScores.length;
  const avgCreativity = individualScores.reduce((sum, s) => sum + s.creativity, 0) / individualScores.length;
  const avgSpeed = individualScores.reduce((sum, s) => sum + s.speed, 0) / individualScores.length;
  const avgCost = individualScores.reduce((sum, s) => sum + s.cost, 0) / individualScores.length;

  // Calculate variance (measure of agreement)
  const variance = individualScores.reduce((sum, s) => {
    return sum + Math.pow(s.code - avgCode, 2) +
           Math.pow(s.reasoning - avgReasoning, 2) +
           Math.pow(s.creativity - avgCreativity, 2);
  }, 0) / (individualScores.length * 3);

  const confidence = variance < 0.5 ? 'high' : variance < 2.0 ? 'medium' : 'low';

  return {
    code: Math.round(avgCode),
    reasoning: Math.round(avgReasoning),
    creativity: Math.round(avgCreativity),
    speed: Math.round(avgSpeed),
    cost: Math.round(avgCost),
    confidence,
    reasoning_text: `Consensus from ${individualScores.length}/${scorers.length} scorers (${individualScores.map(s => s.scorer).join(', ')}). Variance: ${variance.toFixed(2)}`,
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
