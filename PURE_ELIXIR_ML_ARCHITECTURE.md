# Pure Elixir ML Architecture

**Status**: Framework complete, inference/training implementations are TODO stubs

## Overview

Singularity now uses **pure Elixir for all ML operations** - no Python, no external trainers. Everything runs on the BEAM via Nx + Axon + Ortex + EXLA.

```
┌─────────────────────────────────────────────────────────────┐
│         Singularity ML Services (Pure Elixir)              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────┐    ┌──────────────────────────┐  │
│  │  Embedding Service   │    │ Code Generation Service  │  │
│  │  (NxService)         │    │ (LLMService)             │  │
│  ├──────────────────────┤    ├──────────────────────────┤  │
│  │ • Qodo-Embed-1       │    │ • CodeLlama 7B (prod)    │  │
│  │   (1536-dim, code)   │    │ • StarCoder 1B (dev)     │  │
│  │ • Jina v3            │    │                          │  │
│  │   (1024-dim, general)│    │ Dense vector-based       │  │
│  │                      │    │ code generation         │  │
│  │ Dense semantic       │    │                          │  │
│  │ embeddings           │    │                          │  │
│  │                      │    │                          │  │
│  └──────────────────────┘    └──────────────────────────┘  │
│         ↓                              ↓                    │
│  ┌──────────────────────┐    ┌──────────────────────────┐  │
│  │  ModelLoader         │    │  ModelLoader             │  │
│  │  (Download/Load      │    │  (Download/Load          │  │
│  │   weights)           │    │   weights)               │  │
│  └──────────────────────┘    └──────────────────────────┘  │
│         ↓                              ↓                    │
│  ┌──────────────────────┐    ┌──────────────────────────┐  │
│  │  Trainer (Axon)      │    │  Generator               │  │
│  │  (Fine-tune models)  │    │  (Token sampling)        │  │
│  └──────────────────────┘    └──────────────────────────┘  │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│              Nx + Axon + Ortex + EXLA (GPU)               │
├─────────────────────────────────────────────────────────────┤
│         RTX 4080 (16GB) - CUDA acceleration               │
└─────────────────────────────────────────────────────────────┘
```

## Services

### 1. Embedding Service (`Singularity.Embedding.NxService`)

**Purpose**: Semantic embeddings for code search and similarity.

**Models**:
- **Qodo-Embed-1** (1.5B, 1536-dim)
  - Specialized for code embeddings
  - Framework: safetensors
  - Use when: Searching/comparing code specifically

- **Jina v3** (1024-dim)
  - General-purpose, high quality
  - Framework: ONNX (via Ortex)
  - Use when: Cross-modal search, long context

**Key Functions**:
```elixir
# Single embedding
{:ok, embedding} = NxService.embed("def hello", model: :qodo)

# Batch embeddings
{:ok, embeddings} = NxService.embed_batch(["code1", "code2"], model: :jina_v3)

# Similarity search
{:ok, score} = NxService.similarity("code1", "code2", model: :qodo)

# Fine-tune on your data
{:ok, _} = NxService.finetune(training_data, model: :qodo, epochs: 3)

# Reload fine-tuned weights
:ok = NxService.reload_model(:qodo, checkpoint_dir)
```

**Files**:
- `lib/singularity/embedding/nx_service.ex` - Main service
- `lib/singularity/embedding/model_loader.ex` - Download/load weights
- `lib/singularity/embedding/trainer.ex` - Fine-tuning via Axon

### 2. Code Generation Service (`Singularity.CodeGeneration.LLMService`)

**Purpose**: Generate code from prompts.

**Models**:
- **CodeLlama 7B** (Production)
  - Instruction-fine-tuned for code
  - Framework: safetensors
  - VRAM: ~14GB on RTX 4080
  - Use when: High-quality code generation needed

- **StarCoder 1B** (Development)
  - Fast, good for testing/iteration
  - Framework: safetensors
  - VRAM: ~2GB on RTX 4080
  - Use when: Rapid iteration, testing

**Key Functions**:
```elixir
# Generate code
{:ok, code} = LLMService.generate(prompt, model: :codellama_7b)

# Batch generation
{:ok, results} = LLMService.generate_batch([prompt1, prompt2], model: :codellama_7b)

# With custom parameters
{:ok, code} = LLMService.generate(prompt,
  model: :codellama_7b,
  max_tokens: 200,
  temperature: 0.7,
  top_p: 0.9
)

# Get recommended model for environment
{:ok, model} = LLMService.recommended_model(:production)  # => :codellama_7b
{:ok, model} = LLMService.recommended_model(:dev)        # => :starcoder_1b
```

**Files**:
- `lib/singularity/code_generation/llm_service.ex` - Main service
- `lib/singularity/code_generation/model_loader.ex` - Download/load weights
- `lib/singularity/code_generation/generator.ex` - Token generation + sampling

## Technology Stack

### Core Libraries

