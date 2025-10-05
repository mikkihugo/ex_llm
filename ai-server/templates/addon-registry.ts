/**
 * AI Addon Registry
 *
 * Centralized registry for managing AI provider addons.
 * Supports dynamic loading, configuration, and lifecycle management.
 */

import { AIAddon, AIAddonConfig, AIResponse } from './ai-addon-template';

export interface AddonRegistryConfig {
  autoLoad: boolean;
  configPath: string;
  enabledAddons: string[];
}

export class AddonRegistry {
  private addons: Map<string, AIAddon> = new Map();
  private config: AddonRegistryConfig;

  constructor(config: Partial<AddonRegistryConfig> = {}) {
    this.config = {
      autoLoad: true,
      configPath: './addon-config.json',
      enabledAddons: [],
      ...config
    };
  }

  // Register a new addon
  register(addon: AIAddon): void {
    this.addons.set(addon.config.provider, addon);
  }

  // Unregister an addon
  unregister(provider: string): void {
    this.addons.delete(provider);
  }

  // Get addon by provider name
  getAddon(provider: string): AIAddon | undefined {
    return this.addons.get(provider);
  }

  // List all registered addons
  listAddons(): AIAddonConfig[] {
    return Array.from(this.addons.values()).map(addon => addon.config);
  }

  // Initialize all registered addons
  async initializeAll(config?: any): Promise<void> {
    const initPromises = Array.from(this.addons.values()).map(async (addon) => {
      try {
        await addon.initialize(config);
        console.log(`✅ Initialized ${addon.config.name} (${addon.config.provider})`);
      } catch (error) {
        console.error(`❌ Failed to initialize ${addon.config.name}:`, error);
      }
    });

    await Promise.allSettled(initPromises);
  }

  // Validate authentication for all addons
  async validateAllAuth(): Promise<Map<string, boolean>> {
    const results = new Map<string, boolean>();

    for (const [provider, addon] of this.addons) {
      try {
        const isValid = await addon.validateAuth();
        results.set(provider, isValid);
      } catch (error) {
        console.error(`Auth validation failed for ${provider}:`, error);
        results.set(provider, false);
      }
    }

    return results;
  }

  // Unified chat interface across all addons
  async chat(provider: string, messages: any[], options: any = {}): Promise<AIResponse> {
    const addon = this.getAddon(provider);
    if (!addon) {
      throw new Error(`Addon not found: ${provider}`);
    }

    return await addon.chat(messages, options);
  }

  // Stream interface (if supported by addon)
  async *stream(provider: string, messages: any[], options: any = {}): AsyncIterable<AIResponse> {
    const addon = this.getAddon(provider);
    if (!addon || !addon.stream) {
      throw new Error(`Streaming not supported for provider: ${provider}`);
    }

    yield* addon.stream(messages, options);
  }

  // Load addons from configuration
  async loadFromConfig(): Promise<void> {
    try {
      const configData = await import(this.config.configPath);
      const addons = configData.default || configData;

      for (const addonConfig of addons) {
        if (this.config.enabledAddons.length === 0 ||
            this.config.enabledAddons.includes(addonConfig.provider)) {
          const addon = await this.createAddonFromConfig(addonConfig);
          this.register(addon);
        }
      }
    } catch (error) {
      console.warn('Failed to load addon config:', error);
    }
  }

  private async createAddonFromConfig(config: AIAddonConfig): Promise<AIAddon> {
    // Dynamic import based on addon type
    const modulePath = `./${config.provider}-addon`;
    const addonModule = await import(modulePath);
    return addonModule.default || new addonModule[Object.keys(addonModule)[0]]();
  }

  // Get addon statistics
  getStats(): any {
    const stats = {
      totalAddons: this.addons.size,
      providers: Array.from(this.addons.keys()),
      models: {} as Record<string, string[]>
    };

    for (const [provider, addon] of this.addons) {
      stats.models[provider] = addon.config.models.map(m => m.id);
    }

    return stats;
  }
}

// Global registry instance
export const addonRegistry = new AddonRegistry();

// Helper function to create and register common addons
export async function setupCommonAddons(): Promise<void> {
  // Import and register GitHub Models
  const { githubModelsAddon } = await import('./github-models-addon');
  addonRegistry.register(githubModelsAddon);

  // Import and register GitHub Copilot addons
  const { copilotAPIAddon, copilotCLIAddon } = await import('./copilot-addon');
  addonRegistry.register(copilotAPIAddon);
  addonRegistry.register(copilotCLIAddon);

  // Initialize all addons
  await addonRegistry.initializeAll();
}

// Export types for external use
export type { AIAddon, AIAddonConfig, AIResponse };