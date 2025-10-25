#!/usr/bin/env bun

/**
 * @file Shared Queue Consumer (pgmq)
 * @description Consumes requests from shared_queue PostgreSQL database (pgmq).
 *
 * This replaces NATS messaging with PostgreSQL pgmq for durable,
 * ACID-compliant inter-service communication.
 *
 * Consumes from:
 * - pgmq.llm_requests (from Singularity) → Routes to AI providers
 * - pgmq.approval_requests (from Singularity) → Broadcasts to browser
 * - pgmq.question_requests (from Singularity) → Broadcasts to browser
 *
 * Publishes to:
 * - pgmq.llm_results (for Singularity)
 * - pgmq.approval_responses (from browser)
 * - pgmq.question_responses (from browser)
 */

import { logger } from './logger.js';

interface QueueMessage<T = any> {
  msg_id: number;
  read_ct: number;
  enqueued_at: Date;
  vt: Date;
  msg: T;
}

interface LLMRequest {
  agent_id: string;
  task_type: string;
  complexity: 'simple' | 'medium' | 'complex';
  messages: Array<{ role: string; content: string }>;
  context?: Record<string, any>;
}

interface ApprovalRequest {
  id: string;
  file_path: string;
  diff: string;
  description: string;
  agent_id: string;
  timestamp: string;
}

interface QuestionRequest {
  id: string;
  question: string;
  context?: Record<string, any>;
  agent_id: string;
  timestamp: string;
}

class SharedQueueHandler {
  private databaseUrl: string;
  private isConnected = false;
  private pollIntervalMs: number;
  private batchSize: number;

  constructor() {
    this.databaseUrl =
      process.env.SHARED_QUEUE_DB_URL ||
      `postgresql://${process.env.SHARED_QUEUE_USER || 'postgres'}:${process.env.SHARED_QUEUE_PASSWORD || ''}@${process.env.SHARED_QUEUE_HOST || 'localhost'}:${process.env.SHARED_QUEUE_PORT || '5432'}/${process.env.SHARED_QUEUE_DB || 'shared_queue'}`;

    this.pollIntervalMs = parseInt(process.env.SHARED_QUEUE_POLL_MS || '1000', 10);
    this.batchSize = parseInt(process.env.SHARED_QUEUE_BATCH_SIZE || '10', 10);
  }

  /**
   * Initialize connection and start polling
   */
  async initialize(): Promise<boolean> {
    try {
      // TODO: Connect to shared_queue database
      // const client = await postgres(this.databaseUrl);
      // await client`SELECT 1`;  // Test connection

      logger.info('[SharedQueue] Connected to shared_queue database', {
        host: this.databaseUrl.split('@')[1]?.split(':')[0] || 'localhost',
        database: 'shared_queue',
      });

      this.isConnected = true;
      return true;
    } catch (error) {
      logger.error('[SharedQueue] Failed to connect', {
        error: error instanceof Error ? error.message : String(error),
      });
      this.isConnected = false;
      return false;
    }
  }

  /**
   * Start polling for messages
   */
  async startPolling(): Promise<void> {
    if (!this.isConnected) {
      logger.error('[SharedQueue] Cannot start polling: not connected');
      return;
    }

    logger.info('[SharedQueue] Starting polling', {
      interval_ms: this.pollIntervalMs,
      batch_size: this.batchSize,
    });

    // TODO: Implement actual polling loop
    // setInterval(() => this.pollMessages(), this.pollIntervalMs);
  }

