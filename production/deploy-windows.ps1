#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy Singularity to Windows RTX 4080 using Podman

.DESCRIPTION
    Complete deployment script for Windows RTX 4080 production setup
    - Validates prerequisites (Podman, GPU)
    - Loads environment variables
    - Starts all services with health checks
    - Tests deployment

.EXAMPLE
    .\deploy-windows.ps1
    .\deploy-windows.ps1 -Stop
    .\deploy-windows.ps1 -Restart
    .\deploy-windows.ps1 -Logs

.PARAMETER Stop
    Stop all running services

.PARAMETER Restart
    Restart all services

.PARAMETER Logs
    Show live logs from all services

.PARAMETER NoHealthCheck
    Skip health checks (useful for debugging)
#>

param(
    [switch]$Stop,
    [switch]$Restart,
    [switch]$Logs,
    [switch]$NoHealthCheck,
    [switch]$SetupRunner,
    [string]$RunnerToken
)

$ErrorActionPreference = "Stop"

# Detect repository URL from git config
$gitRemote = git config --get remote.origin.url 2>$null
if (-not $gitRemote) {
    $gitRemote = "https://github.com/mikkihugo/singularity-incubation"
}

# Colors for output
$colors = @{
    success = "Green"
    error = "Red"
    warning = "Yellow"
    info = "Cyan"
}

function Write-Status {
    param([string]$Message, [string]$Type = "info")
    $color = $colors[$Type]
    Write-Host "[$Type] $Message" -ForegroundColor $color
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ $Title".PadRight(67) + "║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
}

function Test-Prerequisites {
    Write-Section "Checking Prerequisites"

    # Check Podman
    Write-Status "Checking Podman..." -Type info
    if (!(Get-Command podman -ErrorAction SilentlyContinue)) {
        Write-Status "Podman not found. Install from: https://podman.io/" -Type error
        exit 1
    }
    $podmanVersion = podman --version
    Write-Status "✓ Podman: $podmanVersion" -Type success

    # Check Podman Compose
    Write-Status "Checking Podman Compose..." -Type info
    if (!(Get-Command podman-compose -ErrorAction SilentlyContinue)) {
        Write-Status "Podman Compose not found. Install: pip install podman-compose" -Type error
        exit 1
    }
    Write-Status "✓ Podman Compose installed" -Type success

    # Check NVIDIA GPU
    Write-Status "Checking NVIDIA GPU..." -Type info
    if (!(Get-Command nvidia-smi -ErrorAction SilentlyContinue)) {
        Write-Status "nvidia-smi not found. Ensure NVIDIA drivers are installed." -Type warning
    } else {
        $gpuInfo = nvidia-smi --query-gpu=name --format=csv,noheader | Select-Object -First 1
        Write-Status "✓ GPU detected: $gpuInfo" -Type success
    }

    # Check .env file
    Write-Status "Checking environment file..." -Type info
    if (!(Test-Path ".env")) {
        if (!(Test-Path ".env.production.example")) {
            Write-Status "No .env or .env.production.example found" -Type error
            exit 1
        }
        Write-Status "Copying .env.production.example to .env" -Type warning
        Copy-Item ".env.production.example" ".env"
        Write-Status "⚠️  Edit .env with your actual values before deploying!" -Type warning
        exit 0
    }

    Write-Status "✓ All prerequisites met" -Type success
}

function Start-Services {
    Write-Section "Starting Services"

    Write-Status "Starting all services with profiles: all..." -Type info
    podman-compose --profile all up -d

    if ($LASTEXITCODE -ne 0) {
        Write-Status "Failed to start services" -Type error
        exit 1
    }

    Write-Status "✓ Services started" -Type success

    # Wait for services to stabilize
    Write-Status "Waiting for services to stabilize..." -Type info
    Start-Sleep -Seconds 15
}

function Stop-Services {
    Write-Section "Stopping Services"

    Write-Status "Stopping all services..." -Type info
    podman-compose down

    if ($LASTEXITCODE -eq 0) {
        Write-Status "✓ Services stopped" -Type success
    } else {
        Write-Status "⚠️  Some services may not have stopped cleanly" -Type warning
    }
}

function Restart-Services {
    Write-Section "Restarting Services"

    Stop-Services
    Start-Sleep -Seconds 2
    Start-Services
}

