# CentralCloud Integration Guide - Architecture LLM Team

Complete guide for integrating the Architecture LLM Team templates into CentralCloud.

---

## ✅ Completed: Template Creation

**All templates created successfully:**

### Pattern Detection Templates (8 total)
1. ✅ `detect-microservices.lua` - Microservices architecture
2. ✅ `detect-monolith.lua` - Monolithic architecture (traditional/modular/distributed)
3. ✅ `detect-layered-architecture.lua` - Layered/N-Tier architecture
4. ✅ `detect-event-driven.lua` - Event-Driven Architecture (EDA)
5. ✅ `detect-hexagonal.lua` - Hexagonal/Ports-and-Adapters
6. ✅ `detect-cqrs.lua` - CQRS (Command Query Responsibility Segregation)
7. ✅ `detect-dry-violations.lua` - DRY code quality violations
8. ✅ `detect-solid-violations.lua` - SOLID principle violations

### LLM Team Agent Templates (5 total)
1. ✅ `analyst-discover-pattern.lua` - Pattern Analyst (Claude Opus)
2. ✅ `validator-validate-pattern.lua` - Pattern Validator (GPT-4.1)
3. ✅ `critic-critique-pattern.lua` - Pattern Critic (Gemini 2.5 Pro)
4. ✅ `researcher-research-pattern.lua` - Pattern Researcher (Claude Sonnet)
5. ✅ `coordinator-build-consensus.lua` - Team Coordinator (GPT-5-mini)

### Pattern JSON Definitions (6 total)
1. ✅ `microservices.json` - Complete metadata
2. ✅ `monolith.json` - Complete metadata
3. ✅ `layered.json` - Complete metadata
4. ✅ `event-driven.json` - Complete metadata
5. ✅ `hexagonal.json` - Complete metadata
6. ✅ `cqrs.json` - Complete metadata

---

## 🔨 Implementation Steps

### Phase 1: Database Schema (CentralCloud)

Create migration for pattern storage in `central_services` database:

```elixir
# central_cloud/priv/repo/migrations/YYYYMMDDHHMMSS_create_architecture_patterns.exs
defmodule CentralCloud.Repo.Migrations.CreateArchitecturePatterns do
  use Ecto.Migration

  def change do
    # Pattern definitions table
    create table(:architecture_patterns, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :pattern_id, :string, null: false
      add :name, :string, null: false
      add :category, :string, null: false
      add :version, :string, null: false

      add :description, :text
      add :metadata, :jsonb  # Full pattern JSON
      add :indicators, :jsonb
      add :benefits, {:array, :string}
      add :concerns, {:array, :string}

      add :detection_template, :string  # Lua template name
      add :embedding, :vector, size: 768  # For semantic search

      timestamps()
    end

    create unique_index(:architecture_patterns, [:pattern_id, :version])
    create index(:architecture_patterns, [:category])
    create index(:architecture_patterns, :embedding, using: "ivfflat")

    # Pattern validation results table
    create table(:pattern_validations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :codebase_id, :string, null: false
      add :pattern_id, references(:architecture_patterns, type: :binary_id), null: false

      add :analyst_result, :jsonb
      add :validator_result, :jsonb
      add :critic_result, :jsonb
      add :researcher_result, :jsonb
      add :consensus_result, :jsonb

      add :consensus_score, :integer
      add :confidence, :float
      add :approved, :boolean

      timestamps()
    end

    create index(:pattern_validations, [:codebase_id])
    create index(:pattern_validations, [:pattern_id])
  end
end
```

### Phase 2: Template Loader Service (CentralCloud)

```elixir
# central_cloud/lib/central_cloud/template_loader.ex
defmodule CentralCloud.TemplateLoader do
  @moduledoc """
  Loads and renders Lua prompt templates from templates_data/.

  Supports:
  - Dynamic variable injection
  - Workspace integration (glob, grep, read_file)
  - Template caching
  """

  use GenServer
  require Logger

  @templates_dir "templates_data/prompt_library"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Load and render a Lua template.

  ## Examples

      iex> TemplateLoader.load("architecture/llm_team/analyst-discover-pattern.lua", %{
        pattern_type: "architecture",
        code_samples: samples,
        codebase_id: "mikkihugo/singularity"
      })
      {:ok, "rendered prompt string"}
  """
  def load(template_path, variables \\ %{}) do
    GenServer.call(__MODULE__, {:load, template_path, variables})
  end

  ## GenServer Callbacks

  def init(_opts) do
    {:ok, %{cache: %{}}}
  end

  def handle_call({:load, template_path, variables}, _from, state) do
    case get_or_load_template(template_path, state.cache) do
      {:ok, lua_code, new_cache} ->
        case render_template(lua_code, variables) do
          {:ok, rendered} ->
            {:reply, {:ok, rendered}, %{state | cache: new_cache}}

          {:error, reason} ->
            Logger.error("Template render failed: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp get_or_load_template(template_path, cache) do
    full_path = Path.join(@templates_dir, template_path)

    case Map.get(cache, template_path) do
      nil ->
        # Cache miss - load from file
        case File.read(full_path) do
          {:ok, content} ->
            new_cache = Map.put(cache, template_path, content)
            {:ok, content, new_cache}

          {:error, reason} ->
            {:error, {:file_read_failed, reason}}
        end

      cached_content ->
        # Cache hit
        {:ok, cached_content, cache}
    end
  end

  defp render_template(lua_code, variables) do
    # TODO: Integrate with Luerl (Lua interpreter for Erlang)
    # For now, return placeholder
    # In production: Execute Lua with luerl, inject variables, call workspace functions

    {:ok, "TODO: Render Lua template with luerl"}
  end
end
```

