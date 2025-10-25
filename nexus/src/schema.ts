/**
 * @file Drizzle ORM Schema
 * @description Type-safe database schema for Nexus
 *
 * Defines tables for:
 * - Approval requests
 * - Question requests
 * - HITL metrics
 */

import {
  pgTable,
  uuid,
  text,
  boolean,
  timestamp,
  integer,
  jsonb,
  varchar,
  index,
  decimal,
  serial,
} from 'drizzle-orm/pg-core';

/**
 * Approval requests from Singularity agents
 * Stores code changes awaiting human approval
 */
export const approvalRequests = pgTable(
  'approval_requests',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    filePath: text('file_path').notNull(),
    diff: text('diff').notNull(),
    description: text('description'),
    agentId: varchar('agent_id').notNull(),
    timestamp: timestamp('timestamp').defaultNow(),
    approved: boolean('approved'),
    approvedAt: timestamp('approved_at'),
    createdAt: timestamp('created_at').defaultNow(),
  },
  (table) => ({
    agentIdIdx: index('idx_approval_agent_id').on(table.agentId),
    timestampIdx: index('idx_approval_timestamp').on(table.timestamp),
  })
);

/**
 * Question requests from Singularity agents
 * Stores questions asked to humans
 */
export const questionRequests = pgTable(
  'question_requests',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    question: text('question').notNull(),
    context: jsonb('context'),
    agentId: varchar('agent_id').notNull(),
    timestamp: timestamp('timestamp').defaultNow(),
    response: text('response'),
    responseAt: timestamp('response_at'),
    createdAt: timestamp('created_at').defaultNow(),
  },
  (table) => ({
    agentIdIdx: index('idx_question_agent_id').on(table.agentId),
    timestampIdx: index('idx_question_timestamp').on(table.timestamp),
  })
);

/**
 * HITL (Human-in-the-Loop) metrics
 * Tracks response times and performance
 */
export const hitlMetrics = pgTable('hitl_metrics', {
  id: integer('id').primaryKey().generatedAlwaysAsIdentity(),
  requestType: varchar('request_type', { length: 50 }).notNull(),
  requestId: uuid('request_id').notNull(),
  responseTimeMs: integer('response_time_ms'),
  userId: varchar('user_id'),
  createdAt: timestamp('created_at').defaultNow(),
});

/**
 * Exported types for TypeScript
 */
export type ApprovalRequest = typeof approvalRequests.$inferSelect;
export type ApprovalRequestInsert = typeof approvalRequests.$inferInsert;

export type QuestionRequest = typeof questionRequests.$inferSelect;
export type QuestionRequestInsert = typeof questionRequests.$inferInsert;

export type HitlMetric = typeof hitlMetrics.$inferSelect;
export type HitlMetricInsert = typeof hitlMetrics.$inferInsert;
