defmodule Singularity.Tools.Catalog do
  @moduledoc """
  Tool catalog - manages available tools per provider using :persistent_term.

  In agentic systems, this is the central catalog where tools are registered,
  discovered, and retrieved by agents and interfaces.
  """

  @prefix {:singularity, :tools}

  @spec add_tool(term(), any()) :: :ok
  def add_tool(provider, tool) do
    update(provider, fn tools -> Map.put(tools, tool.name, tool) end)
  end

  @spec add_tools(term(), Enumerable.t()) :: :ok
  def add_tools(provider, tools) do
    update(provider, fn existing -> Enum.reduce(tools, existing, &Map.put(&2, &1.name, &1)) end)
  end

  # Legacy aliases for backward compatibility
  defdelegate add_tool(provider, tool), to: __MODULE__, as: :add_tool
  defdelegate add_tools(provider, tools), to: __MODULE__, as: :add_tools

  @spec get_tool(term(), String.t()) :: {:ok, any()} | :error
  def get_tool(provider, name) do
    case get_tools(provider) do
      %{^name => tool} -> {:ok, tool}
      _ -> :error
    end
  end

  @spec list_tools(term()) :: [any()]
  def list_tools(provider) do
    get_tools(provider) |> Map.values()
  end

  # Legacy aliases for backward compatibility
  defdelegate get_tool(provider, name), to: __MODULE__, as: :get_tool

  @spec clear(term()) :: :ok
  def clear(provider) do
    :persistent_term.erase(key(provider))
    :ok
  end

  defp update(provider, fun) do
    key = key(provider)
    existing = :persistent_term.get(key, %{})
    :persistent_term.put(key, fun.(existing))
    :ok
  end

  defp get_tools(provider) do
    :persistent_term.get(key(provider), %{})
  end

  defp key(provider), do: {@prefix, provider}
end
