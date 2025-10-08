# Rust/Elixir T5 Training Pipeline

This document describes the specialized T5 fine-tuning pipeline for Rust and Elixir code generation in the Singularity project.

## Overview

The Rust/Elixir T5 training pipeline is designed to create a specialized code generation model that understands the unique patterns, idioms, and best practices of both Rust and Elixir programming languages. The pipeline includes:

- **Database-driven training data preparation** from PostgreSQL code chunks
- **Language-specific preprocessing** for Rust and Elixir patterns
- **Cross-language learning** to transfer patterns between languages
- **Specialized evaluation metrics** for both languages
- **Production-ready model deployment** with GeneratorEngine integration

## Architecture

### Database Schema

The training pipeline uses several database tables to manage the training process:

- `t5_training_sessions` - Tracks training sessions and configuration
- `t5_training_examples` - Stores individual training examples with quality scores
- `t5_model_versions` - Manages different versions of trained models
- `t5_training_progress` - Real-time training monitoring
- `t5_evaluation_results` - Performance evaluation results

### Training Flow

```
Code Chunks (PostgreSQL)
    ↓
Language-Specific Preprocessing
    ↓
Quality Scoring & Filtering
    ↓
Cross-Language Pattern Learning
    ↓
T5 Fine-Tuning (LoRA)
    ↓
Model Evaluation
    ↓
Deployment to GeneratorEngine
```

## Features

### Rust-Specific Features

- **Pattern Recognition**: Functions, structs, impls, traits, enums, modules
- **Error Handling**: Result<T, E> and Option<T> patterns
- **Documentation**: /// comment generation
- **Ownership**: Proper borrowing and ownership patterns
- **Testing**: #[cfg(test)] module generation

### Elixir-Specific Features

- **Pattern Recognition**: Modules, functions, private functions, macros, callbacks, behaviours
- **Error Handling**: {:ok, result} and {:error, reason} patterns
- **Documentation**: @doc attribute generation
- **OTP Patterns**: GenServer, Supervisor, and supervision tree patterns
- **Testing**: ExUnit test generation

### Cross-Language Learning

- **Pattern Transfer**: Rust patterns → Elixir generation
- **Concept Mapping**: Similar concepts across languages
- **Quality Scoring**: Language-specific quality metrics
- **Weighted Training**: Adjustable weights for each language

## Usage

### Quick Start

```bash
# Run the complete training pipeline
./scripts/setup_rust_elixir_t5_training.sh
```

### Manual Training

```elixir
# 1. Prepare training data
{:ok, session_id} = RustElixirT5Trainer.prepare_multi_language_training(
  name: "rust_elixir_v1",
  languages: ["rust", "elixir"],
  max_examples: 20000,
  cross_language_learning: true,
  quality_threshold: 0.7
)

# 2. Fine-tune the model
{:ok, model_id} = RustElixirT5Trainer.fine_tune(session_id, 
  epochs: 12,
  learning_rate: 2.0e-4,
  cross_language_learning: true
)

# 3. Deploy the model
T5FineTuner.deploy_model(model_id)

# 4. Switch to fine-tuned model
T5FineTuner.switch_to_fine_tuned()
```

### Code Generation

```elixir
# Generate Rust code
{:ok, result} = GeneratorEngine.code_generate(
  "Create a REST API client with error handling",
  "rust",
  "my-repo",
  "production",
  true
)

# Generate Elixir code
{:ok, result} = GeneratorEngine.code_generate(
  "Create a GenServer for caching with TTL",
  "elixir",
  "my-repo", 
  "production",
  true
)
```

## Configuration

### Training Configuration

```elixir
# config/runtime.exs
config :singularity, :code_generation,
  model: "Salesforce/codet5p-770m",
  use_fine_tuned: true,
  fine_tuned_path: "~/.cache/singularity/codet5p-770m-rust-elixir"
```

### Python Training Script

```bash
python ai-server/scripts/train_rust_elixir_t5.py \
    --train-file data/rust_elixir/train.jsonl \
    --eval-file data/rust_elixir/eval.jsonl \
    --output-dir runs/codet5p-770m-rust-elixir \
    --epochs 12 \
    --learning-rate 2.0e-4 \
    --cross-language-learning \
    --rust-weight 1.0 \
    --elixir-weight 1.0
```

## Database Operations

### Training Data Preparation

