import { CodexLanguageModel, type CodexModelConfig } from './codex-language-model';

export interface CodexProvider {
  (modelId: string, config?: CodexModelConfig): CodexLanguageModel;
  languageModel(modelId: string, config?: CodexModelConfig): CodexLanguageModel;
}

export function createCodexProvider(): CodexProvider {
  const provider = (modelId: string, config: CodexModelConfig = {}) => {
    return new CodexLanguageModel(modelId, config);
  };

  provider.languageModel = (modelId: string, config: CodexModelConfig = {}) => {
    return new CodexLanguageModel(modelId, config);
  };

  return provider as CodexProvider;
}

// Default export for convenience
export const codex = createCodexProvider();
