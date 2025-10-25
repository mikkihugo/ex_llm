import { describe, test, expect, beforeEach, afterEach } from 'bun:test';
import { createHash, randomBytes } from 'crypto';
import { z } from 'zod';

// Unit tests for utility functions
describe('Server Utilities (Unit)', () => {
  describe('parsePort', () => {
    let originalWarn: typeof console.warn;

    beforeEach(() => {
      originalWarn = console.warn;
      console.warn = () => {}; // Suppress warnings during tests
    });

    afterEach(() => {
      console.warn = originalWarn; // Restore original warn
    });

    // Re-implement the function for testing
    function parsePort(value: string | undefined, fallback: number, label: string): number {
      if (!value || value.trim().length === 0) {
        return fallback;
      }

      const parsed = Number.parseInt(value, 10);

      if (!Number.isInteger(parsed) || parsed < 1 || parsed > 65535) {
        console.warn(`⚠️  Invalid ${label}="${value}"; falling back to ${fallback}`);
        return fallback;
      }

      return parsed;
    }

    test('returns fallback for undefined', () => {
      expect(parsePort(undefined, 3000, 'PORT')).toBe(3000);
    });

    test('returns fallback for empty string', () => {
      expect(parsePort('', 3000, 'PORT')).toBe(3000);
    });

    test('returns fallback for whitespace', () => {
      expect(parsePort('  ', 3000, 'PORT')).toBe(3000);
    });

    test('parses valid port number', () => {
      expect(parsePort('8080', 3000, 'PORT')).toBe(8080);
    });

    test('returns fallback for non-numeric string', () => {
      expect(parsePort('abc', 3000, 'PORT')).toBe(3000);
    });

    test('returns fallback for port below 1', () => {
      expect(parsePort('0', 3000, 'PORT')).toBe(3000);
      expect(parsePort('-1', 3000, 'PORT')).toBe(3000);
    });

    test('returns fallback for port above 65535', () => {
      expect(parsePort('65536', 3000, 'PORT')).toBe(3000);
      expect(parsePort('99999', 3000, 'PORT')).toBe(3000);
    });

    test('accepts port 1', () => {
      expect(parsePort('1', 3000, 'PORT')).toBe(1);
    });

    test('accepts port 65535', () => {
      expect(parsePort('65535', 3000, 'PORT')).toBe(65535);
    });
  });

  describe('toNumber', () => {
    function toNumber(value: unknown): number | undefined {
      return typeof value === 'number' && Number.isFinite(value) ? value : undefined;
    }

    test('returns number for valid finite number', () => {
      expect(toNumber(42)).toBe(42);
      expect(toNumber(0)).toBe(0);
      expect(toNumber(-10.5)).toBe(-10.5);
    });

    test('returns undefined for non-number types', () => {
      expect(toNumber('42')).toBeUndefined();
      expect(toNumber(null)).toBeUndefined();
      expect(toNumber(undefined)).toBeUndefined();
      expect(toNumber({})).toBeUndefined();
      expect(toNumber([])).toBeUndefined();
    });

    test('returns undefined for non-finite numbers', () => {
      expect(toNumber(NaN)).toBeUndefined();
      expect(toNumber(Infinity)).toBeUndefined();
      expect(toNumber(-Infinity)).toBeUndefined();
    });
  });

  describe('estimateTokensFromText', () => {
    function estimateTokensFromText(text?: string | null): number {
      if (!text) return 0;
      const bytes = Buffer.byteLength(text, 'utf8');
      if (bytes === 0) return 0;
      return Math.max(1, Math.ceil(bytes / 4));
    }

    test('returns 0 for null or undefined', () => {
      expect(estimateTokensFromText(null)).toBe(0);
      expect(estimateTokensFromText(undefined)).toBe(0);
    });

    test('returns 0 for empty string', () => {
      expect(estimateTokensFromText('')).toBe(0);
    });

    test('returns at least 1 for non-empty string', () => {
      expect(estimateTokensFromText('a')).toBe(1);
      expect(estimateTokensFromText('ab')).toBe(1);
      expect(estimateTokensFromText('abc')).toBe(1);
    });

    test('estimates roughly 1 token per 4 bytes', () => {
      const text = 'a'.repeat(100); // 100 bytes
      expect(estimateTokensFromText(text)).toBe(25);
    });

    test('handles multi-byte UTF-8 characters', () => {
      const emoji = '😀'.repeat(10); // Each emoji is 4 bytes
      expect(estimateTokensFromText(emoji)).toBe(10); // 40 bytes / 4 = 10 tokens
    });

    test('rounds up for partial tokens', () => {
      expect(estimateTokensFromText('a'.repeat(5))).toBe(2); // 5 / 4 = 1.25 -> 2
      expect(estimateTokensFromText('a'.repeat(7))).toBe(2); // 7 / 4 = 1.75 -> 2
    });
  });

  describe('estimateTokensFromMessages', () => {
    interface Message {
      role: 'system' | 'user' | 'assistant';
      content: string;
    }

    function estimateTokensFromText(text?: string | null): number {
      if (!text) return 0;
      const bytes = Buffer.byteLength(text, 'utf8');
      if (bytes === 0) return 0;
      return Math.max(1, Math.ceil(bytes / 4));
    }

    function estimateTokensFromMessages(messages: Message[]): number {
      return messages.reduce((sum, message) => sum + estimateTokensFromText(message.content), 0);
    }

    test('returns 0 for empty messages array', () => {
      expect(estimateTokensFromMessages([])).toBe(0);
    });

    test('sums tokens from multiple messages', () => {
      const messages: Message[] = [
        { role: 'user', content: 'a'.repeat(8) }, // 2 tokens
        { role: 'assistant', content: 'b'.repeat(12) }, // 3 tokens
      ];
      expect(estimateTokensFromMessages(messages)).toBe(5);
    });

    test('handles messages with empty content', () => {
      const messages: Message[] = [
        { role: 'user', content: '' },
        { role: 'assistant', content: 'test' },
      ];
      expect(estimateTokensFromMessages(messages)).toBe(1);
    });
  });

  describe('PKCE generation', () => {
    function generatePKCE() {
      const verifier = randomBytes(32).toString('base64url');
      const challenge = createHash('sha256').update(verifier).digest('base64url');
      return { verifier, challenge };
    }

    test('generates verifier with correct length', () => {
      const { verifier } = generatePKCE();
      expect(verifier).toBeTruthy();
      expect(verifier.length).toBeGreaterThan(40); // base64url of 32 bytes
    });

    test('generates unique verifiers', () => {
      const pkce1 = generatePKCE();
      const pkce2 = generatePKCE();
      expect(pkce1.verifier).not.toBe(pkce2.verifier);
      expect(pkce1.challenge).not.toBe(pkce2.challenge);
    });

    test('challenge is SHA256 hash of verifier', () => {
      const { verifier, challenge } = generatePKCE();
      const expectedChallenge = createHash('sha256').update(verifier).digest('base64url');
      expect(challenge).toBe(expectedChallenge);
    });

    test('uses base64url encoding (no padding)', () => {
      const { verifier, challenge } = generatePKCE();
      expect(verifier).not.toMatch(/[+/=]/); // base64url doesn't have these
      expect(challenge).not.toMatch(/[+/=]/);
    });
  });

  describe('OAuth state generation', () => {
    function createOAuthState(): string {
      return randomBytes(16).toString('hex');
    }

    test('generates 32 character hex string', () => {
      const state = createOAuthState();
      expect(state).toMatch(/^[0-9a-f]{32}$/);
    });

    test('generates unique states', () => {
      const state1 = createOAuthState();
      const state2 = createOAuthState();
      expect(state1).not.toBe(state2);
    });
  });

  describe('normalizeUsage', () => {
    interface Message {
      role: 'system' | 'user' | 'assistant';
      content: string;
    }

    interface UsageSummary {
      promptTokens: number;
      completionTokens: number;
      totalTokens: number;
    }

    function toNumber(value: unknown): number | undefined {
      return typeof value === 'number' && Number.isFinite(value) ? value : undefined;
    }

    function estimateTokensFromText(text?: string | null): number {
      if (!text) return 0;
      const bytes = Buffer.byteLength(text, 'utf8');
      if (bytes === 0) return 0;
      return Math.max(1, Math.ceil(bytes / 4));
    }

    function estimateTokensFromMessages(messages: Message[]): number {
      return messages.reduce((sum, message) => sum + estimateTokensFromText(message.content), 0);
    }

    function normalizeUsage(
      messages: Message[],
      generatedText?: string,
      usage?: any
    ): UsageSummary {
      const promptFromUsage = toNumber(usage?.promptTokens ?? usage?.prompt_tokens ?? usage?.input_tokens);
      const completionFromUsage = toNumber(usage?.completionTokens ?? usage?.completion_tokens ?? usage?.output_tokens);
      let totalFromUsage = toNumber(usage?.totalTokens ?? usage?.total_tokens ?? usage?.total);

      if (typeof promptFromUsage === 'number' && typeof completionFromUsage === 'number') {
        if (typeof totalFromUsage !== 'number') {
          totalFromUsage = promptFromUsage + completionFromUsage;
        }

        if (typeof totalFromUsage === 'number') {
          return {
            promptTokens: promptFromUsage,
            completionTokens: completionFromUsage,
            totalTokens: totalFromUsage,
          };
        }
      }

      const estimatedPrompt = estimateTokensFromMessages(messages);
      const estimatedCompletion = estimateTokensFromText(generatedText);
      const estimatedTotal = estimatedPrompt + estimatedCompletion;

      return {
        promptTokens: estimatedPrompt,
        completionTokens: estimatedCompletion,
        totalTokens: estimatedTotal,
      };
    }

    test('uses provider usage when available', () => {
      const messages: Message[] = [{ role: 'user', content: 'test' }];
      const usage = { promptTokens: 10, completionTokens: 20, totalTokens: 30 };

      const result = normalizeUsage(messages, 'response', usage);

      expect(result.promptTokens).toBe(10);
      expect(result.completionTokens).toBe(20);
      expect(result.totalTokens).toBe(30);
    });

    test('handles different provider formats (snake_case)', () => {
      const messages: Message[] = [{ role: 'user', content: 'test' }];
      const usage = { prompt_tokens: 5, completion_tokens: 15, total_tokens: 20 };

      const result = normalizeUsage(messages, 'response', usage);

      expect(result.promptTokens).toBe(5);
      expect(result.completionTokens).toBe(15);
      expect(result.totalTokens).toBe(20);
    });

    test('handles Anthropic format (input_tokens/output_tokens)', () => {
      const messages: Message[] = [{ role: 'user', content: 'test' }];
      const usage = { input_tokens: 8, output_tokens: 12 };

      const result = normalizeUsage(messages, 'response', usage);

      expect(result.promptTokens).toBe(8);
      expect(result.completionTokens).toBe(12);
      expect(result.totalTokens).toBe(20);
    });

    test('calculates total if missing but prompt and completion present', () => {
      const messages: Message[] = [{ role: 'user', content: 'test' }];
      const usage = { promptTokens: 10, completionTokens: 15 };

      const result = normalizeUsage(messages, 'response', usage);

      expect(result.totalTokens).toBe(25);
    });

    test('falls back to estimation when usage unavailable', () => {
      const messages: Message[] = [{ role: 'user', content: 'a'.repeat(16) }]; // 4 tokens
      const generatedText = 'b'.repeat(12); // 3 tokens

      const result = normalizeUsage(messages, generatedText);

      expect(result.promptTokens).toBe(4);
      expect(result.completionTokens).toBe(3);
      expect(result.totalTokens).toBe(7);
    });

    test('handles invalid usage values', () => {
      const messages: Message[] = [{ role: 'user', content: 'test' }];
      const usage = { promptTokens: 'invalid', completionTokens: null };

      const result = normalizeUsage(messages, 'response', usage);

      // Should fall back to estimation
      expect(result.promptTokens).toBeGreaterThan(0);
      expect(result.completionTokens).toBeGreaterThan(0);
    });
  });

  describe('json_object response enforcement', () => {
    interface ProviderResult {
      text: string;
      finishReason: string;
    }

    const JsonObjectSchema = z.object({}).passthrough();

    function enforceJsonObject(result: ProviderResult): ProviderResult {
      const trimmed = result.text.trim();
      try {
        const parsed = JsonObjectSchema.parse(JSON.parse(trimmed));
        return {
          ...result,
          text: JSON.stringify(parsed),
        };
      } catch (error: any) {
        throw new Error(`Provider returned non-JSON output while json_object response_format was requested: ${error?.message || error}`);
      }
    }

    test('returns normalized JSON string when output is valid object', () => {
      const result = enforceJsonObject({ text: '{"a":1}', finishReason: 'stop' });
      expect(result.text).toBe('{"a":1}');
    });

    test('pretty printed JSON is re-serialized compactly', () => {
      const pretty = '{\n  "foo": true\n}';
      const result = enforceJsonObject({ text: pretty, finishReason: 'stop' });
      expect(result.text).toBe('{"foo":true}');
    });

    test('throws when response is not valid JSON', () => {
      expect(() => enforceJsonObject({ text: 'not json', finishReason: 'stop' })).toThrow('Provider returned non-JSON output');
    });

    test('throws when JSON is array', () => {
      expect(() => enforceJsonObject({ text: '[]', finishReason: 'stop' })).toThrow('Provider returned non-JSON output');
    });
  });

  describe('escapeHtml', () => {
    test('imported from escape-html package', async () => {
      const escapeHtml = (await import('escape-html')).default;

      expect(escapeHtml('<script>alert("xss")</script>'))
        .toBe('&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;');

      expect(escapeHtml('Hello & goodbye'))
        .toBe('Hello &amp; goodbye');

      expect(escapeHtml("It's a test"))
        .toBe('It&#39;s a test');
    });
  });

  describe('normalizeTemperature', () => {
    function normalizeTemperature(value: any): number | undefined {
      if (typeof value !== 'number') return undefined;
      if (!Number.isFinite(value)) return undefined;
      return Math.max(0, Math.min(2, value));
    }

    test('returns valid temperature as-is', () => {
      expect(normalizeTemperature(0.7)).toBe(0.7);
      expect(normalizeTemperature(1.0)).toBe(1.0);
    });

    test('clamps temperature to min 0', () => {
      expect(normalizeTemperature(-0.5)).toBe(0);
      expect(normalizeTemperature(-100)).toBe(0);
    });

    test('clamps temperature to max 2', () => {
      expect(normalizeTemperature(2.5)).toBe(2);
      expect(normalizeTemperature(100)).toBe(2);
    });

    test('returns undefined for non-number', () => {
      expect(normalizeTemperature('0.7')).toBeUndefined();
      expect(normalizeTemperature(null)).toBeUndefined();
      expect(normalizeTemperature(undefined)).toBeUndefined();
    });

    test('returns undefined for non-finite', () => {
      expect(normalizeTemperature(NaN)).toBeUndefined();
      expect(normalizeTemperature(Infinity)).toBeUndefined();
    });
  });

  describe('normalizeMaxTokens', () => {
    function normalizeMaxTokens(value: any): number | undefined {
      if (typeof value !== 'number') return undefined;
      if (!Number.isInteger(value)) return undefined;
      return Math.max(1, value);
    }

    test('returns valid maxTokens as-is', () => {
      expect(normalizeMaxTokens(100)).toBe(100);
      expect(normalizeMaxTokens(4096)).toBe(4096);
    });

    test('clamps to min 1', () => {
      expect(normalizeMaxTokens(0)).toBe(1);
      expect(normalizeMaxTokens(-100)).toBe(1);
    });

    test('returns undefined for non-integer', () => {
      expect(normalizeMaxTokens(100.5)).toBeUndefined();
      expect(normalizeMaxTokens(1.99)).toBeUndefined();
    });

    test('returns undefined for non-number', () => {
      expect(normalizeMaxTokens('100')).toBeUndefined();
      expect(normalizeMaxTokens(null)).toBeUndefined();
    });
  });

  describe('decodeJWT', () => {
    function decodeJWT(token: string): any {
      try {
        const parts = token.split('.');
        if (parts.length !== 3) return null;
        const payload = parts[1];
        const decoded = Buffer.from(payload, 'base64').toString('utf-8');
        return JSON.parse(decoded);
      } catch {
        return null;
      }
    }

    test('decodes valid JWT', () => {
      const payload = { sub: '1234567890', name: 'Test User', iat: 1516239022 };
      const encodedPayload = Buffer.from(JSON.stringify(payload)).toString('base64');
      const token = `header.${encodedPayload}.signature`;

      const result = decodeJWT(token);
      expect(result?.sub).toBe('1234567890');
      expect(result?.name).toBe('Test User');
    });

    test('returns null for malformed token', () => {
      expect(decodeJWT('invalid')).toBeNull();
      expect(decodeJWT('header.payload')).toBeNull();
      expect(decodeJWT('a.b.c.d')).toBeNull();
    });

    test('returns null for invalid base64', () => {
      expect(decodeJWT('header.!!!invalid!!!.signature')).toBeNull();
    });

    test('returns null for invalid JSON', () => {
      const invalidJson = Buffer.from('{invalid json}').toString('base64');
      expect(decodeJWT(`header.${invalidJson}.signature`)).toBeNull();
    });
  });

  describe('mapOpenAIMessageToInternal', () => {
    function mapOpenAIMessageToInternal(message: any): { role: string; content: string } {
      const role = typeof message?.role === 'string' ? message.role : 'user';
      const content = message?.content;

      if (typeof content === 'string') {
        return { role, content };
      }

      if (Array.isArray(content)) {
        const combined = content
          .map((item) => {
            if (!item) return '';
            if (typeof item === 'string') return item;
            if (typeof item.text === 'string') return item.text;
            if (Array.isArray(item?.text)) {
              return item.text.map((value: any) => (typeof value === 'string' ? value : '')).join('\n');
            }
            return '';
          })
          .filter(Boolean)
          .join('\n');
        return { role, content: combined };
      }

      if (typeof content?.text === 'string') {
        return { role, content: content.text };
      }

      return { role, content: '' };
    }

    test('converts simple string content', () => {
      const message = { role: 'user', content: 'Hello' };
      expect(mapOpenAIMessageToInternal(message)).toEqual({
        role: 'user',
        content: 'Hello'
      });
    });

    test('defaults role to user if missing', () => {
      const message = { content: 'Hello' };
      expect(mapOpenAIMessageToInternal(message).role).toBe('user');
    });

    test('handles array content with text objects', () => {
      const message = {
        role: 'user',
        content: [
          { type: 'text', text: 'Line 1' },
          { type: 'text', text: 'Line 2' }
        ]
      };
      const result = mapOpenAIMessageToInternal(message);
      expect(result.content).toBe('Line 1\nLine 2');
    });

    test('handles array content with string items', () => {
      const message = {
        role: 'user',
        content: ['First', 'Second', 'Third']
      };
      const result = mapOpenAIMessageToInternal(message);
      expect(result.content).toBe('First\nSecond\nThird');
    });

    test('handles nested array in text field', () => {
      const message = {
        role: 'assistant',
        content: [{ text: ['Nested 1', 'Nested 2'] }]
      };
      const result = mapOpenAIMessageToInternal(message);
      expect(result.content).toBe('Nested 1\nNested 2');
    });

    test('filters out null/empty items', () => {
      const message = {
        role: 'user',
        content: ['First', null, '', 'Second', undefined, 'Third']
      };
      const result = mapOpenAIMessageToInternal(message);
      expect(result.content).toBe('First\nSecond\nThird');
    });

    test('handles object with text property', () => {
      const message = {
        role: 'user',
        content: { type: 'text', text: 'Object text' }
      };
      expect(mapOpenAIMessageToInternal(message).content).toBe('Object text');
    });

    test('returns empty content for invalid formats', () => {
      expect(mapOpenAIMessageToInternal({ role: 'user', content: null }).content).toBe('');
      expect(mapOpenAIMessageToInternal({ role: 'user', content: 123 }).content).toBe('');
      expect(mapOpenAIMessageToInternal({ role: 'user', content: {} }).content).toBe('');
    });
  });

  describe('mergeCatalog', () => {
    interface ModelCatalogEntry {
      id: string;
      provider: string;
      displayName?: string;
      upstreamId?: string;
    }

    function mergeCatalog(base: ModelCatalogEntry[], additions: any): ModelCatalogEntry[] {
      if (!additions) return base;
      const list = Array.isArray(additions) ? additions : additions?.data;
      if (!Array.isArray(list)) return base;

      const merged = [...base];
      for (const entry of list) {
        if (!entry || typeof entry !== 'object') continue;
        const id = typeof entry.id === 'string' ? entry.id : undefined;
        const provider = typeof entry.provider === 'string' ? entry.provider : undefined;
        if (!id || !provider) continue;

        const normalized: ModelCatalogEntry = {
          ...entry,
          id,
          provider,
        };

        const existingIndex = merged.findIndex((item) => item.id === id);
        if (existingIndex >= 0) {
          merged[existingIndex] = { ...merged[existingIndex], ...normalized };
        } else {
          merged.push(normalized);
        }
      }

      return merged;
    }

    test('returns base when additions is null', () => {
      const base: ModelCatalogEntry[] = [{ id: 'model1', provider: 'test' }];
      expect(mergeCatalog(base, null)).toEqual(base);
    });

    test('merges array additions', () => {
      const base: ModelCatalogEntry[] = [{ id: 'model1', provider: 'test' }];
      const additions = [{ id: 'model2', provider: 'test2', displayName: 'Model 2' }];
      const result = mergeCatalog(base, additions);
      expect(result).toHaveLength(2);
      expect(result[1].id).toBe('model2');
    });

    test('merges object with data array', () => {
      const base: ModelCatalogEntry[] = [];
      const additions = { data: [{ id: 'model1', provider: 'test' }] };
      const result = mergeCatalog(base, additions);
      expect(result).toHaveLength(1);
    });

    test('updates existing entries', () => {
      const base: ModelCatalogEntry[] = [{ id: 'model1', provider: 'old' }];
      const additions = [{ id: 'model1', provider: 'new', displayName: 'Updated' }];
      const result = mergeCatalog(base, additions);
      expect(result).toHaveLength(1);
      expect(result[0].provider).toBe('new');
      expect(result[0].displayName).toBe('Updated');
    });

    test('skips entries without id or provider', () => {
      const base: ModelCatalogEntry[] = [];
      const additions = [
        { id: 'model1' }, // missing provider
        { provider: 'test' }, // missing id
        { something: 'else' }, // missing both
      ];
      const result = mergeCatalog(base, additions);
      expect(result).toHaveLength(0);
    });

    test('skips non-object entries', () => {
      const base: ModelCatalogEntry[] = [];
      const additions = ['string', 123, null, undefined, { id: 'model1', provider: 'test' }];
      const result = mergeCatalog(base, additions);
      expect(result).toHaveLength(1);
    });
  });
});