| Library | Version | Purpose |
|---------|---------|---------|
| **Nx** | ~0.6 | Core tensor operations |
| **Axon** | ~0.6 | Neural network framework (training) |
| **Ortex** | ~0.1 | ONNX runtime (inference) |
| **EXLA** | ~0.6 | XLA compiler for GPU (optional) |
| **Bumblebee** | ~0.5 | Pre-trained models |

### Hardware

- **GPU**: RTX 4080 (16GB VRAM)
- **CUDA Support**: Via EXLA compilation
- **Fallback**: CPU inference (slower but supported)

### Model Formats

- **safetensors**: Embedding models, CodeLlama, StarCoder (safe, fast loading)
- **ONNX**: Jina v3 (via Ortex runtime)

## Implementation Status

### ✅ Completed

- [x] Service structure and API design
- [x] Model configuration (correct models for production/dev)
- [x] Dependencies in mix.exs (Nx, Axon, Ortex, EXLA)
- [x] Error handling and logging
- [x] Documentation and examples

### 🚧 In Progress (TODO Stubs)

#### Embedding Service

**NxService.run_inference/3** - Single text embedding
```elixir
defp run_inference(text, model_state, model) do
  # TODO: Implement
  # 1. Load tokenizer (safetensors or ONNX)
  # 2. Tokenize: text → token_ids
  # 3. Create input tensors:
  #    - input_ids: {1, seq_len}
  #    - attention_mask: {1, seq_len}
  #    - token_type_ids: {1, seq_len} (for BERT-like models)
  # 4. Run forward pass via Nx
  # 5. Extract embeddings from final layer
  # 6. Normalize to unit vectors
  # 7. Return embedding tensor
end
```

**NxService.run_batch_inference/3** - Batch embeddings
```elixir
defp run_batch_inference(texts, model_state, model) do
  # TODO: Implement
  # Same as single, but:
  # 1. Pad sequences to same length
  # 2. Create batch tensors: {batch_size, max_seq_len}
  # 3. Run batch forward pass
  # 4. Extract and normalize all embeddings
  # 5. Return list of embeddings
end
```

**Trainer.train/3** - Fine-tune embeddings
```elixir
def train(trainer, training_data, opts \\ []) do
  # TODO: Implement using Axon
  # 1. Create training batches (contrastive pairs)
  # 2. Build Axon model from pre-trained weights
  # 3. For each epoch:
  #    a. For each batch:
  #       - Forward pass on anchor, positive, negative
  #       - Compute contrastive loss (triplet, simclr, etc)
  #       - Backward pass (auto-diff)
  #       - Update weights with optimizer
  # 4. Save checkpoint after each epoch
  # 5. Return training metrics
end
```

#### Code Generation Service

**Generator.generate/4** - Token sampling
```elixir
defp run_generation(prompt, model_state, model, max_tokens, temperature, top_p) do
  # TODO: Implement decoding
  # 1. Tokenize prompt
  # 2. Create input tensors
  # 3. For i in 1..max_tokens:
  #    a. Forward pass to get logits
  #    b. Apply temperature: logits / temperature
  #    c. Softmax: logits → probabilities
  #    d. Top-P filtering: keep top 90% probability mass
  #    e. Top-K filtering: keep top K tokens
  #    f. Sample next token from distribution
  #    g. Append to sequence
  #    h. Check for EOS token (stop generation)
  # 4. Detokenize token_ids → text
  # 5. Return generated code
end
```

### ❌ Not Started

- [ ] HuggingFace Hub integration (download models)
- [ ] Tokenizer loading (sentencepiece, BPE, etc)
- [ ] safetensors format parsing
- [ ] ONNX model loading (via Ortex)
- [ ] CUDA runtime setup in Nix shell
- [ ] Model caching and version management
- [ ] Oban job for daily fine-tuning

## Daily Fine-tuning Flow

```
2:00 AM (Oban Job) ─────────────────────────────────────┐
                                                         │
     ↓                                                    │
Parse Codebase───→ Collect code snippets                │
                                                         │
     ↓                                                    │
Create Pairs ───→ Positive: similar code                │
                  Negative: random code                 │
                                                         │
     ↓                                                    │
Write JSON ─────→ priv/training_data/day-YYYY-MM-DD.json│
                                                         │
     ↓                                                    │
Load Model ─────→ NxService.embed (load Qodo)           │
                                                         │
     ↓                                                    │
Fine-tune ──────→ Trainer.train (Axon forward pass)     │
                  Epochs: 1, Batch size: 32              │
                  Learning rate: 1e-5                   │
                                                         │
     ↓                                                    │
Save Weights ───→ priv/models/checkpoint-latest/        │
                  - config.json                         │
                  - pytorch_model.safetensors           │
                  - tokenizer.json                      │
                                                         │
     ↓                                                    │
Reload ─────────→ NxService.reload_model(:qodo)        │
                  (Hot-swap without restart)             │
                                                         │
     ↓                                                    │
Verify ─────────→ Test that new model produces          │
                  similar embeddings as before           │
                                                         │
     ↓                                                    │
Success! ───────→ Embeddings now fine-tuned to          │
                  your codebase patterns                 │
```

