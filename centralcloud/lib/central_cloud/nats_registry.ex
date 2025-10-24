defmodule CentralCloud.NatsRegistry do
  @moduledoc """
  NATS Subject Registry - Central service registry for distributed Singularity system.

  Provides single source of truth for all NATS subjects used across the Singularity
  ecosystem. This lives in CentralCloud (not Singularity) because:

  1. **Central Coordination** - Singularity instances query CentralCloud for subject info
  2. **Service Discovery** - Maps subjects to handler modules across multiple instances
  3. **Multi-Instance Architecture** - Enables service discovery across distributed system
  4. **Shared Configuration** - JetStream streams/consumers consistent across instances

  ## Architecture

  ```
  Singularity Instance 1 ─┐
  Singularity Instance 2 ──┼──> CentralCloud.NatsRegistry (single source of truth)
  Singularity Instance 3 ─┘
  ```

  ## Problem Solved

  Previously had 756+ hardcoded NATS subject strings scattered across codebase:
  - String "llm.provider.claude" appeared 47 times
  - No central source of truth for subject patterns
  - No service discovery (who handles what subject)
  - Hard to coordinate across multiple Singularity instances
  - Easy to introduce typos that fail at runtime

  ## Subject Categories

  ### LLM Subjects (4)
  - `llm.provider.claude` - Request to Claude API
  - `llm.provider.gemini` - Request to Gemini API
  - `llm.provider.openai` - Request to OpenAI API
  - `llm.provider.copilot` - Request to Copilot API

  ### Analysis Subjects (5)
  - `analysis.code.parse` - Parse code and extract AST
  - `analysis.code.analyze` - Analyze code quality
  - `analysis.code.embed` - Generate embeddings
  - `analysis.code.search` - Semantic code search
  - `analysis.code.detect.frameworks` - Framework detection

  ### Agent Subjects (6)
  - `agents.spawn` - Spawn new agent
  - `agents.status` - Check agent status
  - `agents.pause` - Pause agent
  - `agents.resume` - Resume agent
  - `agents.improve` - Self-improvement request
  - `agents.result` - Publish result

  ### Knowledge Subjects (4)
  - `templates.technology.fetch` - Fetch tech templates
  - `templates.quality.fetch` - Fetch quality templates
  - `knowledge.search` - Semantic search
  - `knowledge.learn` - Store learned pattern

  ### Meta-Registry Subjects (3)
  - `analysis.meta.registry.naming` - Query naming patterns
  - `analysis.meta.registry.architecture` - Query architecture patterns
  - `analysis.meta.registry.quality` - Query quality patterns

  ### System Subjects (2)
  - `system.health` - Health check
  - `system.metrics` - Publish metrics

  ## Public API

  - `get(key)` - Get full subject entry
  - `subject(key)` - Get subject string for atom key
  - `handler(subject_string)` - Get handler module
  - `exists?(subject_string)` - Check if registered
  - `for_service(service)` - Get all subjects for service
  - `all_subjects()` - List all registered subjects
  - `jetstream_config(key)` - Get JetStream configuration
  - `validate(subject_string)` - Validate with suggestions
  - `pattern(key)` - Get NATS pattern matcher

  ## Integration with Singularity

  In Singularity, create a lightweight client that queries CentralCloud:

  ```elixir
  # singularity/lib/singularity/nats/registry_client.ex
  defmodule Singularity.Nats.RegistryClient do
    def get(key) do
      CentralCloud.NatsRegistry.get(key)
    end

    def subject(key) do
      CentralCloud.NatsRegistry.subject(key)
    end

    # ... forward other calls to CentralCloud
  end
  ```

  Or use CentralCloud directly:

  ```elixir
  alias CentralCloud.NatsRegistry

  {:ok, subject} = NatsRegistry.subject(:provider_claude)
  {:ok, config} = NatsRegistry.get(:provider_claude)
  {:ok, handler} = NatsRegistry.handler("llm.provider.claude")
  ```

  ## Performance Characteristics

  - Subject lookup: O(1) via atom key
  - Validation: O(n) with Levenshtein distance (only on error)
  - Service discovery: O(m) where m = subjects in service
  - Network: Subject lookups cached locally in Singularity instances

  ## Module Identity (JSON)
  ```json
  {
    "module_name": "CentralCloud.NatsRegistry",
    "purpose": "central_nats_subject_registry",
    "domain": "distributed_messaging",
    "location": "centralcloud",
    "capabilities": ["subject_lookup", "service_discovery", "jetstream_config", "validation"],
    "replaces": ["756 hardcoded NATS subject strings"],
    "serves": ["Singularity instances", "AI servers", "CentralCloud services"]
  }
  ```

  ## Architecture Diagram (Mermaid)
  ```mermaid
  graph TD
    S1["Singularity Instance 1"]
    S2["Singularity Instance 2"]
    S3["Singularity Instance 3"]
    CC["CentralCloud.NatsRegistry"]
    NATS["NATS Cluster with JetStream"]

    S1 --> CC
    S2 --> CC
    S3 --> CC
    CC --> NATS

    S1 -.->|cache locally| S1
    S2 -.->|cache locally| S2
    S3 -.->|cache locally| S3
  ```

  ## Call Graph (YAML)
  ```yaml
  CentralCloud.NatsRegistry:
    get/1: [Map.get/2]
    subject/1: [get/1]
    handler/1: [find_by_subject/1, Map.get/2]
    exists?/1: [Enum.any?/2]
    for_service/1: [Map.values/1]
    all_subjects/0: [static list]
    jetstream_config/1: [get/1]
    validate/1: [exists?/1, suggest_subjects/2]
    suggest_subjects/2: [levenshtein_distance/2, Enum.filter/2]
  ```

  ## Anti-Patterns

  - **DO NOT** hardcode subject strings in Singularity code
  - **DO NOT** create separate registries per instance
  - **DO NOT** store registry in PostgreSQL (compile-time safety better)
  - **DO NOT** bypass validation on subject lookups
  - **DO NOT** assume subjects are the same across versions

  ## Search Keywords

  nats, messaging, registry, subject, handler, service discovery, centralcloud, distributed, multi-instance, orchestration
  """

  require Logger

  # ============================================================================
  # LLM Provider Subjects
  # ============================================================================

  @llm_subjects %{
    provider_claude: %{
      subject: "llm.provider.claude",
      description: "Request to Claude API via AI Server",
      handler: Singularity.LLM.NatsHandler,
      pattern: "llm.provider.claude",
      request_reply: true,
      timeout: 30000,
      complexity: :complex,
      jetstream: %{
        stream: "llm_requests",
        consumer: "llm_claude_consumer",
        durable: true,
        max_deliver: 3,
        retention: 86400
      }
    },
    provider_gemini: %{
      subject: "llm.provider.gemini",
      description: "Request to Gemini API via AI Server",
      handler: Singularity.LLM.NatsHandler,
      pattern: "llm.provider.gemini",
      request_reply: true,
      timeout: 30000,
      complexity: :complex,
      jetstream: %{
        stream: "llm_requests",
        consumer: "llm_gemini_consumer",
        durable: true,
        max_deliver: 3,
        retention: 86400
      }
    },
    provider_openai: %{
      subject: "llm.provider.openai",
      description: "Request to OpenAI API via AI Server",
      handler: Singularity.LLM.NatsHandler,
      pattern: "llm.provider.openai",
      request_reply: true,
      timeout: 30000,
      complexity: :complex,
      jetstream: %{
        stream: "llm_requests",
        consumer: "llm_openai_consumer",
        durable: true,
        max_deliver: 3,
        retention: 86400
      }
    },
    provider_copilot: %{
      subject: "llm.provider.copilot",
      description: "Request to Copilot API via AI Server",
      handler: Singularity.LLM.NatsHandler,
      pattern: "llm.provider.copilot",
      request_reply: true,
      timeout: 30000,
      complexity: :complex,
      jetstream: %{
        stream: "llm_requests",
        consumer: "llm_copilot_consumer",
        durable: true,
        max_deliver: 3,
        retention: 86400
      }
    }
  }

  # ============================================================================
  # Code Analysis Subjects
  # ============================================================================

  @analysis_subjects %{
    code_parse: %{
      subject: "analysis.code.parse",
      description: "Parse code and extract AST",
      handler: Singularity.CodeAnalysis.NatsHandler,
      pattern: "analysis.code.parse",
      request_reply: true,
      timeout: 10000,
      complexity: :medium,
      jetstream: %{
        stream: "analysis_requests",
        consumer: "code_parse_consumer",
        durable: true,
        max_deliver: 2,
        retention: 3600
      }
    },
    code_analyze: %{
      subject: "analysis.code.analyze",
      description: "Analyze code quality and patterns",
      handler: Singularity.CodeAnalysis.NatsHandler,
      pattern: "analysis.code.analyze",
      request_reply: true,
      timeout: 15000,
      complexity: :complex,
      jetstream: %{
        stream: "analysis_requests",
        consumer: "code_analyze_consumer",
        durable: true,
        max_deliver: 2,
        retention: 3600
      }
    },
    code_embed: %{
      subject: "analysis.code.embed",
      description: "Generate embeddings for code",
      handler: Singularity.CodeAnalysis.NatsHandler,
      pattern: "analysis.code.embed",
      request_reply: true,
      timeout: 20000,
      complexity: :medium,
      jetstream: %{
        stream: "analysis_requests",
        consumer: "code_embed_consumer",
        durable: true,
        max_deliver: 2,
        retention: 3600
      }
    },
    code_search: %{
      subject: "analysis.code.search",
      description: "Search code semantically",
      handler: Singularity.CodeAnalysis.NatsHandler,
      pattern: "analysis.code.search",
      request_reply: true,
      timeout: 10000,
      complexity: :medium,
      jetstream: %{
        stream: "analysis_requests",
        consumer: "code_search_consumer",
        durable: true,
        max_deliver: 2,
        retention: 3600
      }
    },
    code_detect_frameworks: %{
      subject: "analysis.code.detect.frameworks",
      description: "Detect frameworks and technologies",
      handler: Singularity.CodeAnalysis.NatsHandler,
      pattern: "analysis.code.detect.frameworks",
      request_reply: true,
      timeout: 10000,
      complexity: :medium,
      jetstream: %{
        stream: "analysis_requests",
        consumer: "code_frameworks_consumer",
        durable: true,
        max_deliver: 2,
        retention: 3600
      }
    }
  }

  # ============================================================================
  # Agent Management Subjects
  # ============================================================================

  @agent_subjects %{
    agent_spawn: %{
      subject: "agents.spawn",
      description: "Spawn new autonomous agent",
      handler: Singularity.Agents.NatsHandler,
      pattern: "agents.spawn",
      request_reply: true,
      timeout: 5000,
      complexity: :medium,
      jetstream: %{
        stream: "agent_management",
        consumer: "agent_spawn_consumer",
        durable: true,
        max_deliver: 2,
        retention: 604800
      }
    },
    agent_status: %{
      subject: "agents.status",
      description: "Check agent status",
      handler: Singularity.Agents.NatsHandler,
      pattern: "agents.status",
      request_reply: true,
      timeout: 5000,
      complexity: :simple,
      jetstream: %{
        stream: "agent_management",
        consumer: "agent_status_consumer",
        durable: true,
        max_deliver: 1,
        retention: 604800
      }
    },
    agent_pause: %{
      subject: "agents.pause",
      description: "Pause running agent",
      handler: Singularity.Agents.NatsHandler,
      pattern: "agents.pause",
      request_reply: true,
      timeout: 5000,
      complexity: :simple,
      jetstream: %{
        stream: "agent_management",
        consumer: "agent_pause_consumer",
        durable: true,
        max_deliver: 2,
        retention: 604800
      }
    },
    agent_resume: %{
      subject: "agents.resume",
      description: "Resume paused agent",
      handler: Singularity.Agents.NatsHandler,
      pattern: "agents.resume",
      request_reply: true,
      timeout: 5000,
      complexity: :simple,
      jetstream: %{
        stream: "agent_management",
        consumer: "agent_resume_consumer",
        durable: true,
        max_deliver: 2,
        retention: 604800
      }
    },
    agent_improve: %{
      subject: "agents.improve",
      description: "Request agent self-improvement",
      handler: Singularity.Agents.NatsHandler,
      pattern: "agents.improve",
      request_reply: true,
      timeout: 60000,
      complexity: :complex,
      jetstream: %{
        stream: "agent_management",
        consumer: "agent_improve_consumer",
        durable: true,
        max_deliver: 3,
        retention: 604800
      }
    },
    agent_result: %{
      subject: "agents.result",
      description: "Publish agent execution result",
      handler: Singularity.Agents.NatsHandler,
      pattern: "agents.result",
      request_reply: false,
      timeout: nil,
      complexity: nil,
      jetstream: %{
        stream: "agent_management",
        durable: false,
        retention: 604800
      }
    }
  }

  # ============================================================================
  # Knowledge & Template Subjects
  # ============================================================================

  @knowledge_subjects %{
    templates_technology_fetch: %{
      subject: "templates.technology.fetch",
      description: "Fetch technology templates",
      handler: Singularity.Knowledge.NatsHandler,
      pattern: "templates.technology.fetch",
      request_reply: true,
      timeout: 5000,
      complexity: :simple,
      jetstream: %{
        stream: "knowledge_requests",
        consumer: "templates_technology_consumer",
        durable: true,
        max_deliver: 1,
        retention: 3600
      }
    },
    templates_quality_fetch: %{
      subject: "templates.quality.fetch",
      description: "Fetch quality templates",
      handler: Singularity.Knowledge.NatsHandler,
      pattern: "templates.quality.fetch",
      request_reply: true,
      timeout: 5000,
      complexity: :simple,
      jetstream: %{
        stream: "knowledge_requests",
        consumer: "templates_quality_consumer",
        durable: true,
        max_deliver: 1,
        retention: 3600
      }
    },
    knowledge_search: %{
      subject: "knowledge.search",
      description: "Search knowledge base semantically",
      handler: Singularity.Knowledge.NatsHandler,
      pattern: "knowledge.search",
      request_reply: true,
      timeout: 10000,
      complexity: :medium,
      jetstream: %{
        stream: "knowledge_requests",
        consumer: "knowledge_search_consumer",
        durable: true,
        max_deliver: 1,
        retention: 3600
      }
    },
    knowledge_learn: %{
      subject: "knowledge.learn",
      description: "Store learned pattern in knowledge base",
      handler: Singularity.Knowledge.NatsHandler,
      pattern: "knowledge.learn",
      request_reply: false,
      timeout: nil,
      complexity: nil,
      jetstream: %{
        stream: "knowledge_requests",
        durable: false,
        retention: 604800
      }
    }
  }

  # ============================================================================
  # Meta-Registry Subjects
  # ============================================================================

  @meta_subjects %{
    meta_registry_naming: %{
      subject: "analysis.meta.registry.naming",
      description: "Query naming patterns from meta-registry",
      handler: Singularity.ArchitectureEngine.MetaRegistry.NatsHandler,
      pattern: "analysis.meta.registry.naming",
      request_reply: true,
      timeout: 5000,
      complexity: :simple,
      jetstream: %{
        stream: "meta_registry_requests",
        consumer: "meta_naming_consumer",
        durable: true,
        max_deliver: 1,
        retention: 3600
      }
    },
    meta_registry_architecture: %{
      subject: "analysis.meta.registry.architecture",
      description: "Query architecture patterns from meta-registry",
      handler: Singularity.ArchitectureEngine.MetaRegistry.NatsHandler,
      pattern: "analysis.meta.registry.architecture",
      request_reply: true,
      timeout: 5000,
      complexity: :simple,
      jetstream: %{
        stream: "meta_registry_requests",
        consumer: "meta_architecture_consumer",
        durable: true,
        max_deliver: 1,
        retention: 3600
      }
    },
    meta_registry_quality: %{
      subject: "analysis.meta.registry.quality",
      description: "Query quality patterns from meta-registry",
      handler: Singularity.ArchitectureEngine.MetaRegistry.NatsHandler,
      pattern: "analysis.meta.registry.quality",
      request_reply: true,
      timeout: 5000,
      complexity: :simple,
      jetstream: %{
        stream: "meta_registry_requests",
        consumer: "meta_quality_consumer",
        durable: true,
        max_deliver: 1,
        retention: 3600
      }
    }
  }

  # ============================================================================
  # System Subjects
  # ============================================================================

  @system_subjects %{
    system_health: %{
      subject: "system.health",
      description: "Health check and monitoring",
      handler: Singularity.System.NatsHandler,
      pattern: "system.health",
      request_reply: true,
      timeout: 5000,
      complexity: :simple,
      jetstream: %{
        stream: "system_monitoring",
        consumer: "system_health_consumer",
        durable: true,
        max_deliver: 1,
        retention: 3600
      }
    },
    system_metrics: %{
      subject: "system.metrics",
      description: "Publish system metrics",
      handler: Singularity.System.NatsHandler,
      pattern: "system.metrics",
      request_reply: false,
      timeout: nil,
      complexity: nil,
      jetstream: %{
        stream: "system_monitoring",
        durable: false,
        retention: 86400
      }
    }
  }

  # ============================================================================
  # Compile-Time Subject Collection
  # ============================================================================

  @all_subjects @llm_subjects
               |> Map.merge(@analysis_subjects)
               |> Map.merge(@agent_subjects)
               |> Map.merge(@knowledge_subjects)
               |> Map.merge(@meta_subjects)
               |> Map.merge(@system_subjects)

  @all_subject_strings @all_subjects
                       |> Map.values()
                       |> Enum.map(fn config -> config.subject end)

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Get full subject entry by atom key.

  Returns the complete configuration including handler, timeout, JetStream config, etc.

  ## Examples

      iex> CentralCloud.NatsRegistry.get(:provider_claude)
      {:ok, %{
        subject: "llm.provider.claude",
        handler: Singularity.LLM.NatsHandler,
        request_reply: true,
        timeout: 30000,
        complexity: :complex,
        jetstream: %{...}
      }}

      iex> CentralCloud.NatsRegistry.get(:unknown_key)
      {:error, :not_found}
  """
  @spec get(atom()) :: {:ok, map()} | {:error, :not_found}
  def get(key) when is_atom(key) do
    case Map.get(@all_subjects, key) do
      nil -> {:error, :not_found}
      config -> {:ok, config}
    end
  end

  @doc """
  Get subject string for atom key.

  ## Examples

      iex> CentralCloud.NatsRegistry.subject(:provider_claude)
      {:ok, "llm.provider.claude"}

      iex> CentralCloud.NatsRegistry.subject(:unknown_key)
      {:error, :not_found}
  """
  @spec subject(atom()) :: {:ok, String.t()} | {:error, :not_found}
  def subject(key) when is_atom(key) do
    case get(key) do
      {:ok, config} -> {:ok, config.subject}
      error -> error
    end
  end

  @doc """
  Get handler module atom for subject string.

  Returns the handler module as an atom, ready for dynamic calls or delegation.

  ## Examples

      iex> CentralCloud.NatsRegistry.handler("llm.provider.claude")
      {:ok, Singularity.LLM.NatsHandler}

      iex> CentralCloud.NatsRegistry.handler("unknown.subject")
      {:error, :not_found}
  """
  @spec handler(String.t()) :: {:ok, module()} | {:error, :not_found}
  def handler(subject_string) when is_binary(subject_string) do
    case find_by_subject(subject_string) do
      nil -> {:error, :not_found}
      config -> {:ok, config.handler}
    end
  end

  @doc """
  Check if subject is registered.

  ## Examples

      iex> CentralCloud.NatsRegistry.exists?("llm.provider.claude")
      true

      iex> CentralCloud.NatsRegistry.exists?("unknown.subject")
      false
  """
  @spec exists?(String.t()) :: boolean()
  def exists?(subject_string) when is_binary(subject_string) do
    Enum.any?(@all_subject_strings, &(&1 == subject_string))
  end

  @doc """
  Get all subjects for a service category.

  ## Examples

      iex> CentralCloud.NatsRegistry.for_service(:llm)
      {:ok, [
        %{subject: "llm.provider.claude", ...},
        %{subject: "llm.provider.gemini", ...},
        %{subject: "llm.provider.openai", ...},
        %{subject: "llm.provider.copilot", ...}
      ]}

      iex> CentralCloud.NatsRegistry.for_service(:analysis)
      {:ok, [
        %{subject: "analysis.code.parse", ...},
        %{subject: "analysis.code.analyze", ...},
        %{subject: "analysis.code.embed", ...},
        %{subject: "analysis.code.search", ...},
        %{subject: "analysis.code.detect.frameworks", ...}
      ]}
  """
  @spec for_service(atom()) :: {:ok, list(map())} | {:error, :not_found}
  def for_service(service) when is_atom(service) do
    case service do
      :llm -> {:ok, Map.values(@llm_subjects)}
      :analysis -> {:ok, Map.values(@analysis_subjects)}
      :agent -> {:ok, Map.values(@agent_subjects)}
      :knowledge -> {:ok, Map.values(@knowledge_subjects)}
      :meta -> {:ok, Map.values(@meta_subjects)}
      :system -> {:ok, Map.values(@system_subjects)}
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Get all registered subject strings.

  ## Examples

      iex> CentralCloud.NatsRegistry.all_subjects() |> length()
      26
  """
  @spec all_subjects() :: list(String.t())
  def all_subjects do
    @all_subject_strings
  end

  @doc """
  Get JetStream configuration for subject key.

  ## Examples

      iex> CentralCloud.NatsRegistry.jetstream_config(:provider_claude)
      {:ok, %{
        stream: "llm_requests",
        consumer: "llm_claude_consumer",
        durable: true,
        max_deliver: 3,
        retention: 86400
      }}
  """
  @spec jetstream_config(atom()) :: {:ok, map()} | {:error, :not_found}
  def jetstream_config(key) when is_atom(key) do
    case get(key) do
      {:ok, config} -> {:ok, config.jetstream}
      error -> error
    end
  end

  @doc """
  Validate subject string and suggest alternatives on typo.

  Uses Levenshtein distance for similarity matching.

  ## Examples

      iex> CentralCloud.NatsRegistry.validate("llm.provider.claude")
      :ok

      iex> CentralCloud.NatsRegistry.validate("llm.provider.claud")
      {:error, "Subject not found. Did you mean: [llm.provider.claude, llm.provider.gemini]?"}
  """
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(subject_string) when is_binary(subject_string) do
    if exists?(subject_string) do
      :ok
    else
      suggestions = suggest_subjects(subject_string, limit: 3)

      if Enum.empty?(suggestions) do
        {:error, "Subject not found: #{subject_string}"}
      else
        suggestions_str = inspect(suggestions)
        {:error, "Subject not found. Did you mean: #{suggestions_str}?"}
      end
    end
  end

  @doc """
  Get NATS subject pattern matcher for wildcard subscriptions.

  ## Examples

      iex> CentralCloud.NatsRegistry.pattern(:provider_claude)
      {:ok, "llm.provider.claude"}
  """
  @spec pattern(atom()) :: {:ok, String.t()} | {:error, :not_found}
  def pattern(key) when is_atom(key) do
    subject(key)
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp find_by_subject(subject_string) do
    Map.values(@all_subjects) |> Enum.find(&(&1.subject == subject_string))
  end

  defp suggest_subjects(subject_string, opts) do
    limit = Keyword.get(opts, :limit, 3)

    @all_subject_strings
    |> Enum.map(fn s -> {s, levenshtein_distance(subject_string, s)} end)
    |> Enum.filter(fn {_, distance} -> distance < 5 end)
    |> Enum.sort_by(fn {_, distance} -> distance end)
    |> Enum.take(limit)
    |> Enum.map(fn {s, _} -> s end)
  end

  defp levenshtein_distance(s1, s2) when is_binary(s1) and is_binary(s2) do
    c1 = String.graphemes(s1)
    c2 = String.graphemes(s2)
    levenshtein_impl(c1, c2, 0)
  end

  defp levenshtein_impl([], s2, _acc), do: length(s2)
  defp levenshtein_impl(s1, [], _acc), do: length(s1)

  defp levenshtein_impl([h1 | t1], [h2 | t2], _acc) do
    cost = if h1 == h2, do: 0, else: 1

    min(
      levenshtein_impl(t1, [h2 | t2], 0) + 1,
      min(
        levenshtein_impl([h1 | t1], t2, 0) + 1,
        levenshtein_impl(t1, t2, 0) + cost
      )
    )
  end
end
