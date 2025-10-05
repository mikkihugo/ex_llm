# Pattern Extraction System

**What it does:** Extracts architectural patterns from code and user requests using concrete technical keywords (not marketing fluff).

## The Problem

AI needs to know **what patterns to apply**, but most templates just have "enterprise-ready" and "production-grade" - useless fluff.

## The Solution

Extract **concrete technical patterns** from:
1. User requests → "Create NATS consumer" → `["nats", "consumer", "messaging"]`
2. Existing code → `use GenServer` → `["genserver", "state", "concurrent", "otp"]`
3. Match against templates → Find best architectural pattern

## How It Works

### 1. Extract Patterns from Text

```elixir
iex> CodePatternExtractor.extract_from_text("Create API client with retry logic")
["create", "api", "client", "retry", "logic"]
```

### 2. Extract Patterns from Code

```elixir
code = """
defmodule NatsConsumer do
  use GenServer
  use Broadway

  def handle_call(:subscribe, _from, state) do
    Gnat.sub(state.conn, self(), "events.>")
    {:reply, :ok, state}
  end
end
"""

CodePatternExtractor.extract_from_code(code, :elixir)
# => ["genserver", "state", "concurrent", "otp", "broadway", "pipeline",
#     "stream", "nats", "messaging", "handle_call", "synchronous"]
```

### 3. Match Against Templates

```elixir
patterns = [
  %{
    name: "nats_microservice",
    keywords: ["nats", "consumer", "messaging"],
    relationships: ["genserver", "supervisor", "circuit_breaker"]
  },
  %{
    name: "http_client",
    keywords: ["http", "api", "client"],
    relationships: ["retry", "rate_limit"]
  }
]

user_keywords = ["nats", "consumer", "genserver"]

CodePatternExtractor.find_matching_patterns(user_keywords, patterns)
# => [
#   %{
#     score: 5.5,  # 2 keyword matches (4.0) + 1 relationship match (1.5)
#     pattern: "nats_microservice",
#     matched_keywords: ["nats", "consumer"]
#   }
# ]
```

### 4. Get Full Template with Architecture

```elixir
TemplateMatcher.find_template("Create NATS consumer with Broadway")
# => {:ok, %{
#   template: "elixir_production",
#   pattern: "nats_microservice",
#   score: 8.5,
#   relationships: ["genserver", "supervisor", "broadway_pipeline"],
#   architectural_guidance: %{
#     primary_pattern: "NATS microservice",
#     required_patterns: [
#       %{
#         name: "genserver",
#         why: "nats_microservice requires genserver",
#         structure: "...GenServer code structure..."
#       },
#       %{
#         name: "supervisor",
#         why: "nats_microservice requires supervisor",
#         structure: "...Supervisor code structure..."
#       }
#     ],
#     integration_points: [
#       "GenServer manages NATS connection lifecycle and subscription state",
#       "Supervisor restarts nats_microservice on failure"
#     ]
#   }
# }}
```

## Pattern Categories

### Process Patterns
- `genserver`, `supervisor`, `broadway`, `actor`
- Detected from: `use GenServer`, `use Supervisor`, `use Broadway`, `import gleam/otp/actor`

### Integration Patterns
- `nats`, `http`, `database`, `kafka`
- Detected from: `Gnat.`, `Tesla.`, `Req.`, `Ecto.Schema`

### Resilience Patterns
- `circuit_breaker`, `retry`, `error_handling`
- Detected from: `with`, circuit breaker libs, retry logic

### Concurrency Patterns
- `async`, `concurrent`, `await`, `process`
- Detected from: `async fn`, `.await`, `tokio`, OTP patterns

## Example: Full Flow

**User:** "Create a NATS consumer with Broadway pipeline"

```elixir
# 1. Extract keywords
keywords = CodePatternExtractor.extract_from_text(request)
# => ["create", "nats", "consumer", "broadway", "pipeline"]

# 2. Find matching template
{:ok, match} = TemplateMatcher.find_template(request)

# 3. Get architectural guidance
match.architectural_guidance
# => %{
#   primary_pattern: "NATS consumer with Broadway",
#   required_patterns: [
#     "GenServer for connection management",
#     "Supervisor for fault tolerance",
#     "Broadway pipeline for message processing"
#   ],
#   integration_points: [
#     "GenServer manages NATS connection lifecycle",
#     "Broadway processes messages from NATS subscription",
#     "Supervisor restarts on connection failures"
#   ]
# }

# 4. Generate code using template + patterns
# AI now knows exactly what to build and how it fits together!
```

## Why This Helps AI

### ❌ Without Pattern Extraction
- Template: "Enterprise-ready microservice architecture"
- AI: "What does that mean? Just add some error handling I guess?"

### ✅ With Pattern Extraction
- Extracted: `["nats", "consumer", "genserver", "supervisor"]`
- Template Match: NATS microservice pattern
- Required Patterns: GenServer (state management), Supervisor (fault tolerance), Circuit breaker (resilience)
- AI: "Build GenServer for connection, Supervisor for restarts, add circuit breaker for downstream failures. Here's exactly how they integrate..."

## The Intelligence is in the Template

Your templates already have the knowledge:

```json
{
  "pattern": "nats_microservice",
  "keywords": ["nats", "consumer", "messaging", "pubsub"],
  "relationships": ["genserver", "supervisor", "circuit_breaker"],
  "structure": {
    "supervision": "one_for_one strategy",
    "state": "connection + subscription state",
    "error_handling": "circuit breaker on connection failures"
  }
}
```

Pattern extractor just finds the right template and loads all its architectural knowledge!

## Usage

```elixir
# Extract from user request
CodePatternExtractor.extract_from_text("Create NATS consumer")

# Extract from existing code
CodePatternExtractor.extract_from_code(code, :elixir)

# Find matching patterns
CodePatternExtractor.find_matching_patterns(keywords, template_patterns)

# Get full template with architecture
TemplateMatcher.find_template("Create NATS consumer")

# Analyze existing code
TemplateMatcher.analyze_code(code, :elixir)
```

## Supported Languages

- **Elixir**: GenServer, Supervisor, Broadway, NATS, Phoenix, Ecto
- **Gleam**: Actor, Supervisor, HTTP, JSON
- **Rust**: Async/tokio, Serde, NATS, traits

Easy to extend for more languages/patterns!
