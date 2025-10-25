/**
 * AI Server - PostgreSQL-native AI orchestration
 *
 * Architecture:
 * - Replaces NATS-based AI routing
 * - Uses pgflow for workflow orchestration
 * - Uses pgmq for request/response queues
 * - PostgreSQL as single source of truth
 *
 * Data Flow:
 * 1. Singularity enqueues AI tasks to pgmq:ai_requests
 * 2. pgflow polls pgmq, executes workflows
 * 3. Results stored in PostgreSQL (pgflow state)
 * 4. Results published to pgmq:ai_results
 * 5. Singularity polls results and processes
 */

import { pgflow } from "pgflow";
import { sql } from "postgres";
import postgres from "postgres";

// Import workflow definitions
import {
  llmRequestWorkflow,
  embeddingWorkflow,
  agentCoordinationWorkflow,
} from "./workflows";

// ============================================================================
// Environment & Configuration
// ============================================================================

const DATABASE_URL =
  process.env.DATABASE_URL ||
  "postgresql://postgres@localhost:5432/singularity";
const PORT = parseInt(process.env.PORT || "3001", 10);
const NODE_ENV = process.env.NODE_ENV || "development";

console.log(`🚀 AI Server starting in ${NODE_ENV} mode`);
console.log(`📦 Database: ${DATABASE_URL.replace(/:[^:]*@/, ":***@")}`);

// ============================================================================
// Database Setup
// ============================================================================

let db: ReturnType<typeof postgres>;

async function initializeDatabase() {
  console.log("📊 Initializing database connection...");

  try {
    db = postgres(DATABASE_URL, {
      max: 20,
      timeout: 30 * 1000,
    });

    // Test connection
    await db`SELECT 1`;
    console.log("✅ Database connection successful");

    // Create pgmq extension if not exists
    await db`CREATE EXTENSION IF NOT EXISTS pgmq`;
    console.log("✅ pgmq extension ready");

    // Initialize pgflow tables
    await initializePgflow(db);
    console.log("✅ pgflow tables initialized");

    return db;
  } catch (error) {
    console.error("❌ Database initialization failed:", error);
    process.exit(1);
  }
}

async function initializePgflow(db: ReturnType<typeof postgres>) {
  // pgflow schema tables
  // These track workflow execution state, tasks, and results

  try {
    // Workflow state table
    await db`
      CREATE TABLE IF NOT EXISTS pgflow.workflows (
        id BIGSERIAL PRIMARY KEY,
        workflow_name VARCHAR NOT NULL,
        workflow_id UUID NOT NULL UNIQUE,
        status VARCHAR NOT NULL,
        input JSONB,
        output JSONB,
        error TEXT,
        started_at TIMESTAMP,
        completed_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `;

    // Task execution table
    await db`
      CREATE TABLE IF NOT EXISTS pgflow.tasks (
        id BIGSERIAL PRIMARY KEY,
        workflow_id UUID NOT NULL REFERENCES pgflow.workflows(workflow_id),
        task_name VARCHAR NOT NULL,
        task_index INT NOT NULL,
        status VARCHAR NOT NULL,
        input JSONB,
        output JSONB,
        error TEXT,
        started_at TIMESTAMP,
        completed_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `;

    // pgmq queues for AI workflows
    // Request queues (Singularity → ai-server)
    await db`
      SELECT pgmq.create('ai_requests');
    `;

    await db`
      SELECT pgmq.create('embedding_requests');
    `;

    await db`
      SELECT pgmq.create('agent_messages');
    `;

    // Result queues (ai-server → Singularity)
    await db`
      SELECT pgmq.create('ai_results');
    `;

    await db`
      SELECT pgmq.create('embedding_results');
    `;

    await db`
      SELECT pgmq.create('agent_responses');
    `;

    console.log("✅ pgmq queues initialized");
  } catch (error: any) {
    // Queues may already exist, which is fine
    if (!error.message?.includes("already exists")) {
      throw error;
    }
  }
}

// ============================================================================
// Workflow Processor
// ============================================================================

