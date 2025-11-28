# ==============================================
# 🪄 LOGGING HELPERS
# ==============================================

function Log-Line {
  param(
    [Parameter(Mandatory=$true)][string]$Message,
    [string]$DestFile
  )
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  $line = "[$ts] $Message"
  Write-Host $line
  if ($DestFile) {
    $dir = Split-Path -Parent $DestFile
    if ($dir -and !(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    Add-Content -Path $DestFile -Value $line
  }
}

function Show-Spinner {
  param([Parameter(Mandatory)][System.Diagnostics.Process]$Process)
  $spin = @('|','/','-','\')
  $i = 0
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  while (!$Process.HasExited) {
    Write-Host "`r[$ts] ⏳ Processing... $($spin[$i])" -NoNewline
    $i = ($i + 1) % 4
    Start-Sleep -Milliseconds 100
  }
  Write-Host "`r[$ts] ✅ Done!                    "
}
