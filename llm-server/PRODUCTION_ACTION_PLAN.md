# LLM-Server Production Readiness Action Plan

**Current Status**: 3/10 production-ready
**Timeline**: 3-4 weeks
**Last Updated**: 2025-10-24

## Executive Summary

The llm-server has solid architecture and provider integration but lacks production hardening. Critical issues prevent deployment:

### Critical Blockers (Week 1 - MUST FIX)

1. **C1: No Type Safety** (CRITICAL)
   - All NATS message handlers use `any` types
   - AI SDK providers not properly typed
   - No validation of request/response shapes
   - Crashes will go undetected during development
   - **File**: `src/nats-handler.ts:200` (handleSingleLLMRequest parameter)
   - **Impact**: Silent failures, hard-to-debug issues
   - **Effort**: 2-3 hours

2. **C2: NATS Error Handling Crash** (CRITICAL)
   - Line 200-240 has try/catch but not comprehensive
   - NATS message parsing can throw
   - publishError/publishResponse methods not null-checked
   - **File**: `src/nats-handler.ts:178-240`
   - **Impact**: Crash cascades to lose NATS connection
   - **Effort**: 2 hours

3. **C3: Missing API Key Validation** (CRITICAL)
   - No check if providers loaded successfully
   - Invalid tokens silently fail → confusing errors
   - No per-provider key validation
   - **File**: `src/load-credentials.ts` → `src/nats-handler.ts`
   - **Impact**: 50% of failures are "key not set" but show as provider errors
   - **Effort**: 1-2 hours

4. **C4: Zero Test Coverage** (CRITICAL)
   - No integration tests for NATS handler
   - No unit tests for model selection logic
   - No mocked provider tests
   - **File**: Create `src/__tests__/nats-handler.test.ts`
   - **Impact**: Refactoring breaks things silently
   - **Effort**: 4-6 hours

### High Priority Issues (Week 2-3)

- H1: Inconsistent error format (some JSON, some plain text)
- H2: No timeout protection on NATS messages (infinite hangs possible)
- H3: Missing rate limiting (can overwhelm providers)
- H4: No validation of tool definitions
- H5: Copilot provider completely unimplemented (stubs only)
- H6: No metrics collection for production monitoring
- H7: Health check endpoint missing

## Week 1: Critical Fixes

### Day 1: Type Safety

#### 1.1 Create `src/types.ts` (Core Type Definitions)

