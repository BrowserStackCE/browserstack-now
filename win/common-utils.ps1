# Common helpers shared by the Windows BrowserStack NOW scripts.

# ===== Global Variables =====
$script:WORKSPACE_DIR = Join-Path $env:USERPROFILE ".browserstack"
$script:PROJECT_FOLDER = "NOW"
$script:NOW_OS = "windows"

$script:GLOBAL_DIR = Join-Path $WORKSPACE_DIR $PROJECT_FOLDER
$script:LOG_DIR     = Join-Path $GLOBAL_DIR "logs"
$script:GLOBAL_LOG  = ""
$script:WEB_LOG     = ""
$script:MOBILE_LOG  = ""

# Script state
$script:BROWSERSTACK_USERNAME = ""
$script:BROWSERSTACK_ACCESS_KEY = ""
$script:TEST_TYPE = ""     # Web / App
$script:TECH_STACK = ""    # Java / Python / JS
[double]$script:PARALLEL_PERCENTAGE = 1.00

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

# ===== Error patterns =====
$script:WEB_SETUP_ERRORS   = @("")
$script:WEB_LOCAL_ERRORS   = @("")
$script:MOBILE_SETUP_ERRORS= @("")
$script:MOBILE_LOCAL_ERRORS= @("")

# ===== Workspace Management =====
function Ensure-Workspace {
  if (!(Test-Path $GLOBAL_DIR)) {
    New-Item -ItemType Directory -Path $GLOBAL_DIR | Out-Null
    Log-Line "✅ Created Onboarding workspace: $GLOBAL_DIR" $GLOBAL_LOG
  } else {
    Log-Line "✅ Onboarding workspace found at: $GLOBAL_DIR" $GLOBAL_LOG
  }
}

function Setup-Workspace {
  Log-Section "⚙️ Environment & Credentials" $GLOBAL_LOG
  Ensure-Workspace
}

function Clear-OldLogs {
  if (!(Test-Path $LOG_DIR)) { 
    New-Item -ItemType Directory -Path $LOG_DIR | Out-Null 
  }

  $legacyLogs = @("global.log","web_run_result.log","mobile_run_result.log")
  foreach ($legacy in $legacyLogs) {
    $legacyPath = Join-Path $LOG_DIR $legacy
    if (Test-Path $legacyPath) {
      Remove-Item -Path $legacyPath -Force -ErrorAction SilentlyContinue
    }
  }

  Log-Line "✅ Logs directory cleaned. Legacy files removed." $GLOBAL_LOG
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

function Reset-BrowserStackConfigFile {
  param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [Parameter(Mandatory)][string]$RelativePath
  )
  $gitDir = Join-Path $RepoRoot ".git"
  if (!(Test-Path $gitDir)) { return }
  $normalized = $RelativePath -replace '\\','/'
  try {
    [void](Invoke-External -Exe "git" -Arguments @("checkout","--",$normalized) -LogFile $GLOBAL_LOG -WorkingDirectory $RepoRoot)
  } catch {
    Log-Line "⚠️ Unable to reset $RelativePath via git checkout ($($_.Exception.Message))" $GLOBAL_LOG
  }
}

