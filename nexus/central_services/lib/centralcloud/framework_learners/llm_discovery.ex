defmodule CentralCloud.FrameworkLearners.LLMDiscovery do
  @moduledoc """
  LLM Discovery - Framework detection using AI analysis.

  Implements the FrameworkLearner behavior for intelligent framework detection
  by analyzing package structure and code samples with an LLM.

  ## How It Works

  1. Load framework discovery prompt (with caching)
  2. Format prompt with package info and code samples
  3. Call LLM with formatted prompt via NATS
  4. Parse LLM response to extract framework information

  ## Performance

  - 🤖 Thorough - Analyzes actual code, not just dependencies
  - 🌐 Online - Requires network and LLM availability
  - ⏱️  Slower - LLM calls take 5-60 seconds

  ## Example

  Package: npm:my-app
  Code samples: [package.json content, some .js files, ...]
  LLM analysis: "This is a React + Express application"
  Result: ✅ Framework(s) detected with reasoning

  ## When to Use

  ✅ Fallback to template matcher (priority 20+)
  ✅ For custom/hybrid frameworks
  ✅ When confidence is important (includes reasoning)
  ❌ For real-time responses (use template matcher first)
  ❌ In offline environments
  """

  @behaviour CentralCloud.FrameworkLearner

  require Logger
  alias CentralCloud.NatsClient

  # ===========================
  # FrameworkLearner Behavior Callbacks
  # ===========================

  @impl CentralCloud.FrameworkLearner
  def learner_type, do: :llm_discovery

  @impl CentralCloud.FrameworkLearner
  def description do
    "Intelligent framework detection using LLM analysis of code"
  end

  @impl CentralCloud.FrameworkLearner
  def capabilities do
    ["llm_based", "thorough", "custom_frameworks", "reasoning", "code_analysis"]
  end

  @impl CentralCloud.FrameworkLearner
  def learn(package_id, code_samples) when is_list(code_samples) do
    Logger.info("LLM discovery: Starting framework discovery for #{package_id}")

    prompt_template = load_framework_discovery_prompt()

    case call_llm_discovery(package_id, code_samples, prompt_template) do
      {:ok, framework_data} ->
        Logger.info("LLM discovery: Framework detected for #{package_id}",
          framework: framework_data[:name]
        )
        {:ok, framework_data}

      :no_match ->
        Logger.debug("LLM discovery: Could not determine framework for #{package_id}")
        :no_match

      {:error, reason} ->
        Logger.error("LLM discovery: Error during discovery",
          package_id: package_id,
          reason: inspect(reason)
        )
        {:error, reason}
    end
  end

  @impl CentralCloud.FrameworkLearner
  def record_success(_package_id, _framework) do
    # LLM discovery doesn't need additional recording beyond storage in orchestrator
    :ok
  end

  # ===========================
  # Private Functions
  # ===========================

  defp load_framework_discovery_prompt do
    # Prompts CAN be cached (they change less frequently than frameworks)
    case NatsClient.kv_get("templates", "prompt:framework-discovery") do
      {:ok, prompt} ->
        Logger.debug("LLM discovery: Loaded prompt from cache")
        prompt

      {:error, _} ->
        fetch_prompt_from_knowledge_cache("framework-discovery")
    end
  end

  defp fetch_prompt_from_knowledge_cache(prompt_id) do
    case NatsClient.request("central.template.get", %{
      artifact_type: "prompt_template",
      artifact_id: prompt_id
    }, timeout: 5_000) do
      {:ok, response} ->
        prompt = response["template"] || %{}

        # Cache prompts for future use (they change less often)
        # TODO: Add TTL support to JetStream KV
        spawn(fn -> NatsClient.kv_put("templates", "prompt:#{prompt_id}", prompt) end)

        Logger.debug("LLM discovery: Loaded and cached prompt: #{prompt_id}")
        prompt

      {:error, reason} ->
        Logger.error("LLM discovery: Failed to load prompt",
          prompt_id: prompt_id,
          reason: inspect(reason)
        )
        %{}
    end
  end

  defp call_llm_discovery(package_id, code_samples, prompt_template) do
    prompt_content = format_discovery_prompt(prompt_template, package_id, code_samples)
    request_id = generate_request_id()

    Logger.info("LLM discovery: Calling LLM for #{package_id}",
      request_id: request_id,
      samples_count: length(code_samples)
    )

    case NatsClient.request(CentralCloud.NatsRegistry.subject(:llm_request), %{
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
        framework_name: package_id,
        code_samples: code_samples
      }
    }, timeout: 120_000) do
      {:ok, llm_response} ->
        parse_llm_framework_response(llm_response)

      {:error, :timeout} ->
        Logger.warning("LLM discovery: LLM request timed out", package_id: package_id)
        {:error, :llm_timeout}

      {:error, reason} ->
        Logger.error("LLM discovery: LLM request failed",
          reason: inspect(reason),
          package_id: package_id
        )
        {:error, :llm_failed}
    end
  end

  defp parse_llm_framework_response(llm_response) do
    case llm_response do
      # Direct framework data in response
      %{"framework" => _} = data ->
        {:ok, enrich_framework_data(data)}

      # JSON string in response field
      %{"response" => content} when is_binary(content) ->
        case Jason.decode(content) do
          {:ok, parsed} ->
            {:ok, enrich_framework_data(parsed)}

          {:error, _} ->
            Logger.warning("LLM discovery: Could not parse LLM response as JSON")
            :no_match
        end

      # Empty or invalid response
      %{} ->
        Logger.warning("LLM discovery: Invalid LLM response format")
        :no_match

      nil ->
        :no_match

      _ ->
        Logger.warning("LLM discovery: Unexpected response type")
        :no_match
    end
  end

  defp enrich_framework_data(data) when is_map(data) do
    data
    |> Map.put_new("detected_by", "llm_discovery")
    |> Map.put_new("confidence", 0.85)
  end

  defp enrich_framework_data(data) do
    data
  end

  defp format_discovery_prompt(prompt_template, package_id, code_samples) do
    template_str = prompt_template["prompt_template"] || default_discovery_prompt()

    template_str
    |> String.replace("{{framework_name}}", package_id)
    |> String.replace("{{code_samples}}", Jason.encode!(code_samples))
  end

  defp default_discovery_prompt do
    """
    Analyze the following code and dependencies to identify the framework(s) in use.

    Package: {{framework_name}}

    Code Samples:
    {{code_samples}}

    Based on the code structure, dependencies, and patterns, identify:
    1. Primary framework name
    2. Framework type (web_framework, backend, build_tool, etc.)
    3. Version if detectable
    4. Any secondary frameworks or libraries

    Respond in JSON format:
    {
      "name": "Framework Name",
      "type": "framework_type",
      "version": "detected version or null",
      "confidence": 0.0-1.0,
      "reasoning": "Brief explanation"
    }
    """
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end
