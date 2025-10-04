/**
 * Load AI Provider Credentials from Environment Variables
 *
 * This module handles loading and initializing credentials from environment
 * variables for deployment scenarios where credential files aren't available.
 */

import { writeFileSync, mkdirSync, existsSync, readFileSync } from 'fs';
import { homedir } from 'os';
import { join } from 'path';
import { loadCopilotOAuthTokens } from './github-copilot-oauth';

interface CredentialStats {
  geminiADC: boolean;
  claude: boolean;
  cursor: boolean;
  github: boolean;
}

/**
 * Load credentials from environment variables and write to appropriate locations
 */
export function loadCredentialsFromEnv(): CredentialStats {
  const stats: CredentialStats = {
    geminiADC: false,
    claude: false,
    cursor: false,
    github: false,
  };


  // Load Gemini ADC credentials
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON) {
    try {
      const json = Buffer.from(
        process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON,
        'base64'
      ).toString('utf-8');

      const adcPath = join(homedir(), '.config', 'gcloud');
      const adcFile = join(adcPath, 'application_default_credentials.json');

      mkdirSync(adcPath, { recursive: true });
      writeFileSync(adcFile, json);

      // Set GOOGLE_APPLICATION_CREDENTIALS env var
      process.env.GOOGLE_APPLICATION_CREDENTIALS = adcFile;

      stats.geminiADC = true;
      console.log('✓ Loaded Gemini ADC credentials from environment');
    } catch (error) {
      console.error('✗ Failed to load Gemini ADC credentials:', error);
    }
  }

  const claudeHome = process.env.CLAUDE_HOME || join(homedir(), '.claude');
  const claudeCredentialsFile = join(claudeHome, '.credentials.json');

  let claudeSource: 'CLAUDE_CODE_OAUTH_TOKEN' | 'CLAUDE_ACCESS_TOKEN' | undefined;

  if (process.env.CLAUDE_CODE_OAUTH_TOKEN) {
    claudeSource = 'CLAUDE_CODE_OAUTH_TOKEN';
  } else if (process.env.CLAUDE_ACCESS_TOKEN) {
    process.env.CLAUDE_CODE_OAUTH_TOKEN = process.env.CLAUDE_ACCESS_TOKEN;
    claudeSource = 'CLAUDE_ACCESS_TOKEN';
  }

  const claudeToken = process.env.CLAUDE_CODE_OAUTH_TOKEN;

  if (claudeToken && claudeSource) {
    try {
      mkdirSync(claudeHome, { recursive: true });

      let existingToken: string | undefined;
      if (existsSync(claudeCredentialsFile)) {
        try {
          const parsed = JSON.parse(readFileSync(claudeCredentialsFile, 'utf-8'));
          existingToken = parsed?.claudeAiOauth?.accessToken;
        } catch (error) {
          // Ignore parse errors and rewrite credentials file below
        }
      }

      if (existingToken !== claudeToken) {
        const refreshToken =
          process.env.CLAUDE_CODE_REFRESH_TOKEN || process.env.CLAUDE_REFRESH_TOKEN;
        const expiresAtEnv =
          process.env.CLAUDE_CODE_OAUTH_EXPIRES_AT ||
          process.env.CLAUDE_ACCESS_TOKEN_EXPIRES_AT;

        let expiresAt = Date.now() + 365 * 24 * 60 * 60 * 1000;
        if (expiresAtEnv) {
          const parsedExpiresAt = Number(expiresAtEnv);
          if (!Number.isNaN(parsedExpiresAt) && parsedExpiresAt > 0) {
            expiresAt = parsedExpiresAt;
          }
        }

        const credentials: Record<string, unknown> = {
          claudeAiOauth: {
            accessToken: claudeToken,
            expiresAt,
            scopes: ['user:inference'],
            subscriptionType: null,
          },
        };

        if (refreshToken) {
          (credentials.claudeAiOauth as Record<string, unknown>).refreshToken = refreshToken;
        }

        writeFileSync(claudeCredentialsFile, JSON.stringify(credentials, null, 2));
        console.log(
          `✓ Claude credentials materialized from ${claudeSource} to ${claudeCredentialsFile}`
        );
      } else {
        console.log(`✓ Claude credentials already materialized at ${claudeCredentialsFile}`);
      }

      stats.claude = true;
    } catch (error) {
      console.error('✗ Failed to materialize Claude credentials:', error);
    }
  }

  // Load Cursor credentials
  if (process.env.CURSOR_AUTH_JSON) {
    try {
      const json = Buffer.from(
        process.env.CURSOR_AUTH_JSON,
        'base64'
      ).toString('utf-8');

      const cursorPath = join(homedir(), '.config', 'cursor');
      const cursorFile = join(cursorPath, 'auth.json');

      mkdirSync(cursorPath, { recursive: true });
      writeFileSync(cursorFile, json);

      stats.cursor = true;
      console.log('✓ Loaded Cursor credentials from environment');
    } catch (error) {
      console.error('✗ Failed to load Cursor credentials:', error);
    }
  }

  // GitHub token is already in environment, just verify
  if (process.env.GH_TOKEN || process.env.GITHUB_TOKEN) {
    stats.github = true;
    console.log('✓ GitHub token available in environment');
  }

  // Load GitHub Copilot tokens
  // Priority: GITHUB_COPILOT_TOKEN env var > copilot-api token file
  let copilotToken = process.env.GITHUB_COPILOT_TOKEN;

  // Try loading from copilot-api token file
  if (!copilotToken) {
    try {
      const copilotApiTokenFile = join(homedir(), '.local', 'share', 'copilot-api', 'github_token');
      if (existsSync(copilotApiTokenFile)) {
        copilotToken = readFileSync(copilotApiTokenFile, 'utf-8').trim();
        console.log('✓ GitHub OAuth token loaded from copilot-api');
      }
    } catch (error) {
      // Silently ignore
    }
  }

  if (copilotToken) {
    loadCopilotOAuthTokens(copilotToken);
    if (process.env.GITHUB_COPILOT_TOKEN) {
      console.log('✓ GitHub Copilot token loaded from GITHUB_COPILOT_TOKEN');
    }
  }

  // Load Codex credentials from ~/.codex/auth.json (created by `codex login`)
  try {
    const codexAuthFile = join(homedir(), '.codex', 'auth.json');
    if (existsSync(codexAuthFile)) {
      const codexAuth = JSON.parse(readFileSync(codexAuthFile, 'utf-8'));
      if (codexAuth.tokens?.access_token && codexAuth.tokens?.account_id) {
        // Store in environment for server to use
        process.env.CODEX_ACCESS_TOKEN = codexAuth.tokens.access_token;
        process.env.CODEX_ACCOUNT_ID = codexAuth.tokens.account_id;
        console.log('✓ Codex credentials loaded from ~/.codex/auth.json');
      }
    }
  } catch (error) {
    // Silently ignore if file doesn't exist
  }

  return stats;
}

