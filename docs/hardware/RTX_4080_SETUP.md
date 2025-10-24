# RTX 4080 Setup Guide: Run Singularity Directly on GPU Machine

## Why Run Directly on GPU Machine?

✅ **Better Performance**: No network latency for GPU operations
✅ **Full GPU Utilization**: Direct access to all 16GB VRAM
✅ **Cost Effective**: Use hardware you already own
✅ **Simpler Setup**: No complex remote GPU passthrough

## Setup Steps for Windows RTX 4080

### 1. Install WSL2 with CUDA Support

```powershell
# Enable WSL2 with latest Ubuntu LTS (24.04)
wsl --install -d Ubuntu-24.04

# Install NVIDIA drivers in Windows
# Download from: https://www.nvidia.com/Download/index.aspx

# Install CUDA toolkit in WSL2
wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update
sudo apt-get install cuda-toolkit-12-4
```

### 2. Install Nix in WSL2

```bash
# Install Nix
curl -L https://nixos.org/nix/install | sh

# Enable flakes
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Source Nix
. ~/.nix-profile/etc/profile.d/nix.sh
```

### 3. Clone and Setup Singularity

```bash
# Clone your repo
git clone https://github.com/mikkihugo/singularity-incubation.git
cd singularity-incubation

# Enable GPU in production environment
# Edit flake.nix to enable GPU for prod environment
```

### 4. Configure for GPU Usage

Update your `flake.nix` to enable GPU in production:

```nix
prod = {
  name = "Remote Production Environment";
  purpose = "Production deployment on RTX 4080";
  services = ["nats" "postgresql" "llm-server" "phoenix"];
  gpu = true;  # Enable GPU acceleration
  caching = true;
  remote = false;  # Running locally on GPU machine
  host = "localhost";  # Local access
  docker = false;  # Direct Nix deployment
  includePython = true;  # Enable ML stack for GPU
};
```

### 5. Test GPU Access

```bash
# Enter production environment
nix develop .#prod

# Test GPU detection
nvidia-smi
# Should show: NVIDIA RTX 4080, 16GB VRAM

# Test CUDA
nvcc --version
# Should show CUDA 12.4 or similar
```

### 6. Run Singularity with GPU

```bash
# Start all services with GPU acceleration
just start-all

# Check GPU usage
nvidia-smi
# Should show GPU memory usage by Elixir/Python processes
```

## Remote Access from macOS

Once running on the GPU machine, access from your Mac:

### Option A: Web Interface
```bash
# On GPU machine (Windows/WSL2)
# Services run on localhost:4000, 3000, etc.

# From macOS, access via:
# http://[GPU_MACHINE_IP]:4000  # Phoenix app
# http://[GPU_MACHINE_IP]:3000  # AI server
```

### Option B: SSH Tunneling
```bash
# From macOS
ssh -L 4000:localhost:4000 user@gpu-machine-ip
# Now access localhost:4000 on macOS
```

### Option C: VS Code Remote SSH
- Install "Remote SSH" extension in VS Code
- Connect to `user@gpu-machine-ip`
- Develop directly on GPU machine

## Performance Comparison

| Method | Latency | GPU Utilization | Setup Complexity |
|--------|---------|-----------------|------------------|
| Direct on GPU | 0ms | 100% | Medium |
| Remote GPU access | 10-50ms | 80% | High |
| Serverless API | 200-500ms | N/A | Low |

## Cost Analysis

- **RTX 4080 (already owned)**: $0 additional cost
- **Electricity**: ~$5-10/month extra
- **Serverless alternative**: $5-50/month
- **Cloud GPU**: $2,200/month

**Verdict**: Using your RTX 4080 saves $1,000-2,000/month vs cloud GPU!

## Troubleshooting

### GPU Not Detected
```bash
# Check NVIDIA drivers
nvidia-smi

# Check CUDA installation
nvcc --version

# Check Nix CUDA packages
nix-shell -p cudaPackages.cudatoolkit --run "nvcc --version"
```

### Memory Issues
```bash
# Monitor GPU memory
watch -n 1 nvidia-smi

# Adjust model batch sizes in Elixir config
# Reduce embedding dimensions if needed
```

### Network Access
```bash
# Allow firewall access (Windows)
# Open ports 4000, 3000, 5432, 4222 in Windows Firewall

# Find GPU machine IP
ip addr show eth0
```

This setup gives you **enterprise-grade GPU performance** at **consumer cost**! 🚀