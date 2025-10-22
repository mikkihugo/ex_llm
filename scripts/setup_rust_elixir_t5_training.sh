#!/bin/bash
# Setup Rust/Elixir T5 Training Pipeline
# This script prepares the environment and starts training on Rust and Elixir code

set -e

echo "🚀 Setting up Rust/Elixir T5 Training Pipeline"

# Check if we're in the right directory
if [ ! -f "singularity_app/mix.exs" ]; then
    echo "❌ Please run this script from the singularity project root"
    exit 1
fi

# Check if Nix is available
if ! command -v nix &> /dev/null; then
    echo "❌ Nix is required but not installed"
    exit 1
fi

echo "📦 Setting up Nix environment for LLM training..."

# Enter Nix shell with LLM training environment
nix develop .#llm-train --command bash << 'EOF'
echo "🐍 Setting up Python environment..."

# Check Python version
python --version

# Install required packages
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
pip install transformers accelerate datasets peft
pip install tqdm wandb  # For monitoring

echo "🗄️ Setting up database..."

# Start PostgreSQL if not running
if ! pg_isready -q; then
    echo "Starting PostgreSQL..."
    pg_ctl start -D ~/.local/state/postgres
    sleep 5
fi

# Create database if it doesn't exist
createdb singularity 2>/dev/null || true

# Run migrations
cd singularity_app
mix ecto.migrate

echo "📊 Preparing training data from database..."

# Create training data directory
mkdir -p data/rust_elixir

# Use Elixir to extract training data from database
elixir -e "
alias Singularity.RustElixirT5Trainer

# Prepare multi-language training data
case RustElixirT5Trainer.prepare_multi_language_training(
  name: \"rust_elixir_v1\",
  languages: [\"rust\", \"elixir\"],
  max_examples: 20000,
  cross_language_learning: true,
  quality_threshold: 0.7
) do
  {:ok, session_id} ->
    IO.puts(\"✅ Training data prepared: #{session_id}\")
    System.halt(0)
  {:error, reason} ->
    IO.puts(\"❌ Failed to prepare training data: #{inspect(reason)}\")
    System.halt(1)
end
"

echo "🎯 Starting T5 fine-tuning..."

# Run the specialized Rust/Elixir training script
python llm-server/scripts/train_rust_elixir_t5.py \
    --train-file data/rust_elixir/train.jsonl \
    --eval-file data/rust_elixir/eval.jsonl \
    --output-dir runs/codet5p-770m-rust-elixir \
    --base-model Salesforce/codet5p-770m \
    --epochs 12 \
    --learning-rate 2.0e-4 \
    --train-batch-size 4 \
    --gradient-accumulation 8 \
    --lora-rank 16 \
    --lora-alpha 32 \
    --cross-language-learning \
    --rust-weight 1.0 \
    --elixir-weight 1.0

echo "✅ Training completed!"

# Deploy the trained model
echo "🚀 Deploying trained model..."

elixir -e "
alias Singularity.RustElixirT5Trainer

# Get the latest training session
case RustElixirT5Trainer.prepare_multi_language_training(
  name: \"rust_elixir_v1\",
  languages: [\"rust\", \"elixir\"]
) do
  {:ok, session_id} ->
    # Fine-tune the model
    case RustElixirT5Trainer.fine_tune(session_id, epochs: 12) do
      {:ok, model_id} ->
        IO.puts(\"✅ Model fine-tuned: #{model_id}\")
        
        # Deploy the model
        case Singularity.T5FineTuner.deploy_model(model_id) do
          :ok ->
            IO.puts(\"✅ Model deployed successfully\")
          {:error, reason} ->
            IO.puts(\"❌ Failed to deploy model: #{inspect(reason)}\")
        end
      {:error, reason} ->
        IO.puts(\"❌ Failed to fine-tune model: #{inspect(reason)}\")
    end
  {:error, reason} ->
    IO.puts(\"❌ Failed to prepare training: #{inspect(reason)}\")
end
"

echo "🎉 Rust/Elixir T5 training pipeline completed!"
echo ""
echo "📋 Next steps:"
echo "1. Test the trained model with GeneratorEngine.code_generate/5"
echo "2. Evaluate performance with RustElixirT5Trainer.evaluate_rust_elixir_performance/1"
echo "3. Monitor model performance in the database"
echo ""
echo "🔧 Usage examples:"
echo "  # Generate Rust code"
echo "  GeneratorEngine.code_generate(\"Create a REST API client\", \"rust\", nil, \"production\", true)"
echo ""
echo "  # Generate Elixir code"
echo "  GeneratorEngine.code_generate(\"Create a GenServer for caching\", \"elixir\", nil, \"production\", true)"

EOF

echo "✅ Rust/Elixir T5 training setup completed!"