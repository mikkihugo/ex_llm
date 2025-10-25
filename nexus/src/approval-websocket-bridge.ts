#!/usr/bin/env bun

/**
 * @file Approval & Question WebSocket Bridge
 * @description Bridges NATS approval/question requests to connected WebSocket clients.
 *
 * Flow:
 * 1. Agent publishes approval/question request via NATS (approval.request / question.ask)
 * 2. Bridge subscribes to these NATS topics
 * 3. Bridge forwards messages to all connected WebSocket clients
 * 4. Client (browser) approves/rejects in UI
 * 5. Client sends response via WebSocket
 * 6. Bridge publishes response back to NATS reply subject
 * 7. Agent receives response from NATS request-reply
 *
 * ## Message Format
 *
 * ### Approval Request (NATS → WebSocket)
 * ```json
 * {
 *   "id": "uuid",
 *   "file_path": "lib/my_module.ex",
 *   "diff": "actual diff text",
 *   "description": "Add feature X",
 *   "agent_id": "self-improving-agent",
 *   "timestamp": "2025-01-10T...",
 *   "type": "approval"
 * }
 * ```
 *
 * ### Approval Response (WebSocket → NATS)
 * ```json
 * {
 *   "approved": true,
 *   "request_id": "uuid",
 *   "timestamp": "2025-01-10T..."
 * }
 * ```
 *
 * ### Question Request (NATS → WebSocket)
 * ```json
 * {
 *   "id": "uuid",
 *   "question": "Should we use async or sync?",
 *   "context": { ... },
 *   "agent_id": "architect-agent",
 *   "timestamp": "2025-01-10T...",
 *   "type": "question"
 * }
 * ```
 *
 * ### Question Response (WebSocket → NATS)
 * ```json
 * {
 *   "response": "Use async for I/O bound operations",
 *   "request_id": "uuid",
 *   "timestamp": "2025-01-10T..."
 * }
 * ```
 */

import { connect, NatsConnection, Subscription } from 'nats';
import { logger } from './logger';

interface PendingRequest {
  natsReplySubject: string;
  timeout: NodeJS.Timeout;
}

interface WebSocketMessage {
  type: 'approval_request' | 'question_request' | 'approval_response' | 'question_response';
  id: string;
  data: any;
}

export class ApprovalWebSocketBridge {
  private nc: NatsConnection | null = null;
  private subscriptions: Subscription[] = [];
  private subscriptionTasks: Promise<void>[] = [];
  private connectedClients: Set<WebSocket> = new Set();
  private pendingRequests: Map<string, PendingRequest> = new Map();

  async connect() {
    try {
      const natsUrl = process.env.NATS_URL || 'nats://localhost:4222';
      this.nc = await connect({
        servers: natsUrl
      });

      logger.info('[ApprovalBridge] Connected to NATS server', { url: natsUrl });

      await this.subscribeToApprovalRequests();
      await this.subscribeToQuestionRequests();
    } catch (error) {
      logger.error('[ApprovalBridge] Failed to connect to NATS', {
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined
      });
      throw error;
    }
  }

  private async subscribeToApprovalRequests() {
    if (!this.nc) throw new Error('NATS not connected');
    const subscription = this.nc.subscribe('approval.request');
    this.subscriptions.push(subscription);
    const processor = this.handleApprovalRequestStream(subscription);
    const taskWithCleanup = processor.catch(error => {
      logger.error('[ApprovalBridge] Unhandled error in approval request stream:', error);
      const index = this.subscriptionTasks.indexOf(taskWithCleanup);
      if (index > -1) this.subscriptionTasks.splice(index, 1);
      throw error;
    });
    this.subscriptionTasks.push(taskWithCleanup);
  }

