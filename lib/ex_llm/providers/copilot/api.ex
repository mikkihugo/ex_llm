defmodule ExLLM.Providers.Copilot.API do
  @moduledoc """
  Copilot API Client - Makes calls to Copilot chat/completions endpoint.

  Uses OpenAI-compatible format at:
  POST https://api.githubcopilot.com/chat/completions

  Responsibilities:
  - Call Copilot chat completions API
  - Format messages properly
  - Handle responses
  - No token management logic

  Uses the Copilot token passed in as a parameter.
  """

  require Logger
  alias ExLLM.Providers.Shared.HTTP.Core

  @copilot_api_base "https://api.githubcopilot.com"
  @copilot_completions_endpoint "/chat/completions"
  @copilot_version "0.26.7"
  @editor_plugin_version "copilot-chat/#{@copilot_version}"
  @user_agent "GitHubCopilotChat/#{@copilot_version}"
  @api_version "2025-04-01"

  @doc """
  Call Copilot chat completions API.

  Compatible with OpenAI chat completions format.

  Parameters:
  - copilot_token: The Copilot API token
  - messages: List of message maps with :role and :content
  - opts: Options like model, temperature, max_tokens

  Returns:
  - {:ok, %{"choices" => [%{"message" => %{"content" => "..."}}], ...}}
  - {:error, reason}
  """
  def chat_completions(copilot_token, messages, opts \\ []) do
    url = @copilot_api_base <> @copilot_completions_endpoint
    headers = copilot_headers(copilot_token)

    model = Keyword.get(opts, :model, "gpt-4-turbo")
    temperature = Keyword.get(opts, :temperature, 0.7)
    max_tokens = Keyword.get(opts, :max_tokens, 2048)

    body = %{
      "model" => model,
      "messages" => format_messages(messages),
      "temperature" => temperature,
      "max_tokens" => max_tokens,
      "stream" => false
    }

    client_opts = [
      provider: :copilot,
      base_url: @copilot_api_base
    ]

    client = Core.client(client_opts)

    case execute_request(client, :post, @copilot_completions_endpoint, body, headers) do
      {:ok, %{"choices" => _} = response} ->
        Logger.debug("Copilot API response: #{inspect(response)}")
        {:ok, response}

      {:ok, response} ->
        Logger.error("Copilot API unexpected response: #{inspect(response)}")
        {:error, "Copilot API returned unexpected format"}

      {:error, reason} ->
        Logger.error("Copilot API request failed: #{inspect(reason)}")
        {:error, "Copilot API request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Stream Copilot chat completions.

  Similar to chat_completions but returns streaming chunks.
  """
  def chat_completions_stream(copilot_token, messages, callback, opts \\ []) do
    url = @copilot_api_base <> @copilot_completions_endpoint
    headers = copilot_headers(copilot_token)

    model = Keyword.get(opts, :model, "gpt-4-turbo")
    temperature = Keyword.get(opts, :temperature, 0.7)
    max_tokens = Keyword.get(opts, :max_tokens, 2048)

    body = %{
      "model" => model,
      "messages" => format_messages(messages),
      "temperature" => temperature,
      "max_tokens" => max_tokens,
      "stream" => true
    }

    client_opts = [
      provider: :copilot,
      base_url: @copilot_api_base
    ]

    client = Core.client(client_opts)

    case execute_request(client, :post, @copilot_completions_endpoint, body, headers) do
      {:ok, stream} when is_function(stream) ->
        stream
        |> Stream.map(&parse_stream_chunk/1)
        |> Stream.each(fn
          {:ok, content} -> if callback, do: callback.(content)
          {:error, _} -> :ok
        end)
        |> Stream.run()

        {:ok, "Streaming complete"}

      {:error, reason} ->
        Logger.error("Copilot streaming request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private helpers

  defp format_messages(messages) when is_list(messages) do
    Enum.map(messages, fn msg ->
      %{
        "role" => get_role(msg),
        "content" => get_content(msg)
      }
    end)
  end

  defp get_role(msg) when is_map(msg) do
    Map.get(msg, :role) || Map.get(msg, "role") || "user"
  end

  defp get_content(msg) when is_map(msg) do
    Map.get(msg, :content) || Map.get(msg, "content") || ""
  end

  defp copilot_headers(copilot_token) do
    [
      {"Authorization", "Bearer #{copilot_token}"},
      {"content-type", "application/json"},
      {"accept", "application/json"},
      {"copilot-integration-id", "vscode-chat"},
      {"editor-plugin-version", @editor_plugin_version},
      {"user-agent", @user_agent},
      {"openai-intent", "conversation-panel"},
      {"x-github-api-version", @api_version},
      {"x-vscode-user-agent-library-version", "electron-fetch"}
    ]
  end

  defp execute_request(client, method, path, body, headers) do
    case Tesla.request(client, method: method, url: path, body: body, headers: headers) do
      {:ok, %Tesla.Env{status: 200, body: response_body}} ->
        Jason.decode(response_body)

      {:ok, %Tesla.Env{status: code, body: response_body}} ->
        {:error, "Copilot API failed with status #{code}: #{response_body}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_stream_chunk(chunk) when is_binary(chunk) do
    case String.split(chunk, "\n") do
      chunks ->
        chunks
        |> Enum.filter(&String.starts_with?(&1, "data: "))
        |> Enum.map(&String.replace_leading(&1, "data: ", ""))
        |> Enum.map(&Jason.decode/1)
        |> Enum.find_value(fn
          {:ok, %{"choices" => [%{"delta" => %{"content" => content}}]}} -> {:ok, content}
          _ -> nil
        end)
        |> case do
          nil -> {:error, :no_content}
          result -> result
        end
    end
  end

  defp parse_stream_chunk(_chunk), do: {:error, :invalid_chunk}
end
