defmodule CentralCloud.FrameworkLearningOrchestratorTest do
  @moduledoc """
  Tests for FrameworkLearningOrchestrator - config-driven framework learning.

  Tests the orchestrator's ability to:
  - Try learners in priority order
  - Handle success, no_match, and error responses
  - Filter learners based on options
  - Record learner success
  - Provide learner information
  """

  use ExUnit.Case, async: false

  import Mox

  alias CentralCloud.FrameworkLearningOrchestrator
  alias CentralCloud.FrameworkLearners.{TemplateMatcher, LLMDiscovery}

  # Setup mocks for learner modules
  setup :verify_on_exit!

  describe "learn/2 with all learners enabled" do
    test "returns first matching learner result (template_matcher)" do
      # Mock TemplateMatcher to return success
      package_id = "npm:react"
      code_samples = ["import React from 'react'"]

      framework_result = %{
        "name" => "React",
        "type" => "web_framework",
        "version" => "18.0.0",
        "confidence" => 0.95
      }

      # Create a mock Package struct
      with_mock CentralCloud.Repo, [:passthrough],
        get: fn CentralCloud.Schemas.Package, ^package_id ->
          %CentralCloud.Schemas.Package{
            id: package_id,
            name: "react",
            ecosystem: "npm",
            version: "18.0.0",
            dependencies: ["react", "react-dom"],
            detected_framework: framework_result
          }
        end do

        with_mock CentralCloud.NatsClient, [:passthrough],
          request: fn _subject, _payload, _opts ->
            {:ok, %{"templates" => []}}
          end do

          result = FrameworkLearningOrchestrator.learn(package_id, code_samples)

          assert {:ok, framework, :template_matcher} = result
          assert framework["name"] == "React"
          assert framework["type"] == "web_framework"
        end
      end
    end

    test "tries next learner on :no_match (fallback to llm_discovery)" do
      package_id = "npm:custom-framework"
      code_samples = ["const app = createApp()"]

      # Mock TemplateMatcher to return :no_match
      with_mock CentralCloud.Repo, [:passthrough],
        get: fn CentralCloud.Schemas.Package, ^package_id -> nil end do

        with_mock CentralCloud.NatsClient, [:passthrough],
          request: fn
            "central.template.search", _payload, _opts ->
              {:ok, %{"templates" => []}}
            "llm.request", _payload, _opts ->
              {:ok, %{
                "response" => Jason.encode!(%{
                  "name" => "Custom Framework",
                  "type" => "web_framework",
                  "confidence" => 0.85
                })
              }}
          end do

          result = FrameworkLearningOrchestrator.learn(package_id, code_samples)

          assert {:ok, framework, :llm_discovery} = result
          assert framework["name"] == "Custom Framework"
          assert framework["detected_by"] == "llm_discovery"
        end
      end
    end

    test "returns error when all learners return :no_match" do
      package_id = "npm:unknown-package"
      code_samples = ["console.log('test')"]

      # Mock both learners to return :no_match
      with_mock CentralCloud.Repo, [:passthrough],
        get: fn CentralCloud.Schemas.Package, ^package_id -> nil end do

        with_mock CentralCloud.NatsClient, [:passthrough],
          request: fn
            "central.template.search", _payload, _opts ->
              {:ok, %{"templates" => []}}
            "llm.request", _payload, _opts ->
              {:ok, %{"response" => "{}"}}
          end do

          result = FrameworkLearningOrchestrator.learn(package_id, code_samples)

          assert {:error, :no_framework_found} = result
        end
      end
    end

    test "stops on hard error from learner" do
      package_id = "npm:error-package"
      code_samples = ["code"]

      # Mock TemplateMatcher to return error
      with_mock CentralCloud.Repo, [:passthrough],
        get: fn CentralCloud.Schemas.Package, ^package_id -> nil end do

        with_mock CentralCloud.NatsClient, [:passthrough],
          request: fn "central.template.search", _payload, _opts ->
            {:error, :database_error}
          end do

          result = FrameworkLearningOrchestrator.learn(package_id, code_samples)

          # Should return error and NOT try LLM
          assert {:error, :package_not_found} = result
        end
      end
    end
  end

  describe "learn/2 with priority ordering" do
    test "tries learners in correct priority order (low to high)" do
      package_id = "npm:test"
      code_samples = ["test code"]

      # Track which learner is tried first
      call_order = Agent.start_link(fn -> [] end)
      {:ok, pid} = call_order

      with_mock CentralCloud.Repo, [:passthrough],
        get: fn CentralCloud.Schemas.Package, ^package_id -> nil end do

        with_mock CentralCloud.NatsClient, [:passthrough],
          request: fn subject, _payload, _opts ->
            case subject do
              "central.template.search" ->
                Agent.update(pid, fn calls -> [:template_matcher | calls] end)
                {:ok, %{"templates" => []}}
              "llm.request" ->
                Agent.update(pid, fn calls -> [:llm_discovery | calls] end)
                {:ok, %{"response" => "{}"}}
            end
          end do

          FrameworkLearningOrchestrator.learn(package_id, code_samples)

          # Check call order (reversed because we prepend)
          calls = Agent.get(pid, & &1)
          assert Enum.reverse(calls) == [:template_matcher, :llm_discovery]
        end
      end
    end
  end

  describe "learn/2 with learner filtering" do
    test "only tries specified learners when :learners option provided" do
      package_id = "npm:test"
      code_samples = ["test"]

      # Only try LLM, skip template matcher
      with_mock CentralCloud.Repo, [:passthrough],
        get: fn CentralCloud.Schemas.Package, ^package_id -> nil end do

        with_mock CentralCloud.NatsClient, [:passthrough],
          request: fn "llm.request", _payload, _opts ->
            {:ok, %{
              "response" => Jason.encode!(%{
                "name" => "Framework",
                "type" => "web_framework"
              })
            }}
          end do

          result = FrameworkLearningOrchestrator.learn(
            package_id,
            code_samples,
            learners: [:llm_discovery]
          )

          assert {:ok, _framework, :llm_discovery} = result
        end
      end
    end

    test "filters to only enabled learners from specified list" do
      package_id = "npm:test"
      code_samples = ["test"]

      with_mock CentralCloud.Repo, [:passthrough],
        get: fn CentralCloud.Schemas.Package, ^package_id -> nil end do

        with_mock CentralCloud.NatsClient, [:passthrough],
          request: fn _subject, _payload, _opts ->
            {:ok, %{"templates" => []}}
          end do

          # Try to use disabled learner - should return error
          result = FrameworkLearningOrchestrator.learn(
            package_id,
            code_samples,
            learners: [:disabled_learner]
          )

          assert {:error, :no_framework_found} = result
        end
      end
    end
  end

  describe "get_learners_info/0" do
    test "returns information about all enabled learners" do
      info = FrameworkLearningOrchestrator.get_learners_info()

      assert is_list(info)
      assert length(info) >= 2

      # Check template_matcher info
      template_info = Enum.find(info, fn learner -> learner.name == :template_matcher end)
      assert template_info != nil
      assert template_info.enabled == true
      assert template_info.priority == 10
      assert is_binary(template_info.description)
      assert template_info.module == CentralCloud.FrameworkLearners.TemplateMatcher
      assert is_list(template_info.capabilities)

      # Check llm_discovery info
      llm_info = Enum.find(info, fn learner -> learner.name == :llm_discovery end)
      assert llm_info != nil
      assert llm_info.enabled == true
      assert llm_info.priority == 20
      assert is_binary(llm_info.description)
      assert llm_info.module == CentralCloud.FrameworkLearners.LLMDiscovery
      assert is_list(llm_info.capabilities)
    end

    test "learners are sorted by priority" do
      info = FrameworkLearningOrchestrator.get_learners_info()

      priorities = Enum.map(info, & &1.priority)
      assert priorities == Enum.sort(priorities)
    end
  end

  describe "get_capabilities/1" do
    test "returns capabilities for template_matcher" do
      capabilities = FrameworkLearningOrchestrator.get_capabilities(:template_matcher)

      assert is_list(capabilities)
      assert "fast" in capabilities
      assert "offline" in capabilities
      assert "dependency_based" in capabilities
    end

    test "returns capabilities for llm_discovery" do
      capabilities = FrameworkLearningOrchestrator.get_capabilities(:llm_discovery)

      assert is_list(capabilities)
      assert "llm_based" in capabilities
      assert "thorough" in capabilities
      assert "code_analysis" in capabilities
    end

    test "returns empty list for non-existent learner" do
      capabilities = FrameworkLearningOrchestrator.get_capabilities(:nonexistent)

      assert capabilities == []
    end

    test "returns empty list for learner without capabilities function" do
      capabilities = FrameworkLearningOrchestrator.get_capabilities(:no_capabilities)

      assert capabilities == []
    end
  end

  describe "error handling" do
    test "handles learner execution exception gracefully" do
      package_id = "npm:crash-test"
      code_samples = ["test"]

      # Mock to raise exception
      with_mock CentralCloud.Repo, [:passthrough],
        get: fn CentralCloud.Schemas.Package, ^package_id ->
          raise "Simulated error"
        end do

        with_mock CentralCloud.NatsClient, [:passthrough],
          request: fn "llm.request", _payload, _opts ->
            {:ok, %{"response" => "{}"}}
          end do

          # Should not crash, should try next learner
          result = FrameworkLearningOrchestrator.learn(package_id, code_samples)

          # Since template_matcher crashes, tries llm_discovery
          assert {:error, :no_framework_found} = result
        end
      end
    end

    test "returns learning_failed on unhandled exception" do
      package_id = "npm:test"
      code_samples = ["test"]

      # Make load_learners_for_attempt crash
      with_mock CentralCloud.FrameworkLearner, [:passthrough],
        load_enabled_learners: fn -> raise "Config error" end do

        result = FrameworkLearningOrchestrator.learn(package_id, code_samples)

        assert {:error, :learning_failed} = result
      end
    end
  end

  describe "record_learner_success/2 integration" do
    test "calls record_success on successful learner" do
      package_id = "npm:react"
      code_samples = ["import React from 'react'"]

      framework_result = %{
        "name" => "React",
        "type" => "web_framework",
        "confidence" => 0.95
      }

      mock_package = %CentralCloud.Schemas.Package{
        id: package_id,
        name: "react",
        ecosystem: "npm",
        version: "18.0.0",
        dependencies: ["react", "react-dom"],
        detected_framework: framework_result
      }

      with_mock CentralCloud.Repo, [:passthrough],
        get: fn
          CentralCloud.Schemas.Package, ^package_id -> mock_package
        end,
        update: fn _changeset ->
          {:ok, mock_package}
        end do

        with_mock CentralCloud.NatsClient, [:passthrough],
          request: fn _subject, _payload, _opts ->
            {:ok, %{"templates" => []}}
          end do

          result = FrameworkLearningOrchestrator.learn(package_id, code_samples)

          assert {:ok, _framework, :template_matcher} = result

          # Verify Repo.update was called (record_success updates the package)
          assert called(CentralCloud.Repo.update(:_))
        end
      end
    end
  end
end
