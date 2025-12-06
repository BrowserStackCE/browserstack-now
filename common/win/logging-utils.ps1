# Logging Helpers for PowerShell

# ==============================================
# 🎨 COLOR & STYLE DEFINITIONS
# ==============================================
# PowerShell uses Write-Host -ForegroundColor for colors.
# We will define helper functions instead of raw escape codes for better compatibility.

function Log-Section {
    param([string]$Message)
    Write-Host ""
    Write-Host "───────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor White
    Write-Host "───────────────────────────────────────────────" -ForegroundColor Cyan
}

function Log-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Gray
}

function Log-Success {
    param([string]$Message)
    Write-Host "✅  $Message" -ForegroundColor Green
}

function Log-Warn {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Log-Error {
    param([string]$Message)
    Write-Host "❌  $Message" -ForegroundColor Red
}

function Log-Line {
    param(
        [string]$Message,
        [string]$LogFile
    )
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[$ts] $Message"
    
    # Print to console if debug mode (or always, depending on usage in bash)
    # Bash version: prints to console if RUN_MODE contains --debug
    # But common-utils.sh log_msg_to also prints to console if debug.
    # Here we just append to file if provided.
    
    if (-not [string]::IsNullOrWhiteSpace($LogFile)) {
        $dir = Split-Path -Parent $LogFile
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Add-Content -Path $LogFile -Value $line -Encoding UTF8
    }
}
