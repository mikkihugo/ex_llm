/**
 * Cursor Agent Provider
 *
 * AI SDK provider factory for Cursor Agent.
 */

import { CursorLanguageModel, type CursorModelConfig } from './cursor-language-model';

export interface CursorProvider {
  (modelId: string, config?: CursorModelConfig): CursorLanguageModel;
  languageModel(modelId: string, config?: CursorModelConfig): CursorLanguageModel;
}

export function createCursorProvider(): CursorProvider {
  const provider = (modelId: string, config: CursorModelConfig = {}) => {
    return new CursorLanguageModel(modelId, config);
  };

  provider.languageModel = (modelId: string, config: CursorModelConfig = {}) => {
    return new CursorLanguageModel(modelId, config);
  };

  return provider as CursorProvider;
}

// Default export for convenience
export const cursor = createCursorProvider();
