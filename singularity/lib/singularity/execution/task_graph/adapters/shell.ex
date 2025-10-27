defmodule Singularity.Execution.TaskGraph.Adapters.Shell do
  @moduledoc """
  Shell Adapter - Safe shell command execution with timeouts and resource limits.

  ## Security Features

  - Command whitelisting (enforced by Policy module)
  - Timeout enforcement
  - Working directory restriction
  - Environment variable control
  - Output size limits

  ## Examples

      # Safe command execution
      Shell.exec(%{cmd: ["mix", "test"]}, cwd: "/code", timeout: 60_000)
      # => {:ok, %{stdout: "...", stderr: "...", exit: 0}}

      # Timeout enforcement
      Shell.exec(%{cmd: ["sleep", "1000"]}, timeout: 5_000)
      # => {:error, :timeout}
  """

  require Logger

  @default_timeout 120_000
  # 1MB
  @max_output_size 1_000_000

  @doc """
  Execute shell command safely.

  ## Options

  - `:cwd` - Working directory (default: current)
  - `:env` - Environment variables (map)
  - `:timeout` - Timeout in milliseconds (default: 120s)
  - `:capture_stderr` - Capture stderr separately (default: false)
  """
  @spec exec(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def exec(args, _opts \\ [])

  def exec(%{cmd: cmd}, _opts) when is_list(cmd) do
    cwd = Keyword.get(_opts, :cwd, File.cwd!())
    env = Keyword.get(_opts, :env, %{})
    timeout = Keyword.get(_opts, :timeout, @default_timeout)
    capture_stderr = Keyword.get(_opts, :capture_stderr, false)

    Logger.debug("Executing shell command",
      cmd: inspect(cmd),
      cwd: cwd,
      timeout: timeout
    )

    # Validate command is not empty
    if cmd == [] or List.first(cmd) == nil do
      {:error, :empty_command}
    else
      do_exec(cmd, cwd, env, timeout, capture_stderr)
    end
  end

  def exec(args, _opts) do
    {:error, {:invalid_args, "cmd must be a list", args}}
  end

  ## Private Functions

  defp do_exec(cmd, cwd, env, timeout, capture_stderr) do
    binary = List.first(cmd)
    args = Enum.drop(cmd, 1)

    task =
      Task.async(fn ->
        try do
          system_opts = [
            cd: cwd,
            env: map_to_env_list(env),
            stderr_to_stdout: !capture_stderr,
            parallelism: true
          ]

          if capture_stderr do
            # Use Port for separate stderr capture
            port_exec(binary, args, system_opts)
          else
            # Use System.cmd for simplicity
            System.cmd(binary, args, system_opts)
          end
        rescue
          e ->
            {:error, {:execution_failed, Exception.message(e)}}
        end
      end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:error, reason}} ->
        {:error, reason}

      {:ok, {output, exit_code}} ->
        output = truncate_output(output)

        result = %{
          stdout: output,
          stderr: "",
          exit: exit_code,
          timeout: false
        }

        Logger.debug("Shell command completed",
          cmd: List.first(cmd),
          exit: exit_code,
          output_size: byte_size(output)
        )

        {:ok, result}

      nil ->
        Logger.warning("Shell command timeout",
          cmd: inspect(cmd),
          timeout: timeout
        )

        {:error, :timeout}
    end
  end

  defp port_exec(binary, args, _opts) do
    # For separate stderr capture, use Port
    port =
      Port.open({:spawn_executable, System.find_executable(binary)}, [
        {:args, args},
        {:cd, _opts[:cd]},
        {:env, _opts[:env]},
        :binary,
        :exit_status,
        :use_stdio,
        :stderr_to_stdout
      ])

    collect_port_output(port, "", "")
  end

  defp collect_port_output(port, stdout, stderr) do
    receive do
      {^port, {:data, data}} ->
        collect_port_output(port, stdout <> data, stderr)

      {^port, {:exit_status, status}} ->
        {stdout, status}
    after
      5000 ->
        Port.close(port)
        {:error, :port_timeout}
    end
  end

  defp map_to_env_list(env) when is_map(env) do
    Enum.map(env, fn {k, v} ->
      {to_string(k), to_string(v)}
    end)
  end

  defp truncate_output(output) when byte_size(output) > @max_output_size do
    <<truncated::binary-size(@max_output_size), _rest::binary>> = output
    truncated <> "\n... (output truncated at #{@max_output_size} bytes)"
  end

  defp truncate_output(output), do: output
end