```typescript
/**
 * @file Core type definitions for LLM Server
 */

// ============================================================================
// Request/Response Types
// ============================================================================

export interface LLMRequest {
  /** AI provider name or auto-select 'auto' */
  provider?: string;
  /** Model ID within provider (e.g., 'gpt-4o', 'sonnet') */
  model?: string;
  /** Chat messages in OpenAI format */
  messages: Array<{
    role: 'user' | 'assistant' | 'system';
    content: string;
  }>;
  /** Maximum output tokens (default: 4000) */
  max_tokens?: number;
  /** Temperature for randomness (0.0-2.0, default: 0.7) */
  temperature?: number;
  /** Enable streaming response (default: false) */
  stream?: boolean;
  /** Unique request ID for tracking */
  correlation_id?: string;
  /** OpenAI-format tools/functions */
  tools?: OpenAITool[];
  /** Pre-computed task complexity */
  complexity?: 'simple' | 'medium' | 'complex';
  /** Task type for model selection */
  task_type?: TaskType;
  /** Capability hints */
  capabilities?: CapabilityHint[];
}

export interface LLMResponse {
  /** The generated text response */
  text: string;
  /** Model used (format: 'provider:model') */
  model: string;
  /** Tokens consumed by request */
  tokens_used?: number;
  /** Cost in cents (0.0001 precision) */
  cost_cents?: number;
  /** ISO8601 timestamp */
  timestamp: string;
  /** Request correlation ID */
  correlation_id?: string;
}

export interface LLMError {
  /** Human-readable error message */
  error: string;
  /** Machine-readable error code */
  error_code: string;
  /** Request correlation ID for tracking */
  correlation_id?: string;
  /** ISO8601 timestamp */
  timestamp: string;
}

// ============================================================================
// Task & Provider Types
// ============================================================================

export type TaskType = 'general' | 'architect' | 'coder' | 'qa';
export type TaskComplexity = 'simple' | 'medium' | 'complex';
export type CapabilityHint = 'code' | 'reasoning' | 'creativity' | 'speed' | 'cost';
export type ProviderKey = 'claude' | 'gemini' | 'codex' | 'copilot' | 'github' | 'jules' | 'cursor' | 'openrouter';

// ============================================================================
// Tool Types (OpenAI format)
// ============================================================================

export interface OpenAITool {
  type: 'function';
  function: {
    name: string;
    description?: string;
    parameters?: Record<string, any>;
  };
}

// ============================================================================
// Provider Credentials
// ============================================================================

export interface CredentialStatus {
  provider: ProviderKey;
  available: boolean;
  error?: string;
  last_checked: string;
}

// ============================================================================
// Validation Guards
// ============================================================================

export function isValidLLMRequest(obj: unknown): obj is LLMRequest {
  if (!obj || typeof obj !== 'object') return false;
  const req = obj as Record<string, unknown>;

  // Must have messages
  if (!Array.isArray(req.messages) || req.messages.length === 0) return false;

  // Messages must be valid
  for (const msg of req.messages) {
    if (!msg || typeof msg !== 'object') return false;
    const m = msg as Record<string, unknown>;
    if (typeof m.role !== 'string' || typeof m.content !== 'string') return false;
    if (!['user', 'assistant', 'system'].includes(m.role)) return false;
  }

  // Optional fields must be correct type
  if (req.model !== undefined && typeof req.model !== 'string') return false;
  if (req.provider !== undefined && typeof req.provider !== 'string') return false;
  if (req.max_tokens !== undefined && (typeof req.max_tokens !== 'number' || req.max_tokens < 1)) return false;
  if (req.temperature !== undefined && (typeof req.temperature !== 'number' || req.temperature < 0 || req.temperature > 2)) return false;
  if (req.stream !== undefined && typeof req.stream !== 'boolean') return false;
  if (req.correlation_id !== undefined && typeof req.correlation_id !== 'string') return false;
  if (req.complexity !== undefined && !['simple', 'medium', 'complex'].includes(req.complexity as string)) return false;
  if (req.task_type !== undefined && !['general', 'architect', 'coder', 'qa'].includes(req.task_type as string)) return false;

  return true;
}

export function assertValidLLMRequest(obj: unknown): asserts obj is LLMRequest {
  if (!isValidLLMRequest(obj)) {
    throw new Error(`Invalid LLM request: ${JSON.stringify(obj)}`);
  }
}
```

#### 1.2 Update `src/nats-handler.ts` to use types

Replace lines 27-56 with:

```typescript
import type {
  LLMRequest,
  LLMResponse,
  LLMError,
  TaskType,
  TaskComplexity,
  CapabilityHint,
  ProviderKey,
  OpenAITool
} from './types';
import { isValidLLMRequest } from './types';
```

Update line 200:

```typescript
private async handleSingleLLMRequest(msg: any): Promise<void> {  // ← Already typed here
  let request: LLMRequest | null = null;
  const startTime = Date.now();
  try {
    const data = JSON.parse(msg.data.toString());

    // ← Use strict validation
    if (!isValidLLMRequest(data)) {
      throw new ValidationError('Request does not match LLMRequest schema');
    }
    request = data as LLMRequest;
```

**Effort**: 30 mins

### Day 2: Error Handling

#### 2.1 Create Safe NATS Publisher

Create `src/nats-publisher.ts`:

