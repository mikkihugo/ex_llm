# AI Addon Template System

A modular, extensible system for adding AI providers to the Singularity AI Server. Supports HTTP APIs, CLI tools, OAuth, and custom authentication methods.

## 🏗️ Architecture

```
AI Addon Template System
├── ai-addon-template.ts     # Base template interface
├── addon-registry.ts        # Centralized addon management
├── github-models-addon.ts   # GitHub Models implementation
└── [your-addon].ts         # Your custom addon
```

## 🚀 Quick Start

### 1. Create a New Addon

```typescript
import { AIAddonTemplate, AIAddonConfig } from './ai-addon-template';

const myAddonConfig: AIAddonConfig = {
  name: 'My AI Provider',
  version: '1.0.0',
  provider: 'my-provider',
  description: 'Custom AI provider integration',
  models: [
    {
      id: 'my-model',
      name: 'My Model',
      contextWindow: 4096,
      capabilities: ['completion']
    }
  ],
  auth: {
    type: 'api_key',
    envVars: ['MY_API_KEY'],
    setupInstructions: 'Set MY_API_KEY environment variable'
  },
  capabilities: {
    completion: true,
    streaming: false,
    reasoning: false,
    vision: false
  }
};

export class MyAddon extends AIAddonTemplate {
  constructor() {
    super(myAddonConfig);
  }

  async chat(messages: any[], options: any = {}): Promise<AIResponse> {
    // Implement your chat logic here
    const response = await fetch('https://api.myprovider.com/chat', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.MY_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ messages, ...options })
    });

    const data = await response.json();
    return {
      text: data.response,
      usage: data.usage,
      finishReason: data.finish_reason,
      model: options.model || 'my-model'
    };
  }
}
```

### 2. Register Your Addon

```typescript
import { addonRegistry } from './addon-registry';
import { MyAddon } from './my-addon';

const myAddon = new MyAddon();
addonRegistry.register(myAddon);

// Initialize all addons
await addonRegistry.initializeAll();
```

### 3. Use Your Addon

```typescript
// Chat with your addon
const response = await addonRegistry.chat('my-provider', messages, {
  model: 'my-model',
  temperature: 0.7
});

// Stream (if supported)
for await (const chunk of addonRegistry.stream('my-provider', messages)) {
  console.log(chunk.text);
}
```

## 📦 Pre-built Addons

### GitHub Models Addon

```typescript
import { githubModelsAddon } from './github-models-addon';

// Already integrated with Vercel AI SDK
const response = await githubModelsAddon.chat(messages, {
  model: 'gpt-4o-mini'
});
```

### GitHub Copilot Addons

```typescript
import { copilotAPIAddon, copilotCLIAddon } from './copilot-addon';

// API version (recommended)
const apiResponse = await copilotAPIAddon.chat(messages, {
  model: 'copilot-gpt-4.1'
});

// CLI version (fallback)
const cliResponse = await copilotCLIAddon.chat(messages, {
  model: 'copilot-cli-gpt-4.1'
});
```

## 🔧 Supported Authentication Types

- **`api_key`**: Simple API key authentication
- **`oauth`**: OAuth 2.0 flow with token refresh
- **`cli_token`**: CLI tool authentication (e.g., Claude, Cursor)
- **`adc`**: Application Default Credentials (Google Cloud)

## 🎯 Addon Capabilities

- **Completion**: Text generation
- **Streaming**: Real-time response streaming
- **Reasoning**: Advanced reasoning capabilities
- **Vision**: Image understanding

## 📊 Registry Features

- **Dynamic Loading**: Load addons from configuration
- **Health Checks**: Validate authentication and connectivity
- **Unified Interface**: Consistent API across all providers
- **Statistics**: Track usage and performance

## 🛠️ Development

### Creating a New Addon

1. **Extend `AIAddonTemplate`** for basic functionality
2. **Implement required methods**: `chat()`, `validateAuth()`
3. **Add authentication logic** in `initialize()`
4. **Register with the registry**

### Testing Your Addon

```typescript
// Test authentication
const isValid = await myAddon.validateAuth();

// Test chat functionality
const response = await myAddon.chat([
  { role: 'user', content: 'Hello!' }
]);
```

## 📋 Configuration

Create `addon-config.json`:

```json
[
  {
    "provider": "github-models",
    "enabled": true,
    "config": {
      "apiKey": "your-github-token"
    }
  },
  {
    "provider": "my-provider",
    "enabled": true,
    "config": {
      "apiKey": "your-api-key"
    }
  }
]
```

## 🚀 Integration with AI Server

The addon system integrates seamlessly with the existing AI server:

```typescript
// In server.ts
import { addonRegistry, setupCommonAddons } from './templates/addon-registry';

// Initialize addons
await setupCommonAddons();

// Use in chat endpoint
const response = await addonRegistry.chat(request.provider, request.messages, request);
```

## 📈 Benefits

- **🔄 Reusable**: Drop-in templates for new providers
- **🔒 Secure**: Standardized authentication handling
- **📏 Scalable**: Easy to add new providers
- **🎛️ Configurable**: Runtime configuration and feature flags
- **🧪 Testable**: Isolated testing of individual addons
- **📊 Observable**: Built-in metrics and logging

This template system makes it trivial to add new AI providers to your projects! 🎉