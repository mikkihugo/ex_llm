defmodule SeedAgent.DynamicCompiler do
  @moduledoc """
  Validates and loads dynamically generated Elixir modules for self-improving
  agents. Modules are expected to define at least a `respond/1` function.
  """

  require Logger

  @spec validate(String.t()) :: :ok | {:error, term()}
  def validate(source) when is_binary(source) do
    trimmed = String.trim(source)

    cond do
      trimmed == "" -> {:error, :empty_source}
      byte_size(trimmed) > 500_000 -> {:error, :source_too_large}
      true -> ensure_parsable(trimmed)
    end
  end

  def validate(_), do: {:error, :invalid_source}

  @spec compile_file(Path.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def compile_file(path) do
    with {:ok, source} <- File.read(path),
         {:ok, modules} <- compile(path, source) do
      version = version_stamp()
      Logger.info("Dynamic module loaded", modules: modules, version: version)
      {:ok, version}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  ## Internal helpers

  defp ensure_parsable(source) do
    case Code.string_to_quoted(source) do
      {:ok, ast} -> ensure_respond(ast)
      {:error, {line, error, token}} -> {:error, {:syntax_error, line, error, token}}
    end
  rescue
    error -> {:error, error}
  end

  defp ensure_respond(ast) do
    {_ast, found?} =
      Macro.prewalk(ast, false, fn
        {:def, _, [{:respond, _, _args}, _]} = node, _ -> {node, true}
        node, acc -> {node, acc}
      end)

    case found? do
      true -> :ok
      false -> {:error, :respond_function_missing}
    end
  end

  defp compile(path, source) do
    case Code.string_to_quoted(source) do
      {:ok, ast} ->
        modules = collect_modules(ast)
        Enum.each(modules, &purge_module/1)

        try do
          result = Code.compile_string(source, path)
          {:ok, Enum.map(result, fn {mod, _bin} -> mod end)}
        rescue
          error -> {:error, {:compile_failed, error}}
        end

      {:error, reason} -> {:error, reason}
    end
  end

  defp collect_modules(ast) do
    {_ast, modules} =
      Macro.postwalk(ast, [], fn
        {:defmodule, _, [{:__aliases__, _, names}, _]} = node, acc ->
          module = Module.concat(names)
          {node, [module | acc]}

        node, acc ->
          {node, acc}
      end)

    modules
  end

  defp purge_module(module) do
    :code.purge(module)
    :code.delete(module)
  end

  defp version_stamp do
    System.system_time(:millisecond)
  end
end
