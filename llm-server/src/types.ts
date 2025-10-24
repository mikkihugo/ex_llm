/**
 * @file Core type definitions for LLM Server
 * @description Comprehensive type safety for all LLM server operations.
 * Used by NATS handlers, provider selection, and API responses.
 */

// ============================================================================
// Request/Response Types
// ============================================================================

/**
 * LLMRequest - Incoming request from Elixir via NATS
 *
 * All fields are optional except `messages` to allow flexible routing.
 * The NATS handler validates this structure.
 */
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

/**
 * LLMResponse - Successful response published to NATS
 *
 * All responses must include timestamp and model for traceability.
 * Token usage and cost are optional (depends on provider).
 */
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

/**
 * LLMError - Error response published to NATS
 *
 * Consistent error format across all providers.
 * error_code is machine-readable for error handling.
 */
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

/**
 * TaskType - Classification of what the LLM is being asked to do
 *
 * Used for model selection and complexity scoring.
 * Aligns with Elixir task_type in LLM.Service.call/3
 */
export type TaskType =
  | 'general'      // Generic Q&A, simple parsing
  | 'architect'    // System design, architecture decisions
  | 'coder'        // Code generation, refactoring
  | 'qa'           // Code review, testing, validation
  | 'classifier'   // Text classification
  | 'parser'       // Parsing, extraction
  | 'simple_chat'  // Conversational Q&A
  | 'decomposition'   // Breaking down problems
  | 'planning'     // Planning and strategy
  | 'pseudocode'   // Algorithm pseudocode
  | 'code_analysis' // Analyzing existing code
  | 'refactoring'   // Code refactoring tasks
  | 'pattern_analyzer' // Analyzing patterns
  | 'web_search'   // Web search integration tasks;

/**
 * TaskComplexity - Computed complexity level of a task
 *
 * Based on task type, message length, code needs, etc.
 * Maps to model capabilities:
 * - simple: Gemini Flash, GPT-4o mini (~$0.001 per call)
 * - medium: Claude Sonnet, GPT-4o (~$0.01-0.05 per call)
 * - complex: Claude Opus, GPT-4 Turbo (~$0.10-0.50 per call)
 */
export type TaskComplexity = 'simple' | 'medium' | 'complex';

/**
 * CapabilityHint - Hints about what capabilities to prioritize
 *
 * Used to guide model selection when multiple models could work.
 * Maps to provider capabilities matrices.
 */
export type CapabilityHint =
  | 'code'       // Code generation quality
  | 'reasoning'  // Multi-step reasoning
  | 'creativity' // Creative/novel solutions
  | 'speed'      // Fast inference time
  | 'cost';      // Cost efficiency

/**
 * ProviderKey - Supported AI providers
 *
 * Each provider is registered in MODEL_CAPABILITIES
 * and has corresponding provider module in ./providers/
 */
export type ProviderKey =
  | 'claude'     // Anthropic Claude
  | 'gemini'     // Google Gemini
  | 'codex'      // OpenAI Codex
  | 'copilot'    // GitHub Copilot
  | 'github'     // GitHub Models
  | 'jules'      // Google Jules (specialized agent)
  | 'cursor'     // Cursor IDE provider
  | 'openrouter'; // OpenRouter aggregator

// ============================================================================
// Tool Types (OpenAI format)
// ============================================================================

/**
 * OpenAITool - Function calling tool in OpenAI format
 *
 * Used by tool_translator.ts to convert between formats.
 * Matches OpenAI SDK tool definition.
 */
export interface OpenAITool {
  type: 'function';
  function: {
    name: string;
    description?: string;
    parameters?: {
      type: 'object';
      properties?: Record<string, unknown>;
      required?: string[];
    };
  };
}

// ============================================================================
// Provider Credentials
// ============================================================================

/**
 * CredentialStatus - Status of a provider's credentials
 *
 * Used by health check and startup validation.
 * Tracks when credentials were last verified.
 */
export interface CredentialStatus {
  provider: ProviderKey;
  available: boolean;
  error?: string;
  last_checked: string;
}

// ============================================================================
// Validation Guards
// ============================================================================

/**
 * Type guard: Check if object is valid LLMRequest
 *
 * Validates entire request structure including all message fields.
 * Used in NATS handler to validate incoming messages.
 *
 * @param obj - Object to validate
 * @returns true if obj is valid LLMRequest
 *
 * @example
 * ```typescript
 * const data = JSON.parse(msg.data.toString());
 * if (isValidLLMRequest(data)) {
 *   const request: LLMRequest = data;
 * }
 * ```
 */
