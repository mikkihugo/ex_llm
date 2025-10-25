/**
 * AI Server pgflow Workflows
 *
 * PostgreSQL-native AI orchestration replacing NATS
 *
 * Architecture:
 * - Singularity (Elixir/Oban) enqueues AI tasks to pgmq:ai_requests
 * - AI Server (pgflow) polls pgmq, processes request
 * - AI Server publishes result back to pgmq:ai_results
 * - Singularity polls for results, processes them
 *
 * pgflow provides:
 * - SQL-native state management
 * - TypeScript DSL for workflow definitions
 * - Automatic retry/backoff
 * - Task dependencies and parallel execution
 */

import { pgflow } from "pgflow";

/**
 * LLM Request Workflow
 *
 * Handles AI provider routing and LLM API calls
 * Replaces: NATS llm.request topic
 *
 * Flow:
 * 1. Receive request from pgmq (via Singularity Oban job)
 * 2. Analyze complexity (simple/medium/complex)
 * 3. Select model based on availability and cost
 * 4. Call LLM provider (Claude, Gemini, etc.)
 * 5. Store result back to pgmq:ai_results
 */
export const llmRequestWorkflow = pgflow.define({
  name: "llm_request",
  description: "Route and process LLM requests from Singularity agents",

  steps: [
    /**
     * Step 1: Receive LLM request from pgmq
     * Input: { request_id, messages, task_type, model, provider }
     */
    pgflow.step("receive_request", async (input: any) => {
      console.log(`Received LLM request: ${input.request_id}`);
      console.log(`Task type: ${input.task_type}, Model: ${input.model}`);

      return {
        request_id: input.request_id,
        messages: input.messages,
        task_type: input.task_type,
        model: input.model || "auto",
        provider: input.provider || "auto",
        received_at: new Date().toISOString(),
      };
    }),

    /**
     * Step 2: Analyze complexity and select model
     * If model="auto", determine best model based on:
     * - Task type (architect, coder, classifier, etc.)
     * - Available models and credentials
     * - Cost optimization
     */
    pgflow.step("select_model", async (prev: any) => {
      const { task_type, model } = prev;

      let selected_model = model;
      let selected_provider = prev.provider;

      if (model === "auto") {
        const complexity = getComplexityForTask(task_type);
        ({ model: selected_model, provider: selected_provider } =
          selectBestModel(complexity));
      }

      console.log(`Selected model: ${selected_model} from ${selected_provider}`);

      return {
        ...prev,
        selected_model,
        selected_provider,
        complexity: getComplexityForTask(task_type),
      };
    }),

    /**
     * Step 3: Call LLM Provider
     * Handles retries, timeout, rate limiting
     * Supports: Claude, Gemini, OpenAI, etc.
     */
    pgflow.step("call_llm_provider", async (prev: any) => {
      const { selected_provider, selected_model, messages, request_id } = prev;

      try {
        const response = await callProvider(
          selected_provider,
          selected_model,
          messages
        );

        console.log(`LLM response received for ${request_id}`);

        return {
          ...prev,
          response: response.text,
          model_used: response.model,
          tokens_used: response.tokens,
          cost_cents: response.cost,
          success: true,
        };
      } catch (error) {
        console.error(`LLM call failed: ${error.message}`);
        return {
          ...prev,
          error: error.message,
          success: false,
        };
      }
    }),

    /**
     * Step 4: Store result back to pgmq:ai_results
     * Singularity will poll and process
     */
    pgflow.step("publish_result", async (prev: any) => {
      const { request_id, response, success, error, model_used, tokens_used, cost_cents } = prev;

      const result = {
        request_id,
        response: success ? response : null,
        error: success ? null : error,
        model: model_used,
        tokens_used: tokens_used || 0,
        cost_cents: cost_cents || 0,
        timestamp: new Date().toISOString(),
      };

      console.log(`Publishing result for ${request_id} to pgmq:ai_results`);
      // Result will be persisted by pgflow state management
      // Singularity polls pgmq:ai_results and processes responses

      return result;
    }),
  ],
});

