import { Logger } from './logger';

interface ToolCall {
  name: string;
  arguments: Record<string, any>;
}

interface ToolResult {
  success: boolean;
  result: any;
  error: string | null;
}

/**
 * MCP Client - communicates with remote backend server via HTTP
 */
export class MCP {
  private serverUrl: string;
  private logger: Logger;
  private initialized: boolean = false;

  constructor(serverUrl: string, logger: Logger) {
    // Ensure URL has protocol
    if (!serverUrl.startsWith('http://') && !serverUrl.startsWith('https://')) {
      serverUrl = `http://${serverUrl}`;
    }
    this.serverUrl = serverUrl;
    this.logger = logger;
  }

  /**
   * Initialize the MCP connection
   */
  async initialize(): Promise<void> {
    try {
      this.logger.log(`Connecting to MCP server: ${this.serverUrl}`);

      // Try a health check
      const response = await fetch(`${this.serverUrl}/health`, {
        method: 'GET',
        timeout: 5000
      });

      if (!response.ok) {
        throw new Error(`Server returned status ${response.status}`);
      }

      this.initialized = true;
      this.logger.log('MCP server connection established');
    } catch (error) {
      this.logger.error(`Failed to connect to MCP server: ${error}`);
      throw error;
    }
  }

  /**
   * Call a tool on the remote server
   */
  async call(toolName: string, args: Record<string, any>): Promise<ToolResult> {
    if (!this.initialized) {
      throw new Error('MCP not initialized');
    }

    const toolCall: ToolCall = {
      name: toolName,
      arguments: args
    };

    this.logger.log(`Calling: ${toolName} ${JSON.stringify(args)}`);

    try {
      const response = await fetch(`${this.serverUrl}/tool`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(toolCall),
        timeout: 30000
      });

      if (!response.ok) {
        throw new Error(`Server returned status ${response.status}`);
      }

      const result = (await response.json()) as ToolResult;
      this.logger.log(`Response: ${result.success ? 'success' : 'error'}`);

      return result;
    } catch (error) {
      this.logger.error(`Error calling tool: ${error}`);
      throw error;
    }
  }

  /**
   * Dispose the MCP connection
   */
  dispose() {
    this.logger.log('Closing MCP connection');
    this.initialized = false;
  }
}
