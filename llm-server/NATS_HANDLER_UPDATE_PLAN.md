# NATS Handler Integration Plan

**Target File**: `src/nats-handler.ts`
**Status**: Ready for update
**Effort**: 2-3 hours (Day 3)

## Overview

Update existing NATS handler to use new type-safe modules:
- ✅ types.ts (type definitions)
- ✅ error-formatter.ts (error handling)
- ✅ nats-publisher.ts (NATS messaging)
- ✅ credential-validator.ts (API key validation)

## Changes Required

### 1. Update Imports (Lines 1-25)

**Current**:
```typescript
import { generateText, streamText } from 'ai';
import { createGeminiProvider } from './providers/gemini-code';
// ... other imports
```

**Add New Imports**:
```typescript
// Type safety
import type {
  LLMRequest,
  LLMResponse,
  LLMError,
  TaskType,
  TaskComplexity,
  ProviderKey,
  ErrorCode
} from './types';
import { isValidLLMRequest } from './types';

// Error handling
import {
  StandardAPIError,
  ValidationError as APIValidationError,
  ProviderError,
  TimeoutError,
  formatError,
  extractErrorCode
} from './error-formatter';

// NATS publisher
import { SafeNATSPublisher, createPublisher } from './nats-publisher';

// Credential validation
import {
  isProviderAvailable,
  validateAllProviders,
  logCredentialStatus
} from './credential-validator';
```

### 2. Remove Duplicate Type Definitions (Lines 27-86)

**Current** (DELETE THESE):
```typescript
type TaskType = 'general' | 'architect' | 'coder' | 'qa';
type CapabilityHint = 'code' | 'reasoning' | 'creativity' | 'speed' | 'cost';
interface LLMRequest { ... }
interface LLMResponse { ... }
interface LLMError { ... }
class ValidationError extends Error { ... }
class ProviderNotFoundError extends Error { ... }
```

These are now defined in `src/types.ts` and imported above.

### 3. Update NATSHandler Class (Lines 147-152)

**Current**:
```typescript
class NATSHandler {
  private nc: NatsConnection | null = null;
  private subscriptions: Subscription[] = [];
  private subscriptionTasks: Promise<void>[] = [];
  private processingCount: number = 0;
  private readonly MAX_CONCURRENT = 10;
```

**Add**:
```typescript
class NATSHandler {
  private nc: NatsConnection | null = null;
  private subscriptions: Subscription[] = [];
  private subscriptionTasks: Promise<void>[] = [];
  private processingCount: number = 0;
  private readonly MAX_CONCURRENT = 10;
  private publisher: SafeNATSPublisher | null = null;  // ← ADD THIS
```

### 4. Update connect() Method (Lines 157-168)

**Current**:
```typescript
async connect() {
  try {
    this.nc = await connect({
      servers: process.env.NATS_URL || 'nats://localhost:4222'
    });
    console.log('[NATS] Connected to NATS');
    await this.subscribeToLLMRequests();
  } catch (error) {
    console.error('[NATS] Failed to connect:', error);
    throw error;
  }
}
```

**Update To**:
```typescript
async connect() {
  try {
    // Validate credentials before connecting
    logCredentialStatus();

    this.nc = await connect({
      servers: process.env.NATS_URL || 'nats://localhost:4222'
    });
    this.publisher = createPublisher(this.nc);

    logger.info('[NATS] Connected to NATS', {
      url: process.env.NATS_URL || 'nats://localhost:4222'
    });

    await this.subscribeToLLMRequests();
  } catch (error) {
    logger.error('[NATS] Failed to connect', {
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined
    });
    throw error;
  }
}
```

### 5. Update handleSingleLLMRequest() (Lines 200-241)

**Current** (REPLACE ENTIRE METHOD):
```typescript
private async handleSingleLLMRequest(msg: any) {
  let request: LLMRequest | null = null;
  const startTime = Date.now();
  try {
    request = JSON.parse(msg.data.toString()) as LLMRequest;
    this.validateRequest(request);
    // ... rest of method
  } catch (error) {
    // ... error handling
  }
}
```

**Replace With**:
```typescript
private async handleSingleLLMRequest(msg: any): Promise<void> {
  let request: LLMRequest | null = null;
  const startTime = Date.now();

  try {
    // ──── Step 1: Parse JSON ────
    let parsedData: unknown;
    try {
      parsedData = JSON.parse(msg.data.toString());
    } catch (parseError) {
      throw new APIValidationError(
        `Invalid JSON in request: ${parseError instanceof Error ? parseError.message : 'parse error'}`
      );
    }

    // ──── Step 2: Validate schema ────
    if (!isValidLLMRequest(parsedData)) {
      throw new APIValidationError('Request does not match LLMRequest schema');
    }
    request = parsedData;

    logger.info('[NATS] Received LLM request', {
      model: request.model,
      taskType: request.task_type,
      correlationId: request.correlation_id
    });

    // ──── Step 3: Process with timeout (30s max) ────
    const response = await Promise.race([
      this.processLLMRequest(request),
      this.createTimeoutPromise(30000)
    ]);

    // ──── Step 4: Publish response safely ────
    if (!this.publisher) {
      logger.error('[NATS] Publisher not initialized');
      return;
    }

    if (msg.reply) {
      await this.publisher.publishToReply(msg.reply, response);
    } else {
      await this.publisher.publishResponse('llm.response', response);
    }

    // ──── Step 5: Record metrics ────
    const duration = Date.now() - startTime;
    metrics.recordRequest('nats_llm_request', duration, false);
    if (response.model) {
      const [provider, model] = response.model.split(':');
      metrics.recordModelUsage(provider || 'unknown', model || response.model, response.tokens_used);
    }

    logger.info('[NATS] LLM request completed', {
      model: response.model,
      duration: `${duration}ms`,
      correlationId: request.correlation_id
    });

  } catch (error) {
    // ──── Step 6: Handle errors safely ────
    const duration = Date.now() - startTime;
    metrics.recordRequest('nats_llm_request', duration, true);

    logger.error('[NATS] Error processing LLM request', {
      error: error instanceof Error ? error.message : String(error),
      correlationId: request?.correlation_id,
      stack: error instanceof Error ? error.stack : undefined
    });

    // Format error consistently
    const lmmError = formatError(error, request?.correlation_id);

    // Publish error safely
    if (!this.publisher) {
      logger.error('[NATS] Cannot publish error - publisher not initialized');
      return;
    }

    if (msg.reply) {
      await this.publisher.publishToReply(msg.reply, lmmError);
    } else {
      await this.publisher.publishError('llm.error', lmmError);
    }
  }
}
```