/**
 * Embedding Request Workflow
 *
 * Generates semantic embeddings (replaces Embedding.Service NATS)
 * - Receives query from pgmq:embedding_requests
 * - Calls Singularity NxService (or external embedding API)
 * - Returns embedding vector to pgmq:embedding_results
 */
export const embeddingWorkflow = pgflow.define({
  name: "embedding_request",
  description: "Generate semantic embeddings for code and text",

  steps: [
    pgflow.step("receive_query", async (input: any) => {
      return {
        query_id: input.query_id,
        query: input.query,
        model: input.model || "qodo",
        received_at: new Date().toISOString(),
      };
    }),

    pgflow.step("generate_embedding", async (prev: any) => {
      const { query, model } = prev;

      try {
        // Call NxService via HTTP or direct connection
        const embedding = await generateEmbedding(query, model);

        return {
          ...prev,
          embedding,
          embedding_dim: embedding.length,
          success: true,
        };
      } catch (error) {
        return {
          ...prev,
          error: error.message,
          success: false,
        };
      }
    }),

    pgflow.step("publish_embedding", async (prev: any) => {
      const { query_id, embedding, success, error } = prev;

      const result = {
        query_id,
        embedding: success ? embedding : null,
        error: success ? null : error,
        embedding_dim: success ? embedding.length : 0,
        timestamp: new Date().toISOString(),
      };

      console.log(`Publishing embedding for ${query_id} to pgmq:embedding_results`);
      // Result will be persisted by pgflow state management
      // Singularity polls pgmq:embedding_results and processes responses

      return result;
    }),
  ],
});

/**
 * Agent Coordination Workflow
 *
 * Routes messages between Singularity agents
 * - Receives coordination message from pgmq:agent_messages
 * - Routes to target agent (or broadcasts)
 * - Agent processes, responds to pgmq:agent_responses
 */
export const agentCoordinationWorkflow = pgflow.define({
  name: "agent_coordination",
  description: "Coordinate communication between autonomous agents",

  steps: [
    pgflow.step("receive_message", async (input: any) => {
      return {
        message_id: input.message_id,
        source_agent: input.source_agent,
        target_agent: input.target_agent,
        message_type: input.message_type,
        payload: input.payload,
      };
    }),

    pgflow.step("route_message", async (prev: any) => {
      const { target_agent, message_type } = prev;

      console.log(
        `Routing ${message_type} from ${prev.source_agent} to ${target_agent}`
      );

      // Message routing logic would go here
      // For now, just log that it's being processed

      return {
        ...prev,
        routed_at: new Date().toISOString(),
        status: "routed",
      };
    }),

    pgflow.step("notify_agent", async (prev: any) => {
      // Publish to pgmq:agent_messages or trigger Singularity poll
      console.log(
        `Notifying ${prev.target_agent} of incoming ${prev.message_type}`
      );

      return {
        ...prev,
        notification_sent: true,
      };
    }),
  ],
});

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

function selectBestModel(
  complexity: string
): { model: string; provider: string } {
  // This would normally check:
  // - Available API keys
  // - Current rate limits
  // - Cost vs performance
  // - Provider availability

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

async function callProvider(
  provider: string,
  model: string,
  messages: any[]
): Promise<{ text: string; model: string; tokens: number; cost: number }> {
  // TODO: Implement actual provider calls
  // For now, return mock response

  console.log(`Calling ${provider}/${model} with ${messages.length} messages`);

  // Simulated API call - in production, call actual LLM API
  await new Promise((resolve) => setTimeout(resolve, 100));

  // Cost varies by model
  const costMap: Record<string, number> = {
    "gemini-1.5-flash": 5,
    "claude-sonnet-4.5": 25,
    "claude-opus": 50,
  };

  return {
    text: "Mock response from " + model,
    model,
    tokens: 150,
    cost: costMap[model] || 10,
  };
}

async function generateEmbedding(
  query: string,
  model: string
): Promise<number[]> {
  // TODO: Call NxService or external embedding API
  console.log(`Generating ${model} embedding for: "${query.substring(0, 50)}..."`);

  // Mock embedding (real would be 2560-dim)
  return Array(10).fill(0).map(() => Math.random());
}