export function isValidLLMRequest(obj: unknown): obj is LLMRequest {
  if (!obj || typeof obj !== 'object') return false;
  const req = obj as Record<string, unknown>;

  // ── Mandatory fields ──
  // Must have messages array
  if (!Array.isArray(req.messages)) return false;
  if (req.messages.length === 0) return false;

  // Validate each message
  for (let i = 0; i < req.messages.length; i++) {
    const msg = req.messages[i];
    if (!msg || typeof msg !== 'object') return false;

    const m = msg as Record<string, unknown>;
    if (typeof m.role !== 'string' || typeof m.content !== 'string') return false;

    // Role must be valid
    const validRoles = ['user', 'assistant', 'system'];
    if (!validRoles.includes(m.role)) return false;

    // Content must not be empty
    if (m.content.length === 0) return false;
  }

  // ── Optional fields with type validation ──
  if (req.model !== undefined && typeof req.model !== 'string') return false;
  if (req.provider !== undefined && typeof req.provider !== 'string') return false;

  // max_tokens must be positive integer
  if (req.max_tokens !== undefined) {
    if (typeof req.max_tokens !== 'number' || req.max_tokens < 1 || req.max_tokens > 128000) {
      return false;
    }
  }

  // temperature must be in valid range
  if (req.temperature !== undefined) {
    if (typeof req.temperature !== 'number' || req.temperature < 0 || req.temperature > 2) {
      return false;
    }
  }

  if (req.stream !== undefined && typeof req.stream !== 'boolean') return false;
  if (req.correlation_id !== undefined && typeof req.correlation_id !== 'string') return false;

  // complexity must be valid
  if (req.complexity !== undefined) {
    const validComplexity = ['simple', 'medium', 'complex'];
    if (!validComplexity.includes(req.complexity as string)) return false;
  }

  // task_type must be valid
  if (req.task_type !== undefined) {
    const validTaskTypes = [
      'general', 'architect', 'coder', 'qa',
      'classifier', 'parser', 'simple_chat',
      'decomposition', 'planning', 'pseudocode',
      'code_analysis', 'refactoring', 'pattern_analyzer', 'web_search'
    ];
    if (!validTaskTypes.includes(req.task_type as string)) return false;
  }

  // capabilities must be array of valid hints
  if (req.capabilities !== undefined) {
    if (!Array.isArray(req.capabilities)) return false;
    const validHints = ['code', 'reasoning', 'creativity', 'speed', 'cost'];
    for (const hint of req.capabilities) {
      if (!validHints.includes(hint as string)) return false;
    }
  }

  // tools must be array of valid OpenAI tools
  if (req.tools !== undefined) {
    if (!Array.isArray(req.tools)) return false;
    for (const tool of req.tools) {
      if (!isValidOpenAITool(tool)) return false;
    }
  }

  return true;
}

/**
 * Type guard: Check if object is valid OpenAITool
 *
 * @param obj - Object to validate
 * @returns true if obj is valid OpenAITool
 */
export function isValidOpenAITool(obj: unknown): obj is OpenAITool {
  if (!obj || typeof obj !== 'object') return false;
  const tool = obj as Record<string, unknown>;

  if (tool.type !== 'function') return false;
  if (!tool.function || typeof tool.function !== 'object') return false;

  const func = tool.function as Record<string, unknown>;
  if (typeof func.name !== 'string') return false;
  if (func.description !== undefined && typeof func.description !== 'string') return false;
  if (func.parameters !== undefined && typeof func.parameters !== 'object') return false;

  return true;
}

/**
 * Assertion guard: Throw if object is not valid LLMRequest
 *
 * Used in NATS handler to ensure types are correct before processing.
 *
 * @param obj - Object to validate
 * @throws Error if validation fails
 *
 * @example
 * ```typescript
 * try {
 *   assertValidLLMRequest(data);
 *   const request: LLMRequest = data; // type is now narrowed
 * } catch (error) {
 *   // Handle validation error
 * }
 * ```
 */
export function assertValidLLMRequest(obj: unknown): asserts obj is LLMRequest {
  if (!isValidLLMRequest(obj)) {
    const objStr = JSON.stringify(obj).substring(0, 200);
    throw new Error(`Invalid LLM request - must match LLMRequest schema: ${objStr}`);
  }
}

// ============================================================================
// Error Types
// ============================================================================

/**
 * Custom error codes for LLM Server
 *
 * Used in error responses to indicate what went wrong.
 * Allows Elixir to handle different error types appropriately.
 */
export const ERROR_CODES = {
  VALIDATION_ERROR: 'VALIDATION_ERROR',
  PROVIDER_NOT_FOUND: 'PROVIDER_NOT_FOUND',
  PROVIDER_ERROR: 'PROVIDER_ERROR',
  TIMEOUT: 'TIMEOUT',
  RATE_LIMITED: 'RATE_LIMITED',
  INVALID_TOOL: 'INVALID_TOOL',
  MISSING_CREDENTIALS: 'MISSING_CREDENTIALS',
  INTERNAL_ERROR: 'INTERNAL_ERROR',
  UNKNOWN_ERROR: 'UNKNOWN_ERROR'
} as const;

export type ErrorCode = typeof ERROR_CODES[keyof typeof ERROR_CODES];

// ============================================================================
// Model Selection
// ============================================================================

/**
 * ModelSelection - Result of model selection logic
 *
 * Contains the provider and model chosen for a request,
 * along with the computed complexity level.
 */
export interface ModelSelection {
  provider: ProviderKey;
  model: string;
  complexity: TaskComplexity;
  reason?: string;
}
