/**
 * TODO Management Tool for LLMs
 *
 * Simple tool that LLMs can use to manage a TODO list.
 * This integrates with AI models to track tasks.
 */

import * as fs from 'fs/promises';
import { z } from 'zod';

// Schema for TODO items
const TodoSchema = z.object({
  id: z.string(),
  task: z.string(),
  priority: z.enum(['low', 'medium', 'high', 'critical']),
  status: z.enum(['pending', 'in_progress', 'completed', 'blocked']),
  assignee: z.string().optional(),
  createdAt: z.string(),
  updatedAt: z.string(),
  completedAt: z.string().optional(),
  tags: z.array(z.string()).optional(),
  dependencies: z.array(z.string()).optional(),
});

type Todo = z.infer<typeof TodoSchema>;

export class TodoTool {
  private todos: Map<string, Todo> = new Map();
  private filePath = '.todos.json';

  constructor() {
    this.load();
  }

  private async load() {
    try {
      const data = await fs.readFile(this.filePath, 'utf-8');
      const parsed = JSON.parse(data);
      this.todos = new Map(parsed.todos);
    } catch {
      // File doesn't exist, start fresh
    }
  }

  private async save() {
    await fs.writeFile(this.filePath, JSON.stringify({
      todos: Array.from(this.todos.entries()),
      lastUpdated: new Date().toISOString()
    }, null, 2));
  }

  /**
   * Add a new TODO item
   */
  async add(task: string, priority: Todo['priority'] = 'medium', tags?: string[]): Promise<Todo> {
    const id = `todo_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const todo: Todo = {
      id,
      task,
      priority,
      status: 'pending',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      tags
    };

    this.todos.set(id, todo);
    await this.save();
    return todo;
  }

  /**
   * List TODOs with optional filtering
   */
  async list(filter?: {
    status?: Todo['status'];
    priority?: Todo['priority'];
    assignee?: string;
    tag?: string;
  }): Promise<Todo[]> {
    let todos = Array.from(this.todos.values());

    if (filter) {
      if (filter.status) {
        todos = todos.filter(t => t.status === filter.status);
      }
      if (filter.priority) {
        todos = todos.filter(t => t.priority === filter.priority);
      }
      if (filter.assignee) {
        todos = todos.filter(t => t.assignee === filter.assignee);
      }
      if (filter.tag) {
        todos = todos.filter(t => t.tags?.includes(filter.tag));
      }
    }

    // Sort by priority and status
    const priorityOrder = { critical: 0, high: 1, medium: 2, low: 3 };
    const statusOrder = { blocked: 0, in_progress: 1, pending: 2, completed: 3 };

    todos.sort((a, b) => {
      const statusDiff = statusOrder[a.status] - statusOrder[b.status];
      if (statusDiff !== 0) return statusDiff;
      return priorityOrder[a.priority] - priorityOrder[b.priority];
    });

    return todos;
  }

  /**
   * Update TODO status
   */
  async updateStatus(id: string, status: Todo['status']): Promise<Todo | null> {
    const todo = this.todos.get(id);
    if (!todo) return null;

    todo.status = status;
    todo.updatedAt = new Date().toISOString();

    if (status === 'completed') {
      todo.completedAt = new Date().toISOString();
    }

    this.todos.set(id, todo);
    await this.save();
    return todo;
  }

  /**
   * Assign TODO to someone/something
   */
  async assign(id: string, assignee: string): Promise<Todo | null> {
    const todo = this.todos.get(id);
    if (!todo) return null;

    todo.assignee = assignee;
    todo.updatedAt = new Date().toISOString();

    this.todos.set(id, todo);
    await this.save();
    return todo;
  }

  /**
   * Delete a TODO
   */
  async delete(id: string): Promise<boolean> {
    const deleted = this.todos.delete(id);
    if (deleted) {
      await this.save();
    }
    return deleted;
  }

  /**
   * Get summary statistics
   */
  async getStats(): Promise<{
    total: number;
    byStatus: Record<Todo['status'], number>;
    byPriority: Record<Todo['priority'], number>;
    assigned: number;
    unassigned: number;
  }> {
    const todos = Array.from(this.todos.values());

    const stats = {
      total: todos.length,
      byStatus: {
        pending: 0,
        in_progress: 0,
        completed: 0,
        blocked: 0
      },
      byPriority: {
        low: 0,
        medium: 0,
        high: 0,
        critical: 0
      },
      assigned: 0,
      unassigned: 0
    };

    for (const todo of todos) {
      stats.byStatus[todo.status]++;
      stats.byPriority[todo.priority]++;
      if (todo.assignee) {
        stats.assigned++;
      } else {
        stats.unassigned++;
      }
    }

    return stats;
  }
}

/**
 * AI SDK Tool Definition for TODO management
 */
export const todoTools = {
  addTodo: {
    description: 'Add a new TODO item to the list',
    parameters: z.object({
      task: z.string().describe('The task description'),
      priority: z.enum(['low', 'medium', 'high', 'critical']).default('medium').describe('Task priority'),
      tags: z.array(z.string()).optional().describe('Tags for categorization')
    }),
    execute: async (params: any) => {
      const tool = new TodoTool();
      return await tool.add(params.task, params.priority, params.tags);
    }
  },

  listTodos: {
    description: 'List TODO items with optional filtering',
    parameters: z.object({
      status: z.enum(['pending', 'in_progress', 'completed', 'blocked']).optional(),
      priority: z.enum(['low', 'medium', 'high', 'critical']).optional(),
      assignee: z.string().optional(),
      tag: z.string().optional()
    }),
    execute: async (params: any) => {
      const tool = new TodoTool();
      return await tool.list(params);
    }
  },

  updateTodoStatus: {
    description: 'Update the status of a TODO item',
    parameters: z.object({
      id: z.string().describe('TODO ID'),
      status: z.enum(['pending', 'in_progress', 'completed', 'blocked']).describe('New status')
    }),
    execute: async (params: any) => {
      const tool = new TodoTool();
      return await tool.updateStatus(params.id, params.status);
    }
  },

  assignTodo: {
    description: 'Assign a TODO to someone or something (like Jules)',
    parameters: z.object({
      id: z.string().describe('TODO ID'),
      assignee: z.string().describe('Who/what to assign to (e.g., "jules", "user", "gpt-5")')
    }),
    execute: async (params: any) => {
      const tool = new TodoTool();
      return await tool.assign(params.id, params.assignee);
    }
  },

  getTodoStats: {
    description: 'Get statistics about current TODOs',
    parameters: z.object({}),
    execute: async () => {
      const tool = new TodoTool();
      return await tool.getStats();
    }
  }
};