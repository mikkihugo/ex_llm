/**
 * GitHub Copilot Provider
 *
 * AI SDK provider factory for GitHub Copilot.
 */

import { CopilotLanguageModel, type CopilotModelConfig } from './copilot-language-model';

export interface CopilotProvider {
  (modelId: string, config?: CopilotModelConfig): CopilotLanguageModel;
  languageModel(modelId: string, config?: CopilotModelConfig): CopilotLanguageModel;
}

export function createCopilotProvider(): CopilotProvider {
  const provider = (modelId: string, config: CopilotModelConfig = {}) => {
    return new CopilotLanguageModel(modelId, config);
  };

  provider.languageModel = (modelId: string, config: CopilotModelConfig = {}) => {
    return new CopilotLanguageModel(modelId, config);
  };

  return provider as CopilotProvider;
}

// Default export for convenience
export const copilot = createCopilotProvider();
