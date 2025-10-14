/**
 * @file NATS JetStream Integration Service
 * @description This module provides a singleton service for interacting with NATS JetStream.
 * It handles connecting to NATS, setting up streams, and publishing/subscribing to
 * various topics related to AI, LLM, agents, and tools.
 */

import { connect, type NatsConnection, type JetStreamClient, StringCodec, RetentionPolicy, StorageType } from 'nats';

const sc = StringCodec();

/**
 * @class NatsService
 * @description A singleton class that manages the NATS connection and JetStream client.
 */
export class NatsService {
  private nc: NatsConnection | null = null;
  private js: JetStreamClient | null = null;

  /**
   * Connects to the NATS server and initializes the JetStream client.
   * @param {string} [url='nats://localhost:4222'] The URL of the NATS server.
   * @returns {Promise<void>}
   */
  async connect(url = 'nats://localhost:4222') {
    this.nc = await connect({ servers: url });
    this.js = this.nc.jetstream();

    console.log('[NATS] Connected to NATS JetStream');

    // Setup streams required by the application.
    await this.setupStreams();
  }

  /**
   * Sets up the necessary NATS JetStream streams if they don't already exist.
   * @private
   */
  private async setupStreams() {
    if (!this.js) return;

    const jsm = await this.nc!.jetstreamManager();

    // NOTE: AI_EVENTS stream disabled because it was intercepting request/reply messages
    // The stream captured all 'ai.>' subjects including 'ai.llm.request', causing
    // Gnat.request() to receive JetStream ACKs instead of actual LLM responses.
    // If you need event streaming in the future, use a more specific subject pattern
    // that doesn't overlap with request/reply subjects (e.g., 'ai.events.>' instead of 'ai.>')

    // AI Events stream for general AI-related events.
    // try {
    //   await jsm.streams.add({
    //     name: 'AI_EVENTS',
    //     subjects: ['ai.>', 'llm.>', 'agent.>'],
    //     retention: RetentionPolicy.Limits,
    //     max_age: 3_600_000_000_000, // 1 hour
    //     storage: StorageType.Memory,
    //   });
    // } catch (err: any) {
    //   if (!err.message?.includes('stream name already in use')) {
    //     console.error('[NATS] Failed to create AI_EVENTS stream:', err);
    //   }
    // }
  }

  /**
   * Publishes a token from an LLM stream to a specific session's topic.
   * @param {string} sessionId The unique session identifier.
   * @param {string} token The token to publish.
   * @param {any} [metadata] Optional metadata to include with the token.
   */
  async publishLLMToken(sessionId: string, token: string, metadata?: any) {
    if (!this.nc) throw new Error('Not connected to NATS');
    await this.nc.publish(
      `llm.stream.${sessionId}`,
      sc.encode(JSON.stringify({ token, metadata, timestamp: Date.now() }))
    );
  }

  /**
   * Publishes an event related to a specific agent.
   * @param {string} agentId The ID of the agent.
   * @param {string} event The name of the event.
   * @param {any} data The event data.
   */
  async publishAgentEvent(agentId: string, event: string, data: any) {
    if (!this.nc) throw new Error('Not connected to NATS');
    await this.nc.publish(
      `agent.${agentId}.${event}`,
      sc.encode(JSON.stringify({ event, data, timestamp: Date.now() }))
    );
  }

  /**
   * Queries the fact system for information.
   * @param {any} query The query to send to the fact system.
   * @returns {Promise<any>} A promise that resolves with the query result.
   */
  async queryFacts(query: any): Promise<any> {
    if (!this.nc) throw new Error('Not connected to NATS');
    const response = await this.nc.request(
      'facts.query',
      sc.encode(JSON.stringify(query)),
      { timeout: 5000 }
    );
    return JSON.parse(sc.decode(response.data));
  }

  /**
   * Requests the execution of a tool by a worker.
   * @param {string} tool The name of the tool to execute.
   * @param {any} params The parameters for the tool.
   * @returns {Promise<any>} A promise that resolves with the tool's execution result.
   */
  async executeTool(tool: string, params: any): Promise<any> {
    if (!this.nc) throw new Error('Not connected to NATS');
    const response = await this.nc.request(
      `tools.${tool}`,
      sc.encode(JSON.stringify(params)),
      { timeout: 30000 }
    );
    return JSON.parse(sc.decode(response.data));
  }

  /**
   * Subscribes to an LLM stream and yields tokens as they are received.
   * @param {string} sessionId The session ID for the stream to subscribe to.
   * @returns {AsyncIterableIterator<any>} An async iterator that yields stream data.
   */
  async *subscribeLLMStream(sessionId: string): AsyncIterableIterator<any> {
    if (!this.nc) throw new Error('Not connected to NATS');
    const sub = this.nc.subscribe(`llm.stream.${sessionId}`);
    for await (const msg of sub) {
      yield JSON.parse(sc.decode(msg.data));
    }
  }

  /**
   * Drains the NATS connection and closes it gracefully.
   */
  async close() {
    await this.nc?.drain();
  }
}

/**
 * @const {NatsService} nats
 * @description The singleton instance of the NatsService, providing a global point of access.
 */
export const nats = new NatsService();
