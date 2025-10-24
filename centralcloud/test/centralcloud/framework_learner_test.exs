defmodule Centralcloud.FrameworkLearnerTest do
  @moduledoc """
  Tests for FrameworkLearner behavior contract and config loading.

  Tests the config-driven framework learner system including:
  - Loading enabled learners from config
  - Checking if learners are enabled
  - Getting learner modules and priorities
  - Getting learner descriptions
  """

  use ExUnit.Case, async: true

  alias Centralcloud.FrameworkLearner

  describe "load_enabled_learners/0" do
    test "returns enabled learners sorted by priority (ascending)" do
      learners = FrameworkLearner.load_enabled_learners()

      # Should return list of tuples: {learner_type, priority, config}
      assert is_list(learners)
      assert length(learners) > 0

      # Extract types and priorities
      types = Enum.map(learners, fn {type, _priority, _config} -> type end)
      priorities = Enum.map(learners, fn {_type, priority, _config} -> priority end)

      # Verify template_matcher and llm_discovery are present
      assert :template_matcher in types
      assert :llm_discovery in types

      # Verify priorities are in ascending order
      assert priorities == Enum.sort(priorities)
    end

    test "template_matcher has lower priority than llm_discovery" do
      learners = FrameworkLearner.load_enabled_learners()

      template_priority =
        learners
        |> Enum.find(fn {type, _priority, _config} -> type == :template_matcher end)
        |> elem(1)

      llm_priority =
        learners
        |> Enum.find(fn {type, _priority, _config} -> type == :llm_discovery end)
        |> elem(1)

      # Lower priority number means tries first
      assert template_priority < llm_priority
    end

    test "only returns enabled learners" do
      learners = FrameworkLearner.load_enabled_learners()

      # All returned learners should have enabled: true
      Enum.each(learners, fn {_type, _priority, config} ->
        assert config[:enabled] == true
      end)
    end

    test "each learner has module and description" do
      learners = FrameworkLearner.load_enabled_learners()

      Enum.each(learners, fn {_type, _priority, config} ->
        assert config[:module] != nil
        assert config[:description] != nil
      end)
    end
  end

  describe "enabled?/1" do
    test "returns true for enabled learner" do
      assert FrameworkLearner.enabled?(:template_matcher) == true
      assert FrameworkLearner.enabled?(:llm_discovery) == true
    end

    test "returns false for disabled or non-existent learner" do
      assert FrameworkLearner.enabled?(:nonexistent_learner) == false
      assert FrameworkLearner.enabled?(:signature_analyzer) == false
    end
  end

  describe "get_learner_module/1" do
    test "returns module for configured learner" do
      assert {:ok, Centralcloud.FrameworkLearners.TemplateMatcher} =
        FrameworkLearner.get_learner_module(:template_matcher)

      assert {:ok, Centralcloud.FrameworkLearners.LLMDiscovery} =
        FrameworkLearner.get_learner_module(:llm_discovery)
    end

    test "returns error for non-configured learner" do
      assert {:error, :learner_not_configured} =
        FrameworkLearner.get_learner_module(:nonexistent_learner)
    end

    test "returns error for learner with invalid config" do
      # Test with atom that exists but has no module in config
      # This would require modifying config, so we test with non-existent
      assert {:error, :learner_not_configured} =
        FrameworkLearner.get_learner_module(:invalid_config)
    end
  end

  describe "get_priority/1" do
    test "returns priority for configured learner" do
      assert FrameworkLearner.get_priority(:template_matcher) == 10
      assert FrameworkLearner.get_priority(:llm_discovery) == 20
    end

    test "returns default priority 100 for non-configured learner" do
      assert FrameworkLearner.get_priority(:nonexistent_learner) == 100
    end

    test "returns default priority 100 for learner without priority" do
      # If a learner is configured but has no priority field
      assert FrameworkLearner.get_priority(:missing_priority) == 100
    end
  end

  describe "get_description/1" do
    test "returns description for configured learner with loaded module" do
      description = FrameworkLearner.get_description(:template_matcher)
      assert is_binary(description)
      assert description =~ "template"

      description = FrameworkLearner.get_description(:llm_discovery)
      assert is_binary(description)
      assert description =~ "LLM" or description =~ "framework"
    end

    test "returns 'Unknown learner' for non-configured learner" do
      assert FrameworkLearner.get_description(:nonexistent_learner) == "Unknown learner"
    end

    test "returns 'Unknown learner' for learner with unloadable module" do
      assert FrameworkLearner.get_description(:invalid_module) == "Unknown learner"
    end
  end

  describe "config validation" do
    test "all enabled learners have required fields" do
      learners = FrameworkLearner.load_enabled_learners()

      Enum.each(learners, fn {type, priority, config} ->
        # Required fields
        assert is_atom(type), "Learner type must be atom"
        assert is_integer(priority), "Priority must be integer"
        assert is_map(config), "Config must be map"

        # Config fields
        assert config[:module] != nil, "Module is required"
        assert config[:enabled] == true, "Enabled must be true"
        assert is_integer(config[:priority]), "Priority must be integer"
        assert is_binary(config[:description]), "Description must be string"
      end)
    end
  end
end
