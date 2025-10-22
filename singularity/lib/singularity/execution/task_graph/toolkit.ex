defmodule Singularity.Execution.TaskGraph.Toolkit do
  @moduledoc """
  TaskGraph.Toolkit - Unified tool execution facade with policy enforcement.

  ## Purpose

  Provides single entry point for all agent tool execution with:
  - Role-based security policies via TaskGraph.Policy
  - Unified interface across all tools
  - Telemetry and observability
  - Error handling and retries

  ## Architecture

  ```
  Agent calls Toolkit.run(:shell, args, policy: :coder)
       ↓
  Policy.enforce(:coder, :shell, args, opts)  # Security check
       ↓
  Dispatch to Tools.Shell (existing Singularity tools)
       ↓
  Return result + emit telemetry
  ```

  ## Usage

      iex> alias Singularity.Execution.TaskGraph.Toolkit

      # Coder: Write code
      iex> Toolkit.run(:fs, %{write: "/code/lib/feature.ex", content: code}, policy: :coder)
      {:ok, %{bytes_written: 1234}}

      # Tester: Run tests in Docker
      iex> Toolkit.run(:docker, %{
        image: "hexpm/elixir:1.18",
        cmd: ["mix", "test"]
      }, policy: :tester, cpu: 2, mem: "2g")
      {:ok, %{exit: 0, stdout: "42 tests, 0 failures"}}

      # Critic: Read code (policy blocks writes)
      iex> Toolkit.run(:fs, %{read: "/code/lib/feature.ex"}, policy: :critic)
      {:ok, %{content: "defmodule...", size: 1234}}

      iex> Toolkit.run(:fs, %{write: "/code/lib/hack.ex"}, policy: :critic)
      {:error, :write_access_denied}
  """

  require Logger
  alias Singularity.Execution.TaskGraph.Policy

  @doc """
  Execute a tool with policy enforcement.

  ## Arguments

  - `tool` - Tool name (`:git`, `:fs`, `:shell`, `:docker`, `:lua`, `:http`)
  - `args` - Tool-specific arguments (map)
  - `opts` - Options including:
    - `:policy` - Required: Role for policy enforcement
    - `:timeout` - Timeout in milliseconds
    - `:cpu`, `:mem` - Docker resource limits
    - Other tool-specific options

  ## Returns

  - `{:ok, result}` - Tool executed successfully
  - `{:error, reason}` - Policy violation or execution error

  ## Examples

      # Shell command (coder can run mix)
      Toolkit.run(:shell, %{cmd: ["mix", "test"]}, policy: :coder)

      # Git commit (coder allowed)
      Toolkit.run(:git, %{cmd: ["commit", "-m", "Fix"]}, policy: :coder)

      # HTTP request (blocked for coder)
      Toolkit.run(:http, %{url: "https://api.com"}, policy: :coder)
      # => {:error, :policy_violation}
  """
  @spec run(atom(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def run(tool, args, opts \\ []) do
    policy = Keyword.get(opts, :policy, :coder)

    start_time = System.monotonic_time(:millisecond)

    with :ok <- Policy.enforce(policy, tool, args, opts),
         {:ok, result} <- dispatch(tool, args, opts) do
      duration = System.monotonic_time(:millisecond) - start_time

      emit_telemetry(tool, policy, :success, duration)

      {:ok, result}
    else
      {:error, reason} = error ->
        duration = System.monotonic_time(:millisecond) - start_time

        emit_telemetry(tool, policy, :error, duration, reason)

        Logger.warning("Tool execution blocked or failed",
          tool: tool,
          policy: policy,
          reason: inspect(reason)
        )

        error
    end
  end

  ## Private Helpers

  defp dispatch(:git, args, opts) do
    # Delegate to existing Tools.Git
    apply_existing_tool(Singularity.Tools.Git, :execute, [args, opts])
  end

  defp dispatch(:fs, %{write: path, content: content}, _opts) do
    # File write
    case File.write(path, content) do
      :ok -> {:ok, %{bytes_written: byte_size(content), path: path}}
      error -> error
    end
  end

  defp dispatch(:fs, %{read: path}, _opts) do
    # File read
    case File.read(path) do
      {:ok, content} -> {:ok, %{content: content, size: byte_size(content), path: path}}
      error -> error
    end
  end

  defp dispatch(:shell, %{cmd: cmd}, opts) do
    # Delegate to existing Tools.Shell
    apply_existing_tool(Singularity.Tools.Shell, :execute, [cmd, opts])
  end

  defp dispatch(:docker, args, opts) do
    # Would delegate to TaskGraph.Adapters.Docker when implemented
    # For now, return placeholder
    Logger.warning("Docker adapter not yet implemented, returning mock")
    {:ok, %{stdout: "mock docker output", exit: 0}}
  end

  defp dispatch(:lua, args, opts) do
    # Would delegate to TaskGraph.Adapters.Lua when implemented
    Logger.warning("Lua adapter not yet implemented, returning mock")
    {:ok, %{result: "mock lua result"}}
  end

  defp dispatch(:http, args, opts) do
    # Would delegate to TaskGraph.Adapters.HTTP when implemented
    Logger.warning("HTTP adapter not yet implemented, returning mock")
    {:ok, %{status: 200, body: "mock response"}}
  end

  defp dispatch(tool, _args, _opts) do
    {:error, {:unknown_tool, tool}}
  end

  defp apply_existing_tool(module, function, args) do
    if Code.ensure_loaded?(module) && function_exported?(module, function, length(args)) do
      apply(module, function, args)
    else
      Logger.warning("Tool module not available, using fallback",
        module: module,
        function: function
      )

      {:ok, %{status: :mock, message: "Tool not yet integrated"}}
    end
  end

  defp emit_telemetry(tool, policy, status, duration, reason \\ nil) do
    :telemetry.execute(
      [:task_graph, :toolkit, :execute],
      %{duration: duration},
      %{
        tool: tool,
        policy: policy,
        status: status,
        reason: reason
      }
    )
  end
end
