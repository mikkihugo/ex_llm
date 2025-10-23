#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Complete Windows RTX 4080 setup - Install all prerequisites and configure GitHub runner

.DESCRIPTION
    One-command setup for Windows RTX 4080 production:
    1. Installs Podman (if not installed)
    2. Installs GitHub CLI (if not installed)
    3. Authenticates with GitHub
    4. Creates and configures GitHub self-hosted runner
    5. Sets up environment file
    6. Ready for deployment

.EXAMPLE
    .\setup-windows.ps1
    # OR with authentication token
    .\setup-windows.ps1 -GithubToken "ghp_xxxx"

.PARAMETER GithubToken
    GitHub personal access token (optional, will prompt if needed)
    Must have: admin:org_hook, repo, workflow scopes
#>

param(
    [string]$GithubToken
)

$ErrorActionPreference = "Stop"

# Colors for output
$colors = @{
    success = "Green"
    error = "Red"
    warning = "Yellow"
    info = "Cyan"
    highlight = "Magenta"
}

function Write-Status {
    param([string]$Message, [string]$Type = "info")
    $color = $colors[$Type]
    Write-Host "[$([datetime]::Now.ToString('HH:mm:ss'))] $Message" -ForegroundColor $color
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ $Title".PadRight(68) + "║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Install-Chocolatey {
    Write-Status "Installing Chocolatey..." -Type info

    $chocoPath = "C:\ProgramData\chocolatey\bin\choco.exe"
    if (Test-Path $chocoPath) {
        Write-Status "✓ Chocolatey already installed" -Type success
        return $true
    }

    Write-Status "Downloading Chocolatey..." -Type info
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Status "✓ Chocolatey installed" -Type success
        return $true
    } catch {
        Write-Status "Failed to install Chocolatey: $_" -Type error
        return $false
    }
}

function Install-Podman {
    Write-Status "Checking Podman..." -Type info

    if (Get-Command podman -ErrorAction SilentlyContinue) {
        $version = podman --version
        Write-Status "✓ Podman already installed: $version" -Type success
        return $true
    }

    Write-Status "Installing Podman..." -Type warning
    try {
        choco install podman -y
        Write-Status "✓ Podman installed" -Type success
        return $true
    } catch {
        Write-Status "Failed to install Podman: $_" -Type error
        return $false
    }
}

function Install-PodmanCompose {
    Write-Status "Checking Podman Compose..." -Type info

    if (Get-Command podman-compose -ErrorAction SilentlyContinue) {
        Write-Status "✓ Podman Compose already installed" -Type success
        return $true
    }

    Write-Status "Installing Podman Compose..." -Type warning
    try {
        pip install podman-compose
        Write-Status "✓ Podman Compose installed" -Type success
        return $true
    } catch {
        Write-Status "Failed to install Podman Compose: $_" -Type error
        return $false
    }
}

function Install-GitHubCLI {
    Write-Status "Checking GitHub CLI..." -Type info

    if (Get-Command gh -ErrorAction SilentlyContinue) {
        $version = gh --version
        Write-Status "✓ GitHub CLI already installed: $version" -Type success
        return $true
    }

    Write-Status "Installing GitHub CLI..." -Type warning
    try {
        choco install gh -y
        Write-Status "✓ GitHub CLI installed" -Type success
        return $true
    } catch {
        Write-Status "Failed to install GitHub CLI: $_" -Type error
        return $false
    }
}

function Install-Git {
    Write-Status "Checking Git..." -Type info

    if (Get-Command git -ErrorAction SilentlyContinue) {
        $version = git --version
        Write-Status "✓ Git already installed: $version" -Type success
        return $true
    }

    Write-Status "Installing Git..." -Type warning
    try {
        choco install git -y
        Write-Status "✓ Git installed" -Type success
        return $true
    } catch {
        Write-Status "Failed to install Git: $_" -Type error
        return $false
    }
}

function Verify-GPU {
    Write-Status "Checking NVIDIA GPU..." -Type info

    if (!(Get-Command nvidia-smi -ErrorAction SilentlyContinue)) {
        Write-Status "⚠️  nvidia-smi not found. Ensure NVIDIA drivers are installed." -Type warning
        Write-Status "Download from: https://www.nvidia.com/Download/driverDetails.aspx" -Type info
        return $false
    }

    try {
        $gpu = nvidia-smi --query-gpu=name --format=csv,noheader | Select-Object -First 1
        Write-Status "✓ GPU detected: $gpu" -Type success
        return $true
    } catch {
        Write-Status "Could not query GPU info" -Type warning
        return $false
    }
}

