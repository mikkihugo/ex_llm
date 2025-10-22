# Setup GitHub Actions Runner on RTX 4080
# Run this PowerShell script on your Windows RTX 4080 machine

param(
    [Parameter(Mandatory=$true)]
    [string]$RepoUrl = "https://github.com/mikkihugo/singularity-incubation",

    [Parameter(Mandatory=$true)]
    [string]$Token,

    [string]$RunnerName = "rtx4080-runner",
    [string]$Labels = "rtx4080,gpu,cuda,ml"
)

Write-Host "🎮 Setting up GitHub Actions Runner on RTX 4080..." -ForegroundColor Green

# Create runner directory
$runnerDir = "C:\actions-runner"
if (!(Test-Path $runnerDir)) {
    New-Item -ItemType Directory -Path $runnerDir -Force
}
Set-Location $runnerDir

# Download latest runner
$runnerVersion = "2.311.0"
$runnerUrl = "https://github.com/actions/runner/releases/download/v$runnerVersion/actions-runner-win-x64-$runnerVersion.zip"
$zipPath = "$runnerDir\actions-runner.zip"

Write-Host "📥 Downloading GitHub Actions Runner..."
Invoke-WebRequest -Uri $runnerUrl -OutFile $zipPath

# Extract runner
Write-Host "📦 Extracting runner..."
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $runnerDir)

# Configure runner
Write-Host "⚙️  Configuring runner..."
$configCmd = ".\config.cmd --url $RepoUrl --token $Token --name $RunnerName --labels $Labels --unattended --replace"
Invoke-Expression $configCmd

# Install as service
Write-Host "🔧 Installing as Windows service..."
.\install.cmd

# Start service
Write-Host "🚀 Starting runner service..."
.\start.cmd

# Verify GPU access
Write-Host "🎮 Verifying GPU access..."
$nvidiaOutput = & nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ GPU detected: $nvidiaOutput" -ForegroundColor Green
} else {
    Write-Host "⚠️  GPU not detected. Make sure NVIDIA drivers are installed." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✅ GitHub Actions Runner setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next steps:"
Write-Host "1. Go to $RepoUrl/actions/runners"
Write-Host "2. Verify runner appears as '$RunnerName'"
Write-Host "3. Push code to trigger workflows"
Write-Host ""
Write-Host "🎯 Your RTX 4080 is now a GitHub Actions runner!" -ForegroundColor Cyan