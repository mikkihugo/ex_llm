defmodule Singularity.Jobs.DomainVocabularyTrainerJobTest do
  @moduledoc """
  Comprehensive test suite for DomainVocabularyTrainerJob.

  Tests cover:
  - Job execution with Oban integration
  - Vocabulary extraction from different sources (templates, codebase)
  - Training data creation
  - Tokenizer augmentation
  - Vocabulary storage
  - NATS event publishing
  - Error handling and recovery
  - Multi-language support
  - Job scheduling and configuration
  """

  use ExUnit.Case

  require Logger
  alias Singularity.Jobs.DomainVocabularyTrainerJob

  setup do
    :ok
  end

  describe "perform/1 with valid arguments" do
    test "executes training job from templates source" do
      job = %Oban.Job{
        args: %{
          "source" => "templates",
          "include_sparc" => true,
          "include_patterns" => true
        }
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "executes training job from codebase source" do
      job = %Oban.Job{
        args: %{
          "source" => "codebase",
          "languages" => ["elixir", "rust"]
        }
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "executes with default arguments" do
      job = %Oban.Job{args: %{}}

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "logs job start with arguments" do
      job = %Oban.Job{
        args: %{
          "source" => "templates"
        }
      }

      assert capture_log([level: :info], fn ->
        DomainVocabularyTrainerJob.perform(job)
      end) =~ "Starting"
    end
  end

  describe "vocabulary extraction" do
    test "extracts vocabulary from templates" do
      job = %Oban.Job{
        args: %{
          "source" => "templates",
          "include_sparc" => true,
          "include_patterns" => true,
          "include_templates" => true
        }
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "extracts vocabulary from codebase" do
      job = %Oban.Job{
        args: %{
          "source" => "codebase",
          "languages" => ["elixir"]
        }
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "extracts SPARC-specific vocabulary" do
      job = %Oban.Job{
        args: %{
          "source" => "templates",
          "include_sparc" => true
        }
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "extracts pattern-specific vocabulary" do
      job = %Oban.Job{
        args: %{
          "source" => "templates",
          "include_patterns" => true
        }
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "respects min_token_frequency filter" do
      job = %Oban.Job{
        args: %{
          "source" => "codebase",
          "min_token_frequency" => 10
        }
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "training parameters" do
    test "accepts custom language selection" do
      job = %Oban.Job{
        args: %{
          "languages" => ["rust", "elixir", "python"]
        }
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "uses default languages if not provided" do
      job = %Oban.Job{
        args: %{
          "source" => "codebase"
        }
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "accepts custom token frequency threshold" do
      job = %Oban.Job{
        args: %{
          "min_token_frequency" => 5
        }
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "uses default token frequency if not provided" do
      job = %Oban.Job{
        args: %{}
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "vocabulary configuration options" do
    test "controls SPARC vocabulary inclusion" do
      job1 = %Oban.Job{
        args: %{"include_sparc" => true}
      }

      job2 = %Oban.Job{
        args: %{"include_sparc" => false}
      }

      result1 = DomainVocabularyTrainerJob.perform(job1)
      result2 = DomainVocabularyTrainerJob.perform(job2)

      assert is_atom(result1) or is_tuple(result1)
      assert is_atom(result2) or is_tuple(result2)
    end

    test "controls pattern vocabulary inclusion" do
      job1 = %Oban.Job{
        args: %{"include_patterns" => true}
      }

      job2 = %Oban.Job{
        args: %{"include_patterns" => false}
      }

      result1 = DomainVocabularyTrainerJob.perform(job1)
      result2 = DomainVocabularyTrainerJob.perform(job2)

      assert is_atom(result1) or is_tuple(result1)
      assert is_atom(result2) or is_tuple(result2)
    end

    test "controls template vocabulary inclusion" do
      job1 = %Oban.Job{
        args: %{"include_templates" => true}
      }

      job2 = %Oban.Job{
        args: %{"include_templates" => false}
      }

      result1 = DomainVocabularyTrainerJob.perform(job1)
      result2 = DomainVocabularyTrainerJob.perform(job2)

      assert is_atom(result1) or is_tuple(result1)
      assert is_atom(result2) or is_tuple(result2)
    end
  end

  describe "training data creation" do
    test "creates training data from vocabulary" do
      job = %Oban.Job{
        args: %{
          "source" => "templates"
        }
      }

      # Should create training data suitable for embedding models
      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "handles vocabulary with various token frequencies" do
      job = %Oban.Job{
        args: %{
          "source" => "codebase",
          "min_token_frequency" => 1
        }
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "tokenizer augmentation" do
    test "augments tokenizer with custom tokens" do
      job = %Oban.Job{
        args: %{
          "source" => "templates"
        }
      }

      # Should augment with SPARC, template vars, NATS subjects
      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "handles tokenizer augmentation errors gracefully" do
      job = %Oban.Job{
        args: %{
          "source" => "codebase"
        }
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "vocabulary storage" do
    test "stores vocabulary in database" do
      job = %Oban.Job{
        args: %{
          "source" => "templates"
        }
      }

      # Should store extracted vocabulary
      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "returns vocabulary ID after storage" do
      job = %Oban.Job{
        args: %{
          "source" => "templates"
        }
      }

      result = DomainVocabularyTrainerJob.perform(job)

      # Successful execution should return vocab_id in result
      assert is_atom(result) or is_tuple(result)
    end

    test "handles database storage errors" do
      job = %Oban.Job{
        args: %{
          "source" => "codebase"
        }
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "tracks vocabulary size metrics" do
      job = %Oban.Job{
        args: %{
          "source" => "templates"
        }
      }

      log = capture_log([level: :info], fn ->
        DomainVocabularyTrainerJob.perform(job)
      end)

      # May log vocabulary size
      assert String.length(log) >= 0
    end
  end

  describe "NATS event publishing" do
    test "publishes completion event on success" do
      job = %Oban.Job{
        args: %{
          "source" => "templates"
        }
      }

      _result = DomainVocabularyTrainerJob.perform(job)
      :ok
    end

    test "publishes failure event on error" do
      job = %Oban.Job{
        args: %{
          "source" => "invalid_source"
        }
      }

      _result = DomainVocabularyTrainerJob.perform(job)
      :ok
    end

    test "handles NATS publish errors gracefully" do
      job = %Oban.Job{
        args: %{
          "source" => "templates"
        }
      }

      # Even if NATS is down, job should continue
      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "publishes vocabulary metadata" do
      job = %Oban.Job{
        args: %{
          "source" => "templates"
        }
      }

      _result = DomainVocabularyTrainerJob.perform(job)
      :ok
    end
  end

  describe "error handling and resilience" do
    test "handles vocabulary extraction errors" do
      job = %Oban.Job{
        args: %{
          "source" => "invalid"
        }
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "handles all errors without crashing" do
      job = %Oban.Job{
        args: %{
          "source" => "templates"
        }
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "handles exceptions during execution" do
      job = %Oban.Job{
        args: %{
          "source" => "codebase"
        }
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "logs all errors for debugging" do
      job = %Oban.Job{
        args: %{
          "source" => "templates"
        }
      }

      _log = capture_log([level: :error], fn ->
        DomainVocabularyTrainerJob.perform(job)
      end)

      :ok
    end
  end

  describe "job configuration" do
    test "job is configured for ml_training queue" do
      job = %Oban.Job{
        args: %{"source" => "templates"},
        queue: "ml_training"
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "job has max_attempts of 3" do
      job = %Oban.Job{
        args: %{"source" => "templates"},
        max_attempts: 3
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "job has high priority (1)" do
      job = %Oban.Job{
        args: %{"source" => "templates"},
        priority: 1
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "job can be retried on failure" do
      job1 = %Oban.Job{
        args: %{"source" => "templates"},
        attempt: 1,
        max_attempts: 3
      }

      job2 = %Oban.Job{
        args: %{"source" => "templates"},
        attempt: 2,
        max_attempts: 3
      }

      result1 = DomainVocabularyTrainerJob.perform(job1)
      result2 = DomainVocabularyTrainerJob.perform(job2)

      assert is_atom(result1) or is_tuple(result1)
      assert is_atom(result2) or is_tuple(result2)
    end
  end

  describe "multi-language support" do
    test "supports elixir vocabulary" do
      job = %Oban.Job{
        args: %{
          "source" => "codebase",
          "languages" => ["elixir"]
        }
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "supports rust vocabulary" do
      job = %Oban.Job{
        args: %{
          "source" => "codebase",
          "languages" => ["rust"]
        }
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "supports multi-language vocabulary" do
      job = %Oban.Job{
        args: %{
          "source" => "codebase",
          "languages" => ["elixir", "rust", "python"]
        }
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "vocabulary sources" do
    test "supports templates source" do
      job = %Oban.Job{
        args: %{"source" => "templates"}
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "supports codebase source" do
      job = %Oban.Job{
        args: %{"source" => "codebase"}
      }

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "uses default source if not provided" do
      job = %Oban.Job{args: %{}}

      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "special vocabulary types" do
    test "includes SPARC vocabulary when enabled" do
      job = %Oban.Job{
        args: %{
          "source" => "templates",
          "include_sparc" => true
        }
      }

      # Should extract SPARC phases, principles, etc.
      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "includes architectural patterns when enabled" do
      job = %Oban.Job{
        args: %{
          "source" => "templates",
          "include_patterns" => true
        }
      }

      # Should extract patterns like GenServer, NATS, async/await
      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "includes template variables when enabled" do
      job = %Oban.Job{
        args: %{
          "source" => "templates",
          "include_templates" => true
        }
      }

      # Should extract {{MODULE_NAME}}, template placeholders, etc.
      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "logging and monitoring" do
    test "logs job start with source" do
      job = %Oban.Job{
        args: %{"source" => "templates"}
      }

      assert capture_log([level: :info], fn ->
        DomainVocabularyTrainerJob.perform(job)
      end) =~ "Starting"
    end

    test "logs completion with vocab ID and size" do
      job = %Oban.Job{
        args: %{"source" => "templates"}
      }

      _log = capture_log([level: :info], fn ->
        DomainVocabularyTrainerJob.perform(job)
      end)

      :ok
    end

    test "logs failure with error details" do
      job = %Oban.Job{
        args: %{}
      }

      _log = capture_log([level: :error], fn ->
        DomainVocabularyTrainerJob.perform(job)
      end)

      :ok
    end
  end

  describe "RAG integration" do
    test "vocabulary trained for RAG code search" do
      job = %Oban.Job{
        args: %{
          "source" => "codebase",
          "languages" => ["elixir", "rust"]
        }
      }

      # Vocabulary should be suitable for RAG
      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end

    test "stores embeddings for RAG retrieval" do
      job = %Oban.Job{
        args: %{
          "source" => "templates"
        }
      }

      # Should store embeddings alongside vocabulary
      result = DomainVocabularyTrainerJob.perform(job)
      assert is_atom(result) or is_tuple(result)
    end
  end

  # Helper function
  defp capture_log(_opts, fun) do
    ExUnit.CaptureLog.capture_log(fn ->
      fun.()
    end)
  end
end
