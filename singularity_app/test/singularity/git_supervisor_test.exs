defmodule Singularity.Git.SupervisorTest do
  use Singularity.DataCase, async: false

  alias Singularity.Git.Supervisor, as: GitSupervisor

  setup do
    original = Application.get_env(:singularity, :git_coordinator, [])

    on_exit(fn ->
      Application.put_env(:singularity, :git_coordinator, original)
    end)

    :ok
  end

  test "does not start tree coordinator when disabled" do
    Application.put_env(:singularity, :git_coordinator, enabled: false)

    {:ok, sup} = GitSupervisor.start_link()
    assert Supervisor.count_children(sup).active == 0

    :ok = Supervisor.stop(sup)
  end

  test "starts tree coordinator when enabled" do
    tmp_repo =
      System.tmp_dir!()
      |> Path.join(
        "git_supervisor_test_" <> Integer.to_string(System.unique_integer([:positive]))
      )

    Application.put_env(:singularity, :git_coordinator,
      enabled: true,
      repo_path: tmp_repo,
      base_branch: "main",
      remote: nil
    )

    {:ok, sup} = GitSupervisor.start_link()

    assert Supervisor.count_children(sup).active == 1

    :ok = Supervisor.stop(sup)
    File.rm_rf(tmp_repo)
  end
end
