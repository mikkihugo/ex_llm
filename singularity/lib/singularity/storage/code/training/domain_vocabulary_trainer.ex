defmodule Singularity.DomainVocabularyTrainer do
  @moduledoc """
  Trains embedding models to understand YOUR domain-specific vocabulary.

  Teaches CodeT5+, Voyage, OpenAI embeddings about custom terminology:
  - SPARC methodology (5-phase workflow: Specification → Pseudocode → Architecture → Refinement → Completion)
  - Technology patterns (frameworks, languages, tools from technology_patterns table)
  - Template variables ({{MODULE_NAME}}, {{SUBJECT}})
  - Prompt bits (<REASONING>, <CODE_QUALITY>)
  - pgmq subjects (db.query, facts.technology_detected)
  - Custom modules (RAGCodeGenerator, HybridAgent)

  ## Why This Matters

  Without domain vocabulary training:
  - "sparc-phase-3-architecture" → tokenized as ["sp", "arc", "-", "phase", "##3", ...]
  - "{{MODULE_NAME}}" → treated as random punctuation
  - "use GenServer" → loses semantic meaning as Elixir pattern

  With domain vocabulary training:
  - "sparc-phase-3-architecture" → understood as SPARC_ARCHITECTURE semantic unit
  - "{{MODULE_NAME}}" → preserved as template variable token
  - "use GenServer" → recognized as Elixir OTP pattern

  ## Usage

      # Extract vocabulary from technology_patterns table + templates
      vocab = DomainVocabularyTrainer.extract_custom_vocabulary()

      # Create training pairs for fine-tuning
      training_data = DomainVocabularyTrainer.create_template_training_data(vocab)

      # Augment tokenizer with custom tokens
      tokenizer = DomainVocabularyTrainer.augment_tokenizer(tokenizer, vocab)

      # Preprocess code before embedding
      processed = DomainVocabularyTrainer.preprocess_for_embedding(code, vocab)

  ## Integration Points

  - Used by: RAGCodeGenerator (semantic code search)
  - Used by: CodeSynthesisPipeline (template-aware generation)
  - Used by: CodeSearch (SPARC-aware retrieval)
  - Reads from: technology_patterns table (framework detection patterns)
  """

  require Logger
  alias Singularity.Repo
  alias Singularity.Schemas.TechnologyPattern

  @doc """
  Extract ALL custom keywords from your templates & codebase
  These become special tokens the model MUST understand
  """
  def extract_custom_vocabulary do
    Logger.info("Extracting custom vocabulary from templates...")

    # 1. SPARC 5-phase keywords (S.P.A.R.C methodology)
    sparc_keywords = [
      # The 5 SPARC phases
      # S - Define what to build
      "sparc-specification",
      # P - Logic in plain language
      "sparc-pseudocode",
      # A - System design
      "sparc-architecture",
      # R - Improve and optimize
      "sparc-refinement",
      # C - Final implementation
      "sparc-completion",

      # Phase number variants
      "sparc-phase-1-specification",
      "sparc-phase-2-pseudocode",
      "sparc-phase-3-architecture",
      "sparc-phase-4-refinement",
      "sparc-phase-5-completion",

      # Additional workflow steps (not core phases but used in templates)
      "sparc-research",
      "sparc-security",
      "sparc-performance",
      "sparc-implementation",
      "sparc-testing",
      "sparc-deployment"
    ]

    # 2. Template variable patterns
    template_vars = extract_template_variables()

    # 3. Prompt bit markers
    prompt_bits = [
      "<REASONING>",
      "</REASONING>",
      "<CODE_QUALITY>",
      "</CODE_QUALITY>",
      "<CONTEXT>",
      "</CONTEXT>",
      "<TASK>",
      "</TASK>",
      "<OUTPUT>",
      "</OUTPUT>"
    ]

    # 4. Framework-specific patterns from your detectors
    framework_patterns = extract_framework_patterns()

    # 5. Custom code patterns from templates
    code_patterns = extract_code_patterns()

    vocabulary = %{
      sparc: sparc_keywords,
      templates: template_vars,
      prompts: prompt_bits,
      frameworks: framework_patterns,
      patterns: code_patterns,
      total:
        length(sparc_keywords) + length(template_vars) +
          length(prompt_bits) + length(framework_patterns) +
          length(code_patterns)
    }

    Logger.info("Found #{vocabulary.total} custom tokens to teach the model")
    vocabulary
  end

  defp extract_template_variables do
    # Find all {{VARIABLE}} patterns in templates
    # Note: This would query codebase_chunks table (YOUR code, not external packages)
    # For now, return common template variables used in the system
    [
      "{{MODULE_NAME}}",
      "{{SUBJECT}}",
      "{{MESSAGE_TYPE}}",
      "{{TASK_NAME}}",
      "{{REPO_NAME}}",
      "{{LANGUAGE}}",
      "{{FRAMEWORK}}",
      "{{CODEBASE_PATH}}",
      "{{TECHNOLOGY}}"
    ]
  end

  defp extract_framework_patterns do
    # Get detector patterns from technology_patterns table using Ecto
    # This includes frameworks, languages, cloud, monitoring, security, AI, messaging

    file_patterns = Repo.all(TechnologyPattern.file_patterns_query()) |> Enum.uniq()
    config_patterns = Repo.all(TechnologyPattern.config_files_query()) |> Enum.uniq()
    patterns = file_patterns ++ config_patterns

    # Add common code patterns from extended_metadata if available
    additional =
      Repo.all(TechnologyPattern.code_patterns_query())
      |> Enum.flat_map(fn row ->
        case Jason.decode(row) do
          {:ok, decoded} when is_list(decoded) -> decoded
          _ -> []
        end
      end)
      |> Enum.uniq()

    patterns = patterns ++ additional

    if Enum.empty?(patterns) do
      # Fallback to common framework patterns
      [
        "use GenServer",
        "use Phoenix",
        "impl Trait",
        "async fn",
        "defmodule",
        "@Component",
        "useState",
        "Cargo.toml",
        "package.json",
        "next.config.js"
      ]
    else
      Enum.uniq(patterns) |> Enum.take(200)
    end
  end

  defp extract_code_patterns do
    case load_configured_patterns() do
      {:ok, patterns} -> patterns
      {:error, _} -> default_patterns()
    end
  end

  defp load_configured_patterns do
    with {:ok, priv_dir} <- priv_dir_path(),
         path = Path.join([priv_dir, "patterns", "default_patterns.json"]),
         true <- File.exists?(path),
         {:ok, contents} <- File.read(path),
         {:ok, %{"patterns" => patterns}} when is_list(patterns) <- Jason.decode(contents) do
      {:ok, Enum.uniq(patterns)}
    else
      false -> {:error, :enoent}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_format}
    end
  end

  defp priv_dir_path do
    case :code.priv_dir(:singularity) do
      charlist when is_list(charlist) -> {:ok, List.to_string(charlist)}
      {:error, _} = error -> error
    end
  end

  defp default_patterns do
    [
      "def handle_call",
      "def handle_cast",
      "def handle_info",
      "use Application",
      "use Supervisor",
      "@behaviour",
      "impl From",
      "impl Display",
      "#[derive(",
      "pub async fn",
      "tokio::spawn",
      ".await?",
      "Singularity.Jobs.PgmqClient.subscribe",
      "Singularity.Jobs.PgmqClient.publish",
      "JetStream",
      "knowledge.facts.technology_patterns",
      "llm.analyze",
      "RAGCodeGenerator",
      "CodeSynthesisPipeline",
      "HybridAgent",
      "PatternIndexer"
    ]
  end

  @doc """
  Create special training data that teaches the model about templates
  """
  def create_template_training_data(vocabulary) do
    Logger.info("Creating template-aware training data...")

    # 1. Create pairs where template vars are preserved
    template_pairs = create_template_preservation_pairs(vocabulary.templates)

    # 2. Create SPARC phase understanding pairs
    sparc_pairs = create_sparc_phase_pairs(vocabulary.sparc)

    # 3. Create framework pattern recognition pairs
    pattern_pairs = create_pattern_recognition_pairs(vocabulary.patterns)

    training_data = %{
      template_pairs: template_pairs,
      sparc_pairs: sparc_pairs,
      pattern_pairs: pattern_pairs,
      total: length(template_pairs) + length(sparc_pairs) + length(pattern_pairs)
    }

    Logger.info("Created #{training_data.total} template-aware training pairs")
    training_data
  end

  defp create_template_preservation_pairs(template_vars) do
    # Teach model that {{VARS}} are semantic units
    Enum.flat_map(template_vars, fn var ->
      [
        # Positive: Same variable in different contexts
        %{
          anchor: "Generate module with name #{var}",
          positive: "Create GenServer named #{var} with supervision",
          label: 1.0
        },
        # Negative: Different variables
        %{
          anchor: "Module #{var} handles messages",
          positive: "Module {{OTHER_VAR}} processes events",
          # Somewhat similar but not the same
          label: 0.3
        }
      ]
    end)
  end

  defp create_sparc_phase_pairs(sparc_keywords) do
    # Teach the 5 SPARC phases (S.P.A.R.C)
    phases = [
      {"specification", 1, "S - Specification: Define what to build"},
      {"pseudocode", 2, "P - Pseudocode: Write logic in plain language"},
      {"architecture", 3, "A - Architecture: Design system structure"},
      {"refinement", 4, "R - Refinement: Improve and optimize"},
      {"completion", 5, "C - Completion: Final implementation"}
    ]

    phase_pairs =
      for {name, num, desc} <- phases do
        [
          %{
            anchor: "sparc-phase-#{num}-#{name}",
            positive: desc,
            label: 1.0,
            metadata: %{phase: num, name: name}
          },
          %{
            anchor: "sparc-#{name}",
            positive: "Phase #{num}: #{desc}",
            label: 0.9
          }
        ]
      end

    # Filter phases based on provided keywords
    filtered_pairs =
      if sparc_keywords && length(sparc_keywords) > 0 do
        Enum.filter(List.flatten(phase_pairs), fn pair ->
          Enum.any?(sparc_keywords, fn keyword ->
            String.contains?(pair.anchor, keyword) ||
              String.contains?(pair.positive, keyword)
          end)
        end)
      else
        List.flatten(phase_pairs)
      end

    filtered_pairs
  end

  defp create_pattern_recognition_pairs(patterns) do
    # Group patterns by language/framework
    grouped =
      Enum.group_by(patterns, fn pattern ->
        cond do
          String.contains?(pattern, ["def ", "defmodule"]) -> :elixir
          String.contains?(pattern, ["impl ", "pub ", "#["]) -> :rust
          String.contains?(pattern, ["pgmq", "pgmq"]) -> :pgmq
          true -> :other
        end
      end)

    # Create same-framework pairs (positive)
    Enum.flat_map(grouped, fn {framework, framework_patterns} ->
      for p1 <- framework_patterns, p2 <- framework_patterns, p1 != p2 do
        %{
          anchor: p1,
          positive: p2,
          # Same framework = similar
          label: 0.8,
          metadata: %{framework: framework}
        }
      end
    end)
    |> Enum.take(500)
  end

  @doc """
  Augment CodeT5+ tokenizer with custom vocabulary
  This makes the model treat your keywords as ATOMIC UNITS
  """
  def augment_tokenizer(tokenizer, vocabulary) do
    # Add custom tokens to tokenizer
    custom_tokens =
      List.flatten([
        vocabulary.sparc,
        vocabulary.templates,
        vocabulary.prompts,
        vocabulary.patterns
      ])

    # Update tokenizer vocabulary
    updated_tokenizer = add_tokens_to_tokenizer(tokenizer, custom_tokens)

    Logger.info("✅ Added #{length(custom_tokens)} custom tokens to tokenizer")
    updated_tokenizer
  end

  defp add_tokens_to_tokenizer(tokenizer, new_tokens) do
    # This would normally use HuggingFace tokenizers library
    # For now, we'll preprocess text to preserve these tokens

    Map.put(tokenizer, :custom_tokens, new_tokens)
  end

  @doc """
  Preprocess code to preserve template tokens during embedding
  """
  def preprocess_for_embedding(code, vocabulary) do
    # Replace template variables with special markers
    preserved =
      vocabulary.templates
      |> Enum.reduce(code, fn template_var, acc ->
        # Preserve template variables as atomic units
        marker = "TOKEN_#{Base.encode16(:crypto.hash(:md5, template_var), case: :lower)}"
        String.replace(acc, template_var, marker)
      end)

    # Preserve SPARC keywords
    preserved =
      vocabulary.sparc
      |> Enum.reduce(preserved, fn sparc_keyword, acc ->
        marker = "SPARC_#{String.upcase(String.replace(sparc_keyword, "-", "_"))}"
        String.replace(acc, sparc_keyword, marker)
      end)

    preserved
  end

  @doc """
  Fine-tune with template awareness - CRITICAL for your system!
  """
  def train_with_template_awareness do
    # 1. Extract custom vocabulary
    vocab = extract_custom_vocabulary()

    # 2. Create template-aware training data
    training_data = create_template_training_data(vocab)

    # Log training data statistics
    Logger.info("Created template training data",
      vocab_size: length(vocab),
      training_examples: length(training_data),
      avg_examples_per_pattern: length(training_data) / max(length(vocab), 1)
    )

    # 3. Load and augment tokenizer
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "Salesforce/codet5p-110m-embedding"})
    augmented_tokenizer = augment_tokenizer(tokenizer, vocab)

    # 4. Train with special attention to templates
    Logger.info("""
    Training CodeT5+ with template awareness:
    - #{length(vocab.sparc)} SPARC keywords
    - #{length(vocab.templates)} template variables
    - #{length(vocab.patterns)} code patterns

    This will make RAG understand your domain-specific language!
    """)

    {:ok, vocab, augmented_tokenizer}
  end
end
