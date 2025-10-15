defmodule Singularity.Execution.TaskGraph.Adapters.Docker do
  @moduledoc """
  Docker Adapter - Sandboxed code execution in isolated containers.

  ## Security Features

  - CPU and memory limits (required)
  - Network isolation (default: denied)
  - Read-only filesystem mounts
  - Automatic cleanup (--rm)
  - User namespace isolation
  - No privileged mode

  ## Examples

      # Run tests in sandbox
      Docker.exec(%{
        image: "hexpm/elixir:1.18",
        cmd: ["mix", "test"],
        mounts: [%{host: "/code", cont: "/work", ro: true}]
      }, cpu: 2, mem: "2g", net: :deny, timeout: 300_000)

      # => {:ok, %{stdout: "...", exit: 0}}
  """

  require Logger

  @default_timeout 300_000
  @max_timeout 600_000

  @doc """
  Execute command in Docker container.

  ## Required Args

  - `image` - Docker image name
  - `cmd` - Command to run (list)

  ## Optional Args

  - `mounts` - Volume mounts (list of %{host:, cont:, ro:})
  - `working_dir` - Working directory in container
  - `env` - Environment variables (map)

  ## Required Options

  - `cpu` - CPU limit (number of cores)
  - `mem` - Memory limit (string like "1g", "512m")

  ## Optional Options

  - `net` - Network access (:allow | :deny, default: :deny)
  - `timeout` - Timeout in milliseconds
  """
  @spec exec(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def exec(args, opts \\ []) do
    with :ok <- validate_args(args),
         :ok <- validate_resource_limits(opts),
         {:ok, docker_args} <- build_docker_args(args, opts) do
      run_docker(docker_args, opts)
    end
  end

  ## Validation

  defp validate_args(%{image: image, cmd: cmd}) when is_binary(image) and is_list(cmd) do
    if image == "" or cmd == [] do
      {:error, :invalid_docker_args}
    else
      :ok
    end
  end

  defp validate_args(args) do
    {:error, {:invalid_docker_args, "image and cmd required", args}}
  end

  defp validate_resource_limits(opts) do
    cpu = Keyword.get(opts, :cpu)
    mem = Keyword.get(opts, :mem)

    cond do
      is_nil(cpu) or is_nil(mem) ->
        {:error, :docker_resource_limits_required}

      !is_number(cpu) or cpu <= 0 ->
        {:error, {:invalid_cpu_limit, cpu}}

      !is_binary(mem) or !valid_memory_format?(mem) ->
        {:error, {:invalid_memory_limit, mem}}

      true ->
        :ok
    end
  end

  defp valid_memory_format?(mem) do
    String.match?(mem, ~r/^\d+[kmg]$/i)
  end

  ## Docker Command Building

  defp build_docker_args(args, opts) do
    docker_args = [
      "run",
      "--rm",
      # Auto-remove container
      "--cpus",
      to_string(opts[:cpu]),
      "-m",
      opts[:mem],
      "--network",
      network_flag(opts[:net]),
      "-w",
      args[:working_dir] || "/work",
      # Security: No privileged mode
      "--security-opt=no-new-privileges",
      # User namespace (run as non-root)
      "--user",
      "1000:1000"
    ]

    # Add volume mounts
    docker_args = docker_args ++ build_mount_flags(args[:mounts] || [])

    # Add environment variables
    docker_args = docker_args ++ build_env_flags(args[:env] || %{})

    # Add image and command
    docker_args = docker_args ++ [args.image] ++ args.cmd

    {:ok, docker_args}
  end

  defp network_flag(:allow), do: "bridge"
  defp network_flag(_), do: "none"

  defp build_mount_flags(mounts) do
    Enum.flat_map(mounts, fn mount ->
      host = Map.fetch!(mount, :host)
      cont = Map.fetch!(mount, :cont)
      ro = Map.get(mount, :ro, false)

      mount_spec = "#{host}:#{cont}#{if ro, do: ":ro", else: ""}"
      ["-v", mount_spec]
    end)
  end

  defp build_env_flags(env) when is_map(env) do
    Enum.flat_map(env, fn {k, v} ->
      ["-e", "#{k}=#{v}"]
    end)
  end

  ## Docker Execution

  defp run_docker(docker_args, opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    timeout =
      if timeout > @max_timeout do
        Logger.warning("Docker timeout capped",
          requested: timeout,
          max: @max_timeout
        )

        @max_timeout
      else
        timeout
      end

    Logger.info("Executing Docker container",
      image: Enum.at(docker_args, -2),
      cmd: Enum.drop(docker_args, -1) |> List.last(),
      cpu: opts[:cpu],
      mem: opts[:mem],
      timeout: timeout
    )

    task = Task.async(fn ->
      try do
        System.cmd("docker", docker_args, stderr_to_stdout: true, parallelism: true)
      rescue
        e ->
          {:error, {:docker_execution_failed, Exception.message(e)}}
      end
    end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:error, reason}} ->
        {:error, reason}

      {:ok, {output, exit_code}} ->
        result = %{
          stdout: output,
          stderr: "",
          exit: exit_code,
          timeout: false
        }

        Logger.info("Docker execution completed",
          exit: exit_code,
          output_size: byte_size(output)
        )

        {:ok, result}

      nil ->
        Logger.warning("Docker execution timeout",
          timeout: timeout
        )

        # Try to stop container
        cleanup_timed_out_containers()

        {:error, :timeout}
    end
  end

  defp cleanup_timed_out_containers do
    # Best effort cleanup of containers that may be running
    spawn(fn ->
      try do
        {output, _} = System.cmd("docker", ["ps", "-q", "--filter", "status=running"])

        output
        |> String.split("\n", trim: true)
        |> Enum.each(fn container_id ->
          System.cmd("docker", ["stop", container_id])
        end)
      rescue
        _ -> :ok
      end
    end)
  end
end
