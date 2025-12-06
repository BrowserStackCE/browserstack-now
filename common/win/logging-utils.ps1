# Logging Helpers for PowerShell

# ==============================================
# COLOR & STYLE DEFINITIONS
# ==============================================
# PowerShell uses Write-Host -ForegroundColor for colors.
# We will define helper functions instead of raw escape codes for better compatibility.

function Log-Section {
    param([string]$Message)
    Write-Host ""
    Write-Host "-----------------------------------------------" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor White
    Write-Host "-----------------------------------------------" -ForegroundColor Cyan
}

function Log-Info {
    param([string]$Message)
    Write-Host "$Message" -ForegroundColor Gray
}

function Log-Success {
    param([string]$Message)
    Write-Host "$Message" -ForegroundColor Green
}

function Log-Warn {
    param([string]$Message)
    Write-Host "$Message" -ForegroundColor Yellow
}

function Log-Error {
    param([string]$Message)
    Write-Host "$Message" -ForegroundColor Red
}

function Log-Line {
    param(
        [string]$Message,
        [string]$LogFile
    )
    if (-not $LogFile) {
    $DestFile = Get-RunLogFile
    }

    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "$Message"
    Write-Host $line
    if ($DestFile) {
        $dir = Split-Path -Parent $DestFile
        if ($dir -and !(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
        Add-Content -Path $DestFile -Value $line
    }
}

