# Windows RTX 4080 Production Setup: Quick Start

## You Asked: Which K8s Option is Best?

For your Windows RTX 4080 setup, here's the answer:

| Option | Recommendation | Why |
|--------|---|---|
| **Podman** (This setup) | ✅ **START HERE** | Simplest, direct GPU access, 15 min setup |
| **Podman + K8s** | ⚠️ Later if scaling | Only if you add more machines |
| **Kind** | ❌ No GPU | Not for production GPU workloads |
| **Lima** | ❌ macOS only | You're on Windows |
| **Minikube** | ⚠️ Only for testing | Limited GPU, not production-ready |
| **OpenShift Local** | ❌ Overkill | Designed for enterprise, not single RTX 4080 |
| **Existing K8s Cluster** | ✅ If you have one | Use the K8s manifests we provided |

---

## TL;DR: What We Built

### Three Deployment Options

**Option 1: Podman Compose (RECOMMENDED)**
```
GitHub Actions (build) → Podman Compose (deploy) → Running on RTX 4080
- Deploy all 5 services in 1 command
- Direct GPU access to RTX 4080
- Simplest debugging and management
```

**Option 2: Kubernetes (When You Need Scaling)**
```
GitHub Actions (build) → K8s manifests (deploy) → K8s cluster
- Same manifests, run on Minikube, Kind, or existing cluster
- Better for future growth
- More complex to debug now
```

**Option 3: Hybrid (Podman + K8s)**
```
Run K8s inside Podman (on Windows) → Scale to multiple machines later
- Too complex for single RTX 4080
- Don't do this unless you need it
```

---

## Files We Created

```
production/
├── DEPLOYMENT_GUIDE.md                 ← Read this first
├── WINDOWS_RTX4080_SETUP.md           ← You are here
├── podman-compose.yml                  ← Deploy with this
├── nginx.conf                          ← Reverse proxy config
├── scripts/
│   ├── init-databases.sql              ← PostgreSQL setup
│   └── init-extensions.sql             ← PostgreSQL extensions
└── k8s/
    ├── postgresql-statefulset.yml      ← K8s: PostgreSQL
    ├── nats-statefulset.yml            ← K8s: NATS
    ├── deployments.yml                 ← K8s: All 5 apps
    └── ingress.yml                     ← K8s: Networking

.github/workflows/
└── deploy-production-windows-4080.yml  ← GitHub Actions CI/CD
```

---

## Step 1: Install Podman (5 minutes)

```powershell
# Option A: Using Chocolatey
choco install podman podman-compose

# Option B: Using Windows Package Manager
winget install RedHat.Podman
pip install podman-compose

# Option C: Download from https://podman.io/

# Verify installation
podman --version
podman-compose --version
nvidia-smi  # Verify RTX 4080 is detected
```

---

## Step 2: Configure GitHub Runner (10 minutes)

```powershell
# 1. Go to Settings → Actions → Runners → New self-hosted runner
# 2. Download runner for Windows
cd C:\runners
mkdir github-runner
cd github-runner

# 3. Download and extract runner
Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v2.x.x/actions-runner-win-x64-2.x.x.zip" -OutFile runner.zip
Expand-Archive -Path runner.zip

# 4. Configure runner
.\config.cmd --url https://github.com/yourorg/singularity --token YOUR_TOKEN

# 5. Run as service (optional but recommended)
.\svc.cmd install
.\svc.cmd start
```

---

## Step 3: Set Environment Variables (5 minutes)

```powershell
# Create production/.env file
$env_content = @"
REGISTRY=ghcr.io
IMAGE_PREFIX=yourorg/singularity
IMAGE_TAG=latest
SECRET_KEY_BASE=your-secret-key-min-64-chars
POSTGRES_PASSWORD=your-secure-postgres-password
ANTHROPIC_API_KEY=sk-ant-...
GOOGLE_AI_STUDIO_API_KEY=...
OPENAI_API_KEY=sk-proj-...
CENTRALCLOUD_URL=http://localhost:4001
GENESIS_URL=http://localhost:4002
LLM_SERVER_URL=http://localhost:3000
XLA_TARGET=cuda118
"@

Set-Content -Path production/.env -Value $env_content
```

---

