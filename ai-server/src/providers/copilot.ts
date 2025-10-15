/**
 * @file GitHub Copilot Provider
 * @description This module wraps the base `createCopilotWithOAuth` to integrate it
 * with the application's GitHub Copilot OAuth flow. It provides a unified
 * interface for listing Copilot models dynamically from the API.
 */

import { createCopilotWithOAuth } from '../../vendor/ai-sdk-provider-copilot/dist/index.js';
import { getCopilotAccessToken } from '../github-copilot-oauth';

/**
 * @description The Copilot provider instance with OAuth integration.
 * Dynamically fetches models from GitHub Copilot API on startup.
 * @private
 */
const copilotProvider = createCopilotWithOAuth(getCopilotAccessToken);

/**
 * @const {object} copilot
 * @description The singleton instance of the Copilot provider with AI SDK v5 compatibility.
 * Uses async getModelMetadata() to fetch real models from GitHub Copilot API.
 */
export const copilot = copilotProvider;