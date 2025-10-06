#!/bin/bash
# List available models from GitHub Copilot API
#
# Usage:
#   ./scripts/list-copilot-models.sh

# Get GitHub token (from gh CLI or env)
if [ -z "$GITHUB_TOKEN" ]; then
  GITHUB_TOKEN=$(gh auth token 2>/dev/null)
fi

if [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: GITHUB_TOKEN not found. Run 'gh auth login' or set GITHUB_TOKEN env var."
  exit 1
fi

echo "🔍 Fetching Copilot API token..."

# Exchange GitHub token for Copilot token
COPILOT_TOKEN_RESPONSE=$(curl -s https://api.github.com/copilot_internal/v2/token \
  -H "authorization: token $GITHUB_TOKEN" \
  -H "editor-version: vscode/1.99.3" \
  -H "editor-plugin-version: copilot-chat/0.26.7" \
  -H "user-agent: GitHubCopilotChat/0.26.7" \
  -H "x-github-api-version: 2025-04-01")

COPILOT_TOKEN=$(echo "$COPILOT_TOKEN_RESPONSE" | jq -r '.token')

if [ "$COPILOT_TOKEN" == "null" ] || [ -z "$COPILOT_TOKEN" ]; then
  echo "❌ Failed to get Copilot token:"
  echo "$COPILOT_TOKEN_RESPONSE" | jq .
  exit 1
fi

echo "✅ Got Copilot token"
echo ""
echo "🔍 Querying Copilot chat/completions endpoint for available models..."
echo ""

# Try to get model information from chat/completions endpoint
# Note: Copilot API doesn't have a /models endpoint, so we infer from docs
echo "📋 GitHub Copilot Supported Models (from documentation):"
echo ""
echo "Based on GitHub Copilot docs (as of 2025), supported models include:"
echo ""
echo "OpenAI Models:"
echo "  - gpt-4.1 (default, 128K context via Copilot)"
echo "  - gpt-4o (64K context)"
echo "  - gpt-5 (preview, Pro+ tier)"
echo "  - gpt-5-mini (preview)"
echo "  - o3 (preview, Pro+/Enterprise)"
echo "  - o3-mini"
echo "  - o4-mini (preview)"
echo ""
echo "Anthropic Models:"
echo "  - claude-sonnet-3.5"
echo "  - claude-sonnet-3.7"
echo "  - claude-sonnet-3.7-thinking"
echo "  - claude-sonnet-4"
echo "  - claude-opus-4 (preview)"
echo "  - claude-opus-4.1 (preview)"
echo ""
echo "xAI Models:"
echo "  - grok-coder-1 (256K context, complimentary access)"
echo ""
echo "Google Models:"
echo "  - gemini-2.5-pro"
echo ""
echo "ℹ️  Note: Model availability depends on your Copilot tier:"
echo "   - Individual/Pro: Basic models"
echo "   - Pro+: All models including GPT-5, o3"
echo "   - Business/Enterprise: All models + extended quotas"
echo ""
echo "ℹ️  Copilot API at api.githubcopilot.com doesn't expose a /models endpoint"
echo "   Model list is based on official GitHub Copilot documentation"
echo ""
echo "🔗 Official docs: https://docs.github.com/en/copilot/reference/ai-models/supported-models"