async function processWorkflows(db: ReturnType<typeof postgres>) {
  console.log("🔄 Starting workflow processor...");

  // Register workflows with pgflow
  const workflows = [
    llmRequestWorkflow,
    embeddingWorkflow,
    agentCoordinationWorkflow,
  ];

  for (const workflow of workflows) {
    console.log(`📋 Registered workflow: ${workflow.name}`);
  }

  // Main processing loop
  // In a production system, pgflow handles this internally
  // For now, we simulate with polling

  const processRequests = async () => {
    try {
      // Poll LLM requests
      const llmRequests = await db`
        SELECT * FROM pgmq.read('ai_requests', limit => 1)
      `;

      if (llmRequests.length > 0) {
        const request = llmRequests[0];
        console.log(`📥 Processing LLM request: ${request.msg_id}`);

        try {
          // Execute workflow steps
          const result = await executeLlmWorkflow(request.msg_body);

          // Publish result to ai_results queue
          await db`
            SELECT pgmq.send('ai_results', ${JSON.stringify(result)});
          `;

          // Acknowledge message (mark as processed)
          await db`
            SELECT pgmq.delete('ai_requests', ${request.msg_id});
          `;

          console.log(`✅ LLM request processed: ${request.msg_id}`);
        } catch (error) {
          console.error(`❌ LLM request failed:`, error);
          // Message will be retried on next poll
        }
      }

      // Poll embedding requests
      const embeddingRequests = await db`
        SELECT * FROM pgmq.read('embedding_requests', limit => 1)
      `;

      if (embeddingRequests.length > 0) {
        const request = embeddingRequests[0];
        console.log(`📥 Processing embedding request: ${request.msg_id}`);

        try {
          const result = await executeEmbeddingWorkflow(request.msg_body);

          await db`
            SELECT pgmq.send('embedding_results', ${JSON.stringify(result)});
          `;

          await db`
            SELECT pgmq.delete('embedding_requests', ${request.msg_id});
          `;

          console.log(`✅ Embedding request processed: ${request.msg_id}`);
        } catch (error) {
          console.error(`❌ Embedding request failed:`, error);
        }
      }

      // Poll agent messages
      const agentMessages = await db`
        SELECT * FROM pgmq.read('agent_messages', limit => 1)
      `;

      if (agentMessages.length > 0) {
        const request = agentMessages[0];
        console.log(`📥 Processing agent message: ${request.msg_id}`);

        try {
          const result = await executeAgentWorkflow(request.msg_body);

          await db`
            SELECT pgmq.send('agent_responses', ${JSON.stringify(result)});
          `;

          await db`
            SELECT pgmq.delete('agent_messages', ${request.msg_id});
          `;

          console.log(`✅ Agent message processed: ${request.msg_id}`);
        } catch (error) {
          console.error(`❌ Agent message failed:`, error);
        }
      }
    } catch (error) {
      console.error("❌ Workflow processor error:", error);
    }

    // Schedule next poll
    setTimeout(processRequests, 1000);
  };

  // Start polling
  processRequests();
}

// ============================================================================
// Workflow Execution (simplified for now)
// ============================================================================

async function executeLlmWorkflow(input: any) {
  // Step 1: Receive request
  const { request_id, messages, task_type, model = "auto", provider = "auto" } = input;

  // Step 2: Determine complexity and select model
  const complexity = getComplexityForTask(task_type);
  const selectedModel = model === "auto" ? selectBestModel(complexity) : { model, provider };

  console.log(
    `🧠 LLM Request [${request_id}]: task=${task_type}, complexity=${complexity}, model=${selectedModel.model}`
  );

  // Step 3: Call LLM provider (mock for now)
  const response = {
    text: `Mock response from ${selectedModel.model} for task: ${task_type}`,
    model: selectedModel.model,
    tokens: 150,
    cost: 25,
  };

  // Step 4: Return result
  return {
    request_id,
    response: response.text,
    model_used: response.model,
    tokens_used: response.tokens,
    cost_cents: response.cost,
    timestamp: new Date().toISOString(),
  };
}

async function executeEmbeddingWorkflow(input: any) {
  const { query_id, query, model = "qodo" } = input;

  console.log(`🔍 Embedding Request [${query_id}]: model=${model}`);

  // Mock embedding (2560-dim in production)
  const embedding = Array(10)
    .fill(0)
    .map(() => Math.random());

  return {
    query_id,
    embedding,
    embedding_dim: embedding.length,
    timestamp: new Date().toISOString(),
  };
}

async function executeAgentWorkflow(input: any) {
  const { message_id, source_agent, target_agent, message_type, payload } = input;

  console.log(
    `🤖 Agent Message [${message_id}]: ${source_agent} → ${target_agent} (${message_type})`
  );

  return {
    message_id,
    source_agent,
    target_agent,
    message_type,
    payload,
    routed: true,
    timestamp: new Date().toISOString(),
  };
}

// ============================================================================
// Helper Functions
// ============================================================================

function getComplexityForTask(taskType: string): string {
  const complexityMap: Record<string, string> = {
    classifier: "simple",
    parser: "simple",
    simple_chat: "simple",
    coder: "medium",
    decomposition: "medium",
    planning: "medium",
    chat: "medium",
    architect: "complex",
    code_generation: "complex",
    qa: "complex",
    refactoring: "complex",
  };

  return complexityMap[taskType] || "medium";
}

function selectBestModel(complexity: string): { model: string; provider: string } {
  switch (complexity) {
    case "simple":
      return { model: "gemini-1.5-flash", provider: "gemini" };
    case "medium":
      return { model: "claude-sonnet-4.5", provider: "anthropic" };
    case "complex":
      return { model: "claude-opus", provider: "anthropic" };
    default:
      return { model: "claude-sonnet-4.5", provider: "anthropic" };
  }
}

// ============================================================================
// Server Setup
// ============================================================================

async function startServer() {
  try {
    // Initialize database
    await initializeDatabase();

    // Start workflow processor
    await processWorkflows(db);

    console.log(`✅ AI Server running on port ${PORT}`);
    console.log(`🔌 Workflows: llm_request, embedding_request, agent_coordination`);
    console.log(`📨 Listening to pgmq queues: ai_requests, embedding_requests, agent_messages`);
  } catch (error) {
    console.error("❌ Failed to start server:", error);
    process.exit(1);
  }
}

// ============================================================================
// Graceful Shutdown
// ============================================================================

process.on("SIGINT", async () => {
  console.log("\n🛑 Shutting down...");

  try {
    if (db) {
      await db.end();
      console.log("✅ Database connection closed");
    }
    process.exit(0);
  } catch (error) {
    console.error("❌ Error during shutdown:", error);
    process.exit(1);
  }
});

// ============================================================================
// Start
// ============================================================================

startServer();
