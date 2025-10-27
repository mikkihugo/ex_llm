defmodule ExLLM.Providers.Copilot.API do
  @moduledoc """
  Copilot API Client - Makes calls to Copilot endpoints.

  Responsibilities:
  - Create chat threads
  - Send messages to threads
  - Get responses
  - No token management logic

  Uses the Copilot token passed in as a parameter.
  """

  require Logger

  @copilot_api_base "https://api.githubcopilot.com"
  @copilot_version "0.26.7"
  @editor_plugin_version "copilot-chat/#{@copilot_version}"
  @user_agent "GitHubCopilotChat/#{@copilot_version}"
  @api_version "2025-04-01"

  @doc """
  Create a new chat thread.

  Returns:
  - {:ok, %{thread_id: "...", ...}}
  - {:error, reason}
  """
  def create_thread(copilot_token) do
    url = @copilot_api_base <> "/github/chat/threads"

    headers = copilot_headers(copilot_token)

    case HTTPoison.post(url, "{}", headers) do
      {:ok, %HTTPoison.Response{status_code: 201, body: body}} ->
        case Jason.decode(body) do
          {:ok, response} ->
            Logger.debug("Created Copilot chat thread: #{inspect(response)}")
            {:ok, response}

          {:error, reason} ->
            {:error, "Failed to parse thread response: #{inspect(reason)}"}
        end

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        {:error, "Create thread failed (#{code}): #{body}"}

      {:error, reason} ->
        {:error, "Create thread request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Send a message to a thread.

  Returns:
  - {:ok, %{message: "...", ...}}
  - {:error, reason}
  """
  def send_message(copilot_token, thread_id, message) do
    url = @copilot_api_base <> "/github/chat/threads/#{thread_id}/messages"

    headers = copilot_headers(copilot_token)

    body = Jason.encode!(%{
      "body" => message,
      "intent" => "chat"
    })

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 201, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, response} ->
            Logger.debug("Sent message to Copilot thread")
            {:ok, response}

          {:error, reason} ->
            {:error, "Failed to parse message response: #{inspect(reason)}"}
        end

      {:ok, %HTTPoison.Response{status_code: code, body: response_body}} ->
        {:error, "Send message failed (#{code}): #{response_body}"}

      {:error, reason} ->
        {:error, "Send message request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Get thread information.

  Returns:
  - {:ok, thread_data}
  - {:error, reason}
  """
  def get_thread(copilot_token, thread_id) do
    url = @copilot_api_base <> "/github/chat/threads/#{thread_id}"
    headers = copilot_headers(copilot_token)

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, response} ->
            {:ok, response}

          {:error, reason} ->
            {:error, "Failed to parse thread data: #{inspect(reason)}"}
        end

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        {:error, "Get thread failed (#{code}): #{body}"}

      {:error, reason} ->
        {:error, "Get thread request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  List messages in a thread.

  Returns:
  - {:ok, [messages]}
  - {:error, reason}
  """
  def list_messages(copilot_token, thread_id) do
    url = @copilot_api_base <> "/github/chat/threads/#{thread_id}/messages"
    headers = copilot_headers(copilot_token)

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"messages" => messages}} ->
            {:ok, messages}

          {:ok, response} ->
            {:ok, response}

          {:error, reason} ->
            {:error, "Failed to parse messages: #{inspect(reason)}"}
        end

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        {:error, "List messages failed (#{code}): #{body}"}

      {:error, reason} ->
        {:error, "List messages request failed: #{inspect(reason)}"}
    end
  end

  # Private helpers

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
end
