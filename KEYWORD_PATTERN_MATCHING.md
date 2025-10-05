# Keyword to Pattern Matching System

## The Problem

User says: **"Create an API client with authentication"**

How does the system know:
- ✅ Use "API client" pattern?
- ✅ Add "OAuth2" authentication?
- ✅ Include rate limiting?
- ✅ Add retry logic?

---

## The Solution: Semantic Pattern Matching

Your templates already have **keyword mappings**! Look at `elixir_production.json`:

### Pattern Definitions (lines 101-126)

```json
{
  "pattern": "API client",
  "pseudocode": "module → client_state → request(method, path, params) → {:ok, response} | {:error, reason}",
  "relationships": ["GenServer for state", "HTTP client (Req/Finch)", "rate limiting", "retry logic"],
  "keywords": ["http", "api", "request", "client", "endpoint"]  ← MATCHING KEYWORDS
}

{
  "pattern": "GenServer cache",
  "pseudocode": "GenServer → state:map → get(key) → {:ok, value} | :not_found",
  "relationships": ["ETS for backing", "periodic cleanup", "pub/sub for invalidation"],
  "keywords": ["cache", "genserver", "state", "ttl", "get", "put"]  ← MATCHING KEYWORDS
}

{
  "pattern": "Data pipeline",
  "pseudocode": "Broadway → fetch → validate → transform → store → handle_failed",
  "relationships": ["producers", "processors", "batchers", "error handling"],
  "keywords": ["pipeline", "stream", "transform", "batch", "flow"]  ← MATCHING KEYWORDS
}

{
  "pattern": "Ecto schema",
  "pseudocode": "schema → fields → associations → changeset → validations → repo operations",
  "relationships": ["belongs_to", "has_many", "many_to_many", "embeds"],
  "keywords": ["schema", "changeset", "repo", "association", "validation"]  ← MATCHING KEYWORDS
}
```

---

## How Matching Works

### Implementation in ContextBuilder

```rust
impl ContextBuilder {
    /// Match user request to semantic patterns
    fn match_patterns(&self, user_request: &str) -> Vec<String> {
        let request_lower = user_request.to_lowercase();
        let mut matched_patterns = Vec::new();

        // Load patterns from template
        let patterns = load_semantic_patterns(self.framework);

        for pattern in patterns {
            // Check if any keywords match user request
            for keyword in &pattern.keywords {
                if request_lower.contains(keyword) {
                    matched_patterns.push(pattern.clone());
                    break;
                }
            }
        }

        matched_patterns
    }

    /// Select patterns and load related components
    pub fn with_pattern_detection(mut self, user_request: &str) -> Self {
        let matched = self.match_patterns(user_request);

        for pattern in matched {
            // Add pattern-specific bits
            for relationship in pattern.relationships {
                self.add_related_component(relationship);
            }
        }

        self
    }
}
```

---

## Real Example: User Request Processing

### Example 1: "Create an API client with authentication"

**Step 1: Keyword Extraction**
```
Input: "Create an API client with authentication"
Extracted keywords: ["api", "client", "authentication"]
```

**Step 2: Pattern Matching**
```json
Matched patterns:

1. "API client" pattern
   Keywords matched: ["api", "client"]
   Confidence: 1.0

   Loads:
   - relationships: ["GenServer for state", "HTTP client (Req/Finch)",
                     "rate limiting", "retry logic"]
   - pseudocode: "module → client_state → request(...) → {:ok, response}"

2. "OAuth2" (from authentication keyword)
   Keywords matched: ["authentication"]
   Confidence: 0.9

   Loads:
   - bits/security/oauth2.md
   - Example: JWT token handling
   - Example: Refresh token flow
```

**Step 3: Context Assembly**
```
ContextBuilder::new()
  .for_framework("elixir")
  .match_patterns("Create an API client with authentication")

Assembles:
  ✅ API client pattern structure
  ✅ GenServer for state management
  ✅ HTTP client (Req/Finch) setup
  ✅ OAuth2 authentication
  ✅ Rate limiting middleware
  ✅ Retry logic for failures
```

**Generated Code:**
```elixir
defmodule MyApp.APIClient do
  @moduledoc """
  HTTP API client with OAuth2 authentication.

  Features:
  - OAuth2 token management
  - Automatic token refresh
  - Rate limiting (100 req/min)
  - Exponential backoff retry
  """

  use GenServer  # ← From "GenServer for state" relationship

  # OAuth2 config  # ← From authentication keyword
  @oauth2_config [
    token_url: "...",
    client_id: "...",
    client_secret: "..."
  ]

  # Rate limiter  # ← From "rate limiting" relationship
  @rate_limit 100  # requests per minute

  # Retry config  # ← From "retry logic" relationship
  @max_retries 3
  @retry_backoff 1000

  # ... implementation follows pattern pseudocode
end
```

