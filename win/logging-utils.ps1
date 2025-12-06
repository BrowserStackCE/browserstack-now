# Logging helpers shared across the Windows BrowserStack NOW scripts.

if (-not (Get-Variable -Name NOW_RUN_LOG_FILE -Scope Script -ErrorAction SilentlyContinue)) {
  $script:NOW_RUN_LOG_FILE = ""
}

if (-not (Get-Variable -Name SILENT_MODE -Scope Script -ErrorAction SilentlyContinue)) {
  $script:SILENT_MODE = $false
}

function Set-RunLogFile {
  param([string]$Path)
  $script:NOW_RUN_LOG_FILE = $Path
  if ($Path) {
    $env:NOW_RUN_LOG_FILE = $Path
  } else {
    Remove-Item Env:NOW_RUN_LOG_FILE -ErrorAction SilentlyContinue
  }
}

function Get-RunLogFile {
  return $script:NOW_RUN_LOG_FILE
}

function Set-SilentMode {
  param([bool]$Enabled)
  $script:SILENT_MODE = $Enabled
}

function Get-SilentMode {
  return $script:SILENT_MODE
}

function Log-Line {
  param(
    [Parameter(Mandatory=$true)][AllowEmptyString()][string]$Message,
    [string]$DestFile
  )
  if (-not $DestFile) {
    $DestFile = Get-RunLogFile
  }

  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  $line = "[$ts] $Message"
  
  # Only write to console if not in silent mode
  if (-not $script:SILENT_MODE) {
    Write-Host $line
  }
  
  # Always write to log file
  if ($DestFile) {
    $dir = Split-Path -Parent $DestFile
    if ($dir -and !(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    Add-Content -Path $DestFile -Value $line
  }
}

function Log-Section {
  param(
    [Parameter(Mandatory)][AllowEmptyString()][string]$Title,
    [string]$DestFile
  )
  $divider = "───────────────────────────────────────────────"
  Log-Line "" $DestFile
  Log-Line $divider $DestFile
  Log-Line ("{0}" -f $Title) $DestFile
  Log-Line $divider $DestFile
}

function Log-Info    { param([string]$Message,[string]$DestFile) Log-Line ("ℹ️  $Message") $DestFile }
function Log-Success { param([string]$Message,[string]$DestFile) Log-Line ("✅  $Message") $DestFile }
function Log-Warn    { param([string]$Message,[string]$DestFile) Log-Line ("⚠️  $Message") $DestFile }
function Log-Error   { param([string]$Message,[string]$DestFile) Log-Line ("❌  $Message") $DestFile }