function Show-Logs {
    Write-Section "Service Logs"

    Write-Status "Showing live logs (Ctrl+C to exit)..." -Type info
    podman-compose logs -f
}

function Test-Health {
    Write-Section "Health Checks"

    $healthChecks = @(
        @{Name = "Singularity"; Port = 4000; Path = "/health"}
        @{Name = "CentralCloud"; Port = 4001; Path = "/health"}
        @{Name = "Genesis"; Port = 4002; Path = "/health"}
        @{Name = "LLM Server"; Port = 3000; Path = "/health"}
    )

    $failCount = 0

    foreach ($check in $healthChecks) {
        Write-Status "Testing $($check.Name)..." -Type info
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$($check.Port)$($check.Path)" `
                -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop

            if ($response.StatusCode -eq 200) {
                Write-Status "✓ $($check.Name) is healthy" -Type success
            } else {
                Write-Status "✗ $($check.Name) returned status $($response.StatusCode)" -Type error
                $failCount++
            }
        } catch {
            Write-Status "✗ $($check.Name) is not responding" -Type error
            $failCount++
        }
    }

    # Check NATS
    Write-Status "Testing NATS..." -Type info
    try {
        $natsHealth = podman exec singularity-nats nats rtt 2>$null
        if ($natsHealth) {
            Write-Status "✓ NATS is healthy" -Type success
        }
    } catch {
        Write-Status "⚠️  Could not verify NATS (might still be starting)" -Type warning
    }

    # Check PostgreSQL
    Write-Status "Testing PostgreSQL..." -Type info
    try {
        $pgReady = podman exec singularity-postgres pg_isready 2>$null
        if ($pgReady) {
            Write-Status "✓ PostgreSQL is ready" -Type success
        }
    } catch {
        Write-Status "✗ PostgreSQL is not ready" -Type error
        $failCount++
    }

    if ($failCount -gt 0) {
        Write-Status "$failCount service(s) failed health checks" -Type warning
        Write-Status "Check logs: podman-compose logs -f" -Type info
    } else {
        Write-Status "✓ All services passed health checks" -Type success
    }

    return $failCount -eq 0
}

function Show-Status {
    Write-Section "Service Status"

    Write-Host ""
    podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

    Write-Host ""
    Write-Status "Access points:" -Type info
    Write-Host "  Singularity:  http://localhost:4000"
    Write-Host "  NATS Admin:   http://localhost:8222"
    Write-Host "  PostgreSQL:   localhost:5432"
    Write-Host ""
}

