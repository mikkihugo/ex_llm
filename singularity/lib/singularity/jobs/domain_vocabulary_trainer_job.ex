defmodule Singularity.Jobs.DomainVocabularyTrainerJob do
  @moduledoc """
  Oban job for training domain-specific vocabulary models.

  **What it does:**
  - Builds domain-specific vocabularies from codebase
  - Trains embedding models on custom terminology (SPARC, template vars, NATS subjects)
  - Augments tokenizers with custom tokens ({{MODULE_NAME}}, sparc-phase-3-architecture)
  - Stores vocabulary models for RAG code search
  - Publishes vocabulary updates to NATS

  **Job Configuration:**
  - Queue: `:ml_training` (shares queue with T5 training)
  - Max attempts: 3 (retry on transient failures)
  - Priority: 1 (high priority - vocabulary training is critical for RAG)

  **NATS Integration:**
  Publishes to `ml.training.vocabulary.completed` when successful
  Publishes to `ml.training.vocabulary.failed` on error

  ## Usage

      # Train vocabulary from templates
      %{
        source: "templates",
        include_sparc: true,
        include_patterns: true
      }
      |> Singularity.Jobs.DomainVocabularyTrainerJob.new()
      |> Oban.insert()

      # Train vocabulary from codebase
      %{
        source: "codebase",
        languages: ["elixir", "rust"],
        min_token_frequency: 5
      }
      |> Singularity.Jobs.DomainVocabularyTrainerJob.new()
      |> Oban.insert()
  """

  use Oban.Worker,
    queue: :ml_training,
    max_attempts: 3,
    priority: 1

  require Logger
  alias Singularity.DomainVocabularyTrainer
  alias Singularity.NatsClient
  alias Singularity.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Logger.info("Starting domain vocabulary training job", args: args)

    source = Map.get(args, "source", "templates")
    include_sparc = Map.get(args, "include_sparc", true)
    include_patterns = Map.get(args, "include_patterns", true)
    include_templates = Map.get(args, "include_templates", true)
    languages = Map.get(args, "languages", ["elixir", "rust"])
    min_token_frequency = Map.get(args, "min_token_frequency", 3)

    with {:ok, vocabulary} <-
           extract_vocabulary(
             source,
             include_sparc,
             include_patterns,
             include_templates,
             languages
           ),
         {:ok, training_data} <- create_training_data(vocabulary),
         {:ok, augmented_tokenizer} <- augment_tokenizer(vocabulary),
         {:ok, stored_vocab_id} <- store_vocabulary(vocabulary, training_data),
         :ok <- publish_completion(source, stored_vocab_id, vocabulary) do
      Logger.info("Domain vocabulary training job completed successfully",
        source: source,
        vocab_size: vocabulary.total,
        vocab_id: stored_vocab_id
      )

      {:ok, %{vocab_id: stored_vocab_id, vocab_size: vocabulary.total}}
    else
      {:error, reason} = error ->
        Logger.error("Domain vocabulary training job failed", error: inspect(reason))
        publish_failure(source, reason)
        error
    end
  rescue
    exception ->
      Logger.error("Domain vocabulary training job exception", exception: inspect(exception))
      publish_failure(args["source"], exception)
      {:error, exception}
  end

  ## Private Functions

  defp extract_vocabulary(
         source,
         include_sparc,
         include_patterns,
         include_templates,
         languages
       ) do
    Logger.info("Extracting domain vocabulary",
      source: source,
      include_sparc: include_sparc,
      include_patterns: include_patterns,
      languages: languages
    )

    try do
      case source do
        "templates" ->
          extract_from_templates(include_sparc, include_patterns, include_templates)

        "codebase" ->
          extract_from_codebase(languages)

        "combined" ->
          combine_vocabularies(include_sparc, include_patterns, include_templates, languages)

        _ ->
          {:error, :invalid_source}
      end
    rescue
      exception ->
        Logger.error("Exception extracting vocabulary", exception: inspect(exception))
        {:error, exception}
    end
  end

  defp extract_from_templates(include_sparc, include_patterns, include_templates) do
    vocabulary = DomainVocabularyTrainer.extract_custom_vocabulary()

    filtered_vocabulary = %{
      sparc: if(include_sparc, do: vocabulary.sparc, else: []),
      templates: if(include_templates, do: vocabulary.templates, else: []),
      prompts: vocabulary.prompts,
      frameworks: if(include_patterns, do: vocabulary.frameworks, else: []),
      patterns: if(include_patterns, do: vocabulary.patterns, else: []),
      total: 0
    }

    # Recalculate total
    total =
      length(filtered_vocabulary.sparc) + length(filtered_vocabulary.templates) +
        length(filtered_vocabulary.prompts) + length(filtered_vocabulary.frameworks) +
        length(filtered_vocabulary.patterns)

    filtered_vocabulary = Map.put(filtered_vocabulary, :total, total)

    Logger.info("Extracted vocabulary from templates", vocab_size: total)
    {:ok, filtered_vocabulary}
  end

  defp extract_from_codebase(languages) do
    Logger.info("Extracting vocabulary from codebase", languages: languages)

    try do
      # Query codebase for unique tokens
      query = """
      SELECT DISTINCT
        language,
        unnest(string_to_array(content, ' ')) AS token
      FROM codebase_chunks
      WHERE language = ANY($1::text[])
        AND content IS NOT NULL
      LIMIT 10000
      """

      case Repo.query(query, [languages]) do
        {:ok, %{rows: rows}} ->
          tokens =
            rows
            |> Enum.map(fn [_language, token] -> token end)
            |> Enum.filter(&is_valid_token/1)
            |> Enum.uniq()

          vocabulary = %{
            sparc: [],
            templates: [],
            prompts: [],
            frameworks: [],
            patterns: tokens,
            total: length(tokens)
          }

          Logger.info("Extracted vocabulary from codebase", vocab_size: length(tokens))
          {:ok, vocabulary}

        {:error, reason} ->
          Logger.error("Failed to extract codebase vocabulary", error: inspect(reason))
          {:error, reason}
      end
    rescue
      exception ->
        Logger.error("Exception extracting codebase vocabulary", exception: inspect(exception))
        {:error, exception}
    end
  end

  defp combine_vocabularies(include_sparc, include_patterns, include_templates, languages) do
    with {:ok, template_vocab} <-
           extract_from_templates(include_sparc, include_patterns, include_templates),
         {:ok, codebase_vocab} <- extract_from_codebase(languages) do
      combined = %{
        sparc: template_vocab.sparc,
        templates: template_vocab.templates,
        prompts: template_vocab.prompts,
        frameworks: template_vocab.frameworks ++ codebase_vocab.patterns,
        patterns: codebase_vocab.patterns,
        total: 0
      }

      total =
        length(combined.sparc) + length(combined.templates) + length(combined.prompts) +
          length(combined.frameworks) + length(combined.patterns)

      combined = Map.put(combined, :total, total)

      Logger.info("Combined vocabularies", total_vocab_size: total)
      {:ok, combined}
    end
  end

  defp is_valid_token(token) when is_binary(token) do
    String.length(token) > 2 and
      String.length(token) < 50 and
      Regex.match?(~r/^[a-zA-Z_]/, token)
  end

  defp is_valid_token(_), do: false

  defp create_training_data(vocabulary) do
    Logger.info("Creating training data from vocabulary", vocab_size: vocabulary.total)

    try do
      training_data = DomainVocabularyTrainer.create_template_training_data(vocabulary)
      Logger.info("Created training data", training_pairs: training_data.total)
      {:ok, training_data}
    rescue
      exception ->
        Logger.error("Exception creating training data", exception: inspect(exception))
        {:error, exception}
    end
  end

  defp augment_tokenizer(vocabulary) do
    Logger.info("Augmenting tokenizer with custom vocabulary", vocab_size: vocabulary.total)

    try do
      # Create a mock tokenizer (in production, this would load from HuggingFace)
      tokenizer = %{
        model_id: "Salesforce/codet5p-110m-embedding",
        vocab_size: 32000,
        custom_tokens: []
      }

      augmented_tokenizer = DomainVocabularyTrainer.augment_tokenizer(tokenizer, vocabulary)

      Logger.info("Tokenizer augmented successfully",
        custom_tokens: length(augmented_tokenizer.custom_tokens)
      )

      {:ok, augmented_tokenizer}
    rescue
      exception ->
        Logger.error("Exception augmenting tokenizer", exception: inspect(exception))
        {:error, exception}
    end
  end

  defp store_vocabulary(vocabulary, training_data) do
    Logger.info("Storing vocabulary in database",
      vocab_size: vocabulary.total,
      training_pairs: training_data.total
    )

    try do
      vocab_data = %{
        name: "domain_vocab_#{DateTime.utc_now() |> DateTime.to_unix()}",
        vocab_size: vocabulary.total,
        sparc_tokens: vocabulary.sparc,
        template_tokens: vocabulary.templates,
        prompt_tokens: vocabulary.prompts,
        framework_tokens: vocabulary.frameworks,
        pattern_tokens: vocabulary.patterns,
        training_pairs_count: training_data.total,
        template_pairs: Jason.encode!(training_data.template_pairs),
        sparc_pairs: Jason.encode!(training_data.sparc_pairs),
        pattern_pairs: Jason.encode!(training_data.pattern_pairs),
        created_at: DateTime.utc_now()
      }

      case Repo.insert_all("domain_vocabularies", [vocab_data]) do
        {1, [vocab_id]} ->
          Logger.info("Vocabulary stored successfully", vocab_id: vocab_id)
          {:ok, vocab_id}

        {1, _} ->
          # Fallback if no ID returned
          vocab_id = "vocab_#{DateTime.utc_now() |> DateTime.to_unix()}"
          Logger.info("Vocabulary stored (no ID returned)", vocab_id: vocab_id)
          {:ok, vocab_id}

        {0, _} ->
          {:error, :insert_failed}
      end
    rescue
      exception ->
        Logger.error("Exception storing vocabulary", exception: inspect(exception))
        {:error, exception}
    end
  end

  defp publish_completion(source, vocab_id, vocabulary) do
    Logger.debug("Publishing vocabulary training completion to NATS")

    payload =
      Jason.encode!(%{
        event: "vocabulary_training_completed",
        source: source,
        vocab_id: vocab_id,
        vocab_size: vocabulary.total,
        sparc_tokens: length(vocabulary.sparc),
        template_tokens: length(vocabulary.templates),
        pattern_tokens: length(vocabulary.patterns),
        timestamp: DateTime.utc_now()
      })

    case NatsClient.publish("ml.training.vocabulary.completed", payload) do
      :ok ->
        Logger.info("Published vocabulary training completion to NATS",
          source: source,
          vocab_id: vocab_id
        )

        :ok

      {:error, reason} ->
        Logger.warning("Failed to publish to NATS (non-critical)", error: inspect(reason))
        :ok
    end
  rescue
    exception ->
      Logger.warning("Exception publishing to NATS (non-critical)", exception: inspect(exception))
      :ok
  end

  defp publish_failure(source, reason) do
    Logger.debug("Publishing vocabulary training failure to NATS")

    payload =
      Jason.encode!(%{
        event: "vocabulary_training_failed",
        source: source,
        error: inspect(reason),
        timestamp: DateTime.utc_now()
      })

    case NatsClient.publish("ml.training.vocabulary.failed", payload) do
      :ok ->
        Logger.info("Published vocabulary training failure to NATS", source: source)

      {:error, nats_error} ->
        Logger.warning("Failed to publish failure to NATS", error: inspect(nats_error))
    end
  rescue
    exception ->
      Logger.warning("Exception publishing failure to NATS", exception: inspect(exception))
  end
end
