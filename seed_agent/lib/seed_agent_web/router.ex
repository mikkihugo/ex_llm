defmodule SeedAgentWeb.Router do
  @moduledoc false
  use Plug.Router

  plug :match
  plug Plug.RequestId
  plug Plug.Logger
  plug :dispatch

  post "/v1/chat/completions" do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn),
         {:ok, payload} <- Jason.decode(body),
         {:ok, messages} <- extract_messages(payload),
         {:ok, model} <- extract_model(payload),
         {:ok, provider} <- select_provider(model, conn.params),
         {:ok, response} <- provider.(messages, payload) do
      send_resp(conn, 200, Jason.encode!(response))
    else
      {:error, :bad_request, reason} ->
        send_resp(conn, 400, Jason.encode!(%{error: %{code: "bad_request", message: reason}}))

      {:error, :provider_missing} ->
        send_resp(conn, 400, Jason.encode!(%{error: %{code: "bad_request", message: "Missing provider"}}))

      {:error, {:provider_error, reason}} ->
        send_resp(conn, 500, Jason.encode!(%{error: %{code: "provider_error", message: inspect(reason)}}))

      {:error, reason} ->
        send_resp(conn, 500, Jason.encode!(%{error: %{code: "unexpected_error", message: inspect(reason)}}))
    end
  end

  get "/health" do
    send_resp(conn, 200, Jason.encode!(%{status: "ok"}))
  end

  get "/health/deep" do
    status = SeedAgent.Health.deep_health()
    send_resp(conn, status.http_status, Jason.encode!(status.body))
  end

  get "/metrics" do
    metrics = SeedAgent.PrometheusExporter.render()
    send_resp(conn, 200, metrics)
  end

  match _ do
    send_resp(conn, 404, Jason.encode!(%{error: "not_found"}))
  end

  defp extract_messages(%{"messages" => messages}) when is_list(messages) do
    {:ok, messages}
  end

  defp extract_messages(_), do: {:error, :bad_request, "Missing messages array"}

  defp extract_model(%{"model" => model}) when is_binary(model), do: {:ok, model}
  defp extract_model(_), do: {:error, :bad_request, "Missing model"}

  defp select_provider(model, params) do
    case Map.get(params, "provider", default_provider()) do
      "claude" ->
        {:ok, fn messages, payload ->
          case SeedAgent.Integration.Claude.chat(messages, model: model, metadata: payload) do
            {:ok, %{raw: raw, response: response}} ->
              {:ok, format_openai_response(model, response || raw)}

            {:ok, raw} when is_map(raw) ->
              {:ok, format_openai_response(model, Jason.encode!(raw))}

            {:error, reason} -> {:error, {:provider_error, reason}}
          end
        end}

      "codex" ->
        {:ok, fn messages, _payload ->
          prompt = render_prompt(messages)
          case SeedAgent.Integration.Codex.chat(prompt, model: model) do
            {:ok, text} -> {:ok, format_openai_response(model, text)}
            {:error, reason} -> {:error, {:provider_error, reason}}
          end
        end}

      "gemini" ->
        {:ok, fn messages, payload ->
          case SeedAgent.Integration.Gemini.chat(messages, payload) do
            {:ok, text} -> {:ok, format_openai_response(model, text)}
            {:error, reason} -> {:error, {:provider_error, reason}}
          end
        end}

      "cursor-agent" ->
        {:ok, fn messages, _payload ->
          prompt = render_prompt(messages)
          case SeedAgent.Integration.CursorAgent.chat(prompt) do
            {:ok, text} -> {:ok, format_openai_response(model, text)}
            {:error, reason} -> {:error, {:provider_error, reason}}
          end
        end}

      "copilot" ->
        {:ok, fn messages, _payload ->
          prompt = render_prompt(messages)
          case SeedAgent.Integration.Copilot.chat(prompt) do
            {:ok, text} -> {:ok, format_openai_response(model, text)}
            {:error, reason} -> {:error, {:provider_error, reason}}
          end
        end}

      _ -> {:error, :provider_missing}
    end
  end

  defp default_provider do
    Application.get_env(:seed_agent, :lvm_gateway)[:default_provider] || "claude"
  end

  defp render_prompt(messages) do
    messages
    |> Enum.map(fn %{"role" => role, "content" => content} ->
      "#{role}: #{content_to_string(content)}"
    %{} -> ""
    end)
    |> Enum.join("\n\n")
  end

  defp content_to_string(content) when is_binary(content), do: content
  defp content_to_string(content) when is_list(content), do: Enum.map(content, &content_to_string/1) |> Enum.join("\n")
  defp content_to_string(%{"text" => text}), do: text
  defp content_to_string(_), do: ""

  defp format_openai_response(model, text) do
    %{
      id: "chatcmpl-" <> Integer.to_string(:erlang.unique_integer([:positive])),
      object: "chat.completion",
      created: System.os_time(:second),
      model: model,
      choices: [
        %{
          index: 0,
          message: %{role: "assistant", content: text},
          finish_reason: "stop"
        }
      ],
      usage: %{
        prompt_tokens: String.length(text),
        completion_tokens: String.length(text),
        total_tokens: String.length(text) * 2
      }
    }
  end
end
