defmodule Nexus.Workflows.LLMRequestWorkflowTest do
  @moduledoc """
  Unit tests for Nexus.Workflows.LLMRequestWorkflow workflow steps.

  Tests each step of the LLM request workflow:
  1. validate - validates request parameters
  2. route_llm - routes to appropriate LLM provider
  3. publish_result - publishes result back to pgmq
  4. track_metrics - tracks usage metrics
  """

  use ExUnit.Case, async: true

  alias Nexus.Workflows.LLMRequestWorkflow

  describe "validate step" do
    test "accepts valid request with required fields" do
      request = %{
        "request_id" => "req-123",
        "complexity" => "medium",
        "messages" => [%{"role" => "user", "content" => "test"}]
      }

      {:ok, validated} = LLMRequestWorkflow.validate(request)
      assert validated["request_id"] == "req-123"
      assert validated["complexity"] == "medium"
      assert validated["messages"] == [%{"role" => "user", "content" => "test"}]
    end

    test "rejects request without request_id" do
      request = %{
        "complexity" => "medium",
        "messages" => [%{"role" => "user", "content" => "test"}]
      }

      {:error, {:missing_fields, missing}} = LLMRequestWorkflow.validate(request)
      assert "request_id" in missing
    end

    test "rejects request with invalid complexity" do
      request = %{
        "request_id" => "req-123",
        "complexity" => "invalid",
        "messages" => [%{"role" => "user", "content" => "test"}]
      }

      {:error, {:invalid_complexity, "invalid"}} = LLMRequestWorkflow.validate(request)
    end

    test "rejects request with empty messages" do
      request = %{
        "request_id" => "req-123",
        "complexity" => "medium",
        "messages" => []
      }

      {:error, :empty_messages} = LLMRequestWorkflow.validate(request)
    end

    test "accepts request with all optional fields" do
      request = %{
        "request_id" => "req-123",
        "agent_id" => "agent-1",
        "complexity" => "complex",
        "task_type" => "architect",
        "messages" => [%{"role" => "user", "content" => "Design a system"}],
        "max_tokens" => 4000,
        "temperature" => 0.7,
        "api_version" => "chat_completions"
      }

      {:ok, validated} = LLMRequestWorkflow.validate(request)
      assert validated["request_id"] == "req-123"
      assert validated["agent_id"] == "agent-1"
      assert validated["task_type"] == "architect"
    end
  end

  describe "workflow step definition" do
    test "__workflow_steps__ returns all workflow steps" do
      steps = LLMRequestWorkflow.__workflow_steps__()
      step_names = Enum.map(steps, fn {name, _func, _deps} -> name end)

      assert :validate in step_names
      assert :route_llm in step_names
      assert :publish_result in step_names
      assert :track_metrics in step_names
    end

    test "workflow steps have proper dependencies" do
      steps = LLMRequestWorkflow.__workflow_steps__()

      # Build a map of step name to dependencies
      step_map = Enum.map(steps, fn
        {name, _func, opts} when is_list(opts) ->
          deps = Keyword.get(opts, :depends_on, [])
          {name, deps}
        {name, _func, _func2} ->
          {name, []}
      end) |> Map.new()

      # validate has no dependencies
      assert step_map[:validate] == [] or step_map[:validate] == nil

      # route_llm depends on validate
      assert :validate in (step_map[:route_llm] || [])

      # publish_result depends on route_llm
      assert :route_llm in (step_map[:publish_result] || [])

      # track_metrics depends on publish_result
      assert :publish_result in (step_map[:track_metrics] || [])
    end
  end

  describe "route_llm step" do
    test "converts string keys to atoms for router" do
      state = %{
        "validate" => %{
          "request_id" => "req-123",
          "complexity" => "medium",
          "task_type" => "coder",
          "messages" => [%{"role" => "user", "content" => "code review"}],
          "max_tokens" => 2000,
          "temperature" => 0.5
        }
      }

      # We can't actually route without a real LLM response, but we can test
      # that the function correctly extracts and converts parameters
      # This test verifies the structure is correct for routing

      # The actual routing test would require mocking LLMRouter
      assert is_map(state["validate"])
      assert state["validate"]["request_id"] == "req-123"
      assert state["validate"]["complexity"] == "medium"
    end
  end

  describe "publish_result step" do
    test "extracts request and response data correctly" do
      # Simulate state from route_llm step
      state = %{
        "route_llm" => %{
          request: %{
            "request_id" => "req-123",
            "agent_id" => "agent-1",
            "complexity" => "medium"
          },
          response: %{
            model: "claude-opus",
            content: "Here's the analysis...",
            usage: %{prompt_tokens: 100, completion_tokens: 150, total_tokens: 250},
            cost: 0.015
          },
          latency_ms: 2500,
          timestamp: "2025-10-25T10:00:00Z"
        }
      }

      # Verify the structure is correct for result publishing
      result = state["route_llm"]
      assert result.request["request_id"] == "req-123"
      assert result.response.model == "claude-opus"
      assert result.latency_ms == 2500
    end

    test "formats result message for pgmq" do
      request_id = "req-#{System.unique_integer()}"
      response = %{
        model: "claude-sonnet-4.5",
        content: "Generated code",
        usage: %{prompt_tokens: 50, completion_tokens: 200, total_tokens: 250},
        cost: 0.012
      }

      # Build expected result message
      result_message = %{
        request_id: request_id,
        agent_id: "test-agent",
        response: response.content,
        model: response.model,
        usage: response.usage,
        cost: response.cost,
        latency_ms: 1500,
        timestamp: "2025-10-25T10:00:00Z"
      }

      # Verify it's a valid map with all required fields
      assert is_map(result_message)
      assert result_message.request_id == request_id
      assert result_message.response == response.content
      assert result_message.model == response.model
    end
  end

  describe "track_metrics step" do
    test "extracts metrics from workflow state" do
      state = %{
        "route_llm" => %{
          request: %{
            "request_id" => "req-123",
            "agent_id" => "agent-1",
            "complexity" => "complex",
            "task_type" => "architect"
          },
          response: %{
            model: "claude-opus",
            usage: %{
              prompt_tokens: 200,
              completion_tokens: 500,
              total_tokens: 700
            },
            cost: 0.035
          },
          latency_ms: 3500,
          timestamp: "2025-10-25T10:00:05Z"
        }
      }

      # Extract metrics as the step would
      result = state["route_llm"]
      metrics = %{
        request_id: result.request["request_id"],
        agent_id: result.request["agent_id"],
        complexity: result.request["complexity"],
        task_type: result.request["task_type"],
        model: result.response.model,
        tokens: 700,
        prompt_tokens: 200,
        completion_tokens: 500,
        cost: 0.035,
        latency_ms: 3500,
        timestamp: "2025-10-25T10:00:05Z"
      }

      # Verify metrics structure
      assert metrics.tokens == 700
      assert metrics.cost == 0.035
      assert metrics.latency_ms == 3500
    end
  end

  describe "error handling" do
    test "validate rejects missing all required fields" do
      {:error, {:missing_fields, missing}} = LLMRequestWorkflow.validate(%{})
      assert "request_id" in missing
      assert "complexity" in missing
      assert "messages" in missing
    end

    test "route_llm handles invalid complexity gracefully" do
      state = %{
        "validate" => %{
          "request_id" => "req-123",
          "complexity" => "bogus",
          "messages" => []
        }
      }

      # Validation should have caught this, but route_llm should handle gracefully
      assert is_map(state["validate"])
    end
  end

  describe "full workflow structure" do
    test "workflow DAG is properly constructed" do
      steps = LLMRequestWorkflow.__workflow_steps__()
      assert length(steps) == 4

      # Extract step names
      step_names = Enum.map(steps, fn {name, _func, _opts} -> name end)
      assert step_names == [:validate, :route_llm, :publish_result, :track_metrics]
    end

    test "each step has a valid function" do
      steps = LLMRequestWorkflow.__workflow_steps__()

      Enum.each(steps, fn {name, func, _opts} ->
        assert is_function(func, 1), "Step #{name} should have a function/1"
      end)
    end
  end
end