  private async subscribeToQuestionRequests() {
    if (!this.nc) throw new Error('NATS not connected');
    const subscription = this.nc.subscribe('question.ask');
    this.subscriptions.push(subscription);
    const processor = this.handleQuestionRequestStream(subscription);
    const taskWithCleanup = processor.catch(error => {
      logger.error('[ApprovalBridge] Unhandled error in question request stream:', error);
      const index = this.subscriptionTasks.indexOf(taskWithCleanup);
      if (index > -1) this.subscriptionTasks.splice(index, 1);
      throw error;
    });
    this.subscriptionTasks.push(taskWithCleanup);
  }

  private async handleApprovalRequestStream(subscription: Subscription) {
    for await (const msg of subscription) {
      this.handleApprovalRequest(msg).catch(error => {
        logger.error('[ApprovalBridge] Error handling approval request:', error);
      });
    }
  }

  private async handleQuestionRequestStream(subscription: Subscription) {
    for await (const msg of subscription) {
      this.handleQuestionRequest(msg).catch(error => {
        logger.error('[ApprovalBridge] Error handling question request:', error);
      });
    }
  }

  private async handleApprovalRequest(msg: any): Promise<void> {
    try {
      const request = JSON.parse(msg.data.toString());

      logger.info('[ApprovalBridge] Received approval request', {
        id: request.id,
        filePath: request.file_path,
        agentId: request.agent_id
      });

      // Store NATS reply subject if this is a request-reply
      if (msg.reply) {
        const timeout = setTimeout(() => {
          // Timeout after 30 seconds if no response
          this.pendingRequests.delete(request.id);
          logger.warn('[ApprovalBridge] Approval request timeout:', { id: request.id });
        }, 30000);

        this.pendingRequests.set(request.id, {
          natsReplySubject: msg.reply,
          timeout
        });
      }

      // Forward to all connected WebSocket clients
      this.broadcastToClients({
        type: 'approval_request',
        id: request.id,
        data: request
      });
    } catch (error) {
      logger.error('[ApprovalBridge] Error parsing approval request:', error);
      if (msg.reply) {
        await this.publishError(msg.reply, 'Failed to parse approval request');
      }
    }
  }

  private async handleQuestionRequest(msg: any): Promise<void> {
    try {
      const request = JSON.parse(msg.data.toString());

      logger.info('[ApprovalBridge] Received question request', {
        id: request.id,
        agentId: request.agent_id
      });

      // Store NATS reply subject if this is a request-reply
      if (msg.reply) {
        const timeout = setTimeout(() => {
          // Timeout after 30 seconds if no response
          this.pendingRequests.delete(request.id);
          logger.warn('[ApprovalBridge] Question request timeout:', { id: request.id });
        }, 30000);

        this.pendingRequests.set(request.id, {
          natsReplySubject: msg.reply,
          timeout
        });
      }

      // Forward to all connected WebSocket clients
      this.broadcastToClients({
        type: 'question_request',
        id: request.id,
        data: request
      });
    } catch (error) {
      logger.error('[ApprovalBridge] Error parsing question request:', error);
      if (msg.reply) {
        await this.publishError(msg.reply, 'Failed to parse question request');
      }
    }
  }

  /**
   * Handle response from WebSocket client
   * (approval approved/rejected or question answered)
   */
  async handleClientResponse(message: WebSocketMessage): Promise<void> {
    try {
      const { id, data } = message;

      // Find the pending request
      const pending = this.pendingRequests.get(id);
      if (!pending) {
        logger.warn('[ApprovalBridge] Received response for unknown request:', { id });
        return;
      }

      // Clear the timeout
      clearTimeout(pending.timeout);
      this.pendingRequests.delete(id);

      logger.info('[ApprovalBridge] Received client response', {
        id,
        type: message.type
      });

      // Publish response back to NATS reply subject
      await this.publishResponse(pending.natsReplySubject, data);
    } catch (error) {
      logger.error('[ApprovalBridge] Error handling client response:', error);
    }
  }

