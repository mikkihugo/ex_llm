/**
 * Google Jules AI Agent Provider
 *
 * Jules is Google's autonomous AI coding agent from Google Labs.
 * It can handle complex coding tasks, fix bugs, and integrate with GitHub.
 *
 * Features:
 * - Autonomous code generation and bug fixing
 * - GitHub integration for issues and PRs
 * - Multi-file editing capabilities
 * - Test generation and execution
 *
 * Limits (Free Tier):
 * - 15 tasks per day
 * - Max 3 concurrent sessions
 * - Upgrade to Pro ($19.99/mo) for ~75 tasks/day
 * - Upgrade to Ultra ($124.99/mo) for ~300 tasks/day
 */

import { z } from 'zod';

// Jules API configuration
// Jules is available via Google Labs with official API
const JULES_API_ENDPOINT = process.env.JULES_API_ENDPOINT || 'https://jules.googleapis.com/v1alpha';
const JULES_API_KEY = process.env.JULES_API_KEY || process.env.GOOGLE_AI_STUDIO_API_KEY;

// Jules uses Gemini 2.5 Pro under the hood
// When Jules API becomes public, this will switch to the official endpoint

export interface JulesConfig {
  apiKey?: string;
  endpoint?: string;
  projectId?: string;
  githubToken?: string; // For GitHub integration
}

export interface JulesSource {
  name: string; // e.g., "sources/github/owner/repo"
  id: string;
  githubRepo?: {
    owner: string;
    repo: string;
  };
}

export interface JulesSession {
  name?: string; // e.g., "sessions/31415926535897932384"
  id?: string;
  title: string;
  prompt: string;
  sourceContext: {
    source: string; // Source name from list sources
    githubRepoContext?: {
      startingBranch?: string;
    };
  };
  requirePlanApproval?: boolean;
}

export interface JulesActivity {
  type: string;
  content: string;
  timestamp: string;
}

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
   * List available sources (GitHub repos connected to Jules)
   */
  async listSources(): Promise<{ sources: JulesSource[] }> {
    const response = await fetch(`${this.config.endpoint}/sources`, {
      headers: {
        'X-Goog-Api-Key': this.config.apiKey!,
      },
    });

    if (!response.ok) {
      throw new Error(`Failed to list sources: ${response.statusText}`);
    }

    return await response.json();
  }

  /**
   * Create a new Jules session for autonomous coding
   */
  async createSession(session: JulesSession): Promise<JulesSession> {
    if (!this.config.apiKey) {
      throw new Error('Jules requires API key. Set JULES_API_KEY environment variable');
    }

    const response = await fetch(`${this.config.endpoint}/sessions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': this.config.apiKey,
      },
      body: JSON.stringify(session),
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Jules API error: ${response.status} - ${error}`);
    }

    return await response.json();
  }

  /**
   * List activities in a session
   */
  async listActivities(sessionId: string, pageSize: number = 30): Promise<{ activities: JulesActivity[] }> {
    const response = await fetch(`${this.config.endpoint}/sessions/${sessionId}/activities?pageSize=${pageSize}`, {
      headers: {
        'X-Goog-Api-Key': this.config.apiKey!,
      },
    });

    if (!response.ok) {
      throw new Error(`Failed to list activities: ${response.statusText}`);
    }

    return await response.json();
  }

  /**
   * Send a message to Jules in an existing session
   */
  async sendMessage(sessionId: string, prompt: string): Promise<void> {
    const response = await fetch(`${this.config.endpoint}/sessions/${sessionId}:sendMessage`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': this.config.apiKey!,
      },
      body: JSON.stringify({ prompt }),
    });

    if (!response.ok) {
      throw new Error(`Failed to send message: ${response.statusText}`);
    }
  }

  /**
   * Approve plan for a session (if requirePlanApproval was set)
   */
  async approvePlan(sessionId: string): Promise<void> {
    const response = await fetch(`${this.config.endpoint}/sessions/${sessionId}:approvePlan`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': this.config.apiKey!,
      },
    });

    if (!response.ok) {
      throw new Error(`Failed to approve plan: ${response.statusText}`);
    }
  }

  /**
   * Helper: Create a session for a GitHub repo task
   */
  async createGitHubTask(owner: string, repo: string, prompt: string, branch: string = 'main'): Promise<JulesSession> {
    // First, try to find the source
    const sources = await this.listSources();
    const sourceId = `github/${owner}/${repo}`;
    const source = sources.sources.find(s => s.id === sourceId);

    if (!source) {
      throw new Error(`GitHub repo ${owner}/${repo} not connected to Jules. Please connect it at https://jules.google`);
    }

    return this.createSession({
      prompt,
      title: prompt.slice(0, 50),
      sourceContext: {
        source: source.name,
        githubRepoContext: {
          startingBranch: branch,
        },
      },
      requirePlanApproval: false, // Auto-approve for API calls
    });
  }
}

// Export singleton instance
export const jules = new JulesProvider();

/**
 * AI SDK compatible model wrapper for Jules
 */
export function createJulesModel(taskType: JulesTask['type'] = 'feature') {
  return {
    id: 'google-jules',
    provider: 'google-jules',

    async doGenerate(options: any) {
      const task: JulesTask = {
        type: taskType,
        description: options.prompt || options.messages?.map((m: any) => m.content).join('\n'),
        context: {
          files: options.files,
        },
      };

      const response = await jules.submitTask(task);

      // Wait for completion
      let finalResponse = response;
      while (finalResponse.status === 'in_progress') {
        await new Promise(resolve => setTimeout(resolve, 1000));
        finalResponse = await jules.getTaskStatus(response.taskId);
      }

      return {
        text: finalResponse.summary,
        usage: {
          promptTokens: 0,
          completionTokens: 0,
        },
        finishReason: finalResponse.status === 'completed' ? 'stop' : 'error',
        metadata: {
          changes: finalResponse.changes,
          testsRun: finalResponse.testsRun,
          testsPassed: finalResponse.testsPassed,
        },
      };
    },

    async doStream(options: any) {
      const task: JulesTask = {
        type: taskType,
        description: options.prompt || options.messages?.map((m: any) => m.content).join('\n'),
      };

      const response = await jules.submitTask(task);

      return {
        async *stream() {
          for await (const update of jules.streamTaskProgress(response.taskId)) {
            yield {
              type: 'text',
              text: update.summary,
            };
          }
        },
      };
    },
  };
}