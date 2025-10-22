defmodule Singularity.Git.CoordinatorTest do
  use Singularity.DataCase, async: false

  alias Singularity.Git.Coordinator
  alias Singularity.Git.Store
  alias Singularity.Git.Supervisor, as: GitSupervisor

  setup do
    original = Application.get_env(:singularity, :git_coordinator, [])

    on_exit(fn ->
      Application.put_env(:singularity, :git_coordinator, original)
    end)

    :ok
  end

  test "returns disabled error when coordinator not enabled" do
    Application.put_env(:singularity, :git_coordinator, enabled: false)

    assert {:error, :disabled} = Coordinator.assign_task(:agent, %{id: 1})
    assert {:error, :disabled} = Coordinator.submit_work(:agent, %{})
    assert {:error, :disabled} = Coordinator.merge_status(:correlation)
    assert {:error, :disabled} = Coordinator.merge_all_for_epic(:correlation)
  end

  test "delegates to tree coordinator when enabled" do
    tmp_repo =
      System.tmp_dir!()
      |> Path.join(
        "git_coordinator_test_" <> Integer.to_string(System.unique_integer([:positive]))
      )

    Application.put_env(:singularity, :git_coordinator,
      enabled: true,
      repo_path: tmp_repo,
      base_branch: "main",
      remote: nil
    )

    {:ok, sup} = GitSupervisor.start_link()

    task = %{id: 123, description: "demo task"}
    assert {:ok, assignment} = Coordinator.assign_task(:agent, task, use_llm: false)
    assert assignment.method == :rules
    assert [%{agent_id: "agent"}] = Store.list_sessions()

    :ok = Supervisor.stop(sup)
    File.rm_rf(tmp_repo)
  end
end
