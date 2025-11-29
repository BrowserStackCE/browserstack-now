# Common helpers shared by the Windows BrowserStack NOW scripts.

# ===== Global Variables =====
$script:WORKSPACE_DIR = Join-Path $env:USERPROFILE ".browserstack"
$script:PROJECT_FOLDER = "NOW"

$script:GLOBAL_DIR = Join-Path $WORKSPACE_DIR $PROJECT_FOLDER
$script:LOG_DIR     = Join-Path $GLOBAL_DIR "logs"

# Script state
$script:BROWSERSTACK_USERNAME = ""
$script:BROWSERSTACK_ACCESS_KEY = ""
$script:TEST_TYPE = ""     # Web / App
$script:TECH_STACK = ""    # Java / Python / JS

$script:WEB_PLAN_FETCHED = $false
$script:MOBILE_PLAN_FETCHED = $false
[int]$script:TEAM_PARALLELS_MAX_ALLOWED_WEB = 0
[int]$script:TEAM_PARALLELS_MAX_ALLOWED_MOBILE = 0

# URL handling
$script:DEFAULT_TEST_URL = "https://bstackdemo.com"
$script:CX_TEST_URL = $DEFAULT_TEST_URL

# App handling
$script:APP_URL = ""
$script:APP_PLATFORM = ""  # ios | android | all

# Chosen Python command tokens (set during validation when Python is selected)
$script:PY_CMD = @()

# ===== Workspace Management =====
function Ensure-Workspace {
  if (!(Test-Path $GLOBAL_DIR)) {
    New-Item -ItemType Directory -Path $GLOBAL_DIR | Out-Null
    Log-Line "✅ Created Onboarding workspace: $GLOBAL_DIR" $NOW_RUN_LOG_FILE
  } else {
    Log-Line "✅ Onboarding workspace found at: $GLOBAL_DIR" $NOW_RUN_LOG_FILE
  }
}

function Setup-Workspace {
  Log-Section "⚙️ Environment & Credentials" $NOW_RUN_LOG_FILE
  Ensure-Workspace
}

function Clear-OldLogs {
  if (!(Test-Path $LOG_DIR)) { 
    New-Item -ItemType Directory -Path $LOG_DIR | Out-Null 
  }
  '' | Out-File -FilePath $NOW_RUN_LOG_FILE -Encoding UTF8
  Log-Line "✅ Logs cleared and fresh run initiated." $NOW_RUN_LOG_FILE
}

# ===== Git Clone =====
function Invoke-GitClone {
    param(
        [Parameter(Mandatory)] [string]$Url,
        [Parameter(Mandatory)] [string]$Target,
        [string]$Branch,
        [string]$LogFile
    )

    $args = @("clone")
    if ($Branch) { $args += @("-b", $Branch) }
    $args += @($Url, $Target)

    # Run git with normal PowerShell invocation
    $result = git @args 2>&1 -ErrorAction Ignore

    # Logging
    if ($LogFile) {
        $result | Out-File -FilePath $LogFile -Append
    }

    # Detect failure
    if ($LASTEXITCODE -ne 0) {
        throw "git clone failed (exit $LASTEXITCODE): $result"
    }
}


function Set-ContentNoBom {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Value
  )
  $enc = New-Object System.Text.UTF8Encoding($false)  # no BOM
  [System.IO.File]::WriteAllText($Path, $Value, $enc)
}