/**
 * Check if credentials are available (either in files or env vars)
 */
export function checkCredentialAvailability(): CredentialStats {
  const stats: CredentialStats = {
    geminiADC: false,
    claude: false,
    cursor: false,
    github: false,
  };

  // Check Gemini ADC
  const adcFile = join(homedir(), '.config', 'gcloud', 'application_default_credentials.json');
  stats.geminiADC = existsSync(adcFile) || !!process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON;

  // Check Claude
  const claudeFile = join(homedir(), '.claude', '.credentials.json');
  stats.claude =
    existsSync(claudeFile) || !!process.env.CLAUDE_CODE_OAUTH_TOKEN || !!process.env.CLAUDE_ACCESS_TOKEN;

  // Check Cursor
  const cursorFile = join(homedir(), '.config', 'cursor', 'auth.json');
  stats.cursor = existsSync(cursorFile) || !!process.env.CURSOR_AUTH_JSON;

  // Check GitHub
  stats.github = !!process.env.GH_TOKEN || !!process.env.GITHUB_TOKEN;

  return stats;
}

/**
 * Print credential status report
 */
export function printCredentialStatus(stats: CredentialStats): void {
  console.log('\n📋 Credential Status:');
  console.log(`  Gemini ADC:   ${stats.geminiADC ? '✓' : '✗'}`);
  console.log(`  Claude:       ${stats.claude ? '✓' : '✗'}`);
  console.log(`  Cursor:       ${stats.cursor ? '✓' : '✗'}`);
  console.log(`  GitHub:       ${stats.github ? '✓' : '✗'}`);
  console.log(`  Codex:        OAuth via HTTP`);
  console.log('');
}
