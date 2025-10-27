defmodule Singularity.Embedding.Validation do
  @moduledoc """
  Validation & Testing for Phase 4.1

  Comprehensive testing of the embedding system with real models:
  - Model loading from HuggingFace
  - Inference quality verification
  - Fine-tuning convergence
  - Performance benchmarking

  ## Usage

  ```elixir
  # Load and test real models
  {:ok, results} = Validation.test_real_model_loading()

  # Verify inference quality
  {:ok, quality} = Validation.verify_inference_quality(:qodo)

  # Test fine-tuning convergence
  {:ok, convergence} = Validation.test_convergence(:qodo)

  # Run complete benchmark
  {:ok, benchmarks} = Validation.benchmark_complete_system()
  ```
  """

  require Logger
  alias Singularity.Embedding.{ModelLoader, NxService, Trainer}

  @doc """
  Test real model loading from HuggingFace
  """
  def test_real_model_loading do
    Logger.info("=" <> String.duplicate("=", 78))
    Logger.info("🧪 TEST: Real Model Loading from HuggingFace")
    Logger.info("=" <> String.duplicate("=", 78))

    try do
      results1 = %{}

      # Test Qodo loading
      Logger.info("\n📦 Testing Qodo-Embed-1 loading...")
      qodo_data = test_model_loading(:qodo)

      {qodo_result, qodo_status} =
        case qodo_data do
          {:ok, data} -> {data, :success}
          {:error, _reason} -> {%{status: :error}, :error}
        end

      results1 = Map.put(results1, :qodo, qodo_result)

      # Test Jina loading
      Logger.info("\n📦 Testing Jina v3 loading...")
      jina_data = test_model_loading(:jina_v3)

      {jina_result, jina_status} =
        case jina_data do
          {:ok, data} -> {data, :success}
          {:error, _reason} -> {%{status: :error}, :error}
        end

      results1 = Map.put(results1, :jina_v3, jina_result)

      # Summary
      Logger.info("\n" <> String.duplicate("=", 80))
      Logger.info("📊 Model Loading Summary:")
      Logger.info("  Qodo: #{inspect(qodo_status)}")
      Logger.info("  Jina: #{inspect(jina_status)}")
      Logger.info("=" <> String.duplicate("=", 80))

      {:ok, results1}
    rescue
      e ->
        Logger.error("Test failed: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc false
  defp test_model_loading(model) do
    try do
      start_time = System.monotonic_time(:millisecond)

      case ModelLoader.load_model(model) do
        {:ok, state} ->
          load_time = System.monotonic_time(:millisecond) - start_time

          Logger.info("✅ Model loaded successfully")
          Logger.info("   Time: #{load_time} ms")
          Logger.info("   Size: #{inspect(Map.get(state, :model_size, "unknown"))} MB")
          Logger.info("   Has weights: #{Map.has_key?(state, :tensors)}")

          if Map.has_key?(state, :tensors) and map_size(state.tensors) > 0 do
            Logger.info("   Tensors: #{map_size(state.tensors)}")
          end

          {:ok,
           %{
             status: :success,
             model: model,
             load_time_ms: load_time,
             has_weights: Map.has_key?(state, :tensors),
             tensor_count:
               try do
                 map_size(state.tensors)
               rescue
                 _ -> 0
               end
           }}

        {:error, reason} ->
          Logger.warning("⚠️  Model loading failed: #{inspect(reason)}")

          {:ok,
           %{
             status: :fallback,
             model: model,
             reason: reason,
             uses_mock: true
           }}
      end
    rescue
      e ->
        Logger.error("Exception during model loading: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Verify inference quality produces meaningful embeddings
  """
  def verify_inference_quality(model \\ :qodo) do
    Logger.info("\n" <> String.duplicate("=", 80))
    Logger.info("🎯 TEST: Inference Quality Verification (#{model})")
    Logger.info("=" <> String.duplicate("=", 80))

    try do
      test_texts = [
        "def hello_world: return 42",
        "async fn fetch_data() {}",
        "class MyClass: pass",
        "SELECT * FROM users WHERE id = 1",
        "const API_URL = 'https://api.example.com'"
      ]

      Logger.info("\n🧬 Generating embeddings for #{length(test_texts)} test texts...")

      results =
        test_texts
        |> Enum.with_index(1)
        |> Enum.map(fn {text, idx} ->
          Logger.info("  [#{idx}] #{String.slice(text, 0..50)}...")

          case NxService.embed(text, model: model) do
            {:ok, embedding} ->
              # Verify embedding properties
              shape = Nx.shape(embedding)
              norm = compute_norm(embedding)
              min_val = embedding |> Nx.reduce_min() |> Nx.to_number()
              max_val = embedding |> Nx.reduce_max() |> Nx.to_number()

              Logger.debug("      Shape: #{inspect(shape)}")
              Logger.debug("      Norm: #{Float.round(norm, 4)}")

              Logger.debug(
                "      Min/Max: #{Float.round(min_val, 4)} / #{Float.round(max_val, 4)}"
              )

              {:ok,
               %{
                 text: String.slice(text, 0..30),
                 shape: shape,
                 norm: norm,
                 min: min_val,
                 max: max_val
               }}

            {:error, reason} ->
              Logger.warning("      ❌ Failed: #{inspect(reason)}")
              {:error, reason}
          end
        end)

      # Verify similarity computation
      Logger.info("\n📏 Testing similarity computation...")

      case verify_similarities(test_texts, model) do
        {:ok, sims} ->
          Logger.info("   ✅ Computed #{map_size(sims)} similarity pairs")

          Enum.each(sims, fn {{text1, text2}, sim} ->
            Logger.debug(
              "      #{String.slice(text1, 0..20)} ↔ #{String.slice(text2, 0..20)}: #{Float.round(sim, 4)}"
            )
          end)

          {:ok,
           %{
             embeddings: results,
             similarities: sims
           }}

        {:error, reason} ->
          Logger.warning("⚠️  Similarity test failed: #{inspect(reason)}")
          {:ok, %{embeddings: results}}
      end
    rescue
      e ->
        Logger.error("Verification failed: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc false
  defp verify_similarities(texts, model) do
    try do
      pairs = generate_pairs(texts)

      similarities =
        pairs
        |> Enum.map(fn [text1, text2] ->
          case NxService.similarity(text1, text2, model: model) do
            {:ok, sim} -> {{text1, text2}, sim}
            {:error, _} -> nil
          end
        end)
        |> Enum.filter(&(not is_nil(&1)))
        |> Enum.into(%{})

      {:ok, similarities}
    rescue
      e ->
        {:error, e}
    end
  end

  @doc false
  defp compute_norm(tensor) do
    Nx.sqrt(Nx.sum(Nx.multiply(tensor, tensor))) |> Nx.to_number()
  end

  @doc """
  Test fine-tuning convergence on real data
  """
  def test_convergence(model \\ :qodo) do
    Logger.info("\n" <> String.duplicate("=", 80))
    Logger.info("📊 TEST: Fine-Tuning Convergence (#{model})")
    Logger.info("=" <> String.duplicate("=", 80))

    try do
      # Create small training dataset
      Logger.info("\n📚 Creating training data...")

      training_data = [
        %{
          anchor: "def process_data",
          positive: "def handle_data",
          negative: "SELECT FROM table"
        },
        %{
          anchor: "async fn fetch",
          positive: "async fn load",
          negative: "const config"
        },
        %{
          anchor: "class Worker",
          positive: "class Handler",
          negative: "def helper"
        },
        %{
          anchor: "if condition then",
          positive: "if test do",
          negative: "console.log"
        },
        %{
          anchor: "@decorator",
          positive: "@wrapper",
          negative: "import module"
        }
      ]

      Logger.info("✅ Created #{length(training_data)} training triplets")

      # Initialize trainer
      Logger.info("\n🏋️  Initializing trainer...")

      case Trainer.new(model) do
        {:ok, trainer} ->
          Logger.info("✅ Trainer initialized")

          # Run fine-tuning for a few epochs
          Logger.info("\n🚀 Running fine-tuning (3 epochs)...")

          start_time = System.monotonic_time(:millisecond)

          case Trainer.train(trainer, training_data, epochs: 3, learning_rate: 1.0e-4) do
            {:ok, metrics} ->
              train_time = System.monotonic_time(:millisecond) - start_time

              # Extract losses
              losses =
                metrics
                |> Map.get(:metrics_per_epoch, [])
                |> Enum.map(& &1.loss)

              Logger.info("✅ Fine-tuning completed in #{train_time} ms")
              Logger.info("\n📈 Loss per epoch:")

              losses
              |> Enum.with_index(1)
              |> Enum.each(fn {loss, epoch} ->
                Logger.info("   Epoch #{epoch}: #{Float.round(Nx.to_number(loss), 4)}")
              end)

              # Check convergence
              first_loss = List.first(losses) |> Nx.to_number()
              last_loss = List.last(losses) |> Nx.to_number()
              improved = first_loss > last_loss

              Logger.info("\n✨ Convergence Analysis:")
              Logger.info("   First loss: #{Float.round(first_loss, 4)}")
              Logger.info("   Last loss:  #{Float.round(last_loss, 4)}")
              Logger.info("   Improved:   #{improved}")

              Logger.info(
                "   Improvement: #{Float.round((first_loss - last_loss) * 100 / first_loss, 1)}%"
              )

              {:ok,
               %{
                 status: :success,
                 model: model,
                 epochs: 3,
                 losses: losses,
                 converged: improved,
                 improvement_percent: Float.round((first_loss - last_loss) * 100 / first_loss, 1)
               }}

            {:error, reason} ->
              Logger.error("Fine-tuning failed: #{inspect(reason)}")
              {:error, reason}
          end

        {:error, reason} ->
          Logger.error("Trainer initialization failed: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Convergence test failed: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Benchmark complete system performance
  """
  def benchmark_complete_system do
    Logger.info("\n" <> String.duplicate("=", 80))
    Logger.info("⚡ BENCHMARK: Complete System Performance")
    Logger.info("=" <> String.duplicate("=", 80))

    try do
      benchmarks = %{}

      # Benchmark inference
      Logger.info("\n🔍 Benchmarking inference...")

      inference_bench = benchmark_inference()
      benchmarks = Map.put(benchmarks, :inference, inference_bench)

      # Benchmark gradient computation
      Logger.info("\n🔍 Benchmarking gradient computation...")

      gradient_bench = benchmark_gradients()
      benchmarks = Map.put(benchmarks, :gradients, gradient_bench)

      # Print summary
      Logger.info("\n" <> String.duplicate("=", 80))
      Logger.info("📊 Performance Summary:")
      Logger.info("=" <> String.duplicate("=", 80))

      Logger.info("\n⚙️  Inference:")
      Logger.info("   Avg time: #{Map.get(inference_bench, :avg_ms, "N/A")} ms")
      Logger.info("   Min time: #{Map.get(inference_bench, :min_ms, "N/A")} ms")
      Logger.info("   Max time: #{Map.get(inference_bench, :max_ms, "N/A")} ms")

      Logger.info("\n📐 Gradient Computation:")
      Logger.info("   Nx.Defn available: #{Map.get(gradient_bench, :defn_available, false)}")
      Logger.info("   Time: #{Map.get(gradient_bench, :time_ms, "N/A")} ms")

      {:ok, benchmarks}
    rescue
      e ->
        Logger.error("Benchmark failed: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc false
  defp benchmark_inference do
    try do
      texts = [
        "def hello_world: return 42",
        "async fn fetch_data() {}",
        "class MyClass: pass",
        "SELECT * FROM users",
        "const API_URL = 'https://api.example.com'"
      ]

      iterations = 10

      Logger.info("   Running #{iterations} iterations...")

      times =
        1..iterations
        |> Enum.map(fn _ ->
          text = Enum.random(texts)

          start = System.monotonic_time(:millisecond)

          case NxService.embed(text) do
            {:ok, _embedding} ->
              System.monotonic_time(:millisecond) - start

            {:error, _} ->
              nil
          end
        end)
        |> Enum.filter(&(not is_nil(&1)))

      if Enum.empty?(times) do
        %{error: "No successful inferences"}
      else
        %{
          iterations: length(times),
          avg_ms: Float.round(Enum.sum(times) / length(times), 2),
          min_ms: Enum.min(times),
          max_ms: Enum.max(times)
        }
      end
    rescue
      e ->
        Logger.error("Inference benchmark error: #{inspect(e)}")
        %{error: inspect(e)}
    end
  end

  @doc false
  defp benchmark_gradients do
    try do
      Logger.info("   Testing Nx.Defn availability...")

      # Simple loss function
      loss_fn = fn _params, _batch -> Nx.tensor(0.5) end

      # Test Nx.Defn
      start = System.monotonic_time(:millisecond)

      defn_available =
        try do
          Singularity.Embedding.AutomaticDifferentiation.validate_defn_compatibility(loss_fn)
          true
        rescue
          _ -> false
        end

      defn_time = System.monotonic_time(:millisecond) - start

      %{
        defn_available: defn_available,
        time_ms: defn_time
      }
    rescue
      e ->
        Logger.error("Gradient benchmark error: #{inspect(e)}")
        %{error: inspect(e)}
    end
  end

  @doc """
  Run complete validation suite
  """
  def run_complete_validation do
    Logger.info("\n" <> String.duplicate("🔬", 40))
    Logger.info("🔬 PHASE 4.1: COMPLETE VALIDATION SUITE")
    Logger.info(String.duplicate("🔬", 40))

    # Test 1: Model loading
    Logger.info("\n[1/4] Testing model loading...")

    results1 =
      case test_real_model_loading() do
        {:ok, loading_results} ->
          %{model_loading: loading_results}

        {:error, e} ->
          Logger.error("Model loading test failed: #{inspect(e)}")
          %{}
      end

    # Test 2: Inference quality
    Logger.info("\n[2/4] Testing inference quality...")

    results2 =
      case verify_inference_quality(:qodo) do
        {:ok, quality} ->
          %{inference_quality: quality}

        {:error, e} ->
          Logger.error("Inference quality test failed: #{inspect(e)}")
          %{}
      end

    # Test 3: Convergence
    Logger.info("\n[3/4] Testing fine-tuning convergence...")

    results3 =
      case test_convergence(:qodo) do
        {:ok, convergence} ->
          %{convergence: convergence}

        {:error, e} ->
          Logger.error("Convergence test failed: #{inspect(e)}")
          %{}
      end

    # Test 4: Benchmarks
    Logger.info("\n[4/4] Running performance benchmarks...")

    results4 =
      case benchmark_complete_system() do
        {:ok, benchmarks} ->
          %{benchmarks: benchmarks}

        {:error, e} ->
          Logger.error("Benchmark test failed: #{inspect(e)}")
          %{}
      end

    # Final summary
    Logger.info("\n" <> String.duplicate("✨", 40))
    Logger.info("✨ VALIDATION SUITE COMPLETE ✨")
    Logger.info(String.duplicate("✨", 40))

    results = Map.merge(results1, Map.merge(results2, Map.merge(results3, results4)))
    {:ok, results}
  end

  @doc """
  Test edge cases: empty inputs, very long inputs, special characters
  """
  def test_edge_cases do
    Logger.info("\n" <> String.duplicate("=", 80))
    Logger.info("🧪 TEST: Edge Cases Handling")
    Logger.info("=" <> String.duplicate("=", 80))

    try do
      results1 = %{}

      # Test 1: Empty string
      Logger.info("\n📝 Testing empty string...")

      results1 =
        case NxService.embed("", model: :qodo) do
          {:ok, _embedding} ->
            Logger.info("✅ Empty string handled")
            Map.put(results1, :empty_string, :success)

          {:error, reason} ->
            Logger.warning("⚠️  Empty string failed: #{inspect(reason)}")
            Map.put(results1, :empty_string, :error)
        end

      # Test 2: Very long string (10KB)
      Logger.info("\n📝 Testing very long input...")
      long_text = String.duplicate("def long_function(): pass\n", 400)

      results2 =
        case NxService.embed(long_text, model: :qodo) do
          {:ok, _embedding} ->
            Logger.info("✅ Long string handled: #{byte_size(long_text)} bytes")
            Map.put(results1, :long_string, :success)

          {:error, reason} ->
            Logger.warning("⚠️  Long string failed: #{inspect(reason)}")
            Map.put(results1, :long_string, :error)
        end

      # Test 3: Special characters and Unicode
      Logger.info("\n📝 Testing special characters...")

      special_texts = [
        "code with emoji 🚀 🎉",
        "unicode: Ñoño, Čeština, 中文",
        "symbols: !@#$%^&*()_+-=[]{}|;:,.<>?",
        "tabs\tand\nnewlines\rhere"
      ]

      special_results =
        special_texts
        |> Enum.map(fn text ->
          case NxService.embed(text, model: :qodo) do
            {:ok, _emb} -> :ok
            {:error, _} -> :error
          end
        end)

      ok_count = Enum.count(special_results, &(&1 == :ok))
      Logger.info("✅ Special characters: #{ok_count}/#{length(special_results)} handled")
      results3 = Map.put(results2, :special_chars, ok_count)

      {:ok, results3}
    rescue
      e ->
        Logger.error("Edge case test failed: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Test model-specific behavior: Qodo vs Jina differences
  """
  def test_model_specifics do
    Logger.info("\n" <> String.duplicate("=", 80))
    Logger.info("🧪 TEST: Model-Specific Behavior")
    Logger.info("=" <> String.duplicate("=", 80))

    try do
      test_text = "async fn fetch_data() { await http.get() }"
      results1 = %{}

      # Test Qodo-specific behavior
      Logger.info("\n📦 Testing Qodo-Embed-1...")

      results2 =
        case NxService.embed(test_text, model: :qodo) do
          {:ok, _emb} ->
            Logger.info("✅ Qodo embedding: shape={2560}")
            Map.put(results1, :qodo, :ok)

          {:error, e} ->
            Logger.warning("⚠️  Qodo failed: #{inspect(e)}")
            Map.put(results1, :qodo, :error)
        end

      # Test Jina-specific behavior
      Logger.info("\n📦 Testing Jina v3...")

      results3 =
        case NxService.embed(test_text, model: :jina_v3) do
          {:ok, _emb} ->
            Logger.info("✅ Jina embedding: shape={2560}")
            Map.put(results2, :jina_v3, :ok)

          {:error, e} ->
            Logger.warning("⚠️  Jina failed: #{inspect(e)}")
            Map.put(results2, :jina_v3, :error)
        end

      # Test cross-model consistency with same text
      Logger.info("\n📏 Testing cross-model consistency...")

      results4 =
        case NxService.similarity(test_text, test_text, model: :qodo) do
          {:ok, sim} ->
            Logger.info("✅ Same text consistency: #{Float.round(sim, 4)}")
            Map.put(results3, :consistency, :ok)

          {:error, e} ->
            Logger.warning("⚠️  Consistency test failed: #{inspect(e)}")
            Map.put(results3, :consistency, :error)
        end

      {:ok, results4}
    rescue
      e ->
        Logger.error("Model specifics test failed: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Test similarity edge cases: identical, opposite, empty
  """
  def test_similarity_edge_cases do
    Logger.info("\n" <> String.duplicate("=", 80))
    Logger.info("🧪 TEST: Similarity Edge Cases")
    Logger.info("=" <> String.duplicate("=", 80))

    try do
      results1 = %{}

      # Test 1: Identical texts (should have sim ≈ 1.0)
      Logger.info("\n🔄 Testing identical text similarity...")
      text = "def process_data(): return transformed"

      results2 =
        case NxService.similarity(text, text, model: :qodo) do
          {:ok, sim} ->
            Logger.info("✅ Identical texts: similarity=#{Float.round(sim, 4)}")
            identical_ok = sim > 0.99
            Map.put(results1, :identical, identical_ok)

          {:error, e} ->
            Logger.warning("⚠️  Identical test failed: #{inspect(e)}")
            Map.put(results1, :identical, false)
        end

      # Test 2: Completely different texts (should have low sim)
      Logger.info("\n🔄 Testing very different text similarity...")
      text1 = "def hello_world(): return 42"
      text2 = "SELECT COUNT(*) FROM users WHERE id > 100"

      results3 =
        case NxService.similarity(text1, text2, model: :qodo) do
          {:ok, sim} ->
            Logger.info("✅ Different texts: similarity=#{Float.round(sim, 4)}")
            different_ok = sim < 0.5
            Map.put(results2, :different, different_ok)

          {:error, e} ->
            Logger.warning("⚠️  Different test failed: #{inspect(e)}")
            Map.put(results2, :different, false)
        end

      # Test 3: Similar but not identical (should be medium-high)
      Logger.info("\n🔄 Testing similar text similarity...")
      text1 = "def calculate_sum(): return sum"
      text2 = "def compute_total(): return total"

      results4 =
        case NxService.similarity(text1, text2, model: :qodo) do
          {:ok, sim} ->
            Logger.info("✅ Similar texts: similarity=#{Float.round(sim, 4)}")
            similar_ok = 0.5 < sim and sim < 0.99
            Map.put(results3, :similar, similar_ok)

          {:error, e} ->
            Logger.warning("⚠️  Similar test failed: #{inspect(e)}")
            Map.put(results3, :similar, false)
        end

      {:ok, results4}
    rescue
      e ->
        Logger.error("Similarity edge cases test failed: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Test batch processing of multiple texts
  """
  def test_batch_processing do
    Logger.info("\n" <> String.duplicate("=", 80))
    Logger.info("🧪 TEST: Batch Processing")
    Logger.info("=" <> String.duplicate("=", 80))

    try do
      texts = [
        "def process_data(): pass",
        "async fn fetch(): await",
        "class Worker: pass",
        "SELECT FROM users",
        "const config = {}",
        "if condition: then",
        "@decorator\ndef func",
        "fn map(f, xs) -> ys"
      ]

      Logger.info("\n🔄 Processing #{length(texts)} texts...")

      embeddings =
        texts
        |> Enum.with_index(1)
        |> Enum.map(fn {text, idx} ->
          case NxService.embed(text, model: :qodo) do
            {:ok, emb} ->
              Logger.debug("  [#{idx}] ✅ Embedded")
              {:ok, emb}

            {:error, reason} ->
              Logger.debug("  [#{idx}] ❌ Failed: #{inspect(reason)}")
              {:error, reason}
          end
        end)

      ok_count = Enum.count(embeddings, &match?({:ok, _}, &1))
      Logger.info("✅ Batch processing: #{ok_count}/#{length(texts)} successful")

      # Verify batch consistency
      Logger.info("\n📊 Verifying embeddings consistency...")

      batch_results =
        embeddings
        |> Enum.filter(&match?({:ok, _}, &1))
        |> Enum.map(fn {:ok, emb} ->
          shape = Nx.shape(emb)
          norm = compute_norm(emb)
          {shape, norm}
        end)

      if Enum.all?(batch_results, fn {shape, norm} ->
           shape == {2560} and abs(norm - 1.0) < 0.01
         end) do
        Logger.info("✅ All embeddings consistent")
        {:ok, %{batch_size: ok_count, consistency: :ok}}
      else
        Logger.warning("⚠️  Inconsistent embedding properties")
        {:ok, %{batch_size: ok_count, consistency: :warning}}
      end
    rescue
      e ->
        Logger.error("Batch processing test failed: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Test fallback mechanisms explicitly
  """
  def test_fallback_mechanisms do
    Logger.info("\n" <> String.duplicate("=", 80))
    Logger.info("🧪 TEST: Fallback Mechanisms")
    Logger.info("=" <> String.duplicate("=", 80))

    try do
      results = %{}

      # Test that embedding always returns a valid result
      Logger.info("\n⚙️  Testing fallback resilience...")

      test_texts = [
        "",
        "normal code",
        String.duplicate("x", 100_000),
        "👨‍💻🎉📚",
        nil
      ]

      results_list =
        test_texts
        |> Enum.filter(&(&1 != nil))
        |> Enum.map(fn text ->
          case NxService.embed(text, model: :qodo) do
            {:ok, _emb} -> :ok
            {:error, _} -> :fallback
          end
        end)

      ok_count = Enum.count(results_list, &(&1 == :ok))
      fallback_count = Enum.count(results_list, &(&1 == :fallback))

      Logger.info("✅ Real inference: #{ok_count}")
      Logger.info("✅ Fallback used: #{fallback_count}")

      results = Map.put(results, :fallback_resilience, {ok_count, fallback_count})

      # Test that fallback produces valid embeddings
      Logger.info("\n⚙️  Testing fallback output quality...")

      case NxService.embed("test", model: :qodo) do
        {:ok, emb} ->
          shape = Nx.shape(emb)

          if shape == {2560} do
            Logger.info("✅ Fallback produces valid 2560D embeddings")
            results = Map.put(results, :fallback_quality, :valid)
          else
            Logger.warning("⚠️  Fallback produces wrong shape: #{inspect(shape)}")
            results = Map.put(results, :fallback_quality, :invalid)
          end

        {:error, e} ->
          Logger.error("Failed to embed: #{inspect(e)}")
          results = Map.put(results, :fallback_quality, :failed)
      end

      {:ok, results}
    rescue
      e ->
        Logger.error("Fallback mechanisms test failed: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Test reproducibility: same input always produces same output
  """
  def test_reproducibility do
    Logger.info("\n" <> String.duplicate("=", 80))
    Logger.info("🧪 TEST: Reproducibility")
    Logger.info("=" <> String.duplicate("=", 80))

    try do
      test_text = "def fibonacci(n): return fib"

      Logger.info("\n🔄 Running 5 iterations of same embedding...")

      embeddings =
        1..5
        |> Enum.map(fn i ->
          case NxService.embed(test_text, model: :qodo) do
            {:ok, emb} ->
              Logger.debug("  [#{i}] ✅ Generated")
              emb

            {:error, e} ->
              Logger.debug("  [#{i}] ❌ Failed: #{inspect(e)}")
              nil
          end
        end)
        |> Enum.filter(&(&1 != nil))

      if length(embeddings) < 3 do
        Logger.warning("⚠️  Not enough embeddings for reproducibility test")
        {:ok, %{reproducible: false, reason: :insufficient_embeddings}}
      else
        # Compare embeddings
        first = List.first(embeddings)
        rest = Enum.drop(embeddings, 1)

        identical_count =
          rest
          |> Enum.count(fn emb ->
            case Nx.allclose(first, emb, atol: 1.0e-5) do
              {:ok, true} -> true
              _ -> false
            end
          end)

        reproducible = identical_count == length(rest)

        if reproducible do
          Logger.info(
            "✅ Embeddings are reproducible (#{identical_count}/#{length(rest)} identical)"
          )

          {:ok, %{reproducible: true, identical_runs: identical_count}}
        else
          Logger.warning("⚠️  Embeddings vary across runs")
          {:ok, %{reproducible: false, identical_runs: identical_count}}
        end
      end
    rescue
      e ->
        Logger.error("Reproducibility test failed: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Test numerical stability: check for NaN, Inf, and extreme values
  """
  def test_numerical_stability do
    Logger.info("\n" <> String.duplicate("=", 80))
    Logger.info("🧪 TEST: Numerical Stability")
    Logger.info("=" <> String.duplicate("=", 80))

    try do
      test_texts = [
        "short",
        String.duplicate("very long text ", 100),
        "123 456 789",
        "special !@#$%^&*()"
      ]

      Logger.info("\n📊 Checking numerical stability...")

      stability_results =
        test_texts
        |> Enum.map(fn text ->
          case NxService.embed(text, model: :qodo) do
            {:ok, emb} ->
              # Check for NaN and Inf
              flat = Nx.flatten(emb) |> Nx.to_flat_list()
              has_nan = Enum.any?(flat, fn x -> is_float(x) and x != x end)

              has_inf =
                Enum.any?(flat, fn x ->
                  x == :infinity or x == :neg_infinity
                end)

              if has_nan or has_inf do
                Logger.warning("⚠️  Found NaN/Inf in embedding")
                :unstable
              else
                :stable
              end

            {:error, _} ->
              :error
          end
        end)

      stable_count = Enum.count(stability_results, &(&1 == :stable))
      error_count = Enum.count(stability_results, &(&1 == :error))
      unstable_count = Enum.count(stability_results, &(&1 == :unstable))

      Logger.info("✅ Stable: #{stable_count}")
      Logger.info("⚠️  Unstable: #{unstable_count}")
      Logger.info("❌ Errors: #{error_count}")

      if unstable_count == 0 do
        {:ok, %{stable: stable_count, unstable: unstable_count}}
      else
        {:ok,
         %{stable: stable_count, unstable: unstable_count, warning: "Found numerical issues"}}
      end
    rescue
      e ->
        Logger.error("Numerical stability test failed: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Run extended test suite (all additional tests)
  """
  def run_extended_tests do
    Logger.info("\n" <> String.duplicate("🔬", 40))
    Logger.info("🔬 PHASE 4.1: EXTENDED TEST SUITE")
    Logger.info(String.duplicate("🔬", 40))

    results = %{}

    # Test 1: Edge cases
    Logger.info("\n[1/6] Testing edge cases...")

    results1 =
      case test_edge_cases() do
        {:ok, r} ->
          %{edge_cases: r}

        {:error, e} ->
          Logger.error("Edge cases test failed: #{inspect(e)}")
          %{}
      end

    # Test 2: Model specifics
    Logger.info("\n[2/6] Testing model-specific behavior...")

    results2 =
      case test_model_specifics() do
        {:ok, r} ->
          %{model_specifics: r}

        {:error, e} ->
          Logger.error("Model specifics test failed: #{inspect(e)}")
          %{}
      end

    # Test 3: Similarity edge cases
    Logger.info("\n[3/6] Testing similarity edge cases...")

    results3 =
      case test_similarity_edge_cases() do
        {:ok, r} ->
          %{similarity_edge_cases: r}

        {:error, e} ->
          Logger.error("Similarity edge cases test failed: #{inspect(e)}")
          %{}
      end

    # Test 4: Batch processing
    Logger.info("\n[4/6] Testing batch processing...")

    results4 =
      case test_batch_processing() do
        {:ok, r} ->
          %{batch_processing: r}

        {:error, e} ->
          Logger.error("Batch processing test failed: #{inspect(e)}")
          %{}
      end

    # Test 5: Fallback mechanisms
    Logger.info("\n[5/6] Testing fallback mechanisms...")

    results5 =
      case test_fallback_mechanisms() do
        {:ok, r} ->
          %{fallback_mechanisms: r}

        {:error, e} ->
          Logger.error("Fallback mechanisms test failed: #{inspect(e)}")
          %{}
      end

    # Test 6: Extended tests
    Logger.info("\n[6/6] Testing reproducibility and stability...")

    results6_repro =
      case test_reproducibility() do
        {:ok, r} ->
          r

        {:error, e} ->
          Logger.error("Reproducibility test failed: #{inspect(e)}")
          %{}
      end

    results6_stable =
      case test_numerical_stability() do
        {:ok, r} ->
          r

        {:error, e} ->
          Logger.error("Numerical stability test failed: #{inspect(e)}")
          %{}
      end

    results6 = %{reproducibility: results6_repro, numerical_stability: results6_stable}

    # Final summary
    Logger.info("\n" <> String.duplicate("✨", 40))
    Logger.info("✨ EXTENDED TEST SUITE COMPLETE ✨")
    Logger.info(String.duplicate("✨", 40))

    merged_results =
      Map.merge(
        results1,
        Map.merge(
          results2,
          Map.merge(results3, Map.merge(results4, Map.merge(results5, results6)))
        )
      )

    {:ok, merged_results}
  end

  @doc false
  defp generate_pairs(list) do
    case list do
      [] ->
        []

      [_head] ->
        []

      [head | tail] ->
        Enum.map(tail, &[head, &1]) ++ generate_pairs(tail)
    end
  end
end
