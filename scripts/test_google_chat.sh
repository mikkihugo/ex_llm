#!/bin/bash
# Test Google Chat webhook integration
# This shows you how to send messages to Google Chat

WEBHOOK_URL="https://chat.googleapis.com/v1/spaces/AAQAwUL-JVA/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=9Y28DBKXSvJ7iWjCmm-Db8FLLsIagRZnO56ovN8R-fk"

echo "=== Google Chat Webhook Test ==="
echo ""
echo "Sending test message..."
echo ""

response=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "text": "✅ Google Chat is WORKING!\n\n📊 Dynamic Tool Limits Implemented:\n• Tiny models (12k): 4 tools\n• Small models (128k): 12 tools\n• Large models (200k): 20 tools\n• Huge models (2M): 30 tools\n\n🚀 Singularity ready for agent approvals!"
  }' \
  "$WEBHOOK_URL")

if echo "$response" | grep -q '"name"'; then
  echo "✅ SUCCESS! Message sent to Google Chat"
  echo ""
  echo "Check your Google Chat space to see the message!"
  echo ""
  echo "Response:"
  echo "$response" | jq -r '.text' 2>/dev/null || echo "$response"
else
  echo "❌ FAILED"
  echo "Response: $response"
  exit 1
fi

echo ""
echo "=== How to Use in Your Code ==="
echo ""
echo "From Elixir:"
echo '  Singularity.Conversation.GoogleChat.notify("Your message here")'
echo ""
echo "From Bash:"
echo '  curl -X POST -H "Content-Type: application/json" \'
echo '    -d '"'"'{"text": "Your message"}'"'"' \'
echo '    "$GOOGLE_CHAT_WEBHOOK_URL"'
echo ""