  /**
   * Register a WebSocket client for receiving approval/question requests
   */
  addClient(ws: WebSocket): void {
    this.connectedClients.add(ws);
    logger.info('[ApprovalBridge] Client connected', {
      totalClients: this.connectedClients.size
    });

    // Handle WebSocket messages from client
    ws.onmessage = (event) => {
      try {
        const message = JSON.parse(event.data);
        if (message.type === 'approval_response' || message.type === 'question_response') {
          this.handleClientResponse(message);
        }
      } catch (error) {
        logger.error('[ApprovalBridge] Error processing WebSocket message:', error);
      }
    };

    // Remove client when disconnected
    ws.onclose = () => {
      this.connectedClients.delete(ws);
      logger.info('[ApprovalBridge] Client disconnected', {
        totalClients: this.connectedClients.size
      });
    };

    ws.onerror = (event) => {
      logger.error('[ApprovalBridge] WebSocket error:', event);
      this.connectedClients.delete(ws);
    };
  }

  /**
   * Broadcast message to all connected WebSocket clients
   */
  private broadcastToClients(message: WebSocketMessage): void {
    const payload = JSON.stringify(message);

    for (const client of this.connectedClients) {
      try {
        if (client.readyState === WebSocket.OPEN) {
          client.send(payload);
        }
      } catch (error) {
        logger.error('[ApprovalBridge] Error sending to client:', error);
        this.connectedClients.delete(client);
      }
    }

    // Log if no clients connected
    if (this.connectedClients.size === 0) {
      logger.warn('[ApprovalBridge] Broadcasting with no connected clients', {
        messageType: message.type,
        messageId: message.id
      });
    }
  }

  /**
   * Publish response back to NATS
   */
  private async publishResponse(replySubject: string, responseData: any): Promise<void> {
    if (!this.nc) {
      logger.error('[ApprovalBridge] Cannot publish response - NATS not connected');
      return;
    }

    try {
      const payload = JSON.stringify(responseData);
      this.nc.publish(replySubject, payload);
      logger.info('[ApprovalBridge] Published response to NATS', {
        subject: replySubject
      });
    } catch (error) {
      logger.error('[ApprovalBridge] Failed to publish response:', error);
    }
  }

  /**
   * Publish error response back to NATS
   */
  private async publishError(replySubject: string, errorMessage: string): Promise<void> {
    if (!this.nc) {
      logger.error('[ApprovalBridge] Cannot publish error - NATS not connected');
      return;
    }

    try {
      const error = JSON.stringify({
        error: errorMessage,
        timestamp: new Date().toISOString()
      });
      this.nc.publish(replySubject, error);
    } catch (error) {
      logger.error('[ApprovalBridge] Failed to publish error:', error);
    }
  }

  async close(): Promise<void> {
    for (const client of this.connectedClients) {
      client.close();
    }
    this.connectedClients.clear();

    for (const [, pending] of this.pendingRequests) {
      clearTimeout(pending.timeout);
    }
    this.pendingRequests.clear();

    for (const sub of this.subscriptions) {
      sub.unsubscribe();
    }
    this.subscriptions = [];

    await Promise.allSettled(this.subscriptionTasks);
    this.subscriptionTasks = [];

    if (this.nc) {
      await this.nc.close();
      logger.info('[ApprovalBridge] Disconnected from NATS');
    }
  }
}

/**
 * Global singleton instance
 */
let bridgeInstance: ApprovalWebSocketBridge | null = null;

/**
 * Initialize the approval WebSocket bridge
 */
export async function initializeApprovalBridge(): Promise<ApprovalWebSocketBridge> {
  if (bridgeInstance) {
    return bridgeInstance;
  }

  bridgeInstance = new ApprovalWebSocketBridge();
  await bridgeInstance.connect();
  return bridgeInstance;
}

/**
 * Get the global bridge instance
 */
export function getApprovalBridge(): ApprovalWebSocketBridge | null {
  return bridgeInstance;
}

export default ApprovalWebSocketBridge;
