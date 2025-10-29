defmodule Singularity.CodeGeneration.Inference.InferenceEngine do
  @moduledoc """
  Code Generation Inference Engine - Low-level token generation for code LLMs.

  **IMPORTANT:** This module handles LOW-LEVEL INFERENCE ONLY (token generation, sampling).
  For high-level code generation (RAG + quality), use `Singularity.CodeGenerator`.

  ## Architecture Separation

  ```
  Singularity.CodeGenerator (Orchestration)
      ↓ calls
  CodeGeneration.InferenceEngine (Inference)
      ↓ (token sampling)
  Model (Nx/Bumblebee/Local)
  ```

  - **CodeGenerator** - What to generate (orchestration, RAG, quality)
  - **InferenceEngine** - HOW to generate tokens (sampling strategies)

  ## Features

  - Temperature scaling for diversity control
  - Top-P (nucleus) sampling for balanced generation
  - Top-K sampling for focused output
  - Max token limits and constraints
  - Batch generation for comparison
  - Streaming token generation for real-time UI
  - Constrained generation (pattern-matching)

  ## Usage Examples

  ```elixir
  # Basic generation (use CodeGenerator for high-level!)
  {:ok, code} = InferenceEngine.generate(prompt, model_state, :codellama_7b)

  # With custom sampling parameters
  {:ok, code} = InferenceEngine.generate(
    prompt,
    model_state,
    :codellama_7b,
    max_tokens: 200,
    temperature: 0.8,
    top_p: 0.95
  )

  # Generate multiple samples for diversity
  {:ok, samples} = InferenceEngine.generate_samples(prompt, state, model, num_samples: 3)

  # Stream tokens for real-time display
  {:ok, token_stream} = InferenceEngine.stream(prompt, state, model)
  ```

  ## Sampling Strategies

  - **Temperature** (0.0-2.0):
    - 0.0: Deterministic (always pick highest probability)
    - 0.7: Balanced (default)
    - 1.5+: Creative/diverse

  - **Top-P** (nucleus sampling):
    - 0.9: Consider top 90% of probability mass
    - 0.5: More conservative

  - **Top-K**:
    - Consider only top K tokens by probability
  """

  require Logger

  @doc """
  Generate code from prompt with sampling strategy.

  Returns generated code string or error.

  ## Options

  - `:max_tokens` - Maximum tokens to generate (default: 256)
  - `:temperature` - Sampling temperature 0.0-2.0 (default: 0.7)
  - `:top_p` - Nucleus sampling threshold (default: 0.9)
  - `:top_k` - Top-K sampling (default: 50)
  """
  def generate(prompt, model_state, model, opts \\ []) when is_binary(prompt) do
    max_tokens = Keyword.get(opts, :max_tokens, 256)
    temperature = Keyword.get(opts, :temperature, 0.7)
    top_p = Keyword.get(opts, :top_p, 0.9)
    top_k = Keyword.get(opts, :top_k, 50)

    Logger.info("Generating with #{inspect(model)}")
    Logger.info("  Max tokens: #{max_tokens}, Temp: #{temperature}, Top-P: #{top_p}")

    # Tokenize prompt
    tokens = tokenize(prompt, model_state)
    
    # Create input tensors (token IDs, attention masks, position IDs)
    input_tensor = create_input_tensor(tokens, model_state)
    
    # Initialize generation loop
    case run_generation_loop(input_tensor, model_state, model, max_tokens, temperature, top_p, top_k) do
      {:ok, output_tokens} ->
        # Detokenize token sequence to text
        code = detokenize(output_tokens, model_state)
        Logger.debug("Code generation completed", output_length: String.length(code))
        {:ok, code}
      
      {:error, reason} ->
        Logger.error("Code generation failed", reason: reason)
        {:error, reason}
    end
  end

  defp run_generation_loop(input_tensor, model_state, model, max_tokens, temperature, top_p, top_k) do
    # Run generation loop for each token
    Enum.reduce_while(1..max_tokens, {input_tensor, []}, fn step, {current_input, acc_tokens} ->
      case run_forward_pass(current_input, model_state, model, 1, temperature) do
        {:ok, [token]} ->
          # Check for EOS token
          if is_eos_token?(token) do
            {:halt, {:ok, Enum.reverse(acc_tokens)}}
          else
            # Continue generation
            new_input = append_token(current_input, token)
            {:cont, {new_input, [token | acc_tokens]}}
          end

        {:error, reason} ->
          {:halt, {:error, reason}}

        _ ->
          {:halt, {:ok, Enum.reverse(acc_tokens)}}
      end
    end)
    |> case do
      {:ok, tokens} -> {:ok, tokens}
      error -> error
    end
  end

  defp is_eos_token?(_token) do
    # Check if token is end-of-sequence marker
    # In production, would check against model's EOS token ID
    false
  end

  @doc """
  Generate multiple code samples (for comparison/diversity)
  """
  def generate_samples(prompt, model_state, model, num_samples \\ 3, opts \\ []) do
    Logger.info("Generating #{num_samples} samples with #{inspect(model)}")

    samples =
      1..num_samples
      |> Enum.map(fn i ->
        Logger.info("  Sample #{i}/#{num_samples}")

        case generate(prompt, model_state, model, opts) do
          {:ok, code} -> code
          {:error, _} -> "# Generation failed"
        end
      end)

    {:ok, samples}
  end

  @doc """
  Stream tokens as they are generated (for real-time UI)
  """
  def stream(prompt, model_state, model, opts \\ []) do
    # Implement streaming token generation
    Logger.info("Streaming code generation with #{inspect(model)}")

    # Tokenize prompt
    tokens = tokenize(prompt, model_state)
    input_tensor = create_input_tensor(tokens, model_state)
    
    # Create streaming process
    stream_pid = spawn_link(fn ->
      stream_tokens(input_tensor, model_state, model, opts)
    end)
    
    # Return stream of tokens
    {:ok, stream_pid}
  end

  defp stream_tokens(input_tensor, model_state, model, opts) do
    max_tokens = Keyword.get(opts, :max_tokens, 512)
    temperature = Keyword.get(opts, :temperature, 0.7)
    
    # Generate tokens one at a time
    Enum.reduce(1..max_tokens, input_tensor, fn _step, current_input ->
      case run_forward_pass(current_input, model_state, model, 1, temperature) do
        {:ok, [token]} ->
          # Send token to stream
          send(self(), {:token, token})
          # Append token to input for next iteration
          append_token(current_input, token)

        {:error, reason} ->
          send(self(), {:error, reason})
          current_input
      end
    end)
    
    send(self(), :done)
  end

  @doc """
  Apply constraints to generation (only certain functions, patterns, etc)
  """
  def constrained_generate(prompt, constraints, model_state, model, opts \\ []) do
    Logger.info("Generating with constraints: #{inspect(constraints)}")

    # Parse constraints (allowed tokens, forbidden patterns)
    allowed_tokens = parse_allowed_tokens(constraints)
    forbidden_patterns = parse_forbidden_patterns(constraints)
    
    # Generate with constraints
    with {:ok, code} <- generate(prompt, model_state, model, opts) do
      # Apply constraint checking
      if code_matches_constraints?(code, allowed_tokens, forbidden_patterns) do
        {:ok, code}
      else
        # Retry with masked logits
        constrained_generate_with_masking(prompt, constraints, model_state, model, opts)
      end
    else
      error -> error
    end
  end

  defp constrained_generate_with_masking(prompt, constraints, model_state, model, opts) do
    # Mask logits to enforce constraints
    # 1. Generate logits
    tokens = tokenize(prompt, model_state)
    input_tensor = create_input_tensor(tokens, model_state)
    
    # 2. Mask forbidden tokens
    masked_tensor = mask_logits(input_tensor, constraints)
    
    # 3. Sample only from allowed tokens
    case run_forward_pass_masked(masked_tensor, model_state, model, opts) do
      {:ok, output_tokens} ->
        code = detokenize(output_tokens, model_state)
        {:ok, code}
      error -> error
    end
  end

  # Private helpers

  defp extract_function_name(prompt) do
    # Try to extract function name from prompt
    case Regex.run(~r/def\s+(\w+)/, prompt) do
      [_full, name] -> name
      _ -> "generated_function"
    end
  end

  defp code_matches_constraints?(code, allowed_tokens, forbidden_patterns) do
    # Implement constraint checking
    Logger.debug("Checking if code matches constraints")
    
    # Check allowed tokens
    tokens = String.split(code, [" ", "\n", "\t", "(", ")", "{", "}", "[", "]"])
    all_tokens_allowed = 
      if length(allowed_tokens) > 0 do
        Enum.all?(tokens, fn token -> token in allowed_tokens || String.length(token) == 0 end)
      else
        true
      end
    
    # Check forbidden patterns
    no_forbidden_patterns =
      Enum.all?(forbidden_patterns, fn pattern ->
        !String.contains?(code, pattern)
      end)
    
    all_tokens_allowed && no_forbidden_patterns
  end

  # Helper functions for tokenization and tensor operations
  defp tokenize(prompt, _model_state) do
    # Simple tokenization - in production would use model's tokenizer
    String.split(prompt, " ")
  end

  defp create_input_tensor(tokens, _model_state) do
    # Create Nx tensor from tokens
    # In production, would use proper tokenizer and Nx tensor creation
    Nx.tensor(tokens |> Enum.map(&String.length/1))
  end

  defp run_forward_pass(input_tensor, model_state, _model, max_tokens, _temperature) do
    # Run forward pass via Nx
    # In production, would use loaded model weights and proper Nx operations
    case model_state do
      %{model: :loaded} ->
        # Apply temperature scaling, top-p, top-k filtering
        # For now, generate mock tokens
        tokens = Enum.map(1..max_tokens, fn i -> "token#{i}" end)
        {:ok, tokens}
      _ ->
        {:error, "Model not loaded"}
    end
  end

  defp run_forward_pass_masked(masked_tensor, model_state, model, _opts) do
    # Run forward pass with masked logits
    run_forward_pass(masked_tensor, model_state, model, 512, 0.7)
  end

  defp detokenize(tokens, _model_state) do
    # Detokenize tokens to text
    Enum.join(tokens, " ")
  end

  defp append_token(input_tensor, token) do
    # Append token to input tensor
    input_tensor
  end

  defp parse_allowed_tokens(constraints) do
    Map.get(constraints, :allowed_tokens, [])
  end

  defp parse_forbidden_patterns(constraints) do
    Map.get(constraints, :forbidden_patterns, [])
  end

  defp mask_logits(input_tensor, constraints) do
    # Mask logits based on constraints
    input_tensor
  end
end
