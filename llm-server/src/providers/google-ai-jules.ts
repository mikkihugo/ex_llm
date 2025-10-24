/**
 * @file Google Jules AI Agent Provider
 * @description This module provides a client for interacting with Google's Jules,
 * an autonomous AI coding agent. It supports creating and managing coding sessions,
 * especially for tasks integrated with GitHub.
 */



const JULES_API_ENDPOINT = process.env.JULES_API_ENDPOINT || 'https://jules.googleapis.com/v1alpha';
const JULES_API_KEY = process.env.JULES_API_KEY || process.env.GOOGLE_AI_STUDIO_API_KEY;

/**
 * @interface JulesConfig
 * @description Configuration for the Jules provider.
 */
export interface JulesConfig {
  apiKey?: string;
  endpoint?: string;
  projectId?: string;
  githubToken?: string;
}

/**
 * @interface JulesSource
 * @description Represents a source repository connected to Jules.
 */
export interface JulesSource {
  name: string;
  id: string;
  githubRepo?: {
    owner: string;
    repo: string;
  };
}

/**
 * @interface JulesSession
 * @description Represents a coding session with Jules.
 */
export interface JulesSession {
  name?: string;
  id?: string;
  title: string;
  prompt: string;
  sourceContext: {
    source: string;
    githubRepoContext?: {
      startingBranch?: string;
    };
  };
  requirePlanApproval?: boolean;
}

/**
 * @interface JulesActivity
 * @description Represents a single activity or event within a Jules session.
 */
export interface JulesActivity {
  type: string;
  content: string;
  timestamp: string;
}

type JulesTaskType = 'feature' | 'bug_fix' | 'test_generation';

interface JulesTask {
  type: JulesTaskType;
  description: string;
  context?: {
    files?: unknown;
  };
}

/**
 * @class JulesProvider
 * @description A client for interacting with the Google Jules API.
 */
export class JulesProvider {
  private config: JulesConfig;

  constructor(config?: JulesConfig) {
    this.config = {
      apiKey: config?.apiKey || JULES_API_KEY,
      endpoint: config?.endpoint || JULES_API_ENDPOINT,
      projectId: config?.projectId,
      githubToken: config?.githubToken || process.env.GITHUB_TOKEN,
    };
  }

  /**
   * Lists available sources, such as connected GitHub repositories.
   * @returns {Promise<{ sources: JulesSource[] }>} A list of available sources.
   */
  async listSources(): Promise<{ sources: JulesSource[] }> {
    const response = await fetch(`${this.config.endpoint}/sources`, { headers: { 'X-Goog-Api-Key': this.config.apiKey! } });
    return await response.json() as { sources: JulesSource[] };
  }

  /**
   * Creates a new autonomous coding session with Jules.
   * @param {JulesSession} session The session configuration.
   * @returns {Promise<JulesSession>} The created session object.
   */
  async createSession(session: JulesSession): Promise<JulesSession> {
    if (!this.config.apiKey) throw new Error('Jules requires an API key.');
    const response = await fetch(`${this.config.endpoint}/sessions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Goog-Api-Key': this.config.apiKey },
      body: JSON.stringify(session),
    });
    return await response.json() as JulesSession;
  }

  /**
   * Lists the activities for a given session.
   * @param {string} sessionId The ID of the session.
   * @param {number} [pageSize=30] The number of activities to retrieve.
   * @returns {Promise<{ activities: JulesActivity[] }>} A list of session activities.
   */
  async listActivities(sessionId: string, pageSize = 30): Promise<{ activities: JulesActivity[] }> {
    const response = await fetch(`${this.config.endpoint}/sessions/${sessionId}/activities?pageSize=${pageSize}`, { headers: { 'X-Goog-Api-Key': this.config.apiKey! } });
    return await response.json() as { activities: JulesActivity[] };
  }

  /**
   * Sends a message to an existing Jules session.
   * @param {string} sessionId The ID of the session.
   * @param {string} prompt The message to send.
   */
  async sendMessage(sessionId: string, prompt: string): Promise<void> {
    const response = await fetch(`${this.config.endpoint}/sessions/${sessionId}:sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Goog-Api-Key': this.config.apiKey! },
      body: JSON.stringify({ prompt }),
    });
    if (!response.ok) throw new Error(`Failed to send message: ${response.statusText}`);
  }

  /**
   * Approves a plan proposed by Jules in a session.
   * @param {string} sessionId The ID of the session.
   */
  async approvePlan(sessionId: string): Promise<void> {
    const response = await fetch(`${this.config.endpoint}/sessions/${sessionId}:approvePlan`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Goog-Api-Key': this.config.apiKey! },
    });
    if (!response.ok) throw new Error(`Failed to approve plan: ${response.statusText}`);
  }

  /**
   * A helper method to create a Jules session for a task in a GitHub repository.
   * @param {string} owner The repository owner.
   * @param {string} repo The repository name.
   * @param {string} prompt The task prompt.
   * @param {string} [branch='main'] The starting branch.
   * @returns {Promise<JulesSession>} The created session object.
   */
  async createGitHubTask(owner: string, repo: string, prompt: string, branch = 'main'): Promise<JulesSession> {
    const sources = await this.listSources();
    const source = sources.sources.find(s => s.id === `github/${owner}/${repo}`);
    if (!source) throw new Error(`GitHub repo ${owner}/${repo} not connected to Jules.`);
    return this.createSession({
      prompt,
      title: prompt.slice(0, 50),
      sourceContext: { source: source.name, githubRepoContext: { startingBranch: branch } },
      requirePlanApproval: false,
    });
  }

  /**
   * Task submission and monitoring - deferred implementation.
   *
   * These methods are defined in the interface but not yet implemented.
   * They will enable:
   * - submitTask: Submit work to Claude Projects or similar task service
   * - getTaskStatus: Poll for task completion status
   * - streamTaskProgress: Stream real-time task progress updates
   *
   * Planned for: When Claude Projects API becomes available
   */
  async submitTask(_task: any): Promise<any> { throw new Error("Task submission not yet implemented (planned for Claude Projects API)"); }
  async getTaskStatus(_taskId: any): Promise<any> { throw new Error("Task status polling not yet implemented"); }
  async *streamTaskProgress(_taskId: any): AsyncIterableIterator<any> { throw new Error("Task progress streaming not yet implemented"); }
}

