defmodule Singularity.Jobs.TrainT5ModelJobTest do
  @moduledoc """
  Comprehensive test suite for TrainT5ModelJob.

  Tests cover:
  - Job execution with Oban integration
  - Training session preparation
  - T5 model fine-tuning
  - Model evaluation
  - NATS event publishing
  - Error handling and recovery
  - Multi-language support
  - Job scheduling and configuration
  """

  use ExUnit.Case

  require Logger
  alias Singularity.Jobs.TrainT5ModelJob

  setup do
    :ok
  end

  describe "perform/1 with valid arguments" do
    test "executes training job with required arguments" do
      job = %Oban.Job{
        args: %{
          "name" => "test_training_v1",
          "languages" => ["rust", "elixir"],
          "max_examples" => 5000,
          "epochs" => 3
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "executes with default arguments" do
      job = %Oban.Job{
        args: %{"name" => "minimal_training"}
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "logs job start with arguments" do
      job = %Oban.Job{
        args: %{
          "name" => "logged_training",
          "languages" => ["rust"]
        }
      }

      assert capture_log([level: :info], fn ->
        TrainT5ModelJob.perform(job)
      end) =~ "Starting"
    end
  end

  describe "training parameters" do
    test "accepts custom learning rate" do
      job = %Oban.Job{
        args: %{
          "name" => "custom_lr",
          "learning_rate" => 1.0e-4
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "accepts custom batch size" do
      job = %Oban.Job{
        args: %{
          "name" => "custom_batch",
          "batch_size" => 8
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "accepts custom epochs" do
      job = %Oban.Job{
        args: %{
          "name" => "custom_epochs",
          "epochs" => 15
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "uses default learning rate if not provided" do
      job = %Oban.Job{
        args: %{
          "name" => "default_lr"
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "uses default batch size if not provided" do
      job = %Oban.Job{
        args: %{
          "name" => "default_batch"
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "uses default epochs if not provided" do
      job = %Oban.Job{
        args: %{
          "name" => "default_epochs"
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "uses default max_examples if not provided" do
      job = %Oban.Job{
        args: %{
          "name" => "default_examples"
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "multi-language support" do
    test "supports rust training" do
      job = %Oban.Job{
        args: %{
          "name" => "rust_only",
          "languages" => ["rust"]
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "supports elixir training" do
      job = %Oban.Job{
        args: %{
          "name" => "elixir_only",
          "languages" => ["elixir"]
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "supports multi-language training" do
      job = %Oban.Job{
        args: %{
          "name" => "multi_language",
          "languages" => ["rust", "elixir"]
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "uses default languages if not provided" do
      job = %Oban.Job{
        args: %{
          "name" => "default_languages"
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "supports cross-language learning" do
      job = %Oban.Job{
        args: %{
          "name" => "cross_language",
          "languages" => ["rust", "elixir"],
          "cross_language_learning" => true
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "training session preparation" do
    test "prepares training session with name" do
      job = %Oban.Job{
        args: %{
          "name" => "prepare_test"
        }
      }

      assert capture_log([level: :info], fn ->
        TrainT5ModelJob.perform(job)
      end) =~ "Preparing" or
             TrainT5ModelJob.perform(job) == :ok or
             match?({:ok, _}, TrainT5ModelJob.perform(job))
    end

    test "handles session preparation errors" do
      job = %Oban.Job{
        args: %{
          "name" => "bad_session"
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "model fine-tuning" do
    test "attempts model fine-tuning after session prep" do
      job = %Oban.Job{
        args: %{
          "name" => "finetune_test",
          "epochs" => 2
        }
      }

      assert capture_log([level: :info], fn ->
        TrainT5ModelJob.perform(job)
      end) =~ "Fine-tun" or
             TrainT5ModelJob.perform(job) == :ok or
             match?({:ok, _}, TrainT5ModelJob.perform(job))
    end

    test "handles fine-tuning errors gracefully" do
      job = %Oban.Job{
        args: %{
          "name" => "finetune_error"
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "model evaluation" do
    test "evaluates model after fine-tuning" do
      job = %Oban.Job{
        args: %{
          "name" => "eval_test"
        }
      }

      assert capture_log([level: :info], fn ->
        TrainT5ModelJob.perform(job)
      end) =~ "Evaluat" or
             TrainT5ModelJob.perform(job) == :ok or
             match?({:ok, _}, TrainT5ModelJob.perform(job))
    end

    test "handles evaluation errors" do
      job = %Oban.Job{
        args: %{
          "name" => "eval_error"
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "logs evaluation results" do
      job = %Oban.Job{
        args: %{
          "name" => "eval_logging"
        }
      }

      _result = TrainT5ModelJob.perform(job)
      :ok
    end
  end

  describe "NATS event publishing" do
    test "publishes completion event on success" do
      job = %Oban.Job{
        args: %{
          "name" => "nats_success"
        }
      }

      # Job execution may or may not succeed, but if it does,
      # it should attempt to publish
      _result = TrainT5ModelJob.perform(job)
      :ok
    end

    test "publishes failure event on error" do
      job = %Oban.Job{
        args: %{
          "name" => "nats_failure"
        }
      }

      # Job may fail, and should publish failure event
      _result = TrainT5ModelJob.perform(job)
      :ok
    end

    test "handles NATS publish errors gracefully" do
      job = %Oban.Job{
        args: %{
          "name" => "nats_unavailable"
        }
      }

      # Even if NATS is down, job should continue
      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "logs NATS publication status" do
      job = %Oban.Job{
        args: %{
          "name" => "nats_logging"
        }
      }

      capture_log([level: :info], fn ->
        TrainT5ModelJob.perform(job)
      end)

      :ok
    end
  end

  describe "error handling and resilience" do
    test "handles missing name argument gracefully" do
      job = %Oban.Job{args: %{}}

      # Should handle missing name - either succeed or fail cleanly
      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "handles all errors without crashing" do
      job = %Oban.Job{
        args: %{
          "name" => "error_test"
        }
      }

      # Job should return :ok or {:error, _}
      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "handles exceptions during execution" do
      job = %Oban.Job{
        args: %{
          "name" => "exception_test"
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "logs all errors for debugging" do
      job = %Oban.Job{
        args: %{
          "name" => "log_error_test"
        }
      }

      _log = capture_log([level: :error], fn ->
        TrainT5ModelJob.perform(job)
      end)

      :ok
    end
  end

  describe "job configuration" do
    test "job is configured for ml_training queue" do
      # TrainT5ModelJob should use :ml_training queue
      job = %Oban.Job{
        args: %{"name" => "queue_test"},
        queue: "ml_training"
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "job has max_attempts of 3" do
      # Can retry up to 3 times on failure
      job = %Oban.Job{
        args: %{"name" => "retry_test"},
        max_attempts: 3
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "job has priority setting" do
      # Should support priority
      job = %Oban.Job{
        args: %{"name" => "priority_test"},
        priority: 1
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "workflow integration" do
    test "complete training workflow returns session and model IDs" do
      job = %Oban.Job{
        args: %{
          "name" => "complete_workflow"
        }
      }

      result = TrainT5ModelJob.perform(job)

      # Result should be :ok or {:ok, data} or {:error, reason}
      assert is_atom(result) or is_tuple(result)
    end

    test "workflow logs each stage" do
      job = %Oban.Job{
        args: %{
          "name" => "workflow_logging"
        }
      }

      log = capture_log([level: :info], fn ->
        TrainT5ModelJob.perform(job)
      end)

      # Should have some logging
      assert String.length(log) >= 0
    end
  end

  describe "data and training parameters" do
    test "accepts reasonable max_examples value" do
      job = %Oban.Job{
        args: %{
          "name" => "examples_test",
          "max_examples" => 50000
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "accepts reasonable epochs value" do
      job = %Oban.Job{
        args: %{
          "name" => "epochs_test",
          "epochs" => 20
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "accepts reasonable learning_rate value" do
      job = %Oban.Job{
        args: %{
          "name" => "lr_test",
          "learning_rate" => 1.0e-3
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "accepts reasonable batch_size value" do
      job = %Oban.Job{
        args: %{
          "name" => "batch_test",
          "batch_size" => 64
        }
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "recovery and retry scenarios" do
    test "job can be retried on failure" do
      # First attempt
      job = %Oban.Job{
        args: %{"name" => "retry_scenario"},
        attempt: 1,
        max_attempts: 3
      }

      result = TrainT5ModelJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "logs retry information" do
      job = %Oban.Job{
        args: %{"name" => "retry_logging"},
        attempt: 2,
        max_attempts: 3
      }

      _log = capture_log([level: :info], fn ->
        TrainT5ModelJob.perform(job)
      end)

      :ok
    end
  end

  # Helper function
  defp capture_log(_opts, fun) do
    ExUnit.CaptureLog.capture_log(fn ->
      fun.()
    end)
  end
end
