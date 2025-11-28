#requires -version 5.0
<#
  BrowserStack Onboarding (PowerShell 5.0, GUI)
  - Full parity port of macOS bash
  - Uses WinForms for GUI prompts
  - Logs to %USERPROFILE%\.browserstack\NOW\logs
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ===== Global Variables =====
$WORKSPACE_DIR = Join-Path $env:USERPROFILE ".browserstack"
$PROJECT_FOLDER = "NOW"

$GLOBAL_DIR = Join-Path $WORKSPACE_DIR $PROJECT_FOLDER
$LOG_DIR     = Join-Path $GLOBAL_DIR "logs"
$GLOBAL_LOG  = Join-Path $LOG_DIR "global.log"
$WEB_LOG     = Join-Path $LOG_DIR "web_run_result.log"
$MOBILE_LOG  = Join-Path $LOG_DIR "mobile_run_result.log"

# Clear/prepare logs
if (!(Test-Path $LOG_DIR)) { New-Item -ItemType Directory -Path $LOG_DIR | Out-Null }
'' | Out-File -FilePath $GLOBAL_LOG -Encoding UTF8
'' | Out-File -FilePath $WEB_LOG -Encoding UTF8
'' | Out-File -FilePath $MOBILE_LOG -Encoding UTF8

# Script state
$BROWSERSTACK_USERNAME = ""
$BROWSERSTACK_ACCESS_KEY = ""
$TEST_TYPE = ""     # Web / App / Both
$TECH_STACK = ""    # Java / Python / JS
[double]$PARALLEL_PERCENTAGE = 1.00

$WEB_PLAN_FETCHED = $false
$MOBILE_PLAN_FETCHED = $false
[int]$TEAM_PARALLELS_MAX_ALLOWED_WEB = 0
[int]$TEAM_PARALLELS_MAX_ALLOWED_MOBILE = 0

# URL handling
$DEFAULT_TEST_URL = "https://bstackdemo.com"
$CX_TEST_URL = $DEFAULT_TEST_URL

# App handling
$APP_URL = ""
$APP_PLATFORM = ""  # ios | android | all

# Chosen Python command tokens (set during validation when Python is selected)
$PY_CMD = @()

# ===== Error patterns (placeholders to match your original arrays) =====
$WEB_SETUP_ERRORS   = @("")
$WEB_LOCAL_ERRORS   = @("")
$MOBILE_SETUP_ERRORS= @("")
$MOBILE_LOCAL_ERRORS= @("")

# ===== Source Modular Scripts =====
. "$PSScriptRoot\logging-utils.ps1"
. "$PSScriptRoot\common-utils.ps1"
. "$PSScriptRoot\user-interaction.ps1"
. "$PSScriptRoot\device-machine-allocation.ps1"
. "$PSScriptRoot\env-prequisite-checks.ps1"
. "$PSScriptRoot\env-setup-run.ps1"


# ===== Orchestration =====
function Run-Setup {
  Log-Line "Orchestration: TEST_TYPE=$TEST_TYPE, WEB_PLAN_FETCHED=$WEB_PLAN_FETCHED, MOBILE_PLAN_FETCHED=$MOBILE_PLAN_FETCHED" $GLOBAL_LOG
  
  $webRan = $false
  $mobileRan = $false
  
  switch ($TEST_TYPE) {
    "Web" {
      if ($WEB_PLAN_FETCHED) { 
        Setup-Web
        $webRan = $true
      } else { 
        Log-Line "⚠️ Skipping Web setup — Web plan not fetched" $GLOBAL_LOG 
      }
    }
    "App" {
      if ($MOBILE_PLAN_FETCHED) { 
        Setup-Mobile
        $mobileRan = $true
      } else { 
        Log-Line "⚠️ Skipping Mobile setup — Mobile plan not fetched" $GLOBAL_LOG 
      }
    }
    "Both" {
      $ranAny = $false
      if ($WEB_PLAN_FETCHED) { 
        Setup-Web
        $webRan = $true
        $ranAny = $true 
      } else { 
        Log-Line "⚠️ Skipping Web setup — Web plan not fetched" $GLOBAL_LOG 
      }
      if ($MOBILE_PLAN_FETCHED) { 
        Setup-Mobile
        $mobileRan = $true
        $ranAny = $true 
      } else { 
        Log-Line "⚠️ Skipping Mobile setup — Mobile plan not fetched" $GLOBAL_LOG 
      }
      if (-not $ranAny) { 
        Log-Line "❌ Both Web and Mobile setup were skipped. Exiting." $GLOBAL_LOG
        throw "No setups executed" 
      }
    }
    default { 
      Log-Line "❌ Invalid TEST_TYPE: $TEST_TYPE" $GLOBAL_LOG
      throw "Invalid TEST_TYPE" 
    }
  }
  
  # Final Summary
  Log-Line " " $GLOBAL_LOG
  Log-Line "========================================" $GLOBAL_LOG
  Log-Line "📋 EXECUTION SUMMARY" $GLOBAL_LOG
  Log-Line "========================================" $GLOBAL_LOG
  if ($webRan) {
    Log-Line "✅ Web Testing: COMPLETED" $GLOBAL_LOG
    Log-Line "   📄 Logs: $WEB_LOG" $GLOBAL_LOG
  }
  if ($mobileRan) {
    Log-Line "✅ Mobile App Testing: COMPLETED" $GLOBAL_LOG
    Log-Line "   📄 Logs: $MOBILE_LOG" $GLOBAL_LOG
  }
  Log-Line "========================================" $GLOBAL_LOG
  Log-Line "🎉 All requested tests have been executed!" $GLOBAL_LOG
  Log-Line "🔗 View results: https://automation.browserstack.com/" $GLOBAL_LOG
  Log-Line "========================================" $GLOBAL_LOG
}

# ===== Main =====
try {
  Ensure-Workspace
  Ask-BrowserStack-Credentials
  Ask-Test-Type
  Ask-Tech-Stack
  Validate-Tech-Stack
  Fetch-Plan-Details

  Log-Line "Plan summary: WEB_PLAN_FETCHED=$WEB_PLAN_FETCHED (team max=$TEAM_PARALLELS_MAX_ALLOWED_WEB), MOBILE_PLAN_FETCHED=$MOBILE_PLAN_FETCHED (team max=$TEAM_PARALLELS_MAX_ALLOWED_MOBILE)" $GLOBAL_LOG
  
  # Check for proxy configuration
  Log-Line "ℹ️ Checking proxy in environment" $GLOBAL_LOG
  $proxyCheckScript = Join-Path $PSScriptRoot "env-prequisite-checks.ps1"
  if (Test-Path $proxyCheckScript) {
    try {
      & $proxyCheckScript -BrowserStackUsername $BROWSERSTACK_USERNAME -BrowserStackAccessKey $BROWSERSTACK_ACCESS_KEY
      if ($env:PROXY_HOST -and $env:PROXY_PORT) {
        Log-Line "✅ Proxy configured: $env:PROXY_HOST:$env:PROXY_PORT" $GLOBAL_LOG
      } else {
        Log-Line "ℹ️ No proxy configured or proxy check failed" $GLOBAL_LOG
      }
    } catch {
      Log-Line "⚠️ Proxy check script failed: $($_.Exception.Message)" $GLOBAL_LOG
    }
  } else {
    Log-Line "⚠️ Proxy check script not found at: $proxyCheckScript" $GLOBAL_LOG
  }
  
  Run-Setup
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