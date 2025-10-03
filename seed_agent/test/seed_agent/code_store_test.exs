defmodule SeedAgent.CodeStoreTest do
  use ExUnit.Case, async: false

  alias SeedAgent.CodeStore

  setup do
    # Use a temp directory for tests
    temp_dir = System.tmp_dir!() |> Path.join("code_store_test_#{:rand.uniform(100_000)}")
    old_env = System.get_env("CODE_ROOT")
    System.put_env("CODE_ROOT", temp_dir)

    on_exit(fn ->
      File.rm_rf(temp_dir)

      if old_env do
        System.put_env("CODE_ROOT", old_env)
      else
        System.delete_env("CODE_ROOT")
      end
    end)

    :ok
  end

  test "stages code successfully" do
    agent_id = "test-agent"
    version = 1
    code = "pub fn hello() { \"world\" }"
    metadata = %{source: "test"}

    {:ok, version_file} = CodeStore.stage(agent_id, version, code, metadata)

    assert File.exists?(version_file)
    assert File.read!(version_file) == code
  end

  test "promotes code to active" do
    agent_id = "test-agent"
    version = 1
    code = "pub fn hello() { \"world\" }"

    {:ok, version_file} = CodeStore.stage(agent_id, version, code, %{})
    {:ok, active_file} = CodeStore.promote(agent_id, version_file)

    assert File.exists?(active_file)
    assert File.read!(active_file) == code
  end

  test "handles staging errors gracefully" do
    # Test with invalid code (empty)
    {:error, _} = CodeStore.stage("agent", 1, "", %{})
  end

  test "returns error when promoting non-existent file" do
    {:error, _} = CodeStore.promote("agent", "/nonexistent/path.gleam")
  end
end
