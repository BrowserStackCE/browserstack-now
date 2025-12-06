#requires -version 5.0
param(
  [string]$RunMode = "--interactive",
  [string]$TT,
  [string]$TSTACK,
  [string]$TestUrl,
  [string]$AppPath,
  [string]$AppPlatform
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$commonScript = Join-Path $scriptDir "..\common\win\run.ps1"

# Resolve to absolute path
if (Test-Path $commonScript) {
    $commonScript = (Resolve-Path $commonScript).Path
} else {
    Write-Error "Common script not found at $commonScript"
    exit 1
}

# Execute common script with arguments
& $commonScript -RunMode $RunMode -TT $TT -TSTACK $TSTACK -TestUrl $TestUrl -AppPath $AppPath -AppPlatform $AppPlatform
