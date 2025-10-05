defmodule SingularityWeb.Router do
  @moduledoc false
  use Plug.Router

  alias Singularity.Tools.ToolCall

  plug :match
  plug Plug.RequestId
  plug Plug.Logger
  plug :dispatch

  post "/api/tools/run" do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn),
         {:ok, params} <- decode_json(body),
         {:ok, provider} <- normalize_tool_provider(Map.get(params, "provider")),
         {:ok, tool_name} <- fetch_tool_name(params),
         {:ok, arguments} <- fetch_arguments(params),
         {:ok, tool_call} <- build_tool_call(tool_name, Map.get(params, "call_id"), arguments),
         context <- Map.get(params, "context") || %{},
         {:ok, result} <- Singularity.Tools.Runner.execute(provider, tool_call, context) do
      send_resp(conn, 200, Jason.encode!(serialize_result(result)))
    else
      {:error, :bad_request, reason} ->
        send_resp(conn, 400, Jason.encode!(%{error: %{code: "bad_request", message: reason}}))

      {:error, reason} when is_binary(reason) ->
        send_resp(conn, 500, Jason.encode!(%{error: %{code: "tool_error", message: reason}}))

      {:error, reason} ->
        send_resp(
          conn,
          500,
          Jason.encode!(%{error: %{code: "tool_error", message: inspect(reason)}})
        )
    end
  end

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
        send_resp(
          conn,
          400,
          Jason.encode!(%{error: %{code: "bad_request", message: "Missing provider"}})
        )

      {:error, {:provider_error, reason}} ->
        send_resp(
          conn,
          500,
          Jason.encode!(%{error: %{code: "provider_error", message: inspect(reason)}})
        )

      {:error, reason} ->
        send_resp(
          conn,
          500,
          Jason.encode!(%{error: %{code: "unexpected_error", message: inspect(reason)}})
        )
    end
  end

  get "/health" do
    send_resp(conn, 200, Jason.encode!(%{status: "ok"}))
  end

  get "/health/deep" do
    status = Singularity.Health.deep_health()
    send_resp(conn, status.http_status, Jason.encode!(status.body))
  end

  get "/metrics" do
    metrics = Singularity.PrometheusExporter.render()
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
      "claude" -> create_claude_provider(model)
      "codex" -> create_codex_provider(model)
      "gemini" -> create_gemini_provider(model)
      "cursor-agent" -> create_cursor_agent_provider(model)
      "copilot" -> create_copilot_provider(model)
      _ -> {:error, :provider_missing}
    end
  end

  defp create_claude_provider(model) do
    {:ok,
     fn messages, payload ->
       case Singularity.Integration.Claude.chat(messages, model: model, metadata: payload) do
         {:ok, %{raw: raw, response: response}} ->
           {:ok, format_openai_response(model, response || raw)}

         {:ok, raw} when is_map(raw) ->
           {:ok, format_openai_response(model, Jason.encode!(raw))}

         {:error, reason} ->
           {:error, {:provider_error, reason}}
       end
     end}
  end

  defp create_codex_provider(model) do
    {:ok,
     fn messages, _payload ->
       prompt = render_prompt(messages)

       case Singularity.Integration.Codex.chat(prompt, model: model) do
         {:ok, text} -> {:ok, format_openai_response(model, text)}
         {:error, reason} -> {:error, {:provider_error, reason}}
       end
     end}
  end

  defp create_gemini_provider(model) do
    {:ok,
     fn messages, payload ->
       case Singularity.Integration.Gemini.chat(messages, payload) do
         {:ok, text} -> {:ok, format_openai_response(model, text)}
         {:error, reason} -> {:error, {:provider_error, reason}}
       end
     end}
  end

  defp create_cursor_agent_provider(model) do
    {:ok,
     fn messages, _payload ->
       prompt = render_prompt(messages)

       case Singularity.Integration.LlmProviders.CursorLlmProvider.chat(prompt) do
         {:ok, text} -> {:ok, format_openai_response(model, text)}
         {:error, reason} -> {:error, {:provider_error, reason}}
       end
     end}
  end

  defp create_copilot_provider(model) do
    {:ok,
     fn messages, _payload ->
       prompt = render_prompt(messages)

       case Singularity.Integration.Copilot.chat(prompt) do
         {:ok, text} -> {:ok, format_openai_response(model, text)}
         {:error, reason} -> {:error, {:provider_error, reason}}
       end
     end}
  end

  defp default_provider do
    Application.get_env(:singularity, :lvm_gateway)[:default_provider] || "claude"
  end

  defp render_prompt(messages) do
    Enum.map_join(messages, "\n\n", fn
      %{"role" => role, "content" => content} ->
        "#{role}: #{content_to_string(content)}"

      %{} ->
        ""
    end)
  end

  defp content_to_string(content) when is_binary(content), do: content

  defp content_to_string(content) when is_list(content),
    do: Enum.map_join(content, "\n", &content_to_string/1)

  defp content_to_string(%{"text" => text}), do: text
  defp content_to_string(_), do: ""

  defp format_openai_response(model, text) do
    token_count = rough_token_estimate(text)

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
        # Use a rough token estimate (~4 bytes per token). For accurate
        # accounting, replace with a real tokenizer for the deployed model.
        prompt_tokens: token_count,
        completion_tokens: token_count,
        total_tokens: token_count * 2
      }
    }
  end

  defp rough_token_estimate(text) when is_binary(text) do
    bytes = byte_size(text)

    if bytes == 0 do
      0
    else
      div(bytes + 3, 4)
    end
  end

  defp rough_token_estimate(_), do: 0

  defp decode_json(body) do
    case Jason.decode(body) do
      {:ok, params} when is_map(params) -> {:ok, params}
      {:ok, _} -> {:error, :bad_request, "Request body must be a JSON object"}
      {:error, reason} -> {:error, :bad_request, Exception.message(reason)}
    end
  end

  @provider_map %{
    "claude_cli" => :claude_cli,
    "claude_http" => :claude_http,
    "gemini_cli" => :gemini_cli,
    "gemini_http" => :gemini_http
  }

  defp normalize_tool_provider(provider) when is_binary(provider) do
    case Map.get(@provider_map, provider) do
      nil -> {:ok, provider}
      atom -> {:ok, atom}
    end
  end

  defp normalize_tool_provider(provider) when is_atom(provider), do: {:ok, provider}
  defp normalize_tool_provider(_), do: {:error, :bad_request, "Invalid provider"}

  defp fetch_tool_name(%{"tool" => name}) when is_binary(name) and byte_size(name) > 0,
    do: {:ok, name}

  defp fetch_tool_name(_), do: {:error, :bad_request, "Missing tool name"}

  defp fetch_arguments(%{"arguments" => args}) when is_map(args), do: {:ok, args}
  defp fetch_arguments(%{"arguments" => nil}), do: {:ok, %{}}
  defp fetch_arguments(_), do: {:ok, %{}}

  defp build_tool_call(tool_name, call_id, arguments) do
    payload = %{
      status: :complete,
      type: :function,
      call_id: call_id || tool_name,
      name: tool_name,
      arguments: Jason.encode!(arguments)
    }

    {:ok, ToolCall.new!(payload)}
  rescue
    ArgumentError -> {:error, :bad_request, "Invalid tool payload"}
  end

  defp serialize_result(result) do
    %{
      content: result.content,
      processed_content: result.processed_content,
      display_text: result.display_text,
      is_error: result.is_error
    }
  end
end
