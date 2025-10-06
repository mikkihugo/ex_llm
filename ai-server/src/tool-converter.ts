/**
 * Tool Format Converter
 *
 * Converts tools from OpenAI format (from Elixir) to AI SDK format.
 * AI SDK will automatically handle provider-specific conversion (MCP, Anthropic, etc.)
 */

import { tool } from 'ai';
import { z } from 'zod';

/**
 * OpenAI tool format (what Elixir sends)
 */
export interface OpenAITool {
  type: 'function';
  function: {
    name: string;
    description?: string;
    parameters: {
      type: 'object';
      properties: Record<string, any>;
      required?: string[];
    };
  };
}

/**
 * Convert OpenAI JSON Schema to Zod schema
 */
function jsonSchemaToZod(schema: any): z.ZodTypeAny {
  if (schema.type === 'object') {
    const shape: Record<string, z.ZodTypeAny> = {};

    for (const [key, value] of Object.entries(schema.properties || {})) {
      const prop = value as any;
      let zodType: z.ZodTypeAny;

      switch (prop.type) {
        case 'string':
          zodType = z.string();
          if (prop.description) {
            zodType = zodType.describe(prop.description);
          }
          break;
        case 'number':
          zodType = z.number();
          if (prop.description) {
            zodType = zodType.describe(prop.description);
          }
          break;
        case 'boolean':
          zodType = z.boolean();
          if (prop.description) {
            zodType = zodType.describe(prop.description);
          }
          break;
        case 'array':
          zodType = z.array(jsonSchemaToZod(prop.items || { type: 'string' }));
          if (prop.description) {
            zodType = zodType.describe(prop.description);
          }
          break;
        case 'object':
          zodType = jsonSchemaToZod(prop);
          break;
        default:
          zodType = z.any();
      }

      // Make optional if not in required array
      if (!schema.required?.includes(key)) {
        zodType = zodType.optional();
      }

      shape[key] = zodType;
    }

    return z.object(shape);
  }

  return z.any();
}

/**
 * Convert OpenAI tools to AI SDK tools
 *
 * @param openaiTools - Tools in OpenAI format from Elixir
 * @param executeHandler - Function to execute tools (calls Elixir via NATS)
 * @returns Tools in AI SDK format
 */
export function convertOpenAIToolsToAISDK(
  openaiTools: OpenAITool[],
  executeHandler: (toolName: string, args: any) => Promise<any>
) {
  const tools: Record<string, ReturnType<typeof tool>> = {};

  for (const openaiTool of openaiTools) {
    const { name, description, parameters } = openaiTool.function;

    // Convert JSON Schema to Zod
    const zodSchema = jsonSchemaToZod(parameters);

    // Create AI SDK tool
    tools[name] = tool({
      description: description || `Execute ${name}`,
      parameters: zodSchema,
      execute: async (args) => {
        try {
          const result = await executeHandler(name, args);
          return result;
        } catch (error) {
          console.error(`Tool ${name} execution failed:`, error);
          throw error;
        }
      }
    });
  }

  return tools;
}

/**
 * Example OpenAI tools from Elixir
 */
export const EXAMPLE_OPENAI_TOOLS: OpenAITool[] = [
  {
    type: 'function',
    function: {
      name: 'shell',
      description: 'Execute a shell command',
      parameters: {
        type: 'object',
        properties: {
          command: {
            type: 'string',
            description: 'The shell command to execute'
          }
        },
        required: ['command']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'read_file',
      description: 'Read contents of a file',
      parameters: {
        type: 'object',
        properties: {
          path: {
            type: 'string',
            description: 'Path to the file'
          }
        },
        required: ['path']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'write_file',
      description: 'Write contents to a file',
      parameters: {
        type: 'object',
        properties: {
          path: {
            type: 'string',
            description: 'Path to the file'
          },
          content: {
            type: 'string',
            description: 'Content to write'
          }
        },
        required: ['path', 'content']
      }
    }
  }
];
