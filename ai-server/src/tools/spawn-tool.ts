/**
 * Spawn Tool for LLMs
 *
 * Allows LLMs to spawn tasks to various agents and services.
 * Can delegate to Jules, other LLMs, or create async jobs.
 */

import { z } from 'zod';
import { jules } from '../providers/google-ai-jules';
import { TodoTool } from './todo-tool';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

export interface SpawnedTask {
  id: string;
  type: 'jules' | 'llm' | 'shell' | 'nats' | 'webhook';
  target: string;
  task: string;
  status: 'spawned' | 'running' | 'completed' | 'failed';
  createdAt: Date;
  result?: any;
  error?: string;
}

export class SpawnTool {
  private activeTasks: Map<string, SpawnedTask> = new Map();
  private todoTool = new TodoTool();

  /**
   * Spawn a task to Jules for autonomous coding
   */
  async spawnToJules(task: string, githubRepo?: string): Promise<SpawnedTask> {
    const taskId = `jules_${Date.now()}`;

    try {
      // Default to current repo if not specified
      const [owner, repo] = (githubRepo || 'mhugo/singularity').split('/');

      // Create Jules session
      const session = await jules.createGitHubTask(owner, repo, task, 'main');

      const spawnedTask: SpawnedTask = {
        id: taskId,
        type: 'jules',
        target: session.id || 'jules',
        task,
        status: 'spawned',
        createdAt: new Date(),
        result: { sessionId: session.id }
      };

      this.activeTasks.set(taskId, spawnedTask);

      // Also add to TODO list
      await this.todoTool.add(
        `Jules: ${task}`,
        'high',
        ['jules', 'automated']
      );

      return spawnedTask;
    } catch (error: any) {
      return {
        id: taskId,
        type: 'jules',
        target: 'jules',
        task,
        status: 'failed',
        createdAt: new Date(),
        error: error.message
      };
    }
  }

  /**
   * Spawn a task to another LLM
   */
  async spawnToLLM(task: string, model: string = 'gpt-5-codex'): Promise<SpawnedTask> {
    const taskId = `llm_${Date.now()}`;

    // This would integrate with the orchestration pipeline
    // For now, we'll simulate it
    const spawnedTask: SpawnedTask = {
      id: taskId,
      type: 'llm',
      target: model,
      task,
      status: 'spawned',
      createdAt: new Date()
    };

    this.activeTasks.set(taskId, spawnedTask);

    // Queue the task for execution
    this.executeLLMTask(taskId, task, model);

    return spawnedTask;
  }

  /**
   * Spawn a shell command
   */
  async spawnShellCommand(command: string, background: boolean = false): Promise<SpawnedTask> {
    const taskId = `shell_${Date.now()}`;

    const spawnedTask: SpawnedTask = {
      id: taskId,
      type: 'shell',
      target: 'bash',
      task: command,
      status: 'spawned',
      createdAt: new Date()
    };

    this.activeTasks.set(taskId, spawnedTask);

    if (background) {
      // Run in background
      exec(command, (error, stdout, stderr) => {
        const task = this.activeTasks.get(taskId);
        if (task) {
          if (error) {
            task.status = 'failed';
            task.error = error.message;
          } else {
            task.status = 'completed';
            task.result = { stdout, stderr };
          }
        }
      });
    } else {
      // Run and wait
      try {
        const { stdout, stderr } = await execAsync(command);
        spawnedTask.status = 'completed';
        spawnedTask.result = { stdout, stderr };
      } catch (error: any) {
        spawnedTask.status = 'failed';
        spawnedTask.error = error.message;
      }
    }

    return spawnedTask;
  }

  /**
   * Spawn a NATS message
   */
  async spawnToNATS(subject: string, message: any): Promise<SpawnedTask> {
    const taskId = `nats_${Date.now()}`;

    // This would use the NATS client
    // For now, simulate
    const spawnedTask: SpawnedTask = {
      id: taskId,
      type: 'nats',
      target: subject,
      task: JSON.stringify(message),
      status: 'spawned',
      createdAt: new Date()
    };

    this.activeTasks.set(taskId, spawnedTask);

    // Would actually publish to NATS here
    // await nats.publish(subject, message);

    spawnedTask.status = 'completed';
    return spawnedTask;
  }

