defmodule Singularity.PgflowAdapterEmbeddingTest do
  use ExUnit.Case, async: true
  import Mox
  import ExUnit.CaptureLog

  alias Broadway.Message
  alias Singularity.Embedding.BroadwayEmbeddingPipeline
  alias Pgflow.Workflow
  alias Singularity.Repo

  setup :verify_on_exit!

  setup do
    # Mock PGFlow workflow and Repo for integration test
    {:ok, workflow_pid} = start_supervised({Agent, fn -> [] end})
    Mox.expect(Repo, :all, fn _query -> [%{id: 1, data: %{artifact_id: "test"}, metadata: %{}}] end)
    Mox.expect(Repo, :update_all, fn _query, _ -> {1, []} end)

    # Mock NxService for embedding generation
    Mox.defmock(Singularity.Embedding.NxServiceMock, for: Singularity.Embedding.NxService.Behaviour)
    Mox.expect(Singularity.Embedding.NxServiceMock, :embed, fn _text, device: :cpu -> {:ok, Nx.tensor([1.0])} end)

    %{workflow_pid: workflow_pid}
  end

  describe "end-to-end PGFlow adapter integration" do
    test "pipeline fetches from PGFlow queue, processes embeddings, and writes to DB" do
      # Enqueue test job in mock queue
      Repo.insert_all("embedding_jobs", [%{data: %{artifact_id: "test"}, status: "pending"}])

      opts = [
        artifacts: [],  # PGFlowProducer fetches independently
        device: :cpu,
        workers: 1,
        batch_size: 1,
        verbose: false
      ]

      # Start pipeline with PGFlowProducer
      {:ok, _pid} = BroadwayEmbeddingPipeline.start_pipeline(
        [],
        :cpu,
        1,
        1,
        false
      )

      # Simulate demand and workflow yield
      expect(Workflow, :enqueue, fn _, :fetch, %{demand: 1} ->
        messages = [
          %Message{
            data: {1, %{artifact_id: "test"}},
            metadata: %{workflow_pid: self()},
            acknowledger: {Broadway.PgflowProducer.Workflow, 1}
          }
        ]
        send(self(), {:workflow_yield, messages})
        :ok
      end)

      # Run pipeline
      assert {:ok, metrics} = BroadwayEmbeddingPipeline.run(opts)

      # Verify metrics
      assert metrics.processed == 1
      assert metrics.success_rate > 0

      # Capture logs for verification
      assert capture_log(fn ->
        # Simulate ack
        Broadway.PgflowProducer.Workflow.handle_update(:ack, %{id: 1}, %{})
      end) =~ "Acked job 1"
    end
  end
end