function Set-BrowserStackPlatformsSection {
  param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [Parameter(Mandatory)][string]$RelativeConfigPath,
    [Parameter(Mandatory)][string]$PlatformsYaml
  )

  $configPath = Join-Path $RepoRoot $RelativeConfigPath
  if (!(Test-Path $configPath)) {
    throw "browserstack config not found: $configPath"
  }

  Reset-BrowserStackConfigFile -RepoRoot $RepoRoot -RelativePath $RelativeConfigPath

  $normalizedPlatforms = ($PlatformsYaml -replace "`r","").TrimEnd("`n")
  $blockBuilder = New-Object System.Text.StringBuilder
  [void]$blockBuilder.AppendLine("")
  [void]$blockBuilder.AppendLine("platforms:")
  if (-not [string]::IsNullOrWhiteSpace($normalizedPlatforms)) {
    foreach ($line in ($normalizedPlatforms -split "`n")) {
      [void]$blockBuilder.AppendLine($line)
    }
  }

  $appendText = ($blockBuilder.ToString() -replace "`n","`r`n")
  Add-Content -Path $configPath -Value $appendText
  Log-Line "✅ Updated platforms in $RelativeConfigPath" $GLOBAL_LOG
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
    [Parameter()][string[]]$Arguments = @(),
    [string]$LogFile,
    [string]$WorkingDirectory,
    [int]$TimeoutSeconds = 0  # 0 means no timeout
  )
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $exeToRun = $Exe
  $argLine  = ($Arguments | ForEach-Object { if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ } }) -join ' '

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

  if ($LogFile) {
    $logDir = Split-Path -Parent $LogFile
    if ($logDir -and !(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

    # Simplified event handlers - write directly to reduce CPU overhead
    # Batching adds complexity and may not help if output is sparse
    $stdoutAction = {
      if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
        try {
          Add-Content -Path $Event.MessageData -Value $EventArgs.Data -ErrorAction SilentlyContinue
        } catch {
          # Silently ignore write errors to prevent event handler from blocking
        }
      }
    }
    $stderrAction = {
      if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
        try {
          Add-Content -Path $Event.MessageData -Value $EventArgs.Data -ErrorAction SilentlyContinue
        } catch {
          # Silently ignore write errors to prevent event handler from blocking
        }
      }
    }

    $stdoutEvent = Register-ObjectEvent -InputObject $p -EventName OutputDataReceived -Action $stdoutAction -MessageData $LogFile
    $stderrEvent = Register-ObjectEvent -InputObject $p -EventName ErrorDataReceived -Action $stderrAction -MessageData $LogFile

    [void]$p.Start()
    $startTime = Get-Date
    $processId = $p.Id
    
    # Log process start immediately (before BeginOutputReadLine to ensure it's logged)
    $startLogMsg = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Process started: PID=$processId, Command=$exeToRun $argLine"
    if ($LogFile) {
      try {
        Add-Content -Path $LogFile -Value $startLogMsg -ErrorAction Stop
      } catch {
        # If log file write fails, try to log to GLOBAL_LOG
        if ($GLOBAL_LOG) {
          Log-Line "⚠️ Failed to write to log file $LogFile, error: $($_.Exception.Message)" $GLOBAL_LOG
        }
      }
    }
    
    # Also log to GLOBAL_LOG for visibility
    if ($GLOBAL_LOG) {
      Log-Line "ℹ️ External process started: PID=$processId, Command=$exeToRun" $GLOBAL_LOG
    }
    
    # Verify process is actually running and log initial state
    Start-Sleep -Milliseconds 200
    if ($p.HasExited) {
      $exitCode = $p.ExitCode
      $errorMsg = "Process exited immediately with code $exitCode: $exeToRun $argLine"
      if ($LogFile) {
        Add-Content -Path $LogFile -Value "[ERROR] $errorMsg"
      }
      throw $errorMsg
    }
    
    # Log process state verification
    try {
      $procInfo = Get-Process -Id $processId -ErrorAction SilentlyContinue
      if ($procInfo) {
        $procStateMsg = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Process verified running: PID=$processId, CPU=$([math]::Round($procInfo.CPU, 2))s, Memory=$([math]::Round($procInfo.WorkingSet64/1MB, 2))MB"
        if ($LogFile) {
          Add-Content -Path $LogFile -Value $procStateMsg
        }
      }
    } catch {
      # Ignore process info errors
    }
    
    $p.BeginOutputReadLine()
    $p.BeginErrorReadLine()
    
    # Wait with timeout support and periodic status checks
    if ($TimeoutSeconds -gt 0) {
      $checkInterval = 30  # Check every 30 seconds
      $lastOutputTime = Get-Date
      $lastLogCheck = Get-Date
      $lastResourceCheck = Get-Date
      $highCpuCount = 0
      $highCpuThreshold = 90  # Warn if CPU > 90%
      $consecutiveHighCpuLimit = 3  # Warn after 3 consecutive high CPU checks
      
      # Use WaitForExit with timeout, but check periodically for status
      $timeoutMs = $TimeoutSeconds * 1000
      $remainingMs = $timeoutMs
      
      while (-not $p.HasExited -and $remainingMs -gt 0) {
        $checkMs = [Math]::Min($checkInterval * 1000, $remainingMs)
        if (-not $p.WaitForExit($checkMs)) {
          $remainingMs -= $checkMs
          $elapsed = ((Get-Date) - $startTime).TotalSeconds
          
          # Monitor CPU and memory usage every 30 seconds
          if (((Get-Date) - $lastResourceCheck).TotalSeconds -ge 30) {
            try {
              # Get process CPU usage
              $proc = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
              if ($proc) {
                $procCpu = [math]::Round($proc.CPU, 2)
                $procMemoryMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
                
                # Get system CPU usage
                $sysCpu = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples[0].CookedValue
                $sysCpuPercent = [math]::Round($sysCpu, 2)
                
                # Get system memory
                $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
                if ($os) {
                  $usedMemoryGB = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 2)
                  $totalMemoryGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
                  $memoryPercent = [math]::Round(($usedMemoryGB / $totalMemoryGB) * 100, 2)
                  
                  # Log resource usage
                  if ($LogFile) {
                    Add-Content -Path $LogFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Resource check - Process CPU: ${procCpu}s, Process Memory: ${procMemoryMB}MB, System CPU: ${sysCpuPercent}%, System Memory: ${usedMemoryGB}GB/${totalMemoryGB}GB ($memoryPercent%)"
                  }
                  
                  # Warn if CPU is consistently high
                  if ($sysCpuPercent -gt $highCpuThreshold) {
                    $highCpuCount++
                    if ($highCpuCount -ge $consecutiveHighCpuLimit) {
                      $warningMsg = "⚠️ High CPU usage detected: ${sysCpuPercent}% (threshold: ${highCpuThreshold}%). This may cause performance issues or apparent hangs."
                      if ($LogFile) {
                        Add-Content -Path $LogFile -Value "[WARNING] $warningMsg"
                      }
                      Log-Line $warningMsg $GLOBAL_LOG
                      $highCpuCount = 0  # Reset counter after warning
                    }
                  } else {
                    $highCpuCount = 0  # Reset counter if CPU drops
                  }
                  
                  # Warn if memory is high (>85%)
                  if ($memoryPercent -gt 85) {
                    $memWarningMsg = "⚠️ High memory usage detected: ${memoryPercent}%. System may be under memory pressure."
                    if ($LogFile) {
                      Add-Content -Path $LogFile -Value "[WARNING] $memWarningMsg"
                    }
                    Log-Line $memWarningMsg $GLOBAL_LOG
                  }
                }
              }
            } catch {
              # Silently continue if resource monitoring fails
            }
            $lastResourceCheck = Get-Date
          }
          
          # Check if log file has been updated recently (indicates process is producing output)
          $hasOutput = $false
          if ($LogFile -and (Test-Path $LogFile)) {
            $logLastWrite = (Get-Item $LogFile).LastWriteTime
            if ($logLastWrite -gt $lastOutputTime) {
              $lastOutputTime = $logLastWrite
              $hasOutput = $true
            }
            
            # Log status every minute
            if (((Get-Date) - $lastLogCheck).TotalSeconds -ge 60) {
              $statusMsg = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Process still running... Elapsed: $([math]::Round($elapsed, 0))s, Remaining: $([math]::Round($remainingMs/1000, 0))s"
              if (-not $hasOutput -and $elapsed -gt 60) {
                $statusMsg += " [WARNING: No output detected in last 60+ seconds - process may be hung]"
              }
              Add-Content -Path $LogFile -Value $statusMsg
              $lastLogCheck = Get-Date
            }
          }
          
          # Warn if process has been running for 2+ minutes with no output
          if (-not $hasOutput -and $elapsed -ge 120) {
            $noOutputWarning = "⚠️ Process has been running for $([math]::Round($elapsed, 0))s with no output. This may indicate the process is hung."
            if ($LogFile) {
              Add-Content -Path $LogFile -Value "[WARNING] $noOutputWarning"
            }
            if ($GLOBAL_LOG) {
              Log-Line $noOutputWarning $GLOBAL_LOG
            }
            # Reset check to avoid spam
            $lastOutputTime = Get-Date
          }
        } else {
          break  # Process exited
        }
      }
      
      # Check if we timed out
      if (-not $p.HasExited) {
        # Log final resource state before timeout
        try {
          $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
          if ($os) {
            $usedMemoryGB = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 2)
            $totalMemoryGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
            $memoryPercent = [math]::Round(($usedMemoryGB / $totalMemoryGB) * 100, 2)
            $sysCpu = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples[0].CookedValue
            $sysCpuPercent = [math]::Round($sysCpu, 2)
            
            if ($LogFile) {
              Add-Content -Path $LogFile -Value "[TIMEOUT] Final resource state - System CPU: ${sysCpuPercent}%, System Memory: ${usedMemoryGB}GB/${totalMemoryGB}GB ($memoryPercent%)"
            }
            
            # Check if high CPU might have contributed to timeout
            if ($sysCpuPercent -gt $highCpuThreshold) {
              $cpuWarning = "⚠️ High CPU usage (${sysCpuPercent}%) detected at timeout. This may have contributed to the timeout."
              if ($LogFile) {
                Add-Content -Path $LogFile -Value "[TIMEOUT] $cpuWarning"
              }
              Log-Line $cpuWarning $GLOBAL_LOG
            }
          }
        } catch {
          # Ignore resource check errors during timeout
        }
        
        $errorMsg = "Command timed out after $TimeoutSeconds seconds: $exeToRun $argLine"
        Add-Content -Path $LogFile -Value "[TIMEOUT] $errorMsg"
        Log-Line "❌ $errorMsg" $GLOBAL_LOG
        try {
          if (-not $p.HasExited) {
            $p.Kill()
            Start-Sleep -Milliseconds 500
            if (-not $p.HasExited) {
              Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
            }
          }
        } catch {
          Log-Line "⚠️ Error killing timed-out process: $($_.Exception.Message)" $GLOBAL_LOG
        }
        Unregister-Event -SourceIdentifier $stdoutEvent.Name -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier $stderrEvent.Name -ErrorAction SilentlyContinue
        Remove-Job -Id $stdoutEvent.Id -Force -ErrorAction SilentlyContinue
        Remove-Job -Id $stderrEvent.Id -Force -ErrorAction SilentlyContinue
        throw $errorMsg
      }
    } else {
      $p.WaitForExit()
    }
    
    # Log process completion with final resource state
    if ($LogFile) {
      $endTime = Get-Date
      $duration = ($endTime - $startTime).TotalSeconds
      
      # Log final resource state
      try {
        $proc = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
        $procCpu = if ($proc) { [math]::Round($proc.CPU, 2) } else { "N/A" }
        $procMemoryMB = if ($proc) { [math]::Round($proc.WorkingSet64 / 1MB, 2) } else { "N/A" }
        
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
          $usedMemoryGB = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 2)
          $totalMemoryGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
          $memoryPercent = [math]::Round(($usedMemoryGB / $totalMemoryGB) * 100, 2)
          $sysCpu = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples[0].CookedValue
          $sysCpuPercent = [math]::Round($sysCpu, 2)
          
          Add-Content -Path $LogFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Process completed: ExitCode=$($p.ExitCode), Duration=$([math]::Round($duration, 2))s"
          Add-Content -Path $LogFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Final resources - Process CPU: ${procCpu}s, Process Memory: ${procMemoryMB}MB, System CPU: ${sysCpuPercent}%, System Memory: ${usedMemoryGB}GB/${totalMemoryGB}GB ($memoryPercent%)"
        } else {
          Add-Content -Path $LogFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Process completed: ExitCode=$($p.ExitCode), Duration=$([math]::Round($duration, 2))s"
        }
      } catch {
        Add-Content -Path $LogFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Process completed: ExitCode=$($p.ExitCode), Duration=$([math]::Round($duration, 2))s"
      }
    }

    Unregister-Event -SourceIdentifier $stdoutEvent.Name -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier $stderrEvent.Name -ErrorAction SilentlyContinue
    Remove-Job -Id $stdoutEvent.Id -Force -ErrorAction SilentlyContinue
    Remove-Job -Id $stderrEvent.Id -Force -ErrorAction SilentlyContinue
  } else {
    [void]$p.Start()
    
    if ($TimeoutSeconds -gt 0) {
      if (-not $p.WaitForExit($TimeoutSeconds * 1000)) {
        $p.Kill()
        throw "Command timed out after $TimeoutSeconds seconds: $exeToRun $argLine"
      }
      $stdout = $p.StandardOutput.ReadToEnd()
      $stderr = $p.StandardError.ReadToEnd()
    } else {
      $stdout = $p.StandardOutput.ReadToEnd()
      $stderr = $p.StandardError.ReadToEnd()
      $p.WaitForExit()
    }
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
  
  # Skip spinner in silent mode
  if (Get-SilentMode) {
    $Process.WaitForExit()
    return
  }
  
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
  Log-Line "Website domain: $domain" $GLOBAL_LOG
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

function Get-BasicAuthHeader {
  param([string]$User, [string]$Key)
  $pair = "{0}:{1}" -f $User,$Key
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
  "Basic {0}" -f [System.Convert]::ToBase64String($bytes)
}

# ===== Fetch plan details =====
function Fetch-Plan-Details {
  param([string]$TestType)
  
  if ([string]::IsNullOrWhiteSpace($TestType)) {
    throw "Test type is required to fetch plan details."
  }

  $normalized = $TestType.ToLowerInvariant()
  Log-Line "ℹ️ Fetching BrowserStack plan for $normalized" $GLOBAL_LOG

  $auth = Get-BasicAuthHeader -User $BROWSERSTACK_USERNAME -Key $BROWSERSTACK_ACCESS_KEY
  $headers = @{ Authorization = $auth }

  switch ($normalized) {
    "web" {
      try {
        $resp = Invoke-RestMethod -Method Get -Uri "https://api.browserstack.com/automate/plan.json" -Headers $headers
        $script:WEB_PLAN_FETCHED = $true
        $script:TEAM_PARALLELS_MAX_ALLOWED_WEB = [int]$resp.parallel_sessions_max_allowed
        Log-Line "✅ Web Testing Plan fetched: Team max parallel sessions = $TEAM_PARALLELS_MAX_ALLOWED_WEB" $GLOBAL_LOG
      } catch {
        Log-Line "❌ Web Testing Plan fetch failed ($($_.Exception.Message))" $GLOBAL_LOG
      }
      if (-not $WEB_PLAN_FETCHED) {
        throw "Unable to fetch Web Testing plan details."
      }
    }
    "app" {
      try {
        $resp2 = Invoke-RestMethod -Method Get -Uri "https://api-cloud.browserstack.com/app-automate/plan.json" -Headers $headers
        $script:MOBILE_PLAN_FETCHED = $true
        $script:TEAM_PARALLELS_MAX_ALLOWED_MOBILE = [int]$resp2.parallel_sessions_max_allowed
        Log-Line "✅ Mobile App Testing Plan fetched: Team max parallel sessions = $TEAM_PARALLELS_MAX_ALLOWED_MOBILE" $GLOBAL_LOG
      } catch {
        Log-Line "❌ Mobile App Testing Plan fetch failed ($($_.Exception.Message))" $GLOBAL_LOG
      }
      if (-not $MOBILE_PLAN_FETCHED) {
        throw "Unable to fetch Mobile App Testing plan details."
      }
    }
    default {
      throw "Unsupported TEST_TYPE: $TestType. Allowed values: Web, App."
    }
  }

  Log-Line "ℹ️ Plan summary: Web fetched=$WEB_PLAN_FETCHED (team max=$TEAM_PARALLELS_MAX_ALLOWED_WEB), Mobile fetched=$MOBILE_PLAN_FETCHED (team max=$TEAM_PARALLELS_MAX_ALLOWED_MOBILE)" $GLOBAL_LOG
}


