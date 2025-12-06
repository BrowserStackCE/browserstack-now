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

# ===== Import utilities =====
$script:PSScriptRootResolved = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $PSScriptRootResolved "logging-utils.ps1")
. (Join-Path $PSScriptRootResolved "common-utils.ps1")

. (Join-Path $PSScriptRootResolved "user-interaction.ps1")
. (Join-Path $PSScriptRootResolved "env-prequisite-checks.ps1")
. (Join-Path $PSScriptRootResolved "env-setup-run.ps1")


# ===== Main flow (baseline steps then run) =====
try {

  $script:CurrentDir = (Get-Location).Path
  
  # Get test type and tech stack before logging
  if ($RunMode -match "--silent|--debug") {
    $textInfo = (Get-Culture).TextInfo
    $ttCandidate = if ($TT) { $TT } else { $env:TEST_TYPE }
    if ([string]::IsNullOrWhiteSpace($ttCandidate)) { throw "TEST_TYPE is required in silent/debug mode." }
    $tsCandidate = if ($TSTACK) { $TSTACK } else { $env:TECH_STACK }
    if ([string]::IsNullOrWhiteSpace($tsCandidate)) { throw "TECH_STACK is required in silent/debug mode." }
    $script:TEST_TYPE = $textInfo.ToTitleCase($ttCandidate.ToLowerInvariant())
    $script:TECH_STACK = $textInfo.ToTitleCase($tsCandidate.ToLowerInvariant())
    if ($TEST_TYPE -notin @("Web","App")) { throw "TEST_TYPE must be either 'Web' or 'App'." }
    if ($TECH_STACK -notin @("Java","Python","NodeJS")) { throw "TECH_STACK must be one of: Java, Python, NodeJS." }
  } else {
    Resolve-Test-Type -RunMode $RunMode -CliValue $TT
    Resolve-Tech-Stack -RunMode $RunMode -CliValue $TSTACK
  }

  # Setup log file path AFTER selections
  $logFileName = "{0}_{1}_run_result.log" -f $TEST_TYPE.ToLowerInvariant(), $TECH_STACK.ToLowerInvariant()
  $logFile = Join-Path $script:LOG_DIR $logFileName
  if (!(Test-Path $script:LOG_DIR)) {
    New-Item -ItemType Directory -Path $script:LOG_DIR -Force | Out-Null
  }
  '' | Out-File -FilePath $logFile -Encoding UTF8
  $script:GLOBAL_LOG = $logFile
  $global:NOW_RUN_LOG_FILE = $logFile
  
  Log-Line "Log file path: $logFile" $global:NOW_RUN_LOG_FILE

  # Setup Summary Header
  Log-Section "Setup Summary - BrowserStack NOW"
  Log-Line "Timestamp: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))" $global:NOW_RUN_LOG_FILE
  
  Log-Line "Run Mode: $RunMode" $global:NOW_RUN_LOG_FILE
  Log-Line "Selected Testing Type: $TEST_TYPE" $global:NOW_RUN_LOG_FILE
  Log-Line "Selected Tech Stack: $TECH_STACK" $global:NOW_RUN_LOG_FILE

  # Setup workspace and get credentials BEFORE app upload
  Setup-Workspace
  Ask-BrowserStack-Credentials -RunMode $RunMode -UsernameFromEnv $env:BROWSERSTACK_USERNAME -AccessKeyFromEnv $env:BROWSERSTACK_ACCESS_KEY

  # NOW handle URL/App upload (requires credentials)
  Perform-NextSteps-BasedOnTestType -TestType $TEST_TYPE -RunMode $RunMode -TestUrl $TestUrl -AppPath $AppPath -AppPlatform $AppPlatform

  # Run the setup
  Setup-Environment -SetupType $TEST_TYPE.ToLower() -TechStack $TECH_STACK.ToLower()

  # Platform & Tech Stack section
  Log-Section "Platform & Tech Stack"
  Log-Line "Platform: $TEST_TYPE" $global:NOW_RUN_LOG_FILE
  Log-Line "Tech Stack: $TECH_STACK" $global:NOW_RUN_LOG_FILE

  # System Prerequisites Check
  Validate-Tech-Stack -TechStack $TECH_STACK

  # Account & Plan Details
  Fetch-Plan-Details -TestType $TEST_TYPE

  Log-Line "Checking proxy in environment" $global:NOW_RUN_LOG_FILE
  Set-ProxyInEnv

  # Getting Ready section
  Log-Section "Getting Ready"
  Log-Line "Detected Operating system: Windows" $global:NOW_RUN_LOG_FILE
  Log-Line "Clearing old logs from NOW Home Directory inside .browserstack" $global:NOW_RUN_LOG_FILE
  Clear-OldLogs

  Log-Line "Starting $TEST_TYPE setup for $TECH_STACK" $global:NOW_RUN_LOG_FILE
  
  # Run the setup
  Setup-Environment -SetupType $TEST_TYPE.ToLower() -TechStack $TECH_STACK.ToLower()
} 
catch {
  Log-Line " " $global:NOW_RUN_LOG_FILE
  Log-Line "========================================" $global:NOW_RUN_LOG_FILE
  Log-Line "EXECUTION FAILED" $global:NOW_RUN_LOG_FILE
  Log-Line "========================================" $global:NOW_RUN_LOG_FILE
  Log-Line "Error: $($_.Exception.Message)" $global:NOW_RUN_LOG_FILE
  Log-Line "Check logs for details:" $global:NOW_RUN_LOG_FILE
  Log-Line ("  Run Log: {0}" -f $global:NOW_RUN_LOG_FILE) $global:NOW_RUN_LOG_FILE
  Log-Line "========================================" $global:NOW_RUN_LOG_FILE
  Set-Location -Path $script:CurrentDir
  exit 1
} finally {
  Set-Location -Path $script:CurrentDir
}

