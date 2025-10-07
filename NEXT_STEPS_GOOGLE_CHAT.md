# Next Steps: Enable Two-Way Google Chat Approvals

## What's Working Now ✅

1. **Google Chat API enabled** in project `singularity-460212`
2. **Webhook URL configured** - Can send messages to Google Chat
3. **ngrok installed** - Ready to expose local server
4. **Webhook endpoint created** at `/webhooks/google-chat`

## What Needs To Be Done

### Step 1: Fix Server Startup Issues

The Phoenix server has dependency issues (missing modules like `Singularity.EmbeddingEngine`). Need to:

```bash
cd singularity_app
mix deps.get
mix compile
```

Then start the server:
```bash
mix phx.server
# Should run on http://localhost:4000
```

### Step 2: Expose Server with ngrok

Once the server is running:

```bash
# In a new terminal
ngrok http 4000
```

You'll get a URL like:
```
https://abc123.ngrok.io
```

Your webhook endpoint will be:
```
https://abc123.ngrok.io/webhooks/google-chat
```

### Step 3: Configure Google Chat Bot

1. Go to [Google Chat API Configuration](https://console.cloud.google.com/apis/api/chat.googleapis.com/hangouts-chat?project=singularity-460212)

2. Click **"Configuration"** tab

3. Fill in:
   - **App name:** Singularity
   - **Avatar URL:** (optional)
   - **Description:** AI agent approval system
   - **Functionality:**
     - ☑ Receive 1:1 messages
     - ☑ Join spaces and group conversations
   - **Connection settings:**
     - Select: **App URL (HTTP)**
     - **App URL:** `https://your-ngrok-url.ngrok.io/webhooks/google-chat`

4. **Permissions:**
   - Under "Visibility", choose who can install (Your Workspace or specific people)

5. Click **Save**

### Step 4: Add Bot to Your Space

1. Go to your Google Chat space (where the webhook is sending messages)
2. Click the space name → **Apps & integrations**
3. Click **Add apps**
4. Search for "Singularity" and add it

### Step 5: Test It!

**Send a test approval request:**

```elixir
# In iex -S mix
Singularity.HITL.GoogleChat.post_approval_request(
  "lib/test.ex",
  "+ def new_function, do: :ok",
  description: "Test approval",
  agent_id: "test"
)
```

**In Google Chat:**
- You'll see the request
- Type: `approve` or `reject`
- Singularity receives it at `/webhooks/google-chat`
- Check logs to see the webhook was received

## Quick Command Summary

```bash
# Terminal 1: Start Singularity
cd singularity_app
mix phx.server

# Terminal 2: Start ngrok
ngrok http 4000
# Copy the https://xxx.ngrok.io URL

# Terminal 3: Test webhook
curl -X POST https://xxx.ngrok.io/webhooks/google-chat \
  -H "Content-Type: application/json" \
  -d '{"type": "MESSAGE", "message": {"text": "approve", "sender": {"displayName": "Test User"}}}'
```

## Current Status

✅ API enabled
✅ ngrok installed
✅ Webhook endpoint coded
✅ One-way notifications working
⚠️ Server has startup issues (needs deps fixed)
⚠️ Webhook not exposed publicly yet
⚠️ Google Chat bot not configured yet

## For Now: Use One-Way Notifications

Until you fix the server and set up the webhook:

**Notifications work great!**
```bash
./test_google_chat.sh
```

You can use Singularity for:
- Error alerts
- Daily summaries
- Task notifications
- Agent status updates

Approvals can be added later when you have time to set up the webhook properly.

## Files Created

- ✅ [lib/singularity_web/health_router.ex](singularity_app/lib/singularity_web/health_router.ex:70) - Webhook receiver
- ✅ [.envrc](.envrc:128-136) - Google Chat config
- ✅ [test_google_chat.sh](test_google_chat.sh:1) - Test script
- ✅ [GOOGLE_CHAT_SETUP.md](GOOGLE_CHAT_SETUP.md:1) - Setup guide
- ✅ [GOOGLE_CHAT_APPROVALS_SETUP.md](GOOGLE_CHAT_APPROVALS_SETUP.md:1) - Detailed approval setup
- ✅ [NEXT_STEPS_GOOGLE_CHAT.md](NEXT_STEPS_GOOGLE_CHAT.md:1) - This file

**You're 80% of the way there!** Just need to fix the server startup and expose it with ngrok.