function Authenticate-GitHub {
    Write-Status "Authenticating with GitHub..." -Type info

    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Status "✓ Already authenticated with GitHub" -Type success
        # Get current user
        $user = gh api user --jq '.login'
        Write-Status "  Logged in as: $user" -Type success
        return $true
    }

    Write-Status "Starting GitHub authentication..." -Type warning
    Write-Status "A browser window will open. Sign in with your GitHub account." -Type info

    try {
        gh auth login --web
        if ($LASTEXITCODE -eq 0) {
            Write-Status "✓ Successfully authenticated with GitHub" -Type success
            return $true
        } else {
            Write-Status "Authentication failed" -Type error
            return $false
        }
    } catch {
        Write-Status "Authentication error: $_" -Type error
        return $false
    }
}

function Setup-GitHubRunner {
    Write-Section "Setting Up GitHub Actions Runner"

    # Get repository info
    $gitRemote = git config --get remote.origin.url 2>$null
    if (-not $gitRemote) {
        Write-Status "Error: Not in a git repository or no remote configured" -Type error
        return $false
    }

    # Convert SSH URL to HTTPS if needed
    $repoUrl = $gitRemote -replace "git@github\.com:", "https://github.com/" -replace "\.git$", ""
    Write-Status "Repository: $repoUrl" -Type info

    # Parse owner/repo
    if ($repoUrl -match "github\.com/([^/]+)/([^/]+)") {
        $owner = $matches[1]
        $repo = $matches[2]
    } else {
        Write-Status "Could not parse repository URL: $repoUrl" -Type error
        return $false
    }

    Write-Status "Owner: $owner, Repo: $repo" -Type info

    # Create runner directory
    $runnerDir = "C:\runners\$repo"
    Write-Status "Creating runner directory: $runnerDir" -Type info

    if (Test-Path $runnerDir) {
        Write-Status "⚠️  Runner directory already exists" -Type warning
        $choice = Read-Host "Overwrite existing runner? (y/n)"
        if ($choice -ne "y") {
            Write-Status "Skipping runner setup" -Type warning
            return $false
        }
        Remove-Item -Recurse -Force $runnerDir
    }

    New-Item -ItemType Directory -Force -Path $runnerDir | Out-Null

    # Download runner
    Write-Status "Downloading GitHub Actions runner..." -Type info
    $runnerVersion = "2.319.0"
    $runnerUrl = "https://github.com/actions/runner/releases/download/v$runnerVersion/actions-runner-win-x64-$runnerVersion.zip"
    $runnerZip = "$runnerDir\runner.zip"

    try {
        Invoke-WebRequest -Uri $runnerUrl -OutFile $runnerZip -ErrorAction Stop
        Write-Status "✓ Runner downloaded" -Type success
    } catch {
        Write-Status "Failed to download runner: $_" -Type error
        return $false
    }

    # Extract
    Write-Status "Extracting runner..." -Type info
    try {
        Expand-Archive -Path $runnerZip -DestinationPath $runnerDir -Force
        Remove-Item $runnerZip
        Write-Status "✓ Runner extracted" -Type success
    } catch {
        Write-Status "Failed to extract runner: $_" -Type error
        return $false
    }

    # Get registration token
    Write-Status "Getting registration token from GitHub..." -Type info
    try {
        $response = gh api --method POST "repos/$owner/$repo/actions/runners/registration-token" --jq '.token' 2>$null
        if (-not $response) {
            Write-Status "Could not generate token. You may need to provide a personal access token." -Type warning
            if ($GithubToken) {
                Write-Status "Using provided GitHub token..." -Type info
                $env:GH_TOKEN = $GithubToken
                $response = gh api --method POST "repos/$owner/$repo/actions/runners/registration-token" --jq '.token' 2>$null
            } else {
                Write-Status "Please provide token with -GithubToken parameter" -Type error
                Write-Status "Create at: https://github.com/settings/tokens (scopes: repo, workflow, admin:org_hook)" -Type info
                return $false
            }
        }
        $token = $response
        Write-Status "✓ Registration token obtained" -Type success
    } catch {
        Write-Status "Error getting token: $_" -Type error
        return $false
    }

    # Configure runner
    Write-Status "Configuring runner..." -Type info
    Push-Location $runnerDir

    try {
        $runnerName = "$env:COMPUTERNAME-$repo"
        Write-Status "Runner name: $runnerName" -Type info

        .\config.cmd --url $repoUrl --token $token --name $runnerName --work "_work" --replace --unattended

        if ($LASTEXITCODE -ne 0) {
            Write-Status "Runner configuration failed" -Type error
            Pop-Location
            return $false
        }

        Write-Status "✓ Runner configured" -Type success
    } catch {
        Write-Status "Configuration error: $_" -Type error
        Pop-Location
        return $false
    }

    # Install as service
    Write-Status "Installing runner as Windows Service..." -Type info
    try {
        .\svc.cmd install
        if ($LASTEXITCODE -ne 0) {
            Write-Status "Service installation failed" -Type error
            Pop-Location
            return $false
        }
        Write-Status "✓ Service installed" -Type success
    } catch {
        Write-Status "Service installation error: $_" -Type error
        Pop-Location
        return $false
    }

    # Start service
    Write-Status "Starting runner service..." -Type info
    try {
        .\svc.cmd start
        Write-Status "✓ Service started" -Type success
    } catch {
        Write-Status "Service start error: $_" -Type error
        Pop-Location
        return $false
    }

    Pop-Location

    Write-Status "✓ GitHub runner installed and started" -Type success
    Write-Status "  Location: $runnerDir" -Type info
    Write-Status "  Name: $runnerName" -Type info

    Start-Sleep -Seconds 5
    Write-Status "Runner will appear in GitHub within 30 seconds" -Type highlight
    Write-Status "View at: $repoUrl/settings/actions/runners" -Type info

    return $true
}

