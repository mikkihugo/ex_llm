defmodule ExLLM.Providers.Copilot do
  @moduledoc """
  GitHub Copilot Provider for ExLLM.

  Integrates three separate concerns:
  1. GitHub Token Manager - Gets and caches GitHub tokens
  2. Copilot Token Manager - Exchanges GitHub token for Copilot token
  3. Copilot API - Makes chat API calls with Copilot token

  ## Authentication Flow

  1. Get GitHub token (from `gh auth token` or device OAuth)
  2. Exchange for Copilot token (POST to `/copilot_internal/v2/token`)
  3. Use Copilot token for chat API calls
  4. Auto-refresh Copilot token every `refresh_in` seconds

  ## Usage

      iex> {:ok, response} = ExLLM.Providers.Copilot.chat([
      ...>   %{role: "user", content: "Hello Copilot"}
      ...> ])
      iex> response.content
      "Hello! How can I help you today?"
  """

  @behaviour ExLLM.Adapter

  require Logger

  alias ExLLM.Providers.{GitHub, Copilot}

  @doc """
  Chat with GitHub Copilot.

  Options:
  - model: (optional) Copilot model to use
  - temperature: (optional) 0.0-2.0, controls randomness
  - max_tokens: (optional) max response tokens
  """
  @impl true
  def chat(messages, _model \\ "copilot", opts \\ []) do
    with {:ok, github_token} <- GitHub.TokenManager.get_token(),
         :ok <- ensure_copilot_token_manager(github_token),
         {:ok, copilot_token} <- Copilot.TokenManager.get_token(),
         {:ok, thread} <- Copilot.API.create_thread(copilot_token),
         {:ok, _} <- Copilot.API.send_message(copilot_token, thread["id"], format_messages(messages)) do
      # Get the response from the thread
      case Copilot.API.list_messages(copilot_token, thread["id"]) do
        {:ok, messages} ->
          # Extract the assistant's response (last non-user message)
          response = find_assistant_response(messages)

          {:ok,
           %ExLLM.Types.LLMResponse{
             content: response,
             model: "copilot",
             usage: %{input_tokens: 0, output_tokens: 0},
             cost: 0.0,
             metadata: %{thread_id: thread["id"]}
           }}

        {:error, reason} ->
          {:error, "Failed to get response: #{reason}"}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Stream responses from Copilot (creates thread, sends message, streams responses).

  Calls callback with each chunk as it arrives.
  """
  @impl true
  def stream(messages, _model \\ "copilot", callback \\ nil, opts \\ []) do
    with {:ok, github_token} <- GitHub.TokenManager.get_token(),
         :ok <- ensure_copilot_token_manager(github_token),
         {:ok, copilot_token} <- Copilot.TokenManager.get_token(),
         {:ok, thread} <- Copilot.API.create_thread(copilot_token),
         {:ok, _} <- Copilot.API.send_message(copilot_token, thread["id"], format_messages(messages)) do
      # Poll for messages with streaming simulation
      stream_responses(thread["id"], copilot_token, callback, opts)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Create a chat thread for multi-turn conversation.

  Returns thread_id for use with send_message/3.
  """
  def create_thread() do
    with {:ok, github_token} <- GitHub.TokenManager.get_token(),
         :ok <- ensure_copilot_token_manager(github_token),
         {:ok, copilot_token} <- Copilot.TokenManager.get_token(),
         {:ok, thread} <- Copilot.API.create_thread(copilot_token) do
      {:ok, thread["id"]}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Send a message to an existing thread.

  Returns the assistant's response.
  """
  def send_message(thread_id, user_message) do
    with {:ok, _github_token} <- GitHub.TokenManager.get_token(),
         {:ok, copilot_token} <- Copilot.TokenManager.get_token(),
         {:ok, _} <- Copilot.API.send_message(copilot_token, thread_id, user_message) do
      # Get response
      case Copilot.API.list_messages(copilot_token, thread_id) do
        {:ok, messages} ->
          response = find_assistant_response(messages)
          {:ok, response}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get thread conversation history.
  """
  def get_thread(thread_id) do
    with {:ok, _github_token} <- GitHub.TokenManager.get_token(),
         {:ok, copilot_token} <- Copilot.TokenManager.get_token(),
         {:ok, messages} <- Copilot.API.list_messages(copilot_token, thread_id) do
      {:ok, messages}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Private helpers

  defp ensure_copilot_token_manager(github_token) do
    case :global.whereis_name(Copilot.TokenManager) do
      :undefined ->
        # Start token manager if not already running
        case Copilot.TokenManager.start_link(github_token: github_token) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, reason} -> {:error, reason}
        end

      _pid ->
        :ok
    end
  end

  defp format_messages(messages) when is_list(messages) do
    messages
    |> Enum.map(fn msg ->
      case msg do
        %{"role" => role, "content" => content} -> content
        %{role: role, content: content} -> content
        msg when is_binary(msg) -> msg
        _ -> ""
      end
    end)
    |> Enum.join("\n")
  end

  defp format_messages(message) when is_binary(message), do: message

  defp find_assistant_response(messages) when is_list(messages) do
    messages
    |> Enum.reverse()
    |> Enum.find_value(fn msg ->
      case msg do
        %{"role" => "assistant", "body" => body} -> body
        %{"role" => "assistant", "content" => content} -> content
        %{role: "assistant", body: body} -> body
        %{role: "assistant", content: content} -> content
        _ -> nil
      end
    end)
    |> case do
      nil -> "No response received"
      response -> response
    end
  end

  defp stream_responses(thread_id, copilot_token, callback, opts) do
    # Simulate streaming by polling for messages
    case poll_for_response(thread_id, copilot_token, 0) do
      {:ok, message} ->
        if callback, do: callback.(message)
        {:ok, message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp poll_for_response(thread_id, _copilot_token, attempt) when attempt > 30 do
    {:error, "Response timeout"}
  end

  defp poll_for_response(thread_id, copilot_token, attempt) do
    case Copilot.API.list_messages(copilot_token, thread_id) do
      {:ok, messages} ->
        response = find_assistant_response(messages)

        if response != "No response received" do
          {:ok, response}
        else
          Process.sleep(1000)
          poll_for_response(thread_id, copilot_token, attempt + 1)
        end

      {:error, _reason} ->
        Process.sleep(1000)
        poll_for_response(thread_id, copilot_token, attempt + 1)
    end
  end
end
