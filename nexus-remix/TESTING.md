# Testing Nexus HITL Control Panel

Complete guide to testing the WebSocket bridge, NATS integration, and end-to-end HITL flow.

## Prerequisites

Before running tests, make sure you have:

```bash
# 1. NATS running
nats-server -js &

# 2. Remix dev server running (in nexus-remix directory)
bun run dev &

# 3. Browser open to the approvals page
# Open: http://localhost:3000/approvals
```

---

## Quick Start: 5-Minute End-to-End Test

### Step 1: Start Services

**Terminal 1 - NATS:**
```bash
nats-server -js
# Should show: "Listening on 127.0.0.1:4222"
```

**Terminal 2 - Remix:**
```bash
cd /Users/mhugo/code/singularity-incubation/nexus-remix
bun run dev
# Should show: "Remix + Bun HITL Control Panel running on http://localhost:3000"
```

**Step 2: Open Browser**

```bash
# In a new browser window
open http://localhost:3000/approvals
```

You should see:
- ✅ Page loads (Dashboard, Approvals & Questions, System Status tabs)
- ✅ "Connecting to approval bridge..." message briefly
- ✅ Then "Approvals & Questions" panel ready

**Step 3: Check WebSocket Connection**

In browser DevTools:
1. Press `F12` to open DevTools
2. Go to **Network** tab
3. Filter for **WS** (WebSocket)
4. You should see `/ws/approval` connection
5. Right-click it → **Show in Network** → Check Status: `101 Web Socket Protocol Handshake`

**Step 4: Run Test Script**

**Terminal 3 - Test Script:**
```bash
cd /Users/mhugo/code/singularity-incubation/nexus-remix
bun run scripts/send-test-approval.ts approved
```

Expected output:
```
📝 Sending test approval request (will approved in browser)
📍 NATS URL: nats://127.0.0.1:4222

✅ Connected to NATS

📤 Sending request:
   ID: 550e8400-e29b-41d4-a716-446655440000
   File: lib/test/example.ex
   Description: Test approval request - please click APPROVED

⏳ Waiting for response from browser (30s timeout)...
   (In browser, click "Approve" or "Reject" button)
```

**Step 5: Respond in Browser**

In the browser, you should see an approval card appear:
```
Code Approval Requested
lib/test/example.ex
Test approval request - please click APPROVED

[CODE DIFF PREVIEW]

[Reject] [Approve]
```

Click **Approve** button.

**Step 6: Verify Response**

In Terminal 3, you should see:
```
✅ Received response:
   {"approved": true}
   ✅ Correct response!

Done!
```

🎉 **SUCCESS! End-to-end flow is working!**

---

## Detailed Testing Scenarios

### Test 1: Approval Card with Diff Preview

```bash
bun run scripts/send-test-approval.ts approved
```

**Expected Flow:**
1. ✅ Card appears in browser with file path
2. ✅ Code diff is visible and scrollable
3. ✅ Approve/Reject buttons are clickable
4. ✅ Click Approve → Terminal shows response
5. ✅ Card disappears after response

---

### Test 2: Question Card with Context

```bash
bun run scripts/send-test-question.ts
```

**Expected Flow:**
1. ✅ Card appears with question text
2. ✅ Context section shows JSON (scrollable)
3. ✅ Text input is ready for answer
4. ✅ 💡 button is available (for LLM suggestions)
5. ✅ Type answer → Click "Answer" button
6. ✅ Terminal shows response with your answer

---

### Test 3: Multiple Rapid Requests

```bash
bun run scripts/test-hitl-flow.ts
```

This script:
1. Sends approval request
2. Waits for response
3. Sends question request
4. Waits for response
5. Sends 2 rapid approvals back-to-back
6. Reports success/failure count

**Expected Flow:**
```
✅ Test 1: Sending approval request
⏳ Waiting for approval response (30s timeout)...
   (In browser, click "Approve" or "Reject" button)

[Wait for your click in browser]

✅ Received approval response: {"approved":true}

📝 Test 2: Sending question request
⏳ Waiting for question response (30s timeout)...
   (In browser, type answer and click "Answer" button)

[Wait for your input in browser]

✅ Received question response: {"response":"yes, implement caching"}

📝 Test 3: Sending rapid sequential requests
  Sending: Quick refactor 1
  ✅ Response received
  Sending: Quick refactor 2
  ✅ Response received

📊 Results: 2 succeeded, 0 failed

✅ Test complete!
```

---

## Troubleshooting

### Issue: "No responders available"

```
❌ No responders - WebSocket bridge not connected
```

**Causes:**
1. NATS not running
2. Remix server not running
3. Browser page not open to `/approvals`
4. WebSocket connection failed

**Fix:**
```bash
# Terminal 1: Check NATS
nats-server -js
# Should show: "Ready for connections"

# Terminal 2: Check Remix
cd nexus-remix && bun run dev
# Should show: "Remix + Bun HITL Control Panel running on http://localhost:3000"

# Browser: Navigate to http://localhost:3000/approvals
# Check DevTools → Network → WS tab for /ws/approval connection
```

---

### Issue: "Timed out waiting for response"

```
⏱️  Timed out (no response from browser)
```

**Causes:**
1. Forgot to click button in browser
2. Browser is not responsive
3. WebSocket disconnected

**Fix:**
```bash
# Refresh browser
open http://localhost:3000/approvals

# Check WebSocket is connected (DevTools → Network → WS)

# Run test again and make sure to click the button quickly
bun run scripts/send-test-approval.ts approved
```

---

