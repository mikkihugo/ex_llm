defmodule Centralcloud.FrameworkLearnerTest do
  use ExUnit.Case

  alias Centralcloud.FrameworkLearner

  describe "load_enabled_learners/0" do
    test "returns enabled learners sorted by priority ascending" do
      learners = FrameworkLearner.load_enabled_learners()

      assert is_list(learners)
      assert length(learners) > 0

      # Verify sorted by priority (ascending)
      priorities = Enum.map(learners, fn {_type, priority, _config} -> priority end)
      assert priorities == Enum.sort(priorities)
    end

    test "returns learner tuples with type, priority, config" do
      learners = FrameworkLearner.load_enabled_learners()

      Enum.each(learners, fn learner ->
        assert is_tuple(learner)
        assert tuple_size(learner) == 3
        {type, priority, config} = learner
        assert is_atom(type)
        assert is_integer(priority)
        assert is_map(config)
      end)
    end

    test "includes template_matcher with priority 10" do
      learners = FrameworkLearner.load_enabled_learners()
      learner = Enum.find(learners, fn {type, _priority, _config} -> type == :template_matcher end)

      assert learner != nil
      {_type, priority, _config} = learner
      assert priority == 10
    end

    test "includes llm_discovery with priority 20" do
      learners = FrameworkLearner.load_enabled_learners()
      learner = Enum.find(learners, fn {type, _priority, _config} -> type == :llm_discovery end)

      assert learner != nil
      {_type, priority, _config} = learner
      assert priority == 20
    end

    test "filters out disabled learners" do
      learners = FrameworkLearner.load_enabled_learners()

      # Should not include disabled learners
      refute Enum.any?(learners, fn {_type, _priority, config} -> config[:enabled] == false end)
    end
  end

  describe "enabled?/1" do
    test "returns true for enabled learner" do
      assert FrameworkLearner.enabled?(:template_matcher) == true
      assert FrameworkLearner.enabled?(:llm_discovery) == true
    end

    test "returns false for non-existent learner" do
      assert FrameworkLearner.enabled?(:nonexistent_learner) == false
    end
  end

  describe "get_learner_module/1" do
    test "returns module for template_matcher" do
      {:ok, module} = FrameworkLearner.get_learner_module(:template_matcher)
      assert module == Centralcloud.FrameworkLearners.TemplateMatcher
    end

    test "returns module for llm_discovery" do
      {:ok, module} = FrameworkLearner.get_learner_module(:llm_discovery)
      assert module == Centralcloud.FrameworkLearners.LLMDiscovery
    end

    test "returns error for nonexistent learner" do
      {:error, :learner_not_configured} = FrameworkLearner.get_learner_module(:nonexistent)
    end
  end

  describe "get_priority/1" do
    test "returns priority for template_matcher" do
      priority = FrameworkLearner.get_priority(:template_matcher)
      assert priority == 10
    end

    test "returns priority for llm_discovery" do
      priority = FrameworkLearner.get_priority(:llm_discovery)
      assert priority == 20
    end

    test "returns default priority 100 for nonexistent learner" do
      priority = FrameworkLearner.get_priority(:nonexistent)
      assert priority == 100
    end
  end

  describe "get_description/1" do
    test "returns description for template_matcher" do
      description = FrameworkLearner.get_description(:template_matcher)
      assert is_binary(description)
      assert String.length(description) > 0
    end

    test "returns description for llm_discovery" do
      description = FrameworkLearner.get_description(:llm_discovery)
      assert is_binary(description)
      assert String.length(description) > 0
    end

    test "returns unknown description for nonexistent learner" do
      description = FrameworkLearner.get_description(:nonexistent)
      assert description == "Unknown learner"
    end
  end

  describe "configuration validation" do
    test "all enabled learners have module configured" do
      learners = FrameworkLearner.load_enabled_learners()

      Enum.each(learners, fn {type, _priority, config} ->
        assert Map.has_key?(config, :module),
               "Learner #{type} missing :module in config"
        assert is_atom(config[:module]),
               "Learner #{type} :module is not an atom"
      end)
    end
  end
end
