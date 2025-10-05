defmodule Singularity.Git.StoreTest do
  use Singularity.DataCase, async: true

  alias Singularity.Git.Store

  test "upserts and lists sessions" do
    {:ok, session} =
      Store.upsert_session(%{
        agent_id: :agent_1,
        branch: "feature/demo",
        workspace_path: "/tmp/demo",
        correlation_id: "corr-1",
        status: :active,
        meta: %{task_id: 42}
      })

    assert session.agent_id == "agent_1"

    sessions = Store.list_sessions()
    assert Enum.count(sessions) == 1
  end

  test "upserts pending merge and logs history" do
    {:ok, _pending} =
      Store.upsert_pending_merge(%{
        branch: "feature/demo",
        pr_number: 12,
        agent_id: "agent_1",
        task_id: "task",
        correlation_id: "corr"
      })

    assert [%{branch: "feature/demo"} | _] = Store.list_pending_merges()

    {1, nil} = Store.delete_pending_merge("feature/demo")
    assert Store.list_pending_merges() == []

    assert {:ok, _} =
             Store.log_merge(%{
               branch: "feature/demo",
               status: :merged,
               merge_commit: "abc123"
             })
  end
end
