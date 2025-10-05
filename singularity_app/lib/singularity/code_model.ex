defmodule Singularity.CodeModel do
  @moduledoc """
  Local Code Generation using Bumblebee + StarCoder/DeepSeek models

  Generates clean, lint-free code using state-of-the-art code models.
  Runs locally via Nx/EXLA (no API calls).

  ## Supported Models

  - starcoder2-7b (7B, ~14GB) - ⭐ BEST quality, fewer lint errors (default)
  - starcoder2-3b (3B, ~6GB) - Balanced quality/speed
  - deepseek-coder-1.3b-base (1.3B, ~2.6GB) - Fastest

  ## Configuration

      # config/runtime.exs
      config :singularity, :code_generation,
        model: "bigcode/starcoder2-7b",
        max_tokens: 256,
        temperature: 0.2  # Lower = more deterministic/fewer errors

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

  @type generation_opts :: [
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
  @spec complete(String.t(), generation_opts()) :: {:ok, String.t()} | {:error, term()}
  def complete(prompt, opts \\ []) do
    temperature = Keyword.get(opts, :temperature, 0.1)
    max_tokens = Keyword.get(opts, :max_tokens, 256)

    stop_sequences = Keyword.get(opts, :stop_sequences, [
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
    temperature = Keyword.get(opts, :temperature, 0.05)  # Extra low for FIM
    max_tokens = Keyword.get(opts, :max_tokens, 256)

    model = get_model_name()

    # Different models use different FIM tokens
    prompt = case model do
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
             {:ok, generated} <- generate(serving, prompt, temperature, max_tokens, stop_sequences) do
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

      Logger.info("Loading code generation model: #{model_repo}")

      try do
        {:ok, model_info} = Bumblebee.load_model({:hf, model_repo})
        {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, model_repo})
        {:ok, generation_config} = Bumblebee.load_generation_config({:hf, model_repo})

        # Update generation config for CODE-ONLY output
        generation_config =
          generation_config
          |> Map.put(:max_new_tokens, 256)
          |> Map.put(:strategy, %{type: :multinomial_sampling})
          # Penalties to prevent prose/explanations
          |> Map.put(:repetition_penalty, 1.1)  # Avoid repetitive explanations
          |> Map.put(:no_repeat_ngram_size, 3)  # Prevent phrase repetition

        serving = Bumblebee.Text.generation(model_info, tokenizer, generation_config,
          compile: [batch_size: 1, sequence_length: 1024],
          defn_options: [compiler: EXLA],
          preallocate_params: true  # Faster GPU loading
        )

        # Start as named serving
        {:ok, _pid} = Nx.Serving.start_link(
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
    try do
      result = Nx.Serving.run(serving, %{
        text: prompt,
        max_new_tokens: max_tokens,
        temperature: temperature,
        # Stop at these sequences (prevents explanations)
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

  # Clean up generated code - remove any trailing explanations or comments
  defp cleanup_generated_code(code) do
    code
    |> String.split("\n")
    |> Enum.take_while(fn line ->
      # Stop at explanation markers
      not String.starts_with?(String.trim(line), ["# Explanation", "# Note:", "# This", "# The", "Here's", "This is"])
    end)
    |> Enum.join("\n")
    |> String.trim()
  end

  defp get_model_name do
    Application.get_env(:singularity, :code_generation, [])
    |> Keyword.get(:model, "deepseek-ai/deepseek-coder-1.3b-base")
  end
end
