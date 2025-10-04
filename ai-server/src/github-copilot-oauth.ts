interface DeviceCodeResponse {
  device_code: string;
  user_code: string;
  verification_uri: string;
  expires_in: number;
  interval: number;
}

interface AccessTokenResponse {
  access_token?: string;
  error?: string;
  error_description?: string;
}

interface CopilotTokenResponse {
  token: string;
  expires_at: number;
  refresh_in: number;
  endpoints: {
    api: string;
  };
}

interface CopilotTokenStore {
  githubToken: string;
  copilotToken?: string;
  expiresAt?: number;
}

const CLIENT_ID = 'Iv1.b507a08c87ecfe98';
const DEVICE_CODE_URL = 'https://github.com/login/device/code';
const ACCESS_TOKEN_URL = 'https://github.com/login/oauth/access_token';
const COPILOT_API_KEY_URL = 'https://api.github.com/copilot_internal/v2/token';

let tokenStore: CopilotTokenStore | null = null;

export async function startCopilotOAuth(): Promise<{
  device_code: string;
  user_code: string;
  verification_uri: string;
  interval: number;
  expires_in: number;
}> {
  const response = await fetch(DEVICE_CODE_URL, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': 'GitHubCopilotChat/0.26.7',
    },
    body: JSON.stringify({
      client_id: CLIENT_ID,
      scope: 'read:user',
    }),
  });

  if (!response.ok) {
    throw new Error(`Failed to start OAuth flow: ${response.statusText}`);
  }

  const data: DeviceCodeResponse = await response.json();
  return {
    device_code: data.device_code,
    user_code: data.user_code,
    verification_uri: data.verification_uri,
    interval: data.interval || 5,
    expires_in: data.expires_in,
  };
}

export async function completeCopilotOAuth(deviceCode: string): Promise<boolean> {
  const response = await fetch(ACCESS_TOKEN_URL, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': 'GitHubCopilotChat/0.26.7',
    },
    body: JSON.stringify({
      client_id: CLIENT_ID,
      device_code: deviceCode,
      grant_type: 'urn:ietf:params:oauth:grant-type:device_code',
    }),
  });

  if (!response.ok) {
    return false;
  }

  const data: AccessTokenResponse = await response.json();

  if (data.access_token) {
    tokenStore = {
      githubToken: data.access_token,
    };
    return true;
  }

  if (data.error === 'authorization_pending') {
    return false;
  }

  throw new Error(data.error_description || data.error || 'Unknown error');
}

export async function getCopilotAccessToken(): Promise<string | null> {
  if (!tokenStore) {
    return null;
  }

  // Return cached token if still valid
  if (tokenStore.copilotToken && tokenStore.expiresAt && tokenStore.expiresAt > Date.now()) {
    return tokenStore.copilotToken;
  }

  // Get new Copilot API token using GitHub OAuth token
  // Use exact headers from copilot-api project
  const response = await fetch(COPILOT_API_KEY_URL, {
    headers: {
      'content-type': 'application/json',
      'accept': 'application/json',
      'authorization': `token ${tokenStore.githubToken}`,  // Note: "token" not "Bearer"
      'editor-version': 'vscode/1.99.3',
      'editor-plugin-version': 'copilot-chat/0.26.7',
      'user-agent': 'GitHubCopilotChat/0.26.7',
      'x-github-api-version': '2025-04-01',
      'x-vscode-user-agent-library-version': 'electron-fetch',
    },
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to get Copilot token: ${response.status} ${response.statusText} - ${errorText}`);
  }

  const tokenData: CopilotTokenResponse = await response.json();

  // Update token store with new Copilot API token
  tokenStore.copilotToken = tokenData.token;
  tokenStore.expiresAt = tokenData.expires_at * 1000;

  return tokenData.token;
}

export function loadCopilotOAuthTokens(githubToken: string): void {
  tokenStore = {
    githubToken,
  };
}

export function hasCopilotTokens(): boolean {
  return tokenStore !== null;
}

export function getCopilotTokenStore(): CopilotTokenStore | null {
  return tokenStore;
}
