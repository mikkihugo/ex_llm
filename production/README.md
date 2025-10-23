# Singularity Production Deployment - Windows RTX 4080

Complete production setup for Windows RTX 4080 with GitHub Actions CI/CD.

## Quick Start (One Command)

```powershell
# Run as Administrator
.\setup-windows.ps1
```

This installs everything and configures your GitHub runner automatically.

## What Gets Installed

✅ **Podman** - Container runtime
✅ **Podman Compose** - Multi-container orchestration
✅ **GitHub CLI (gh)** - GitHub integration
✅ **GitHub Actions Runner** - Windows Service for CI/CD
✅ **Environment Configuration** - Preconfigured .env file

## Files in This Directory

### Setup Scripts
| File | Purpose |
|------|---------|
| `setup-windows.ps1` | Complete setup (install + configure runner) |
| `one-liner.ps1` | Quick wrapper for copy-paste |
| `deploy-windows.ps1` | Deploy, manage, and monitor services |

### Configuration
| File | Purpose |
|------|---------|
| `.env.production.example` | Environment template (copy to `.env` and edit) |
| `podman-compose.yml` | All 7 services configuration |
| `nginx.conf` | Reverse proxy with SSL/TLS |

### Database
| File | Purpose |
|------|---------|
| `scripts/init-databases.sql` | PostgreSQL database initialization |
| `scripts/init-extensions.sql` | PostgreSQL extensions setup |

### Kubernetes (Optional)
| File | Purpose |
|------|---------|
| `k8s/postgresql-statefulset.yml` | K8s PostgreSQL database |
| `k8s/nats-statefulset.yml` | K8s message bus |
| `k8s/deployments.yml` | K8s service deployments |
| `k8s/ingress.yml` | K8s networking & monitoring |

### Documentation
| File | Purpose |
|------|---------|
| `README.md` | This file |
| `WINDOWS_QUICK_START.md` | Step-by-step guide |
| `DEPLOYMENT_GUIDE.md` | Comprehensive reference |

---

## Typical Workflow

### 1. Initial Setup (First Time Only)

```powershell
# Run as Administrator
cd production
.\setup-windows.ps1

# Follow prompts:
# - Installs Podman, GitHub CLI, etc.
# - Authenticates with GitHub
# - Creates GitHub Actions runner (Windows Service)
# - Creates .env file
```

**Time: ~15 minutes**

### 2. Configure Environment

```powershell
# Edit .env with your values
notepad .env

# Required changes:
# - POSTGRES_PASSWORD (secure password)
# - SECRET_KEY_BASE (random string)
# - ANTHROPIC_API_KEY (your key)
# - GOOGLE_AI_STUDIO_API_KEY (your key)
# - OPENAI_API_KEY (your key)
```

**Time: ~5 minutes**

### 3. Deploy Services

```powershell
# Start all services
.\deploy-windows.ps1

# Services will be running on:
# - Singularity: http://localhost:4000
# - NATS Admin: http://localhost:8222
# - PostgreSQL: localhost:5432
```

**Time: ~2 minutes**

### 4. Verify GitHub Runner

```powershell
# Check that runner is online:
# GitHub → Settings → Actions → Runners
# Should see: "rtx-4080-runner" (online)
```

**Time: ~1 minute**

---

## Everyday Commands

### Deploy & Monitor

```powershell
# Deploy all services
.\deploy-windows.ps1

# Stop all services
.\deploy-windows.ps1 -Stop

# Restart services
.\deploy-windows.ps1 -Restart

# View live logs
.\deploy-windows.ps1 -Logs
```

### Manage Services

```powershell
# Check running containers
podman ps

# View resource usage
podman stats

# Connect to specific service logs
podman-compose logs -f singularity
podman-compose logs -f postgresql
```

### Database Access

```powershell
# Connect to database
$env:PGPASSWORD="your-postgres-password"
psql -h localhost -U postgres -d singularity

# List all databases
psql -h localhost -U postgres -l

# Backup
podman exec singularity-postgres pg_dump -U postgres singularity > backup.sql

# Restore
cat backup.sql | podman exec -i singularity-postgres psql -U postgres singularity
```

---

## Services Running