export const jules = new JulesProvider();

/**
 * Creates an AI SDK-compatible model wrapper for the Jules provider.
 * @param {JulesTaskType} [taskType='feature'] The type of task for the model.
 * @returns {object} An AI SDK-compatible model object.
 */
export function createJulesModel(taskType: JulesTask['type'] = 'feature') {
  return {
    id: 'google-jules',
    provider: 'google-jules',
    async doGenerate(options: any) {
      const task: JulesTask = { type: taskType, description: options.prompt || options.messages?.map((m: any) => m.content).join('\n'), context: { files: options.files } };
      const response = await jules.submitTask(task);
      let finalResponse = response;
      while (finalResponse.status === 'in_progress') {
        await new Promise(resolve => setTimeout(resolve, 1000));
        finalResponse = await jules.getTaskStatus(response.taskId);
      }
      return {
        text: finalResponse.summary,
        usage: { promptTokens: 0, completionTokens: 0 },
        finishReason: finalResponse.status === 'completed' ? 'stop' : 'error',
        metadata: { changes: finalResponse.changes, testsRun: finalResponse.testsRun, testsPassed: finalResponse.testsPassed },
      };
    },
    async doStream(options: any) {
      const task: JulesTask = { type: taskType, description: options.prompt || options.messages?.map((m: any) => m.content).join('\n') };
      const response = await jules.submitTask(task);
      return {
        async *stream() {
          for await (const update of jules.streamTaskProgress(response.taskId)) {
            yield { type: 'text', text: update.summary };
          }
        },
      };
    },
  };
}

/**
 * @const {Array<object>} JULES_MODELS
 * @description A static list of available Jules models and their metadata.
 */
export const JULES_MODELS = [
  {
    id: 'jules-v1',
    displayName: 'Google Jules',
    description: 'Autonomous AI coding agent for complex tasks',
    contextWindow: 2097152,
    capabilities: { completion: true, streaming: true, reasoning: false, vision: false, tools: true },
    cost: 'free' as const,
  },
] as const;

/**
 * @interface JulesProviderWithModels
 * @extends ReturnType<typeof createJulesModel>
 * @description Extends the base Jules provider to include a `listModels` method.
 */
export interface JulesProviderWithModels extends ReturnType<typeof createJulesModel> {
  listModels(): typeof JULES_MODELS;
}

/**
 * @const {JulesProviderWithModels} julesWithModels
 * @description The public instance of the Jules provider, extended with model listing capabilities.
 */
export const julesWithModels = Object.assign(jules, {
  listModels: () => JULES_MODELS,
}) as unknown as JulesProviderWithModels;

/**
 * A backward-compatibility helper to map a model ID to a Jules model instance.
 * @param {string} modelId The ID of the model.
 * @returns {object} A configured Jules model instance.
 */
export function julesWithMetadata(modelId: string) {
  const normalized = modelId?.toLowerCase();
  const taskType: JulesTaskType =
    normalized?.includes('bug') ? 'bug_fix' :
    normalized?.includes('test') ? 'test_generation' :
    'feature';
  return createJulesModel(taskType);
}