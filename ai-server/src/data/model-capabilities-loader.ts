/**
 * Load model capability scores from disk
 *
 * Capability scores are auto-generated and persisted to model-capabilities.json
 * Run `bun run generate:capabilities` to update scores.
 */

import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

export interface ModelCapabilityScore {
  code: number;        // 1-10
  reasoning: number;   // 1-10
  creativity: number;  // 1-10
  speed: number;       // 1-10
  cost: number;        // 10=FREE, 5=quota, 1=expensive
  confidence?: 'high' | 'medium' | 'low';
  reasoning_text?: string;
}

let cachedCapabilities: Record<string, ModelCapabilityScore> | null = null;

export function loadModelCapabilities(): Record<string, ModelCapabilityScore> {
  if (cachedCapabilities) {
    return cachedCapabilities;
  }

  try {
    const capabilitiesPath = join(__dirname, 'model-capabilities.json');
    const data = readFileSync(capabilitiesPath, 'utf-8');
    cachedCapabilities = JSON.parse(data);
    return cachedCapabilities!;
  } catch (error) {
    console.warn('⚠️  Failed to load model-capabilities.json, using defaults');
    console.warn('   Run: bun run generate:capabilities');
    return {};
  }
}

export function getModelCapability(modelId: string): ModelCapabilityScore | undefined {
  const capabilities = loadModelCapabilities();
  return capabilities[modelId];
}

// Export for convenience
export const MODEL_CAPABILITIES = loadModelCapabilities();
