import { describe, test, expect } from 'bun:test';
import { convertOpenAIToolsToAISDK, EXAMPLE_OPENAI_TOOLS } from '../tool-converter';

describe('Tool Converter', () => {
  test('converts OpenAI tools to AI SDK format', async () => {
    const mockExecute = async (toolName: string, args: any) => {
      return { success: true, toolName, args };
    };

    const tools = convertOpenAIToolsToAISDK(EXAMPLE_OPENAI_TOOLS, mockExecute);

    // Check that tools were converted
    expect(Object.keys(tools)).toHaveLength(3);
    expect(tools).toHaveProperty('shell');
    expect(tools).toHaveProperty('read_file');
    expect(tools).toHaveProperty('write_file');
  });

  test('shell tool has correct structure', async () => {
    const mockExecute = async (toolName: string, args: any) => {
      return { success: true, toolName, args };
    };

    const tools = convertOpenAIToolsToAISDK(EXAMPLE_OPENAI_TOOLS, mockExecute);
    const shellTool = tools['shell'];

    expect(shellTool).toBeDefined();
    expect(shellTool.description).toBe('Execute a shell command');
    expect(shellTool.parameters).toBeDefined();
  });

  test('tool execution calls handler', async () => {
    let capturedToolName = '';
    let capturedArgs: any = null;

    const mockExecute = async (toolName: string, args: any) => {
      capturedToolName = toolName;
      capturedArgs = args;
      return { result: 'mocked' };
    };

    const tools = convertOpenAIToolsToAISDK(EXAMPLE_OPENAI_TOOLS, mockExecute);
    const shellTool = tools['shell'];

    const result = await shellTool.execute({ command: 'ls -la' });

    expect(capturedToolName).toBe('shell');
    expect(capturedArgs).toEqual({ command: 'ls -la' });
    expect(result).toEqual({ result: 'mocked' });
  });

  test('handles empty tools array', () => {
    const tools = convertOpenAIToolsToAISDK([], async () => ({}));
    expect(Object.keys(tools)).toHaveLength(0);
  });

  test('handles complex parameter types', async () => {
    const complexTool = [{
      type: 'function' as const,
      function: {
        name: 'complex_tool',
        description: 'A complex tool',
        parameters: {
          type: 'object' as const,
          properties: {
            name: { type: 'string' },
            age: { type: 'number' },
            active: { type: 'boolean' },
            tags: { type: 'array', items: { type: 'string' } },
            metadata: {
              type: 'object',
              properties: {
                key: { type: 'string' }
              }
            }
          },
          required: ['name', 'age']
        }
      }
    }];

    const tools = convertOpenAIToolsToAISDK(complexTool, async () => ({}));
    expect(tools).toHaveProperty('complex_tool');
  });
});
