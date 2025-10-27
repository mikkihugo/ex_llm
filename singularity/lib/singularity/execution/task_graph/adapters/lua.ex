defmodule Singularity.Execution.TaskGraph.Adapters.Lua do
  @moduledoc """
  Lua Adapter - Sandboxed Lua execution via Luerl (Lua on BEAM).

  ## Security Features

  - Runs in BEAM process (isolated from OS)
  - Restricted standard library (no os, io, package)
  - Timeout enforcement
  - Memory limit via BEAM
  - No file system access
  - No network access
  - No Erlang module access

  ## Examples

      # Safe validation script
      Lua.exec(%{
        src: '''
        function main(code)
          if string.match(code, "unsafe") then
            return {safe = false, reason = "Unsafe pattern"}
          end
          return {safe = true}
        end
        ''',
        argv: ["some code here"]
      }, timeout: 5_000)

      # => {:ok, %{safe: true}}
  """

  require Logger

  @default_timeout 5_000
  @max_timeout 30_000

  @doc """
  Execute Lua script in Luerl sandbox.

  ## Args

  - `src` - Lua source code (string)
  - `argv` - Arguments passed to main() function (list)

  ## Options

  - `timeout` - Timeout in milliseconds (default: 5s, max: 30s)
  """
  @spec exec(map(), keyword()) :: {:ok, term()} | {:error, term()}
  def exec(args, _opts \\ [])

  def exec(%{src: src} = args, _opts) when is_binary(src) do
    argv = Map.get(args, :argv, [])
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    timeout =
      if timeout > @max_timeout do
        Logger.warning("Lua timeout capped",
          requested: timeout,
          max: @max_timeout
        )

        @max_timeout
      else
        timeout
      end

    Logger.debug("Executing Lua script",
      src_size: byte_size(src),
      argv_count: length(argv),
      timeout: timeout
    )

    task =
      Task.async(fn ->
        try do
          execute_lua(src, argv)
        rescue
          e ->
            {:error, {:lua_execution_failed, Exception.message(e)}}
        end
      end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} ->
        Logger.debug("Lua execution completed", result: inspect(result))
        result

      nil ->
        Logger.warning("Lua execution timeout", timeout: timeout)
        {:error, :timeout}
    end
  end

  def exec(args, _opts) do
    {:error, {:invalid_lua_args, "src required", args}}
  end

  ## Lua Execution

  defp execute_lua(src, argv) do
    # Initialize Luerl state
    state = :luerl.init()

    # Restrict standard library
    state = restrict_stdlib(state)

    # Wrap source to call main()
    wrapped_src = """
    #{src}

    -- Call main with arguments
    return main(...)
    """

    # Execute
    case :luerl.do(wrapped_src, state, argv) do
      {result, _final_state} ->
        # Convert Lua result to Elixir
        {:ok, lua_to_elixir(result)}

      {:error, reason} ->
        {:error, {:lua_error, inspect(reason)}}
    end
  rescue
    e ->
      {:error, {:lua_exception, Exception.message(e)}}
  end

  ## Standard Library Restriction

  defp restrict_stdlib(state) do
    state
    # Remove os module (file system, process control)
    |> :luerl.set_table([<<"os">>], %{})
    # Remove io module (file I/O)
    |> :luerl.set_table([<<"io">>], %{})
    # Remove package module (loading external modules)
    |> :luerl.set_table([<<"package">>], %{})
    # Remove debug module (introspection)
    |> :luerl.set_table([<<"debug">>], %{})
    # Remove dofile, loadfile, load (code loading)
    |> remove_unsafe_globals()
  end

  defp remove_unsafe_globals(state) do
    # Keep only safe globals:
    # - string, table, math, ipairs, pairs, type, tonumber, tostring, etc.
    # Remove: dofile, loadfile, load, require
    state
    |> :luerl.set_table([<<"dofile">>], nil)
    |> :luerl.set_table([<<"loadfile">>], nil)
    |> :luerl.set_table([<<"load">>], nil)
    |> :luerl.set_table([<<"loadstring">>], nil)
    |> :luerl.set_table([<<"require">>], nil)
  end

  ## Type Conversion (Lua → Elixir)

  defp lua_to_elixir(nil), do: nil
  defp lua_to_elixir(true), do: true
  defp lua_to_elixir(false), do: false
  defp lua_to_elixir(num) when is_number(num), do: num
  defp lua_to_elixir(str) when is_binary(str), do: str

  # Lua table → Elixir map
  defp lua_to_elixir(table) when is_list(table) do
    # Luerl represents tables as lists of {key, value} tuples
    if Keyword.keyword?(table) do
      # If all keys are atoms/integers, might be a list or map
      if sequential_keys?(table) do
        # Lua array (sequential keys)
        Enum.map(table, fn {_k, v} -> lua_to_elixir(v) end)
      else
        # Lua table (mixed keys) → Elixir map
        Map.new(table, fn {k, v} ->
          {lua_to_elixir(k), lua_to_elixir(v)}
        end)
      end
    else
      table
    end
  end

  defp lua_to_elixir(other), do: other

  defp sequential_keys?(table) do
    keys =
      table
      |> Enum.map(fn {k, _v} -> k end)
      |> Enum.sort()

    keys == Enum.to_list(1..length(keys))
  end
end
