/**
 * Load AI Provider Credentials from Environment Variables
 *
 * This module handles loading and initializing credentials from environment
 * variables for deployment scenarios where credential files aren't available.
 */

import { writeFileSync, mkdirSync, existsSync } from 'fs';
import { homedir } from 'os';
import { join } from 'path';

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

  // Load Claude credentials
  if (process.env.CLAUDE_ACCESS_TOKEN) {
    try {
      const claudePath = join(homedir(), '.claude');
      const claudeFile = join(claudePath, '.credentials.json');

      const credentials = {
        claudeAiOauth: {
          accessToken: process.env.CLAUDE_ACCESS_TOKEN,
          refreshToken: process.env.CLAUDE_REFRESH_TOKEN || '',
          expiresAt: Date.now() + 365 * 24 * 60 * 60 * 1000, // 1 year
          scopes: ['user:inference'],
          subscriptionType: null,
        }
      };

      mkdirSync(claudePath, { recursive: true });
      writeFileSync(claudeFile, JSON.stringify(credentials, null, 2));

      stats.claude = true;
      console.log('✓ Loaded Claude credentials from environment');
    } catch (error) {
      console.error('✗ Failed to load Claude credentials:', error);
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
  stats.claude = existsSync(claudeFile) || !!process.env.CLAUDE_ACCESS_TOKEN;

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