### Phase 3: LLM Team Orchestrator (CentralCloud)

```elixir
# central_cloud/lib/central_cloud/llm_team_orchestrator.ex
defmodule CentralCloud.LLMTeamOrchestrator do
  @moduledoc """
  Orchestrates multi-agent LLM team for pattern validation.

  Workflow:
  1. Analyst discovers pattern
  2. Validator validates technical correctness
  3. Critic finds weaknesses
  4. Researcher validates against industry
  5. Coordinator builds consensus
  """

  require Logger
  alias CentralCloud.TemplateLoader
  alias Singularity.LLM.Service  # Via NATS

  @doc """
  Run full LLM team validation on codebase.

  Returns consensus result with all agent assessments.
  """
  def validate_pattern(codebase_id, code_samples, opts \\ []) do
    Logger.info("Starting LLM Team validation for #{codebase_id}")

    with {:ok, analyst_result} <- run_analyst(code_samples, codebase_id),
         {:ok, validator_result} <- run_validator(analyst_result, codebase_id),
         {:ok, critic_result} <- run_critic(analyst_result, validator_result, codebase_id),
         {:ok, researcher_result} <- run_researcher(analyst_result, validator_result, critic_result, codebase_id),
         {:ok, consensus} <- run_coordinator(analyst_result, validator_result, critic_result, researcher_result, codebase_id) do

      # Store results in database
      store_validation_results(codebase_id, analyst_result, validator_result, critic_result, researcher_result, consensus)

      {:ok, consensus}
    else
      {:error, reason} ->
        Logger.error("LLM Team validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp run_analyst(code_samples, codebase_id) do
    {:ok, prompt} = TemplateLoader.load("architecture/llm_team/analyst-discover-pattern.lua", %{
      pattern_type: "architecture",
      code_samples: code_samples,
      codebase_id: codebase_id
    })

    Service.call(:complex, prompt, provider: :claude_opus, task_type: :pattern_analyzer)
  end

  defp run_validator(analyst_result, codebase_id) do
    pattern = analyst_result["patterns_discovered"] |> List.first()

    {:ok, prompt} = TemplateLoader.load("architecture/llm_team/validator-validate-pattern.lua", %{
      pattern: pattern,
      analyst_assessment: analyst_result,
      codebase_id: codebase_id
    })

    Service.call(:complex, prompt, provider: :gpt4_1, task_type: :pattern_validator)
  end

  defp run_critic(analyst_result, validator_result, codebase_id) do
    pattern = analyst_result["patterns_discovered"] |> List.first()

    {:ok, prompt} = TemplateLoader.load("architecture/llm_team/critic-critique-pattern.lua", %{
      pattern: pattern,
      analyst_assessment: analyst_result,
      validator_assessment: validator_result,
      codebase_id: codebase_id
    })

    Service.call(:complex, prompt, provider: :gemini_2_5_pro, task_type: :pattern_critic)
  end

  defp run_researcher(analyst_result, validator_result, critic_result, codebase_id) do
    pattern = analyst_result["patterns_discovered"] |> List.first()

    {:ok, prompt} = TemplateLoader.load("architecture/llm_team/researcher-research-pattern.lua", %{
      pattern: pattern,
      analyst_assessment: analyst_result,
      validator_assessment: validator_result,
      critic_assessment: critic_result,
      codebase_id: codebase_id
    })

    Service.call(:complex, prompt, provider: :claude_sonnet, task_type: :pattern_researcher)
  end

  defp run_coordinator(analyst_result, validator_result, critic_result, researcher_result, codebase_id) do
    pattern = analyst_result["patterns_discovered"] |> List.first()

    {:ok, prompt} = TemplateLoader.load("architecture/llm_team/coordinator-build-consensus.lua", %{
      pattern: pattern,
      analyst_assessment: analyst_result,
      validator_assessment: validator_result,
      critic_assessment: critic_result,
      researcher_assessment: researcher_result,
      codebase_id: codebase_id
    })

    Service.call(:medium, prompt, provider: :gpt5_mini, task_type: :consensus_builder)
  end

  defp store_validation_results(codebase_id, analyst, validator, critic, researcher, consensus) do
    # Store in database for caching and history
    # TODO: Implement database storage
    :ok
  end
end
```

