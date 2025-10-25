defmodule Singularity.Tools.Runner do
  @moduledoc """
  Executes registered tools and normalizes responses into ToolResult structs.
  """

  alias Singularity.Tools.{Basic, Default}
  alias Singularity.Schemas.Tools.{Tool, ToolCall, ToolResult}

  @provider_aliases %{
    "claude_cli" => :claude_cli,
    "claude_http" => :claude_http,
    "gemini_code_cli" => :gemini_code_cli,
    "gemini_code_api" => :gemini_code_api,
    # Legacy aliases (deprecated)
    "gemini_cli" => :gemini_code_cli,
    "gemini_http" => :gemini_code_api
  }

  @type context :: map()

  @spec execute(String.t() | atom(), ToolCall.t(), context()) ::
          {:ok, ToolResult.t()} | {:error, String.t()}
  def execute(provider, %ToolCall{} = call, context \\ %{}) do
    provider = normalize_provider(provider)

    Default.ensure_registered()
    Basic.ensure_registered()

    case Singularity.Tools.Catalog.get_tool(provider, call.name) do
      {:ok, tool} -> do_execute(tool, call, context)
      :error -> {:error, "Tool #{call.name} is not registered for #{provider}"}
    end
  end

  defp do_execute(%Tool{} = tool, %ToolCall{} = call, context) do
    arguments = call.arguments || %{}

    context_with_tool = Map.put(context, :tool, tool)

    case Tool.execute(tool, arguments, context_with_tool) do
      {:ok, content, processed} ->
        {normalized, processed_content} = normalize_content(content, processed)
        build_result(tool, call, normalized, processed_content)

      {:ok, content} ->
        {normalized, processed_content} = normalize_content(content, nil)
        build_result(tool, call, normalized, processed_content)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_result(tool, call, content, processed) do
    attrs = %{
      type: :function,
      tool_call_id: call.call_id || tool.name,
      name: tool.name,
      content: content,
      processed_content: processed
    }

    {:ok, ToolResult.new!(attrs)}
  rescue
    ArgumentError -> {:error, "Failed to build tool result"}
  end

  defp normalize_content(content, processed) when is_binary(content), do: {content, processed}

  defp normalize_content(content, processed) do
    case Jason.encode(content) do
      {:ok, json} -> {json, processed || content}
      {:error, _} -> {inspect(content), processed || content}
    end
  end

  defp normalize_provider(provider) when is_atom(provider), do: provider

  defp normalize_provider(provider) when is_binary(provider),
    do: Map.get(@provider_aliases, provider, provider)

  defp normalize_provider(other), do: other
end
