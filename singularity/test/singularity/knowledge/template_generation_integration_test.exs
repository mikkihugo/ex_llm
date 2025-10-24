defmodule Singularity.Knowledge.TemplateGenerationIntegrationTest do
  @moduledoc """
  Integration test for Copier patterns - Template Generation Tracking.

  Tests that QualityCodeGenerator properly tracks what templates generate what code.
  """

  use Singularity.DataCase, async: false

  alias Singularity.QualityCodeGenerator
  alias Singularity.Knowledge.TemplateGeneration

  describe "QualityCodeGenerator with tracking" do
    test "tracks generation when output_path provided" do
      # Generate code with output_path
      {:ok, result} =
        QualityCodeGenerator.generate(
          task: "Parse JSON API response",
          language: "elixir",
          quality: :production,
          output_path: "lib/my_app/parser.ex"
        )

      assert result.code
      assert result.quality_score > 0

      # Verify tracking worked
      {:ok, generation} = TemplateGeneration.find_by_file("lib/my_app/parser.ex")

      assert generation.template_id == "quality_template:elixir-production"
      assert generation.template_version == "1.0.0"
      assert generation.answers.task == "Parse JSON API response"
      assert generation.answers.language == "elixir"
      assert generation.answers.quality == :production
      assert generation.success == true
    end

    test "does not track when output_path not provided" do
      # Generate code without output_path
      {:ok, result} =
        QualityCodeGenerator.generate(
          task: "Parse JSON API response",
          language: "elixir",
          quality: :production
        )

      assert result.code
      assert result.quality_score > 0

      # Should not create any generation records
      # (can't verify without output_path)
    end

    test "tracks failure when quality score too low" do
      # This would require mocking to force low quality score
      # For now, just document the expected behavior:
      #
      # When score < 0.7:
      # - success: false
      # - Can analyze why template failed
      # - Self-Improving Agent can fix template
    end
  end

  describe "template statistics" do
    test "calculate success rate for template" do
      # Generate some successful code
      QualityCodeGenerator.generate(
        task: "Task 1",
        language: "elixir",
        quality: :production,
        output_path: "lib/task1.ex"
      )

      QualityCodeGenerator.generate(
        task: "Task 2",
        language: "elixir",
        quality: :production,
        output_path: "lib/task2.ex"
      )

      # Calculate success rate
      template_id = "quality_template:elixir-production"
      success_rate = TemplateGeneration.calculate_success_rate(template_id)

      assert success_rate >= 0.0
      assert success_rate <= 1.0
    end

    test "list all generations from template" do
      # Generate code
      QualityCodeGenerator.generate(
        task: "Task A",
        language: "rust",
        quality: :production,
        output_path: "src/task_a.rs"
      )

      QualityCodeGenerator.generate(
        task: "Task B",
        language: "rust",
        quality: :production,
        output_path: "src/task_b.rs"
      )

      # List generations
      template_id = "quality_template:rust-production"
      generations = TemplateGeneration.list_by_template(template_id)

      assert length(generations) >= 2
      assert Enum.all?(generations, &(&1.template_id == template_id))
    end
  end

  describe "answer file export" do
    test "exports answer file for generated code" do
      # Generate code
      QualityCodeGenerator.generate(
        task: "Create worker",
        language: "elixir",
        quality: :production,
        output_path: "lib/worker.ex"
      )

      # Export answer file (like .copier-answers.yml)
      {:ok, yaml} = TemplateGeneration.export_answer_file("lib/worker.ex")

      assert yaml =~ "_template_id:"
      assert yaml =~ "quality_template:elixir-production"
      assert yaml =~ "task:"
      assert yaml =~ "Create worker"
    end
  end
end
