/**
 * Jules TODO Manager
 *
 * Tracks complex TODOs and spawns Jules sessions to fix them autonomously.
 * Jules can handle up to 3 concurrent tasks (free tier: 15/day).
 */

import { jules } from '../providers/google-ai-jules';
import * as fs from 'fs/promises';
import * as path from 'path';

export interface ComplexTodo {
  id: string;
  title: string;
  description: string;
  files: string[];
  complexity: 'medium' | 'high' | 'massive';
  languages: string[];
  status: 'pending' | 'jules_assigned' | 'in_progress' | 'completed';
  julesSessionId?: string;
  createdAt: Date;
  startedAt?: Date;
  completedAt?: Date;
}

export class JulesTodoCManager {
  private todos: Map<string, ComplexTodo> = new Map();
  private activeSessions: Map<string, string> = new Map(); // todoId -> sessionId
  private dailyTaskCount: number = 0;
  private lastResetDate: Date = new Date();

  constructor(
    private githubOwner: string = 'mhugo',
    private githubRepo: string = 'singularity'
  ) {
    this.loadTodos();
  }

  private async loadTodos() {
    try {
      const data = await fs.readFile('.jules-todos.json', 'utf-8');
      const parsed = JSON.parse(data);
      this.todos = new Map(parsed.todos);
      this.dailyTaskCount = parsed.dailyTaskCount || 0;
      this.lastResetDate = new Date(parsed.lastResetDate || Date.now());
    } catch (e) {
      // File doesn't exist, start fresh
      this.scanForTodos();
    }
  }

  private async saveTodos() {
    await fs.writeFile('.jules-todos.json', JSON.stringify({
      todos: Array.from(this.todos.entries()),
      dailyTaskCount: this.dailyTaskCount,
      lastResetDate: this.lastResetDate,
      activeSessions: Array.from(this.activeSessions.entries())
    }, null, 2));
  }

  /**
   * Scan codebase for complex TODOs that Jules should handle
   */
  async scanForTodos() {
    const complexTodos: ComplexTodo[] = [
      {
        id: 'nats-integration',
        title: 'Complete NATS Integration',
        description: `Complete the NATS messaging integration across all services:
          1. Add gnat dependency to Elixir singularity_app/mix.exs
          2. Wire up NatsOrchestrator in application.ex supervision tree
          3. Make rust/db_service the ONLY service with PostgreSQL access
          4. Update package_registry_indexer to use NATS db.query instead of direct DB
          5. Test pub/sub flow between TypeScript, Elixir, and Rust services`,
        files: [
          'singularity_app/mix.exs',
          'singularity_app/lib/singularity/application.ex',
          'singularity_app/lib/singularity/nats_orchestrator.ex',
          'rust/db_service/src/nats_db_service.rs',
          'rust/package_registry_indexer/src/main.rs'
        ],
        complexity: 'massive',
        languages: ['elixir', 'rust', 'typescript'],
        status: 'pending',
        createdAt: new Date()
      },
      {
        id: 'tool-calling',
        title: 'Implement Tool Calling Support',
        description: `Fix all TODO comments about tool calls in ai-server:
          1. Implement tool_calls in response formatting (line 604, 1432, 1524)
          2. Add MCP server configuration from requests (line 1385)
          3. Convert OpenAI tools to AI SDK format (lines 1273, 1361)
          4. Add streaming tool call support for providers
          5. Test with Claude, GPT-5, and Gemini models`,
        files: [
          'ai-server/src/server.ts',
          'ai-server/src/providers/copilot-api.ts',
          'ai-server/src/providers/google-ai-jules.ts'
        ],
        complexity: 'high',
        languages: ['typescript'],
        status: 'pending',
        createdAt: new Date()
      },
      {
        id: 'test-suite',
        title: 'Build Comprehensive Test Suite',
        description: `Create complete test coverage:
          1. Add Jest config and tests for ai-server TypeScript
          2. Add ExUnit tests for Elixir orchestration logic
          3. Add Rust tests for NATS message handlers
          4. Create integration tests for NATS messaging flow
          5. Setup GitHub Actions CI/CD pipeline
          6. Add test coverage reporting`,
        files: [
          'ai-server/jest.config.js',
          'ai-server/src/**/*.test.ts',
          'singularity_app/test/**/*_test.exs',
          'rust/*/src/**/*.rs',
          '.github/workflows/ci.yml'
        ],
        complexity: 'massive',
        languages: ['typescript', 'elixir', 'rust', 'yaml'],
        status: 'pending',
        createdAt: new Date()
      },
      {
        id: 'vector-db-rag',
        title: 'Implement Vector DB RAG System',
        description: `Wire up pgvector for semantic search:
          1. Complete pattern mining TODOs in pattern_miner.ex
          2. Implement embedding generation with Gemini or OpenAI
          3. Store code patterns in pgvector
          4. Add semantic similarity search
          5. Connect to MemoryCache for fast retrieval`,
        files: [
          'singularity_app/lib/singularity/learning/pattern_miner.ex',
          'singularity_app/lib/singularity/semantic_code_search.ex',
          'rust/db_service/migrations/005_pgvector.sql'
        ],
        complexity: 'high',
        languages: ['elixir', 'sql'],
        status: 'pending',
        createdAt: new Date()
      },
      {
        id: 'mcp-protocol',
        title: 'Implement Model Context Protocol',
        description: `Add full MCP (Model Context Protocol) support:
          1. Create MCP server in ai-server
          2. Define tool schemas for code operations
          3. Implement tool discovery endpoint
          4. Add context management for long conversations
          5. Support tool confirmation workflows`,
        files: [
          'ai-server/src/mcp/server.ts',
          'ai-server/src/mcp/tools.ts',
          'ai-server/src/mcp/context.ts'
        ],
        complexity: 'high',
        languages: ['typescript'],
        status: 'pending',
        createdAt: new Date()
      }
    ];

    for (const todo of complexTodos) {
      this.todos.set(todo.id, todo);
    }

    await this.saveTodos();
    console.log(`📝 Found ${complexTodos.length} complex TODOs for Jules`);
  }