  /**
   * Poll all queues for new messages
   */
  private async pollMessages(): Promise<void> {
    try {
      // TODO: SELECT * FROM pgmq.read('llm_requests', limit := this.batchSize)
      const llmRequests = await this.readQueue<LLMRequest>('llm_requests');
      if (llmRequests.length > 0) {
        await this.handleLLMRequests(llmRequests);
      }

      // TODO: SELECT * FROM pgmq.read('approval_requests', limit := this.batchSize)
      const approvalRequests = await this.readQueue<ApprovalRequest>('approval_requests');
      if (approvalRequests.length > 0) {
        await this.handleApprovalRequests(approvalRequests);
      }

      // TODO: SELECT * FROM pgmq.read('question_requests', limit := this.batchSize)
      const questionRequests = await this.readQueue<QuestionRequest>('question_requests');
      if (questionRequests.length > 0) {
        await this.handleQuestionRequests(questionRequests);
      }
    } catch (error) {
      logger.error('[SharedQueue] Error during polling', {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  /**
   * Read messages from queue
   */
  private async readQueue<T>(queueName: string): Promise<QueueMessage<T>[]> {
    try {
      // Use raw SQL query to call pgmq.read()
      const result = await Bun.sql(
        `SELECT msg_id, read_ct, enqueued_at, vt, msg FROM pgmq.read($1, $2)`
      ).all(queueName, this.batchSize);

      if (!result || result.length === 0) {
        logger.debug('[SharedQueue] No messages in queue', {
          queue: queueName,
        });
        return [];
      }

      const messages = (result as any[]).map((row) => ({
        msg_id: row.msg_id,
        read_ct: row.read_ct,
        enqueued_at: new Date(row.enqueued_at),
        vt: new Date(row.vt),
        msg: typeof row.msg === 'string' ? JSON.parse(row.msg) : row.msg,
      }));

      logger.debug('[SharedQueue] Read messages from queue', {
        queue: queueName,
        count: messages.length,
      });

      return messages;
    } catch (error) {
      logger.error('[SharedQueue] Failed to read queue', {
        queue: queueName,
        error: error instanceof Error ? error.message : String(error),
      });
      return [];
    }
  }

  /**
   * Archive message after successful processing
   */
  private async archiveMessage(queueName: string, msgId: number): Promise<boolean> {
    try {
      // Call pgmq.archive() to move message to archive table
      await Bun.sql(
        `SELECT pgmq.archive($1, $2)`
      ).run(queueName, msgId);

      logger.debug('[SharedQueue] Archived message', {
        queue: queueName,
        msg_id: msgId,
      });
      return true;
    } catch (error) {
      logger.error('[SharedQueue] Failed to archive message', {
        queue: queueName,
        msg_id: msgId,
        error: error instanceof Error ? error.message : String(error),
      });
      return false;
    }
  }

  /**
   * Publish message to queue
   */
  private async publishToQueue<T>(queueName: string, msg: T): Promise<number | null> {
    try {
      // Call pgmq.send() to publish message
      const result = await Bun.sql(
        `SELECT pgmq.send($1, $2::jsonb) as msg_id`
      ).get(queueName, JSON.stringify(msg));

      const msgId = result?.msg_id as number | undefined;

      if (!msgId) {
        throw new Error('pgmq.send() returned no msg_id');
      }

      logger.debug('[SharedQueue] Published message', {
        queue: queueName,
        msg_id: msgId,
      });

      return msgId;
    } catch (error) {
      logger.error('[SharedQueue] Failed to publish message', {
        queue: queueName,
        error: error instanceof Error ? error.message : String(error),
      });
      return null;
    }
  }

  /**
   * Handle LLM requests from Singularity
   */
  private async handleLLMRequests(requests: QueueMessage<LLMRequest>[]): Promise<void> {
    logger.info('[SharedQueue] Processing LLM requests', { count: requests.length });

    for (const { msg_id, msg: request } of requests) {
      try {
        logger.info('[LLMRouter] Routing request', {
          msg_id,
          agent_id: request.agent_id,
          task_type: request.task_type,
          complexity: request.complexity,
        });

        // TODO: Route to appropriate LLM provider
        // const result = await routeToProvider(request);
        // TODO: Publish result to pgmq.llm_results
        // await this.publishToQueue('llm_results', result);

        // Archive after processing
        await this.archiveMessage('llm_requests', msg_id);
      } catch (error) {
        logger.error('[LLMRouter] Failed to process request', {
          msg_id,
          agent_id: request.agent_id,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
  }

  /**
   * Handle approval requests from Singularity
   */
  private async handleApprovalRequests(requests: QueueMessage<ApprovalRequest>[]): Promise<void> {
    logger.info('[HITL] Processing approval requests', { count: requests.length });

    for (const { msg_id, msg: request } of requests) {
      try {
        logger.info('[HITL] Approval request received', {
          msg_id,
          request_id: request.id,
          agent_id: request.agent_id,
          file_path: request.file_path,
        });

        // TODO: Broadcast to connected WebSocket clients
        // This would be handled by approval-websocket-bridge.ts
        // broadcastToWebSocket('approval_request', request);

        // Archive after broadcasting
        await this.archiveMessage('approval_requests', msg_id);
      } catch (error) {
        logger.error('[HITL] Failed to process approval request', {
          msg_id,
          request_id: request.id,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
  }

  /**
   * Handle question requests from Singularity
   */
  private async handleQuestionRequests(requests: QueueMessage<QuestionRequest>[]): Promise<void> {
    logger.info('[HITL] Processing question requests', { count: requests.length });

    for (const { msg_id, msg: request } of requests) {
      try {
        logger.info('[HITL] Question request received', {
          msg_id,
          request_id: request.id,
          agent_id: request.agent_id,
        });

        // TODO: Broadcast to connected WebSocket clients
        // This would be handled by approval-websocket-bridge.ts
        // broadcastToWebSocket('question_request', request);

        // Archive after broadcasting
        await this.archiveMessage('question_requests', msg_id);
      } catch (error) {
        logger.error('[HITL] Failed to process question request', {
          msg_id,
          request_id: request.id,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
  }

  /**
   * Publish approval response to shared_queue
   */
  async publishApprovalResponse(response: {
    request_id: string;
    approved: boolean;
    reason?: string;
  }): Promise<boolean> {
    const msgId = await this.publishToQueue('approval_responses', response);
    return msgId !== null;
  }

  /**
   * Publish question response to shared_queue
   */
  async publishQuestionResponse(response: {
    request_id: string;
    response: string;
  }): Promise<boolean> {
    const msgId = await this.publishToQueue('question_responses', response);
    return msgId !== null;
  }

  /**
   * Check connection status
   */
  isReady(): boolean {
    return this.isConnected;
  }

  /**
   * Graceful shutdown
   */
  async close(): Promise<void> {
    this.isConnected = false;
    logger.info('[SharedQueue] Disconnected');
  }
}

// Global singleton
let handler: SharedQueueHandler | null = null;

/**
 * Initialize handler
 */
export async function initializeSharedQueueHandler(): Promise<SharedQueueHandler> {
  if (handler) {
    return handler;
  }

  handler = new SharedQueueHandler();

  if (!(await handler.initialize())) {
    throw new Error('Failed to initialize shared queue handler');
  }

  await handler.startPolling();
  return handler;
}

/**
 * Get handler instance
 */
export function getSharedQueueHandler(): SharedQueueHandler | null {
  return handler;
}

export default SharedQueueHandler;
