/**
 * @file Consistent Error Formatting
 * @description Converts all error types to standard LLMError format.
 *
 * Ensures that all errors, regardless of source, are formatted consistently
 * for publishing to NATS. Maps error types to standard error codes.
 */

import type { LLMError, ErrorCode } from './types';
import { ERROR_CODES } from './types';
import { logger } from './logger';

/**
 * StandardAPIError - Base error class for API errors
 *
 * All API errors should extend this to ensure consistent formatting.
 *
 * @example
 * ```typescript
 * throw new StandardAPIError(
 *   ERROR_CODES.RATE_LIMITED,
 *   'Too many requests',
 *   429
 * );
 * ```
 */
export class StandardAPIError extends Error {
  constructor(
    public code: ErrorCode,
    message: string,
    public statusCode: number = 400,
    public details?: Record<string, unknown>
  ) {
    super(message);
    this.name = 'StandardAPIError';
    Object.setPrototypeOf(this, StandardAPIError.prototype);
  }
}

/**
 * ValidationError - Invalid request format or schema
 *
 * Thrown when request validation fails.
 */
export class ValidationError extends StandardAPIError {
  constructor(message: string, details?: Record<string, unknown>) {
    super(ERROR_CODES.VALIDATION_ERROR, message, 400, details);
    this.name = 'ValidationError';
  }
}

/**
 * ProviderError - Provider-specific error (auth, API, etc.)
 *
 * Thrown by provider modules when API calls fail.
 */
export class ProviderError extends StandardAPIError {
  constructor(
    provider: string,
    message: string,
    public originalError?: Error,
    statusCode?: number
  ) {
    super(ERROR_CODES.PROVIDER_ERROR, `[${provider}] ${message}`, statusCode || 500, {
      provider,
      originalMessage: message
    });
    this.name = 'ProviderError';
  }
}

/**
 * TimeoutError - Request exceeded time limit
 *
 * Thrown when a request takes too long to process.
 */
export class TimeoutError extends StandardAPIError {
  constructor(timeoutMs: number) {
    super(
      ERROR_CODES.TIMEOUT,
      `Request exceeded ${timeoutMs}ms timeout limit`,
      504,
      { timeoutMs }
    );
    this.name = 'TimeoutError';
  }
}

/**
 * RateLimitError - Rate limit exceeded
 *
 * Thrown when rate limit is exceeded.
 */
export class RateLimitError extends StandardAPIError {
  constructor(provider: string, limit: number, windowMs: number) {
    super(
      ERROR_CODES.RATE_LIMITED,
      `Rate limit exceeded for ${provider} (${limit} requests per ${windowMs}ms)`,
      429,
      { provider, limit, windowMs }
    );
    this.name = 'RateLimitError';
  }
}

/**
 * CredentialError - Missing or invalid API keys
 *
 * Thrown when credentials are not available.
 */
export class CredentialError extends StandardAPIError {
  constructor(provider: string, missingKeys: string[]) {
    super(
      ERROR_CODES.MISSING_CREDENTIALS,
      `Missing credentials for ${provider}: ${missingKeys.join(', ')}`,
      401,
      { provider, missingKeys }
    );
    this.name = 'CredentialError';
  }
}

/**
 * Format any error to standard LLMError response
 *
 * Converts all error types (StandardAPIError, Error, unknown) to
 * consistent LLMError format for publishing to NATS.
 *
 * @param error - Error of any type
 * @param correlationId - Request correlation ID for tracking
 * @returns Formatted LLMError ready to publish
 *
 * @example
 * ```typescript
 * try {
 *   // ... some operation
 * } catch (error) {
 *   const lmmError = formatError(error, request.correlation_id);
 *   await publisher.publishError('llm.error', lmmError);
 * }
 * ```
 */
export function formatError(error: unknown, correlationId?: string): LLMError {
  // ── StandardAPIError (our custom errors) ──
  if (error instanceof StandardAPIError) {
    const lmmError: LLMError = {
      error: error.message,
      error_code: error.code,
      correlation_id: correlationId,
      timestamp: new Date().toISOString()
    };

    logger.debug('Formatted StandardAPIError', {
      code: error.code,
      message: error.message,
      statusCode: error.statusCode,
      correlationId
    });

    return lmmError;
  }

  // ── Standard Error ──
  if (error instanceof Error) {
    const lmmError: LLMError = {
      error: error.message || 'Unknown error',
      error_code: ERROR_CODES.INTERNAL_ERROR,
      correlation_id: correlationId,
      timestamp: new Date().toISOString()
    };

    logger.debug('Formatted Error', {
      message: error.message,
      name: error.name,
      correlationId
    });

    return lmmError;
  }

  // ── Unknown error type ──
  const errorStr = String(error);
  const lmmError: LLMError = {
    error: errorStr || 'Unknown error occurred',
    error_code: ERROR_CODES.UNKNOWN_ERROR,
    correlation_id: correlationId,
    timestamp: new Date().toISOString()
  };

  logger.debug('Formatted unknown error type', {
    type: typeof error,
    value: errorStr.substring(0, 100),
    correlationId
  });

  return lmmError;
}

/**
 * Extract error code from any error type
 *
 * Maps error types to standard error codes.
 * Used in error logging and metrics.
 *
 * @param error - Error of any type
 * @returns Error code string
 */
export function extractErrorCode(error: unknown): string {
  if (error instanceof StandardAPIError) {
    return error.code;
  }

  if (error instanceof SyntaxError) {
    return ERROR_CODES.VALIDATION_ERROR;
  }

  if (error instanceof TypeError) {
    return ERROR_CODES.VALIDATION_ERROR;
  }

  if (error instanceof RangeError) {
    return ERROR_CODES.VALIDATION_ERROR;
  }

  if (error instanceof Error) {
    // Check message for common patterns
    const msg = error.message.toLowerCase();

    if (msg.includes('timeout')) return ERROR_CODES.TIMEOUT;
    if (msg.includes('rate limit')) return ERROR_CODES.RATE_LIMITED;
    if (msg.includes('auth') || msg.includes('credential')) {
      return ERROR_CODES.MISSING_CREDENTIALS;
    }
    if (msg.includes('not found') || msg.includes('unknown provider')) {
      return ERROR_CODES.PROVIDER_NOT_FOUND;
    }

    return ERROR_CODES.INTERNAL_ERROR;
  }

  return ERROR_CODES.UNKNOWN_ERROR;
}

/**
 * Get HTTP status code for error code
 *
 * Maps LLMError codes to standard HTTP status codes.
 * Useful for REST endpoints (if added in future).
 *
 * @param errorCode - Error code from LLMError
 * @returns HTTP status code
 */
export function getStatusCodeForError(errorCode: ErrorCode): number {
  switch (errorCode) {
    case ERROR_CODES.VALIDATION_ERROR:
      return 400;
    case ERROR_CODES.MISSING_CREDENTIALS:
      return 401;
    case ERROR_CODES.RATE_LIMITED:
      return 429;
    case ERROR_CODES.TIMEOUT:
      return 504;
    case ERROR_CODES.PROVIDER_NOT_FOUND:
      return 400;
    case ERROR_CODES.PROVIDER_ERROR:
      return 502;
    case ERROR_CODES.INTERNAL_ERROR:
    case ERROR_CODES.UNKNOWN_ERROR:
      return 500;
    default:
      return 500;
  }
}
