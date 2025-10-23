# Production Deployment Guide: Windows RTX 4080 Setup

## Your Setup

**Machine**: Windows with RTX 4080 GPU + lots of RAM (central hub)
**CI/CD**: GitHub Actions runner on that Windows machine
**Container Runtime**: Podman (preferred over Docker)
**Orchestration**: Kubernetes option available

---

## Three Deployment Options

### Option 1: Podman (Simplest - START HERE) ✅ RECOMMENDED

**Best for:** Single RTX 4080, direct GPU access, simple management

```
GitHub Actions → Podman Compose → Running Services
└─ All containers on same Windows machine
└─ Direct RTX 4080 access via --gpus=all
└─ Easiest to set up and debug
```

**Pros:**
- ✅ Simplest deployment (3 commands)
- ✅ Direct GPU passthrough (best CUDA performance)
- ✅ No K8s complexity
- ✅ Easy logs, debugging, monitoring
- ✅ Single machine = single point of control

**Cons:**
- ❌ No built-in scaling (can't add more workers)
- ❌ No load balancing
- ❌ Manual restart if services fail

**Setup Time:** 15 minutes

---

### Option 2: Podman + Kubernetes (Hybrid) ⚠️ ONLY IF NEEDED

**Best for:** Future growth (adding more RTX GPUs/machines)

```
GitHub Actions → Podman → Kubernetes (on that Podman)
└─ K8s runs inside Podman for isolation
└─ Can scale to multiple nodes later
└─ More management overhead now
```

**Pros:**
- ✅ Can scale to multiple machines later
- ✅ Built-in health checks and auto-restart
- ✅ Declarative infrastructure
- ✅ Future-proof

**Cons:**
- ❌ Complex to debug (K8s abstractions)
- ❌ Higher resource overhead (~1GB just for K8s)
- ❌ Longer setup time

**Setup Time:** 45 minutes

---

### Option 3: Existing Kubernetes Cluster ⚠️ ONLY IF YOU HAVE ONE

**Best for:** If you already have a K8s cluster

**The five K8s options:**

| Option | Resources | Complexity | GPU Support | Best Use |
|--------|-----------|-----------|---|---|
| **Kind** | Low (laptop) | Medium | ❌ No (not production) | Dev/test |
| **Lima** | Low (macOS) | Medium | ❌ No | Dev only |
| **Minikube** | Low (laptop) | Low | ⚠️ Limited | Dev/test |
| **OpenShift Local** | High (4+ CPU) | High | ✅ Yes | Red Hat ecosystems |
| **Existing Cluster** | N/A | N/A | ✅ Maybe | Production |

**Recommendation for Windows RTX 4080:**
- **NOT Kind** - No GPU support
- **NOT Lima** - macOS only
- **NOT Minikube** - Limited GPU, not designed for RTX 4080
- **NOT OpenShift** - Overkill for single machine + requires Red Hat subscription
- **If you have existing cluster** - Use it with `kubectl apply` from deployment manifests

---

## RECOMMENDED PATH: Podman on Windows RTX 4080

### Step 1: Install Prerequisites

```powershell
# 1. Install Podman Desktop (GUI or CLI)
winget install RedHat.Podman
podman --version

# 2. Install Podman Compose
pip install podman-compose

# 3. Verify GPU access
nvidia-smi  # Should list RTX 4080

# 4. Start Podman machine (if using WSL2)
podman machine start
```

### Step 2: Clone and Configure

```powershell
# 1. Clone repository
git clone https://github.com/yourorg/singularity.git
cd singularity

# 2. Set up environment variables
$env:REGISTRY = "ghcr.io"
$env:IMAGE_PREFIX = "yourorg/singularity"
$env:IMAGE_TAG = "latest"
$env:SECRET_KEY_BASE = "your-secret-key-base-min-64-chars"
$env:POSTGRES_PASSWORD = "your-secure-postgres-password"
$env:ANTHROPIC_API_KEY = "sk-ant-..."
$env:GOOGLE_AI_STUDIO_API_KEY = "..."
$env:OPENAI_API_KEY = "sk-proj-..."

# 3. Save as .env file for docker-compose
# Create production/.env
```

### Step 3: Build Services

In GitHub Actions (automatic), but can also build locally:

```powershell
# Build all images
nix build .#singularity-container-image
nix build .#centralcloud-container-image
nix build .#genesis-container-image
nix build .#llm-server-container-image

# Load into Podman
$images = @(
    "result/*/singularity-*.tar.gz",
    "result/*/centralcloud-*.tar.gz",
    "result/*/genesis-*.tar.gz",
    "result/*/llm-server-*.tar.gz"
)

foreach ($image in $images) {
    Get-ChildItem $image | ForEach-Object {
        podman load -i $_.FullName
    }
}
```

### Step 4: Deploy with Podman Compose

```powershell
# Start all services
cd production
podman-compose --profile all up -d

# Verify services are running
podman ps

# Check logs
podman-compose logs -f singularity
podman-compose logs -f centralcloud
podman-compose logs -f genesis
podman-compose logs -f llm-server
podman-compose logs -f nats
podman-compose logs -f postgresql
```

### Step 5: Test Deployment

```powershell
# Health checks
Invoke-WebRequest http://localhost:4000/health
Invoke-WebRequest http://localhost:4001/health
Invoke-WebRequest http://localhost:4002/health
Invoke-WebRequest http://localhost:3000/health

# Database check
psql -h localhost -U postgres -d singularity -c "SELECT version();"

# NATS check
podman exec singularity-nats nats rtt

# Access applications
# Singularity: http://localhost:4000
# NATS Admin: http://localhost:8222
# PostgreSQL: localhost:5432
```

---

## GitHub Actions CI/CD Setup

### 1. Configure GitHub Repository

```powershell
# 1. Add secrets to GitHub Actions
# Settings → Secrets and variables → Actions

# Add these secrets:
- GITHUB_TOKEN (auto, but verify it's enabled)
- Add any API keys needed

# 2. Create runner on Windows RTX 4080
# Settings → Actions → Runners → New self-hosted runner

# Download and configure runner
cd C:\runners
.\config.cmd --url https://github.com/yourorg/singularity --token YOUR_TOKEN
.\run.cmd  # Start runner in background
```

### 2. Deploy on Push to Main

```powershell
# When you push to main:
git push origin main

# GitHub Actions automatically:
# 1. Runs tests
# 2. Builds Nix packages
# 3. Builds OCI images
# 4. Pushes to ghcr.io
# 5. Deploys to RTX 4080 via Podman Compose

# Monitor in Actions tab on GitHub
```

### 3. Manual Deploy Workflow

```powershell
# Option A: Trigger from GitHub UI
# Actions → Deploy to Production (Windows RTX 4080) → Run workflow

# Option B: Deploy from command line
gh workflow run deploy-production-windows-4080.yml -r main
```

---

## Architecture After Deployment

```
┌──────────────────────────────────────────────────────────────┐
│                    Windows RTX 4080                          │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Nginx Reverse Proxy (Port 80/443)                  │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Podman Network (172.30.0.0/16)                       │ │
│  │                                                        │ │
│  │  ┌─────────────────────────────────────────────────┐ │ │
│  │  │ Singularity (4000) - GPU accelerated inference  │ │ │
│  │  └─────────────────────────────────────────────────┘ │ │
│  │                          ↓                             │ │
│  │  ┌─────────────────────────────────────────────────┐ │ │
│  │  │ CentralCloud (4001) - Knowledge authority       │ │ │
│  │  └─────────────────────────────────────────────────┘ │ │
│  │                          ↓                             │ │
│  │  ┌─────────────────────────────────────────────────┐ │ │
│  │  │ Genesis (4002) - Experiment sandbox             │ │ │
│  │  └─────────────────────────────────────────────────┘ │ │
│  │                          ↓                             │ │
│  │  ┌─────────────────────────────────────────────────┐ │ │
│  │  │ NATS (4222) - Message bus with JetStream        │ │ │
│  │  └─────────────────────────────────────────────────┘ │ │
│  │                          ↓                             │ │
│  │  ┌─────────────────────────────────────────────────┐ │ │
│  │  │ LLM Server (3000) - AI provider gateway          │ │ │
│  │  └─────────────────────────────────────────────────┘ │ │
│  │                          ↓                             │ │
│  │  ┌─────────────────────────────────────────────────┐ │ │
│  │  │ PostgreSQL (5432)                               │ │ │
│  │  │  ├─ singularity DB (main app)                   │ │ │
│  │  │  ├─ centralcloud DB (knowledge)                 │ │ │
│  │  │  └─ genesis DB (experiments)                    │ │ │
│  │  └─────────────────────────────────────────────────┘ │ │
│  │                                                        │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  GPU Passthrough: NVIDIA CUDA 12.x (RTX 4080)        │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## Monitoring and Management

### Health Checks

```powershell
# Check service health
$services = @('singularity', 'centralcloud', 'genesis', 'llm-server', 'nats', 'postgresql')
foreach ($service in $services) {
    $status = podman ps | Select-String $service
    Write-Host "$service : $status"
}

# Check logs
podman-compose logs --tail=50 singularity

# Check database
podman exec singularity-postgres psql -U postgres -l

# Check NATS
podman exec singularity-nats nats rtt
podman exec singularity-nats nats jetstream info
```

### Useful Commands

```powershell
# View all containers
podman-compose ps

# Stop services
podman-compose down

# Restart service
podman-compose restart singularity

# Scale service (not recommended for stateful apps)
podman-compose up -d --scale singularity=3

# Export logs
podman-compose logs > production.log

# Database backup
podman exec singularity-postgres pg_dump -U postgres singularity > backup.sql

# Database restore
cat backup.sql | podman exec -i singularity-postgres psql -U postgres singularity
```

---

## If You Later Need Kubernetes

When you want to move from Podman to Kubernetes (if team grows):

### Step 1: Set up K8s Cluster

**Option A: Minikube (for testing)**
```powershell
# Install Minikube for Windows
choco install minikube

# Start cluster with GPU support
minikube start --driver=hyperv --cpus=4 --memory=8192 --gpus=1

# Enable NVIDIA GPU plugin
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/master/nvidia-device-plugin.yml
```

**Option B: Use existing cluster**
```powershell
# Configure kubectl to point to your cluster
kubectl config use-context your-cluster-name
```

### Step 2: Deploy Using K8s Manifests

```powershell
# Create namespace
kubectl create namespace singularity

# Apply manifests in order
kubectl apply -f production/k8s/postgresql-statefulset.yml
kubectl wait --for=condition=ready pod -l app=postgresql -n singularity --timeout=300s

kubectl apply -f production/k8s/nats-statefulset.yml
kubectl wait --for=condition=ready pod -l app=nats -n singularity --timeout=300s

kubectl apply -f production/k8s/deployments.yml
kubectl wait --for=condition=ready pod -l app=singularity -n singularity --timeout=600s

kubectl apply -f production/k8s/ingress.yml

# Check deployment
kubectl get pods -n singularity
kubectl get services -n singularity
kubectl get ingress -n singularity
```

### Step 3: Scale Services

```powershell
# Scale Singularity to 3 replicas
kubectl scale deployment singularity -n singularity --replicas=3

# Auto-scale based on CPU
kubectl autoscale deployment singularity -n singularity --min=1 --max=5 --cpu-percent=70
```

---

## Troubleshooting

### Service won't start

```powershell
# Check logs
podman logs singularity-app

# Check environment variables
podman inspect singularity-app | Select-String -Pattern "Env"

# Verify database connectivity
podman exec singularity-postgres psql -U postgres -c "SELECT 1"

# Restart service
podman-compose restart singularity
```

### GPU not detected

```powershell
# Verify NVIDIA drivers
nvidia-smi

# Check Podman GPU support
podman run --rm --gpus=all nvidia/cuda:12.0-runtime nvidia-smi

# Fix: Update NVIDIA Container Toolkit
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
```

### Database issues

```powershell
# Check PostgreSQL is running
podman exec singularity-postgres pg_isready

# Check database size
podman exec singularity-postgres psql -U postgres -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database;"

# Run migrations
podman exec singularity-app mix ecto.migrate
```

### NATS connection errors

```powershell
# Check NATS logs
podman logs singularity-nats

# Verify NATS is listening
podman exec singularity-nats nats server info

# Test NATS connectivity
podman run --network singularity-net -it nats:latest nats -s nats://singularity-nats:4222 -info
```

---

## Next Steps

### Day 1: Get it running
1. ✅ Install Podman
2. ✅ Configure GitHub runner
3. ✅ Set up environment variables
4. ✅ Deploy with `podman-compose up`

### Week 1: Stabilize
1. Set up backups
2. Configure monitoring (Prometheus/Grafana)
3. Set up log aggregation (ELK stack)
4. Implement alerting

### Month 1: Optimize
1. Tune PostgreSQL for RTX 4080 workloads
2. Implement caching strategies
3. Profile GPU usage
4. Optimize NATS message routing

### Growth: Kubernetes (if needed)
1. Set up K8s cluster
2. Migrate manifests
3. Add more worker nodes
4. Implement federation

---

## File Reference

**Files Created:**

| File | Purpose |
|------|---------|
| `.github/workflows/deploy-production-windows-4080.yml` | GitHub Actions CI/CD pipeline |
| `production/podman-compose.yml` | Podman Compose configuration |
| `production/nginx.conf` | Reverse proxy configuration |
| `production/scripts/init-databases.sql` | PostgreSQL initialization |
| `production/scripts/init-extensions.sql` | PostgreSQL extensions |
| `production/k8s/postgresql-statefulset.yml` | K8s PostgreSQL |
| `production/k8s/nats-statefulset.yml` | K8s NATS |
| `production/k8s/deployments.yml` | K8s app deployments |
| `production/k8s/ingress.yml` | K8s ingress & networking |

---

## Support

For issues, check:
1. Logs: `podman-compose logs -f SERVICE_NAME`
2. Health: `curl http://localhost:4000/health`
3. GitHub Issues: https://github.com/yourorg/singularity/issues
