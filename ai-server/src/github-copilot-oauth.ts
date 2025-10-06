interface DeviceCodeResponse {
  device_code: string;
  user_code: string;
  verification_uri: string;
  expires_in: number;
  interval: number;
}

interface AccessTokenResponse {
  access_token?: string;
  refresh_token?: string;
  expires_in?: number;
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
  refreshToken?: string;
  githubTokenExpiresAt?: number;
  copilotToken?: string;
  expiresAt?: number;
}

import { writeFileSync, readFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';
import { homedir } from 'os';

const CLIENT_ID = 'Iv1.b507a08c87ecfe98';
const DEVICE_CODE_URL = 'https://github.com/login/device/code';
const ACCESS_TOKEN_URL = 'https://github.com/login/oauth/access_token';
const COPILOT_API_KEY_URL = 'https://api.github.com/copilot_internal/v2/token';
const TOKEN_STORE_FILE = join(homedir(), '.local', 'share', 'copilot-api', 'tokens.json');

let tokenStore: CopilotTokenStore | null = null;

/**
 * Save token store to disk for persistence
 */
function saveTokenStore(): void {
  if (!tokenStore) return;

  try {
    const dir = join(homedir(), '.local', 'share', 'copilot-api');
    if (!existsSync(dir)) {
      mkdirSync(dir, { recursive: true });
    }
    writeFileSync(TOKEN_STORE_FILE, JSON.stringify(tokenStore, null, 2), 'utf-8');
  } catch (error) {
    console.error('[copilot-oauth] Failed to save token store:', error);
  }
}

/**
 * Load token store from disk
 */
function loadTokenStore(): void {
  try {
    if (existsSync(TOKEN_STORE_FILE)) {
      const data = readFileSync(TOKEN_STORE_FILE, 'utf-8');
      tokenStore = JSON.parse(data);
      console.log('[copilot-oauth] Loaded token store from disk');
    }
  } catch (error) {
    console.error('[copilot-oauth] Failed to load token store:', error);
  }
}

// Load tokens on module initialization
loadTokenStore();

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

  const data = await response.json() as DeviceCodeResponse;
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

  const data = await response.json() as AccessTokenResponse;

  if (data.access_token) {
    const expiresAt = data.expires_in ? Date.now() + (data.expires_in * 1000) : undefined;
    tokenStore = {
      githubToken: data.access_token,
      refreshToken: data.refresh_token,
      githubTokenExpiresAt: expiresAt,
    };
    saveTokenStore();
    return true;
  }

  if (data.error === 'authorization_pending') {
    return false;
  }

  throw new Error(data.error_description || data.error || 'Unknown error');
}

/**
 * Refresh the GitHub OAuth token using the refresh token
 */
async function refreshGitHubToken(): Promise<boolean> {
  if (!tokenStore?.refreshToken) {
    return false;
  }

  const response = await fetch(ACCESS_TOKEN_URL, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': 'GitHubCopilotChat/0.26.7',
    },
    body: JSON.stringify({
      client_id: CLIENT_ID,
      grant_type: 'refresh_token',
      refresh_token: tokenStore.refreshToken,
    }),
  });

  if (!response.ok) {
    console.error('[copilot-oauth] Failed to refresh token:', response.statusText);
    return false;
  }

  const data = await response.json() as AccessTokenResponse;

  if (data.access_token) {
    const expiresAt = data.expires_in ? Date.now() + (data.expires_in * 1000) : undefined;
    tokenStore.githubToken = data.access_token;
    if (data.refresh_token) {
      tokenStore.refreshToken = data.refresh_token;
    }
    tokenStore.githubTokenExpiresAt = expiresAt;
    saveTokenStore();
    console.log('[copilot-oauth] Successfully refreshed GitHub token');
    return true;
  }

  return false;
}

export async function getCopilotAccessToken(): Promise<string | null> {
  if (!tokenStore) {
    return null;
  }

  // Check if GitHub token needs refresh (expired or about to expire in 5 minutes)
  if (tokenStore.githubTokenExpiresAt) {
    const fiveMinutesFromNow = Date.now() + (5 * 60 * 1000);
    if (tokenStore.githubTokenExpiresAt < fiveMinutesFromNow) {
      console.log('[copilot-oauth] GitHub token expired or expiring soon, refreshing...');
      const refreshed = await refreshGitHubToken();
      if (!refreshed) {
        console.error('[copilot-oauth] Failed to refresh GitHub token');
        return null;
      }
    }
  }

  // Return cached Copilot token if still valid
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

  const tokenData = await response.json() as CopilotTokenResponse;

  // Update token store with new Copilot API token
  tokenStore.copilotToken = tokenData.token;
  tokenStore.expiresAt = tokenData.expires_at * 1000;

  return tokenData.token;
}

export function loadCopilotOAuthTokens(githubToken: string): void {
  // Don't override OAuth tokens if we already have them from OAuth flow
  // OAuth tokens take precedence over env var GITHUB_TOKEN
  if (tokenStore && tokenStore.githubToken) {
    console.log('[copilot-oauth] OAuth token already exists, ignoring GITHUB_TOKEN env var');
    return;
  }

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
