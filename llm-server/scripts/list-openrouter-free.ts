#!/usr/bin/env bun
/**
 * List all FREE models from OpenRouter API
 *
 * Usage:
 *   bun run scripts/list-openrouter-free.ts
 *   bun run scripts/list-openrouter-free.ts --category code
 *   bun run scripts/list-openrouter-free.ts --min-context 100000
 */

const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY;

if (!OPENROUTER_API_KEY) {
  console.error('❌ OPENROUTER_API_KEY not set in environment');
  process.exit(1);
}

interface Model {
  id: string;
  name: string;
  description?: string;
  context_length: number;
  pricing: {
    prompt: string;
    completion: string;
  };
  architecture?: {
    modality?: string;
    tokenizer?: string;
    instruct_type?: string;
  };
  top_provider?: {
    max_completion_tokens?: number;
  };
}

async function fetchFreeModels() {
  const response = await fetch('https://openrouter.ai/api/v1/models', {
    headers: {
      'Authorization': `Bearer ${OPENROUTER_API_KEY}`,
    },
  });

  if (!response.ok) {
    throw new Error(`OpenRouter API error: ${response.statusText}`);
  }

  const data = await response.json() as { data: Model[] };

  // Filter for FREE models only
  const freeModels = data.data.filter(m =>
    m.pricing.prompt === "0" &&
    m.pricing.completion === "0"
  );

  return freeModels;
}

function categorizeModel(model: Model): string {
  const id = model.id.toLowerCase();
  const name = model.name.toLowerCase();
  const desc = (model.description || '').toLowerCase();

  // Categorize by model characteristics
  if (id.includes('coder') || id.includes('devstral') || name.includes('coder')) return 'code';
  if (id.includes('-r1') || name.includes('reasoning') || desc.includes('reasoning')) return 'reasoning';
  if (id.includes('vl') || model.architecture?.modality === 'multimodal') return 'vision';
  if (model.context_length >= 500000) return 'large-context';
  if (model.context_length <= 32768 && (id.includes('8b') || id.includes('7b'))) return 'fast';

  return 'general';
}

function formatModel(model: Model, category: string) {
  return {
    id: model.id,
    name: model.name,
    category,
    context: model.context_length,
    description: model.description?.substring(0, 80) || 'No description',
  };
}

async function main() {
  const args = process.argv.slice(2);
  const categoryFilter = args.find(a => a.startsWith('--category='))?.split('=')[1];
  const minContextStr = args.find(a => a.startsWith('--min-context='))?.split('=')[1];
  const minContext = minContextStr ? parseInt(minContextStr) : 0;

  console.log('🔍 Fetching FREE models from OpenRouter...\n');

  const models = await fetchFreeModels();

  // Categorize and filter
  let categorized = models.map(m => ({
    model: m,
    category: categorizeModel(m),
    formatted: formatModel(m, categorizeModel(m)),
  }));

  if (categoryFilter) {
    categorized = categorized.filter(m => m.category === categoryFilter);
  }

  if (minContext > 0) {
    categorized = categorized.filter(m => m.model.context_length >= minContext);
  }

  // Group by category
  const grouped = categorized.reduce((acc, item) => {
    if (!acc[item.category]) acc[item.category] = [];
    acc[item.category].push(item.formatted);
    return acc;
  }, {} as Record<string, typeof categorized[0]['formatted'][]>);

  // Sort categories by priority
  const categoryOrder = ['reasoning', 'code', 'large-context', 'vision', 'general', 'fast'];
  const sortedCategories = Object.keys(grouped).sort((a, b) => {
    const aIndex = categoryOrder.indexOf(a);
    const bIndex = categoryOrder.indexOf(b);
    return (aIndex === -1 ? 999 : aIndex) - (bIndex === -1 ? 999 : bIndex);
  });

  // Print results
  console.log(`✅ Found ${models.length} FREE models\n`);

  if (categoryFilter || minContext > 0) {
    console.log(`📊 Filtered: ${categorized.length} models\n`);
  }

  for (const category of sortedCategories) {
    const categoryModels = grouped[category];
    console.log(`\n📂 ${category.toUpperCase()} (${categoryModels.length} models)`);
    console.log('─'.repeat(100));

    // Sort by context length (descending)
    categoryModels.sort((a, b) => b.context - a.context);

    for (const model of categoryModels.slice(0, 10)) { // Show top 10 per category
      const contextStr = `${(model.context / 1024).toFixed(0)}K`;
      console.log(`  ${model.id.padEnd(60)} ${contextStr.padStart(8)}  ${model.name}`);
    }

    if (categoryModels.length > 10) {
      console.log(`  ... and ${categoryModels.length - 10} more`);
    }
  }

  // Summary
  console.log(`\n\n📊 SUMMARY BY CATEGORY:`);
  console.log('─'.repeat(100));
  for (const [cat, models] of Object.entries(grouped)) {
    console.log(`  ${cat.padEnd(20)} ${models.length} models`);
  }

  console.log(`\n💡 Usage:`);
  console.log(`  bun run scripts/list-openrouter-free.ts --category code`);
  console.log(`  bun run scripts/list-openrouter-free.ts --min-context 100000`);
}

main().catch(console.error);