## Step 4: Deploy (3 minutes)

```powershell
# From repository root
cd singularity-incubation

# Deploy all services
cd production
podman-compose --profile all up -d

# Wait for services to start
Start-Sleep -Seconds 30

# Check status
podman ps
podman-compose logs singularity

# Test it
Invoke-WebRequest http://localhost:4000/health
```

**That's it!** You're done. Services running on RTX 4080.

---

## Access Your Services

| Service | URL | Port |
|---------|-----|------|
| **Singularity** | http://localhost:4000 | 4000 |
| **NATS Admin** | http://localhost:8222 | 8222 |
| **PostgreSQL** | localhost:5432 | 5432 |
| **NATS WebSocket** | ws://localhost:4223 | 4223 |
| **Nginx Proxy** | http://localhost (when configured) | 80/443 |

---

## Useful Commands

```powershell
# See all services
podman-compose ps

# Check logs
podman-compose logs -f singularity

# Restart service
podman-compose restart singularity

# Stop all
podman-compose down

# Delete all (reset)
podman-compose down -v

# Check database
podman exec singularity-postgres psql -U postgres -l

# Check NATS
podman exec singularity-nats nats rtt
```

---

## GitHub Actions CI/CD

When you push to `main`:

```
Your code → GitHub Actions → Builds Nix packages →
  Pushes images to ghcr.io → Deploys to Podman on RTX 4080
```

**Monitor in:** GitHub repo → Actions tab

**Manual deploy:**
```powershell
gh workflow run deploy-production-windows-4080.yml -r main
```

---

## When You Need Kubernetes Later

If your team grows and you need Kubernetes:

```powershell
# Install Minikube (local testing)
choco install minikube

# Start cluster
minikube start --cpus=4 --memory=8192 --gpus=1

# Deploy using K8s manifests
kubectl apply -f production/k8s/postgresql-statefulset.yml
kubectl apply -f production/k8s/nats-statefulset.yml
kubectl apply -f production/k8s/deployments.yml
kubectl apply -f production/k8s/ingress.yml
```

The manifests are ready to use whenever you need K8s. No changes required.

---

## Troubleshooting

**Services won't start:**
```powershell
podman-compose logs singularity
# Check error, fix, restart
podman-compose restart singularity
```

**GPU not detected:**
```powershell
nvidia-smi  # Should show RTX 4080
podman run --rm --gpus=all nvidia/cuda:12.0-runtime nvidia-smi
```

**Port already in use:**
```powershell
# Change port in podman-compose.yml
# Or kill existing service
netstat -ano | findstr :4000
taskkill /PID [PID] /F
```

**Database issues:**
```powershell
podman exec singularity-postgres pg_isready
podman exec singularity-postgres psql -U postgres -l
```

---

## Architecture (Simple)

```
Windows RTX 4080
├─ Nginx (80/443) → routes to services
├─ Singularity (4000) → your main app + inference
├─ CentralCloud (4001) → knowledge authority
├─ Genesis (4002) → sandbox experiments
├─ LLM Server (3000) → AI provider gateway
├─ NATS (4222/4223) → message bus
└─ PostgreSQL (5432) → databases
    ├─ singularity DB
    ├─ centralcloud DB
    └─ genesis DB

All containers share:
- RTX 4080 GPU access
- Same network (172.30.0.0/16)
- Single PostgreSQL instance
```

---

## Next: Read Full Guide

For detailed setup, troubleshooting, and Kubernetes details:

👉 **See `production/DEPLOYMENT_GUIDE.md`**

---

## Support

- **GitHub Issues:** https://github.com/yourorg/singularity/issues
- **Logs:** `podman-compose logs -f SERVICE_NAME`
- **Health:** `curl http://localhost:4000/health`

---

## Summary

| Task | Time | Status |
|------|------|--------|
| Install Podman | 5 min | ⏹️ Do first |
| Configure GitHub Runner | 10 min | ⏹️ Do second |
| Set environment vars | 5 min | ⏹️ Do third |
| Deploy with Podman Compose | 3 min | ⏹️ Do fourth |
| **Total** | **~25 minutes** | ✅ You're done! |

**Your RTX 4080 will be running all 5 services with GPU acceleration in under 30 minutes.**