### 6. Replace validateRequest() with credential checks

**Delete** (Lines 243-251):
```typescript
private validateRequest(request: LLMRequest) {
  if (!request || typeof request !== 'object') throw new ValidationError('Request payload must be an object');
  // ... all validation logic
}
```

Replace with credential checking in model selection:

### 7. Update resolveModelSelection() (Lines 280-294)

**Add credential check after model selection**:
```typescript
private resolveModelSelection(request: LLMRequest): { model: string; provider: ProviderKey; complexity: TaskComplexity } {
  const providerHint = request.provider ? this.normalizeProvider(request.provider) : null;

  if (request.model && request.model !== 'auto') {
    const provider = providerHint ?? this.getProviderFromModel(request.model);
    if (!provider) throw new ProviderError('model_selection', `Unable to determine provider for model: ${request.model}`);

    // ← ADD THIS: Check if provider has credentials
    if (!isProviderAvailable(provider as ProviderKey)) {
      const missing = getMissingCredentials(provider as ProviderKey);
      throw new ProviderError(
        provider,
        `Provider ${provider} not available. Missing credentials: ${missing.join(', ')}`
      );
    }

    const complexity = request.complexity ?? this.inferComplexity(request, this.taskTypeFromRequest(request));
    return { model: request.model, provider: provider as ProviderKey, complexity };
  }

  // For auto-selection, find an available provider
  const taskType = this.taskTypeFromRequest(request);
  const complexity = request.complexity ?? this.inferComplexity(request, taskType);
  const candidates = this.getModelCandidates(taskType, complexity, providerHint as ProviderKey | null, request.capabilities);

  // Filter to only available providers
  const available = candidates.filter(c => isProviderAvailable(c.provider));
  if (available.length === 0) {
    throw new ProviderError(
      'auto_select',
      `No models available for task_type=${taskType} complexity=${complexity}. Check credential status.`
    );
  }

  const choice = available[0];
  return { model: choice.model, provider: choice.provider, complexity };
}
```

### 8. Add Timeout Helper Method

**Add to class** (after handleNonStreamingRequest):
```typescript
private createTimeoutPromise(ms: number): Promise<LLMResponse> {
  return new Promise((_, reject) => {
    setTimeout(() => {
      reject(new TimeoutError(ms));
    }, ms);
  });
}
```

### 9. Update extractErrorCode() method

**Current** (if exists):
```typescript
private extractErrorCode(error: any): string {
  // ... custom logic
}
```

**Replace with** (use new function):
```typescript
// DELETE this method - use formatError() instead which calls extractErrorCode
```

The `formatError()` function from error-formatter.ts already extracts codes properly.

### 10. Remove Custom Error Classes

**Delete**:
```typescript
class ValidationError extends Error { ... }
class ProviderNotFoundError extends Error { ... }
```

**Use instead**:
- `APIValidationError` (from error-formatter.ts)
- `ProviderError` (from error-formatter.ts)

## Summary of Changes

| Item | Lines | Change | Impact |
|------|-------|--------|--------|
| Imports | 1-25 | Add new imports | Enables type safety |
| Type defs | 27-86 | Delete (use types.ts) | Removes duplication |
| Class props | 147-152 | Add publisher | Safe NATS publishing |
| connect() | 157-168 | Add credential check | Startup validation |
| handleSingleLLMRequest() | 200-241 | Complete rewrite | Type-safe error handling |
| validateRequest() | 243-251 | Delete | Use schema validator |
| resolveModelSelection() | 280-294 | Add credential check | Graceful degradation |
| extractErrorCode() | Unknown | Delete | Use formatError() |
| Custom errors | Various | Delete/replace | Use StandardAPIError subclasses |

## Testing Strategy

After updates, verify:

1. **Type Checking**
   ```bash
   bunx tsc --noEmit src/nats-handler.ts
   ```
   Should show 0 errors

2. **Runtime Test**
   ```bash
   # Create a test request
   bun run src/test-nats-handler.ts
   ```

3. **Integration Test**
   ```bash
   bun test src/__tests__/nats-handler.test.ts
   ```

## Rollback Plan

If issues arise:
```bash
git checkout src/nats-handler.ts
```

Then debug issues and reapply changes.

## Time Estimate

- Reading/understanding current code: 30 min
- Making changes: 90 min
- Testing/debugging: 60 min
- **Total**: 2.5-3 hours
