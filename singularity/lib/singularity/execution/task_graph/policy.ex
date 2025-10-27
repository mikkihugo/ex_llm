defmodule Singularity.Execution.TaskGraph.Policy do
  @moduledoc """
  TaskGraph.Policy - Role-based access control for agent tool execution.

  ## Purpose

  Enforces security policies preventing self-improving agents from:
  - Exfiltrating secrets via network requests
  - Destroying git history
  - Tampering with production code
  - Exhausting system resources
  - Installing backdoors

  ## Policies

  Each role has different tool access:

  ### :coder
  - ✅ Allowed: git (safe subset), fs (code paths), shell (whitelisted), lua
  - ❌ Denied: HTTP/network, docker, dangerous git commands
  - Resource limits: 5 min timeout max

  ### :tester
  - ✅ Allowed: docker (with resource limits), shell (test commands only)
  - ❌ Denied: fs write, git, HTTP, lua
  - Resource limits: 10 min timeout, CPU/memory required for Docker

  ### :critic
  - ✅ Allowed: fs (read-only), lua
  - ❌ Denied: fs write, shell, git, docker, HTTP
  - Resource limits: 30 sec timeout (fastest)

  ### :researcher
  - ✅ Allowed: HTTP (whitelisted domains), fs (read-only)
  - ❌ Denied: All modification tools
  - Whitelist: hexdocs.pm, docs.rs, github.com, etc.

  ### :admin
  - ✅ Allowed: ALL tools (use with caution!)
  - Resource limits: None

  ## Usage

      iex> Policy.enforce(:coder, :git, %{cmd: ["commit", "-m", "Fix"]}, [])
      :ok

      iex> Policy.enforce(:coder, :http, %{url: "https://evil.com"}, [])
      {:error, :policy_violation}
  """

  @policies %{
    coder: %{
      allowed_tools: [:git, :fs, :shell, :lua],
      git_blacklist: ["push --force", "reset --hard", "rebase -i", "filter-branch"],
      shell_whitelist: ["mix", "git", "elixir", "gleam", "cargo", "npm", "bun"],
      fs_allowed_paths: ["/code", "/tmp"],
      # 5 minutes
      max_timeout: 300_000,
      network: :deny
    },
    tester: %{
      allowed_tools: [:docker, :shell],
      shell_whitelist: ["mix test", "cargo test", "npm test", "bun test", "pytest"],
      docker_resource_limits_required: true,
      # 10 minutes
      max_timeout: 600_000,
      network: :deny
    },
    critic: %{
      allowed_tools: [:fs, :lua],
      # Read-only
      fs_write_denied: true,
      # 30 seconds
      max_timeout: 30_000,
      network: :deny
    },
    researcher: %{
      allowed_tools: [:http, :fs],
      fs_write_denied: true,
      http_whitelist: [
        "hexdocs.pm",
        "docs.rs",
        "github.com",
        "elixir-lang.org",
        "rust-lang.org",
        "npmjs.com",
        "crates.io"
      ],
      # 1 minute
      max_timeout: 60_000,
      network: :allow_whitelisted
    },
    admin: %{
      allowed_tools: [:git, :fs, :shell, :docker, :lua, :http],
      # No limit
      max_timeout: nil,
      network: :allow
    }
  }

  @doc """
  Enforce policy for tool execution.

  ## Arguments

  - `role` - Agent role (`:coder`, `:tester`, `:critic`, `:researcher`, `:admin`)
  - `tool` - Tool name (`:git`, `:fs`, `:shell`, `:docker`, `:lua`, `:http`)
  - `args` - Tool-specific arguments
  - `opts` - Options (timeout, resource limits, etc.)

  ## Returns

  - `:ok` - Policy allows execution
  - `{:error, reason}` - Policy violation

  ## Examples

      iex> Policy.enforce(:coder, :shell, %{cmd: ["mix", "test"]}, [])
      :ok

      iex> Policy.enforce(:coder, :shell, %{cmd: ["rm", "-rf", "/"]}, [])
      {:error, {:forbidden_command, ["rm", "-rf", "/"]}}
  """
  def enforce(role, tool, args, opts \\ []) do
    policy = Map.get(@policies, role)

    if policy do
      with :ok <- check_tool_allowed(policy, tool),
           :ok <- check_timeout(policy, Keyword.get(opts, :timeout)),
           :ok <- check_tool_specific_policy(role, policy, tool, args, opts) do
        :ok
      end
    else
      {:error, {:unknown_role, role}}
    end
  end

  @doc """
  Get policy definition for a role.
  """
  def get_policy(role), do: Map.get(@policies, role)

  @doc """
  List all available policies.
  """
  def list_policies, do: Map.keys(@policies)

  ## Private Helpers

  defp check_tool_allowed(policy, tool) do
    if tool in policy.allowed_tools do
      :ok
    else
      {:error, {:forbidden_tool, tool}}
    end
  end

  defp check_timeout(_policy, nil), do: :ok

  defp check_timeout(policy, requested_timeout) do
    case policy[:max_timeout] do
      nil ->
        :ok

      max_timeout when requested_timeout <= max_timeout ->
        :ok

      max_timeout ->
        {:error, {:timeout_exceeded, max: max_timeout, requested: requested_timeout}}
    end
  end

  defp check_tool_specific_policy(role, policy, :git, %{cmd: cmd}, opts) do
    # Check for dangerous git commands
    cmd_str = Enum.join(cmd, " ")

    dangerous_patterns = policy[:git_blacklist] || []

    if Enum.any?(dangerous_patterns, &String.contains?(cmd_str, &1)) do
      {:error, {:dangerous_git_operation, cmd_str}}
    else
      :ok
    end
  end

  defp check_tool_specific_policy(_role, policy, :shell, %{cmd: cmd}, opts) do
    # Check shell command whitelist
    binary = List.first(cmd)
    whitelist = policy[:shell_whitelist] || []

    if Enum.any?(whitelist, &String.starts_with?(binary, &1)) do
      :ok
    else
      {:error, {:forbidden_command, cmd}}
    end
  end

  defp check_tool_specific_policy(_role, policy, :fs, %{write: path}, opts) do
    cond do
      policy[:fs_write_denied] == true ->
        {:error, :write_access_denied}

      allowed_paths = policy[:fs_allowed_paths] ->
        if Enum.any?(allowed_paths, &String.starts_with?(path, &1)) do
          :ok
        else
          {:error, {:forbidden_path, path}}
        end

      true ->
        :ok
    end
  end

  defp check_tool_specific_policy(_role, policy, :fs, %{read: path}, opts) do
    # Read is usually allowed if tool is allowed
    allowed_paths = policy[:fs_allowed_paths]

    if allowed_paths do
      if Enum.any?(allowed_paths, &String.starts_with?(path, &1)) do
        :ok
      else
        {:error, {:forbidden_path, path}}
      end
    else
      :ok
    end
  end

  defp check_tool_specific_policy(_role, policy, :http, %{url: url}, opts) do
    case policy[:network] do
      :deny ->
        {:error, :policy_violation}

      :allow ->
        :ok

      :allow_whitelisted ->
        whitelist = policy[:http_whitelist] || []
        uri = URI.parse(url)

        if Enum.any?(whitelist, &String.contains?(uri.host || "", &1)) do
          :ok
        else
          {:error, {:forbidden_url, url}}
        end
    end
  end

  defp check_tool_specific_policy(_role, policy, :docker, _args, opts) do
    if policy[:docker_resource_limits_required] do
      cpu = Keyword.get(opts, :cpu)
      mem = Keyword.get(opts, :mem)

      if cpu && mem do
        :ok
      else
        {:error, :docker_resource_limits_required}
      end
    else
      :ok
    end
  end

  defp check_tool_specific_policy(_role, _policy, _tool, _args, opts) do
    :ok
  end
end