function Setup-EnvironmentFile {
    Write-Section "Setting Up Environment File"

    $envFile = "$(Get-Location)\production\.env"
    $envExample = "$(Get-Location)\production\.env.production.example"

    if (-not (Test-Path $envExample)) {
        Write-Status "⚠️  .env.production.example not found" -Type warning
        return $false
    }

    if (Test-Path $envFile) {
        Write-Status ".env file already exists" -Type warning
        return $true
    }

    Write-Status "Copying .env.production.example to .env" -Type info
    Copy-Item $envExample $envFile
    Write-Status "✓ .env created" -Type success

    Write-Status "⚠️  IMPORTANT: Edit .env with your actual values:" -Type warning
    Write-Status "  $envFile" -Type info
    Write-Status "" -Type info
    Write-Status "Required changes:" -Type info
    Write-Status "  1. POSTGRES_PASSWORD - Change to secure password" -Type info
    Write-Status "  2. SECRET_KEY_BASE - Generate random string" -Type info
    Write-Status "  3. API Keys:" -Type info
    Write-Status "     - ANTHROPIC_API_KEY" -Type info
    Write-Status "     - GOOGLE_AI_STUDIO_API_KEY" -Type info
    Write-Status "     - OPENAI_API_KEY" -Type info

    return $true
}

function Show-Summary {
    Write-Section "Setup Complete ✅"

    Write-Status "Your Windows RTX 4080 is ready for production!" -Type success
    Write-Host ""

    Write-Host "Next steps:" -ForegroundColor Green
    Write-Host "  1. Edit environment file:" -ForegroundColor Yellow
    Write-Host "     notepad production\.env" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  2. Deploy services:" -ForegroundColor Yellow
    Write-Host "     cd production" -ForegroundColor Cyan
    Write-Host "     .\deploy-windows.ps1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  3. Check GitHub runner:" -ForegroundColor Yellow
    Write-Host "     https://github.com/mikkihugo/singularity-incubation/settings/actions/runners" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Installed components:" -ForegroundColor Green
    Write-Host "  ✓ Podman (container runtime)" -ForegroundColor Green
    Write-Host "  ✓ Podman Compose" -ForegroundColor Green
    Write-Host "  ✓ GitHub CLI (gh)" -ForegroundColor Green
    Write-Host "  ✓ GitHub Actions Runner (Windows Service)" -ForegroundColor Green
    Write-Host "  ✓ Environment file (.env)" -ForegroundColor Green
    Write-Host ""
}

# Main execution
try {
    Write-Section "Windows RTX 4080 Setup"
    Write-Status "Starting complete setup process..." -Type highlight

    # Step 1: Chocolatey
    Write-Section "Step 1: Installing Package Manager"
    if (-not (Install-Chocolatey)) {
        Write-Status "Please install Chocolatey manually from: https://chocolatey.org/install" -Type error
        exit 1
    }

    # Step 2: Prerequisites
    Write-Section "Step 2: Installing Prerequisites"
    if (-not (Install-Git)) { exit 1 }
    if (-not (Install-Podman)) { exit 1 }
    if (-not (Install-PodmanCompose)) { exit 1 }
    if (-not (Install-GitHubCLI)) { exit 1 }

    # Step 3: GPU
    Write-Section "Step 3: Verifying GPU"
    Verify-GPU | Out-Null

    # Step 4: GitHub Authentication
    Write-Section "Step 4: Authenticating with GitHub"
    if (-not (Authenticate-GitHub)) {
        Write-Status "Failed to authenticate with GitHub" -Type error
        exit 1
    }

    # Step 5: GitHub Runner
    Write-Section "Step 5: Setting Up GitHub Actions Runner"
    if (-not (Setup-GitHubRunner)) {
        Write-Status "Failed to setup GitHub runner" -Type warning
    }

    # Step 6: Environment
    Write-Section "Step 6: Setting Up Environment File"
    Setup-EnvironmentFile | Out-Null

    # Summary
    Show-Summary

} catch {
    Write-Status "Fatal error: $_" -Type error
    exit 1
}
