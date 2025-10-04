defmodule SeedAgent.Tools.Registry do
  @moduledoc """
  Stores tool definitions per provider using :persistent_term.
  """

  @prefix {:seed_agent, :tools}

  @spec register_tool(term(), any()) :: :ok
  def register_tool(provider, tool) do
    update(provider, fn tools -> Map.put(tools, tool.name, tool) end)
  end

  @spec register_tools(term(), Enumerable.t()) :: :ok
  def register_tools(provider, tools) do
    update(provider, fn existing -> Enum.reduce(tools, existing, &Map.put(&2, &1.name, &1)) end)
  end

  @spec fetch_tool(term(), String.t()) :: {:ok, any()} | :error
  def fetch_tool(provider, name) do
    case get_tools(provider) do
      %{^name => tool} -> {:ok, tool}
      _ -> :error
    end
  end

  @spec list_tools(term()) :: [any()]
  def list_tools(provider) do
    get_tools(provider) |> Map.values()
  end

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
