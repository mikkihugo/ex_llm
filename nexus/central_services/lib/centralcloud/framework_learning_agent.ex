defmodule CentralCloud.FrameworkLearningAgent do
  @moduledoc """
  Framework Learning Agent for Central Cloud - **REACTIVE PATTERN with NATS JetStream**

  **Triggers on-demand when framework is not found:**
  1. User searches for framework pattern via package_intelligence
  2. No match found in PostgreSQL cache
  3. **Agent activates** - discovers framework via LLM
  4. Stores result in PostgreSQL (packages.detected_framework)
  5. Returns to user + caches for future requests

  ## NATS Integration

  - **Framework Templates**: ALWAYS fetch latest (no caching - new versions released constantly!)
  - **Prompt Templates**: Cached in JetStream KV (change less frequently)
  - **LLM Calls**: Routed to `llm-server` via `llm.request`

  ## Caching Strategy

  - ✅ **Framework templates**: NO cache (always fresh from knowledge_cache)
  - ✅ **Prompt templates**: JetStream KV cache (1 hour TTL)
  - ✅ **Discovery results**: PostgreSQL (packages.detected_framework)

  ## Usage

  ```elixir
  # Start agent
  {:ok, pid} = FrameworkLearningAgent.start_link()

  # Triggered by package_intelligence when framework not found
  {:ok, framework_data} = FrameworkLearningAgent.discover_framework(package_id, code_samples)
  ```
  """

  use GenServer
  require Logger

  alias CentralCloud.Repo
  alias CentralCloud.Schemas.Package
  alias CentralCloud.{TemplateService}
  alias Pgflow

  # ETS table for prompt caching
  @prompt_cache_table :framework_prompt_cache
  @cache_ttl_ms 3_600_000  # 1 hour

  # ===========================
  # Public API
  # ===========================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def discover_framework(package_id, code_samples) do
    GenServer.call(__MODULE__, {:discover, package_id, code_samples}, :timer.minutes(5))
  end

  def framework_known?(package_id) do
    GenServer.call(__MODULE__, {:known?, package_id})
  end

  # ===========================
  # GenServer Callbacks
  # ===========================

  @impl true
  def init(_opts) do
    Logger.info("FrameworkLearningAgent started - reactive mode with NATS JetStream")

    # Create ETS table for prompt caching
    :ets.new(@prompt_cache_table, [:named_table, :set, :public, read_concurrency: true])

    {:ok,
     %{
       discovery_count: 0,
       cache_hits: 0,
       cache_misses: 0,
       llm_calls: 0,
       template_matches: 0
     }}
  end

  @impl true
  def handle_call({:discover, package_id, code_samples}, _from, state) do
    Logger.info("Framework discovery requested for package: #{package_id}")

    result = discover_framework_for_package(package_id, code_samples, state)

    new_state =
      case result do
        {:ok, _framework_data, :llm} ->
          %{state | discovery_count: state.discovery_count + 1, llm_calls: state.llm_calls + 1}

        {:ok, _framework_data, :template} ->
          %{state |
            discovery_count: state.discovery_count + 1,
            template_matches: state.template_matches + 1
          }

        _ ->
          state
      end

    response =
      case result do
        {:ok, data, _source} -> {:ok, data}
        error -> error
      end

    {:reply, response, new_state}
  end

  @impl true
  def handle_call({:known?, package_id}, _from, state) do
    package = Repo.get(Package, package_id)
    known? = package && package.detected_framework != %{}

    new_state =
      if known? do
        %{state | cache_hits: state.cache_hits + 1}
      else
        %{state | cache_misses: state.cache_misses + 1}
      end

    {:reply, known?, new_state}
  end

  # ===========================
  # Private Functions
  # ===========================

  defp discover_framework_for_package(package_id, code_samples, _state) do
    package = Repo.get(Package, package_id)

    if package do
      if package.detected_framework != %{} do
        Logger.debug("Framework already known for #{package.name}")
        {:ok, package.detected_framework, :cached}
      else
        framework_templates = load_framework_templates()

        case match_known_framework(package, framework_templates) do
          {:ok, matched_template} ->
            Logger.info("Matched #{package.name} to known framework: #{matched_template["name"]}")
            {:ok, framework_data} = store_framework_detection(package, matched_template)
            {:ok, framework_data, :template}

          :no_match ->
            Logger.info("Unknown framework for #{package.name} - calling LLM")
            prompt = load_framework_discovery_prompt()

            case call_llm_discovery_with_code(package, code_samples, prompt) do
              {:ok, framework_data} ->
                {:ok, stored_data} = store_framework_detection(package, framework_data)
                {:ok, stored_data, :llm}

              error ->
                error
            end
        end
      end
    else
      {:error, :package_not_found}
    end
  end

  defp match_known_framework(package, framework_templates) do
    matched_template =
      Enum.find(framework_templates, fn template ->
        matches_framework?(package, template)
      end)

    if matched_template, do: {:ok, matched_template}, else: :no_match
  end

  defp matches_framework?(package, template) do
    signatures = template["detector_signatures"] || %{}
    package_deps = package.dependencies || []
    required_deps = signatures["dependencies"] || []

    Enum.any?(required_deps, fn dep ->
      Enum.any?(package_deps, &String.contains?(&1, dep))
    end)
  end

  defp load_framework_templates do
    # ALWAYS fetch latest - frameworks release new versions constantly!
    # No caching to ensure we detect latest framework versions
    fetch_templates_from_knowledge_cache()
  end

  defp fetch_templates_from_knowledge_cache do
    # Use TemplateService directly (same application)
    case TemplateService.list_templates(category: "framework", deprecated: false) do
      {:ok, templates} ->
        Logger.debug("Loaded #{length(templates)} latest framework templates")
        templates

      {:error, reason} ->
        Logger.error("Failed to load templates: #{inspect(reason)}")
        []
    end
  end

  defp load_framework_discovery_prompt do
    # Prompts CAN be cached (they change less frequently than frameworks)
    # Use JetStream KV with TTL for prompts
    # Replace NATS KV with PgFlow or DB lookup
    case fetch_prompt_from_cache("prompt:framework-discovery") do
      {:ok, prompt} ->
        Logger.debug("Loaded framework_discovery prompt from JetStream KV cache")
        prompt

      {:error, _} ->
        fetch_prompt_from_knowledge_cache("framework-discovery")
    end
  end

  defp fetch_prompt_from_knowledge_cache(prompt_id) do
    # Use TemplateService directly (same application)
    case TemplateService.get_template(prompt_id, category: "prompt") do
      {:ok, template} ->
        # Convert template to prompt format
        prompt = %{
          "prompt_template" => get_in(template, ["content", "system"]) || "",
          "system_prompt" => %{"role" => get_in(template, ["metadata", "description"]) || "Framework detection expert"}
        }

        # Cache prompts for 1 hour (they change less often)
        spawn(fn -> cache_prompt(prompt_id, prompt) end)

        Logger.debug("Loaded and cached prompt: #{prompt_id}")
        prompt

      {:error, reason} ->
        Logger.error("Failed to load prompt #{prompt_id}: #{inspect(reason)}")
        %{}
    end
  end

  defp call_llm_discovery_with_code(package, code_samples, prompt_template) do
    prompt_content = format_discovery_prompt(prompt_template, package, code_samples)
    request_id = generate_request_id()

    Logger.info("Calling LLM for #{package.name}, request_id=#{request_id}")

    case Pgflow.send_with_notify(CentralCloud.NatsRegistry.subject(:llm_request), %{
      request_id: request_id,
      complexity: "complex",
      type: "framework_discovery",
      prompt_template_id: "framework-discovery",
      messages: [
        %{
          role: "system",
          content: prompt_template["system_prompt"]["role"] || "Framework detection expert"
        },
        %{role: "user", content: prompt_content}
      ],
      variables: %{
        framework_name: package.name,
        ecosystem: package.ecosystem,
        code_samples: code_samples
      }
    }, CentralCloud.Repo, timeout: 120_000) do
      {:ok, llm_response} ->
        parse_llm_framework_response(llm_response)

      {:error, :timeout} ->
        {:error, :llm_timeout}

      {:error, reason} ->
        Logger.error("LLM failed: #{inspect(reason)}")
        {:error, :llm_failed}
    end
  end

  defp parse_llm_framework_response(llm_response) do
    case llm_response do
      %{"framework" => _} = data ->
        {:ok, data}

      %{"response" => content} when is_binary(content) ->
        case Jason.decode(content) do
          {:ok, parsed} -> {:ok, parsed}
          {:error, _} -> {:error, :invalid_llm_response}
        end

      _ ->
        {:error, :invalid_llm_response}
    end
  end

  defp format_discovery_prompt(prompt_template, package, code_samples) do
    template_str = prompt_template["prompt_template"] || ""

    template_str
    |> String.replace("{{framework_name}}", package.name || "Unknown")
    |> String.replace("{{files_list}}", Jason.encode!(package.dependencies || []))
    |> String.replace("{{code_samples}}", Jason.encode!(code_samples))
  end

  defp store_framework_detection(package, framework_data) do
    import Ecto.Changeset

    package
    |> change(detected_framework: framework_data)
    |> change(last_updated: DateTime.utc_now())
    |> Repo.update()
    |> case do
      {:ok, updated_package} ->
        {:ok, updated_package.detected_framework}

      error ->
        error
    end
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp cache_prompt(prompt_id, prompt) do
    # Store in ETS with TTL (timestamp)
    expires_at = System.system_time(:millisecond) + @cache_ttl_ms
    :ets.insert(@prompt_cache_table, {prompt_id, prompt, expires_at})
    Logger.debug("Cached prompt: #{prompt_id} (expires in 1 hour)")
  end

  defp fetch_prompt_from_cache(cache_key) do
    case :ets.lookup(@prompt_cache_table, cache_key) do
      [{^cache_key, prompt, expires_at}] ->
        # Check if expired
        if System.system_time(:millisecond) < expires_at do
          Logger.debug("Cache hit: #{cache_key}")
          {:ok, prompt}
        else
          # Expired, remove and return not found
          :ets.delete(@prompt_cache_table, cache_key)
          Logger.debug("Cache expired: #{cache_key}")
          {:error, :not_found}
        end

      [] ->
        Logger.debug("Cache miss: #{cache_key}")
        {:error, :not_found}
    end
  end
end
