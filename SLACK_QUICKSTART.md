# Slack Quick Start (2 minutes!)

## Your Slack Token

You already have your token: `xoxe-xoxp-1-Mi0yLTg5MDI2MTM1Mzk1MDQtODkwMjYxMzU1MDEyOC05NjQ4NDM3NjI4MTAzLTk2NTc0OTI5NTY3NTUtYTg5YmQ3Yjk0ZTdjYWZlYmJhN2E5MjQyMDc0ZjkzMmI1MTE1MDBlOTkzNjRiODM4ODQ3Y2E0NDBkYjgzZDVjMA`

## Setup (2 minutes)

### 1. Add to `.env` file:

```bash
cd /home/mhugo/code/singularity
cat >> .env << 'EOF'

# Slack Configuration
SLACK_TOKEN="xoxe-xoxp-1-Mi0yLTg5MDI2MTM1Mzk1MDQtODkwMjYxMzU1MDEyOC05NjQ4NDM3NjI4MTAzLTk2NTc0OTI5NTY3NTUtYTg5YmQ3Yjk0ZTdjYWZlYmJhN2E5MjQyMDc0ZjkzMmI1MTE1MDBlOTkzNjRiODM4ODQ3Y2E0NDBkYjgzZDVjMA"
SLACK_DEFAULT_CHANNEL="#agent-notifications"
CHAT_CHANNEL="slack"
WEB_URL="http://localhost:4000"
EOF
```

### 2. Create Slack channel (if doesn't exist):

In Slack app:
- Click **"+"** next to Channels
- Name: `agent-notifications`
- Click **"Create"**

### 3. Restart Singularity:

```bash
cd singularity_app
nix develop ..#singularity-integrated --command mix phx.server
```

## Test It! (30 seconds)

### Option 1: Quick test from command line

```bash
cd singularity_app
nix develop ..#singularity-integrated --command iex -S mix
```

Then in IEx:
```elixir
alias Singularity.Conversation.Slack
Slack.notify("🎉 Slack integration is working!")
```

### Option 2: Test with agent conversation

```elixir
alias Singularity.Conversation.ChatConversationAgent

# Ask a question
ChatConversationAgent.ask("Should I refactor this module?",
  context: %{file: "lib/my_module.ex"},
  urgency: :high
)
```

## What You'll See

Messages will appear in your `#agent-notifications` channel with:
- ✅ Rich formatting (bold, emoji, code blocks)
- 🔘 Interactive buttons (for approvals/questions)
- 📱 Mobile notifications
- 💬 Threaded conversations

## Troubleshooting

### "Slack not configured" error

**Check your .env file:**
```bash
grep SLACK_TOKEN .env
```

Should output:
```
SLACK_TOKEN="xoxe-xoxp-..."
```

### No messages in Slack

1. **Verify channel name:**
   ```bash
   grep SLACK_DEFAULT_CHANNEL .env
   ```

2. **Check Slack app is installed** in your workspace

3. **Restart Phoenix server:**
   ```bash
   # Kill old server (Ctrl+C)
   mix phx.server  # Start fresh
   ```

### Token invalid error

Your token might have expired. Get a new one:
1. Go to https://api.slack.com/apps
2. Select your app
3. **"OAuth & Permissions"** → Copy new token
4. Update `.env` with new token

## Advanced Usage

See [docs/SLACK_SETUP.md](docs/SLACK_SETUP.md) for:
- Interactive button handling
- Multiple channels
- Custom formatting
- Bot token features
- Production deployment

## Next Steps

1. ✅ Test basic notification (above)
2. Try asking a question
3. Test approval workflow
4. Set up daily summaries
5. Customize messages in `lib/singularity/conversation/slack.ex`

---

**Need help?** Check logs:
```bash
tail -f singularity_app/logs/dev.log | grep Slack
```
