# GitHub Actions Self-Hosted Runner on RTX 4080

## Overview
Run GitHub Actions workflows directly on your RTX 4080 Windows machine for:
- ✅ GPU-accelerated testing
- ✅ Automated deployments
- ✅ CI/CD with your hardware
- ✅ Trigger from Mac development

## Setup Steps

### 1. Install Self-Hosted Runner on Windows

1. **Download Runner**:
   ```powershell
   # Create runner directory
   mkdir C:\actions-runner
   cd C:\actions-runner

   # Download latest runner
   Invoke-WebRequest -Uri https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-win-x64-2.311.0.zip -OutFile actions-runner.zip
   Add-Type -AssemblyName System.IO.Compression.FileSystem
   [System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD/actions-runner.zip", "$PWD")
   ```

2. **Configure Runner**:
   ```powershell
   # Configure (replace with your repo details)
   .\config.cmd --url https://github.com/mikkihugo/singularity-incubation --token YOUR_TOKEN --name rtx4080-runner --labels rtx4080,gpu,cuda --unattended
   ```

3. **Install as Service**:
   ```powershell
   # Install and start as Windows service
   .\install.cmd
   .\start.cmd
   ```

### 2. Create GitHub Actions Workflows

Create `.github/workflows/rtx4080-gpu.yml`:

```yaml
name: RTX 4080 GPU CI/CD

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:  # Manual trigger from GitHub UI

jobs:
  test-with-gpu:
    runs-on: [self-hosted, rtx4080]

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Nix
      uses: cachix/install-nix-action@v22
      with:
        nix_path: nixpkgs=channel:nixos-unstable

    - name: Setup WSL2 (if needed)
      run: |
        # Ensure WSL2 is running
        wsl --list --running
        wsl --distribution Ubuntu-24.04 -- bash -c "echo WSL2 ready"

    - name: Run GPU Tests
      run: |
        cd singularity-incubation
        nix develop .#prod --command mix test

    - name: GPU Performance Test
      run: |
        # Test GPU embeddings
        nix develop .#prod --command elixir -e "
        # Test GPU acceleration
        "

    - name: Deploy to Production
      if: github.ref == 'refs/heads/main'
      run: |
        # Deploy on same machine
        nix develop .#prod --command just start-all

  gpu-benchmarks:
    runs-on: [self-hosted, rtx4080]
    if: github.event_name == 'workflow_dispatch'

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Run GPU Benchmarks
      run: |
        cd singularity-incubation
        nix develop .#prod --command bash -c "
        echo '=== GPU Benchmarks ==='
        nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv
        echo '=== CUDA Test ==='
        python3 -c 'import torch; print(f\"PyTorch CUDA: {torch.cuda.is_available()}\")'
        "
```

### 3. Trigger from Mac

**Option A: Push to trigger automatically**
```bash
# On Mac - push changes
git add .
git commit -m "feat: add new feature"
git push origin main
# Automatically runs on RTX 4080
```

**Option B: Manual trigger from GitHub**
- Go to Actions tab in GitHub
- Click "RTX 4080 GPU CI/CD"
- Click "Run workflow"

**Option C: Use GitHub CLI**
```bash
# Trigger workflow from Mac
gh workflow run "RTX 4080 GPU CI/CD"
```

## Benefits

✅ **Automatic GPU Testing**: Every push tested with real GPU
✅ **No Manual Deployment**: GitHub handles the workflow
✅ **Remote Triggering**: Trigger from Mac, runs on RTX 4080
✅ **Cost Free**: Uses your existing hardware
✅ **Scalable**: Can add more runners later

## Runner Management

### Check Runner Status
```powershell
# Check service status
Get-Service actions.runner.*

# View logs
Get-Content "C:\actions-runner\_diag\*.log" -Tail 50
```

### Update Runner
```powershell
cd C:\actions-runner
.\stop.cmd
.\update.cmd
.\start.cmd
```

### Remove Runner
```powershell
cd C:\actions-runner
.\stop.cmd
.\remove.cmd
```

## Security Considerations

- **Self-hosted runners** have access to your hardware
- **Use with trusted repositories only**
- **Network isolation** if concerned about security
- **Regular updates** of runner software

## Advanced Setup

### Multiple Labels
```powershell
# Configure with multiple labels
.\config.cmd --labels rtx4080,gpu,cuda,ml,production
```

### Runner Groups (GitHub Enterprise)
- Group runners by capability
- Control which workflows use which runners
- Better resource management

### GPU Monitoring
```yaml
- name: GPU Monitoring
  run: |
    nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv
    # Log to monitoring system
```

This gives you **enterprise-grade CI/CD** running on your **RTX 4080 GPU** - all triggered from your Mac development workflow! 🚀