---

### Example 2: "Build a data pipeline to process events from Kafka"

**Step 1: Keyword Extraction**
```
Input: "Build a data pipeline to process events from Kafka"
Extracted keywords: ["pipeline", "process", "events", "kafka"]
```

**Step 2: Pattern Matching**
```json
Matched patterns:

1. "Data pipeline" pattern
   Keywords matched: ["pipeline"]
   Confidence: 1.0

   Loads:
   - pseudocode: "Broadway → fetch → validate → transform → store → handle_failed"
   - relationships: ["producers", "processors", "batchers", "error handling"]

2. "kafka_broadway_pipeline" (distributed pattern)
   Keywords matched: ["kafka", "pipeline"]
   Confidence: 1.0

   Loads:
   - structure: "Broadway → KafkaProducer → fetch batches → transform → acknowledge"
   - relationships: ["Backpressure handling", "Batching for efficiency",
                     "Fault tolerance with retries", "Dead letter queue"]
```

**Generated Architecture:**
```elixir
defmodule MyApp.EventPipeline do
  @moduledoc """
  Broadway pipeline for processing Kafka events.

  Architecture:
  - Kafka topic subscription
  - Batch processing (100 events/batch)
  - Backpressure handling
  - Dead letter queue for failures
  """

  use Broadway  # ← From "Data pipeline" pattern

  # Kafka producer config  # ← From kafka_broadway_pipeline pattern
  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {BroadwayKafka.Producer,  # ← From pattern
          hosts: [...],
          group_id: "event_processor",
          topics: ["events"]
        },
        concurrency: 10
      ],
      processors: [  # ← From relationships
        default: [concurrency: 50]
      ],
      batchers: [  # ← From "batchers" relationship
        default: [
          batch_size: 100,
          batch_timeout: 1000
        ]
      ]
    )
  end

  # Handle batch  # ← From pseudocode
  def handle_batch(_, messages, _, _) do
    # validate → transform → store → handle_failed
  end
end
```

---

### Example 3: "Create a user schema with Ecto"

**Keyword Matching:**
```
Keywords: ["schema", "ecto", "user"]

Matched:
- "Ecto schema" pattern
  Keywords: ["schema", "ecto"]

Loads:
- pseudocode: "schema → fields → associations → changeset → validations"
- relationships: ["belongs_to", "has_many", "many_to_many", "embeds"]
```

**Generated:**
```elixir
defmodule MyApp.Accounts.User do
  use Ecto.Schema  # ← From pattern
  import Ecto.Changeset

  # Schema  # ← From pseudocode
  schema "users" do
    field :email, :string
    field :username, :string
    field :password_hash, :string

    # Associations  # ← From relationships
    has_many :posts, MyApp.Content.Post
    many_to_many :groups, MyApp.Accounts.Group, join_through: "user_groups"

    timestamps()
  end

  # Changeset with validations  # ← From pseudocode
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :username, :password])
    |> validate_required([:email, :username])
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:email)
  end
end
```

---

## Advanced: Combining Multiple Patterns

**User Request:** "Create a microservice with event sourcing and NATS"

**Keyword Matching:**
```
Keywords: ["microservice", "event sourcing", "nats"]

Matched patterns:
1. "nats_microservice"
   Keywords: ["microservice", "nats"]

2. "event_sourcing_nats"
   Keywords: ["event sourcing", "nats"]

3. "service_registry"
   Keywords: ["microservice"]
```

**Pattern Combination:**
```
Combined architecture:
┌─────────────────────────────────────┐
│ From nats_microservice:             │
│ - Service discovery                 │
│ - Health checks                     │
│ - Load balancing (queue groups)     │
│ - Circuit breaker                   │
├─────────────────────────────────────┤
│ From event_sourcing_nats:           │
│ - Command → Event flow              │
│ - JetStream for durability          │
│ - Multiple consumers (projections)  │
│ - Event replay capability           │
├─────────────────────────────────────┤
│ From service_registry:              │
│ - Advertise endpoints               │
│ - Health monitoring                 │
└─────────────────────────────────────┘

Result: Event-sourced microservice with full NATS integration
```

---

## Semantic Search Enhancement

**Beyond Keywords: Vector Similarity**

