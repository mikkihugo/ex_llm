# Windows RTX 4080 - Quick Start (5 Steps, 30 Minutes)

## Your Setup

- **Machine:** Windows with RTX 4080 GPU
- **Deployment:** All services in Podman Compose (simplest option)
- **GitHub:** Self-hosted runner for CI/CD

---

## Step 1: Install Prerequisites (10 minutes)

### A. Install Podman

```powershell
# Using Chocolatey
choco install podman

# OR using Windows Package Manager
winget install RedHat.Podman

# Verify installation
podman --version
```

### B. Install Podman Compose

```powershell
pip install podman-compose

# Verify installation
podman-compose --version
```

### C. Verify NVIDIA GPU

```powershell
nvidia-smi

# Should show your RTX 4080
# Output includes GPU Name, Memory, etc.
```

**Time: ~10 minutes (mostly waiting for downloads)**

---

## Step 2: Configure Environment (5 minutes)

### Navigate to Production Directory

```powershell
cd production
```

### Copy Example Environment File

```powershell
Copy-Item .env.production.example .env
```

### Edit `.env` with Your Values

```powershell
# Edit the file
notepad .env
```

**Required changes (search/replace):**

| Find | Replace With |
|------|---|
| `your-super-secure-postgres-password-change-this` | Your secure password (min 20 chars) |
| `your-secret-key-base-min-64-...` | Generate: `[guid]::NewGuid().ToString().Replace('-','')` × 2 |
| `sk-ant-change-this-to-your-key` | Your Anthropic API key |
| `change-this-to-your-key` | Your Google API key |
| `sk-proj-change-this-to-your-key` | Your OpenAI API key |

**Example for secret key generation:**
```powershell
# Generate a 64-character secret
[convert]::ToBase64String((1..64 | ForEach-Object { [byte](Get-Random -min 32 -max 127) }))
```

**Time: ~5 minutes**

---

## Step 3: Start Services (1 minute)

```powershell
# From production directory
cd production

# Run deployment script
.\deploy-windows.ps1
```

**What it does:**
1. ✅ Checks Podman is installed
2. ✅ Checks GPU is available
3. ✅ Loads `.env` file
4. ✅ Starts all containers
5. ✅ Runs health checks
6. ✅ Shows access points

**Output:**
```
✓ All prerequisites met
✓ Services started
✓ All services passed health checks

🎉 Deployment successful!

Access points:
  Singularity:  http://localhost:4000
  NATS Admin:   http://localhost:8222
  PostgreSQL:   localhost:5432
```

**Time: ~1 minute**

---

## Step 4: Test Everything (3 minutes)

### Test Singularity

```powershell
Invoke-WebRequest http://localhost:4000/health
# Should return 200 OK
```

### Test NATS

```powershell
Invoke-WebRequest http://localhost:8222
# Should show NATS admin interface
```

### Check Services Running

```powershell
podman ps

# Should show all 7 containers:
# - singularity-postgres
# - singularity-nats
# - singularity-llm-server
# - singularity-centralcloud
# - singularity-genesis
# - singularity-app
# - singularity-nginx
```

### Open Web UI

```
http://localhost:4000
```

**Time: ~3 minutes**

---

## Step 5: Verify GPU Acceleration (2 minutes)

```powershell
# Check GPU is being used
nvidia-smi

# Should show:
# - Processes section with "singularity" process
# - GPU Memory usage increasing
```

**Time: ~2 minutes**

---

## Total Time: ~25 minutes

```
Installation:     10 min
Configuration:     5 min
Deployment:        1 min
Testing:           3 min
GPU verification:  2 min
──────────────────────────
Total:            21 min (+ setup buffer = 25 min)
```

---

## Useful Commands After Deployment

### Check Status

```powershell
# See all running services
podman ps

# Check service logs
podman-compose logs -f singularity

# See resource usage
podman stats
```

### Manage Services

```powershell
# Restart a service
podman-compose restart singularity

# Stop all services
.\deploy-windows.ps1 -Stop

# Restart all services
.\deploy-windows.ps1 -Restart

# View live logs
.\deploy-windows.ps1 -Logs
```

### Database Access

```powershell
# Connect to Singularity database
$env:PGPASSWORD="your-postgres-password"
psql -h localhost -U postgres -d singularity

# List all databases
psql -h localhost -U postgres -l

# Backup database
podman exec singularity-postgres pg_dump -U postgres singularity > backup.sql

# Restore database
cat backup.sql | podman exec -i singularity-postgres psql -U postgres singularity
```

---

## Common Issues & Fixes

### Issue: "Podman not found"

```powershell
# Install Podman
winget install RedHat.Podman

# Restart PowerShell after installation
```

### Issue: GPU not detected

```powershell
# Check NVIDIA drivers
nvidia-smi

# If not found, install from:
# https://www.nvidia.com/Download/driverDetails.aspx

# Update Podman to latest version
podman version  # if old
podman machine update
```

### Issue: Port 4000 already in use

```powershell
# Stop existing process on port 4000
netstat -ano | findstr :4000

# Kill process (replace PID with number from above)
taskkill /PID [PID] /F

# Or edit podman-compose.yml to use different port
# Change "4000:4000" to "4001:4000"
```

### Issue: Services starting but health check fails

```powershell
# Wait longer (services take 30-60 seconds to be ready)
Start-Sleep -Seconds 30

# Check detailed logs
podman-compose logs singularity

# Try manual health check
curl http://localhost:4000/health -Verbose
```

---

## Next Steps

### Optional: GitHub Actions CI/CD

To automatically build and deploy on push:

1. **Set up GitHub Runner on Windows:**
   ```powershell
   # On GitHub: Settings → Actions → Runners → New self-hosted runner
   # Download runner and configure

   cd C:\runners
   .\config.cmd --url https://github.com/yourorg/singularity --token TOKEN
   .\run.cmd
   ```

2. **Enable in repository:**
   - Push code to `main` branch
   - Automatically builds OCI images
   - Pushes to GitHub Container Registry
   - Optionally auto-deploys to your RTX 4080

### Optional: SSL/HTTPS

For production with HTTPS:

1. Get SSL certificate (Let's Encrypt free)
2. Update `production/.env`:
   ```
   NGINX_CERT_PATH=/path/to/cert.pem
   NGINX_KEY_PATH=/path/to/key.pem
   ```
3. Restart services

### Optional: External Access

To access from other machines (not just localhost):

1. Note your machine's IP: `ipconfig`
2. Update DNS/firewall to point to that IP
3. Access via: `http://[your-ip]:4000`

---

## Architecture (What's Running)

```
Your Windows Machine + RTX 4080
│
├─ Singularity (4000) - Main app
│  └─ GPU inference (CUDA 12.x)
│
├─ CentralCloud (4001) - Knowledge authority
├─ Genesis (4002) - Experiment sandbox
├─ LLM Server (3000) - AI provider gateway
├─ NATS (4222) - Message bus
│
├─ PostgreSQL (5432) - Database
│  ├─ singularity DB
│  ├─ centralcloud DB
│  └─ genesis DB
│
└─ Nginx (80/443) - Reverse proxy
```

All in Podman containers, sharing RTX 4080 GPU access.

---

## Support

- **GitHub Issues:** https://github.com/yourorg/singularity/issues
- **Logs:** `podman-compose logs -f SERVICE_NAME`
- **Full Guide:** See `DEPLOYMENT_GUIDE.md`

---

## One-Liner Deployment

After first setup, redeploy with one command:

```powershell
cd production
.\deploy-windows.ps1
```

---

**You're done! RTX 4080 is running all Singularity services with GPU acceleration.** 🚀
