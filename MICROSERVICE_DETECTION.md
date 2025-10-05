# How Pattern Extractor Finds Microservices

## What Gets Detected

### Example: NATS Microservice

```elixir
defmodule MyApp.UserService do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, conn} = Gnat.start_link(%{host: "localhost", port: 4222})
    Gnat.sub(conn, self(), "user.>")
    {:ok, %{conn: conn}}
  end

  def handle_info({:msg, %{topic: "user.create", body: body}}, state) do
    user = Jason.decode!(body)
    {:noreply, state}
  end
end
```

**Extracted patterns:**
```elixir
CodePatternExtractor.extract_from_code(code, :elixir)
# => [
#   "genserver",           # OTP process pattern
#   "state",               # State management
#   "concurrent",          # Concurrent processing
#   "otp",                 # OTP behavior
#   "nats",                # NATS messaging
#   "messaging",           # Message-based
#   "pubsub",              # Pub/sub pattern
#   "handle_info",         # Message handler
#   "message",             # Message processing
#   "event",               # Event-driven
#   "init",                # Initialization
#   "lifecycle",           # Lifecycle management
#   "user",                # Domain: users
#   "start",               # Startup logic
#   "service"              # Microservice
# ]
```

---

## How It Identifies Microservices

### Pattern Combination Detection

A microservice typically has these patterns:

```elixir
# Microservice signature = GenServer + Messaging + Event handling
microservice_patterns = [
  "genserver",     # Process-based
  "nats",          # OR "kafka", "rabbitmq", "http"
  "messaging",     # Message-based communication
  "handle_info",   # OR "handle_call", "handle_cast"
  "init"           # Initialization
]

# If file has 3+ of these → It's a microservice
```

### Different Microservice Types Detected

#### 1. NATS Microservice
```elixir
use GenServer
Gnat.start_link()
Gnat.sub(conn, self(), "events.>")
```
**Patterns:** `["genserver", "nats", "messaging", "pubsub"]`

#### 2. HTTP API Microservice
```elixir
use Plug.Router
plug :match
plug :dispatch

get "/users/:id" do
  # ...
end
```
**Patterns:** `["http", "api", "rest", "plug", "web", "server"]`

#### 3. Broadway Pipeline (Stream Processing)
```elixir
use Broadway

def handle_message(_processor, message, _context) do
  # Process message
end
```
**Patterns:** `["broadway", "pipeline", "stream", "data_flow"]`

#### 4. Phoenix Channel (WebSocket Service)
```elixir
use Phoenix.Channel

def join("room:" <> room_id, _params, socket) do
  {:ok, socket}
end

def handle_in("new_msg", payload, socket) do
  broadcast(socket, "new_msg", payload)
  {:noreply, socket}
end
```
**Patterns:** `["channel", "websocket", "pubsub", "realtime"]`

---

## Finding All Microservices in Codebase

### Query: "Show me all microservices"

```elixir
defmodule Singularity.MicroserviceFinder do
  @doc """
  Find all microservices in codebase.

  A microservice has:
  1. GenServer OR Phoenix.Channel OR Plug.Router OR Broadway
  2. Some form of messaging (NATS, HTTP, WebSocket, Kafka)
  3. Event handlers
  """

  def find_all_microservices(codebase_path) do
    # Use the index (to be built this week)
    microservice_indicators = [
      # NATS-based
      ["genserver", "nats"],
      ["genserver", "messaging"],

      # HTTP-based
      ["plug", "http"],
      ["phoenix", "endpoint"],

      # Stream-based
      ["broadway", "pipeline"],

      # WebSocket-based
      ["channel", "websocket"]
    ]

    # Find files matching any indicator pattern
    microservice_indicators
    |> Enum.flat_map(fn patterns ->
      CodeLocationIndex.find_by_all_patterns(patterns)
    end)
    |> Enum.uniq()
  end

  def categorize_microservice(filepath) do
    patterns = CodePatternExtractor.extract_from_code(
      File.read!(filepath),
      :elixir
    )

    cond do
      "nats" in patterns -> :nats_microservice
      "broadway" in patterns -> :stream_processor
      "channel" in patterns -> :websocket_service
      "plug" in patterns and "http" in patterns -> :http_api
      "genserver" in patterns -> :otp_service
      true -> :unknown
    end
  end
end
```

### Example Output

```elixir
iex> MicroserviceFinder.find_all_microservices(".")

[
  # NATS microservices
  %{
    path: "lib/services/user_service.ex",
    type: :nats_microservice,
    patterns: ["genserver", "nats", "messaging", "pubsub"],
    subjects: ["user.>", "user.create", "user.update"]
  },

  %{
    path: "lib/services/email_service.ex",
    type: :nats_microservice,
    patterns: ["genserver", "nats", "messaging"],
    subjects: ["email.send"]
  },

  # HTTP APIs
  %{
    path: "lib/api/user_controller.ex",
    type: :http_api,
    patterns: ["plug", "http", "rest", "api"],
    routes: ["/users", "/users/:id"]
  },

  # Stream processors
  %{
    path: "lib/pipelines/analytics_pipeline.ex",
    type: :stream_processor,
    patterns: ["broadway", "pipeline", "stream"],
    source: "kafka"
  },

  # WebSocket services
  %{
    path: "lib/channels/notification_channel.ex",
    type: :websocket_service,
    patterns: ["channel", "websocket", "pubsub", "realtime"],
    topics: ["notifications:*"]
  }
]
```