function Invoke-External {
    param(
        [Parameter(Mandatory)][string]$Exe,
        [string[]]$Arguments = @(),
        [string]$LogFile,
        [string]$WorkingDirectory
    )

    # Build argument string
    $argLine = ($Arguments | ForEach-Object {
        if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ }
    }) -join ' '

    # Prepare ProcessStartInfo
    $psi = New-Object System.Diagnostics.ProcessStartInfo

    $ext = [System.IO.Path]::GetExtension($Exe)
    if ($ext -and ($ext.ToLower() -in @(".cmd",".bat"))) {
        # Run through cmd.exe for batch files
        $psi.FileName = "cmd.exe"
        $psi.Arguments = "/c `"$Exe`" $argLine"
    }
    else {
        $psi.FileName = $Exe
        $psi.Arguments = $argLine
    }

    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    $psi.WorkingDirectory       = $(if ($WorkingDirectory) { $WorkingDirectory } else { (Get-Location).Path })

    # Start process
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()

    # Read output synchronously (this avoids all hangs!)
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()

    $p.WaitForExit()

    # Logging (if required)
    if ($LogFile) {
        $logDir = Split-Path $LogFile -Parent
        if ($logDir -and !(Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        if ($stdout) { Add-Content -Path $LogFile -Value $stdout }
        if ($stderr) { Add-Content -Path $LogFile -Value $stderr }
    }

    return $p.ExitCode
}


function Get-MavenCommand {
  param([Parameter(Mandatory)][string]$RepoDir)
  $mvnCmd = Get-Command mvn -ErrorAction SilentlyContinue
  if ($mvnCmd) { return $mvnCmd.Source }
  $wrapper = Join-Path $RepoDir "mvnw.cmd"
  if (Test-Path $wrapper) { return $wrapper }
  throw "Maven not found in PATH and 'mvnw.cmd' not present under $RepoDir. Install Maven or ensure the wrapper exists."
}

function Get-VenvPython {
  param([Parameter(Mandatory)][string]$VenvDir)
  $py = Join-Path $VenvDir "Scripts\python.exe"
  if (Test-Path $py) { return $py }
  throw "Python interpreter not found in venv: $VenvDir"
}

function Set-PythonCmd {
  $candidates = @(
    @("python3"),
    @("python"),
    @("py","-3"),
    @("py")
  )
  foreach ($cand in $candidates) {
    try {
      $exe = $cand[0]
      $args = @()
      if ($cand.Length -gt 1) { $args = $cand[1..($cand.Length-1)] }
      $code = Invoke-External -Exe $exe -Arguments ($args + @("--version")) -LogFile $null
      if ($code -eq 0) {
        $script:PY_CMD = $cand
        return
      }
    } catch {}
  }
  throw "Python not found via python3/python/py. Please install Python 3 and ensure it's on PATH."
}

function Invoke-Py {
  param(
    [Parameter(Mandatory)][string[]]$Arguments,
    [string]$LogFile,
    [string]$WorkingDirectory
  )
  if (-not $PY_CMD -or $PY_CMD.Count -eq 0) { Set-PythonCmd }
  $exe = $PY_CMD[0]
  $baseArgs = @()
  if ($PY_CMD.Count -gt 1) { $baseArgs = $PY_CMD[1..($PY_CMD.Count-1)] }
  return (Invoke-External -Exe $exe -Arguments ($baseArgs + $Arguments) -LogFile $LogFile -WorkingDirectory $WorkingDirectory)
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

function Test-PrivateIP {
  param([string]$IP)
  if ([string]::IsNullOrWhiteSpace($IP)) { return $false }
  $parts = $IP.Split('.')
  if ($parts.Count -ne 4) { return $false }
  $first = [int]$parts[0]
  $second = [int]$parts[1]
  if ($first -eq 10) { return $true }
  if ($first -eq 192 -and $second -eq 168) { return $true }
  if ($first -eq 172 -and $second -ge 16 -and $second -le 31) { return $true }
  return $false
}

function Test-DomainPrivate {
  $domain = $CX_TEST_URL -replace '^https?://', '' -replace '/.*$', ''
  Log-Line "Website domain: $domain" $NOW_RUN_LOG_FILE
  $env:NOW_WEB_DOMAIN = $CX_TEST_URL

  $IP_ADDRESS = ""
  try {
    $dnsResult = Resolve-DnsName -Name $domain -Type A -ErrorAction Stop | Where-Object { $_.Type -eq 'A' } | Select-Object -First 1
    if ($dnsResult) {
      $IP_ADDRESS = $dnsResult.IPAddress
    }
  } catch {
    try {
      $nslookupOutput = nslookup $domain 2>&1 | Out-String
      if ($nslookupOutput -match '(?:Address|Addresses):\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})') {
        $IP_ADDRESS = $matches[1]
      }
    } catch {
      Log-Line "⚠️ Failed to resolve domain: $domain (assuming public domain)" $NOW_RUN_LOG_FILE
      $IP_ADDRESS = ""
    }
  }

  if ([string]::IsNullOrWhiteSpace($IP_ADDRESS)) {
    Log-Line "⚠️ DNS resolution failed for: $domain (treating as public domain, BrowserStack Local will be DISABLED)" $NOW_RUN_LOG_FILE
  } else {
    Log-Line "✅ Resolved IP: $IP_ADDRESS" $NOW_RUN_LOG_FILE
  }

  return (Test-PrivateIP -IP $IP_ADDRESS)
}

function Get-BasicAuthHeader {
  param([string]$User, [string]$Key)
  $pair = "{0}:{1}" -f $User,$Key
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
  "Basic {0}" -f [System.Convert]::ToBase64String($bytes)
}

# ===== Fetch plan details =====
function Fetch-Plan-Details {
  param([string]$TestType)
  
  Log-Line "ℹ️ Fetching BrowserStack plan for $TestType" $NOW_RUN_LOG_FILE
  $auth = Get-BasicAuthHeader -User $BROWSERSTACK_USERNAME -Key $BROWSERSTACK_ACCESS_KEY
  $headers = @{ Authorization = $auth }

  if ($TestType -in @("Web","web")) {
    try {
      $resp = Invoke-RestMethod -Method Get -Uri "https://api.browserstack.com/automate/plan.json" -Headers $headers
      $script:WEB_PLAN_FETCHED = $true
      $script:TEAM_PARALLELS_MAX_ALLOWED_WEB = [int]$resp.parallel_sessions_max_allowed
      Log-Line "✅ Web Testing Plan fetched: Team max parallel sessions = $TEAM_PARALLELS_MAX_ALLOWED_WEB" $NOW_RUN_LOG_FILE
    } catch {
      Log-Line "❌ Web Testing Plan fetch failed ($($_.Exception.Message))" $NOW_RUN_LOG_FILE
    }
  }
  if ($TestType -in @("App","app")) {
    try {
      $resp2 = Invoke-RestMethod -Method Get -Uri "https://api-cloud.browserstack.com/app-automate/plan.json" -Headers $headers
      $script:MOBILE_PLAN_FETCHED = $true
      $script:TEAM_PARALLELS_MAX_ALLOWED_MOBILE = [int]$resp2.parallel_sessions_max_allowed
      Log-Line "✅ Mobile App Testing Plan fetched: Team max parallel sessions = $TEAM_PARALLELS_MAX_ALLOWED_MOBILE" $NOW_RUN_LOG_FILE
    } catch {
      Log-Line "❌ Mobile App Testing Plan fetch failed ($($_.Exception.Message))" $NOW_RUN_LOG_FILE
    }
  }

  if ( ($TestType -match "^Web$|^web$" -and -not $WEB_PLAN_FETCHED) -or
       ($TestType -match "^App$|^app$" -and -not $MOBILE_PLAN_FETCHED)) {
    Log-Line "❌ Unauthorized to fetch required plan(s) or failed request(s). Exiting." $NOW_RUN_LOG_FILE
    throw "Plan fetch failed"
  }

  Log-Line "ℹ️ Plan summary: Web $WEB_PLAN_FETCHED ($TEAM_PARALLELS_MAX_ALLOWED_WEB max), Mobile $MOBILE_PLAN_FETCHED ($TEAM_PARALLELS_MAX_ALLOWED_MOBILE max)" $NOW_RUN_LOG_FILE

  if ($RunMode -match "--silent|--debug") {
    if ($TestType -eq "web") {
        $env:TEAM_PARALLELS_MAX_ALLOWED_WEB = "5"
    }
    else {
        $env:TEAM_PARALLELS_MAX_ALLOWED_MOBILE = "5"
    }
    Log-Line "ℹ️ Resetting Plan summary: Web $WEB_PLAN_FETCHED ($TEAM_PARALLELS_MAX_ALLOWED_WEB max), Mobile $MOBILE_PLAN_FETCHED ($TEAM_PARALLELS_MAX_ALLOWED_MOBILE max)" $NOW_RUN_LOG_FILE
  }

}

# ===== Dynamic config generators =====

function Generate-Web-Platforms {
    param(
        [int]$max_total_parallels,
        [string]$platformsListContentFormat
    )

    $platform = "web"
    $env:NOW_PLATFORM = $platform

    $platformsList = Generate-Platforms `
        -platformName $platform `
        -count $max_total_parallels `
        -platformsListContentFormat $platformsListContentFormat

    return $platformsList
}


function Generate-Mobile-Platforms {
    param(
        [int]$max_total_parallels,
        [string]$platformsListContentFormat
    )

    $app_platform = $env:APP_PLATFORM

    $platformsList = Generate-Platforms `
        -platformName $app_platform `
        -count $max_total_parallels `
        -platformsListContentFormat $platformsListContentFormat

    return $platformsList
}

function Detect-OS {

    $env:NOW_OS = "windows"
}
