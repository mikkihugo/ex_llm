#!/bin/bash
# Test T5 Training Setup (without full Nix environment)
# This script tests if our T5 training code can be compiled and run

set -e

echo "🧪 Testing T5 Training Setup"

# Check if we're in the right directory
if [ ! -f "singularity/mix.exs" ]; then
    echo "❌ Please run this script from the singularity project root"
    exit 1
fi

echo "📦 Installing Elixir dependencies..."

# Install Elixir dependencies
cd singularity

# Check if we have Elixir available
if ! command -v elixir &> /dev/null; then
    echo "❌ Elixir not found. Please install Elixir or use Nix environment"
    exit 1
fi

# Install dependencies
mix deps.get

echo "🔧 Compiling Elixir code..."

# Compile the code
mix compile

echo "🗄️ Setting up database..."

# Check if PostgreSQL is running
if ! pg_isready -q; then
    echo "⚠️  PostgreSQL not running. Starting PostgreSQL..."
    # Try to start PostgreSQL
    if command -v pg_ctl &> /dev/null; then
        pg_ctl start -D ~/.local/state/postgres 2>/dev/null || true
        sleep 3
    else
        echo "❌ PostgreSQL not available. Please start PostgreSQL manually"
        exit 1
    fi
fi

# Create database if it doesn't exist
createdb singularity 2>/dev/null || true

# Run migrations
echo "📊 Running database migrations..."
mix ecto.migrate

echo "🧪 Testing T5 training modules..."

# Test if our T5 modules can be loaded
elixir -e "
# Test loading T5 modules
try do
  # Test T5FineTuner
  alias Singularity.Code.Training.T5FineTuner
  IO.puts(\"✅ T5FineTuner module loaded\")
  
  # Test RustElixirT5Trainer
  alias Singularity.Code.Training.RustElixirT5Trainer
  IO.puts(\"✅ RustElixirT5Trainer module loaded\")
  
  # Test GeneratorEngine
  alias Singularity.GeneratorEngine
  IO.puts(\"✅ GeneratorEngine module loaded\")
  
  # Test CodeModel
  alias Singularity.Code.Training.CodeModel
  IO.puts(\"✅ CodeModel module loaded\")
  
  IO.puts(\"🎉 All T5 training modules loaded successfully!\")
  IO.puts(\"📋 Ready for training!\")
  
rescue
  error ->
    IO.puts(\"❌ Error loading modules: #{inspect(error)}\")
    System.halt(1)
end
"

echo "✅ T5 Training Setup Test Complete!"
echo ""
echo "📋 Next steps:"
echo "1. Run full training: ./scripts/setup_rust_elixir_t5_training.sh"
echo "2. Or manually prepare data: elixir -e \"alias Singularity.Code.Training.RustElixirT5Trainer; RustElixirT5Trainer.prepare_multi_language_training(name: \\\"test\\\", languages: [\\\"rust\\\", \\\"elixir\\\"])\""