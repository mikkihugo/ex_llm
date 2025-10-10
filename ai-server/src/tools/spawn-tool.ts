/**
 * @file Spawn Tool for LLMs
 * @description This module provides a `SpawnTool` class that allows an LLM to delegate
 * tasks to various agents and services, such as Jules for autonomous coding, other LLMs,
 * shell commands, or NATS messages. It also defines AI SDK-compatible tool definitions
 * for these spawning capabilities.
 */

import { z } from 'zod';
import { jules } from '../providers/google-ai-jules';
import { TodoTool } from './todo-tool';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

/**
 * @interface SpawnedTask
 * @description Represents a task that has been spawned by the `SpawnTool`.
 */
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

/**
 * @class SpawnTool
 * @description A tool for spawning and managing delegated tasks.
 */
export class SpawnTool {
  private activeTasks: Map<string, SpawnedTask> = new Map();
  private todoTool = new TodoTool();

  /**
   * Spawns a task to the Jules autonomous coding agent.
   * @param {string} task The detailed description of the task for Jules.
   * @param {string} [githubRepo] The GitHub repository in "owner/repo" format.
   * @returns {Promise<SpawnedTask>} The spawned task object.
   */
  async spawnToJules(task: string, githubRepo?: string): Promise<SpawnedTask> {
    const taskId = `jules_${Date.now()}`;
    try {
      const [owner, repo] = (githubRepo || 'mhugo/singularity').split('/');
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
      await this.todoTool.add(`Jules: ${task}`, 'high', ['jules', 'automated']);
      return spawnedTask;
    } catch (error: any) {
      return { id: taskId, type: 'jules', target: 'jules', task, status: 'failed', createdAt: new Date(), error: error.message };
    }
  }

  /**
   * Spawns a task to another LLM for processing.
   * @param {string} task The task description.
   * @param {string} [model='gpt-5-codex'] The model to use for the task.
   * @returns {Promise<SpawnedTask>} The spawned task object.
   */
  async spawnToLLM(task: string, model = 'gpt-5-codex'): Promise<SpawnedTask> {
    const taskId = `llm_${Date.now()}`;
    const spawnedTask: SpawnedTask = { id: taskId, type: 'llm', target: model, task, status: 'spawned', createdAt: new Date() };
    this.activeTasks.set(taskId, spawnedTask);
    this.executeLLMTask(taskId, task, model);
    return spawnedTask;
  }

