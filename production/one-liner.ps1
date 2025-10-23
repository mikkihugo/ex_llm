#!/usr/bin/env pwsh
<#
.SYNOPSIS
    One-liner setup for Windows RTX 4080 (for copy-paste into PowerShell)

.DESCRIPTION
    Run this single script to:
    1. Install all prerequisites
    2. Configure GitHub runner
    3. Set up environment
    4. Ready to deploy

.EXAMPLE
    # Copy-paste into PowerShell as Administrator:
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser; iex (iwr "https://raw.githubusercontent.com/mikkihugo/singularity-incubation/main/production/setup-windows.ps1").Content
#>

# Quick inline setup
Write-Host "Windows RTX 4080 Setup" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan
Write-Host ""

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "ERROR: Please run PowerShell as Administrator" -ForegroundColor Red
    exit 1
}

# Run full setup script
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$setupScript = Join-Path $scriptPath "setup-windows.ps1"

if (Test-Path $setupScript) {
    & $setupScript
} else {
    Write-Host "ERROR: setup-windows.ps1 not found" -ForegroundColor Red
    exit 1
}
