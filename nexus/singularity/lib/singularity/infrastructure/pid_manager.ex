defmodule Singularity.Infrastructure.PidManager do
  @moduledoc """
  Smart PID Management for local services (PostgreSQL, Phoenix endpoint, PGFlow workers).

  This is the PGFlow-era port of our legacy PID manager. The implementation keeps the
  original adoption/kill pattern but updates the documentation to reflect that PGFlow
  orchestration now rides on top of PostgreSQL rather than NATS.

  ## Typical Workflow

  ```elixir
  case Singularity.Infrastructure.PidManager.manage_service(:postgres, 5432) do
    {:adopted, pid} -> Logger.info("✅ PostgreSQL already healthy (pid=" <> inspect(pid) <> ")")
    {:killed_stale, old_pid} -> Logger.info("♻️ Restarting postgres after killing " <> inspect(old_pid))
    {:ready_to_start} -> Logger.info("🚀 Starting postgres from scratch")
  end
  ```

  The helper offers three key behaviours:

    * Detect whether a port is bound and whether the owning process responds to
      a protocol-specific health check.
    * Attempt smart adoption of running services so local workflows do not reboot
      them unnecessarily.
    * Provide convenience helpers for killing stale processes when health checks fail.
  """

  require Logger

  @type service :: :postgres | :pgflow_notify | :phoenix
  @type health_status :: {:healthy, integer()} | {:stale, integer()} | {:not_running}

  @doc """
  Check if a service is running and healthy.
  """
  @spec check_service(service(), port :: integer(), timeout :: integer()) :: health_status()
  def check_service(service, port, timeout \\ 1_000) do
    case find_pid_for_port(port) do
      {:ok, pid} ->
        if process_healthy?(service, port, timeout) do
          {:healthy, pid}
        else
          {:stale, pid}
        end

      {:error, :not_bound} ->
        {:not_running}
    end
  end

  @doc """
  Locate the PID bound to a TCP port using `ss`.
  """
  @spec find_pid_for_port(integer()) :: {:ok, integer()} | {:error, :not_bound}
  def find_pid_for_port(port) when is_integer(port) do
    output = :os.cmd(~c"ss -tlnp 2>/dev/null | grep ':#{port} '") |> List.to_string()

    case Regex.run(~r/pid=(\d+)/, output) do
      [_, pid] -> {:ok, String.to_integer(pid)}
      _ -> {:error, :not_bound}
    end
  end

  @doc """
  Health check dispatcher that understands PostgreSQL, Phoenix, and PGFlow NOTIFY listeners.
  """
  @spec process_healthy?(service(), integer(), integer()) :: boolean()
  def process_healthy?(service, port, timeout) do
    case service do
      :postgres -> postgres_healthy?(port, timeout)
      :pgflow_notify -> pg_notify_healthy?(port, timeout)
      :phoenix -> phoenix_healthy?(port, timeout)
      _ -> tcp_healthy?(port, timeout)
    end
  end

  defp postgres_healthy?(port, timeout) do
    case :gen_tcp.connect(~c"127.0.0.1", port, [], timeout) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true

      {:error, _reason} ->
        false
    end
  end

  defp pg_notify_healthy?(port, timeout) do
    case :gen_tcp.connect(~c"127.0.0.1", port, [], timeout) do
      {:ok, socket} ->
        case :gen_tcp.recv(socket, 0, timeout) do
          {:ok, data} ->
            :gen_tcp.close(socket)
            String.contains?(List.to_string(data), "PG")

          {:error, _} ->
            :gen_tcp.close(socket)
            false
        end

      {:error, _reason} ->
        false
    end
  end

  defp phoenix_healthy?(port, timeout) do
    url = ~c"http://127.0.0.1:#{port}/health"

    try do
      case :httpc.request(:get, {url, []}, [{:timeout, timeout}], []) do
        {:ok, {{_, 200, _}, _headers, _body}} -> true
        _ -> false
      end
    rescue
      _ -> false
    end
  end

  defp tcp_healthy?(port, timeout) do
    case :gen_tcp.connect(~c"127.0.0.1", port, [], timeout) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true

      {:error, _reason} ->
        false
    end
  end

  @doc """
  Kill a stale/zombie process gracefully, then forcefully if required.
  """
  @spec kill_stale(integer()) :: boolean()
  def kill_stale(pid) when is_integer(pid) do
    Logger.warning("🔨 Killing stale process #{pid}")

    :os.cmd(~c"kill #{pid}")
    Process.sleep(2_000)

    if process_exists?(pid) do
      Logger.warning("Process #{pid} ignored SIGTERM, escalating to SIGKILL")
      :os.cmd(~c"kill -9 #{pid}")
      Process.sleep(500)
    end

    not process_exists?(pid)
  end

  @doc """
  Check if a PID is still alive using signal 0.
  """
  @spec process_exists?(integer()) :: boolean()
  def process_exists?(pid) when is_integer(pid) do
    :os.cmd(~c"kill -0 #{pid} 2>/dev/null; echo $?")
    |> List.to_string()
    |> String.trim()
    |> Kernel.==("0")
  end

  @doc """
  Adopt an already healthy process instead of restarting it.
  """
  @spec adopt_service(service(), integer(), integer()) :: {:ok, integer()}
  def adopt_service(service, pid, port) do
    Logger.info("✅ Adopting healthy #{service} on port #{port} (pid=#{pid})")

    Application.put_env(:singularity, {:adopted_service, service}, %{
      pid: pid,
      port: port,
      adopted_at: DateTime.utc_now()
    })

    {:ok, pid}
  end

  @doc """
  Retrieve metadata about an adopted service if present.
  """
  @spec get_adopted(service()) :: map() | nil
  def get_adopted(service) do
    Application.get_env(:singularity, {:adopted_service, service})
  end

  @doc """
  Smart service management orchestration.
  """
  @spec manage_service(service(), integer(), keyword()) ::
          {:adopted, integer()} | {:killed_stale, integer()} | {:ready_to_start}
  def manage_service(service, port, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 1_000)

    case check_service(service, port, timeout) do
      {:healthy, pid} ->
        adopt_service(service, pid, port)
        {:adopted, pid}

      {:stale, pid} ->
        kill_stale(pid)
        {:killed_stale, pid}

      {:not_running} ->
        {:ready_to_start}
    end
  end
end