---

## Microservice Architecture Visualization

Once you have the index (Week 1), you can generate architecture diagrams:

```elixir
defmodule Singularity.ArchitectureMapper do
  @doc """
  Generate microservice architecture map.

  Shows:
  - All microservices
  - How they communicate (NATS subjects, HTTP endpoints)
  - Dependencies between services
  """

  def generate_map(codebase_path) do
    microservices = MicroserviceFinder.find_all_microservices(codebase_path)

    # Build communication graph
    %{
      services: microservices,
      communication: build_communication_map(microservices),
      dependencies: build_dependency_graph(microservices)
    }
  end

  defp build_communication_map(microservices) do
    Enum.flat_map(microservices, fn service ->
      case service.type do
        :nats_microservice ->
          # Extract NATS subjects this service publishes/subscribes to
          subjects = extract_nats_subjects(service.path)
          Enum.map(subjects, fn {action, subject} ->
            %{from: service.path, to: subject, via: :nats, action: action}
          end)

        :http_api ->
          # Extract HTTP routes
          routes = extract_http_routes(service.path)
          Enum.map(routes, fn {method, path} ->
            %{service: service.path, endpoint: path, method: method}
          end)

        _ -> []
      end
    end)
  end
end
```

### Example Architecture Output

```
Microservice Architecture (15 services found)

NATS-based Services (8):
  • UserService          → Subscribes: user.>
                         → Publishes: user.created, user.updated

  • EmailService         → Subscribes: email.send
                         → Publishes: email.sent

  • NotificationService  → Subscribes: user.created, email.sent
                         → Publishes: notification.sent

HTTP APIs (4):
  • UserAPI              → GET /users, POST /users, GET /users/:id
  • AuthAPI              → POST /auth/login, POST /auth/refresh

Stream Processors (2):
  • AnalyticsPipeline    → Source: Kafka (events topic)
  • LogAggregator        → Source: NATS (logs.>)

WebSocket Services (1):
  • NotificationChannel  → Topics: notifications:*

Communication Flow:
  UserAPI (POST /users)
    → Publishes: user.created (NATS)
      → EmailService receives → sends welcome email
      → NotificationService receives → sends push notification
```

---

## Query Examples

After building the index (Week 1), you can ask:

### 1. "Show me all NATS microservices"
```elixir
CodeLocationIndex.find_by_patterns(["genserver", "nats"])
# => [user_service.ex, email_service.ex, webhook_service.ex, ...]
```

### 2. "Which services subscribe to user.created?"
```elixir
NatsSubjectIndex.find_subscribers("user.created")
# => [email_service.ex, notification_service.ex, analytics_pipeline.ex]
```

### 3. "What subjects does UserService publish to?"
```elixir
NatsSubjectIndex.find_publishers("lib/services/user_service.ex")
# => ["user.created", "user.updated", "user.deleted"]
```

### 4. "Show me all HTTP endpoints"
```elixir
CodeLocationIndex.find_by_patterns(["http", "api", "plug"])
# => [user_api.ex, auth_api.ex, webhook_api.ex]
```

### 5. "Is there already a webhook service?"
```elixir
DuplicationDetector.find_similar("webhook NATS consumer")
# => [
#   {"lib/services/webhook_service.ex", 0.95},  # 95% match - already exists!
#   {"lib/services/notification_service.ex", 0.45}
# ]
```

---

## Integration with AI

### Before AI Creates New Microservice

```
AI: "I want to create a webhook consumer for GitHub events"

System checks:
  1. Extract patterns: ["webhook", "github", "consumer", "nats"]

  2. Find existing:
     ✓ Found: lib/services/webhook_service.ex (95% match)
     ✓ Already handles webhooks via NATS

  3. Decision:
     ❌ DON'T create new microservice
     ✅ Extend webhook_service.ex to handle GitHub events
     ✅ Add new NATS subject: github.webhook

  4. Wire-up guidance:
     - Subscribe to: github.webhook
     - Publish to: github.event.* (based on event type)
     - Pattern: Same as existing webhook handlers
```

---

## Summary

**Pattern extractor finds microservices by detecting:**

✅ **Process patterns:** GenServer, Broadway, Phoenix.Channel
✅ **Communication:** NATS, HTTP, WebSocket, Kafka
✅ **Event handling:** handle_info, handle_call, handle_message
✅ **Domain patterns:** Function/module names

**After building index (Week 1):**
- Query: "Show all microservices" → Get list
- Query: "NATS subscribers to topic X" → Find services
- Check: "Does webhook service exist?" → Avoid duplicates
- Map: "Service architecture" → Visualize communication

**No embeddings needed** - keyword patterns work perfectly! 🎯
