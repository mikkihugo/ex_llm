#!/bin/bash
# Authorize GitHub Copilot via OAuth device flow
# This script handles the complete OAuth flow including polling

set -e

SERVER_URL="${SERVER_URL:-http://localhost:3000}"
POLL_INTERVAL=5

echo "🔐 Starting GitHub Copilot OAuth authorization..."
echo ""

# Start OAuth flow
RESPONSE=$(curl -s "$SERVER_URL/copilot/auth/start")
DEVICE_CODE=$(echo "$RESPONSE" | jq -r '.device_code')
USER_CODE=$(echo "$RESPONSE" | jq -r '.user_code')
VERIFICATION_URI=$(echo "$RESPONSE" | jq -r '.verification_uri')
EXPIRES_IN=$(echo "$RESPONSE" | jq -r '.expires_in')

echo "📋 Authorization Details:"
echo "   URL: $VERIFICATION_URI"
echo "   Code: $USER_CODE"
echo "   Expires in: $EXPIRES_IN seconds"
echo ""
echo "👉 Opening browser to $VERIFICATION_URI"
echo "   Enter code: $USER_CODE"
echo ""

# Open browser automatically
if command -v xdg-open > /dev/null; then
  xdg-open "$VERIFICATION_URI" 2>/dev/null &
elif command -v open > /dev/null; then
  open "$VERIFICATION_URI" 2>/dev/null &
elif command -v wslview > /dev/null; then
  wslview "$VERIFICATION_URI" 2>/dev/null &
else
  echo "⚠️  Could not open browser automatically. Please visit:"
  echo "   $VERIFICATION_URI"
fi

echo "⏳ Waiting for authorization (polling every $POLL_INTERVAL seconds)..."
echo "   Press Ctrl+C to cancel"
echo ""

# Poll for completion
ATTEMPTS=0
MAX_ATTEMPTS=$((EXPIRES_IN / POLL_INTERVAL))

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
  sleep $POLL_INTERVAL
  ATTEMPTS=$((ATTEMPTS + 1))

  RESULT=$(curl -s -X POST "$SERVER_URL/copilot/auth/complete" \
    -H "Content-Type: application/json" \
    -d "{\"device_code\": \"$DEVICE_CODE\"}")

  SUCCESS=$(echo "$RESULT" | jq -r '.success // false')
  ERROR=$(echo "$RESULT" | jq -r '.error // ""')

  if [ "$SUCCESS" = "true" ]; then
    echo ""
    echo "✅ Authorization successful!"
    echo "   Tokens saved to ~/.local/share/copilot-api/tokens.json"
    echo "   Auto-refresh enabled - tokens will renew automatically"
    echo ""
    exit 0
  elif [ "$ERROR" != "authorization_pending" ] && [ "$ERROR" != "" ]; then
    echo ""
    echo "❌ Authorization failed: $ERROR"
    exit 1
  fi

  # Show progress
  printf "."
done

echo ""
echo "⏱️  Authorization timed out. Please try again."
exit 1
