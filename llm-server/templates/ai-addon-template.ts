/**
 * AI Addon Template
 *
 * Reusable template for adding new AI providers to the Singularity AI Server.
 * Supports both HTTP API and CLI-based providers with standardized interfaces.
 */

export interface AIAddonConfig {
  name: string;
  version: string;
  provider: string;
  description: string;
  models?: AIModel[]; // Optional static models
  modelDiscovery?: ModelDiscoveryConfig; // Optional dynamic discovery
  auth: {
    type: 'api_key' | 'oauth' | 'cli_token' | 'adc';
    envVars: string[];
    setupInstructions: string;
  };
  capabilities: {
    completion: boolean;
    streaming: boolean;
    reasoning: boolean;
    vision: boolean;
  };
}

export interface ModelDiscoveryConfig {
  type: 'api' | 'cli' | 'static' | 'hybrid';
  endpoint?: string; // For API-based discovery
  command?: string; // For CLI-based discovery
  cache?: {
    enabled: boolean;
    ttl: number; // Time to live in milliseconds
  };
  fallbackModels?: AIModel[]; // Fallback if discovery fails
}

export interface AIModel {
  id: string;
  name: string;
  contextWindow: number;
  pricing?: {
    input: number; // per 1K tokens
    output: number; // per 1K tokens
  };
  capabilities: string[];
}

export interface AIAddon {
  config: AIAddonConfig;
  initialize: (config: any) => Promise<void>;
  chat: (messages: any[], options?: any) => Promise<AIResponse>;
  stream?: (messages: any[], options?: any) => AsyncIterable<AIResponse>;
  validateAuth: () => Promise<boolean>;
}

export interface AIResponse {
  text: string;
  usage: {
    promptTokens: number;
    completionTokens: number;
    totalTokens: number;
  };
  finishReason: string;
  model: string;
}

// Template implementation
export class AIAddonTemplate implements AIAddon {
  constructor(public config: AIAddonConfig) {}

  async initialize(config: any): Promise<void> {
    // Validate configuration
    this.validateConfig(config);

    // Setup authentication
    await this.setupAuth(config);

    // Initialize provider-specific setup
    await this.initializeProvider(config);
  }

  async chat(messages: any[], options: any = {}): Promise<AIResponse> {
    throw new Error('chat() method must be implemented by addon');
  }

  async validateAuth(): Promise<boolean> {
    // Check if required environment variables are set
    return this.config.auth.envVars.every(envVar =>
      process.env[envVar] !== undefined
    );
  }

  private validateConfig(config: any): void {
    if (!config.apiKey && !config.token) {
      throw new Error(`Missing authentication for ${this.config.name}`);
    }
  }

  private async setupAuth(config: any): Promise<void> {
    // Provider-specific auth setup
    switch (this.config.auth.type) {
      case 'api_key':
        this.setupApiKeyAuth(config);
        break;
      case 'oauth':
        await this.setupOAuth(config);
        break;
      case 'cli_token':
        this.setupCliTokenAuth(config);
        break;
      case 'adc':
        this.setupADCAuth(config);
        break;
    }
  }

  private setupApiKeyAuth(config: any): void {
    // Store API key securely
    process.env[`${this.config.provider.toUpperCase()}_API_KEY`] = config.apiKey;
  }

  private async setupOAuth(config: any): Promise<void> {
    // Handle OAuth flow
    throw new Error('OAuth setup not implemented in template');
  }

  private setupCliTokenAuth(config: any): void {
    // Handle CLI token storage
    throw new Error('CLI token setup not implemented in template');
  }

  private setupADCAuth(config: any): void {
    // Handle Application Default Credentials
    throw new Error('ADC setup not implemented in template');
  }

  private async initializeProvider(config: any): Promise<void> {
    // Provider-specific initialization
    // Override in concrete implementations
  }
}

// Factory function to create addons
export function createAIAddon(template: AIAddonConfig): AIAddon {
  return new AIAddonTemplate(template);
}

// Example addon configurations
export const addonTemplates = {
  'openai-compatible': {
    name: 'OpenAI Compatible',
    version: '1.0.0',
    provider: 'openai-compatible',
    description: 'Template for OpenAI-compatible APIs',
    models: [
      {
        id: 'gpt-4o',
        name: 'GPT-4o',
        contextWindow: 128000,
        capabilities: ['completion', 'vision']
      }
    ],
    auth: {
      type: 'api_key',
      envVars: ['OPENAI_API_KEY'],
      setupInstructions: 'Set OPENAI_API_KEY environment variable'
    },
    capabilities: {
      completion: true,
      streaming: true,
      reasoning: true,
      vision: true
    }
  },

  'cli-based': {
    name: 'CLI Based Provider',
    version: '1.0.0',
    provider: 'cli-based',
    description: 'Template for CLI-based AI providers',
    models: [
      {
        id: 'claude-cli',
        name: 'Claude CLI',
        contextWindow: 200000,
        capabilities: ['completion', 'reasoning']
      }
    ],
    auth: {
      type: 'cli_token',
      envVars: ['CLAUDE_TOKEN'],
      setupInstructions: 'Run: claude setup-token'
    },
    capabilities: {
      completion: true,
      streaming: false,
      reasoning: true,
      vision: false
    }
  },

  'oauth-based': {
    name: 'OAuth Based Provider',
    version: '1.0.0',
    provider: 'oauth-based',
    description: 'Template for OAuth-based AI providers',
    models: [
      {
        id: 'github-models',
        name: 'GitHub Models',
        contextWindow: 128000,
        capabilities: ['completion', 'reasoning']
      }
    ],
    auth: {
      type: 'oauth',
      envVars: ['GITHUB_TOKEN'],
      setupInstructions: 'Set GITHUB_TOKEN with GitHub Personal Access Token'
    },
    capabilities: {
      completion: true,
      streaming: false,
      reasoning: true,
      vision: false
    }
  }
};