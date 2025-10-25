#!/usr/bin/env bun

/**
 * @file Nexus Database Layer
 * @description Drizzle ORM integration for PostgreSQL
 *
 * Stores:
 * - Approval request history
 * - Question request history
 * - HITL decision logs
 * - System metrics
 *
 * ## Drizzle Features
 *
 * - Type-safe queries (inferred from schema.ts)
 * - SQL-first (transparent what queries run)
 * - Lightweight (fits Bun philosophy)
 * - Migrations (drizzle-kit migrate)
 * - Connection pooling (native pg)
 */

import { drizzle, type PostgresJsDatabase } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import { logger } from './logger.js';
import { approvalRequests, questionRequests, hitlMetrics } from './schema.js';
import { eq } from 'drizzle-orm';

class NexusDatabase {
  private client: ReturnType<typeof postgres> | null = null;
  private db: PostgresJsDatabase | null = null;

  /**
   * Connect to database and initialize Drizzle
   */
  async connect(): Promise<boolean> {
    try {
      const databaseUrl =
        process.env.DATABASE_URL ||
        `postgresql://${process.env.DB_USER || 'postgres'}:${process.env.DB_PASSWORD || ''}@${process.env.DB_HOST || 'localhost'}:${process.env.DB_PORT || '5432'}/${process.env.NEXUS_DB || 'nexus'}`;

      this.client = postgres(databaseUrl);
      this.db = drizzle(this.client);

      // Test connection
      await this.client`SELECT 1`;

      logger.info('[Database] Connected to PostgreSQL (Drizzle)', {
        database: process.env.NEXUS_DB || 'nexus',
        provider: 'postgresql',
        driver: 'drizzle-orm',
      });

      return true;
    } catch (error) {
      logger.error('[Database] Failed to connect', {
        error: error instanceof Error ? error.message : String(error),
      });
      return false;
    }
  }

  /**
   * Log approval request to database
   */
  async logApprovalRequest(data: {
    id: string;
    filePath: string;
    diff: string;
    description?: string;
    agentId: string;
  }): Promise<void> {
    if (!this.db) return;

    try {
      await this.db.insert(approvalRequests).values({
        id: data.id as any,
        filePath: data.filePath,
        diff: data.diff,
        description: data.description,
        agentId: data.agentId,
      });

      logger.debug('[Database] Logged approval request', {
        id: data.id,
        agentId: data.agentId,
      });
    } catch (error) {
      logger.error('[Database] Failed to log approval request', {
        error: error instanceof Error ? error.message : String(error),
        requestId: data.id,
      });
    }
  }

  /**
   * Log approval decision to database
   */
  async logApprovalDecision(data: { id: string; approved: boolean }): Promise<void> {
    if (!this.db) return;

    try {
      await this.db
        .update(approvalRequests)
        .set({
          approved: data.approved,
          approvedAt: new Date(),
        })
        .where(eq(approvalRequests.id, data.id as any));

      logger.debug('[Database] Logged approval decision', {
        id: data.id,
        approved: data.approved,
      });
    } catch (error) {
      logger.error('[Database] Failed to log approval decision', {
        error: error instanceof Error ? error.message : String(error),
        requestId: data.id,
      });
    }
  }

  /**
   * Log question request to database
   */
  async logQuestionRequest(data: {
    id: string;
    question: string;
    context?: Record<string, unknown>;
    agentId: string;
  }): Promise<void> {
    if (!this.db) return;

    try {
      await this.db.insert(questionRequests).values({
        id: data.id as any,
        question: data.question,
        context: data.context,
        agentId: data.agentId,
      });

      logger.debug('[Database] Logged question request', {
        id: data.id,
        agentId: data.agentId,
      });
    } catch (error) {
      logger.error('[Database] Failed to log question request', {
        error: error instanceof Error ? error.message : String(error),
        requestId: data.id,
      });
    }
  }

  /**
   * Log question response to database
   */
  async logQuestionResponse(data: { id: string; response: string }): Promise<void> {
    if (!this.db) return;

    try {
      await this.db
        .update(questionRequests)
        .set({
          response: data.response,
          responseAt: new Date(),
        })
        .where(eq(questionRequests.id, data.id as any));

      logger.debug('[Database] Logged question response', {
        id: data.id,
      });
    } catch (error) {
      logger.error('[Database] Failed to log question response', {
        error: error instanceof Error ? error.message : String(error),
        requestId: data.id,
      });
    }
  }

  /**
   * Record HITL metric
   */
  async recordMetric(data: {
    requestType: string;
    requestId: string;
    responseTimeMs: number;
    userId?: string;
  }): Promise<void> {
    if (!this.db) return;

    try {
      await this.db.insert(hitlMetrics).values({
        requestType: data.requestType,
        requestId: data.requestId as any,
        responseTimeMs: data.responseTimeMs,
        userId: data.userId,
      });

      logger.debug('[Database] Recorded metric', {
        requestType: data.requestType,
        responseTimeMs: data.responseTimeMs,
      });
    } catch (error) {
      logger.error('[Database] Failed to record metric', {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  /**
   * Get Drizzle instance for advanced queries
   */
  getClient() {
    return this.db;
  }

  /**
   * Close database connection
   */
  async close(): Promise<void> {
    if (this.client) {
      await this.client.end();
      logger.info('[Database] Disconnected from PostgreSQL');
    }
  }
}

// Global singleton instance
let dbInstance: NexusDatabase | null = null;

/**
 * Initialize database
 */
export async function initializeDatabase(): Promise<NexusDatabase> {
  if (dbInstance) {
    return dbInstance;
  }

  dbInstance = new NexusDatabase();
  const connected = await dbInstance.connect();

  if (!connected) {
    throw new Error('Failed to initialize database');
  }

  return dbInstance;
}

/**
 * Get database instance
 */
export function getDatabase(): NexusDatabase | null {
  return dbInstance;
}

/**
 * Get Drizzle client directly (for advanced queries)
 */
export function getDrizzleClient() {
  return dbInstance?.getClient();
}

// Export schema types
export type { ApprovalRequest, ApprovalRequestInsert } from './schema.js';
export type { QuestionRequest, QuestionRequestInsert } from './schema.js';
export type { HitlMetric, HitlMetricInsert } from './schema.js';

export default NexusDatabase;