The training data is prepared from existing code chunks in the database:

```sql
-- Query Rust code chunks
SELECT content, language, file_path, repo, inserted_at, id
FROM code_chunks 
WHERE language = 'rust' 
  AND LENGTH(content) >= 50
  AND file_path NOT LIKE '%test%';

-- Query Elixir code chunks  
SELECT content, language, file_path, repo, inserted_at, id
FROM code_chunks 
WHERE language = 'elixir' 
  AND LENGTH(content) >= 50
  AND file_path NOT LIKE '%test%';
```

### Quality Scoring

Training examples are scored based on language-specific quality indicators:

**Rust Quality Indicators:**
- Result<T, E> and Option<T> usage
- Documentation with /// comments
- Pattern matching with match
- Error propagation with ? operator
- Proper imports and module structure

**Elixir Quality Indicators:**
- @doc documentation
- Pattern matching
- Pipe operator |> usage
- OTP patterns (GenServer, Supervisor)
- Proper error handling with {:ok, result}

## Evaluation

### Language-Specific Metrics

```elixir
# Evaluate Rust performance
{:ok, rust_metrics} = evaluate_language_performance(rust_examples, "rust")

# Evaluate Elixir performance
{:ok, elixir_metrics} = evaluate_language_performance(elixir_examples, "elixir")

# Cross-language evaluation
{:ok, cross_metrics} = evaluate_cross_language_performance(rust_examples, elixir_examples)
```

### Evaluation Metrics

- **BLEU Score**: Code similarity to reference
- **ROUGE Score**: Semantic similarity
- **Syntax Correctness**: Compilation success rate
- **Semantic Similarity**: Functional equivalence
- **Code Quality**: Language-specific best practices

## Monitoring

### Training Progress

The training progress is tracked in the database:

```sql
-- View training progress
SELECT epoch, step, loss, learning_rate, training_time_seconds
FROM t5_training_progress 
WHERE training_session_id = 'session-id'
ORDER BY inserted_at DESC;
```

### Model Performance

```sql
-- View model performance
SELECT version, performance_metrics, evaluation_results
FROM t5_model_versions 
WHERE is_active = true;
```

## Troubleshooting

### Common Issues

1. **Insufficient Training Data**
   ```elixir
   # Check available code chunks
   Repo.aggregate(CodeStore, :count, :id)
   ```

2. **Memory Issues**
   ```bash
   # Reduce batch size
   --train-batch-size 2 --gradient-accumulation 16
   ```

3. **Model Loading Errors**
   ```elixir
   # Check model path
   File.exists?(Path.expand("~/.cache/singularity/codet5p-770m-rust-elixir"))
   ```

### Debugging

```elixir
# Check training session status
session = Repo.get(T5TrainingSession, session_id)
IO.inspect(session.status)

# Check training examples
examples = Repo.all(from e in T5TrainingExample, where: e.training_session_id == ^session_id)
IO.inspect(length(examples))
```

## Performance Optimization

### Training Optimization

- **LoRA Fine-tuning**: Reduces memory usage by 80%
- **Gradient Accumulation**: Enables larger effective batch sizes
- **Mixed Precision**: Uses bfloat16 for faster training
- **Cross-Language Learning**: Improves pattern transfer

### Inference Optimization

- **Language-Specific Parameters**: Optimized temperature and token limits
- **Quality Gating**: Filters low-quality generations
- **RAG Integration**: Uses codebase examples for better generation

## Future Enhancements

1. **Multi-Language Support**: Extend to Python, TypeScript, Go
2. **Real-Time Learning**: Continuous model updates from new code
3. **Custom Datasets**: Support for domain-specific training data
4. **Model Compression**: Quantization and pruning for faster inference
5. **A/B Testing**: Compare different model versions

## Contributing

To contribute to the Rust/Elixir T5 training pipeline:

1. Add new language patterns in `RustElixirT5Trainer`
2. Implement new quality indicators
3. Add evaluation metrics
4. Improve cross-language learning algorithms
5. Optimize training performance

## References

- [CodeT5+ Paper](https://arxiv.org/abs/2205.11275)
- [LoRA Paper](https://arxiv.org/abs/2106.09685)
- [Rust Best Practices](https://doc.rust-lang.org/book/)
- [Elixir Best Practices](https://elixir-lang.org/getting-started/)