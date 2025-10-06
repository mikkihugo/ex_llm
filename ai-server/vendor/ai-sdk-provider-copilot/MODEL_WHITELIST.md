# Copilot Model Whitelist

## How It Works

Models are defined in `src/index.ts` with an `enabled` flag:

```typescript
const ALL_COPILOT_MODELS = [
  {
    id: 'gpt-4.1',
    ...
    enabled: true,  // ✅ This model is available
  },
  {
    id: 'gpt-4o',
    ...
    enabled: false, // ❌ This model is hidden
  },
]

// Only enabled models are exported
export const COPILOT_MODELS = ALL_COPILOT_MODELS.filter(m => m.enabled);
```

## Enabling/Disabling Models

### To Enable a Model:
1. Open `src/index.ts`
2. Find the model in `ALL_COPILOT_MODELS`
3. Set `enabled: true`
4. Run `bun run build`

### To Disable a Model:
1. Open `src/index.ts`
2. Find the model in `ALL_COPILOT_MODELS`
3. Set `enabled: false`
4. Run `bun run build`

### To Add a New Model:
```typescript
{
  id: 'new-model',
  displayName: 'New Model',
  description: 'Description',
  contextWindow: 128000,
  capabilities: { completion: true, streaming: true, reasoning: true, vision: false, tools: true },
  cost: 'subscription' as const,
  subscription: 'GitHub Copilot',
  enabled: true, // Set to true to enable immediately
},
```

## Current Enabled Models

Run this to see currently enabled models:
```bash
cd ai-server/vendor/ai-sdk-provider-copilot
cat src/index.ts | grep -A 10 "enabled: true"
```

Or check the server:
```bash
curl http://localhost:3000/v1/models | jq '.data[] | select(.id | startswith("copilot-"))'
```

## Why Whitelist?

- **Control**: Only expose models you want to use
- **Testing**: Disable models during testing/debugging
- **Quota Management**: Hide models with limited quotas
- **Feature Flags**: Gradually roll out new models
- **Cost Control**: Disable expensive models

## Example Use Cases

### Development: Only Use Free Models
```typescript
{
  id: 'gpt-4.1',
  enabled: false, // Disable paid model in dev
},
{
  id: 'grok-coder-1',
  enabled: true,  // Enable for testing
},
```

### Production: Enable All
```typescript
{
  id: 'gpt-4.1',
  enabled: true,
},
{
  id: 'grok-coder-1',
  enabled: true,
},
```

### Testing New Model
```typescript
{
  id: 'experimental-model',
  enabled: process.env.ENABLE_EXPERIMENTAL === 'true', // Environment-based
},
```

## Environment-Based Filtering

You can also filter based on environment:

```typescript
const ALL_COPILOT_MODELS = [
  {
    id: 'gpt-4.1',
    enabled: true,
    environments: ['development', 'production'], // Metadata
  },
  {
    id: 'experimental',
    enabled: true,
    environments: ['development'], // Dev only
  },
];

// Filter by environment
const currentEnv = process.env.NODE_ENV || 'development';
export const COPILOT_MODELS = ALL_COPILOT_MODELS.filter(
  m => m.enabled && (!m.environments || m.environments.includes(currentEnv))
);
```

## Notes

- Changes require rebuild: `bun run build`
- Server automatically picks up changes (restart server)
- Single source of truth in provider package
- No server code changes needed!