### Phase 4: NATS API (CentralCloud)

```elixir
# central_cloud/lib/central_cloud/nats/pattern_validator_subscriber.ex
defmodule CentralCloud.NATS.PatternValidatorSubscriber do
  @moduledoc """
  NATS subscriber for pattern validation requests.

  Subject: patterns.validate.request
  Response Subject: patterns.validate.response
  """

  use GenServer
  require Logger
  alias CentralCloud.LLMTeamOrchestrator

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    case NatsClient.subscribe("patterns.validate.request", self()) do
      {:ok, subscription} ->
        Logger.info("Subscribed to patterns.validate.request")
        {:ok, %{subscription: subscription}}

      {:error, reason} ->
        Logger.error("Failed to subscribe: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  def handle_info({:nats_msg, subject, reply_to, payload}, state) do
    Logger.debug("Received pattern validation request")

    case Jason.decode(payload) do
      {:ok, %{"codebase_id" => codebase_id, "code_samples" => code_samples}} ->
        # Run LLM Team validation
        case LLMTeamOrchestrator.validate_pattern(codebase_id, code_samples) do
          {:ok, consensus} ->
            response = Jason.encode!(%{
              status: "success",
              consensus: consensus,
              timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
            })

            NatsClient.publish(reply_to, response)

          {:error, reason} ->
            error_response = Jason.encode!(%{
              status: "error",
              error: inspect(reason),
              timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
            })

            NatsClient.publish(reply_to, error_response)
        end

      {:error, _} ->
        Logger.error("Invalid JSON payload")
    end

    {:noreply, state}
  end
end
```

---

## 📋 Integration Checklist

### Database
- [ ] Run migration to create architecture_patterns table
- [ ] Run migration to create pattern_validations table
- [ ] Import pattern JSON definitions into database
- [ ] Generate embeddings for pattern semantic search

### Services
- [ ] Implement TemplateLoader GenServer
- [ ] Integrate luerl (Lua interpreter) for template rendering
- [ ] Implement workspace functions (glob, grep, read_file) in Lua context
- [ ] Implement LLMTeamOrchestrator
- [ ] Add to CentralCloud supervision tree

### NATS Integration
- [ ] Create PatternValidatorSubscriber
- [ ] Add NATS subjects to NATS_SUBJECTS.md
- [ ] Test pattern validation via NATS (Singularity → CentralCloud)
- [ ] Add to CentralCloud.NATS.Supervisor

### Testing
- [ ] Unit tests for TemplateLoader
- [ ] Integration tests for LLMTeamOrchestrator
- [ ] End-to-end test (Singularity request → CentralCloud response)

---

## 🚀 Quick Start (After Implementation)

### From Singularity

```elixir
# Request pattern validation via NATS
alias Singularity.NATS.Client

code_samples = [
  %{path: "lib/service_a.ex", content: "...", language: "elixir"},
  %{path: "lib/service_b.ex", content: "...", language: "elixir"}
]

request = Jason.encode!(%{
  codebase_id: "mikkihugo/singularity",
  code_samples: code_samples
})

{:ok, response} = Client.request("patterns.validate.request", request, timeout: 60_000)

consensus = Jason.decode!(response)
# => %{
#   "consensus_score" => 82,
#   "final_decision" => "APPROVE_WITH_CONDITIONS",
#   "production_readiness_conditions" => [...]
# }
```

### Directly in CentralCloud

```elixir
alias CentralCloud.LLMTeamOrchestrator

{:ok, consensus} = LLMTeamOrchestrator.validate_pattern(
  "mikkihugo/singularity",
  code_samples
)
```

---

## 📈 Performance Considerations

- **Template Caching**: TemplateLoader caches Lua templates in memory
- **Parallel Agent Execution**: Consider running agents in parallel where possible (Analyst alone, then Validator+Critic in parallel, etc.)
- **Result Caching**: Store validation results in database, reuse for same codebase_id
- **Rate Limiting**: LLM providers have rate limits - implement backoff/retry

---

## 🔒 Security

- **Template Sandboxing**: Lua templates run in sandboxed luerl environment
- **No Arbitrary Code Execution**: Templates can only call whitelisted workspace functions
- **NATS Authentication**: Ensure NATS subjects are authenticated (TLS + tokens)

---

## 📖 Documentation

- All templates have version tracking (v1.0.0)
- Pattern JSON definitions include authoritative sources
- LLM Team collaboration notes embedded in template outputs

---

**Status**: Ready for implementation! All templates and patterns created. Integration code provided above.
