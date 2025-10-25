/**
 * @file Credential Loading and Management
 * @description This module handles the loading and validation of AI provider credentials
 * from various sources, including environment variables and local configuration files.
 * It is designed to work in different deployment environments and provides diagnostic
 * tools to report the status of each provider's credentials.
 */

import { writeFileSync, mkdirSync, existsSync, readFileSync } from 'fs';
import { homedir } from 'os';
import { join } from 'path';
import { loadCopilotOAuthTokens } from './github-copilot-oauth';

/**
 * @interface CredentialStats
 * @description Represents the availability status of credentials for each AI provider.
 * @property {boolean} geminiADC - True if Google Application Default Credentials are available.
 * @property {boolean} claude - True if Claude credentials are available.
 * @property {boolean} cursor - True if Cursor credentials are available.
 * @property {boolean} github - True if GitHub credentials (for Copilot) are available.
 * @property {boolean} codex - True if Codex credentials are available.
 */
export interface CredentialStats {
  geminiADC: boolean;
  claude: boolean;
  cursor: boolean;
  github: boolean;
  codex: boolean;
}

/**
 * Loads credentials from environment variables and materializes them into the
 * expected file locations for various AI provider SDKs. This is particularly
 * useful for containerized or serverless environments.
 * @returns {CredentialStats} An object indicating which credentials were successfully loaded.
 */
export function loadCredentialsFromEnv(): CredentialStats {
  const stats: CredentialStats = {
    geminiADC: false,
    claude: false,
    cursor: false,
    github: false,
    codex: false,
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
      // console.log('✓ Loaded Gemini ADC credentials from environment');
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
          },
        };

        if (refreshToken) {
          (credentials.claudeAiOauth as Record<string, unknown>).refreshToken = refreshToken;
        }

        writeFileSync(claudeCredentialsFile, JSON.stringify(credentials, null, 2));
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

      // Also support the alternate historical location ~/.cursor/auth.json
      const altCursorPath = join(homedir(), '.cursor');
      const altCursorFile = join(altCursorPath, 'auth.json');

      mkdirSync(cursorPath, { recursive: true });
      writeFileSync(cursorFile, json);

      try {
        mkdirSync(altCursorPath, { recursive: true });
        writeFileSync(altCursorFile, json);
      } catch (err) {
        // Non-fatal: prefer the config path but attempt the alt path when possible
      }

      stats.cursor = true;
    } catch (error) {
      console.error('✗ Failed to load Cursor credentials:', error);
    }
  }

  // GitHub token - check env or get from gh CLI
  if (!process.env.GH_TOKEN && !process.env.GITHUB_TOKEN) {
    try {
      // Try to get token from gh CLI if logged in
      const { execSync } = require('child_process');
      const ghToken = execSync('gh auth token', { encoding: 'utf8' }).trim();
      if (ghToken && ghToken.startsWith('gho_')) {
        process.env.GITHUB_TOKEN = ghToken;
        stats.github = true;
      }
    } catch (error) {
      // gh not installed or not logged in, that's ok
    }
  } else {
    stats.github = true;
  }

  // Load GitHub Copilot tokens
  // Priority:
  // 1. GITHUB_COPILOT_TOKEN env var (explicit Copilot token)
  // 2. copilot-api token file (from OAuth device flow - preferred for Copilot)
  // 3. GITHUB_TOKEN from env or gh CLI (fallback, may not have Copilot access)

  let copilotToken = process.env.GITHUB_COPILOT_TOKEN;

  // Try loading from copilot-api token file (OAuth device flow)
  if (!copilotToken) {
    try {
      const copilotApiTokenFile = join(homedir(), '.local', 'share', 'copilot-api', 'github_token');
      if (existsSync(copilotApiTokenFile)) {
        copilotToken = readFileSync(copilotApiTokenFile, 'utf-8').trim();
      }
    } catch (error) {
      // Silently ignore
    }
  }

  // Fallback to GITHUB_TOKEN (from env or gh CLI)
  // NOTE: This may not work for Copilot API if token doesn't have Copilot app access
  // Better to use Copilot OAuth device flow via /copilot/auth/start endpoint
  if (!copilotToken) {
    copilotToken = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;
    if (copilotToken) {
      // Test if this token works with Copilot API
      // If not, user should use /copilot/auth/start to get proper token
    }
  }

  if (copilotToken) {
    loadCopilotOAuthTokens(copilotToken);
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
    codex: false,
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
  const altCursorFile = join(homedir(), '.cursor', 'auth.json');
  stats.cursor = existsSync(cursorFile) || existsSync(altCursorFile) || !!process.env.CURSOR_AUTH_JSON;

  // Check GitHub
  stats.github = !!process.env.GH_TOKEN || !!process.env.GITHUB_TOKEN;

  // Check Codex
  const codexFile = join(homedir(), '.codex', 'auth.json');
  stats.codex = existsSync(codexFile) || !!process.env.CODEX_ACCESS_TOKEN;

  return stats;
}

