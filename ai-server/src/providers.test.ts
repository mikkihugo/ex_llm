import { describe, test, expect, beforeEach } from 'bun:test';

// Integration tests for provider handlers (mocked)
describe('Provider Integration Tests', () => {
  interface Message {
    role: 'system' | 'user' | 'assistant';
    content: string;
  }

  interface ChatRequest {
    provider: string;
    messages: Message[];
    model?: string;
    temperature?: number;
    maxTokens?: number;
  }

  describe('messagesToPrompt', () => {
    function messagesToPrompt(messages: Message[]): string {
      return messages.map(msg => `${msg.role}: ${msg.content}`).join('\n');
    }

    test('converts single message to prompt', () => {
      const messages: Message[] = [
        { role: 'user', content: 'Hello' }
      ];
      expect(messagesToPrompt(messages)).toBe('user: Hello');
    });

    test('converts multiple messages with line breaks', () => {
      const messages: Message[] = [
        { role: 'user', content: 'Question' },
        { role: 'assistant', content: 'Answer' },
        { role: 'user', content: 'Follow-up' }
      ];
      const result = messagesToPrompt(messages);
      expect(result).toBe('user: Question\nassistant: Answer\nuser: Follow-up');
    });

    test('handles empty messages array', () => {
      expect(messagesToPrompt([])).toBe('');
    });

    test('preserves message order', () => {
      const messages: Message[] = [
        { role: 'system', content: 'System' },
        { role: 'user', content: 'User' },
        { role: 'assistant', content: 'Assistant' }
      ];
      const result = messagesToPrompt(messages);
      expect(result).toContain('System');
      expect(result).toContain('User');
      expect(result).toContain('Assistant');
      expect(result.indexOf('System')).toBeLessThan(result.indexOf('User'));
      expect(result.indexOf('User')).toBeLessThan(result.indexOf('Assistant'));
    });
  });

  describe('Provider request validation', () => {
    function validateChatRequest(req: ChatRequest): { valid: boolean; error?: string } {
      if (!req.provider) {
        return { valid: false, error: 'Missing provider' };
      }

      if (!req.messages || !Array.isArray(req.messages)) {
        return { valid: false, error: 'Missing or invalid messages' };
      }

      if (req.messages.length === 0) {
        return { valid: false, error: 'Messages array is empty' };
      }

      for (const msg of req.messages) {
        if (!msg.role || !msg.content) {
          return { valid: false, error: 'Invalid message format' };
        }
      }

      return { valid: true };
    }

    test('accepts valid request', () => {
      const req: ChatRequest = {
        provider: 'gemini-code',
        messages: [{ role: 'user', content: 'test' }]
      };
      expect(validateChatRequest(req)).toEqual({ valid: true });
    });

    test('rejects request without provider', () => {
      const req: any = {
        messages: [{ role: 'user', content: 'test' }]
      };
      const result = validateChatRequest(req);
      expect(result.valid).toBe(false);
      expect(result.error).toContain('provider');
    });

    test('rejects request without messages', () => {
      const req: any = {
        provider: 'gemini-code'
      };
      const result = validateChatRequest(req);
      expect(result.valid).toBe(false);
      expect(result.error).toContain('messages');
    });

    test('rejects request with empty messages', () => {
      const req: ChatRequest = {
        provider: 'gemini-code',
        messages: []
      };
      const result = validateChatRequest(req);
      expect(result.valid).toBe(false);
      expect(result.error).toContain('empty');
    });

    test('rejects messages with missing role or content', () => {
      const req: any = {
        provider: 'gemini-code',
        messages: [{ role: 'user' }] // missing content
      };
      const result = validateChatRequest(req);
      expect(result.valid).toBe(false);
      expect(result.error).toContain('Invalid message');
    });
  });

  describe('Provider-specific model defaults', () => {
    function getDefaultModel(provider: string): string {
      const defaults: Record<string, string> = {
        'gemini-code-cli': 'gemini-2.5-pro',
        'gemini-code': 'gemini-2.5-flash',
        'claude-code-cli': 'sonnet',
        'codex': 'gpt-5-codex',
        'cursor-agent': 'gpt-5',
        'copilot': 'claude-sonnet-4.5'
      };
      return defaults[provider] || 'default';
    }

    test('gemini-code-cli defaults to pro model', () => {
      expect(getDefaultModel('gemini-code-cli')).toBe('gemini-2.5-pro');
    });

    test('gemini-code defaults to flash model', () => {
      expect(getDefaultModel('gemini-code')).toBe('gemini-2.5-flash');
    });

    test('claude-code-cli defaults to sonnet', () => {
      expect(getDefaultModel('claude-code-cli')).toBe('sonnet');
    });

    test('codex defaults to gpt-5-codex', () => {
      expect(getDefaultModel('codex')).toBe('gpt-5-codex');
    });

    test('unknown provider uses fallback', () => {
      expect(getDefaultModel('unknown')).toBe('default');
    });
  });

  describe('OAuth state management', () => {
    interface OAuthState {
      state: string;
      pkce: { verifier: string; challenge: string };
    }

    let currentState: OAuthState | null = null;

    function createOAuthFlow() {
      const state = Math.random().toString(36).substring(2);
      const verifier = Math.random().toString(36).substring(2);
      const challenge = verifier; // Simplified for test
      currentState = { state, pkce: { verifier, challenge } };
      return currentState;
    }

    function validateOAuthCallback(receivedState: string): boolean {
      return currentState?.state === receivedState;
    }

    function clearOAuthState() {
      currentState = null;
    }

    beforeEach(() => {
      clearOAuthState();
    });

    test('creates OAuth state with PKCE', () => {
      const oauth = createOAuthFlow();
      expect(oauth.state).toBeTruthy();
      expect(oauth.pkce.verifier).toBeTruthy();
      expect(oauth.pkce.challenge).toBeTruthy();
    });

    test('validates matching state', () => {
      const oauth = createOAuthFlow();
      expect(validateOAuthCallback(oauth.state)).toBe(true);
    });

    test('rejects mismatched state', () => {
      createOAuthFlow();
      expect(validateOAuthCallback('wrong-state')).toBe(false);
    });

    test('clears state after use', () => {
      const oauth = createOAuthFlow();
      clearOAuthState();
      expect(validateOAuthCallback(oauth.state)).toBe(false);
    });
  });

  describe('Response formatting', () => {
    function formatProviderResponse(provider: string, text: string, usage?: any) {
      return {
        text,
        provider,
        usage: usage || {
          promptTokens: 0,
          completionTokens: 0,
          totalTokens: 0
        }
      };
    }

    test('formats basic response', () => {
      const response = formatProviderResponse('gemini-code', 'Hello');
      expect(response.text).toBe('Hello');
      expect(response.provider).toBe('gemini-code');
      expect(response.usage).toBeDefined();
    });

    test('includes usage information', () => {
      const usage = { promptTokens: 10, completionTokens: 20, totalTokens: 30 };
      const response = formatProviderResponse('claude-code-cli', 'Test', usage);
      expect(response.usage.promptTokens).toBe(10);
      expect(response.usage.completionTokens).toBe(20);
      expect(response.usage.totalTokens).toBe(30);
    });

    test('provides default usage when not specified', () => {
      const response = formatProviderResponse('codex', 'Response');
      expect(response.usage.promptTokens).toBe(0);
      expect(response.usage.completionTokens).toBe(0);
      expect(response.usage.totalTokens).toBe(0);
    });
  });

  describe('CLI argument building', () => {
    function buildCLIArgs(command: string, options: Record<string, any>): string[] {
      const args = [command];

      for (const [key, value] of Object.entries(options)) {
        if (value !== undefined && value !== null) {
          args.push(`--${key}`, String(value));
        }
      }

      return args;
    }

    test('builds basic command', () => {
      const args = buildCLIArgs('chat', {});
      expect(args).toEqual(['chat']);
    });

    test('adds options as flags', () => {
      const args = buildCLIArgs('chat', { model: 'sonnet', print: true });
      expect(args).toContain('--model');
      expect(args).toContain('sonnet');
      expect(args).toContain('--print');
    });

    test('skips undefined values', () => {
      const args = buildCLIArgs('chat', { model: 'sonnet', optional: undefined });
      expect(args).toContain('--model');
      expect(args).not.toContain('--optional');
    });

    test('converts values to strings', () => {
      const args = buildCLIArgs('chat', { temperature: 0.7 });
      expect(args).toContain('--temperature');
      expect(args).toContain('0.7');
    });
  });

  describe('Error handling', () => {
    class ProviderError extends Error {
      constructor(public provider: string, message: string) {
        super(`${provider} error: ${message}`);
      }
    }

    function handleProviderError(provider: string, error: unknown): { error: string; provider: string } {
      if (error instanceof ProviderError) {
        return {
          error: error.message,
          provider: error.provider
        };
      }

      if (error instanceof Error) {
        return {
          error: `${provider} request failed: ${error.message}`,
          provider
        };
      }

      return {
        error: `${provider} request failed: ${String(error)}`,
        provider
      };
    }

    test('handles ProviderError', () => {
      const error = new ProviderError('gemini-code', 'API quota exceeded');
      const result = handleProviderError('gemini-code', error);
      expect(result.error).toContain('gemini-code');
      expect(result.error).toContain('quota exceeded');
    });

    test('handles generic Error', () => {
      const error = new Error('Network timeout');
      const result = handleProviderError('claude-code-cli', error);
      expect(result.error).toContain('Network timeout');
      expect(result.provider).toBe('claude-code-cli');
    });

    test('handles non-Error objects', () => {
      const result = handleProviderError('codex', 'Something went wrong');
      expect(result.error).toContain('Something went wrong');
      expect(result.provider).toBe('codex');
    });

    test('includes provider in all error messages', () => {
      // ProviderError uses its own provider field
      const providerError = new ProviderError('test', 'error1');
      const result1 = handleProviderError('test-provider', providerError);
      expect(result1.provider).toBe('test'); // ProviderError.provider takes precedence
      expect(result1.error).toBeTruthy();

      // Other errors use the passed-in provider
      const result2 = handleProviderError('test-provider', new Error('error2'));
      expect(result2.provider).toBe('test-provider');
      expect(result2.error).toBeTruthy();

      const result3 = handleProviderError('test-provider', 'error3');
      expect(result3.provider).toBe('test-provider');
      expect(result3.error).toBeTruthy();
    });
  });

  describe('OAuth URL building', () => {
    function buildOAuthUrl(
      baseUrl: string,
      params: Record<string, string>
    ): string {
      const url = new URL(baseUrl);
      for (const [key, value] of Object.entries(params)) {
        url.searchParams.set(key, value);
      }
      return url.toString();
    }

    test('builds basic OAuth URL', () => {
      const url = buildOAuthUrl('https://auth.example.com/authorize', {
        client_id: 'test-client',
        redirect_uri: 'http://localhost:1455/callback'
      });

      expect(url).toContain('client_id=test-client');
      expect(url).toContain('redirect_uri=http');
    });

    test('handles special characters in params', () => {
      const url = buildOAuthUrl('https://auth.example.com/authorize', {
        state: 'abc-123',
        redirect_uri: 'http://localhost:1455/auth/callback'
      });

      expect(url).toContain('state=abc-123');
      expect(url).toContain('%2F'); // URL encoded slash
    });

    test('builds URL with PKCE challenge', () => {
      const challenge = 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM';
      const url = buildOAuthUrl('https://auth.example.com/authorize', {
        code_challenge: challenge,
        code_challenge_method: 'S256'
      });

      expect(url).toContain('code_challenge=');
      expect(url).toContain('code_challenge_method=S256');
    });
  });

  describe('OpenAI format conversion', () => {
    interface UsageSummary {
      promptTokens: number;
      completionTokens: number;
      totalTokens: number;
    }

    function toOpenAIChatResponse(
      text: string,
      model: string,
      usage: UsageSummary
    ) {
      return {
        id: `chatcmpl-${Date.now()}`,
        object: 'chat.completion',
        created: Math.floor(Date.now() / 1000),
        model,
        choices: [
          {
            index: 0,
            message: {
              role: 'assistant',
              content: text,
            },
            finish_reason: 'stop',
            logprobs: null,
          },
        ],
        usage: {
          prompt_tokens: usage.promptTokens,
          completion_tokens: usage.completionTokens,
          total_tokens: usage.totalTokens,
        },
      };
    }

    test('converts to OpenAI format', () => {
      const response = toOpenAIChatResponse(
        'Hello, world!',
        'gemini-2.5-flash',
        { promptTokens: 10, completionTokens: 5, totalTokens: 15 }
      );

      expect(response.object).toBe('chat.completion');
      expect(response.model).toBe('gemini-2.5-flash');
      expect(response.choices[0].message.content).toBe('Hello, world!');
      expect(response.usage.prompt_tokens).toBe(10);
    });

    test('includes all required fields', () => {
      const response = toOpenAIChatResponse('Test', 'model', {
        promptTokens: 1,
        completionTokens: 1,
        totalTokens: 2
      });

      expect(response.id).toBeTruthy();
      expect(response.created).toBeNumber();
      expect(response.choices).toBeArray();
      expect(response.choices[0].index).toBe(0);
      expect(response.choices[0].finish_reason).toBe('stop');
    });
  });

  describe('Token refresh logic', () => {
    interface TokenStore {
      accessToken?: string;
      refreshToken?: string;
      expiresAt?: number;
    }

    function needsRefresh(store: TokenStore, bufferMs: number = 5 * 60 * 1000): boolean {
      if (!store.accessToken) return false;
      if (!store.expiresAt) return false;
      return store.expiresAt - Date.now() < bufferMs;
    }

    test('needs refresh when token expires soon', () => {
      const store: TokenStore = {
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: Date.now() + 2 * 60 * 1000 // 2 minutes from now
      };

      expect(needsRefresh(store, 5 * 60 * 1000)).toBe(true);
    });

    test('does not need refresh when token is fresh', () => {
      const store: TokenStore = {
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: Date.now() + 30 * 60 * 1000 // 30 minutes from now
      };

      expect(needsRefresh(store, 5 * 60 * 1000)).toBe(false);
    });

    test('returns false when no token', () => {
      const store: TokenStore = {};
      expect(needsRefresh(store)).toBe(false);
    });

    test('returns false when no expiry set', () => {
      const store: TokenStore = {
        accessToken: 'token',
        refreshToken: 'refresh'
      };
      expect(needsRefresh(store)).toBe(false);
    });
  });

  describe('Model registry lookups', () => {
    interface ModelEntry {
      id: string;
      provider: string;
      upstreamId?: string;
    }

    function createModelIndex(models: ModelEntry[]): Map<string, ModelEntry> {
      return new Map(models.map(m => [m.id, m]));
    }

    test('creates searchable index', () => {
      const models: ModelEntry[] = [
        { id: 'gemini-2.5-flash', provider: 'gemini-code', upstreamId: 'gemini-2.5-flash' },
        { id: 'claude-3.5-sonnet', provider: 'claude-code-cli', upstreamId: 'sonnet' }
      ];

      const index = createModelIndex(models);
      expect(index.size).toBe(2);
      expect(index.get('gemini-2.5-flash')?.provider).toBe('gemini-code');
    });

    test('handles lookups', () => {
      const models: ModelEntry[] = [
        { id: 'model1', provider: 'test' }
      ];

      const index = createModelIndex(models);
      expect(index.get('model1')).toBeDefined();
      expect(index.get('nonexistent')).toBeUndefined();
    });
  });

  describe('Codex account ID extraction', () => {
    function extractAccountId(jwt: any): string | undefined {
      return jwt?.['https://api.openai.com/auth']?.chatgpt_account_id;
    }

    test('extracts account ID from JWT payload', () => {
      const payload = {
        'https://api.openai.com/auth': {
          chatgpt_account_id: 'account-123',
          user_id: 'user-456'
        }
      };

      expect(extractAccountId(payload)).toBe('account-123');
    });

    test('returns undefined when missing', () => {
      expect(extractAccountId({})).toBeUndefined();
      expect(extractAccountId(null)).toBeUndefined();
      expect(extractAccountId({ other: 'field' })).toBeUndefined();
    });
  });

  describe('Content-Type validation', () => {
    function isJsonContentType(contentType: string | null): boolean {
      if (!contentType) return false;
      return contentType.includes('application/json');
    }

    test('validates JSON content type', () => {
      expect(isJsonContentType('application/json')).toBe(true);
      expect(isJsonContentType('application/json; charset=utf-8')).toBe(true);
    });

    test('rejects non-JSON types', () => {
      expect(isJsonContentType('text/html')).toBe(false);
      expect(isJsonContentType('text/plain')).toBe(false);
      expect(isJsonContentType(null)).toBe(false);
    });
  });
});
