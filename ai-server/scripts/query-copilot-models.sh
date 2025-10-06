#!/bin/bash
# Query GitHub Copilot Enterprise API for available models

GITHUB_TOKEN=$(cat ~/.local/share/copilot-api/github_token)

# Exchange for Copilot token
COPILOT_TOKEN=$(curl -s https://api.github.com/copilot_internal/v2/token \
  -H "authorization: token $GITHUB_TOKEN" \
  -H "editor-version: vscode/1.99.3" \
  -H "user-agent: GitHubCopilotChat/0.26.7" \
  -H "x-github-api-version: 2025-04-01" | jq -r '.token')

echo "🔍 Querying GitHub Copilot Enterprise API..."
echo ""

# Try /models endpoint
echo "GET https://api.enterprise.githubcopilot.com/models"
curl -s https://api.enterprise.githubcopilot.com/models \
  -H "Authorization: Bearer $COPILOT_TOKEN" \
  -H "Content-Type: application/json" | jq . 2>/dev/null || echo "❌ /models endpoint not found"

echo ""
echo "---"
echo ""

# Test with invalid model to see error response
echo "Testing with invalid model to see supported models list..."
curl -s https://api.enterprise.githubcopilot.com/chat/completions \
  -H "Authorization: Bearer $COPILOT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"INVALID_MODEL","messages":[{"role":"user","content":"test"}],"stream":false}' | jq .