  /**
   * Check status of a spawned task
   */
  async checkStatus(taskId: string): Promise<SpawnedTask | null> {
    const task = this.activeTasks.get(taskId);

    if (!task) return null;

    // For Jules tasks, check the session status
    if (task.type === 'jules' && task.result?.sessionId) {
      try {
        const activities = await jules.listActivities(task.result.sessionId);
        if (activities.activities.length > 0) {
          task.status = 'running';
          const lastActivity = activities.activities[activities.activities.length - 1];
          if (lastActivity.type === 'completed') {
            task.status = 'completed';
          }
        }
      } catch (error) {
        // Session check failed
      }
    }

    return task;
  }

  /**
   * List all spawned tasks
   */
  listTasks(filter?: { type?: SpawnedTask['type']; status?: SpawnedTask['status'] }): SpawnedTask[] {
    let tasks = Array.from(this.activeTasks.values());

    if (filter) {
      if (filter.type) {
        tasks = tasks.filter(t => t.type === filter.type);
      }
      if (filter.status) {
        tasks = tasks.filter(t => t.status === filter.status);
      }
    }

    return tasks.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }

  /**
   * Execute LLM task asynchronously
   */
  private async executeLLMTask(taskId: string, prompt: string, model: string) {
    const task = this.activeTasks.get(taskId);
    if (!task) return;

    task.status = 'running';

    try {
      // This would call the actual LLM
      // For now, simulate with a delay
      await new Promise(resolve => setTimeout(resolve, 2000));

      task.status = 'completed';
      task.result = {
        response: `Completed task: ${prompt}`,
        model,
        tokens: 100
      };
    } catch (error: any) {
      task.status = 'failed';
      task.error = error.message;
    }
  }
}

/**
 * AI SDK Tool Definitions for Spawning
 */
export const spawnTools = {
  spawnToJules: {
    description: 'Spawn a complex coding task to Jules autonomous agent',
    parameters: z.object({
      task: z.string().describe('Detailed task description for Jules'),
      githubRepo: z.string().optional().describe('GitHub repo (owner/repo format)')
    }),
    execute: async (params: any) => {
      const tool = new SpawnTool();
      return await tool.spawnToJules(params.task, params.githubRepo);
    }
  },

  spawnToLLM: {
    description: 'Spawn a task to another LLM for processing',
    parameters: z.object({
      task: z.string().describe('Task to process'),
      model: z.string().default('gpt-5-codex').describe('Model to use')
    }),
    execute: async (params: any) => {
      const tool = new SpawnTool();
      return await tool.spawnToLLM(params.task, params.model);
    }
  },

  spawnShell: {
    description: 'Spawn a shell command',
    parameters: z.object({
      command: z.string().describe('Shell command to execute'),
      background: z.boolean().default(false).describe('Run in background')
    }),
    execute: async (params: any) => {
      const tool = new SpawnTool();
      return await tool.spawnShellCommand(params.command, params.background);
    }
  },

  spawnToNATS: {
    description: 'Spawn a message to NATS messaging system',
    parameters: z.object({
      subject: z.string().describe('NATS subject'),
      message: z.any().describe('Message to send')
    }),
    execute: async (params: any) => {
      const tool = new SpawnTool();
      return await tool.spawnToNATS(params.subject, params.message);
    }
  },

  checkSpawnedTask: {
    description: 'Check status of a spawned task',
    parameters: z.object({
      taskId: z.string().describe('Task ID to check')
    }),
    execute: async (params: any) => {
      const tool = new SpawnTool();
      return await tool.checkStatus(params.taskId);
    }
  },

  listSpawnedTasks: {
    description: 'List all spawned tasks',
    parameters: z.object({
      type: z.enum(['jules', 'llm', 'shell', 'nats', 'webhook']).optional(),
      status: z.enum(['spawned', 'running', 'completed', 'failed']).optional()
    }),
    execute: async (params: any) => {
      const tool = new SpawnTool();
      return tool.listTasks(params);
    }
  }
};