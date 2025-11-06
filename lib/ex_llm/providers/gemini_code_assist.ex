defmodule ExLLM.Providers.GeminiCodeAssist do
  @moduledoc """
  Gemini Code Assist adapter that authenticates with Google Application Default
  Credentials (ADC) from `~/.config/gcloud`.

  This provider targets the same backend used by Google’s Gemini Code CLI. It
  retrieves an OAuth2 access token using the locally configured ADC refresh
  token, scopes it for `https://www.googleapis.com/auth/generative-language` and
  `https://www.googleapis.com/auth/cloud-platform`, and routes requests to the
  Gemini Code Assist endpoint while attaching the required
  `X-Goog-User-Project` billing header.

  The resolved API endpoint is persisted to `/tmp/gemini/code_assist_endpoint`
  so other local tooling can inspect the active destination. You can override it
  with the `GEMINI_CODE_ENDPOINT` environment variable or by writing the desired
  URL into that file. Allowed domains for request filtering can be supplied via
  `GEMINI_CODE_ALLOWED_DOMAINS` or `/tmp/gemini/allowed_domains`.

  ## Configuration

  The provider reads configuration from:

    * `GOOGLE_APPLICATION_CREDENTIALS` – optional path override for ADC JSON.
    * `GEMINI_CODE_PROJECT_ID` – optional override for the billing project.
    * `GEMINI_CODE_LOCATION` – optional override for the region (default:
      `"us-central1"`).

  When the variables are missing, it falls back to the Cloud SDK defaults:

    * `~/.config/gcloud/application_default_credentials.json`
    * `~/.config/gcloud/active_config` + `config_<name>` to determine
      `project_id`.

  Tokens are cached in-memory until 60 seconds prior to expiry.
  """

  @behaviour ExLLM.Provider

  require Logger

  alias ExLLM.Types
  alias __MODULE__.GoogleToken
  alias __MODULE__.Project

  @token_endpoint "https://oauth2.googleapis.com/token"
  @scope "https://www.googleapis.com/auth/generative-language https://www.googleapis.com/auth/cloud-platform"
  @default_endpoint "https://cloudcode-pa.googleapis.com"
  @endpoint_file "/tmp/gemini/code_assist_endpoint"
  @allowed_domains_file "/tmp/gemini/allowed_domains"
  @api_version "v1internal"
  @default_model "gemini-2.5-flash"
  @default_location "us-central1"

  def scope, do: @scope
  def token_endpoint, do: @token_endpoint
  def default_location, do: @default_location

  @impl true
  def chat(messages, options \\ []) do
    session_id = Keyword.get(options, :session_id)
    user_prompt_id = Keyword.get(options, :user_prompt_id)

    with {:ok, access_token} <- GoogleToken.fetch(),
         {:ok, project} <- Project.fetch(),
         model <- Keyword.get(options, :model, @default_model),
         {:ok, request} <-
           build_request(messages, options, model, project, session_id, user_prompt_id),
         {:ok, response} <- call_gemini(:generateContent, request, access_token, project) do
      normalised = normalize_code_assist_response(response)
      {:ok, map_response(normalised, model, response)}
    end
  end

  @impl true
  def stream_chat(_messages, _options \\ []) do
    {:error, :streaming_not_implemented}
  end

  @impl true
  def configured?(_options \\ []) do
    match?({:ok, _}, GoogleToken.load_adc())
  end

  @impl true
  def default_model, do: @default_model

  @impl true
  def list_models(_options \\ []) do
    {:ok,
     [
       %Types.Model{
         id: "gemini-2.5-flash",
         name: "Gemini 2.5 Flash",
         description: "Fast multimodal model optimised for code assist",
         context_window: 1_048_576,
         capabilities: %{completion: true, tools: true, vision: true},
         pricing: nil
       },
       %Types.Model{
         id: "gemini-2.5-pro",
         name: "Gemini 2.5 Pro",
         description: "Most capable Gemini model with 1M tokens",
         context_window: 1_048_576,
         capabilities: %{completion: true, tools: true, vision: true},
         pricing: nil
       }
     ]}
  end

  @impl true
  def embeddings(_inputs, _options \\ []) do
    {:error, :embeddings_not_supported}
  end

  @impl true
  def list_embedding_models(_options \\ []) do
    {:ok, []}
  end

  defp build_request(messages, options, model, project, session_id, user_prompt_id)
       when is_list(messages) do
    with {:ok, request_body} <- build_request_body(messages, options, session_id) do
      %{
        "model" => model,
        "project" => project,
        "user_prompt_id" => user_prompt_id,
        "request" => request_body
      }
      |> strip_nil_values()
      |> ok()
    end
  end

  defp build_request(_messages, _options, _model, _project, _session_id, _user_prompt_id) do
    {:error, :invalid_messages}
  end

  defp call_gemini(operation, payload, token, project) do
    url = "#{api_base()}/#{@api_version}:#{operation}"

    headers =
      [
        {"authorization", "Bearer #{token}"},
        {"content-type", "application/json"}
      ]
      |> maybe_put_header("x-goog-user-project", project)
      |> maybe_put_allowed_domains()

    case Req.post(url: url, headers: headers, json: payload) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:api_error, %{status: status, body: body}}}

      {:error, reason} ->
        {:error, {:network_error, reason}}
    end
  end

  defp build_request_body(messages, options, session_id) when is_list(messages) do
    {system_instruction, contents} =
      messages
      |> Enum.map(&normalize_message/1)
      |> Enum.reject(&is_nil/1)
      |> extract_system_instruction()

    %{
      "contents" => contents,
      "systemInstruction" => system_instruction,
      "cachedContent" => Keyword.get(options, :cached_content),
      "tools" => Keyword.get(options, :tools),
      "toolConfig" => Keyword.get(options, :tool_config),
      "labels" => Keyword.get(options, :labels),
      "safetySettings" => Keyword.get(options, :safety_settings),
      "generationConfig" => build_generation_config(options),
      "session_id" => session_id
    }
    |> strip_nil_values()
    |> ok()
  end

  defp build_request_body(_messages, _options, _session_id), do: {:error, :invalid_messages}

  defp normalize_message(%{role: role, content: content}) when is_binary(content) do
    %{
      "role" => convert_role(role),
      "parts" => [%{"text" => content}]
    }
  end

  defp normalize_message(%{role: role, content: parts}) when is_list(parts) do
    joined =
      parts
      |> Enum.map(&extract_text/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    %{
      "role" => convert_role(role),
      "parts" => [%{"text" => joined}]
    }
  end

  defp normalize_message(%{role: role, content: %{text: text}}) when is_binary(text) do
    %{
      "role" => convert_role(role),
      "parts" => [%{"text" => text}]
    }
  end

  defp normalize_message(%{"role" => role, "content" => content}) do
    normalize_message(%{role: role, content: content})
  end

  defp normalize_message(other) do
    Logger.warning("GeminiCode received unsupported message format: #{inspect(other)}")
    %{"role" => "user", "parts" => [%{"text" => inspect(other)}]}
  end

  defp convert_role(role) when role in ["assistant", :assistant], do: "model"
  defp convert_role(role) when role in ["system", :system], do: "system"
  defp convert_role(_), do: "user"

  defp extract_system_instruction([%{"role" => "system"} = first | rest]), do: {first, rest}
  defp extract_system_instruction(contents), do: {nil, contents}

  defp build_generation_config(options) do
    %{
      "temperature" => Keyword.get(options, :temperature),
      "topP" => Keyword.get(options, :top_p),
      "topK" => Keyword.get(options, :top_k),
      "candidateCount" => Keyword.get(options, :candidate_count),
      "maxOutputTokens" =>
        Keyword.get(options, :max_output_tokens) || Keyword.get(options, :max_tokens),
      "stopSequences" => Keyword.get(options, :stop_sequences),
      "presencePenalty" => Keyword.get(options, :presence_penalty),
      "frequencyPenalty" => Keyword.get(options, :frequency_penalty),
      "responseMimeType" => Keyword.get(options, :response_mime_type),
      "responseModalities" => Keyword.get(options, :response_modalities),
      "responseLogprobs" => Keyword.get(options, :response_logprobs),
      "logprobs" => Keyword.get(options, :logprobs),
      "routingConfig" => Keyword.get(options, :routing_config),
      "modelSelectionConfig" => Keyword.get(options, :model_selection_config),
      "mediaResolution" => Keyword.get(options, :media_resolution),
      "speechConfig" => Keyword.get(options, :speech_config),
      "thinkingConfig" => Keyword.get(options, :thinking_config),
      "audioTimestamp" => Keyword.get(options, :audio_timestamp),
      "seed" => Keyword.get(options, :seed)
    }
    |> strip_nil_values()
    |> case do
      %{} = map when map == %{} -> nil
      map -> map
    end
  end

  defp extract_text(%{text: text}) when is_binary(text), do: text
  defp extract_text(%{"text" => text}) when is_binary(text), do: text
  defp extract_text(text) when is_binary(text), do: text
  defp extract_text(_), do: nil

  defp normalize_code_assist_response(%{"response" => response} = raw) do
    response
    |> Map.put_new("model", Map.get(raw, "model"))
    |> Map.put_new("id", Map.get(raw, "id"))
  end

  defp normalize_code_assist_response(other), do: other

  defp map_response(%{"candidates" => [first | _]} = response, model, raw) do
    text =
      first
      |> get_in(["content", "parts"])
      |> List.wrap()
      |> Enum.filter(&is_map/1)
      |> Enum.map(&Map.get(&1, "text", ""))
      |> Enum.join()

    %Types.LLMResponse{
      content: text,
      model: Map.get(response, "model", model),
      usage: usage_from_response(response),
      finish_reason: Map.get(first, "finishReason"),
      id: Map.get(response, "id"),
      metadata: %{"raw" => raw}
    }
  end

  defp map_response(response, model, raw) do
    %Types.LLMResponse{
      content: nil,
      model: Map.get(response, "model", model),
      usage: usage_from_response(response),
      finish_reason: nil,
      id: Map.get(response, "id"),
      metadata: %{"raw" => raw}
    }
  end

  defp usage_from_response(%{"usageMetadata" => usage}) when is_map(usage) do
    %{
      input_tokens: Map.get(usage, "promptTokenCount"),
      output_tokens: Map.get(usage, "candidatesTokenCount"),
      total_tokens: Map.get(usage, "totalTokenCount")
    }
  end

  defp usage_from_response(_), do: nil

  defp strip_nil_values(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  defp ok(value), do: {:ok, value}

  defp api_base do
    endpoint =
      System.get_env("GEMINI_CODE_ENDPOINT")
      |> present() ||
        read_trimmed(@endpoint_file) ||
        @default_endpoint

    persist_endpoint(endpoint)
    endpoint
  end

  defp allowed_domains do
    System.get_env("GEMINI_CODE_ALLOWED_DOMAINS")
    |> present() ||
      read_trimmed(@allowed_domains_file)
  end

  defp maybe_put_allowed_domains(headers) do
    case allowed_domains() do
      nil -> headers
      domains -> [{"x-geminicodeassist-allowed-domains", domains} | headers]
    end
  end

  defp maybe_put_header(headers, _key, nil), do: headers
  defp maybe_put_header(headers, key, value), do: [{key, value} | headers]

  defp present(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp present(_), do: nil

  defp read_trimmed(path) do
    case File.read(path) do
      {:ok, contents} ->
        contents
        |> String.trim()
        |> case do
          "" -> nil
          trimmed -> trimmed
        end

      {:error, _} ->
        nil
    end
  end

  defp persist_endpoint(endpoint) do
    dir = Path.dirname(@endpoint_file)

    case File.mkdir_p(dir) do
      :ok -> :ok
      {:error, :eexist} -> :ok
      {:error, _reason} -> :error
    end

    case read_trimmed(@endpoint_file) do
      ^endpoint ->
        :ok

      _ ->
        _ = File.write(@endpoint_file, endpoint <> "\n")
        :ok
    end
  end

  defmodule GoogleToken do
    @moduledoc false

    @refresh_margin 60
    @token_key {__MODULE__, :token}

    def fetch do
      case current_token() do
        {:ok, %{token: token}} ->
          {:ok, token}

        _ ->
          with {:ok, adc} <- load_adc(),
               {:ok, token_info} <- refresh_token(adc) do
            store_token(token_info)
            {:ok, token_info.token}
          end
      end
    end

    def load_adc do
      path =
        System.get_env("GOOGLE_APPLICATION_CREDENTIALS") ||
          Path.expand("~/.config/gcloud/application_default_credentials.json")

      with true <- File.exists?(path) || {:error, :adc_not_found},
           {:ok, content} <- File.read(path),
           {:ok, json} <- Jason.decode(content) do
        {:ok,
         %{
           client_id: json["client_id"],
           client_secret: json["client_secret"],
           refresh_token: json["refresh_token"]
         }}
      else
        {:error, _} = error -> error
        false -> {:error, :adc_not_found}
      end
    end

    defp refresh_token(%{client_id: id, client_secret: secret, refresh_token: refresh}) do
      body = %{
        "client_id" => id,
        "client_secret" => secret,
        "refresh_token" => refresh,
        "grant_type" => "refresh_token",
        "scope" => ExLLM.Providers.GeminiCodeAssist.scope()
      }

      case Req.post(url: ExLLM.Providers.GeminiCodeAssist.token_endpoint(), form: body) do
        {:ok, %Req.Response{status: 200, body: resp}} ->
          expires_in = Map.get(resp, "expires_in", 3600)

          {:ok,
           %{
             token: resp["access_token"],
             expires_at: System.system_time(:second) + expires_in
           }}

        {:ok, %Req.Response{status: status, body: resp}} ->
          {:error, {:oauth_error, status, resp}}

        {:error, reason} ->
          {:error, {:network_error, reason}}
      end
    end

    defp current_token do
      case :persistent_term.get(@token_key, nil) do
        %{token: token, expires_at: expires_at} ->
          if expires_at - System.system_time(:second) > @refresh_margin do
            {:ok, %{token: token}}
          else
            :persistent_term.erase(@token_key)
            :error
          end

        _ ->
          :error
      end
    end

    defp store_token(info) do
      :persistent_term.put(@token_key, info)
    end
  end

  defmodule Project do
    @moduledoc false

    def fetch do
      cond do
        project = System.get_env("GEMINI_CODE_PROJECT_ID") ->
          {:ok, String.trim(project)}

        project = System.get_env("GOOGLE_CLOUD_PROJECT") ->
          {:ok, String.trim(project)}

        true ->
          read_from_gcloud()
      end
    end

    def location do
      System.get_env("GEMINI_CODE_LOCATION") ||
        System.get_env("GOOGLE_CLOUD_LOCATION") ||
        ExLLM.Providers.GeminiCodeAssist.default_location()
    end

    defp read_from_gcloud do
      with {:ok, config_name} <- active_config(),
           {:ok, project} <- config_project(config_name) do
        {:ok, project}
      end
    end

    defp active_config do
      path = Path.expand("~/.config/gcloud/active_config")

      with true <- File.exists?(path) || {:error, :active_config_missing},
           {:ok, content} <- File.read(path),
           config when is_binary(config) <- String.trim(content),
           true <- config != "" || {:error, :active_config_empty} do
        {:ok, config}
      else
        {:error, _} = error -> error
        false -> {:error, :active_config_missing}
      end
    end

    defp config_project(config_name) do
      path = Path.expand("~/.config/gcloud/configurations/config_#{config_name}")

      with true <- File.exists?(path) || {:error, :config_file_missing},
           {:ok, content} <- File.read(path),
           project when is_binary(project) <- extract_project(content),
           true <- project != "" || {:error, :project_missing} do
        {:ok, project}
      else
        {:error, _} = error -> error
        false -> {:error, :config_file_missing}
      end
    end

    defp extract_project(content) do
      content
      |> String.split("\n")
      |> Enum.find_value("", fn line ->
        case String.split(String.trim(line), "=", parts: 2) do
          ["project", value] -> String.trim(value)
          _ -> nil
        end
      end)
    end
  end
end
