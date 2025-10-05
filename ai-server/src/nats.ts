/**
 * NATS JetStream integration for AI server
 *
 * Provides:
 * - LLM streaming via NATS
 * - Agent event broadcasting
 * - Tool call distribution
 * - Fact system integration
 */

import { connect, type NatsConnection, type JetStreamClient, StringCodec } from 'nats';

const sc = StringCodec();

export class NatsService {
  private nc: NatsConnection | null = null;
  private js: JetStreamClient | null = null;

  async connect(url = 'nats://localhost:4222') {
    this.nc = await connect({ servers: url });
    this.js = this.nc.jetstream();

    console.log('📡 Connected to NATS JetStream');

    // Setup streams if they don't exist
    await this.setupStreams();
  }

  private async setupStreams() {
    if (!this.js) return;

    const jsm = await this.nc!.jetstreamManager();

    // AI Events stream
    try {
      await jsm.streams.add({
        name: 'AI_EVENTS',
        subjects: ['ai.>', 'llm.>', 'agent.>'],
        retention: 'limits',
        max_age: 3600_000_000_000, // 1 hour in nanoseconds
        storage: 'memory',
      });
    } catch (err: any) {
      if (!err.message?.includes('already exists')) {
        console.error('Failed to create AI_EVENTS stream:', err);
      }
    }
  }

  /**
   * Publish LLM streaming tokens
   */
  async publishLLMToken(sessionId: string, token: string, metadata?: any) {
    if (!this.nc) throw new Error('Not connected to NATS');

    await this.nc.publish(
      `llm.stream.${sessionId}`,
      sc.encode(JSON.stringify({ token, metadata, timestamp: Date.now() }))
    );
  }

  /**
   * Publish agent event
   */
  async publishAgentEvent(agentId: string, event: string, data: any) {
    if (!this.nc) throw new Error('Not connected to NATS');

    await this.nc.publish(
      `agent.${agentId}.${event}`,
      sc.encode(JSON.stringify({ event, data, timestamp: Date.now() }))
    );
  }

  /**
   * Request facts from fact system
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
   * Request tool execution from workers
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
   * Subscribe to LLM stream
   */
  async *subscribeLLMStream(sessionId: string): AsyncIterableIterator<any> {
    if (!this.nc) throw new Error('Not connected to NATS');

    const sub = this.nc.subscribe(`llm.stream.${sessionId}`);

    for await (const msg of sub) {
      yield JSON.parse(sc.decode(msg.data));
    }
  }

  /**
   * Close connection
   */
  async close() {
    await this.nc?.drain();
  }
}

// Singleton instance
export const nats = new NatsService();