/**
 * Print credential status report
 */
export function printCredentialStatus(stats: CredentialStats): void {
  const green = '\x1b[32m';
  const red = '\x1b[31m';
  const yellow = '\x1b[33m';
  const reset = '\x1b[0m';
  const bold = '\x1b[1m';

  interface SourceEntry {
    kind: 'file' | 'env' | 'cli';
    name: string; // file path or env var name or cli action label
    ready: boolean;
    action?: string; // helpful action like login command
    active?: boolean; // whether this source is the active one in use
  }

  interface ProviderRow {
    name: string;
    sources: SourceEntry[]; // ordered by priority (primary first)
    ok: boolean; // any source ready
    primary?: boolean; // whether this provider is the primary/preferred provider
    implementations?: { id: string; label: string }[]; // implementation preference order (highest first)
  }

  // helper to resolve file path expansion (home)
  const home = homedir();
  const adcFile = join(home, '.config', 'gcloud', 'application_default_credentials.json');
  const claudeFile = join(home, '.claude', '.credentials.json');
  const cursorFile = join(home, '.config', 'cursor', 'auth.json');
  const altCursorFile = join(home, '.cursor', 'auth.json');
  const codexFile = join(home, '.codex', 'auth.json');

  const rows: ProviderRow[] = [
    {
      name: 'Gemini',
      sources: [
        { kind: 'file', name: adcFile, ready: existsSync(adcFile), action: 'gcloud auth application-default login' },
        { kind: 'env', name: 'GOOGLE_APPLICATION_CREDENTIALS_JSON', ready: !!process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON },
        { kind: 'cli', name: 'gcloud auth application-default login', ready: false },
      ],
      ok: stats.geminiADC,
      implementations: [
        { id: 'gemini-code', label: 'Gemini API' },
        { id: 'gemini-code-cli', label: 'Gemini CLI' },
      ],
    },
    {
      name: 'Claude',
      sources: [
        { kind: 'file', name: claudeFile, ready: existsSync(claudeFile), action: 'claude setup-token' },
        { kind: 'env', name: 'CLAUDE_CODE_OAUTH_TOKEN', ready: !!process.env.CLAUDE_CODE_OAUTH_TOKEN },
        { kind: 'env', name: 'CLAUDE_ACCESS_TOKEN', ready: !!process.env.CLAUDE_ACCESS_TOKEN },
        { kind: 'cli', name: 'claude setup-token', ready: false },
      ],
      ok: stats.claude,
      implementations: [
        { id: 'claude-code-cli', label: 'Claude CLI' },
        { id: 'claude-code', label: 'Claude API' },
      ],
    },
    {
      name: 'Cursor',
      sources: [
        { kind: 'file', name: cursorFile, ready: existsSync(cursorFile), action: 'cursor-agent login' },
        { kind: 'file', name: altCursorFile, ready: existsSync(altCursorFile), action: 'cursor-agent login' },
        { kind: 'env', name: 'CURSOR_AUTH_JSON', ready: !!process.env.CURSOR_AUTH_JSON },
        { kind: 'cli', name: 'cursor-agent login', ready: false },
      ],
      ok: stats.cursor,
    },
    {
      name: 'GitHub',
      sources: [
        { kind: 'env', name: 'GH_TOKEN', ready: !!process.env.GH_TOKEN },
        { kind: 'env', name: 'GITHUB_TOKEN', ready: !!process.env.GITHUB_TOKEN },
        { kind: 'cli', name: 'set GH_TOKEN/GITHUB_TOKEN', ready: false },
      ],
      ok: stats.github,
      implementations: [
        { id: 'copilot-api', label: 'Copilot API' },
        { id: 'copilot-cli', label: 'Copilot CLI' },
        { id: 'github-models', label: 'GitHub Models' },
      ],
    },
    {
      name: 'Codex',
      sources: [
        { kind: 'file', name: codexFile, ready: existsSync(codexFile), action: 'codex login' },
        { kind: 'env', name: 'CODEX_ACCESS_TOKEN', ready: !!process.env.CODEX_ACCESS_TOKEN },
        { kind: 'cli', name: 'codex login', ready: false },
      ],
      ok: stats.codex,
      implementations: [
        { id: 'codex-cli', label: 'Codex CLI' },
      ],
    },
  ];

  // Determine primary provider from environment or pick the first available provider
  const primaryEnv = (process.env.SINGULARITY_DEFAULT_PROVIDER || process.env.DEFAULT_PROVIDER || process.env.PREFERRED_PROVIDER || process.env.AI_PRIMARY_PROVIDER || '').trim().toLowerCase();
  if (primaryEnv) {
    for (const r of rows) {
      const rn = r.name.toLowerCase();
      if (rn.includes(primaryEnv) || primaryEnv.includes(rn)) {
        r.primary = true;
        break;
      }
    }
  } else {
    // No explicit primary provider: pick the first provider that has credentials ready
    const firstOk = rows.find((r) => r.ok);
    if (firstOk) firstOk.primary = true;
  }

  // For each provider, mark the first ready source as the active one (if any)
  for (const r of rows) {
    const idx = r.sources.findIndex((s) => s.ready);
    if (idx >= 0) {
      r.sources[idx].active = true;
    }
  }

  // For each provider, compute implementation-level primary & active markers.
  // primaryImpl: chosen by env var SINGULARITY_DEFAULT_PROVIDER_IMPL or default to implementations[0]
  // activeImpl: first implementation whose required credentials are available (implementation-specific readiness)
  const implEnv = (process.env.SINGULARITY_DEFAULT_PROVIDER_IMPL || '').trim().toLowerCase();

  function implIsReady(implId: string, r: ProviderRow): boolean {
    // Map implementation ids to the stats or readiness checks
    switch (implId) {
      case 'gemini-code':
      case 'gemini':
        return stats.geminiADC;
      case 'claude-code':
      case 'claude-code-cli':
        return stats.claude;
      case 'codex-cli':
        return stats.codex;
      case 'cursor-agent-cli':
        return stats.cursor;
      case 'copilot-api':
      case 'copilot-cli':
        return stats.github;
      default:
        // Fallback: consider provider ok
        return r.ok;
    }
  }

  for (const r of rows) {
    if (!r.implementations || r.implementations.length === 0) continue;
    // primary implementation selection (independent of auth)
    if (implEnv) {
      for (const impl of r.implementations) {
        if (impl.id.toLowerCase().includes(implEnv) || implEnv.includes(impl.id.toLowerCase())) {
          (r as any).__primaryImpl = impl.id;
          break;
        }
      }
    }
    if (!(r as any).__primaryImpl) {
      (r as any).__primaryImpl = r.implementations[0].id;
    }

    // active implementation: first implementation with required credentials available
    (r as any).__activeImpl = undefined;
    for (const impl of r.implementations) {
      if (implIsReady(impl.id, r)) {
        (r as any).__activeImpl = impl.id;
        break;
      }
    }
  }

  const TARGET_WIDTH = 120; // total inner width (excluding box edges)
  const COL_NAME = 12; // visible width for name column
  const COL_STATUS = 10; // visible width for status column
  const DETAIL_WIDTH = Math.max(40, TARGET_WIDTH - COL_NAME - COL_STATUS - 8); // ensure a reasonable minimum

  function wrap(text: string, width: number): string[] {
    const words = text.split(/\s+/);
    const lines: string[] = [];
    let current = '';
    for (const w of words) {
      if ((current + ' ' + w).trim().length > width) {
        if (current) lines.push(current);
        current = w;
      } else {
        current = current ? current + ' ' + w : w;
      }
    }
    if (current) lines.push(current);
    return lines.length ? lines : [''];
  }

  function formatProvider(row: ProviderRow): string[] {
    const statusIcon = row.ok ? `${green}✓ Ready${reset}` : `${red}✗ Missing${reset}`;

  // Build implementation list (preferred order) and per-source readiness/actions
    const parts: string[] = [];
    if (row.implementations && row.implementations.length > 0) {
      for (const impl of row.implementations) {
        const isPrimaryImpl = (row as any).__primaryImpl === impl.id;
        const isActiveImpl = (row as any).__activeImpl === impl.id;
        const primaryTag = isPrimaryImpl ? ` ${bold}(preferred)${reset}` : '';
        const activeTag = isActiveImpl ? ` ${bold}(active)${reset}` : '';
        parts.push(`${impl.label}${primaryTag}${activeTag}`);
      }
      // Separator between impls and sources
    }

    // Then show per-source readiness and actions
    if (row.name === 'Gemini') {
      // Show implementations first (preferred/active), then list each source inline with status and action.
      const sourcesOrdered = row.sources.filter(Boolean);

      // For Gemini we want the primary source to be obvious: mark the active source as Primary inline
      for (const s of sourcesOrdered) {
        const readyText = s.ready ? `${green}Ready${reset}` : `${red}Missing${reset}`;
        const kindLabel = s.kind === 'file' ? 'File' : s.kind === 'env' ? 'Env' : 'CLI';
        const baseLabel = `${kindLabel}:${s.name}`;
        const activeTag = s.active ? ` ${bold}(active)${reset}` : '';
        const action = s.action ? ` | ${s.action}` : '';
        // If this is the active ADC file or env, append a clearer logged-in note inline
        let note = '';
        if (s.active && (s.kind === 'file' || s.kind === 'env') && s.name.includes('application_default_credentials.json') || s.name === 'GOOGLE_APPLICATION_CREDENTIALS_JSON') {
          note = ` ${bold}we are logged in with the ADC JSON (default)${reset}`;
        }
        parts.push(`${baseLabel}${activeTag} (${readyText})${action}${note}`);
      }
    } else {
      for (const s of row.sources) {
        const readyText = s.ready ? `${green}Ready${reset}` : `${red}Missing${reset}`;
        const baseLabel = `${s.kind === 'file' ? 'File' : s.kind === 'env' ? 'Env' : 'CLI'}:${s.name}`;
        const activeTag = s.active ? ` ${bold}(active)${reset}` : '';
        const action = s.action ? ` | ${s.action}` : '';
        parts.push(`${baseLabel}${activeTag} (${readyText})${action}`);
      }
    }

    const detailsRaw = parts.join('  |  ');
    const wrapped = wrap(detailsRaw, DETAIL_WIDTH);
    return [statusIcon, ...wrapped];
  }

  // Render header
  console.log(`\n${bold}📋 AI Provider Credentials${reset}`);
  const horizontal = '─'.repeat(COL_NAME + COL_STATUS + DETAIL_WIDTH + 8);
  console.log(`┌${horizontal}┐`);
  const headerName = 'Provider'.padEnd(COL_NAME);
  const headerStatus = 'Status'.padEnd(COL_STATUS);
  const headerDetails = 'Details'.padEnd(DETAIL_WIDTH);
  console.log(`│ ${bold}${headerName}${reset} │ ${bold}${headerStatus}${reset} │ ${bold}${headerDetails}${reset} │`);
  console.log(`├${'─'.repeat(COL_NAME + 2)}┼${'─'.repeat(COL_STATUS + 2)}┼${'─'.repeat(DETAIL_WIDTH + 2)}┤`);

  rows.forEach(row => {
    const formatted = formatProvider(row);
    // first element of formatted is status, rest are detail lines
    const statusText = formatted[0];
    const detailLines = formatted.slice(1);
    detailLines.forEach((detail, idx) => {
      const primaryTag = idx === 0 && row.primary ? ' (primary)' : '';
      const rawName = idx === 0 ? (row.name + primaryTag) : '';
      // ensure fixed column width: pad then truncate if necessary
      const nameLabel = rawName.padEnd(COL_NAME).slice(0, COL_NAME);
      const nameCol = idx === 0 ? nameLabel : ' '.repeat(COL_NAME);
      const statusCol = idx === 0 ? statusText.padEnd(COL_STATUS) : ' '.repeat(COL_STATUS);
      console.log(`│ ${nameCol} │ ${statusCol} │ ${detail.padEnd(DETAIL_WIDTH)} │`);
    });
  });

  console.log(`└${horizontal}┘`);
  console.log(`${yellow}Legend:${reset} (primary) marks the preferred provider (set via SINGULARITY_DEFAULT_PROVIDER/DEFAULT_PROVIDER) or selected as first available.`);
  console.log(`${yellow}Legend:${reset} ${bold}(active)${reset} marks the credential source currently used by the server for that provider.`);
  console.log('');
}
