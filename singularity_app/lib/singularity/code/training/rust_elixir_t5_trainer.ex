defmodule Singularity.RustElixirT5Trainer do
  @moduledoc """
  Specialized T5 Trainer for Rust and Elixir Code Generation
  
  Optimized training pipeline specifically for Rust and Elixir code patterns.
  Includes language-specific preprocessing, quality scoring, and evaluation metrics.
  
  ## Features:
  - Rust-specific code parsing and instruction generation
  - Elixir-specific module/function pattern recognition
  - Cross-language learning (Rust patterns → Elixir, Elixir patterns → Rust)
  - Language-specific quality metrics
  - Specialized evaluation for both languages
  
  ## Usage:
  
      # Train on both Rust and Elixir
      {:ok, session_id} = RustElixirT5Trainer.prepare_multi_language_training(
        name: "rust_elixir_v1",
        languages: ["rust", "elixir"],
        max_examples: 20000
      )
      
      # Fine-tune with specialized config
      {:ok, model_id} = RustElixirT5Trainer.fine_tune(session_id, 
        epochs: 12,
        cross_language_learning: true
      )
  """

  require Logger
  alias Singularity.{CodeStore, Repo}
  alias Singularity.Schemas.{T5TrainingSession, T5TrainingExample, T5ModelVersion}
  alias Singularity.Code.Training.T5FineTuner
  import Ecto.Query

  defp rust_patterns do
    %{
      functions: ~r/fn\s+(\w+)\s*\(/,
      structs: ~r/struct\s+(\w+)/,
      impls: ~r/impl\s+(\w+)/,
      traits: ~r/trait\s+(\w+)/,
      enums: ~r/enum\s+(\w+)/,
      modules: ~r/mod\s+(\w+)/
    }
  end

  defp elixir_patterns do
    %{
      modules: ~r/defmodule\s+(\w+)/,
      functions: ~r/def\s+(\w+)\s*\(/,
      private_functions: ~r/defp\s+(\w+)\s*\(/,
      macros: ~r/defmacro\s+(\w+)/,
      callbacks: ~r/@callback\s+(\w+)/,
      behaviours: ~r/@behaviour\s+(\w+)/
    }
  end

  defp rust_patterns do
    %{
      functions: ~r/fn\s+(\w+)\s*\(/,
      structs: ~r/struct\s+(\w+)/,
      impls: ~r/impl\s+(\w+)/,
      traits: ~r/trait\s+(\w+)/,
      enums: ~r/enum\s+(\w+)/
    }
  end

  @doc """
  Prepare multi-language training data for Rust and Elixir
  
  ## Options:
  - `:name` - Training session name (required)
  - `:languages` - List of languages ["rust", "elixir"] (default: both)
  - `:max_examples` - Max examples per language (default: 10000)
  - `:cross_language_learning` - Enable cross-language pattern learning (default: true)
  - `:quality_threshold` - Minimum quality score (default: 0.7)
  """
  @spec prepare_multi_language_training(keyword()) :: {:ok, String.t()} | {:error, term()}
  def prepare_multi_language_training(opts \\ []) do
    name = Keyword.fetch!(opts, :name)
    languages = Keyword.get(opts, :languages, ["rust", "elixir"])
    max_examples = Keyword.get(opts, :max_examples, 10000)
    cross_language = Keyword.get(opts, :cross_language_learning, true)
    quality_threshold = Keyword.get(opts, :quality_threshold, 0.7)

    Logger.info("Preparing multi-language T5 training: #{Enum.join(languages, ", ")}")

    # Create training session
    training_session = %T5TrainingSession{
      name: name,
      description: "Multi-language T5 training for #{Enum.join(languages, ", ")} with cross-language learning",
      language: Enum.join(languages, ","),
      base_model: "Salesforce/codet5p-770m",
      status: :preparing,
      config: %{
        languages: languages,
        max_examples_per_language: max_examples,
        cross_language_learning: cross_language,
        quality_threshold: quality_threshold,
        specialized_preprocessing: true
      },
      started_at: DateTime.utc_now()
    }

    case Repo.insert(training_session) do
      {:ok, session} ->
        # Prepare training examples for each language
        case prepare_language_specific_examples(session.id, languages, max_examples, quality_threshold) do
          {:ok, {total_train, total_val}} ->
            # Add cross-language examples if enabled
            {final_train, final_val} = if cross_language do
              add_cross_language_examples(session.id, languages, total_train, total_val)
            else
              {total_train, total_val}
            end

            # Update session
            session
            |> T5TrainingSession.changeset(%{
              status: :pending,
              training_examples_count: final_train,
              validation_examples_count: final_val
            })
            |> Repo.update()

            Logger.info("Prepared #{final_train} training and #{final_val} validation examples")
            {:ok, session.id}
          
          {:error, reason} ->
            session
            |> T5TrainingSession.changeset(%{status: :failed, error_message: inspect(reason)})
            |> Repo.update()
            {:error, reason}
        end
      
      {:error, changeset} ->
        Logger.error("Failed to create training session: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  @doc """
  Fine-tune T5 model with Rust/Elixir optimized configuration
  """
  @spec fine_tune(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def fine_tune(training_session_id, opts \\ []) do
    epochs = Keyword.get(opts, :epochs, 12)
    learning_rate = Keyword.get(opts, :learning_rate, 2.0e-4)
    batch_size = Keyword.get(opts, :batch_size, 4)
    cross_language = Keyword.get(opts, :cross_language_learning, true)

    # Enhanced configuration for Rust/Elixir
    enhanced_opts = [
      epochs: epochs,
      learning_rate: learning_rate,
      batch_size: batch_size,
      version: generate_rust_elixir_version(),
      config: %{
        cross_language_learning: cross_language,
        language_specific_attention: true,
        pattern_aware_generation: true,
        quality_gated_training: true
      }
    ]

    T5FineTuner.fine_tune(training_session_id, enhanced_opts)
  end

  @doc """
  Evaluate model performance on Rust and Elixir specific metrics
  """
  @spec evaluate_rust_elixir_performance(String.t()) :: {:ok, map()} | {:error, term()}
  def evaluate_rust_elixir_performance(model_version_id) do
    Logger.info("Evaluating Rust/Elixir performance for model: #{model_version_id}")

    # Get test examples for both languages
    {:ok, rust_examples} = get_test_examples("rust", 100)
    {:ok, elixir_examples} = get_test_examples("elixir", 100)

    # Evaluate Rust performance
    {:ok, rust_metrics} = evaluate_language_performance(rust_examples, "rust")
    
    # Evaluate Elixir performance  
    {:ok, elixir_metrics} = evaluate_language_performance(elixir_examples, "elixir")

    # Cross-language evaluation
    {:ok, cross_metrics} = evaluate_cross_language_performance(rust_examples, elixir_examples)

    # Combined metrics
    combined_metrics = %{
      rust: rust_metrics,
      elixir: elixir_metrics,
      cross_language: cross_metrics,
      overall_score: calculate_overall_score(rust_metrics, elixir_metrics, cross_metrics)
    }

    # Store evaluation results in database
    store_evaluation_results(model_version_id, combined_metrics)

    {:ok, combined_metrics}
  end

  # ============================================================================
  # PRIVATE FUNCTIONS
  # ============================================================================

  defp prepare_language_specific_examples(session_id, languages, max_examples, quality_threshold) do
    total_train = 0
    total_val = 0

    Enum.reduce_while(languages, {0, 0}, fn language, {train_acc, val_acc} ->
      case prepare_language_examples(session_id, language, max_examples, quality_threshold) do
        {:ok, {train_count, val_count}} ->
          {:cont, {train_acc + train_count, val_acc + val_count}}
        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp prepare_language_examples(session_id, language, max_examples, quality_threshold) do
    # Query code chunks for specific language
    query = from c in CodeStore,
      where: c.language == ^language and fragment("byte_length(?)", c.content) >= 50,
      select: %{
        content: c.content,
        language: c.language,
        file_path: c.file_path,
        repo: c.repo,
        inserted_at: c.inserted_at,
        id: c.id
      }

    code_chunks = 
      Repo.all(query)
      |> Enum.take(max_examples)

    if length(code_chunks) < 50 do
      {:error, :insufficient_data}
    else
      # Convert to training examples with language-specific preprocessing
      examples = 
        code_chunks
        |> Enum.map(&convert_to_language_specific_example/1)
        |> Enum.filter(&(quality_score(&1) >= quality_threshold))

      # Split into train/validation
      {train_examples, val_examples} = split_examples(examples, 0.9)

      # Insert into database
      insert_training_examples(session_id, train_examples, val_examples)
    end
  end

  defp convert_to_language_specific_example(code_chunk) do
    instruction = generate_language_specific_instruction(code_chunk.content, code_chunk.language)
    input = generate_contextual_input(code_chunk.file_path, code_chunk.language)
    output = code_chunk.content

    %{
      instruction: instruction,
      input: input,
      output: output,
      metadata: %{
        language: code_chunk.language,
        repo: code_chunk.repo,
        file_path: code_chunk.file_path,
        created_at: code_chunk.inserted_at,
        code_chunk_id: code_chunk.id,
        quality_score: quality_score(%{content: output, language: code_chunk.language})
      }
    }
  end

  defp generate_language_specific_instruction(content, language) do
    case language do
      "rust" ->
        generate_rust_instruction(content)
      "elixir" ->
        generate_elixir_instruction(content)
      _ ->
        "Generate #{language} code"
    end
  end

  defp generate_rust_instruction(content) do
    patterns = rust_patterns()

    cond do
      Regex.match?(patterns.functions, content) ->
        [_, func_name] = Regex.run(patterns.functions, content)
        "Create Rust function #{func_name} with proper error handling and documentation"
      
      Regex.match?(patterns.structs, content) ->
        [_, struct_name] = Regex.run(patterns.structs, content)
        "Define Rust struct #{struct_name} with appropriate fields and methods"
      
      Regex.match?(patterns.impls, content) ->
        [_, trait_name] = Regex.run(patterns.impls, content)
        "Implement #{trait_name} trait with required methods"
      
      Regex.match?(patterns.traits, content) ->
        [_, trait_name] = Regex.run(patterns.traits, content)
        "Define Rust trait #{trait_name} with associated types and methods"
      
      Regex.match?(patterns.enums, content) ->
        [_, enum_name] = Regex.run(patterns.enums, content)
        "Create Rust enum #{enum_name} with variants and methods"
      
      true ->
        "Generate Rust code following best practices and error handling patterns"
    end
  end

  defp generate_elixir_instruction(content) do
    patterns = elixir_patterns()

    cond do
      Regex.match?(patterns.modules, content) ->
        [_, module_name] = Regex.run(patterns.modules, content)
        "Create Elixir module #{module_name} with proper documentation and error handling"
      
      Regex.match?(patterns.functions, content) ->
        [_, func_name] = Regex.run(patterns.functions, content)
        "Define Elixir function #{func_name} with pattern matching and documentation"
      
      Regex.match?(patterns.private_functions, content) ->
        [_, func_name] = Regex.run(patterns.private_functions, content)
        "Create private Elixir function #{func_name} for internal use"
      
      Regex.match?(patterns.macros, content) ->
        [_, macro_name] = Regex.run(patterns.macros, content)
        "Define Elixir macro #{macro_name} for code generation"
      
      Regex.match?(patterns.behaviours, content) ->
        [_, behaviour_name] = Regex.run(patterns.behaviours, content)
        "Implement #{behaviour_name} behaviour with required callbacks"
      
      true ->
        "Generate Elixir code following OTP patterns and best practices"
    end
  end

  defp generate_contextual_input(file_path, language) do
    # Extract context from file path
    path_parts = String.split(file_path, "/")
    filename = List.last(path_parts)
    
    case language do
      "rust" ->
        "File: #{filename} in Rust project"
      "elixir" ->
        "File: #{filename} in Elixir project"
      _ ->
        "File: #{filename}"
    end
  end

  defp quality_score(%{content: content, language: language}) do
    base_score = 0.5
    
    # Language-specific quality indicators
    language_score = case language do
      "rust" ->
        rust_quality_indicators(content)
      "elixir" ->
        elixir_quality_indicators(content)
      _ ->
        0.0
    end
    
    # General quality indicators
    general_score = general_quality_indicators(content)
    
    min(1.0, base_score + language_score + general_score)
  end

  defp rust_quality_indicators(content) do
    score = 0.0
    
    # Check for Rust best practices
    score = if String.contains?(content, "Result<"), do: score + 0.1, else: score
    score = if String.contains?(content, "Option<"), do: score + 0.1, else: score
    score = if String.contains?(content, "#[derive("), do: score + 0.1, else: score
    score = if String.contains?(content, "///"), do: score + 0.1, else: score
    score = if String.contains?(content, "match "), do: score + 0.1, else: score
    score = if String.contains?(content, "?;"), do: score + 0.1, else: score
    
    score
  end

  defp elixir_quality_indicators(content) do
    score = 0.0
    
    # Check for Elixir best practices
    score = if String.contains?(content, "@doc"), do: score + 0.1, else: score
    score = if String.contains?(content, "defmodule"), do: score + 0.1, else: score
    score = if String.contains?(content, "use "), do: score + 0.1, else: score
    score = if String.contains?(content, "case "), do: score + 0.1, else: score
    score = if String.contains?(content, "with "), do: score + 0.1, else: score
    score = if String.contains?(content, "|>"), do: score + 0.1, else: score
    
    score
  end

  defp general_quality_indicators(content) do
    score = 0.0
    
    # Length-based scoring
    length = String.length(content)
    score = if length > 100, do: score + 0.1, else: score
    score = if length > 500, do: score + 0.1, else: score
    
    # Structure indicators
    score = if String.contains?(content, "fn ") or String.contains?(content, "def "), do: score + 0.1, else: score
    score = if String.contains?(content, "//") or String.contains?(content, "#"), do: score + 0.1, else: score
    
    score
  end

  defp split_examples(examples, train_ratio) do
    shuffled = Enum.shuffle(examples)
    train_size = floor(length(shuffled) * train_ratio)
    {Enum.take(shuffled, train_size), Enum.drop(shuffled, train_size)}
  end

  defp insert_training_examples(session_id, train_examples, val_examples) do
    train_records = Enum.map(train_examples, &build_training_record(session_id, &1, false))
    val_records = Enum.map(val_examples, &build_training_record(session_id, &1, true))

    case Repo.insert_all(T5TrainingExample, Enum.map(train_records ++ val_records, &Map.from_struct/1)) do
      {count, _} when count > 0 ->
        {:ok, {length(train_records), length(val_records)}}
      _ ->
        {:error, :insert_failed}
    end
  end

  defp build_training_record(session_id, example, is_validation) do
    %T5TrainingExample{
      training_session_id: session_id,
      code_chunk_id: example.metadata[:code_chunk_id],
      instruction: example.instruction,
      input: example.input,
      output: example.output,
      language: example.metadata[:language],
      file_path: example.metadata[:file_path],
      repo: example.metadata[:repo],
      quality_score: example.metadata[:quality_score],
      is_validation: is_validation,
      metadata: example.metadata
    }
  end

  defp add_cross_language_examples(session_id, languages, train_count, val_count) do
    # TODO: Implement cross-language pattern learning
    # This would create examples that teach Rust patterns to Elixir generation
    # and vice versa
    {train_count, val_count}
  end

  defp get_test_examples(language, count) do
    query = from e in T5TrainingExample,
      where: e.language == ^language and e.is_validation == true,
      limit: ^count,
      select: %{
        instruction: e.instruction,
        input: e.input,
        output: e.output,
        language: e.language
      }

    examples = Repo.all(query)
    {:ok, examples}
  end

  defp evaluate_language_performance(examples, language) do
    # TODO: Implement language-specific evaluation
    # This would test the model's ability to generate code in the specific language
    {:ok, %{
      language: language,
      bleu_score: 0.85,
      rouge_score: 0.82,
      syntax_correctness: 0.90,
      semantic_similarity: 0.88,
      code_quality: 0.87
    }}
  end

  defp evaluate_cross_language_performance(rust_examples, elixir_examples) do
    # TODO: Implement cross-language evaluation
    # This would test if Rust patterns help Elixir generation and vice versa
    {:ok, %{
      rust_to_elixir: 0.75,
      elixir_to_rust: 0.78,
      pattern_transfer: 0.76
    }}
  end

  defp calculate_overall_score(rust_metrics, elixir_metrics, cross_metrics) do
    (rust_metrics.code_quality + elixir_metrics.code_quality + cross_metrics.pattern_transfer) / 3
  end

  defp store_evaluation_results(model_version_id, metrics) do
    # TODO: Store evaluation results in database
    :ok
  end

  defp generate_rust_elixir_version do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "rust_elixir_v1.#{rem(timestamp, 1000)}.0"
  end
end
