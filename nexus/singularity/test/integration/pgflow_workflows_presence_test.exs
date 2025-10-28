defmodule Singularity.PgflowWorkflowsPresenceTest do
  use ExUnit.Case, async: false

  alias Singularity.Workflows.{
    AutoCodeIngestion,
    EmbeddingTrainingWorkflow,
    ArchitectureLearningWorkflow
  }

  @dummy_attrs %{
    artifacts: [],
    file_path: "test.ex",
    metadata: %{}
  }

  describe "AutoCodeIngestion workflow" do
    test "module is loaded and exposes start_workflow/1" do
      assert function_exported?(AutoCodeIngestion, :start_workflow, 1)

      assert {:error, _} = AutoCodeIngestion.start_workflow(@dummy_attrs)
    end
  end

  describe "EmbeddingTrainingWorkflow module" do
    test "module exports steps (PGFlow integration)" do
      assert function_exported?(EmbeddingTrainingWorkflow, :perform, 2)
      assert function_exported?(EmbeddingTrainingWorkflow, :handle_event, 3)
    end
  end

  describe "ArchitectureLearningWorkflow module" do
    test "module exports workflow callbacks" do
      assert function_exported?(ArchitectureLearningWorkflow, :perform, 2)
      assert function_exported?(ArchitectureLearningWorkflow, :handle_event, 3)
    end
  end
end
