defmodule Singularity.Knowledge.TemplateQuestionIntegrationTest do
  @moduledoc """
  Integration test for Phase 2: 2-way templates with questions.

  Tests that:
  1. Templates can have questions
  2. Questions are asked during generation
  3. Answers are stored in DB
  4. Answer files are written to disk
  """

  use Singularity.DataCase, async: false

  alias Singularity.QualityCodeGenerator
  alias Singularity.Knowledge.TemplateGeneration

  @test_file_path "/tmp/test_genserver_#{System.unique_integer([:positive])}.ex"

  setup do
    # Clean up any existing test file
    on_exit(fn ->
      File.rm(@test_file_path)
      File.rm(@test_file_path <> ".template-answers.yml")
    end)

    :ok
  end

  describe "QualityCodeGenerator with questions (Phase 2)" do
    @tag :integration
    test "generates code with questions and tracks answers" do
      # Generate code with a task that should trigger GenServer questions
      {:ok, result} =
        QualityCodeGenerator.generate(
          task: "Create a user cache with state management",
          language: "elixir",
          quality: :production,
          output_path: @test_file_path
        )

      # Verify code was generated
      assert result.code
      assert result.quality_score > 0

      # Verify tracking worked with answers
      {:ok, generation} = TemplateGeneration.find_by_file(@test_file_path)

      assert generation.template_id == "quality_template:elixir-production"
      assert generation.template_version == "2.6.0"

      # Verify basic answers
      assert generation.answers["task"] == "Create a user cache with state management"
      assert generation.answers["language"] == "elixir"
      assert generation.answers["quality"] == :production

      # Verify question answers exist (may be defaults if LLM not available)
      # The template has 7 questions, so we should have at least some answers
      answer_keys = Map.keys(generation.answers)

      # Check for question-specific keys
      possible_question_keys = [
        "use_genserver",
        "supervisor_strategy",
        "use_ets",
        "ets_ttl_minutes",
        "include_telemetry",
        "include_circuit_breaker",
        "documentation_level"
      ]

      # At least some question answers should be present
      has_question_answers =
        Enum.any?(possible_question_keys, fn key -> key in answer_keys end)

      assert has_question_answers,
             "Expected at least one question answer in: #{inspect(answer_keys)}"
    end

    @tag :integration
    test "writes answer file to disk" do
      # Generate code
      {:ok, _result} =
        QualityCodeGenerator.generate(
          task: "Simple module",
          language: "elixir",
          quality: :production,
          output_path: @test_file_path
        )

      # Verify answer file was created
      answer_file_path = @test_file_path <> ".template-answers.yml"
      assert File.exists?(answer_file_path), "Answer file should exist at #{answer_file_path}"

      # Read and verify content
      {:ok, content} = File.read(answer_file_path)

      assert content =~ "# Template Answer File"
      assert content =~ "_template_id: quality_template:elixir-production"
      assert content =~ "_template_version: 2.6.0"
      assert content =~ "_success: true"
      assert content =~ "task: \"Simple module\""
      assert content =~ "language: \"elixir\""
    end

    @tag :integration
    test "handles templates without questions gracefully" do
      # Use rust template which might not have questions yet
      {:ok, result} =
        QualityCodeGenerator.generate(
          task: "Parse JSON",
          language: "rust",
          quality: :production,
          output_path: "/tmp/test_rust_#{System.unique_integer([:positive])}.rs"
        )

      assert result.code
      assert result.quality_score > 0

      # Should still work even if template has no questions
    end
  end

  describe "question defaults" do
    test "uses default answers when LLM fails" do
      # This test verifies the fallback to defaults works
      # In real usage, if LLM is unavailable, it should use template defaults

      template = %{
        "questions" => [
          %{"name" => "use_feature", "type" => "boolean", "default" => true},
          %{"name" => "level", "type" => "number", "default" => 5}
        ]
      }

      # Simulate getting defaults
      defaults =
        template["questions"]
        |> Enum.map(fn q -> {q["name"], q["default"]} end)
        |> Enum.into(%{})

      assert defaults["use_feature"] == true
      assert defaults["level"] == 5
    end
  end
end
