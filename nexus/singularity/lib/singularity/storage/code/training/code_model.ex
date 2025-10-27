defmodule Singularity.CodeModel do
  @moduledoc """
  Local Code Generation using Bumblebee + T5/CodeT5/StarCoder models

  Generates clean, lint-free code using state-of-the-art code models.
  Runs locally via Nx/EXLA (no API calls).

  ## Supported Models

  - codet5p-770m (770M, ~1.5GB) - ⭐ BEST for fine-tuning, Elixir/Gleam optimized
  - starcoder2-7b (7B, ~14GB) - High quality, fewer lint errors
  - starcoder2-3b (3B, ~6GB) - Balanced quality/speed
  - deepseek-coder-1.3b-base (1.3B, ~2.6GB) - Fastest

  ## T5/CodeT5 Features

  - Fine-tuned on YOUR codebase patterns
  - Sequence-to-sequence generation (instruction → code)
  - Fill-in-middle (FIM) support
  - Domain-specific vocabulary training
  - LoRA fine-tuning with PEFT

  ## Configuration

      # config/runtime.exs
      config :singularity, :code_generation,
        model: "Salesforce/codet5p-770m",  # T5 model
        max_tokens: 256,
        temperature: 0.2,  # Lower = more deterministic/fewer errors
        use_fine_tuned: true,  # Use fine-tuned model if available
        fine_tuned_path: "~/.cache/singularity/codet5p-770m-singularity"

  ## Usage

      # Complete code
      {:ok, code} = CodeModel.complete(\"\"\"
      defmodule MyApp do
        def calculate_total(items) do
      \"\"\")

      # Fill-in-middle (FIM) - better for completions
      {:ok, code} = CodeModel.fill_in_middle(
        prefix: "defn softmax(x) do\\n",
        suffix: "\\nend",
        temperature: 0.1  # Very low for fewer lint errors
      )
  """

  require Logger

  @type generationopts :: [
          temperature: float(),
          max_tokens: integer(),
          top_p: float()
        ]

  @doc """
  Generate code completion from a prompt

  ## Options

  - `:temperature` - Lower = more deterministic (default: 0.1 for clean code)
  - `:max_tokens` - Maximum tokens to generate (default: 256)
  - `:stop_sequences` - Stop at these tokens (default: code-only stops)
  """
  @spec complete(String.t(), generationopts()) :: {:ok, String.t()} | {:error, term()}
  def complete(prompt, opts \\ []) do
    temperature = Keyword.get(opts, :temperature, 0.1)
    max_tokens = Keyword.get(opts, :max_tokens, 256)

    stop_sequences =
      Keyword.get(opts, :stop_sequences, [
        "\n\n\n",
        "# Explanation:",
        "# Note:",
        "# This code",
        "# The above",
        "/*\n *",
        "```",
        "Here's",
        "This is"
      ])

    meta = %{
      operation: :complete,
      prompt_chars: String.length(prompt),
      temperature: temperature,
      max_tokens: max_tokens
    }

    do_generate(prompt, temperature, max_tokens, stop_sequences, meta)
  end

  @doc """
  Fill-in-middle completion (better for code insertion)

  Uses Fill-In-Middle (FIM) tokens for more accurate completions.
  This is the RECOMMENDED way to generate code - more accurate than simple completion.

  ## Example

      # Complete a function body
      CodeModel.fill_in_middle(
        prefix: "defmodule MyApp do\\n  def calculate(x, y) do\\n",
        suffix: "\\n  end\\nend",
        temperature: 0.05  # Very strict for production code
      )
  """
  @spec fill_in_middle(keyword()) :: {:ok, String.t()} | {:error, term()}
  def fill_in_middle(opts) do
    prefix = Keyword.fetch!(opts, :prefix)
    suffix = Keyword.get(opts, :suffix, "")
    # Extra low for FIM
    temperature = Keyword.get(opts, :temperature, 0.05)
    max_tokens = Keyword.get(opts, :max_tokens, 256)

    model = get_model_name()

    # Different models use different FIM tokens
    prompt =
      case model do
        "deepseek-ai/deepseek-coder" <> _ ->
          "<｜fim▁begin｜>#{prefix}<｜fim▁hole｜>#{suffix}<｜fim▁end｜>"

        "bigcode/starcoder" <> _ ->
          "<fim_prefix>#{prefix}<fim_suffix>#{suffix}<fim_middle>"

        _ ->
          # Fallback to simple concatenation
          prefix <> suffix
      end

    # FIM mode uses stricter stop sequences (code-only)
    stop_sequences = [suffix, "\n\n\n", "# Explanation:", "```"]

    meta = %{
      operation: :fill_in_middle,
      prompt_chars: String.length(prompt),
      prefix_chars: String.length(prefix),
      suffix_chars: String.length(suffix),
      temperature: temperature,
      max_tokens: max_tokens
    }

    do_generate(prompt, temperature, max_tokens, stop_sequences, meta)
  end

  ## Private Functions

  defp do_generate(prompt, temperature, max_tokens, stop_sequences, meta) do
    base_meta = Map.put(meta, :model, get_model_name())

    :telemetry.span([:singularity, :code_generator, :generate], base_meta, fn ->
      result =
        with {:ok, serving} <- get_serving(),
             {:ok, generated} <-
               generate(serving, prompt, temperature, max_tokens, stop_sequences) do
          clean_code = cleanup_generated_code(generated)
          {:ok, clean_code}
        end

      span_meta =
        case result do
          {:ok, code} -> %{status: :ok, generated_chars: String.length(code)}
          {:error, reason} -> %{status: :error, error: inspect(reason)}
        end

      {result, span_meta}
    end)
  end

  defp get_serving do
    # Check if serving is already started
    case Process.whereis(__MODULE__.Serving) do
      nil -> start_serving()
      _pid -> {:ok, __MODULE__.Serving}
    end
  end

  defp start_serving do
    if Code.ensure_loaded?(Bumblebee) do
      model_repo = get_model_name()
      use_fine_tuned = get_fine_tuned_config()
      fine_tuned_path = get_fine_tuned_path()

      Logger.info("Loading code generation model: #{model_repo}")
      Logger.info("Fine-tuned mode: #{use_fine_tuned}")

      try do
        # Load model (fine-tuned or base)
        {model_info, tokenizer, generation_config} =
          if (use_fine_tuned and fine_tuned_path) && File.exists?(Path.expand(fine_tuned_path)) do
            load_fine_tuned_model(fine_tuned_path)
          else
            load_base_model(model_repo)
          end

        # Update generation config for CODE-ONLY output
        generation_config =
          generation_config
          |> Map.put(:max_new_tokens, 256)
          |> Map.put(:strategy, %{type: :multinomial_sampling})
          # Penalties to prevent prose/explanations
          |> Map.put(:repetition_penalty, 1.1)
          |> Map.put(:no_repeat_ngram_size, 3)

        # Configure for T5 vs other models
        serving = configure_serving(model_info, tokenizer, generation_config, model_repo)

        # Start as named serving
        {:ok, _pid} =
          Nx.Serving.start_link(
            serving: serving,
            name: __MODULE__.Serving,
            batch_timeout: 100
          )

        Logger.info("Code generation model loaded successfully")
        {:ok, __MODULE__.Serving}
      rescue
        error ->
          Logger.error("Failed to load code generation model: #{inspect(error)}")
          {:error, :model_load_failed}
      end
    else
      {:error, :bumblebee_not_loaded}
    end
  end

  defp generate(serving, prompt, temperature, max_tokens, stop_sequences) do
    model_repo = get_model_name()

    # Use T5-specific generation for CodeT5 models
    if String.contains?(model_repo, "codet5") do
      generate_t5_style(prompt, temperature, max_tokens, stop_sequences)
    else
      generate_standard(prompt, temperature, max_tokens, stop_sequences)
    end
  end

  # Clean up generated code - remove any trailing explanations or comments
  defp cleanup_generated_code(code) do
    code
    |> String.split("\n")
    |> Enum.take_while(fn line ->
      # Stop at explanation markers
      not String.starts_with?(String.trim(line), [
        "# Explanation",
        "# Note:",
        "# This",
        "# The",
        "Here's",
        "This is"
      ])
    end)
    |> Enum.join("\n")
    |> String.trim()
  end

  defp get_model_name do
    Application.get_env(:singularity, :code_generation, [])
    |> Keyword.get(:model, "Salesforce/codet5p-770m")
  end

  defp get_fine_tuned_config do
    Application.get_env(:singularity, :code_generation, [])
    |> Keyword.get(:use_fine_tuned, true)
  end

  defp get_fine_tuned_path do
    Application.get_env(:singularity, :code_generation, [])
    |> Keyword.get(:fine_tuned_path, "~/.cache/singularity/codet5p-770m-singularity")
  end

  defp load_base_model(model_repo) do
    {:ok, model_info} = Bumblebee.load_model({:hf, model_repo})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, model_repo})
    {:ok, generation_config} = Bumblebee.load_generation_config({:hf, model_repo})
    {model_info, tokenizer, generation_config}
  end

  defp load_fine_tuned_model(fine_tuned_path) do
    expanded_path = Path.expand(fine_tuned_path)

    # Load fine-tuned model components
    {:ok, model_info} = Bumblebee.load_model({:local, expanded_path})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:local, expanded_path})
    {:ok, generation_config} = Bumblebee.load_generation_config({:local, expanded_path})

    Logger.info("Loaded fine-tuned model from: #{expanded_path}")
    {model_info, tokenizer, generation_config}
  end

  defp configure_serving(model_info, tokenizer, generation_config, model_repo) do
    # Configure serving based on model type
    cond do
      String.contains?(model_repo, "codet5") ->
        # T5/CodeT5 configuration
        Bumblebee.Text.generation(model_info, tokenizer, generation_config,
          compile: [batch_size: 1, sequence_length: 1024],
          defn_options: [compiler: EXLA],
          preallocate_params: true
        )

      String.contains?(model_repo, "starcoder") ->
        # StarCoder configuration
        Bumblebee.Text.generation(model_info, tokenizer, generation_config,
          compile: [batch_size: 1, sequence_length: 1024],
          defn_options: [compiler: EXLA],
          preallocate_params: true
        )

      true ->
        # Default configuration
        Bumblebee.Text.generation(model_info, tokenizer, generation_config,
          compile: [batch_size: 1, sequence_length: 1024],
          defn_options: [compiler: EXLA],
          preallocate_params: true
        )
    end
  end

  # T5-specific generation with instruction format
  defp generate_t5_style(prompt, temperature, max_tokens, stop_sequences) do
    # Format prompt for T5 instruction-following
    formatted_prompt = format_t5_prompt(prompt)

    # Use standard generation with T5-optimized parameters
    generate_standard(formatted_prompt, temperature, max_tokens, stop_sequences)
  end

  defp format_t5_prompt(prompt) do
    # Check if prompt is already formatted for T5
    if String.contains?(prompt, "### Desired Output") or String.contains?(prompt, "instruction") do
      prompt
    else
      # Format as T5 instruction
      "Generate code for the following request:\n\n#{prompt}\n\n### Desired Output"
    end
  end

  defp generate_standard(prompt, temperature, max_tokens, stop_sequences) do
    # Standard generation logic
    try do
      result =
        Nx.Serving.run(__MODULE__.Serving, %{
          text: prompt,
          max_new_tokens: max_tokens,
          temperature: temperature,
          stop_sequences: stop_sequences
        })

      generated_text =
        result.results
        |> List.first()
        |> Map.get(:text, "")
        |> String.trim()

      Logger.debug("Generated #{String.length(generated_text)} chars (temp: #{temperature})")
      {:ok, generated_text}
    rescue
      error ->
        Logger.error("Generation failed: #{inspect(error)}")
        {:error, :generation_failed}
    end
  end
end
