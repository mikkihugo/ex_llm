defmodule Singularity.Schemas.LLMRequest do
  @moduledoc """
  Ecto schema for tracking incoming LLM requests from agents.

  Stores all LLM requests from agents before they're published to the shared queue.
  This provides a dedicated table for lower-latency polling of LLM requests
  compared to polling the pgmq queue directly.

  ## UUID Strategy - UUIDv7 for Better Index Performance

  This schema uses UUIDv7 for all IDs (via extension on PG 14-17, native on PG 18+).

  ### Setup

  **PostgreSQL 14-17: Install pg_uuidv7 extension**
  ```sql
  -- One-time setup per database
  CREATE EXTENSION IF NOT EXISTS pg_uuidv7;

  -- Verify installation
  SELECT uuidv7();
  -- Returns: e7e6a930-f4f9-7000-8000-000000000000 (example)
  ```

  Using package manager:
  ```bash
  # macOS (homebrew)
  brew install pg_uuidv7

  # Linux (PGXN)
  pgxn install pg_uuidv7
  ```

  **PostgreSQL 18+**
  - No installation needed - `uuidv7()` is built-in

  ### Benefits

  **UUIDv7 vs UUIDv4:**
  - ✅ Sequential IDs ordered by millisecond timestamp
  - ✅ Better B-tree index locality (no random distribution)
  - ✅ Faster polling queries: `WHERE status = 'pending' ORDER BY id`
  - ✅ Reduced index fragmentation from sequential inserts
  - ✅ Natural timeline preservation (sortable without ORDER BY created_at)
  - ✅ Works across distributed systems (globally sortable)

  ### Migration Details

  Migration uses `COALESCE(uuidv7(), gen_random_uuid())`:
  - **With pg_uuidv7**: Uses UUIDv7 (timestamp-ordered)
  - **Without extension**: Falls back to UUIDv4 (random, still works)
  - **PG 18+**: Native `uuidv7()` used (no extension needed)

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.LLMRequest",
    "purpose": "Stores incoming LLM requests from agents with fast polling support",
    "role": "schema",
    "layer": "infrastructure",
    "table": "llm_requests",
    "uuid_strategy": "v4 (PG 14-17) → v7 (PG 18+)",
    "relationships": {}
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - id: Primary key (UUID - v7 ready for PG 18+)
    - agent_id: ID of agent making the request (CRITICAL: for isolation)
    - task_type: Type of task (simple, medium, complex)
    - complexity: Complexity level for model selection
    - messages: Request messages as JSONB
    - context: Additional context as JSONB
    - status: Request status (pending, processing, completed, failed)
    - published_at: When published to shared queue
    - created_at: When request was created
    - updated_at: Last update timestamp

  indexes:
    - btree: status, created_at (candidates for v7 uuid-based ordering in PG 18+)
    - btree: agent_id for per-agent tracking
    - btree: task_type for analysis

  relationships:
    belongs_to: []
    has_many: []
  ```

  ### Anti-Patterns
  - ❌ DO NOT poll pgmq directly for LLM requests - use this table instead
  - ❌ DO NOT skip storing requests - needed for monitoring and debugging
  - ❌ DO NOT consume messages from other agents - always filter by agent_id
  - ✅ DO poll pending LLM requests with frequent intervals (100ms default)
  - ✅ DO update status as requests progress through pipeline
  - ✅ DO filter by agent_id to prevent cross-contamination in multi-instance

  ### Search Keywords
  llm request, agent request, request status, request tracking, request queue,
  agent communication, request pending, request published, task routing,
  uuid v7, request isolation, multi-instance
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "llm_requests" do
    field :agent_id, :string  # CRITICAL: Track which agent owns this request
    field :task_type, :string
    field :complexity, :string  # simple, medium, complex
    field :messages, :map  # JSONB - conversation history
    field :context, :map   # JSONB - additional context
    field :status, :string, default: "pending"  # pending, processing, completed, failed
    field :published_at, :utc_datetime_usec
    field :error_message, :string
    # Instructor-specific fields for structured output validation
    field :response_schema, :map  # JSONB - Instructor schema for validation
    field :validation_errors, {:array, :map}  # Array of validation errors (if any)
    field :response, :string  # Raw LLM response (before Instructor parsing)
    field :parsed_response, :map  # Parsed/validated response (after Instructor)

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Filter requests by agent_id for isolation.

  CRITICAL: Only agents should see their own requests and results.
  """
  def by_agent(query, agent_id) do
    from r in query, where: r.agent_id == ^agent_id
  end

  def changeset(request, attrs) do
    request
    |> cast(attrs, [
      :agent_id,
      :task_type,
      :complexity,
      :messages,
      :context,
      :status,
      :published_at,
      :error_message,
      :response_schema,
      :validation_errors,
      :response,
      :parsed_response
    ])
    |> validate_required([
      :agent_id,
      :task_type,
      :complexity,
      :messages
    ])
    |> validate_inclusion(:complexity, ["simple", "medium", "complex"])
    |> validate_inclusion(:status, ["pending", "processing", "completed", "failed"])
  end

  def mark_processing(request) do
    changeset(request, %{status: "processing"})
  end

  def mark_completed(request) do
    changeset(request, %{status: "completed", published_at: DateTime.utc_now()})
  end

  def mark_failed(request, error_message) do
    changeset(request, %{
      status: "failed",
      error_message: error_message
    })
  end

  def mark_failed_with_validation_errors(request, error_message, validation_errors) do
    changeset(request, %{
      status: "failed",
      error_message: error_message,
      validation_errors: validation_errors
    })
  end

  def mark_completed_with_response(request, response, parsed_response \\ nil) do
    changeset(request, %{
      status: "completed",
      response: response,
      parsed_response: parsed_response,
      published_at: DateTime.utc_now()
    })
  end

  def mark_failed_llm_down(request, reason \\ "LLM provider unavailable") do
    changeset(request, %{
      status: "failed",
      error_message: reason
    })
  end

  def mark_failed_malformed_response(request, response, validation_errors) do
    changeset(request, %{
      status: "failed",
      error_message: "Malformed or invalid LLM response (Instructor validation failed)",
      response: response,
      validation_errors: validation_errors
    })
  end
end
