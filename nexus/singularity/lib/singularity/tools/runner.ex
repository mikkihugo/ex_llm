defmodule Singularity.Tools.Runner do
  @moduledoc """
  Executes registered tools and normalizes responses into ToolResult structs.

  Provider selection uses models and complexity from:
  1. Database (via sync from CentralCloud/Nexus)
  2. Pgflow (if not in database)
  """

  alias Singularity.Schemas.Tools.{Tool, ToolCall, ToolResult}
  alias Singularity.Repo
  import Ecto.Query

  @doc """
  Get provider alias based on provider name string.

  Maps provider name strings to normalized atoms, handling compatibility variants.
  """
  def get_provider_alias(provider) when is_binary(provider) do
    provider_aliases().(provider)
  end

  def get_provider_alias(provider) when is_atom(provider), do: provider
  def get_provider_alias(other), do: other

  alias Singularity.LLM.Config

  @doc """
  Get task complexity for provider selection.

  Delegates to system-wide LLM.Config.
  """
  def get_task_complexity(provider, context \\ %{}) do
    Config.get_task_complexity(provider, context)
  end

  @doc """
  Get models for provider selection.

  Delegates to system-wide LLM.Config.
  """
  def get_models(provider, context \\ %{}) do
    Config.get_models(provider, context)
  end

  # Provider alias mapping based on task complexity and provider variants
  defp provider_aliases do
    fn
      "claude_cli" -> :claude_cli
      "claude_http" -> :claude_http
      "gemini" -> :gemini
      "copilot" -> :copilot
      # Compatibility aliases for gemini provider variants
      "gemini_code_cli" -> :gemini
      "gemini_code_api" -> :gemini
      "gemini_cli" -> :gemini
      "gemini_http" -> :gemini
      other -> other
    end
  end

  @type context :: map()

  @spec execute(String.t() | atom(), ToolCall.t(), context()) ::
          {:ok, ToolResult.t()} | {:error, String.t()}
  def execute(provider, %ToolCall{} = call, context \\ %{}) do
    provider = normalize_provider(provider)

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

  defp normalize_provider(provider), do: get_provider_alias(provider)
end