| Service | Port | Purpose |
|---------|------|---------|
| **Singularity** | 4000 | Main app with GPU inference |
| **CentralCloud** | 4001 | Knowledge authority |
| **Genesis** | 4002 | Experiment sandbox |
| **LLM Server** | 3000 | AI provider gateway |
| **NATS** | 4222 | Message bus |
| **NATS WebSocket** | 4223 | WebSocket access |
| **NATS Admin** | 8222 | Monitoring interface |
| **PostgreSQL** | 5432 | Database (3 databases) |
| **Nginx** | 80/443 | Reverse proxy |

---

## GitHub Actions CI/CD

Your GitHub runner is now configured as a Windows Service.

### How It Works

1. You push code to `main` branch
2. GitHub Actions automatically triggers
3. Workflow runs on your Windows RTX 4080 runner
4. Services are built and deployed
5. Results appear in GitHub Actions tab

### View Workflow Runs

```powershell
# List recent runs
gh run list -R mikkihugo/singularity-incubation

# View specific run
gh run view RUN_ID -R mikkihugo/singularity-incubation
```

### Manage Runner Service

```powershell
# Check runner status
Get-Service "GitHub Actions Runner" | Select-Object Status

# Start runner service
Start-Service "GitHub Actions Runner"

# Stop runner service
Stop-Service "GitHub Actions Runner"

# Restart runner
Restart-Service "GitHub Actions Runner"
```

### View Runner Location

Runner is installed at:
```
C:\runners\singularity-incubation\
```

---

## Troubleshooting

### Runner Not Appearing in GitHub

1. Check service is running:
   ```powershell
   Get-Service "GitHub Actions Runner" | Select-Object Status
   ```

2. Check logs:
   ```powershell
   Get-Content "C:\runners\singularity-incubation\_diag\*.log" | Select-Object -Last 20
   ```

3. Restart runner:
   ```powershell
   Restart-Service "GitHub Actions Runner"
   ```

### Services Not Starting

```powershell
# Check logs
podman-compose logs singularity

# Verify .env is configured
type .env | grep -v "^#"

# Verify GPU is available
nvidia-smi

# Check ports are free
netstat -ano | findstr :4000
```

### Database Connection Error

```powershell
# Check PostgreSQL is running
podman ps | grep postgres

# Test connection
$env:PGPASSWORD="password"
psql -h localhost -U postgres -c "SELECT 1"

# Check database exists
psql -h localhost -U postgres -l
```

### GitHub Authentication Fails

```powershell
# Re-authenticate
gh auth logout
gh auth login

# Check status
gh auth status
```

---

## Advanced: Kubernetes Option

For scaling across multiple machines, use Kubernetes manifests:

```powershell
# Install Minikube (for testing)
choco install minikube

# Start cluster
minikube start --cpus=4 --memory=8192 --gpus=1

# Deploy
kubectl apply -f k8s/postgresql-statefulset.yml
kubectl apply -f k8s/nats-statefulset.yml
kubectl apply -f k8s/deployments.yml
```

---

## Support & Documentation

- **Quick Start**: `WINDOWS_QUICK_START.md` (5 steps, 25 min)
- **Full Guide**: `DEPLOYMENT_GUIDE.md` (comprehensive reference)
- **Issues**: GitHub Issues on mikkihugo/singularity-incubation
- **Logs**: `podman-compose logs -f SERVICE_NAME`

---

## Architecture

```
Windows RTX 4080
├─ GitHub Actions Runner (Windows Service)
│  └─ Auto-deploys on push to main
│
├─ Podman Network (172.30.0.0/16)
│  ├─ Singularity (4000) + GPU
│  ├─ CentralCloud (4001)
│  ├─ Genesis (4002)
│  ├─ LLM Server (3000)
│  ├─ NATS (4222)
│  ├─ PostgreSQL (5432)
│  └─ Nginx (80/443)
│
└─ NVIDIA RTX 4080 GPU
   └─ CUDA 12.x acceleration
```

---

## Key Insight

Everything is automated:
- ✅ One command setup (`setup-windows.ps1`)
- ✅ GitHub runner auto-configured
- ✅ Services auto-deployed
- ✅ CI/CD fully integrated
- ✅ Production-ready on first run

---

**Ready to deploy? Run: `.\setup-windows.ps1`**
