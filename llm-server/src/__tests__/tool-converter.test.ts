import { describe, test, expect } from 'bun:test';
import { convertOpenAIToolsToAISDK, EXAMPLE_OPENAI_TOOLS } from '../tool-converter';

describe('Tool Converter', () => {
  test('converts OpenAI tools to AI SDK format', async () => {
    const tools = convertOpenAIToolsToAISDK(EXAMPLE_OPENAI_TOOLS);

    // Check that tools were converted
    expect(Object.keys(tools)).toHaveLength(3);
    expect(tools).toHaveProperty('shell');
    expect(tools).toHaveProperty('read_file');
    expect(tools).toHaveProperty('write_file');
  });

  test('shell tool has correct structure', async () => {
    const tools = convertOpenAIToolsToAISDK(EXAMPLE_OPENAI_TOOLS);
    const shellTool = tools['shell'];

    expect(shellTool).toBeDefined();
    expect(shellTool.description).toBe('Execute a shell command');
  });

  test.skip('tool execution calls handler', async () => {
    const tools = convertOpenAIToolsToAISDK(EXAMPLE_OPENAI_TOOLS);
    const shellTool = tools['shell'];

    // In AI SDK v5, tools don't have execute functions - they're handled at generateText level
    expect(shellTool).toBeDefined();
    expect(typeof shellTool).toBe('object');
    // Tool should have the expected structure for AI SDK v5
    expect(shellTool).toHaveProperty('description');
    expect(shellTool).toHaveProperty('inputSchema');
  });

  test('handles empty tools array', () => {
    const tools = convertOpenAIToolsToAISDK([]);
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

    const tools = convertOpenAIToolsToAISDK(complexTool);
    expect(tools).toHaveProperty('complex_tool');
  });
});
