# Mac + RTX 4080 Development Workflow

## Overview
- **Mac Laptop**: Lightweight development environment
- **Windows RTX 4080**: GPU-accelerated production/test environment
- **Remote Access**: Seamless connection between environments

## Development Workflow

### 1. Local Development on Mac
```bash
# Fast, lightweight development
cd singularity-incubation
nix develop .#dev  # No Python, quick startup

# Edit code, run tests
mix test
mix compile

# Commit changes
git add .
git commit -m "feat: add new feature"
git push
```

### 2. Deploy to RTX 4080 for Testing
```bash
# On RTX 4080 machine (Windows/WSL2)
cd singularity-incubation
git pull  # Get latest changes

# Start production environment with GPU
nix develop .#prod
just start-all

# Test with real GPU acceleration
# - Semantic search with embeddings
# - Code analysis with ML models
# - Autonomous agents with GPU power
```

### 3. Access Production from Mac
```bash
# SSH tunnel for web access
ssh -L 4000:localhost:4000 user@rtx4080-ip
# Now access http://localhost:4000 on Mac

# Or direct IP access
open http://rtx4080-ip:4000  # Phoenix app
open http://rtx4080-ip:3000  # AI server
```

## Environment Comparison

| Environment | Machine | GPU | Python | Use Case |
|-------------|---------|-----|--------|----------|
| `dev` | Mac | Metal (light) | ❌ | Fast development, testing |
| `prod` | RTX 4080 | CUDA (full) | ✅ | Production workloads, ML |

## File Sync Options

### Option 1: Git-based (Recommended)
```bash
# Develop on Mac, push to GitHub
git push origin main

# Pull on RTX 4080
ssh rtx4080 'cd singularity-incubation && git pull'
```

### Option 2: VS Code Remote SSH
- Install "Remote SSH" extension
- Connect directly to RTX 4080 machine
- Edit files remotely with full GPU access

### Option 3: File sharing
```bash
# Mount RTX 4080 share on Mac
# Edit files locally, sync to remote
```

## Performance Benefits

✅ **Mac Development**:
- Fast startup (no Python/ML dependencies)
- Battery-efficient for mobile work
- Full macOS ecosystem (Xcode, etc.)

✅ **RTX 4080 Production**:
- 16GB GPU memory for large models
- CUDA acceleration for embeddings
- Enterprise-grade ML performance

## Cost Analysis

- **RTX 4080**: Already owned = **$0/month**
- **Electricity**: ~$10/month extra
- **No cloud GPU costs**: Save $2,200/month
- **Mac development**: Unchanged

## Workflow Commands

### Quick Development Cycle
```bash
# Mac: Develop and test locally
mix test && git commit -am "work in progress"

# RTX 4080: Deploy and test with GPU
ssh rtx4080 'cd singularity && git pull && nix develop .#prod --command just start-all'

# Mac: Access production system
open http://rtx4080-ip:4000
```

### Remote GPU Testing
```bash
# Test GPU features remotely
curl http://rtx4080-ip:3000/api/embeddings \
  -X POST \
  -d '{"text": "test code"}'
```

This setup gives you **professional ML infrastructure** at **minimal cost** while keeping your Mac development experience smooth! 🚀