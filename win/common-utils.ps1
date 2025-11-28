# ==============================================
# 🛠️ COMMON UTILITIES
# ==============================================

function Ensure-Workspace {
  if (!(Test-Path $GLOBAL_DIR)) {
    New-Item -ItemType Directory -Path $GLOBAL_DIR | Out-Null
    Log-Line "✅ Created Onboarding workspace: $GLOBAL_DIR" $GLOBAL_LOG
  } else {
    Log-Line "ℹ️ Onboarding Workspace already exists: $GLOBAL_DIR" $GLOBAL_LOG
  }
}

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

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "git"
  $psi.Arguments = ($args | ForEach-Object {
    if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ }
  }) -join ' '
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow   = $true
  $psi.WorkingDirectory = (Get-Location).Path

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  [void]$p.Start()
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()

  if ($LogFile) {
    if ($stdout) { Add-Content -Path $LogFile -Value $stdout }
    if ($stderr) { Add-Content -Path $LogFile -Value $stderr }
  }

  if ($p.ExitCode -ne 0) {
    throw "git clone failed (exit $($p.ExitCode)): $stderr"
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

# Run external tools capturing stdout/stderr without throwing on STDERR
function Invoke-External {
  param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter()][string[]]$Arguments = @(),
    [string]$LogFile,
    [string]$WorkingDirectory
  )
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $exeToRun = $Exe
  $argLine  = ($Arguments | ForEach-Object { if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ } }) -join ' '

  # .cmd/.bat need to be invoked via cmd.exe when UseShellExecute=false
  $ext = [System.IO.Path]::GetExtension($Exe)
  if ($ext -and ($ext.ToLowerInvariant() -in @('.cmd','.bat'))) {
    if (-not (Test-Path $Exe)) { throw "Command not found: $Exe" }
    $psi.FileName = "cmd.exe"
    $psi.Arguments = "/c `"$Exe`" $argLine"
  } else {
    $psi.FileName = $exeToRun
    $psi.Arguments = $argLine
  }

  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow   = $true
  if ([string]::IsNullOrWhiteSpace($WorkingDirectory)) {
    $psi.WorkingDirectory = (Get-Location).Path
  } else {
    $psi.WorkingDirectory = $WorkingDirectory
  }

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  
  # Stream output to log file in real-time if LogFile is specified
  if ($LogFile) {
    # Ensure the log file directory exists
    $logDir = Split-Path -Parent $LogFile
    if ($logDir -and !(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
    
    # Create script blocks to handle output streaming
    $stdoutAction = {
      if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
        Add-Content -Path $Event.MessageData -Value $EventArgs.Data
      }
    }
    $stderrAction = {
      if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
        Add-Content -Path $Event.MessageData -Value $EventArgs.Data
      }
    }
    
    # Register events to capture output line by line as it's produced
    $stdoutEvent = Register-ObjectEvent -InputObject $p -EventName OutputDataReceived -Action $stdoutAction -MessageData $LogFile
    $stderrEvent = Register-ObjectEvent -InputObject $p -EventName ErrorDataReceived -Action $stderrAction -MessageData $LogFile
    
    [void]$p.Start()
    $p.BeginOutputReadLine()
    $p.BeginErrorReadLine()
    $p.WaitForExit()
    
    # Clean up event handlers
    Unregister-Event -SourceIdentifier $stdoutEvent.Name
    Unregister-Event -SourceIdentifier $stderrEvent.Name
    Remove-Job -Id $stdoutEvent.Id -Force
    Remove-Job -Id $stderrEvent.Id -Force
  } else {
    # If no log file, just read all output at once (original behavior)
    [void]$p.Start()
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
  }
  
  return $p.ExitCode
}

# Return a Maven executable path or wrapper for a given repo directory
function Get-MavenCommand {
  param([Parameter(Mandatory)][string]$RepoDir)
  $mvnCmd = Get-Command mvn -ErrorAction SilentlyContinue
  if ($mvnCmd) { return $mvnCmd.Source }
  $wrapper = Join-Path $RepoDir "mvnw.cmd"
  if (Test-Path $wrapper) { return $wrapper }
  throw "Maven not found in PATH and 'mvnw.cmd' not present under $RepoDir. Install Maven or ensure the wrapper exists."
}

# Get the python.exe inside a Windows venv
function Get-VenvPython {
  param([Parameter(Mandatory)][string]$VenvDir)
  $py = Join-Path $VenvDir "Scripts\python.exe"
  if (Test-Path $py) { return $py }
  throw "Python interpreter not found in venv: $VenvDir"
}

# Detect a working Python interpreter and set $PY_CMD accordingly
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

# Invoke Python with arguments using the detected interpreter
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

# Check if IP is private
function Test-PrivateIP {
  param([string]$IP)
  # If IP resolution failed (empty), assume it's a public domain
  # BrowserStack Local should only be enabled for confirmed private IPs
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

# Check if domain is private
function Test-DomainPrivate {
  $domain = $CX_TEST_URL -replace '^https?://', '' -replace '/.*$', ''
  Log-Line "Website domain: $domain" $GLOBAL_LOG
  $env:NOW_WEB_DOMAIN = $CX_TEST_URL
  
  # Resolve domain using Resolve-DnsName (more reliable than nslookup)
  $IP_ADDRESS = ""
  try {
    # Try using Resolve-DnsName first (Windows PowerShell 5.1+)
    $dnsResult = Resolve-DnsName -Name $domain -Type A -ErrorAction Stop | Where-Object { $_.Type -eq 'A' } | Select-Object -First 1
    if ($dnsResult) {
      $IP_ADDRESS = $dnsResult.IPAddress
    }
  } catch {
    # Fallback to nslookup if Resolve-DnsName fails
    try {
      $nslookupOutput = nslookup $domain 2>&1 | Out-String
      # Extract IP addresses from nslookup output (match IPv4 pattern)
      if ($nslookupOutput -match '(?:Address|Addresses):\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})') {
        $IP_ADDRESS = $matches[1]
      }
    } catch {
      Log-Line "⚠️ Failed to resolve domain: $domain (assuming public domain)" $GLOBAL_LOG
      $IP_ADDRESS = ""
    }
  }
  
  if ([string]::IsNullOrWhiteSpace($IP_ADDRESS)) {
    Log-Line "⚠️ DNS resolution failed for: $domain (treating as public domain, BrowserStack Local will be DISABLED)" $GLOBAL_LOG
  } else {
    Log-Line "✅ Resolved IP: $IP_ADDRESS" $GLOBAL_LOG
  }
  
  return (Test-PrivateIP -IP $IP_ADDRESS)
}

# ===== Fetch plan details =====
function Fetch-Plan-Details {
  Log-Line "ℹ️ Fetching BrowserStack Plan Details..." $GLOBAL_LOG
  $auth = Get-BasicAuthHeader -User $BROWSERSTACK_USERNAME -Key $BROWSERSTACK_ACCESS_KEY
  $headers = @{ Authorization = $auth }

  if ($TEST_TYPE -in @("Web","Both")) {
    try {
      $resp = Invoke-RestMethod -Method Get -Uri "https://api.browserstack.com/automate/plan.json" -Headers $headers
      $script:WEB_PLAN_FETCHED = $true
      $script:TEAM_PARALLELS_MAX_ALLOWED_WEB = [int]$resp.parallel_sessions_max_allowed
      Log-Line "✅ Web Testing Plan fetched: Team max parallel sessions = $TEAM_PARALLELS_MAX_ALLOWED_WEB" $GLOBAL_LOG
    } catch {
      Log-Line "❌ Web Testing Plan fetch failed ($($_.Exception.Message))" $GLOBAL_LOG
    }
  }
  if ($TEST_TYPE -in @("App","Both")) {
    try {
      $resp2 = Invoke-RestMethod -Method Get -Uri "https://api-cloud.browserstack.com/app-automate/plan.json" -Headers $headers
      $script:MOBILE_PLAN_FETCHED = $true
      $script:TEAM_PARALLELS_MAX_ALLOWED_MOBILE = [int]$resp2.parallel_sessions_max_allowed
      Log-Line "✅ Mobile App Testing Plan fetched: Team max parallel sessions = $TEAM_PARALLELS_MAX_ALLOWED_MOBILE" $GLOBAL_LOG
    } catch {
      Log-Line "❌ Mobile App Testing Plan fetch failed ($($_.Exception.Message))" $GLOBAL_LOG
    }
  }

  if ( ($TEST_TYPE -eq "Web"   -and -not $WEB_PLAN_FETCHED) -or
       ($TEST_TYPE -eq "App"   -and -not $MOBILE_PLAN_FETCHED) -or
       ($TEST_TYPE -eq "Both"  -and -not ($WEB_PLAN_FETCHED -or $MOBILE_PLAN_FETCHED)) ) {
    Log-Line "❌ Unauthorized to fetch required plan(s) or failed request(s). Exiting." $GLOBAL_LOG
    throw "Plan fetch failed"
  }
}
