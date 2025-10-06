/**
 * GitHub Copilot Provider Wrapper
 * Integrates ai-sdk-provider-copilot with GitHub Copilot OAuth flow
 */

import { createCopilotWithOAuth } from '../../vendor/ai-sdk-provider-copilot/dist/index.js';
import { getCopilotAccessToken } from '../github-copilot-oauth';

/**
 * GitHub Copilot provider instance with OAuth integration
 *
 * Features:
 * - ✅ AI SDK tools support (Elixir executes)
 * - ✅ Streaming support
 * - ✅ Dynamic model loading from GitHub Copilot API
 * - ✅ GitHub Copilot OAuth flow integration
 * - ✅ Automatic token refresh
 * - ✅ Cost tier tagging (free vs limited)
 *
 * Authentication:
 * Uses GitHub Copilot OAuth flow via getCopilotAccessToken()
 * which handles:
 * 1. GitHub OAuth token → Copilot API token exchange
 * 2. Token caching with expiration
 * 3. Automatic refresh
 */
export const copilot = createCopilotWithOAuth(getCopilotAccessToken);