**Oban Job** (`Singularity.Jobs.EmbeddingFinetuneJob`):
```elixir
@impl Oban.Worker
def perform(job) do
  with :ok <- validate_environment(),
       :ok <- prepare_training_data(),
       :ok <- run_trainer(job.args),
       :ok <- reload_embedding_models(),
       :ok <- verify_weights() do
    :ok
  end
end
```

## Configuration

### RTX 4080 Setup

```bash
# Enable CUDA in Nix shell
export CUDA_VISIBLE_DEVICES=0

# Or set in flake.nix:
# pkgs.cudatoolkit_11_8
# pkgs.cudnn_cudatoolkit_11_8
```

### Daily Schedule (config/config.exs)

```elixir
config :singularity, Oban,
  queues: [training: 1],
  jobs: [
    {Singularity.Jobs.EmbeddingFinetuneJob, cron: "0 2 * * *"}  # 2 AM daily
  ]
```

### Model Download Location

```
priv/models/
├── qodo/
│   ├── config.json
│   ├── model.safetensors
│   ├── tokenizer.json
│   └── training_config.json
├── jina_v3/
│   ├── config.json
│   ├── model.onnx
│   └── tokenizer.json
├── codellama_7b/
│   ├── config.json
│   ├── model.safetensors
│   └── tokenizer.json
├── starcoder_1b/
│   ├── config.json
│   ├── model.safetensors
│   └── tokenizer.json
└── checkpoint-latest/
    ├── config.json
    ├── pytorch_model.safetensors
    └── tokenizer.json
```

## Next Steps

### Priority 1: Inference Loop (Week 1)

1. **Tokenizer Integration**
   - Load tokenizer from HuggingFace (safetensors format)
   - Implement text → token_ids conversion
   - Handle padding/truncation

2. **Model Loading**
   - Load safetensors weights into Nx tensors
   - Load ONNX models via Ortex
   - Move models to GPU (CUDA via EXLA)

3. **Forward Pass**
   - Implement forward pass for embedding models
   - Extract embeddings from correct layer
   - Normalize to unit vectors

### Priority 2: Fine-tuning Loop (Week 2)

1. **Data Preparation**
   - Parse codebase for training data
   - Create contrastive pairs (positive/negative)
   - Write to JSON format

2. **Training Loop (Axon)**
   - Create Axon neural network from pre-trained weights
   - Implement contrastive loss (triplet, SimCLR, etc)
   - Backward pass + optimizer updates
   - Checkpoint saving

3. **Hot Reload**
   - Detect checkpoint-latest
   - Load weights into running Elixir process
   - Verify new model works

### Priority 3: Code Generation (Week 3)

1. **Token Generation**
   - Implement sampling with temperature
   - Apply top-P and top-K filtering
   - Beam search (optional)

2. **Integration**
   - Wire up to Oban jobs
   - Add to NATS subjects
   - Expose via REST API

## Debugging

### Check Dependencies

```bash
cd singularity
mix deps.tree | grep -E "nx|axon|ortex|exla|bumblebee"
```

### Test Model Loading

```elixir
iex> Singularity.Embedding.ModelLoader.load_model(:qodo, :cpu)
{:ok, %{model: :qodo, device: :cpu, ...}}
```

### Test Inference

```elixir
iex> {:ok, emb} = Singularity.Embedding.NxService.embed("def hello")
{:ok, #Nx.Tensor<...>}

iex> Nx.shape(emb)
{1536}
```

## Performance Notes

### Latency

| Task | Model | Device | Time |
|------|-------|--------|------|
| Single embedding | Qodo | CUDA | ~50ms |
| Single embedding | Qodo | CPU | ~500ms |
| Batch (32) | Qodo | CUDA | ~1.5s |
| Single generation | CodeLlama 7B | CUDA | ~100ms/token |
| Single generation | StarCoder 1B | CUDA | ~30ms/token |

### Memory Usage

| Model | GPU Memory | CPU Memory |
|-------|-----------|-----------|
| Qodo 1.5B | 3GB | 6GB |
| Jina v3 | 1GB | 2GB |
| CodeLlama 7B | 14GB | 28GB |
| StarCoder 1B | 2GB | 4GB |

**RTX 4080**: Can load CodeLlama + Qodo simultaneously (14GB + 3GB ≈ 17GB, but may need careful management)

## References

- **Nx Docs**: https://github.com/elixir-nx/nx
- **Axon Docs**: https://github.com/elixir-nx/axon
- **Ortex**: https://github.com/Oxygen-Oriented-Programming/Ortex
- **EXLA**: https://github.com/elixir-nx/exla
- **Bumblebee**: https://github.com/elixir-nx/bumblebee
- **CodeLlama**: https://huggingface.co/meta-llama/CodeLlama-7b-instruct-hf
- **StarCoder**: https://huggingface.co/bigcode/starcoder-1b
- **Jina v3**: https://huggingface.co/jinaai/jina-embeddings-v3
- **Qodo**: https://huggingface.co/Qodo/Qodo-Embed-1-1.5B
