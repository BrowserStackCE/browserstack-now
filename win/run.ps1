#requires -version 5.0
<#
  BrowserStack Onboarding (PowerShell 5.0, GUI)
  - Full parity port of macOS bash run.sh
  - Uses WinForms for GUI prompts
  - Logs to %USERPROFILE%\.browserstack\NOW\logs
#>

param(
  [string]$RunMode = "--interactive",
  [string]$TT,
  [string]$TSTACK,
  [string]$TestUrl,
  [string]$AppPath,
  [string]$AppPlatform
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ===== Import utilities (like Mac's source commands) =====
$script:PSScriptRootResolved = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $PSScriptRootResolved "logging-utils.ps1")
. (Join-Path $PSScriptRootResolved "common-utils.ps1")
. (Join-Path $PSScriptRootResolved "device-machine-allocation.ps1")
. (Join-Path $PSScriptRootResolved "user-interaction.ps1")
. (Join-Path $PSScriptRootResolved "env-prequisite-checks.ps1")
. (Join-Path $PSScriptRootResolved "env-setup-run.ps1")

# ===== Main flow (baseline steps then run) =====
try {
  # Setup Summary Header
  Log-Section "🧭 Setup Summary – BrowserStack NOW" $GLOBAL_LOG
  Log-Line "ℹ️ Timestamp: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))" $GLOBAL_LOG

  # Get test type and tech stack FIRST
  if ($RunMode -match "--silent|--debug") {
    $script:TEST_TYPE = if ($TT) { (Get-Culture).TextInfo.ToTitleCase($TT.ToLowerInvariant()) } else { $env:TEST_TYPE }
    $script:TECH_STACK = if ($TSTACK) { (Get-Culture).TextInfo.ToTitleCase($TSTACK.ToLowerInvariant()) } else { $env:TECH_STACK }
    Log-Line "ℹ️ Run Mode: $RunMode" $GLOBAL_LOG
  } else {
    Resolve-Test-Type -RunMode $RunMode -CliValue $TT
    Resolve-Tech-Stack -RunMode $RunMode -CliValue $TSTACK
  }

  # Setup log file path
  $logFile = Join-Path $LOG_DIR ("{0}_{1}_run_result.log" -f $TEST_TYPE.ToLowerInvariant(), $TECH_STACK.ToLowerInvariant())
  Log-Line "ℹ️ Log file path: $logFile" $GLOBAL_LOG
  Set-RunLogFile $logFile

  # Setup workspace and get credentials BEFORE app upload
  Setup-Workspace
  Ask-BrowserStack-Credentials -RunMode $RunMode -UsernameFromEnv $env:BROWSERSTACK_USERNAME -AccessKeyFromEnv $env:BROWSERSTACK_ACCESS_KEY

  # NOW handle URL/App upload (requires credentials)
  Perform-NextSteps-BasedOnTestType -TestType $TEST_TYPE -RunMode $RunMode -TestUrl $TestUrl -AppPath $AppPath -AppPlatform $AppPlatform

  # Platform & Tech Stack section
  Log-Section "⚙️ Platform & Tech Stack" $GLOBAL_LOG
  Log-Line "ℹ️ Platform: $TEST_TYPE" $GLOBAL_LOG
  Log-Line "ℹ️ Tech Stack: $TECH_STACK" $GLOBAL_LOG

  # System Prerequisites Check
  Log-Section "🧩 System Prerequisites Check" $GLOBAL_LOG
  Validate-Tech-Stack

  # Account & Plan Details
  Log-Section "☁️ Account & Plan Details" $GLOBAL_LOG
  Fetch-Plan-Details -TestType $TEST_TYPE

  Log-Line "Plan summary: WEB_PLAN_FETCHED=$WEB_PLAN_FETCHED (team max=$TEAM_PARALLELS_MAX_ALLOWED_WEB), MOBILE_PLAN_FETCHED=$MOBILE_PLAN_FETCHED (team max=$TEAM_PARALLELS_MAX_ALLOWED_MOBILE)" $GLOBAL_LOG
  Log-Line "Checking proxy in environment" $GLOBAL_LOG
  Set-ProxyInEnv -Username $BROWSERSTACK_USERNAME -AccessKey $BROWSERSTACK_ACCESS_KEY

  # Getting Ready section
  Log-Section "🧹 Getting Ready" $GLOBAL_LOG
  Log-Line "ℹ️ Detected Operating system: Windows" $GLOBAL_LOG
  Log-Line "ℹ️ Clearing old logs from NOW Home Directory inside .browserstack" $GLOBAL_LOG
  Clear-OldLogs

  Log-Line "ℹ️ Starting $TEST_TYPE setup for $TECH_STACK" $GLOBAL_LOG
  
  # Run the setup
  Run-Setup -TestType $TEST_TYPE -TechStack $TECH_STACK

} catch {
  Log-Line " " $GLOBAL_LOG
  Log-Line "========================================" $GLOBAL_LOG
  Log-Line "❌ EXECUTION FAILED" $GLOBAL_LOG
  Log-Line "========================================" $GLOBAL_LOG
  Log-Line "Error: $($_.Exception.Message)" $GLOBAL_LOG
  Log-Line "Check logs for details:" $GLOBAL_LOG
  Log-Line "  Global: $GLOBAL_LOG" $GLOBAL_LOG
  Log-Line "  Web: $WEB_LOG" $GLOBAL_LOG
  Log-Line "  Mobile: $MOBILE_LOG" $GLOBAL_LOG
  Log-Line "========================================" $GLOBAL_LOG
  throw
}