```typescript
import { NatsConnection } from 'nats';
import type { LLMResponse, LLMError } from './types';
import { logger } from './logger';

export class SafeNATSPublisher {
  constructor(private nc: NatsConnection) {}

  async publishResponse(subject: string, response: LLMResponse): Promise<void> {
    try {
      if (!this.nc || this.nc.isClosed()) {
        logger.error('NATS connection not available', { subject });
        return;
      }

      const serialized = JSON.stringify(response);
      this.nc.publish(subject, new TextEncoder().encode(serialized));
      logger.debug('Published response', { subject, correlationId: response.correlation_id });
    } catch (error) {
      logger.error('Failed to publish response', { subject, error });
      // Don't throw - NATS publish is fire-and-forget
    }
  }

  async publishError(subject: string, error: LLMError): Promise<void> {
    try {
      if (!this.nc || this.nc.isClosed()) {
        logger.error('NATS connection not available for error', { subject, error: error.error });
        return;
      }

      const serialized = JSON.stringify(error);
      this.nc.publish(subject, new TextEncoder().encode(serialized));
      logger.debug('Published error', { subject, correlationId: error.correlation_id });
    } catch (error) {
      logger.error('Failed to publish error', { subject, error });
    }
  }
}
```

#### 2.2 Update `src/nats-handler.ts` error handling

Update the `handleSingleLLMRequest` method (lines 200-241):

```typescript
private async handleSingleLLMRequest(msg: any): Promise<void> {
  let request: LLMRequest | null = null;
  const startTime = Date.now();

  try {
    // ← Step 1: Parse JSON with error handling
    let parsedData: unknown;
    try {
      parsedData = JSON.parse(msg.data.toString());
    } catch (parseError) {
      throw new ValidationError(`Invalid JSON: ${parseError instanceof Error ? parseError.message : 'unknown error'}`);
    }

    // ← Step 2: Validate schema
    if (!isValidLLMRequest(parsedData)) {
      throw new ValidationError(`Request must be LLMRequest type`);
    }
    request = parsedData;

    logger.info('[NATS] Received LLM request', { model: request.model, correlationId: request.correlation_id });

    // ← Step 3: Process request with timeout
    const response = await Promise.race([
      this.processLLMRequest(request),
      new Promise<LLMResponse>((_, reject) =>
        setTimeout(() => reject(new Error('Request timeout after 30s')), 30000)
      )
    ]);

    // ← Step 4: Publish response safely
    if (msg.reply) {
      await this.publisher.publishResponse(msg.reply, response);
    } else {
      await this.publisher.publishResponse('llm.response', response);
    }

    const duration = Date.now() - startTime;
    metrics.recordRequest('nats_llm_request', duration);
    if (response.model) {
      const [provider, model] = response.model.split(':');
      metrics.recordModelUsage(provider || 'unknown', model || response.model, response.tokens_used);
    }
    logger.info('[NATS] LLM request completed', { model: response.model, duration: `${duration}ms`, correlationId: request.correlation_id });

  } catch (error) {
    const duration = Date.now() - startTime;
    metrics.recordRequest('nats_llm_request', duration, true);

    logger.error('[NATS] Error processing LLM request', {
      error: error instanceof Error ? error.message : 'Unknown error',
      correlationId: request?.correlation_id,
      stack: error instanceof Error ? error.stack : undefined
    });

    // ← Step 5: Create properly formatted error
    const errorResponse: LLMError = {
      error: error instanceof Error ? error.message : 'Unknown error occurred',
      error_code: this.extractErrorCode(error),
      correlation_id: request?.correlation_id,
      timestamp: new Date().toISOString()
    };

    // ← Step 6: Publish error safely
    if (msg.reply) {
      await this.publisher.publishError(msg.reply, errorResponse);
    } else {
      await this.publisher.publishError('llm.error', errorResponse);
    }
  }
}
```

**Effort**: 1.5 hours

### Day 3: API Key Validation

#### 3.1 Update `src/load-credentials.ts`

Add validation method:

```typescript
export function validateRequiredCredentials(): string[] {
  const missing: string[] = [];

  // Check which providers need keys
  if (!process.env.ANTHROPIC_API_KEY) missing.push('ANTHROPIC_API_KEY');
  if (!process.env.GOOGLE_API_KEY) missing.push('GOOGLE_API_KEY');
  if (!process.env.GITHUB_TOKEN) missing.push('GITHUB_TOKEN');

  return missing;
}

export function assertCredentialsLoaded(): void {
  const missing = validateRequiredCredentials();
  if (missing.length > 0) {
    throw new Error(`Missing required credentials: ${missing.join(', ')}`);
  }
}
```