```rust
// In ContextBuilder
async fn match_patterns_semantic(&self, user_request: &str) -> Vec<Pattern> {
    // 1. Generate embedding for user request
    let request_embedding = generate_embedding(user_request).await?;

    // 2. Query database with vector similarity
    let query = r#"
        SELECT
            tp.pattern_type,
            tp.title,
            tp.description,
            tp.code_example,
            1 - (tp.pattern_embedding <=> $1) AS similarity
        FROM tool_patterns tp
        JOIN tools t ON tp.tool_id = t.id
        WHERE t.tool_name = $2
        ORDER BY similarity DESC
        LIMIT 10
    "#;

    let patterns = sqlx::query_as(query)
        .bind(request_embedding)
        .bind(self.framework)
        .fetch_all(&pool)
        .await?;

    // 3. Filter by similarity threshold
    patterns
        .into_iter()
        .filter(|p| p.similarity > 0.7)
        .collect()
}
```

**Example:**
```
User: "I need a way to handle background jobs with retries"

Semantic match finds:
1. "Broadway pipeline" (similarity: 0.89)
   - Even though "broadway" not mentioned!
   - Semantic understanding: background jobs = pipeline

2. "Oban job queue" (similarity: 0.91)
   - From database patterns
   - Real implementation from indexed repos

3. "Task.Supervisor pattern" (similarity: 0.75)
   - Alternative simpler approach
```

---

## The Complete Flow

```
User Request
    │
    ▼
┌──────────────────────────────────┐
│ 1. Extract Keywords              │
│    "api client authentication"   │
│    → ["api", "client", "auth"]   │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│ 2. Match Patterns (Exact)        │
│    Load from template keywords   │
│    → "API client" pattern ✓      │
│    → "OAuth2" pattern ✓          │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│ 3. Semantic Search (DB) 🔍      │
│    Query tool_patterns with      │
│    vector similarity             │
│    → API client examples (0.92)  │
│    → Auth patterns (0.88)        │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│ 4. Load Relationships            │
│    From matched patterns:        │
│    → GenServer for state         │
│    → HTTP client (Req/Finch)     │
│    → Rate limiting               │
│    → OAuth2 flow                 │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│ 5. Assemble Context              │
│    Pattern structure +           │
│    Relationships +               │
│    DB examples +                 │
│    Bits (oauth2.md)              │
│    → Complete prompt             │
└────────┬─────────────────────────┘
         │
         ▼
     Generate Code
```

---

## What You Need to Build

**Keyword Matcher:**
```rust
// In context_builder.rs
impl ContextBuilder {
    pub fn match_keywords(&self, user_request: &str) -> Vec<SemanticPattern> {
        // Load patterns from template JSON
        let template = load_quality_template(self.language);
        let patterns = template.semantic_patterns.common_patterns;

        let request_lower = user_request.to_lowercase();
        let mut matches = Vec::new();

        for pattern in patterns {
            let keyword_matches = pattern.keywords
                .iter()
                .filter(|k| request_lower.contains(k.as_str()))
                .count();

            if keyword_matches > 0 {
                matches.push((pattern, keyword_matches));
            }
        }

        // Sort by number of keyword matches
        matches.sort_by_key(|(_, count)| *count);
        matches.reverse();

        matches.into_iter().map(|(p, _)| p).collect()
    }
}
```

**Pattern Loader:**
```rust
#[derive(Debug, Clone)]
struct SemanticPattern {
    pattern: String,
    pseudocode: String,
    relationships: Vec<String>,
    keywords: Vec<String>,
}

fn load_semantic_patterns(language: &str) -> Vec<SemanticPattern> {
    // Load from elixir_production.json, rust_production.json, etc.
    let template_path = format!("code_quality_templates/{}_production.json", language);
    let content = std::fs::read_to_string(template_path)?;
    let template: Value = serde_json::from_str(&content)?;

    template["semantic_patterns"]["common_patterns"]
        .as_array()
        .map(|patterns| {
            patterns.iter().map(|p| SemanticPattern {
                pattern: p["pattern"].as_str().unwrap().to_string(),
                pseudocode: p["pseudocode"].as_str().unwrap().to_string(),
                relationships: p["relationships"].as_array()...
                keywords: p["keywords"].as_array()...
            }).collect()
        })
        .unwrap_or_default()
}
```

---

## Answer

**YES, the system knows** through:

1. **Keyword Matching** - Template defines keywords for each pattern
2. **Semantic Search** - Vector similarity in database
3. **Relationship Loading** - Pattern triggers related components
4. **Context Assembly** - Combines all matched patterns

**You just need to wire up the keyword matcher in ContextBuilder!**

The patterns and keywords are already in your templates. 🎯