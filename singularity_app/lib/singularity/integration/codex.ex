defmodule Singularity.Integration.Codex do
  @moduledoc """
  Codex integration via unified HTTP server.

  Prerequisites:
  - Codex CLI installed
  - AI server running: bun run tools/ai-server.ts

  Environment:
  - AI_SERVER_URL (default: http://localhost:3000)
  - CODEX_SANDBOX (default: read-only)
  """

  require Logger

  @default_model "gpt-5-codex"
  @default_timeout :timer.minutes(2)
  @default_server_url "http://localhost:3000"

  @spec chat(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def chat(prompt, opts \\ []) when is_binary(prompt) do
    model = Keyword.get(opts, :model, @default_model)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    # Convert prompt to messages format
    messages = [%{role: "user", content: prompt}]

    request = %{
      provider: "codex",
      model: model,
      messages: messages
    }

    case call_server(request, timeout) do
      {:ok, result} -> extract_text(result)
      {:error, reason} -> {:error, reason}
    end
  end

  defp call_server(request, timeout) do
    server_url = System.get_env("AI_SERVER_URL") || @default_server_url
    url = "#{server_url}/chat"

    Logger.debug("Calling AI HTTP server", provider: "codex", model: request.model, url: url)

    case Req.post(url,
           json: request,
           receive_timeout: timeout,
           retry: :transient,
           max_retries: 2
         ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} when status >= 400 ->
        Logger.error("AI server error", status: status, body: body)
        {:error, {:codex_error, status, body}}

      {:error, %{reason: :timeout}} ->
        {:error, :timeout}

      {:error, reason} ->
        Logger.error("Codex HTTP request failed", error: inspect(reason))
        {:error, {:request_failed, reason}}
    end
  end

  defp extract_text(%{"text" => text}) when is_binary(text) do
    {:ok, text}
  end

  defp extract_text(result) do
    Logger.warning("Unexpected Codex response format", result: inspect(result))
    {:error, {:invalid_response_format, result}}
  end
end
