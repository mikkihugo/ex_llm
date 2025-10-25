/**
 * @file Safe NATS Publisher
 * @description Wraps NATS publishing with error handling and logging.
 *
 * Ensures that NATS publish operations don't crash the server even if
 * the connection is lost or closed. Uses proper error codes and logging.
 */

import { NatsConnection } from 'nats';
import type { LLMResponse, LLMError } from './types';
import { logger } from './logger';

/**
 * SafeNATSPublisher - Safely publishes messages to NATS
 *
 * Handles connection state, encoding, and errors gracefully.
 * Never throws - failures are logged and ignored (NATS is fire-and-forget).
 *
 * @example
 * ```typescript
 * const publisher = new SafeNATSPublisher(natsConnection);
 *
 * const response: LLMResponse = {
 *   text: "Hello world",
 *   model: "gpt-4o",
 *   timestamp: new Date().toISOString()
 * };
 *
 * await publisher.publishResponse('llm.response', response);
 * ```
 */
export class SafeNATSPublisher {
  constructor(private nc: NatsConnection | null) {}

  /**
   * Publish a successful LLM response to NATS
   *
   * @param subject - NATS subject to publish to (e.g., 'llm.response')
   * @param response - LLMResponse to publish
   * @returns void - never throws, errors are logged
   */
  async publishResponse(subject: string, response: LLMResponse): Promise<void> {
    try {
      // Check connection is alive
      if (!this.nc) {
        logger.error('NATS not initialized for response', {
          subject,
          correlationId: response.correlation_id
        });
        return;
      }

      if (this.nc.isClosed()) {
        logger.error('NATS connection closed for response', {
          subject,
          correlationId: response.correlation_id
        });
        return;
      }

      // Serialize to JSON
      const serialized = JSON.stringify(response);
      const bytes = new TextEncoder().encode(serialized);

      // Publish to NATS
      this.nc.publish(subject, bytes);

      logger.debug('Published LLM response', {
        subject,
        model: response.model,
        textLength: response.text.length,
        correlationId: response.correlation_id
      });
    } catch (error) {
      // Log error but don't throw - NATS is fire-and-forget
      logger.error('Failed to publish LLM response', {
        subject,
        error: error instanceof Error ? error.message : String(error),
        correlationId: response.correlation_id,
        stack: error instanceof Error ? error.stack : undefined
      });
    }
  }

  /**
   * Publish an error response to NATS
   *
   * Uses same format as responses for consistency.
   *
   * @param subject - NATS subject to publish to (e.g., 'llm.error')
   * @param error - LLMError to publish
   * @returns void - never throws, errors are logged
   */
  async publishError(subject: string, error: LLMError): Promise<void> {
    try {
      // Check connection is alive
      if (!this.nc) {
        logger.error('NATS not initialized for error', {
          subject,
          errorCode: error.error_code,
          correlationId: error.correlation_id
        });
        return;
      }

      if (this.nc.isClosed()) {
        logger.error('NATS connection closed for error', {
          subject,
          errorCode: error.error_code,
          correlationId: error.correlation_id
        });
        return;
      }

      // Serialize to JSON
      const serialized = JSON.stringify(error);
      const bytes = new TextEncoder().encode(serialized);

      // Publish to NATS
      this.nc.publish(subject, bytes);

      logger.debug('Published error response', {
        subject,
        errorCode: error.error_code,
        message: error.error,
        correlationId: error.correlation_id
      });
    } catch (error) {
      // Log error but don't throw
      logger.error('Failed to publish error response', {
        subject,
        error: error instanceof Error ? error.message : String(error),
        originalError: error instanceof Error ? error.message : 'unknown',
        stack: error instanceof Error ? error.stack : undefined
      });
    }
  }

  /**
   * Publish to a reply subject (request/reply pattern)
   *
   * Used when a message came with a reply subject,
   * following NATS request/reply pattern.
   *
   * @param replySubject - Reply subject from original message
   * @param response - LLMResponse to publish
   * @returns void - never throws
   */
  async publishToReply(
    replySubject: string,
    response: LLMResponse | LLMError
  ): Promise<void> {
    try {
      if (!this.nc || this.nc.isClosed()) {
        logger.error('Cannot publish to reply - NATS not available', {
          replySubject,
          correlationId: 'correlation_id' in response ? response.correlation_id : 'unknown'
        });
        return;
      }

      const serialized = JSON.stringify(response);
      const bytes = new TextEncoder().encode(serialized);
      this.nc.publish(replySubject, bytes);

      logger.debug('Published to reply subject', {
        replySubject,
        isError: 'error_code' in response
      });
    } catch (error) {
      logger.error('Failed to publish to reply', {
        replySubject,
        error: error instanceof Error ? error.message : String(error)
      });
    }
  }

  /**
   * Check if NATS is connected and ready
   *
   * @returns true if connection is alive
   */
  isConnected(): boolean {
    return this.nc !== null && !this.nc.isClosed();
  }
}

/**
 * Create a SafeNATSPublisher from existing NATS connection
 *
 * Handles null/undefined connections gracefully.
 *
 * @param nc - NATS connection (can be null)
 * @returns SafeNATSPublisher instance
 */
export function createPublisher(nc: NatsConnection | null): SafeNATSPublisher {
  return new SafeNATSPublisher(nc);
}