  /**
   * Spawn Jules session for a TODO
   */
  async spawnJulesSession(todoId: string): Promise<string> {
    // Check daily limit (resets at midnight)
    const now = new Date();
    if (now.getDate() !== this.lastResetDate.getDate()) {
      this.dailyTaskCount = 0;
      this.lastResetDate = now;
    }

    if (this.dailyTaskCount >= 15) {
      throw new Error('Daily Jules limit reached (15 tasks/day on free tier)');
    }

    if (this.activeSessions.size >= 3) {
      throw new Error('Max concurrent Jules sessions reached (3 on free tier)');
    }

    const todo = this.todos.get(todoId);
    if (!todo) {
      throw new Error(`TODO ${todoId} not found`);
    }

    if (todo.status !== 'pending') {
      throw new Error(`TODO ${todoId} already ${todo.status}`);
    }

    try {
      // Create Jules session
      const session = await jules.createGitHubTask(
        this.githubOwner,
        this.githubRepo,
        todo.description,
        'main'
      );

      // Update TODO status
      todo.status = 'jules_assigned';
      todo.julesSessionId = session.id;
      todo.startedAt = new Date();
      this.activeSessions.set(todoId, session.id!);
      this.dailyTaskCount++;

      await this.saveTodos();

      console.log(`🤖 Jules session ${session.id} created for TODO: ${todo.title}`);
      return session.id!;

    } catch (error: any) {
      console.error(`Failed to spawn Jules session: ${error.message}`);
      throw error;
    }
  }

