defmodule SeedAgent.Integration.Gemini do
  @moduledoc """
  Gemini AI integration via unified HTTP server.

  Prerequisites:
  - npm install -g @google/gemini-cli
  - AI server running: bun run tools/ai-server.ts

  Environment:
  - AI_SERVER_URL (default: http://localhost:3000)

  Models:
  - "gemini-2.5-pro" (default) - Most capable
  - "gemini-2.5-flash" - Faster for simpler tasks
  """

  require Logger

  @default_model "gemini-2.5-pro"
  @default_timeout :timer.minutes(2)
  @default_server_url "http://localhost:3000"

  @type message :: %{role: String.t(), content: String.t()}
  @type opts :: keyword()

  @spec chat([message()], opts() | map()) :: {:ok, String.t()} | {:error, term()}
  def chat(messages, opts_or_payload \\ [])

  def chat(messages, payload) when is_map(payload) do
    # Called from router with payload map
    opts = [
      model: payload["model"],
      temperature: payload["temperature"],
      max_tokens: payload["max_tokens"]
    ]

    chat(messages, opts)
  end

  def chat(messages, opts) when is_list(messages) and is_list(opts) do
    model = opts[:model] || @default_model
    timeout = opts[:timeout] || @default_timeout

    request = %{
      provider: "gemini",
      model: model,
      messages: normalize_messages(messages),
      temperature: opts[:temperature] || 0.7,
      maxTokens: opts[:max_tokens]
    }

    case call_server(request, timeout) do
      {:ok, result} -> extract_text(result)
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_messages(messages) do
    Enum.map(messages, fn
      %{"role" => role, "content" => content} ->
        %{role: role, content: stringify_content(content)}

      %{role: role, content: content} ->
        %{role: to_string(role), content: stringify_content(content)}

      message when is_map(message) ->
        %{
          role: Map.get(message, "role") || Map.get(message, :role) || "user",
          content:
            stringify_content(Map.get(message, "content") || Map.get(message, :content) || "")
        }
    end)
  end

  defp stringify_content(content) when is_binary(content), do: content

  defp stringify_content(content) when is_list(content),
    do: Enum.map_join(content, "\n", &stringify_content/1)

  defp stringify_content(%{"text" => text}), do: text
  defp stringify_content(%{text: text}), do: text
  defp stringify_content(other), do: inspect(other)

  defp call_server(request, timeout) do
    server_url = System.get_env("AI_SERVER_URL") || @default_server_url
    url = "#{server_url}/chat"

    Logger.debug("Calling AI HTTP server", provider: "gemini", model: request.model, url: url)

    case Req.post(url,
           json: request,
           receive_timeout: timeout,
           retry: :transient,
           max_retries: 2
         ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} when status >= 400 ->
        Logger.error("Gemini server error", status: status, body: body)
        {:error, {:gemini_error, status, body}}

      {:error, %{reason: :timeout}} ->
        {:error, :timeout}

      {:error, reason} ->
        Logger.error("Gemini HTTP request failed", error: inspect(reason))
        {:error, {:request_failed, reason}}
    end
  end

  defp extract_text(%{"text" => text}) when is_binary(text) do
    {:ok, text}
  end

  defp extract_text(result) do
    Logger.warning("Unexpected Gemini response format", result: inspect(result))
    {:error, {:invalid_response_format, result}}
  end
end
