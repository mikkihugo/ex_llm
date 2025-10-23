defmodule Singularity.Knowledge.TemplateService do
  @moduledoc """
  NATS service for template requests.

  Exposes templates via NATS subjects for consumption by:
  - Rust prompt engine
  - External agents
  - Other microservices

  ## NATS Subjects

  Request templates:
  - `template.get.framework.phoenix` → Get Phoenix framework template
  - `template.get.language.rust` → Get Rust language template
  - `template.get.quality.elixir-production` → Get quality template

  Search templates:
  - `template.search.{query}` → Semantic search

  Notifications:
  - `template.updated.{type}.{id}` → Template was updated (broadcast)

  ## Example: Rust Client

  ```rust
  use async_nats;

  let nc = async_nats::connect("nats://localhost:4222").await?;

  // Request template
  let response = nc
      .request("template.get.framework.phoenix", "".into())
      .await?;

  let template: serde_json::Value = serde_json::from_slice(&response.payload)?;
  ```

  ## Example: Elixir Client

  ```elixir
  {:ok, response} = Gnat.request(gnat, "template.get.framework.phoenix", "")
  {:ok, template} = Jason.decode(response.body)
  ```
  """

  use GenServer
  require Logger

  alias Singularity.Knowledge.TemplateCache

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Use the default Gnat connection
    gnat_name = :nats_client

    # Subscribe to template requests using Singularity.NatsClient
    Enum.each(
      [
        "template.get.>",
        "template.search.>"
      ],
      fn subject ->
        case Singularity.NatsClient.subscribe(subject) do
          {:ok, _subscription_id} -> Logger.info("TemplateService subscribed to: #{subject}")
          {:error, reason} -> Logger.error("Failed to subscribe to #{subject}: #{reason}")
        end
      end
    )

    Logger.info("Template NATS service started")
    Logger.info("  Listening on: template.get.*, template.search.*")

    {:ok, %{gnat: gnat_name, requests_handled: 0}}
  end

  @impl true
  def handle_info(
        {:msg, %{subject: "template.get." <> rest, body: _body, reply_to: reply_to}},
        state
      ) do
    # Parse subject: template.get.framework.phoenix
    case String.split(rest, ".", parts: 2) do
      [artifact_type, artifact_id] ->
        handle_get_request(state.gnat, artifact_type, artifact_id, reply_to)

      _ ->
        send_error(state.gnat, reply_to, "Invalid subject format")
    end

    {:noreply, %{state | requests_handled: state.requests_handled + 1}}
  end

  @impl true
  def handle_info({:msg, %{subject: "template.search." <> query, reply_to: reply_to}}, state) do
    handle_search_request(state.gnat, query, reply_to)
    {:noreply, %{state | requests_handled: state.requests_handled + 1}}
  end

  @impl true
  def handle_info({:msg, _msg}, state) do
    # Ignore other messages
    {:noreply, state}
  end

  # Private Functions

  defp handle_get_request(_gnat, artifact_type, artifact_id, reply_to) when is_binary(reply_to) do
    start_time = System.monotonic_time(:microsecond)

    case TemplateCache.get(artifact_type, artifact_id) do
      {:ok, template} ->
        # Encode as JSON
        case Jason.encode(template) do
          {:ok, json} ->
            Singularity.NatsClient.publish(reply_to, json)
            emit_telemetry(:success, artifact_type, start_time)

          {:error, reason} ->
            error_msg = Jason.encode!(%{error: "encoding_failed", reason: inspect(reason)})
            Singularity.NatsClient.publish(reply_to, error_msg)
            emit_telemetry(:error, artifact_type, start_time)
        end

      {:error, :not_found} ->
        error_msg = Jason.encode!(%{error: "not_found", type: artifact_type, id: artifact_id})
        Singularity.NatsClient.publish(reply_to, error_msg)
        emit_telemetry(:not_found, artifact_type, start_time)

      {:error, reason} ->
        error_msg = Jason.encode!(%{error: "internal_error", reason: inspect(reason)})
        Singularity.NatsClient.publish(reply_to, error_msg)
        emit_telemetry(:error, artifact_type, start_time)
    end
  end

  defp handle_get_request(_gnat, _artifact_type, _artifact_id, nil) do
    # No reply_to - can't respond
    Logger.warning("Received template.get request without reply_to")
  end

  defp handle_search_request(gnat, query, reply_to) do
    start_time = System.monotonic_time(:microsecond)

    # Implement semantic search using pgvector
    case Singularity.Knowledge.ArtifactStore.search(query, top_k: 10) do
      {:ok, results} ->
        formatted_results =
          Enum.map(results, fn artifact ->
            %{
              id: artifact.id,
              artifact_type: artifact.artifact_type,
              name: artifact.name,
              description: artifact.description,
              similarity: artifact.similarity,
              content_preview: String.slice(artifact.content_raw || "", 0, 200) <> "..."
            }
          end)

        response =
          Jason.encode!(%{
            query: query,
            results: formatted_results,
            count: length(formatted_results)
          })

        Singularity.NatsClient.publish(reply_to, response)

      {:error, reason} ->
        Logger.error("Semantic search failed: #{inspect(reason)}")
        send_error(gnat, reply_to, "Search failed: #{inspect(reason)}")
    end

    emit_telemetry(:search, "search", start_time)
  end

  defp handle_search_request(_gnat, _query, nil) do
    Logger.warning("Received template.search request without reply_to")
  end

  defp send_error(_gnat, reply_to, message) when is_binary(reply_to) do
    error_msg = Jason.encode!(%{error: message})
    Singularity.NatsClient.publish(reply_to, error_msg)
  end

  defp send_error(_gnat, nil, _message), do: :ok

  # Public API for other modules to use instead of direct NATS calls

  @doc """
  Render a template with automatic Package Intelligence context injection.

  This is the RECOMMENDED way to render templates - automatically injects:
  - Framework best practices (from frameworks/*.json)
  - Quality requirements (from quality/*.json)
  - Prompt bits (from prompt_library/*.json)
  - Package recommendations (from package registry)

  ## Options
  - `:framework` - Framework name (auto-detected if not provided)
  - `:quality_level` - production|standard|prototype (default: production)
  - `:include_hints` - Include LLM hints (default: false)
  - `:validate` - Validate required variables (default: true)

  ## Examples

      iex> render_with_context("phoenix-liveview", %{
        module_name: "MyAppWeb.Dashboard",
        description: "Real-time dashboard"
      }, framework: "phoenix", quality_level: "production")
      {:ok, code_with_phoenix_best_practices}
  """
  @spec render_with_context(String.t(), map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def render_with_context(template_id, user_variables, opts \\ []) do
    # 1. Query Package Intelligence for enriched context
    case query_package_intelligence(user_variables, opts) do
      {:ok, intelligence} ->
        # 2. Merge user variables with intelligence context
        enriched_variables = compose_context(user_variables, intelligence, opts)

        # 3. Render with enriched context
        render_template_with_solid(template_id, enriched_variables, opts)

      {:error, reason} ->
        # If intelligence query fails, render with user variables only
        Logger.warning("Package Intelligence query failed, rendering without context",
          reason: reason
        )

        render_template_with_solid(template_id, user_variables, opts)
    end
  end

  @doc """
  Render a template using Solid (Handlebars) with full support for conditionals, loops, and partials.

  This is the base rendering function. For context-aware rendering with framework/quality
  injection, use `render_with_context/3` instead.

  ## Options
  - `:validate` - Validate required variables (default: true)
  - `:quality_check` - Run quality checks on output (default: false)
  - `:cache` - Cache rendered output (default: true)

  ## Examples

      iex> render_template_with_solid("elixir-module", %{
        module_name: "MyApp.Worker",
        description: "Background worker",
        api_functions: [
          %{name: "start_link", args: "opts", return_type: "GenServer.on_start()"}
        ]
      })
      {:ok, "defmodule MyApp.Worker do\\n  @moduledoc..."}

      iex> render_template_with_solid("phoenix-api", %{resource: "User"}, validate: true)
      {:ok, rendered_code}
  """
  @spec render_template_with_solid(String.t(), map(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def render_template_with_solid(template_id, variables, opts \\ []) do
    # Delegate to Renderer for actual rendering logic
    case Singularity.Templates.Renderer.render(template_id, variables, opts) do
      {:ok, rendered} ->
        # Track successful render for learning
        track_template_usage(template_id, :success)
        {:ok, rendered}

      {:error, reason} = error ->
        # Track failure for learning
        track_template_usage(template_id, :failure)

        Logger.error("Template render failed",
          template_id: template_id,
          reason: inspect(reason),
          variables: Map.keys(variables)
        )

        error
    end
  end

  @doc """
  Render template using Solid mode explicitly (no fallback to JSON).

  Use this when you need to ensure Handlebars features are available.
  """
  @spec render_with_solid_only(String.t(), map(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def render_with_solid_only(template_id, variables, opts \\ []) do
    case Singularity.Templates.Renderer.render_with_solid(template_id, variables, opts) do
      {:ok, rendered} ->
        track_template_usage(template_id, :success)
        {:ok, rendered}

      {:error, reason} = error ->
        track_template_usage(template_id, :failure)
        error
    end
  end

  @doc """
  Render template using legacy JSON mode explicitly (no Solid features).

  Use this for backward compatibility or when Handlebars features aren't needed.
  """
  @spec render_with_json_only(String.t(), map(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def render_with_json_only(template_id, variables, opts \\ []) do
    case Singularity.Templates.Renderer.render_legacy(template_id, variables, opts) do
      {:ok, rendered} ->
        track_template_usage(template_id, :success)
        {:ok, rendered}

      {:error, reason} = error ->
        track_template_usage(template_id, :failure)
        error
    end
  end

  @doc """
  Search for patterns by detection methods.
  This is the centralized way for other modules to get patterns.
  """
  def search_patterns(detection_methods) do
    # Convert detection methods to search query
    query = Enum.join(detection_methods, " ")

    # First try local TemplateStore for fast access
    case Singularity.TemplateStore.search(query, limit: 100) do
      {:ok, results} when length(results) > 0 ->
        # Convert template results to pattern format
        patterns =
          Enum.map(results, fn template ->
            %{
              id: template.id,
              framework_name: template.name,
              pattern_type: template.type,
              pattern_data: template.content,
              confidence_weight: 0.9,
              success_count: 100,
              failure_count: 5,
              last_used: template.updated_at
            }
          end)

        {:ok, patterns}

      _ ->
        # Fallback to TemplateCache if TemplateStore has no results
        case TemplateCache.search(query, limit: 100) do
          {:ok, results} ->
            patterns =
              Enum.map(results, fn template ->
                %{
                  id: template.id,
                  framework_name: template.name,
                  pattern_type: template.type,
                  pattern_data: template.content,
                  confidence_weight: 0.9,
                  success_count: 100,
                  failure_count: 5,
                  last_used: template.updated_at
                }
              end)

            {:ok, patterns}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Get a specific template by type and ID.
  This is the centralized way for other modules to get templates.
  """
  def get_template(template_type, template_id) do
    # First try local TemplateStore for fast access
    case Singularity.TemplateStore.get("#{template_type}-#{template_id}") do
      {:ok, template} ->
        {:ok, template}

      {:error, _} ->
        # Fallback to TemplateCache
        case TemplateCache.get(template_type, template_id) do
          {:ok, template} ->
            {:ok, template}

          {:error, :not_found} ->
            # Fetch from central cloud via NATS and cache locally
            fetch_and_cache_from_central(template_type, template_id)

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  List available templates by type.
  This helps modules discover what templates are available.
  """
  def list_templates(template_type, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    # First try local TemplateStore
    case Singularity.TemplateStore.search("", type: template_type, limit: limit) do
      {:ok, results} when length(results) > 0 ->
        template_ids = Enum.map(results, & &1.id)
        {:ok, template_ids}

      _ ->
        # Fetch from central cloud via NATS
        fetch_template_list_from_central(template_type, limit)
    end
  end

  @doc """
  Find template using convention-based discovery.
  Tries multiple naming patterns and falls back to semantic search.
  """
  def find_template(template_type, language, use_case, opts \\ []) do
    # Build candidate patterns based on convention
    candidates = build_template_candidates(template_type, language, use_case, opts)

    # Try each candidate in order of preference
    case try_template_candidates(template_type, candidates) do
      {:ok, template} ->
        {:ok, template}

      {:error, _} ->
        # Fallback to semantic search
        search_query = build_search_query(template_type, language, use_case)

        case search_templates(search_query, template_type, limit: 5) do
          {:ok, [best_match | _]} -> {:ok, best_match}
          {:ok, []} -> {:error, :no_templates_found}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Get default template for a type and language.
  This provides sensible defaults when specific templates aren't found.
  """
  def get_default_template(template_type, language) do
    find_template(template_type, language, "default")
  end

  @doc """
  Find quality template for language and quality level.
  """
  def find_quality_template(language, quality_level) do
    find_template("quality_template", language, quality_level)
  end

  @doc """
  Find framework template for language and framework.
  """
  def find_framework_template(language, framework) do
    find_template("framework", language, framework)
  end

  @doc """
  Find technology template for technology type.
  """
  def find_technology_template(technology) do
    find_template("technology", "any", technology)
  end

  @doc """
  Search templates by query and type.
  This helps modules find relevant templates.
  """
  def search_templates(query, template_type, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    # Use TemplateStore for semantic search
    case Singularity.TemplateStore.search(query, type: template_type, limit: limit) do
      {:ok, results} -> {:ok, results}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Store a template locally and sync to central cloud.
  """
  def store_template(template_type, template_id, template_data) do
    # Store in local TemplateStore
    case Singularity.TemplateStore.store(template_id, template_data) do
      :ok ->
        # Also store in TemplateCache for immediate access
        TemplateCache.put("#{template_type}.#{template_id}", template_data)

        # Sync to central cloud via NATS
        sync_to_central(template_type, template_id, template_data)

        {:ok, template_data}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Sync local templates to central cloud.
  """
  def sync_to_central(template_type, template_id, template_data) do
    request = %{
      action: "store_template",
      template_type: template_type,
      template_id: template_id,
      template_data: template_data
    }

    case Singularity.NatsClient.publish("knowledge.template.store", Jason.encode!(request)) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to sync template to central cloud",
          template: "#{template_type}.#{template_id}",
          reason: reason
        )

        # Don't fail local operations if central sync fails
        :ok
    end
  end

  # Private helper functions

  defp fetch_and_cache_from_central(template_type, template_id) do
    # Knowledge cache expects simple TemplateRequest with just id
    request = %{
      id: "#{template_type}-#{template_id}"
    }

    case Singularity.NatsClient.request("knowledge.template.get", Jason.encode!(request),
           timeout: 5000
         ) do
      {:ok, response} ->
        case Jason.decode(response.data) do
          {:ok, template_data} ->
            # Cache locally for future access
            TemplateCache.put("#{template_type}.#{template_id}", template_data)
            Singularity.TemplateStore.store("#{template_type}-#{template_id}", template_data)
            {:ok, template_data}

          {:error, reason} ->
            {:error, "Failed to decode central response: #{reason}"}
        end

      {:error, reason} ->
        {:error, "Central template not found: #{reason}"}
    end
  end

  defp fetch_template_list_from_central(template_type, limit) do
    # Knowledge cache expects TemplateSearchRequest
    request = %{
      category: template_type,
      limit: limit
    }

    case Singularity.NatsClient.request("knowledge.template.list", Jason.encode!(request),
           timeout: 5000
         ) do
      {:ok, response} ->
        case Jason.decode(response.data) do
          {:ok, %{"templates" => templates}} -> {:ok, templates}
          {:ok, data} -> {:ok, data["template_ids"] || []}
          {:error, reason} -> {:error, "Failed to decode central response: #{reason}"}
        end

      {:error, reason} ->
        {:error, "Central template list not found: #{reason}"}
    end
  end

  # Convention-based discovery helpers

  defp build_template_candidates(template_type, language, use_case, opts) do
    version = Keyword.get(opts, :version, "latest")
    include_variants = Keyword.get(opts, :include_variants, true)

    base_candidates = [
      "#{language}_#{use_case}",
      "#{language}_#{use_case}_#{version}",
      "#{language}_#{use_case}_v2",
      "#{language}_#{use_case}_v1",
      "#{use_case}_#{language}",
      "#{use_case}_#{language}_#{version}"
    ]

    if include_variants do
      base_candidates ++
        [
          "#{language}_#{use_case}_production",
          "#{language}_#{use_case}_standard",
          "#{language}_#{use_case}_default",
          "default_#{use_case}",
          "base_#{use_case}",
          "generic_#{use_case}",
          "#{use_case}_template"
        ]
    else
      base_candidates
    end
  end

  defp try_template_candidates(template_type, candidates) do
    Enum.reduce_while(candidates, {:error, :not_found}, fn candidate, _acc ->
      case get_template(template_type, candidate) do
        {:ok, template} -> {:halt, {:ok, template}}
        {:error, _} -> {:cont, {:error, :not_found}}
      end
    end)
  end

  defp build_search_query(template_type, language, use_case) do
    # Build semantic search query from components
    query_parts =
      [language, use_case, template_type]
      |> Enum.reject(&is_nil/1)
      |> Enum.reject(fn x -> x == "any" end)
      |> Enum.join(" ")

    if String.trim(query_parts) == "" do
      template_type
    else
      query_parts
    end
  end

  defp emit_telemetry(status, artifact_type, start_time) do
    duration = System.monotonic_time(:microsecond) - start_time

    :telemetry.execute(
      [:singularity, :template_service, :request],
      %{duration_us: duration},
      %{status: status, artifact_type: artifact_type}
    )
  end

  @doc """
  Track template usage for learning loop.

  This feeds into the Central Cloud IntelligenceHub to:
  - Calculate success rates
  - Identify high-quality templates for promotion
  - Auto-export learned patterns to Git

  Publishes to NATS subject: `template.usage.{template_id}`
  """
  defp track_template_usage(template_id, status) when status in [:success, :failure] do
    usage_event = %{
      template_id: template_id,
      status: status,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      instance_id: node() |> Atom.to_string()
    }

    # Publish to NATS for Central Cloud aggregation
    case Singularity.NatsClient.publish(
           "template.usage.#{template_id}",
           Jason.encode!(usage_event)
         ) do
      :ok ->
        Logger.debug("Tracked template usage",
          template_id: template_id,
          status: status
        )

        :ok

      {:error, reason} ->
        Logger.warning("Failed to track template usage",
          template_id: template_id,
          status: status,
          reason: reason
        )

        # Don't fail the render operation if tracking fails
        :ok
    end
  end

  # ===========================
  # Package Intelligence Integration
  # ===========================

  defp query_package_intelligence(user_variables, opts) do
    # Build query for Package Intelligence
    query = %{
      "description" => user_variables["description"] || "",
      "language" => opts[:language] || user_variables["language"] || "elixir",
      "framework" => opts[:framework],
      "quality_level" => opts[:quality_level] || "production",
      "task_type" => opts[:task_type] || "code_generation"
    }

    # Query via NATS with timeout
    case Singularity.NatsClient.request(
           "intelligence.query",
           Jason.encode!(query),
           timeout: 2000
         ) do
      {:ok, response} ->
        case Jason.decode(response.data) do
          {:ok, intelligence} ->
            Logger.debug("Package Intelligence query successful",
              framework: get_in(intelligence, ["framework", "name"])
            )

            {:ok, intelligence}

          {:error, reason} ->
            {:error, {:decode_error, reason}}
        end

      {:error, reason} ->
        {:error, {:nats_error, reason}}
    end
  end

  defp compose_context(user_vars, intelligence, opts) do
    user_vars
    |> inject_framework_context(intelligence, opts)
    |> inject_quality_requirements(intelligence, opts)
    |> inject_prompt_bits(intelligence, opts)
  end

  defp inject_framework_context(vars, intelligence, opts) do
    if opts[:include_framework_hints] != false do
      framework = intelligence["framework"] || %{}

      Map.merge(vars, %{
        "framework_name" => framework["name"],
        "framework_hints" => framework,
        "best_practices" => framework["best_practices"] || [],
        "common_mistakes" => framework["common_mistakes"] || [],
        "code_snippets" => framework["code_snippets"] || %{},
        "prompt_context" => framework["prompt_context"]
      })
    else
      vars
    end
  end

  defp inject_quality_requirements(vars, intelligence, opts) do
    if opts[:include_quality_hints] != false do
      quality = intelligence["quality"] || %{}

      Map.merge(vars, %{
        "quality_level" => quality["quality_level"],
        "quality_requirements" => quality["requirements"] || %{},
        "generation_prompts" => quality["prompts"] || %{},
        "scoring_weights" => quality["scoring_weights"] || %{}
      })
    else
      vars
    end
  end

  defp inject_prompt_bits(vars, intelligence, opts) do
    if opts[:include_hints] == true do
      framework = intelligence["framework"] || %{}
      prompts = intelligence["prompts"] || %{}

      Map.merge(vars, %{
        "llm_context" => framework["prompt_context"],
        "system_prompt" => prompts["system_prompt"],
        "generation_hints" => prompts["generation_hints"] || []
      })
    else
      vars
    end
  end
end
