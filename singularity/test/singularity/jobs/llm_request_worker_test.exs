defmodule Singularity.Jobs.LlmRequestWorkerTest do
  use ExUnit.Case, async: false
  doctest Singularity.Jobs.LlmRequestWorker

  alias Singularity.Jobs.LlmRequestWorker
  alias Singularity.Schemas.Execution.JobResult
  alias Singularity.Repo

  describe "enqueue_llm_request/3" do
    test "enqueues an LLM request and returns request_id" do
      messages = [%{role: "user", content: "Test message"}]

      {:ok, request_id} =
        LlmRequestWorker.enqueue_llm_request("classifier", messages, complexity: "simple")

      assert is_binary(request_id)
      assert String.length(request_id) == 36  # UUID format
    end

    test "enqueues request with optional parameters" do
      messages = [%{role: "user", content: "Test"}]

      {:ok, request_id} =
        LlmRequestWorker.enqueue_llm_request("architect", messages,
          model: "claude-opus",
          provider: "anthropic",
          max_tokens: 2000,
          temperature: 0.7
        )

      assert is_binary(request_id)
    end
  end

  describe "await_responses_result/2" do
    test "returns timeout when no result available" do
      request_id = Ecto.UUID.generate()

      result =
        LlmRequestWorker.await_responses_result(request_id, timeout_ms: 100, poll_interval_ms: 50)

      assert result == {:error, :timeout}
    end

    test "returns result when JobResult record exists" do
      # Create a mock JobResult with success status
      request_id = Ecto.UUID.generate()

      {:ok, _job_result} =
        Repo.insert(%JobResult{
          workflow: "Singularity.Workflows.LlmRequest",
          instance_id: Ecto.UUID.generate(),
          job_id: 1,
          status: "success",
          input: %{"request_id" => request_id},
          output: %{"text" => "Test response", "cost_cents" => 10},
          tokens_used: 100,
          cost_cents: 10,
          duration_ms: 500
        })

      {:ok, result} =
        LlmRequestWorker.await_responses_result(request_id, timeout_ms: 1000)

      assert result["text"] == "Test response"
      assert result["cost_cents"] == 10
    end

    test "returns error when workflow failed" do
      request_id = Ecto.UUID.generate()

      {:ok, _job_result} =
        Repo.insert(%JobResult{
          workflow: "Singularity.Workflows.LlmRequest",
          instance_id: Ecto.UUID.generate(),
          job_id: 1,
          status: "failed",
          input: %{"request_id" => request_id},
          error: "Provider timeout",
          duration_ms: 30000
        })

      result =
        LlmRequestWorker.await_responses_result(request_id, timeout_ms: 1000)

      assert {:error, {:failed, "Provider timeout"}} = result
    end
  end

  describe "integration: enqueue → result storage → retrieval" do
    test "full queue loop with mocked result storage" do
      messages = [%{role: "user", content: "Classify this text"}]

      # Enqueue request
      {:ok, request_id} =
        LlmRequestWorker.enqueue_llm_request("classifier", messages, complexity: "simple")

      # Simulate result storage (what LlmResultPoller does)
      {:ok, _job_result} =
        Repo.insert(%JobResult{
          workflow: "Singularity.Workflows.LlmRequest",
          instance_id: Ecto.UUID.generate(),
          job_id: 1,
          status: "success",
          input: %{"request_id" => request_id, "task_type" => "classifier"},
          output: %{"text" => "Classified as: Important", "model" => "gemini-flash"},
          tokens_used: 50,
          cost_cents: 1,
          duration_ms: 250
        })

      # Wait and retrieve result
      {:ok, result} =
        LlmRequestWorker.await_responses_result(request_id, timeout_ms: 5000)

      assert result["text"] == "Classified as: Important"
      assert result["model"] == "gemini-flash"
    end
  end
end