  /**
   * Spawn all high-priority TODOs to Jules (up to limits)
   */
  async spawnAllToJules(): Promise<void> {
    const pending = Array.from(this.todos.values())
      .filter(t => t.status === 'pending')
      .sort((a, b) => {
        // Prioritize by complexity
        const complexityScore = { massive: 3, high: 2, medium: 1 };
        return complexityScore[b.complexity] - complexityScore[a.complexity];
      });

    console.log(`\n🎯 Spawning ${pending.length} TODOs to Jules...`);

    for (const todo of pending) {
      try {
        if (this.activeSessions.size >= 3) {
          console.log('⚠️  Max concurrent sessions reached, waiting...');
          break;
        }

        await this.spawnJulesSession(todo.id);
        console.log(`✅ Spawned: ${todo.title}`);

        // Small delay between spawns
        await new Promise(resolve => setTimeout(resolve, 2000));

      } catch (error: any) {
        console.error(`❌ Failed to spawn ${todo.id}: ${error.message}`);
        if (error.message.includes('Daily Jules limit')) {
          break;
        }
      }
    }

    console.log(`\n📊 Jules Status:`);
    console.log(`- Active Sessions: ${this.activeSessions.size}/3`);
    console.log(`- Daily Tasks Used: ${this.dailyTaskCount}/15`);
    console.log(`- Pending TODOs: ${pending.length - this.activeSessions.size}`);
  }

  /**
   * Check status of all active Jules sessions
   */
  async checkProgress(): Promise<void> {
    for (const [todoId, sessionId] of this.activeSessions) {
      try {
        const activities = await jules.listActivities(sessionId);
        const todo = this.todos.get(todoId)!;

        console.log(`\n📋 ${todo.title}:`);
        console.log(`   Session: ${sessionId}`);
        console.log(`   Activities: ${activities.activities.length}`);

        // Check if completed
        const lastActivity = activities.activities[activities.activities.length - 1];
        if (lastActivity?.type === 'completed') {
          todo.status = 'completed';
          todo.completedAt = new Date();
          this.activeSessions.delete(todoId);
          console.log(`   ✅ COMPLETED!`);
        } else {
          todo.status = 'in_progress';
          console.log(`   ⏳ In Progress...`);
        }

      } catch (error: any) {
        console.error(`Failed to check ${sessionId}: ${error.message}`);
      }
    }

    await this.saveTodos();
  }

  /**
   * List all TODOs with status
   */
  listTodos(): void {
    console.log('\n📋 Complex TODOs for Jules:\n');

    const todos = Array.from(this.todos.values());
    const grouped = {
      pending: todos.filter(t => t.status === 'pending'),
      jules_assigned: todos.filter(t => t.status === 'jules_assigned'),
      in_progress: todos.filter(t => t.status === 'in_progress'),
      completed: todos.filter(t => t.status === 'completed')
    };

    for (const [status, items] of Object.entries(grouped)) {
      if (items.length > 0) {
        console.log(`${status.toUpperCase()} (${items.length}):`);
        for (const todo of items) {
          const emoji = status === 'completed' ? '✅' :
                       status === 'in_progress' ? '⏳' :
                       status === 'jules_assigned' ? '🤖' : '📝';
          console.log(`  ${emoji} ${todo.id}: ${todo.title}`);
          if (todo.julesSessionId) {
            console.log(`      Session: ${todo.julesSessionId}`);
          }
        }
        console.log();
      }
    }
  }
}

// CLI Interface
if (require.main === module) {
  const manager = new JulesTodoCManager();

  const command = process.argv[2];

  (async () => {
    switch (command) {
      case 'scan':
        await manager.scanForTodos();
        manager.listTodos();
        break;

      case 'list':
        manager.listTodos();
        break;

      case 'spawn':
        const todoId = process.argv[3];
        if (todoId) {
          await manager.spawnJulesSession(todoId);
        } else {
          await manager.spawnAllToJules();
        }
        break;

      case 'status':
        await manager.checkProgress();
        break;

      default:
        console.log(`
Jules TODO Manager - Manage complex tasks with autonomous AI

Usage:
  bun run ai-server/src/tools/jules-todo-manager.ts <command>

Commands:
  scan     - Scan codebase for complex TODOs
  list     - List all TODOs with status
  spawn    - Spawn Jules sessions for all pending TODOs
  spawn <id> - Spawn Jules session for specific TODO
  status   - Check progress of active Jules sessions

Limits (Free Tier):
  - 15 tasks per day
  - 3 concurrent sessions
  - Upgrade at https://jules.google for more
        `);
    }
  })();
}