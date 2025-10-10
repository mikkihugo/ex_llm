/**
 * @file TODO Management Tool for LLMs
 * @description This module provides a simple `TodoTool` class that allows language models
 * to manage a persistent TODO list. It includes functionalities for adding, listing,
 * updating, and getting statistics about TODO items.
 */

import * as fs from 'fs/promises';
import { z } from 'zod';

/**
 * @const {z.ZodObject} TodoSchema
 * @description The Zod schema for a TODO item, defining its structure and types.
 */
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

/**
 * @class TodoTool
 * @description A class for managing a TODO list, with methods for CRUD operations and stats.
 */
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
      // File doesn't exist, start fresh.
    }
  }

  private async save() {
    await fs.writeFile(this.filePath, JSON.stringify({
      todos: Array.from(this.todos.entries()),
      lastUpdated: new Date().toISOString()
    }, null, 2));
  }

  /**
   * Adds a new TODO item to the list.
   * @param {string} task The description of the task.
   * @param {Todo['priority']} [priority='medium'] The priority of the task.
   * @param {string[]} [tags] Optional tags for categorization.
   * @returns {Promise<Todo>} The newly created TODO item.
   */
  async add(task: string, priority: Todo['priority'] = 'medium', tags?: string[]): Promise<Todo> {
    const id = `todo_${Date.now()}`;
    const todo: Todo = {
      id, task, priority, status: 'pending',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      tags
    };
    this.todos.set(id, todo);
    await this.save();
    return todo;
  }

  /**
   * Lists TODO items, with optional filtering.
   * @param {object} [filter] Optional filters for the list.
   * @returns {Promise<Todo[]>} A sorted and filtered list of TODO items.
   */
  async list(filter?: {
    status?: Todo['status'];
    priority?: Todo['priority'];
    assignee?: string;
    tag?: string;
  }): Promise<Todo[]> {
    let todos = Array.from(this.todos.values());
    if (filter) {
      if (filter.status) todos = todos.filter(t => t.status === filter.status);
      if (filter.priority) todos = todos.filter(t => t.priority === filter.priority);
      if (filter.assignee) todos = todos.filter(t => t.assignee === filter.assignee);
      if (filter.tag) todos = todos.filter(t => t.tags?.includes(filter.tag!));
    }

    const priorityOrder = { critical: 0, high: 1, medium: 2, low: 3 };
    const statusOrder = { blocked: 0, in_progress: 1, pending: 2, completed: 3 };
    todos.sort((a, b) => (statusOrder[a.status] - statusOrder[b.status]) || (priorityOrder[a.priority] - priorityOrder[b.priority]));
    return todos;
  }

  /**
   * Updates the status of a TODO item.
   * @param {string} id The ID of the TODO item to update.
   * @param {Todo['status']} status The new status for the item.
   * @returns {Promise<Todo | null>} The updated TODO item, or null if not found.
   */
  async updateStatus(id: string, status: Todo['status']): Promise<Todo | null> {
    const todo = this.todos.get(id);
    if (!todo) return null;
    todo.status = status;
    todo.updatedAt = new Date().toISOString();
    if (status === 'completed') todo.completedAt = new Date().toISOString();
    this.todos.set(id, todo);
    await this.save();
    return todo;
  }

  /**
   * Assigns a TODO item to a user or service.
   * @param {string} id The ID of the TODO item.
   * @param {string} assignee The name of the assignee.
   * @returns {Promise<Todo | null>} The updated TODO item, or null if not found.
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
   * Deletes a TODO item.
   * @param {string} id The ID of the TODO item to delete.
   * @returns {Promise<boolean>} True if the item was deleted, false otherwise.
   */
  async delete(id: string): Promise<boolean> {
    const deleted = this.todos.delete(id);
    if (deleted) await this.save();
    return deleted;
  }

  /**
   * Gets summary statistics for the TODO list.
   * @returns {Promise<object>} An object containing the summary statistics.
   */
  async getStats(): Promise<any> {
    const todos = Array.from(this.todos.values());
    const stats = {
      total: todos.length,
      byStatus: { pending: 0, in_progress: 0, completed: 0, blocked: 0 },
      byPriority: { low: 0, medium: 0, high: 0, critical: 0 },
      assigned: 0,
      unassigned: 0,
    };
    for (const todo of todos) {
      stats.byStatus[todo.status]++;
      stats.byPriority[todo.priority]++;
      if (todo.assignee) stats.assigned++;
      else stats.unassigned++;
    }
    return stats;
  }
}

/**
 * @const {object} todoTools
 * @description An object containing AI SDK-compatible tool definitions for the TodoTool.
 */
export const todoTools = {
  addTodo: {
    description: 'Add a new TODO item to the list.',
    parameters: z.object({
      task: z.string().describe('The task description.'),
      priority: z.enum(['low', 'medium', 'high', 'critical']).default('medium'),
      tags: z.array(z.string()).optional(),
    }),
    execute: async (params: any) => new TodoTool().add(params.task, params.priority, params.tags),
  },
  listTodos: {
    description: 'List TODO items with optional filters.',
    parameters: z.object({
      status: z.enum(['pending', 'in_progress', 'completed', 'blocked']).optional(),
      priority: z.enum(['low', 'medium', 'high', 'critical']).optional(),
      assignee: z.string().optional(),
      tag: z.string().optional(),
    }),
    execute: async (params: any) => new TodoTool().list(params),
  },
  updateTodoStatus: {
    description: 'Update the status of a TODO item.',
    parameters: z.object({
      id: z.string().describe('The ID of the TODO item.'),
      status: z.enum(['pending', 'in_progress', 'completed', 'blocked']),
    }),
    execute: async (params: any) => new TodoTool().updateStatus(params.id, params.status),
  },
  assignTodo: {
    description: 'Assign a TODO to someone or something.',
    parameters: z.object({
      id: z.string().describe('The ID of the TODO item.'),
      assignee: z.string().describe('The name of the assignee (e.g., "jules", "user").'),
    }),
    execute: async (params: any) => new TodoTool().assign(params.id, params.assignee),
  },
  getTodoStats: {
    description: 'Get statistics about the current TODO list.',
    parameters: z.object({}),
    execute: async () => new TodoTool().getStats(),
  },
};