/**
 * @file Tool Format Converter
 * @description This module provides utilities to convert tool definitions from the
 * OpenAI format (as sent by the Elixir backend) to the Vercel AI SDK format.
 * The AI SDK then handles the provider-specific conversions (e.g., to MCP, Anthropic, etc.).
 */

import { tool } from 'ai';
import { z } from 'zod';

/**
 * @interface OpenAITool
 * @description Represents the structure of a tool in the OpenAI format,
 * which is the format expected from the Elixir backend.
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
 * Converts a JSON Schema object to a Zod schema.
 * @private
 * @param {any} schema The JSON Schema to convert.
 * @returns {z.ZodTypeAny} The equivalent Zod schema.
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
 * Converts an array of tools from the OpenAI format to the AI SDK format.
 * @param {OpenAITool[]} openaiTools An array of tools in the OpenAI format.
 * @param {(toolName: string, args: any) => Promise<any>} executeHandler A function to handle the execution of the tool.
 * @returns {Record<string, ReturnType<typeof tool>>} A map of tool names to their AI SDK tool definitions.
 */
export function convertOpenAIToolsToAISDK(
  openaiTools: OpenAITool[],
  executeHandler: (toolName: string, args: any) => Promise<any>
) {
  const tools: Record<string, ReturnType<typeof tool>> = {};

  for (const openaiTool of openaiTools) {
    const { name, description, parameters } = openaiTool.function;
    const zodSchema = jsonSchemaToZod(parameters);

    tools[name] = tool({
      description: description || `Execute the ${name} tool.`,
      parameters: zodSchema,
      execute: async (args) => {
        try {
          return await executeHandler(name, args);
        } catch (error) {
          console.error(`[ToolConverter] Tool execution failed for "${name}":`, error);
          throw error;
        }
      }
    });
  }

  return tools;
}

/**
 * @const {OpenAITool[]} EXAMPLE_OPENAI_TOOLS
 * @description An example set of tools in the OpenAI format for testing and demonstration.
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