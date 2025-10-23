# Production Deployment Architecture for RTX 4080

## Your Scenario

**GitHub Actions CI/CD → Nix builds → Deploy to RTX 4080 production**

You have **two deployment options**:
1. **Option A: Kubernetes (Recommended for team scaling)**
2. **Option B: Bare Metal Nix (Recommended for simplicity & GPU performance)**

---

## Five Services to Deploy

```
┌─────────────────────────────────────────────────────────────────┐
│ PRODUCTION RTX 4080                                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ 1. SINGULARITY (Main App - Elixir/Phoenix)                     │
│    Port: 4000 (HTTP), 4001 (HTTPS)                             │
│    Memory: 2GB, CPU: 2 cores                                    │
│    GPU: Optional (inference mostly local)                       │
│    Database: singularity DB                                     │
│                                                                 │
│ 2. CENTRALCLOUD (Knowledge Authority - Elixir)                 │
│    Port: 4001 (internal only)                                   │
│    Memory: 1GB, CPU: 1 core                                     │
│    GPU: None (lightweight coordination)                         │
│    Database: centralcloud DB                                    │
│    Jobs: PackageSyncJob (once daily at 2 AM)                   │
│                                                                 │
│ 3. GENESIS (Sandbox - Elixir)                                  │
│    Port: 4002 (internal only)                                  │
│    Memory: 2GB, CPU: 2 cores                                    │
│    GPU: Optional (testing improvements)                         │
│    Database: genesis DB                                         │
│                                                                 │
│ 4. LLM-SERVER (TypeScript/Bun - AI Provider Gateway)           │
│    Port: 3000 (internal only)                                   │
│    Memory: 1GB, CPU: 1 core                                     │
│    GPU: None (API gateway only)                                 │
│    Endpoints: /request, /response                               │
│                                                                 │
│ 5. NATS (Message Bus - JetStream enabled)                      │
│    Port: 4222 (core), 4221 (TLS), 4223 (WebSocket)            │
│    Memory: 500MB, CPU: 1 core                                   │
│    GPU: None (messaging only)                                   │
│    Persistence: JetStream with PostgreSQL KV store              │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ SHARED SERVICES                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ PostgreSQL (Single instance, 3 databases)                       │
│    Port: 5432 (internal only)                                   │
│    Memory: 4GB                                                   │
│    Databases:                                                   │
│      - singularity (main app data)                              │
│      - centralcloud (global knowledge)                          │
│      - genesis (isolated experiments)                           │
│    Storage: 100GB (scalable)                                    │
│    Backups: Daily automated snapshots                           │
│                                                                 │
│ Reverse Proxy (Nginx or Caddy)                                  │
│    Port: 80 (HTTP), 443 (HTTPS)                                 │
│    Routes:                                                      │
│      - / → Singularity:4000                                     │
│      - /internal/llm → llm-server:3000                          │
│      - /internal/nats → NATS WebSocket:4223                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Option A: Kubernetes Deployment (Recommended for Teams)

### Architecture

```
GitHub Actions
    ↓ (nix build .#container-images)
Nix builds OCI images
    ↓
Push to registry (ghcr.io, your-registry)
    ↓
ArgoCD or flux watches main branch
    ↓
K8s cluster (3+ nodes, 1 RTX 4080 node)
├─ Singularity Pod
├─ CentralCloud Pod
├─ Genesis Pod
├─ llm-server Pod
├─ NATS StatefulSet
└─ PostgreSQL StatefulSet
```

### K8s Manifests Structure

```yaml
# kubernetes/
├── namespace.yaml                    # namespace: singularity-prod
├── secrets.yaml                      # API keys, passwords (encrypted)
├── configmaps.yaml                   # Config files
├── pvc.yaml                          # PostgreSQL persistent volume
├── postgres.yaml                     # PostgreSQL StatefulSet
├── nats.yaml                         # NATS StatefulSet
├── singularity.yaml                  # Singularity Deployment
├── centralcloud.yaml                 # CentralCloud Deployment
├── genesis.yaml                      # Genesis Deployment
├── llm-server.yaml                   # llm-server Deployment
├── nginx-ingress.yaml                # Ingress (public routes)
├── network-policies.yaml             # Security (pod-to-pod comms)
└── hpa.yaml                          # Horizontal Pod Autoscaling
```

### Example: Singularity K8s Manifest

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: singularity
  namespace: singularity-prod
spec:
  replicas: 2  # High availability
  selector:
    matchLabels:
      app: singularity
  template:
    metadata:
      labels:
        app: singularity
    spec:
      # Pin to RTX 4080 node (CUDA access required)
      nodeSelector:
        gpu: nvidia
        gpu-type: rtx-4080

      containers:
      - name: singularity
        image: ghcr.io/yourusername/singularity:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 4000
          name: http

        # GPU access
        resources:
          requests:
            nvidia.com/gpu: 1
          limits:
            nvidia.com/gpu: 1

        # Environment
        env:
        - name: MIX_ENV
          value: "prod"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: singularity-url
        - name: NATS_HOST
          value: "nats.singularity-prod"
        - name: NATS_PORT
          value: "4222"
        - name: PORT
          value: "4000"

        # Health checks
        livenessProbe:
          httpGet:
            path: /health
            port: 4000
          initialDelaySeconds: 60
          periodSeconds: 30

        readinessProbe:
          httpGet:
            path: /health
            port: 4000
          initialDelaySeconds: 30
          periodSeconds: 10

        # Security context
        securityContext:
          readOnlyRootFilesystem: false
          allowPrivilegeEscalation: false

        # Logging
        volumeMounts:
        - name: logs
          mountPath: /app/logs

      volumes:
      - name: logs
        emptyDir: {}

  # Rollout strategy
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

### GitHub Actions CI/CD for K8s

```yaml
# .github/workflows/deploy-k8s.yml
name: Deploy to Kubernetes

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    # Step 1: Build Nix images
    - uses: cachix/install-nix-action@v22
    - run: nix flake update
    - run: nix build .#singularity-container-image
    - run: nix build .#centralcloud-container-image
    - run: nix build .#genesis-container-image
    - run: nix build .#llm-server-container-image
    - run: nix build .#nats-container-image

    # Step 2: Load and push images
    - run: |
        docker load < result-singularity
        docker load < result-centralcloud
        docker load < result-genesis
        docker load < result-llm-server
        docker load < result-nats

    - uses: docker/login-action@v2
      with:
        registry: ghcr.io
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - run: |
        docker tag singularity ghcr.io/${{ github.repository }}/singularity:latest
        docker push ghcr.io/${{ github.repository }}/singularity:latest
        # ... repeat for other images

    # Step 3: Deploy to K8s
    - uses: azure/k8s-set-context@v3
      with:
        kubeconfig: ${{ secrets.KUBE_CONFIG }}

    - run: kubectl apply -f kubernetes/
    - run: kubectl set image deployment/singularity singularity=ghcr.io/${{ github.repository }}/singularity:latest
    - run: kubectl rollout status deployment/singularity

    # Step 4: Run smoke tests
    - run: |
        kubectl run test-pod --image=curlimages/curl --rm -i --restart=Never -- \
          curl http://singularity.singularity-prod/health
```

### K8s Advantages

✅ **High Availability** - Multiple replicas, auto-failover
✅ **Easy Scaling** - HPA scales based on CPU/memory
✅ **Rolling Updates** - Zero-downtime deployments
✅ **Resource Management** - GPU node affinity
✅ **Networking** - Service discovery, ingress
✅ **Observability** - Prometheus, Grafana integration
✅ **GitOps** - ArgoCD auto-syncs from Git

### K8s Disadvantages

❌ **Complexity** - More moving parts
❌ **Overhead** - kubelet, API server on every node
❌ **GPU Scheduling** - NVIDIA GPU operator required
❌ **Learning Curve** - More concepts to master

---

## Option B: Bare Metal Nix (Recommended for Simplicity & GPU)

### Architecture

```
GitHub Actions
    ↓ (nix build .#singularity-integrated)
Nix builds complete system
    ↓
Create NixOS ISO/system closure
    ↓
Deploy to RTX 4080 bare metal
    ↓
Systemd services (all 5 services)
├─ singularity.service
├─ centralcloud.service
├─ genesis.service
├─ llm-server.service
├─ nats.service
├─ postgresql.service
└─ nginx.service
```

### NixOS Configuration Structure

```nix
# nixos/configuration.nix
{ config, pkgs, lib, ... }:

{
  # Hardware
  boot.loader.grub.enable = true;
  boot.initrd.kernelModules = [ "nvidia" ];

  # NVIDIA GPU support
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia.open = false;  # Use closed-source for better perf

  # Network
  networking.hostName = "singularity-prod";
  networking.firewall.allowedTCPPorts = [ 80 443 4000 4001 4002 3000 ];

  # PostgreSQL
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    port = 5432;
    dataDir = "/var/lib/postgresql";
    authentication = pkgs.lib.mkOverride 10 ''
      local all all trust
      host all all 127.0.0.1/32 md5
    '';
    initialScript = pkgs.writeText "init.sql" ''
      CREATE DATABASE singularity;
      CREATE DATABASE centralcloud;
      CREATE DATABASE genesis;
    '';
  };

  # NATS
  services.nats.enable = true;
  services.nats.port = 4222;
  services.nats.jetstream.enable = true;
  services.nats.jetstream.maxStoreSize = "100GB";

  # Nginx reverse proxy
  services.nginx = {
    enable = true;
    virtualHosts = {
      "singularity-prod.local" = {
        listen = [ { addr = "0.0.0.0"; port = 80; } ];
        locations = {
          "/" = {
            proxyPass = "http://localhost:4000";
            proxyWebsockets = true;
          };
          "/internal/llm/" = {
            proxyPass = "http://localhost:3000/";
          };
          "/internal/nats/" = {
            proxyPass = "http://localhost:4223/";
          };
        };
      };
    };
  };

  # Systemd services
  systemd.services.singularity = {
    description = "Singularity Production";
    after = [ "network.target" "postgresql.service" "nats.service" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      MIX_ENV = "prod";
      DATABASE_URL = "ecto://postgres:password@localhost/singularity";
      NATS_HOST = "localhost";
      NATS_PORT = "4222";
      PORT = "4000";
    };
    serviceConfig = {
      Type = "simple";
      User = "singularity";
      WorkingDirectory = "/opt/singularity";
      ExecStart = "${pkgs.beam}/bin/elixir /opt/singularity/bin/singularity start";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  # Similar for: centralcloud.service, genesis.service, llm-server.service
}
```

### Systemd Services File

```ini
# /etc/systemd/system/singularity.service
[Unit]
Description=Singularity Production Service
After=network.target postgresql.service nats.service
Wants=nats.service postgresql.service

[Service]
Type=simple
User=singularity
WorkingDirectory=/opt/singularity
Environment="MIX_ENV=prod"
Environment="DATABASE_URL=ecto://postgres:password@localhost/singularity"
Environment="NATS_HOST=localhost"
Environment="NATS_PORT=4222"
Environment="PORT=4000"
ExecStart=/nix/store/.../bin/elixir /opt/singularity/bin/singularity start
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### GitHub Actions CI/CD for Bare Metal

```yaml
# .github/workflows/deploy-nixos.yml
name: Deploy to Bare Metal (NixOS)

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: [self-hosted, linux, x86_64]  # Runs on RTX 4080 runner

    steps:
    - uses: actions/checkout@v3

    # Step 1: Build Nix closure
    - uses: cachix/install-nix-action@v22
    - run: nix flake update
    - run: nix build .#singularity-integrated --out-link result

    # Step 2: Copy closure to runner
    - run: |
        nix copy --to file:///tmp/nix-store ./result
        cp result/bin/* /opt/singularity/bin/

    # Step 3: Reload systemd services
    - run: |
        sudo systemctl daemon-reload
        sudo systemctl restart singularity
        sudo systemctl restart centralcloud
        sudo systemctl restart genesis
        sudo systemctl restart llm-server

    # Step 4: Health checks
    - run: |
        sleep 10
        curl -f http://localhost:4000/health || exit 1
        curl -f http://localhost:3000/health || exit 1
        nats ping || exit 1

    # Step 5: Smoke tests
    - run: |
        ./scripts/smoke-tests.sh
```

### Bare Metal Advantages

✅ **Simplicity** - Declarative NixOS config
✅ **GPU Performance** - Direct CUDA access, no container overhead
✅ **Fast Deployments** - Just restart systemd services
✅ **Resource Efficiency** - No K8s overhead
✅ **Reproducibility** - Same config = same result everywhere
✅ **Easy Debugging** - SSH directly to host
✅ **Fast Boot** - No container runtime startup

### Bare Metal Disadvantages

❌ **Single Point of Failure** - No automatic failover
❌ **Manual Scaling** - Need to provision new hardware
❌ **No HA** - Single machine deployment
❌ **Limited to one RTX 4080** - Can't scale horizontally

---

## Recommended Approach: Hybrid (Best of Both)

### For Your Scenario

```
RTX 4080 Bare Metal (Primary)
  ├─ Singularity (systemd service)
  ├─ CentralCloud (systemd service)
  ├─ Genesis (systemd service)
  ├─ llm-server (systemd service)
  ├─ NATS (systemd service)
  └─ PostgreSQL (systemd service)

Dev Machines (K8s optional for scaling later)
  └─ Can run full K8s if team grows
```

### Why This Works

✅ **Start Simple** - Bare metal NixOS on RTX 4080
✅ **Production Ready** - Systemd services, auto-restart
✅ **Easy CI/CD** - GitHub Actions → nix build → restart
✅ **GPU Friendly** - Direct CUDA access
✅ **Scale Later** - Can migrate to K8s when needed
✅ **GitOps Ready** - NixOS config in git

---

## Database Strategy

### Single PostgreSQL Instance (Recommended)

```sql
-- PostgreSQL 17 on RTX 4080

-- Database 1: Singularity (main app)
CREATE DATABASE singularity;
\c singularity
-- Migration runs here (via Ecto)

-- Database 2: CentralCloud (global knowledge)
CREATE DATABASE centralcloud;
\c centralcloud
-- Migrations run here

-- Database 3: Genesis (isolated sandbox)
CREATE DATABASE genesis;
\c genesis
-- Migrations run here

-- Backups
pg_dump singularity > backups/singularity-$(date +%Y%m%d).sql
pg_dump centralcloud > backups/centralcloud-$(date +%Y%m%d).sql
pg_dump genesis > backups/genesis-$(date +%Y%m%d).sql
```

### Backup Strategy

```bash
#!/bin/bash
# Daily automated backups

BACKUP_DIR="/backups/postgresql"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Backup all three databases
pg_dump singularity > $BACKUP_DIR/singularity_$TIMESTAMP.sql
pg_dump centralcloud > $BACKUP_DIR/centralcloud_$TIMESTAMP.sql
pg_dump genesis > $BACKUP_DIR/genesis_$TIMESTAMP.sql

# Compress
gzip $BACKUP_DIR/*.sql

# Keep last 7 days
find $BACKUP_DIR -name "*.sql.gz" -mtime +7 -delete

# Copy to remote storage (S3, etc)
aws s3 sync $BACKUP_DIR s3://my-backups/postgresql/
```

---

## Network Architecture

### Internal Network (Private)

```
Singularity (4000) ──┐
CentralCloud (4001)  │
Genesis (4002)       ├── NATS (4222) ──┐
llm-server (3000)    │                  │
PostgreSQL (5432) ───┤                  ├── Nginx (80/443)
                     │                  │      ↓
                     └──────────────────┴─→ External

Only port 80/443 exposed to internet
Internal services communicate via NATS
Database access restricted to localhost
```

### Security

```nix
# NixOS firewall
networking.firewall = {
  enable = true;
  allowedTCPPorts = [ 80 443 ];  # Only HTTP/HTTPS
  allowedUDPPorts = [ ];
};

# Nginx TLS/SSL
services.nginx.virtualHosts."singularity-prod.local" = {
  forceSSL = true;
  enableACME = true;  # Let's Encrypt
};
```

---

## Monitoring & Observability

### Prometheus Metrics

```nix
# Export metrics from each service
services.prometheus = {
  enable = true;
  scrapeConfigs = [
    {
      job_name = "singularity";
      static_configs = [{ targets = [ "localhost:4000" ]; }];
    }
    {
      job_name = "centralcloud";
      static_configs = [{ targets = [ "localhost:4001" ]; }];
    }
    {
      job_name = "genesis";
      static_configs = [{ targets = [ "localhost:4002" ]; }];
    }
    {
      job_name = "nats";
      static_configs = [{ targets = [ "localhost:8222" ]; }];
    }
  ];
};
```

### Grafana Dashboards

```
RTX 4080 Monitoring:
├─ CPU usage (should be low, peaks during analysis)
├─ GPU usage (should be low, peaks during inference)
├─ Memory usage (each service ~1-2GB)
├─ Disk usage (PostgreSQL growth)
├─ Network I/O (NATS messages)
├─ Service health (systemd status)
└─ Error logs (journalctl)
```

---

## Deployment Checklist

### Pre-Production (Dev/Staging)

- [ ] GitHub Actions CI/CD working
- [ ] Nix builds reproducible
- [ ] All 5 services start correctly
- [ ] NATS connectivity working
- [ ] PostgreSQL migrations running
- [ ] llm-server API keys configured
- [ ] Systemd services auto-restart
- [ ] Health checks passing
- [ ] Logs being captured
- [ ] Backups running daily

### Production Deployment

- [ ] RTX 4080 hardware ready
- [ ] NixOS installed
- [ ] Secrets configured (GitHub secrets)
- [ ] PostgreSQL initialized with 3 databases
- [ ] NATS JetStream enabled
- [ ] SSL/TLS configured
- [ ] Backups automated
- [ ] Monitoring enabled
- [ ] Alerting configured
- [ ] Disaster recovery plan documented

### Day 1 Verification

- [ ] `curl http://localhost/health` → Singularity responds
- [ ] `nats sub -all` → NATS working
- [ ] `psql singularity -c "SELECT version()"` → PostgreSQL connected
- [ ] `curl http://localhost:3000/health` → llm-server responding
- [ ] `systemctl status singularity` → All services running
- [ ] Logs clean, no errors in journalctl

---

## Summary: My Recommendation

### For Your Scenario (GitHub → RTX 4080)

**Use Bare Metal NixOS** ✅

```
Reasons:
1. Simple: One config file (flake.nix + configuration.nix)
2. Fast: No container overhead for GPU
3. GitOps: GitHub → nix build → systemctl restart
4. Reproducible: Same config = same result always
5. Perfect for single RTX 4080 machine
```

### If You Grow to Multiple Machines

**Migrate to Kubernetes** (later)

```
When you need:
1. Multiple RTX 4080s
2. High availability (multiple replicas)
3. Auto-scaling
4. Load balancing across machines
```

### GitHub Actions Workflow (Recommended)

```yaml
name: Build & Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: [self-hosted, linux, nix]  # RTX 4080 runner
    steps:
    - uses: actions/checkout@v3
    - run: nix flake update
    - run: nix build .#singularity-integrated
    - run: |
        sudo systemctl daemon-reload
        sudo systemctl restart singularity centralcloud genesis llm-server nats
    - run: ./scripts/health-check.sh
```

---

## Next Steps

1. **Choose deployment style** (Bare Metal Nix recommended)
2. **Create NixOS configuration** for RTX 4080
3. **Setup GitHub Actions** self-hosted runner
4. **Configure secrets** (API keys, DB credentials)
5. **Test locally first** (nix develop, ./start-all.sh)
6. **Deploy to production** (Git push → automatic)
7. **Monitor continuously** (Prometheus + Grafana)
8. **Backup daily** (automated PostgreSQL dumps)