  /**
   * Spawns a shell command for execution.
   * @param {string} command The shell command to execute.
   * @param {boolean} [background=false] Whether to run the command in the background.
   * @returns {Promise<SpawnedTask>} The spawned task object.
   */
  async spawnShellCommand(command: string, background = false): Promise<SpawnedTask> {
    const taskId = `shell_${Date.now()}`;
    const spawnedTask: SpawnedTask = { id: taskId, type: 'shell', target: 'bash', task: command, status: 'spawned', createdAt: new Date() };
    this.activeTasks.set(taskId, spawnedTask);

    if (background) {
      exec(command, (error, stdout, stderr) => {
        const task = this.activeTasks.get(taskId);
        if (task) {
          task.status = error ? 'failed' : 'completed';
          task.error = error ? error.message : undefined;
          task.result = { stdout, stderr };
        }
      });
    } else {
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
   * Spawns a message to the NATS messaging system.
   * @param {string} subject The NATS subject to publish to.
   * @param {any} message The message payload.
   * @returns {Promise<SpawnedTask>} The spawned task object.
   */
  async spawnToNATS(subject: string, message: any): Promise<SpawnedTask> {
    const taskId = `nats_${Date.now()}`;
    const spawnedTask: SpawnedTask = { id: taskId, type: 'nats', target: subject, task: JSON.stringify(message), status: 'completed', createdAt: new Date() };
    this.activeTasks.set(taskId, spawnedTask);
    // TODO: Implement actual NATS publishing logic here.
    return spawnedTask;
  }

  /**
   * Checks the status of a previously spawned task.
   * @param {string} taskId The ID of the task to check.
   * @returns {Promise<SpawnedTask | null>} The task object with updated status, or null if not found.
   */
  async checkStatus(taskId: string): Promise<SpawnedTask | null> {
    const task = this.activeTasks.get(taskId);
    if (!task) return null;

    if (task.type === 'jules' && task.result?.sessionId) {
      try {
        const activities = await jules.listActivities(task.result.sessionId);
        if (activities.activities.length > 0) {
          task.status = 'running';
          const lastActivity = activities.activities.slice(-1)[0];
          if (lastActivity?.type === 'completed') {
            task.status = 'completed';
          }
        }
      } catch (error) {
        console.warn(`[SpawnTool] Failed to check Jules session status for task ${taskId}.`);
      }
    }
    return task;
  }

  /**
   * Lists all currently tracked spawned tasks.
   * @param {object} [filter] Optional filters for the task list.
   * @returns {SpawnedTask[]} An array of spawned tasks.
   */
  listTasks(filter?: { type?: SpawnedTask['type']; status?: SpawnedTask['status'] }): SpawnedTask[] {
    let tasks = Array.from(this.activeTasks.values());
    if (filter?.type) tasks = tasks.filter(t => t.type === filter.type);
    if (filter?.status) tasks = tasks.filter(t => t.status === filter.status);
    return tasks.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }

  /**
   * Executes an LLM task asynchronously.
   * @private
   */
  private async executeLLMTask(taskId: string, prompt: string, model: string) {
    const task = this.activeTasks.get(taskId);
    if (!task) return;
    task.status = 'running';
    try {
      // TODO: Replace this with an actual call to the LLM orchestration pipeline.
      await new Promise(resolve => setTimeout(resolve, 2000)); // Simulate network delay
      task.status = 'completed';
      task.result = { response: `Completed task: ${prompt}`, model, tokens: 100 };
    } catch (error: any) {
      task.status = 'failed';
      task.error = error.message;
    }
  }
}

/**
 * @const {object} spawnTools
 * @description An object containing AI SDK-compatible tool definitions for the SpawnTool.
 */
export const spawnTools = {
  spawnToJules: {
    description: 'Spawn a complex coding task to the Jules autonomous agent.',
    parameters: z.object({
      task: z.string().describe('A detailed description of the task for Jules.'),
      githubRepo: z.string().optional().describe('The target GitHub repository in "owner/repo" format.'),
    }),
    execute: async (params: any) => new SpawnTool().spawnToJules(params.task, params.githubRepo),
  },
  spawnToLLM: {
    description: 'Delegate a task to another LLM for processing.',
    parameters: z.object({
      task: z.string().describe('The task to be processed.'),
      model: z.string().default('gpt-5-codex').describe('The model to use for the task.'),
    }),
    execute: async (params: any) => new SpawnTool().spawnToLLM(params.task, params.model),
  },
  spawnShell: {
    description: 'Execute a shell command.',
    parameters: z.object({
      command: z.string().describe('The shell command to execute.'),
      background: z.boolean().default(false).describe('Whether to run the command in the background.'),
    }),
    execute: async (params: any) => new SpawnTool().spawnShellCommand(params.command, params.background),
  },
  spawnToNATS: {
    description: 'Publish a message to a NATS subject.',
    parameters: z.object({
      subject: z.string().describe('The NATS subject to publish the message to.'),
      message: z.any().describe('The message payload.'),
    }),
    execute: async (params: any) => new SpawnTool().spawnToNATS(params.subject, params.message),
  },
  checkSpawnedTask: {
    description: 'Check the status of a spawned task.',
    parameters: z.object({
      taskId: z.string().describe('The ID of the task to check.'),
    }),
    execute: async (params: any) => new SpawnTool().checkStatus(params.taskId),
  },
  listSpawnedTasks: {
    description: 'List all spawned tasks, with optional filters.',
    parameters: z.object({
      type: z.enum(['jules', 'llm', 'shell', 'nats', 'webhook']).optional(),
      status: z.enum(['spawned', 'running', 'completed', 'failed']).optional(),
    }),
    execute: async (params: any) => new SpawnTool().listTasks(params),
  },
};