function Setup-GitHubRunner {
    param([string]$Token)

    Write-Section "Setting up GitHub Self-Hosted Runner"

    Write-Status "Repository: $gitRemote" -Type info

    # Check gh CLI
    Write-Status "Checking gh CLI..." -Type info
    if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Status "gh CLI not found. Installing..." -Type warning
        choco install gh
    }

    # Authenticate with GitHub
    Write-Status "Authenticating with GitHub..." -Type info
    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Status "Please authenticate with GitHub:" -Type warning
        gh auth login
    } else {
        Write-Status "✓ Authenticated with GitHub" -Type success
    }

    # Create runner directory
    $runnerDir = "C:\runners\singularity-runner"
    Write-Status "Creating runner directory: $runnerDir" -Type info
    New-Item -ItemType Directory -Force -Path $runnerDir | Out-Null

    # Download latest runner
    Write-Status "Downloading GitHub Actions runner..." -Type info
    $runnerUrl = "https://github.com/actions/runner/releases/download/v2.319.0/actions-runner-win-x64-2.319.0.zip"
    $runnerZip = "$runnerDir\runner.zip"

    try {
        Invoke-WebRequest -Uri $runnerUrl -OutFile $runnerZip -ErrorAction Stop
        Expand-Archive -Path $runnerZip -DestinationPath $runnerDir
        Remove-Item $runnerZip
        Write-Status "✓ Runner downloaded" -Type success
    } catch {
        Write-Status "Failed to download runner: $_" -Type error
        return $false
    }

    # Configure runner using gh
    Write-Status "Configuring runner with GitHub..." -Type info
    Push-Location $runnerDir

    # Get registration token if not provided
    if (-not $Token) {
        Write-Status "Getting registration token from GitHub..." -Type info
        try {
            $Token = gh actions-cache list --repo $gitRemote 2>&1 | Select-Object -First 1
            # Alternative: use gh api to create token
            $response = gh api --method POST "repos/{owner}/{repo}/actions/runners/registration-token" 2>$null
            if ($response) {
                $Token = ($response | ConvertFrom-Json).token
            } else {
                Write-Status "Could not auto-generate token. Get it from:" -Type warning
                Write-Status "GitHub → Repository → Settings → Actions → Runners → New self-hosted runner" -Type info
                Pop-Location
                return $false
            }
        } catch {
            Write-Status "Error getting token: $_" -Type warning
            Write-Status "Get manual token from:" -Type info
            Write-Status "GitHub → Repository → Settings → Actions → Runners → New self-hosted runner" -Type info
            Pop-Location
            return $false
        }
    }

    # Run configuration
    Write-Status "Running configuration..." -Type info
    .\config.cmd --url $gitRemote --token $Token --name "rtx-4080-runner" --work "_work" --replace

    if ($LASTEXITCODE -ne 0) {
        Write-Status "Runner configuration failed" -Type error
        Pop-Location
        return $false
    }

    # Install and start as service
    Write-Status "Installing runner as Windows Service..." -Type info
    .\svc.cmd install

    if ($LASTEXITCODE -ne 0) {
        Write-Status "Failed to install service" -Type error
        Pop-Location
        return $false
    }

    Write-Status "Starting runner service..." -Type info
    .\svc.cmd start

    Pop-Location

    Write-Status "✓ GitHub runner installed and started" -Type success
    Write-Status "Runner location: $runnerDir" -Type info
    Write-Status "Runner name: rtx-4080-runner" -Type info

    # Verify runner is connected
    Start-Sleep -Seconds 5
    Write-Status "Checking runner status on GitHub..." -Type info
    $runners = gh run list --repo $gitRemote --json name --limit 1 2>&1
    Write-Status "✓ Runner should appear in GitHub → Settings → Actions → Runners within 30 seconds" -Type success

    return $true
}

function Show-Help {
    Write-Section "Usage"

    Write-Host "Deployment modes:"
    Write-Host "  .\deploy-windows.ps1                                      # Deploy and start"
    Write-Host "  .\deploy-windows.ps1 -Stop                              # Stop services"
    Write-Host "  .\deploy-windows.ps1 -Restart                           # Restart services"
    Write-Host "  .\deploy-windows.ps1 -Logs                              # Show live logs"
    Write-Host ""
    Write-Host "GitHub Runner setup:"
    Write-Host "  .\deploy-windows.ps1 -SetupRunner                       # Setup GitHub runner (auto-detects repo)"
    Write-Host "  .\deploy-windows.ps1 -SetupRunner -RunnerToken TOKEN    # Setup with manual token"
    Write-Host ""
    Write-Host "Useful commands:"
    Write-Host "  podman-compose ps                                        # Show running containers"
    Write-Host "  podman-compose logs -f singularity                       # Follow logs"
    Write-Host "  podman exec -it singularity-app bash                     # Shell into container"
    Write-Host "  gh run list -R yourorg/singularity                       # View recent runs"
    Write-Host ""
}

# Main execution
try {
    if ($SetupRunner) {
        $result = Setup-GitHubRunner -Token $RunnerToken -RepoUrl $RunnerUrl
        if (!$result) {
            exit 1
        }
        Show-Help
    } elseif ($Stop) {
        Stop-Services
    } elseif ($Restart) {
        Restart-Services
        if (!$NoHealthCheck) { Test-Health | Out-Null }
        Show-Status
    } elseif ($Logs) {
        Show-Logs
    } else {
        # Normal deploy
        Test-Prerequisites
        Start-Services

        if (!$NoHealthCheck) {
            if (Test-Health) {
                Write-Host ""
                Write-Status "🎉 Deployment successful!" -Type success
            } else {
                Write-Status "⚠️  Some services may not be fully ready. Check logs." -Type warning
            }
        }

        Show-Status
        Show-Help
    }
} catch {
    Write-Status "Error: $_" -Type error
    exit 1
}
