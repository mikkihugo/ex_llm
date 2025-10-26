defmodule Singularity.Jobs.LlmResultPollerTest do
  use Singularity.DataCase, async: true

  alias Singularity.Jobs.LlmResultPoller
  alias Singularity.Schemas.Execution.JobResult

  describe "await_responses_result/2" do
    test "returns persisted success payload" do
      request_id = Ecto.UUID.generate()

      {:ok, %JobResult{}} =
        JobResult.record_success(
          workflow: "Singularity.Workflows.LlmRequest",
          input: %{request_id: request_id},
          output: %{request_id: request_id, response: %{"text" => "ok"}},
          tokens_used: 10,
          cost_cents: 1,
          duration_ms: 123
        )

      assert {:ok, %{"response" => %{"text" => "ok"}}} =
               LlmResultPoller.await_responses_result(request_id, timeout: 100, poll_interval: 10)
    end

    test "times out when result is missing" do
      assert {:error, :timeout} =
               LlmResultPoller.await_responses_result(Ecto.UUID.generate(), timeout: 30, poll_interval: 5)
    end

    test "surfaces failure metadata" do
      request_id = Ecto.UUID.generate()

      {:ok, %JobResult{}} =
        JobResult.record_failure(
          workflow: "Singularity.Workflows.LlmRequest",
          input: %{request_id: request_id},
          error: "model unavailable",
          duration_ms: 2000
        )

      assert {:error, {:failed, "model unavailable", _}} =
               LlmResultPoller.await_responses_result(request_id, timeout: 100, poll_interval: 10)
    end
  end
end
