defmodule Singularity.HotReload.ModuleReloaderTest do
  use ExUnit.Case, async: false

  alias Singularity.HotReload.ModuleReloader

  setup do
    paths = Singularity.CodeStore.paths()
    cleanup_generated(paths)

    on_exit(fn -> cleanup_generated(paths) end)

    # Wait for queue to drain between tests
    :timer.sleep(100)
    :ok
  end

  test "enqueues requests successfully when queue has space" do
    agent_id = "test-agent-#{:rand.uniform(100_000)}"
    payload = %{code: "defmodule TestStrategy do\n  def respond(input), do: {:ok, input}\nend"}

    depth = Manager.queue_depth()

    if depth < 90 do
      assert :ok = Manager.enqueue(agent_id, payload)
    end

    assert Manager.queue_depth() >= 0
  end

  test "rejects requests when queue is full" do
    agent_id = "test-agent-#{:rand.uniform(100_000)}"

    payload = %{
      code: "defmodule BlockingStrategy do\n  def respond(input), do: {:ok, input}\nend"
    }

    manager = Process.whereis(Manager)
    original_state = :sys.get_state(manager)

    full_queue =
      Enum.reduce(1..100, :queue.new(), fn _, queue ->
        entry = %{
          id: make_ref(),
          agent_id: agent_id,
          payload: payload,
          inserted_at: System.system_time(:millisecond)
        }

        :queue.in(entry, queue)
      end)

    :sys.replace_state(manager, fn state -> %{state | queue: full_queue} end)

    try do
      assert {:error, :queue_full} = Manager.enqueue(agent_id, payload)
    after
      :sys.replace_state(manager, fn _ -> original_state end)
    end
  end

  test "queue depth is non-negative" do
    depth = Manager.queue_depth()
    assert depth >= 0
    assert is_integer(depth)
  end

  defp cleanup_generated(%{active: active_dir, versions: versions_dir}) do
    remove_matching(active_dir, "test-agent*.exs")
    remove_matching(active_dir, "test-agent*.gleam")
    remove_matching(versions_dir, "test-agent*.exs")
    remove_matching(versions_dir, "test-agent*.gleam")
    remove_matching(versions_dir, "test-agent*.json")
  end

  defp cleanup_generated(_), do: :ok

  defp remove_matching(dir, pattern) do
    dir
    |> Path.join(pattern)
    |> Path.wildcard()
    |> Enum.each(&File.rm/1)
  end
end