### Issue: Browser Shows "Connecting to approval bridge..."

```
Text: "Connecting to approval bridge..."
```

**Causes:**
1. WebSocket is trying to connect but not established
2. Server hasn't started yet
3. NATS isn't available

**Fix:**
```bash
# 1. Make sure Remix server is running
bun run dev

# 2. Make sure NATS is running
nats-server -js

# 3. Wait 3 seconds for auto-reconnect
# The hook has 3-second retry logic

# 4. Refresh browser if it doesn't connect
```

---

### Issue: Card Appears but Buttons Don't Work

**Causes:**
1. React component not mounted
2. WebSocket send failed
3. Server error

**Fix:**
```bash
# Check browser console (F12 → Console)
# Look for JavaScript errors

# Check Network tab (F12 → Network → WS)
# WebSocket should show messages being sent

# Restart Remix server
# Kill: pkill -f "bun run dev"
# Restart: bun run dev
```

---

## Manual Testing via NATS CLI

You can also test using the NATS CLI directly:

### Test Approval with NATS CLI

```bash
# Terminal 1: Listen for approval requests
nats sub "approval.request"

# Terminal 2: Send test approval request
nats pub "approval.request" '{
  "id": "test-1",
  "agent_id": "test",
  "type": "approval",
  "timestamp": "2025-01-10T12:00:00Z",
  "file_path": "lib/test.ex",
  "diff": "test diff",
  "description": "Test"
}' --reply="approval.response.test-1"

# Terminal 3: Send response
nats pub "approval.response.test-1" '{"approved": true}'
```

---

## Performance Testing

### Measure WebSocket Latency

Open browser console and run:

```javascript
// In browser console
const start = performance.now();
ws.send(JSON.stringify({
  requestId: 'latency-test',
  type: 'approval',
  approved: true
}));

// Measure time when you see "response_received" message
const end = performance.now();
console.log(`Latency: ${end - start}ms`);
```

Expected: **<50ms** for round-trip NATS message

---

### Bundle Size Check

```bash
bun run build
du -sh build/
```

Expected: **~85KB** total (including assets)

Breakdown:
- `build/index.js` - ~40KB (server + client code)
- Tailwind CSS - ~20KB
- Static assets - ~25KB

---

## Load Testing

Test multiple concurrent HITL requests:

```bash
# Send 10 approval requests rapidly
for i in {1..10}; do
  bun run scripts/send-test-approval.ts approved &
done
wait
```

Expected:
- All 10 cards appear in browser
- All 10 respond to clicks
- All 10 responses recorded in terminal

---

## Integration Testing with Singularity

Once you've verified the NATS ↔ WebSocket bridge works, test with actual Singularity:

```bash
# 1. Start NATS
nats-server -js

# 2. Start Nexus Remix
cd nexus-remix && bun run dev

# 3. Start Singularity
cd singularity && mix phx.server

# 4. In Singularity, trigger an agent that requests approval:
# This depends on your agent implementation, but something like:
# iex> ApprovalService.request_approval(...)
```

Watch for:
1. ✅ Card appears in browser
2. ✅ You can approve/reject
3. ✅ Agent receives decision
4. ✅ Agent continues with changes applied/skipped

---

## Test Checklist

Use this checklist to verify all components:

```
Infrastructure:
  [ ] NATS server running (nats-server -js)
  [ ] Remix dev server running (bun run dev)
  [ ] Browser open to http://localhost:3000/approvals

WebSocket Connection:
  [ ] DevTools shows /ws/approval connection (101 status)
  [ ] Console shows "[useApprovalWebSocket] Connected"
  [ ] Status changes from "Connecting..." to showing cards

NATS Integration:
  [ ] Test script connects to NATS successfully
  [ ] Approval request sent via NATS
  [ ] Question request sent via NATS
  [ ] Bridge receives both request types

Browser UI:
  [ ] Approval cards render with file path
  [ ] Code diff is visible and scrollable
  [ ] Approve/Reject buttons work
  [ ] Question cards render with text input
  [ ] Context section shows JSON
  [ ] Answer button works
  [ ] Cards disappear after response

Round-Trip Flow:
  [ ] Run test script → Card appears → Click button → Script gets response
  [ ] Multiple rapid requests work
  [ ] Timeouts handled gracefully
  [ ] Reconnection after disconnect works

Performance:
  [ ] Dev server starts in <1s
  [ ] WebSocket connects in <100ms
  [ ] Card appears in <100ms after request sent
  [ ] Response sent in <50ms after click
  [ ] Bundle is ~85KB
```

---

## Quick Test Commands

```bash
# Run these in order:

# Start infrastructure
nats-server -js &
cd nexus-remix && bun run dev &
open http://localhost:3000/approvals

# Then in separate terminal, run tests:
bun run scripts/send-test-approval.ts approved
bun run scripts/send-test-question.ts
bun run scripts/test-hitl-flow.ts
```

---

## Next Steps

Once all tests pass:

1. ✅ Write a test for Singularity integration
2. ✅ Deploy Remix to production
3. ✅ Test with real agents requesting approvals
4. ✅ Monitor WebSocket connections in production
5. ✅ (Optional) Add shadcn/ui components for better UI

---

## Support

If tests fail:

1. Check browser console (F12 → Console) for errors
2. Check server logs (Terminal 2) for error messages
3. Check NATS logs (Terminal 1) for connection issues
4. Verify all 3 services are running:
   - `ps aux | grep nats-server`
   - `ps aux | grep "bun run dev"`
   - Browser has focus on `/approvals` tab
