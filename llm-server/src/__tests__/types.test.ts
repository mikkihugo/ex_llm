import { describe, it, expect } from 'bun:test';
import {
  isValidLLMRequest,
  assertValidLLMRequest,
  isValidOpenAITool,
  type LLMRequest
} from '../types';

describe('LLMRequest Validation', () => {
  describe('isValidLLMRequest', () => {
    it('should accept minimal valid request', () => {
      const request = {
        messages: [{ role: 'user' as const, content: 'Hello' }]
      };
      expect(isValidLLMRequest(request)).toBe(true);
    });

    it('should accept complete valid request', () => {
      const request: LLMRequest = {
        provider: 'claude',
        model: 'sonnet',
        messages: [
          { role: 'user', content: 'Hello' },
          { role: 'assistant', content: 'Hi there' }
        ],
        max_tokens: 1000,
        temperature: 0.7,
        stream: false,
        correlation_id: 'abc123',
        complexity: 'simple',
        task_type: 'general'
      };
      expect(isValidLLMRequest(request)).toBe(true);
    });

    it('should reject non-object', () => {
      expect(isValidLLMRequest('string')).toBe(false);
      expect(isValidLLMRequest(null)).toBe(false);
      expect(isValidLLMRequest(undefined)).toBe(false);
      expect(isValidLLMRequest(123)).toBe(false);
    });

    it('should reject missing messages', () => {
      expect(isValidLLMRequest({})).toBe(false);
      expect(isValidLLMRequest({ provider: 'claude' })).toBe(false);
    });

    it('should reject empty messages array', () => {
      expect(isValidLLMRequest({ messages: [] })).toBe(false);
    });

    it('should reject invalid message structure', () => {
      expect(
        isValidLLMRequest({
          messages: [{ role: 'user' }] // missing content
        })
      ).toBe(false);

      expect(
        isValidLLMRequest({
          messages: [{ content: 'Hello' }] // missing role
        })
      ).toBe(false);

      expect(
        isValidLLMRequest({
          messages: [{ role: 'user', content: 123 }] // invalid type
        })
      ).toBe(false);
    });

    it('should reject invalid role', () => {
      expect(
        isValidLLMRequest({
          messages: [{ role: 'invalid', content: 'Hello' }]
        })
      ).toBe(false);
    });

    it('should reject invalid max_tokens', () => {
      expect(
        isValidLLMRequest({
          messages: [{ role: 'user', content: 'Hello' }],
          max_tokens: -1
        })
      ).toBe(false);

      expect(
        isValidLLMRequest({
          messages: [{ role: 'user', content: 'Hello' }],
          max_tokens: 'invalid'
        })
      ).toBe(false);
    });

    it('should reject invalid temperature', () => {
      expect(
        isValidLLMRequest({
          messages: [{ role: 'user', content: 'Hello' }],
          temperature: -0.1
        })
      ).toBe(false);

      expect(
        isValidLLMRequest({
          messages: [{ role: 'user', content: 'Hello' }],
          temperature: 2.1
        })
      ).toBe(false);
    });

    it('should reject invalid complexity', () => {
      expect(
        isValidLLMRequest({
          messages: [{ role: 'user', content: 'Hello' }],
          complexity: 'invalid'
        })
      ).toBe(false);
    });

    it('should reject invalid task_type', () => {
      expect(
        isValidLLMRequest({
          messages: [{ role: 'user', content: 'Hello' }],
          task_type: 'invalid_type'
        })
      ).toBe(false);
    });

    it('should accept valid tools', () => {
      const request = {
        messages: [{ role: 'user' as const, content: 'Hello' }],
        tools: [
          {
            type: 'function' as const,
            function: {
              name: 'get_weather',
              description: 'Get weather info',
              parameters: { type: 'object', properties: {} }
            }
          }
        ]
      };
      expect(isValidLLMRequest(request)).toBe(true);
    });

    it('should reject invalid tools', () => {
      expect(
        isValidLLMRequest({
          messages: [{ role: 'user' as const, content: 'Hello' }],
          tools: [
            {
              type: 'invalid',
              function: { name: 'get_weather' }
            }
          ]
        })
      ).toBe(false);

      expect(
        isValidLLMRequest({
          messages: [{ role: 'user' as const, content: 'Hello' }],
          tools: [
            {
              type: 'function' as const,
              function: {}  // missing name
            }
          ]
        })
      ).toBe(false);
    });

    it('should accept valid capabilities', () => {
      const request = {
        messages: [{ role: 'user' as const, content: 'Hello' }],
        capabilities: ['code', 'reasoning']
      };
      expect(isValidLLMRequest(request)).toBe(true);
    });

    it('should reject invalid capabilities', () => {
      expect(
        isValidLLMRequest({
          messages: [{ role: 'user' as const, content: 'Hello' }],
          capabilities: ['code', 'invalid']
        })
      ).toBe(false);
    });
  });

  describe('assertValidLLMRequest', () => {
    it('should not throw for valid request', () => {
      const request = {
        messages: [{ role: 'user' as const, content: 'Hello' }]
      };
      expect(() => assertValidLLMRequest(request)).not.toThrow();
    });

    it('should throw for invalid request', () => {
      expect(() => assertValidLLMRequest({})).toThrow();
      expect(() => assertValidLLMRequest({ messages: [] })).toThrow();
    });

    it('should throw descriptive error', () => {
      const error = expect(() => assertValidLLMRequest({ invalid: true })).toThrow();
    });
  });

  describe('isValidOpenAITool', () => {
    it('should accept valid tool', () => {
      const tool = {
        type: 'function' as const,
        function: {
          name: 'get_weather',
          description: 'Get weather info',
          parameters: { type: 'object', properties: {} }
        }
      };
      expect(isValidOpenAITool(tool)).toBe(true);
    });

    it('should accept tool without description', () => {
      const tool = {
        type: 'function' as const,
        function: {
          name: 'get_weather',
          parameters: { type: 'object', properties: {} }
        }
      };
      expect(isValidOpenAITool(tool)).toBe(true);
    });

    it('should accept tool without parameters', () => {
      const tool = {
        type: 'function' as const,
        function: {
          name: 'get_weather'
        }
      };
      expect(isValidOpenAITool(tool)).toBe(true);
    });

    it('should reject invalid type', () => {
      expect(
        isValidOpenAITool({
          type: 'invalid',
          function: { name: 'get_weather' }
        })
      ).toBe(false);
    });

    it('should reject missing function', () => {
      expect(
        isValidOpenAITool({
          type: 'function' as const
        })
      ).toBe(false);
    });

    it('should reject missing name', () => {
      expect(
        isValidOpenAITool({
          type: 'function' as const,
          function: {}
        })
      ).toBe(false);
    });
  });
});
