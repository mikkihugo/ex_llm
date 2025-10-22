/**
 * @file GitHub Copilot OAuth Helper
 * @description This module handles the OAuth 2.0 device flow for GitHub Copilot,
 * allowing the AI server to obtain API tokens on behalf of a user. It manages
 * token storage, refresh logic, and the process of exchanging a GitHub token
 * for a Copilot-specific API token.
 */

import { writeFileSync, readFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';
import { homedir } from 'os';

// --- Interfaces ---

/**
 * @interface DeviceCodeResponse
 * @description Response from the GitHub device code endpoint.
 */
interface DeviceCodeResponse {
  device_code: string;
  user_code: string;
  verification_uri: string;
  expires_in: number;
  interval: number;
}

/**
 * @interface AccessTokenResponse
 * @description Response from the GitHub access token endpoint.
 */
interface AccessTokenResponse {
  access_token?: string;
  refresh_token?: string;
  expires_in?: number;
  error?: string;
  error_description?: string;
}

/**
 * @interface CopilotTokenResponse
 * @description Response from the Copilot internal token endpoint.
 */
interface CopilotTokenResponse {
  token: string;
  expires_at: number;
  refresh_in: number;
  endpoints: {
    api: string;
  };
}

/**
 * @interface CopilotTokenStore
 * @description In-memory and on-disk storage for OAuth tokens.
 */
interface CopilotTokenStore {
  githubToken: string;
  refreshToken?: string;
  githubTokenExpiresAt?: number;
  copilotToken?: string;
  expiresAt?: number;
}

// --- Constants ---

/** The client ID for the GitHub OAuth application. */
const CLIENT_ID = 'Iv1.b507a08c87ecfe98';
/** The URL for initiating the device code flow. */
const DEVICE_CODE_URL = 'https://github.com/login/device/code';
/** The URL for exchanging a device code for an access token. */
const ACCESS_TOKEN_URL = 'https://github.com/login/oauth/access_token';
/** The URL for exchanging a GitHub token for a Copilot API token. */
const COPILOT_API_KEY_URL = 'https://api.github.com/copilot_internal/v2/token';
/** The file path for persisting the token store. */
const TOKEN_STORE_FILE = join(homedir(), '.local', 'share', 'copilot-api', 'tokens.json');

let tokenStore: CopilotTokenStore | null = null;

// --- Token Store Management ---

/**
 * Saves the current token store to a file on disk.
 * @private
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
 * Loads the token store from a file on disk.
 * @private
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

// --- Public API ---

/**
 * Starts the GitHub Copilot OAuth device flow.
 * @returns {Promise<object>} An object containing the device code, user code, and verification URI.
 */
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

/**
 * Completes the GitHub Copilot OAuth device flow by polling for an access token.
 * @param {string} deviceCode The device code obtained from `startCopilotOAuth`.
 * @returns {Promise<boolean>} A promise that resolves to `true` if the flow is complete, `false` if pending.
 * @throws {Error} If the OAuth flow fails.
 */
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
 * Refreshes the GitHub OAuth token using the stored refresh token.
 * @private
 * @returns {Promise<boolean>} A promise that resolves to `true` if the token was refreshed successfully.
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

/**
 * Retrieves a valid Copilot access token, handling caching and refresh logic.
 * @returns {Promise<string | null>} A promise that resolves to the Copilot access token, or `null` if unavailable.
 */
export async function getCopilotAccessToken(): Promise<string | null> {
  if (!tokenStore) {
    return null;
  }

  // Check if GitHub token needs refresh
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

  // Get new Copilot API token
  const response = await fetch(COPILOT_API_KEY_URL, {
    headers: {
      'authorization': `token ${tokenStore.githubToken}`,
      'accept': 'application/json',
      'editor-version': 'vscode/1.99.3',
      'editor-plugin-version': 'copilot-chat/0.26.7',
      'user-agent': 'GitHubCopilotChat/0.26.7',
    },
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error(`[copilot-oauth] Failed to exchange token: ${response.status} - ${errorText.substring(0, 200)}`);
    throw new Error(`Failed to get Copilot token: ${response.status} ${response.statusText}`);
  }

  const tokenData = await response.json() as CopilotTokenResponse;

  tokenStore.copilotToken = tokenData.token;
  tokenStore.expiresAt = tokenData.expires_at * 1000;
  saveTokenStore();

  console.log('[copilot-oauth] Successfully obtained and saved Copilot API token');
  return tokenData.token;
}

/**
 * Loads a GitHub token from an environment variable into the token store.
 * This is used as a fallback if the full OAuth flow is not performed.
 * @param {string} githubToken A GitHub personal access token.
 */
export function loadCopilotOAuthTokens(githubToken: string): void {
  if (tokenStore && tokenStore.githubToken) {
    console.log('[copilot-oauth] OAuth token already exists, ignoring GITHUB_TOKEN env var');
    return;
  }

  tokenStore = {
    githubToken,
  };
}

/**
 * Checks if a token is available in the store.
 * @returns {boolean} True if a token is available.
 */
export function hasCopilotTokens(): boolean {
  return tokenStore !== null;
}

/**
 * Retrieves the current token store.
 * @returns {CopilotTokenStore | null} The current token store, or `null`.
 */
export function getCopilotTokenStore(): CopilotTokenStore | null {
  return tokenStore;
}