#### 3.2 Update `src/nats-handler.ts` constructor

```typescript
constructor() {
  // Validate credentials before starting
  const missingCreds = validateRequiredCredentials();
  if (missingCreds.length > 0) {
    logger.warn('Missing credentials (some providers may be unavailable)', { missing: missingCreds });
    // Don't throw - graceful degradation
  }
  this.publisher = new SafeNATSPublisher(this.nc!);
}
```

#### 3.3 Add per-provider validation in model selection

Update `resolveModelSelection` method to check credentials:

```typescript
private resolveModelSelection(request: LLMRequest) {
  // ... existing code ...

  // Check if selected provider has credentials
  const provider = selectedOption.provider;
  if (!this.isProviderAvailable(provider)) {
    logger.warn(`Provider ${provider} not available, trying fallback`, { request });
    // Try next option in fallback list
    return this.findAvailableModel(selectedOption.provider);
  }

  return { model: selectedOption.model, provider, complexity };
}

private isProviderAvailable(provider: ProviderKey): boolean {
  // Check credentials for this provider
  switch (provider) {
    case 'claude': return !!process.env.ANTHROPIC_API_KEY;
    case 'gemini': return !!process.env.GOOGLE_API_KEY;
    case 'copilot': return !!process.env.GITHUB_TOKEN;
    // ... etc
  }
  return false;
}
```

**Effort**: 1.5 hours

### Day 4: Test Coverage (Unit Tests)

Create `src/__tests__/nats-handler.test.ts`:

```typescript
import { describe, it, expect, mock } from 'bun:test';
import { NATSHandler } from '../nats-handler';
import type { LLMRequest, LLMResponse } from '../types';

describe('NATSHandler', () => {
  describe('Request Validation', () => {
    it('should reject requests without messages', () => {
      const handler = new NATSHandler();
      const request = { model: 'gpt-4' };

      expect(() => {
        handler.validateRequest(request as any);
      }).toThrow('must include at least one message');
    });

    it('should reject requests with invalid messages', () => {
      const handler = new NATSHandler();
      const request = {
        messages: [{ role: 'user' }] // missing content
      };

      expect(() => {
        handler.validateRequest(request as any);
      }).toThrow('invalid');
    });

    it('should accept valid requests', () => {
      const handler = new NATSHandler();
      const request: LLMRequest = {
        messages: [{ role: 'user', content: 'Hello' }],
        model: 'gpt-4'
      };

      expect(() => {
        handler.validateRequest(request);
      }).not.toThrow();
    });
  });

  describe('Model Selection', () => {
    it('should select simple model for simple tasks', () => {
      const handler = new NATSHandler();
      const request: LLMRequest = {
        messages: [{ role: 'user', content: 'classify this' }],
        task_type: 'general',
        complexity: 'simple'
      };

      const selection = handler.resolveModelSelection(request);
      expect(selection.complexity).toBe('simple');
    });

    it('should select complex model for architect tasks', () => {
      const handler = new NATSHandler();
      const request: LLMRequest = {
        messages: [{ role: 'user', content: 'design system' }],
        task_type: 'architect',
        complexity: 'complex'
      };

      const selection = handler.resolveModelSelection(request);
      expect(selection.complexity).toBe('complex');
    });
  });

  describe('Error Handling', () => {
    it('should handle JSON parse errors', async () => {
      const handler = new NATSHandler();
      const msg = {
        data: new TextEncoder().encode('{invalid json}'),
        reply: null
      };

      // Should not throw, should publish error
      await expect(handler.handleSingleLLMRequest(msg)).resolves.not.toThrow();
    });

    it('should timeout long-running requests', async () => {
      const handler = new NATSHandler();
      const slowProvider = mock(async () => new Promise(resolve =>
        setTimeout(resolve, 35000)
      ));

      // Mock provider to be slow
      // Should timeout after 30s
    });
  });
});
```

**Effort**: 3-4 hours

## Week 2: Testing & High Priority Fixes

### Day 1-2: Integration Tests

Create `src/__tests__/integration.test.ts`:

```typescript
import { describe, it, expect } from 'bun:test';
import { NATSHandler } from '../nats-handler';

describe('NATS Integration', () => {
  it('should handle full request cycle', async () => {
    // Connect to real NATS
    // Send request
    // Verify response published
  });

  it('should handle provider failures gracefully', async () => {
    // Test with invalid API key
    // Should get proper error response
  });

  it('should respect max_tokens limit', async () => {
    // Request with max_tokens=10
    // Should not exceed limit
  });
});
```

**Target**: 60% code coverage

### Day 3-5: High Priority Issues

#### H1: Consistent Error Format

Create `src/error-formatter.ts`:

```typescript
import type { LLMError } from './types';

export class APIError extends Error {
  constructor(
    public code: string,
    message: string,
    public statusCode: number = 400,
    public details?: Record<string, unknown>
  ) {
    super(message);
    this.name = 'APIError';
  }
}

export function formatErrorResponse(error: unknown, correlationId?: string): LLMError {
  if (error instanceof APIError) {
    return {
      error: error.message,
      error_code: error.code,
      correlation_id: correlationId,
      timestamp: new Date().toISOString()
    };
  }

  if (error instanceof Error) {
    return {
      error: error.message,
      error_code: 'INTERNAL_ERROR',
      correlation_id: correlationId,
      timestamp: new Date().toISOString()
    };
  }

  return {
    error: String(error),
    error_code: 'UNKNOWN_ERROR',
    correlation_id: correlationId,
    timestamp: new Date().toISOString()
  };
}
```

#### H2-H4: Production Safety

```typescript
// Request timeout (30s max)
const response = await Promise.race([
  this.processLLMRequest(request),
  new Promise<LLMResponse>((_, reject) =>
    setTimeout(() => reject(new APIError('TIMEOUT', 'Request exceeded 30s limit', 504)), 30000)
  )
]);

// Rate limiting
const rateLimiter = new RateLimiter({
  max_requests: 100,
  window_ms: 60000
});

if (!rateLimiter.check(request.provider || 'default')) {
  throw new APIError('RATE_LIMITED', 'Too many requests', 429);
}

// Tool validation
if (request.tools && request.tools.length > 0) {
  for (const tool of request.tools) {
    if (!tool.function?.name) {
      throw new APIError('INVALID_TOOL', 'Tool must have a name', 400);
    }
  }
}
```

## Week 3: Production Hardening

### Health Checks

Create `src/health.ts`:

```typescript
import type { CredentialStatus } from './types';

export async function getHealthStatus() {
  return {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    providers: await checkProviderHealth(),
    uptime_ms: process.uptime() * 1000,
    memory_mb: process.memoryUsage().heapUsed / 1024 / 1024
  };
}

async function checkProviderHealth(): Promise<Record<string, CredentialStatus>> {
  // Check each provider is working
}
```

### Metrics & Monitoring

Already have `src/metrics.ts` - just need to:
1. Export Prometheus metrics endpoint
2. Add request duration histograms
3. Add error rate tracking

## Week 4: Deployment

### Validation Checklist

- [ ] All types are strict (no `any`)
- [ ] NATS errors caught and logged
- [ ] API keys validated on startup
- [ ] Tests passing (>60% coverage)
- [ ] Timeout protection (30s max)
- [ ] Rate limiting enabled
- [ ] Health check endpoint working
- [ ] Metrics collecting
- [ ] Logging structured (JSON)
- [ ] Error messages consistent

### Deployment Command

```bash
# 1. Run tests
bun test

# 2. Type check
bunx tsc --noEmit

# 3. Build
bun build src/server.ts --outfile=dist/server.js

# 4. Start
bun run src/server.ts
```

## Summary

| Week | Focus | Effort | Complexity |
|------|-------|--------|-----------|
| 1 | Critical fixes (types, error handling, validation, tests) | 8-10h | HIGH |
| 2 | Integration tests, error formatting, safety guards | 8-10h | MEDIUM |
| 3 | Health checks, metrics, monitoring | 4-6h | MEDIUM |
| 4 | Validation and deployment | 2-4h | LOW |
| **Total** | **Production ready** | **22-30h** | **HIGH** |

**Next Step**: Start Week 1 Day 1 by creating `src/types.ts`
