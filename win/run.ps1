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

# ===== Example Platform Templates =====
$WEB_PLATFORM_TEMPLATES = @(
  "Windows|10|Chrome",
  "Windows|10|Firefox",
  "Windows|11|Edge",
  "Windows|11|Chrome",
  "Windows|8|Chrome",
  "OS X|Monterey|Chrome",
  "OS X|Ventura|Chrome",
  "OS X|Catalina|Firefox"
)

# Mobile tiers (kept for parity)
$MOBILE_TIER1 = @(
  "ios|iPhone 15|17",
  "ios|iPhone 15 Pro|17",
  "ios|iPhone 16|18",
  "android|Samsung Galaxy S25|15",
  "android|Samsung Galaxy S24|14"
)
$MOBILE_TIER2 = @(
  "ios|iPhone 14 Pro|16",
  "ios|iPhone 14|16",
  "ios|iPad Air 13 2025|18",
  "android|Samsung Galaxy S23|13",
  "android|Samsung Galaxy S22|12",
  "android|Samsung Galaxy S21|11",
  "android|Samsung Galaxy Tab S10 Plus|15"
)
$MOBILE_TIER3 = @(
  "ios|iPhone 13 Pro Max|15",
  "ios|iPhone 13|15",
  "ios|iPhone 12 Pro|14",
  "ios|iPhone 12 Pro|17",
  "ios|iPhone 12|17",
  "ios|iPhone 12|14",
  "ios|iPhone 12 Pro Max|16",
  "ios|iPhone 13 Pro|15",
  "ios|iPhone 13 Mini|15",
  "ios|iPhone 16 Pro|18",
  "ios|iPad 9th|15",
  "ios|iPad Pro 12.9 2020|14",
  "ios|iPad Pro 12.9 2020|16",
  "ios|iPad 8th|16",
  "android|Samsung Galaxy S22 Ultra|12",
  "android|Samsung Galaxy S21|12",
  "android|Samsung Galaxy S21 Ultra|11",
  "android|Samsung Galaxy S20|10",
  "android|Samsung Galaxy M32|11",
  "android|Samsung Galaxy Note 20|10",
  "android|Samsung Galaxy S10|9",
  "android|Samsung Galaxy Note 9|8",
  "android|Samsung Galaxy Tab S8|12",
  "android|Google Pixel 9|15",
  "android|Google Pixel 6 Pro|13",
  "android|Google Pixel 8|14",
  "android|Google Pixel 7|13",
  "android|Google Pixel 6|12",
  "android|Vivo Y21|11",
  "android|Vivo Y50|10",
  "android|Oppo Reno 6|11"
)
$MOBILE_TIER4 = @(
  "ios|iPhone 15 Pro Max|17",
  "ios|iPhone 15 Pro Max|26",
  "ios|iPhone 15|26",
  "ios|iPhone 15 Plus|17",
  "ios|iPhone 14 Pro|26",
  "ios|iPhone 14|18",
  "ios|iPhone 14|26",
  "ios|iPhone 13 Pro Max|18",
  "ios|iPhone 13|16",
  "ios|iPhone 13|17",
  "ios|iPhone 13|18",
  "ios|iPhone 12 Pro|18",
  "ios|iPhone 14 Pro Max|16",
  "ios|iPhone 14 Plus|16",
  "ios|iPhone 11|13",
  "ios|iPhone 8|11",
  "ios|iPhone 7|10",
  "ios|iPhone 17 Pro Max|26",
  "ios|iPhone 17 Pro|26",
  "ios|iPhone 17 Air|26",
  "ios|iPhone 17|26",
  "ios|iPhone 16e|18",
  "ios|iPhone 16 Pro Max|18",
  "ios|iPhone 16 Plus|18",
  "ios|iPhone SE 2020|16",
  "ios|iPhone SE 2022|15",
  "ios|iPad Air 4|14",
  "ios|iPad 9th|18",
  "ios|iPad Air 5|26",
  "ios|iPad Pro 11 2021|18",
  "ios|iPad Pro 13 2024|17",
  "ios|iPad Pro 12.9 2021|14",
  "ios|iPad Pro 12.9 2021|17",
  "ios|iPad Pro 11 2024|17",
  "ios|iPad Air 6|17",
  "ios|iPad Pro 12.9 2022|16",
  "ios|iPad Pro 11 2022|16",
  "ios|iPad 10th|16",
  "ios|iPad Air 13 2025|26",
  "ios|iPad Pro 11 2020|13",
  "ios|iPad Pro 11 2020|16",
  "ios|iPad 8th|14",
  "ios|iPad Mini 2021|15",
  "ios|iPad Pro 12.9 2018|12",
  "ios|iPad 6th|11",
  "android|Samsung Galaxy S23 Ultra|13",
  "android|Samsung Galaxy S22 Plus|12",
  "android|Samsung Galaxy S21 Plus|11",
  "android|Samsung Galaxy S20 Ultra|10",
  "android|Samsung Galaxy S25 Ultra|15",
  "android|Samsung Galaxy S24 Ultra|14",
  "android|Samsung Galaxy M52|11",
  "android|Samsung Galaxy A52|11",
  "android|Samsung Galaxy A51|10",
  "android|Samsung Galaxy A11|10",
  "android|Samsung Galaxy A10|9",
  "android|Samsung Galaxy Tab A9 Plus|14",
  "android|Samsung Galaxy Tab S9|13",
  "android|Samsung Galaxy Tab S7|10",
  "android|Samsung Galaxy Tab S7|11",
  "android|Samsung Galaxy Tab S6|9",
  "android|Google Pixel 9|16",
  "android|Google Pixel 10 Pro XL|16",
  "android|Google Pixel 10 Pro|16",
  "android|Google Pixel 10|16",
  "android|Google Pixel 9 Pro XL|15",
  "android|Google Pixel 9 Pro|15",
  "android|Google Pixel 6 Pro|12",
  "android|Google Pixel 6 Pro|15",
  "android|Google Pixel 8 Pro|14",
  "android|Google Pixel 7 Pro|13",
  "android|Google Pixel 5|11",
  "android|OnePlus 13R|15",
  "android|OnePlus 12R|14",
  "android|OnePlus 11R|13",
  "android|OnePlus 9|11",
  "android|OnePlus 8|10",
  "android|Motorola Moto G71 5G|11",
  "android|Motorola Moto G9 Play|10",
  "android|Vivo V21|11",
  "android|Oppo A96|11",
  "android|Oppo Reno 3 Pro|10",
  "android|Xiaomi Redmi Note 11|11",
  "android|Xiaomi Redmi Note 9|10",
  "android|Huawei P30|9"
)

# MOBILE_ALL combines the tiers
$MOBILE_ALL = @()
$MOBILE_ALL += $MOBILE_TIER1
$MOBILE_ALL += $MOBILE_TIER2
$MOBILE_ALL += $MOBILE_TIER3
$MOBILE_ALL += $MOBILE_TIER4

# ===== Helpers =====
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
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    Add-Content -Path $DestFile -Value $line
  }
}

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

# Spinner function for long-running operations
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

# ===== GUI helpers =====
function Show-InputBox {
  param(
    [string]$Title = "Input",
    [string]$Prompt = "Enter value:",
    [string]$DefaultText = ""
  )
  $form = New-Object System.Windows.Forms.Form
  $form.Text = $Title
  $form.Size = New-Object System.Drawing.Size(500,220)
  $form.StartPosition = "CenterScreen"

  $label = New-Object System.Windows.Forms.Label
  $label.Text = $Prompt
  $label.MaximumSize = New-Object System.Drawing.Size(460,0)
  $label.AutoSize = $true
  $label.Location = New-Object System.Drawing.Point(10,20)
  $form.Controls.Add($label)

  $textBox = New-Object System.Windows.Forms.TextBox
  $textBox.Size = New-Object System.Drawing.Size(460,20)
  $textBox.Location = New-Object System.Drawing.Point(10,($label.Bottom + 10))
  $textBox.Text = $DefaultText
  $form.Controls.Add($textBox)

  $okButton = New-Object System.Windows.Forms.Button
  $okButton.Text = "OK"
  $okButton.Location = New-Object System.Drawing.Point(380,($textBox.Bottom + 20))
  $okButton.Add_Click({ $form.Tag = $textBox.Text; $form.Close() })
  $form.Controls.Add($okButton)

  $form.AcceptButton = $okButton
  [void]$form.ShowDialog()
  return [string]$form.Tag
}

function Show-PasswordBox {
  param(
    [string]$Title = "Secret",
    [string]$Prompt = "Enter secret:"
  )
  $form = New-Object System.Windows.Forms.Form
  $form.Text = $Title
  $form.Size = New-Object System.Drawing.Size(500,220)
  $form.StartPosition = "CenterScreen"

  $label = New-Object System.Windows.Forms.Label
  $label.Text = $Prompt
  $label.MaximumSize = New-Object System.Drawing.Size(460,0)
  $label.AutoSize = $true
  $label.Location = New-Object System.Drawing.Point(10,20)
  $form.Controls.Add($label)

  $textBox = New-Object System.Windows.Forms.TextBox
  $textBox.Size = New-Object System.Drawing.Size(460,20)
  $textBox.Location = New-Object System.Drawing.Point(10,($label.Bottom + 10))
  $textBox.UseSystemPasswordChar = $true
  $form.Controls.Add($textBox)

  $okButton = New-Object System.Windows.Forms.Button
  $okButton.Text = "OK"
  $okButton.Location = New-Object System.Drawing.Point(380,($textBox.Bottom + 20))
  $okButton.Add_Click({ $form.Tag = $textBox.Text; $form.Close() })
  $form.Controls.Add($okButton)

  $form.AcceptButton = $okButton
  [void]$form.ShowDialog()
  return [string]$form.Tag
}

function Show-ChoiceBox {
  param(
    [string]$Title = "Choose",
    [string]$Prompt = "Select one:",
    [string[]]$Choices,
    [string]$DefaultChoice
  )
  $form = New-Object System.Windows.Forms.Form
  $form.Text = $Title
  $form.Size = New-Object System.Drawing.Size(420, 240)
  $form.StartPosition = "CenterScreen"

  $label = New-Object System.Windows.Forms.Label
  $label.Text = $Prompt
  $label.AutoSize = $true
  $label.Location = New-Object System.Drawing.Point(10, 10)
  $form.Controls.Add($label)

  $group = New-Object System.Windows.Forms.Panel
  $group.Location = New-Object System.Drawing.Point(10, 35)
  $group.Width  = 380
  $startY  = 10
  $spacing = 28

  $radios = @()
  [int]$i = 0
  foreach ($c in $Choices) {
    $rb = New-Object System.Windows.Forms.RadioButton
    $rb.Text = $c
    $rb.AutoSize = $true
    $rb.Location = New-Object System.Drawing.Point(10, ($startY + $i * $spacing))
    if ($c -eq $DefaultChoice) { $rb.Checked = $true }
    $group.Controls.Add($rb)
    $radios += $rb
    $i++
  }
  $group.Height = [Math]::Max(120, $startY + ($Choices.Count * $spacing) + 10)
  $form.Controls.Add($group)

  $ok = New-Object System.Windows.Forms.Button
  $ok.Text = "OK"
  $ok.Location = New-Object System.Drawing.Point(300, ($group.Bottom + 10))
  $ok.Add_Click({
    foreach ($rb in $radios) { if ($rb.Checked) { $form.Tag = $rb.Text; break } }
    $form.Close()
  })
  $form.Controls.Add($ok)

  $form.Height = $ok.Bottom + 70
  $form.AcceptButton = $ok
  [void]$form.ShowDialog()
  return [string]$form.Tag
}

# === NEW: Big clickable button chooser ===
function Show-ClickChoice {
  param(
    [string]$Title = "Choose",
    [string]$Prompt = "Select one:",
    [string[]]$Choices,
    [string]$DefaultChoice
  )
  if (-not $Choices -or $Choices.Count -eq 0) { return "" }

  $form = New-Object System.Windows.Forms.Form
  $form.Text = $Title
  $form.StartPosition = "CenterScreen"
  $form.MinimizeBox = $false
  $form.MaximizeBox = $false
  $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
  $form.BackColor = [System.Drawing.Color]::FromArgb(245,245,245)

  $label = New-Object System.Windows.Forms.Label
  $label.Text = $Prompt
  $label.AutoSize = $true
  $label.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
  $label.Location = New-Object System.Drawing.Point(12, 12)
  $form.Controls.Add($label)

  $panel = New-Object System.Windows.Forms.FlowLayoutPanel
  $panel.Location = New-Object System.Drawing.Point(12, 40)
  $panel.Size = New-Object System.Drawing.Size(460, 140)
  $panel.WrapContents = $true
  $panel.AutoScroll = $true
  $panel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
  $form.Controls.Add($panel)

  $selected = $null
  foreach ($c in $Choices) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $c
    $btn.Width = 140
    $btn.Height = 40
    $btn.Margin = '8,8,8,8'
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btn.FlatStyle = 'System'
    if ($c -eq $DefaultChoice) {
      $btn.BackColor = [System.Drawing.Color]::FromArgb(232,240,254)
    }
    $btn.Add_Click({
      $script:selected = $this.Text
      $form.Tag = $script:selected
      $form.Close()
    })
    $panel.Controls.Add($btn)
  }

  $cancel = New-Object System.Windows.Forms.Button
  $cancel.Text = "Cancel"
  $cancel.Width = 90
  $cancel.Height = 32
  $cancel.Location = New-Object System.Drawing.Point(382, 188)
  $cancel.Add_Click({ $form.Tag = ""; $form.Close() })
  $form.Controls.Add($cancel)
  $form.CancelButton = $cancel

  $form.ClientSize = New-Object System.Drawing.Size(484, 230)
  [void]$form.ShowDialog()
  return [string]$form.Tag
}

function Show-OpenFileDialog {
  param(
    [string]$Title = "Select File",
    [string]$Filter = "All files (*.*)|*.*"
  )
  $ofd = New-Object System.Windows.Forms.OpenFileDialog
  $ofd.Title = $Title
  $ofd.Filter = $Filter
  $ofd.Multiselect = $false
  if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    return $ofd.FileName
  }
  return ""
}

# ===== Baseline interactions =====
function Ask-BrowserStack-Credentials {
  $script:BROWSERSTACK_USERNAME = Show-InputBox -Title "BrowserStack Setup" -Prompt "Enter your BrowserStack Username:`n`nNote: Locate it in your BrowserStack account page`nhttps://www.browserstack.com/accounts/profile/details" -DefaultText ""
  if ([string]::IsNullOrWhiteSpace($script:BROWSERSTACK_USERNAME)) {
    Log-Line "❌ Username empty" $GLOBAL_LOG
    throw "Username is required"
  }
  $script:BROWSERSTACK_ACCESS_KEY = Show-PasswordBox -Title "BrowserStack Setup" -Prompt "Enter your BrowserStack Access Key:`n`nNote: Locate it in your BrowserStack account page`nhttps://www.browserstack.com/accounts/profile/details"
  if ([string]::IsNullOrWhiteSpace($script:BROWSERSTACK_ACCESS_KEY)) {
    Log-Line "❌ Access Key empty" $GLOBAL_LOG
    throw "Access Key is required"
  }
  Log-Line "✅ BrowserStack credentials captured (access key hidden)" $GLOBAL_LOG
}

# === UPDATED: click-select for Web/App/Both ===
function Ask-Test-Type {
  $choice = Show-ClickChoice -Title "Testing Type" `
                             -Prompt "What do you want to run?" `
                             -Choices @("Web","App","Both") `
                             -DefaultChoice "Web"
  if ([string]::IsNullOrWhiteSpace($choice)) { throw "No testing type selected" }
  $script:TEST_TYPE = $choice
  Log-Line "✅ Selected Testing Type: $script:TEST_TYPE" $GLOBAL_LOG

  switch ($script:TEST_TYPE) {
    "Web"   { Ask-User-TestUrl }
    "App"   { Ask-And-Upload-App }
    "Both"  { Ask-User-TestUrl; Ask-And-Upload-App }
  }
}

# === UPDATED: click-select for Tech Stack ===
function Ask-Tech-Stack {
  $choice = Show-ClickChoice -Title "Tech Stack" `
                             -Prompt "Select your installed language / framework:" `
                             -Choices @("Java","Python","NodeJS") `
                             -DefaultChoice "Java"
  if ([string]::IsNullOrWhiteSpace($choice)) { throw "No tech stack selected" }
  $script:TECH_STACK = $choice
  Log-Line "✅ Selected Tech Stack: $script:TECH_STACK" $GLOBAL_LOG
}

function Validate-Tech-Stack {
  Log-Line "ℹ️ Checking prerequisites for $script:TECH_STACK" $GLOBAL_LOG
  switch ($script:TECH_STACK) {
    "Java" {
      Log-Line "🔍 Checking if 'java' command exists..." $GLOBAL_LOG
      if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
        Log-Line "❌ Java command not found in PATH." $GLOBAL_LOG
        throw "Java not found"
      }
      Log-Line "🔍 Checking if Java runs correctly..." $GLOBAL_LOG
      $verInfo = & cmd /c 'java -version 2>&1'
      if (-not $verInfo) {
        Log-Line "❌ Java exists but failed to run." $GLOBAL_LOG
        throw "Java invocation failed"
      }
      Log-Line "✅ Java is installed. Version details:" $GLOBAL_LOG
      ($verInfo -split "`r?`n") | ForEach-Object { if ($_ -ne "") { Log-Line "  $_" $GLOBAL_LOG } }
    }
    "Python" {
      Log-Line "🔍 Checking if 'python3' command exists..." $GLOBAL_LOG
      try {
        Set-PythonCmd
        Log-Line "🔍 Checking if Python3 runs correctly..." $GLOBAL_LOG
        $code = Invoke-Py -Arguments @("--version") -LogFile $null -WorkingDirectory (Get-Location).Path
        if ($code -eq 0) {
          Log-Line ("✅ Python3 is installed: {0}" -f ( ($PY_CMD -join ' ') )) $GLOBAL_LOG
        } else {
          throw "Python present but failed to execute"
        }
      } catch {
        Log-Line "❌ Python3 exists but failed to run." $GLOBAL_LOG
        throw
      }
    }

    "NodeJS" {
      Log-Line "🔍 Checking if 'node' command exists..." $GLOBAL_LOG
      if (-not (Get-Command node -ErrorAction SilentlyContinue)) { 
        Log-Line "❌ Node.js command not found in PATH." $GLOBAL_LOG
        throw "Node not found" 
      }
      Log-Line "🔍 Checking if 'npm' command exists..." $GLOBAL_LOG
      if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { 
        Log-Line "❌ npm command not found in PATH." $GLOBAL_LOG
        throw "npm not found" 
      }
      Log-Line "🔍 Checking if Node.js runs correctly..." $GLOBAL_LOG
      $nodeVer = & node -v 2>&1
      if (-not $nodeVer) {
        Log-Line "❌ Node.js exists but failed to run." $GLOBAL_LOG
        throw "Node.js invocation failed"
      }
      Log-Line "🔍 Checking if npm runs correctly..." $GLOBAL_LOG
      $npmVer = & npm -v 2>&1
      if (-not $npmVer) {
        Log-Line "❌ npm exists but failed to run." $GLOBAL_LOG
        throw "npm invocation failed"
      }
      Log-Line "✅ Node.js is installed: $nodeVer" $GLOBAL_LOG
      Log-Line "✅ npm is installed: $npmVer" $GLOBAL_LOG
    }
    default { Log-Line "❌ Unknown tech stack selected: $script:TECH_STACK" $GLOBAL_LOG; throw "Unknown tech stack" }
  }
  Log-Line "✅ Prerequisites validated for $script:TECH_STACK" $GLOBAL_LOG
}
# fix Python branch without ternary
function Get-PythonCmd {
  if (Get-Command python3 -ErrorAction SilentlyContinue) { return "python3" }
  return "python"
}

function Ask-User-TestUrl {
  $u = Show-InputBox -Title "Test URL Setup" -Prompt "Enter the URL you want to test with BrowserStack:`n(Leave blank for default: $DEFAULT_TEST_URL)" -DefaultText ""
  if ([string]::IsNullOrWhiteSpace($u)) {
    $script:CX_TEST_URL = $DEFAULT_TEST_URL
    Log-Line "⚠️ No URL entered. Falling back to default: $script:CX_TEST_URL" $GLOBAL_LOG
  } else {
    $script:CX_TEST_URL = $u
    Log-Line "🌐 Using custom test URL: $script:CX_TEST_URL" $GLOBAL_LOG
  }
}

function Get-BasicAuthHeader {
  param([string]$User, [string]$Key)
  $pair = "{0}:{1}" -f $User,$Key
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
  "Basic {0}" -f [System.Convert]::ToBase64String($bytes)
}

function Ask-And-Upload-App {
  # First, show a choice screen for Sample App vs Browse
  $appChoice = Show-ClickChoice -Title "App Selection" `
                                -Prompt "Choose an app to test:" `
                                -Choices @("Sample App","Browse") `
                                -DefaultChoice "Sample App"
  
  if ([string]::IsNullOrWhiteSpace($appChoice) -or $appChoice -eq "Sample App") {
    Log-Line "⚠️ Using default sample app: bs://sample.app" $GLOBAL_LOG
    $script:APP_URL = "bs://sample.app"
    $script:APP_PLATFORM = "all"
    return
  }
  
  # User chose "Browse", so open file picker
  $path = Show-OpenFileDialog -Title "📱 Select your .apk or .ipa file" -Filter "App Files (*.apk;*.ipa)|*.apk;*.ipa|All files (*.*)|*.*"
  if ([string]::IsNullOrWhiteSpace($path)) {
    Log-Line "⚠️ No app selected. Using default sample app: bs://sample.app" $GLOBAL_LOG
    $script:APP_URL = "bs://sample.app"
    $script:APP_PLATFORM = "all"
    return
  }
  
  $ext = [System.IO.Path]::GetExtension($path).ToLowerInvariant()
  switch ($ext) {
    ".apk" { $script:APP_PLATFORM = "android" }
    ".ipa" { $script:APP_PLATFORM = "ios" }
    default { Log-Line "❌ Unsupported file type. Only .apk or .ipa allowed." $GLOBAL_LOG; throw "Unsupported app file" }
  }

  Log-Line "⬆️ Uploading $path to BrowserStack..." $GLOBAL_LOG
  
  # Create multipart form data manually for PowerShell 5.1 compatibility
  $boundary = [System.Guid]::NewGuid().ToString()
  $LF = "`r`n"
  $fileBin = [System.IO.File]::ReadAllBytes($path)
  $fileName = [System.IO.Path]::GetFileName($path)
  
  $bodyLines = (
    "--$boundary",
    "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`"",
    "Content-Type: application/octet-stream$LF",
    [System.Text.Encoding]::GetEncoding("iso-8859-1").GetString($fileBin),
    "--$boundary--$LF"
  ) -join $LF
  
  $headers = @{
    Authorization = (Get-BasicAuthHeader -User $BROWSERSTACK_USERNAME -Key $BROWSERSTACK_ACCESS_KEY)
    "Content-Type" = "multipart/form-data; boundary=$boundary"
  }
  
  $resp = Invoke-RestMethod -Method Post -Uri "https://api-cloud.browserstack.com/app-automate/upload" -Headers $headers -Body $bodyLines
  $url = $resp.app_url
  if ([string]::IsNullOrWhiteSpace($url)) {
    Log-Line "❌ Upload failed. Response: $(ConvertTo-Json $resp -Depth 5)" $GLOBAL_LOG
    throw "Upload failed"
  }
  $script:APP_URL = $url
  Log-Line "✅ App uploaded successfully: $script:APP_URL" $GLOBAL_LOG
}

# ===== Generators =====
function Generate-Web-Platforms-Yaml {
  param([int]$MaxTotalParallels)
  $max = [Math]::Floor($MaxTotalParallels * $PARALLEL_PERCENTAGE)
  if ($max -lt 0) { $max = 0 }
  $sb = New-Object System.Text.StringBuilder
  $count = 0

  foreach ($t in $WEB_PLATFORM_TEMPLATES) {
    $parts = $t.Split('|')
    $os = $parts[0]; $osVersion = $parts[1]; $browserName = $parts[2]
    foreach ($version in @('latest','latest-1','latest-2')) {
      [void]$sb.AppendLine("  - os: $os")
      [void]$sb.AppendLine("    osVersion: $osVersion")
      [void]$sb.AppendLine("    browserName: $browserName")
      [void]$sb.AppendLine("    browserVersion: $version")
      $count++
      if ($count -ge $max -and $max -gt 0) {
        return $sb.ToString()
      }
    }
  }
  return $sb.ToString()
}

function Generate-Mobile-Platforms-Yaml {
  param([int]$MaxTotalParallels)
  $max = [Math]::Floor($MaxTotalParallels * $PARALLEL_PERCENTAGE)
  if ($max -lt 1) { $max = 1 }
  $sb = New-Object System.Text.StringBuilder
  $count = 0

  foreach ($t in $MOBILE_ALL) {
    $parts = $t.Split('|')
    $platformName  = $parts[0]
    $deviceName    = $parts[1]
    $platformVer   = $parts[2]

    if (-not [string]::IsNullOrWhiteSpace($APP_PLATFORM)) {
      if ($APP_PLATFORM -eq 'ios' -and $platformName -ne 'ios') { continue }
      if ($APP_PLATFORM -eq 'android' -and $platformName -ne 'android') { continue }
    }

    [void]$sb.AppendLine("  - platformName: $platformName")
    [void]$sb.AppendLine("    deviceName: $deviceName")
    [void]$sb.AppendLine("    platformVersion: '${platformVer}.0'")
    $count++
    if ($count -ge $max) { return $sb.ToString() }
  }
  return $sb.ToString()
}

function Generate-Mobile-Caps-Json {
  param([int]$MaxTotalParallels, [string]$OutputFile)
  $max = $MaxTotalParallels
  if ($max -lt 1) { $max = 1 }
  
  $items = @()
  $count = 0
  
  foreach ($t in $MOBILE_ALL) {
    $parts = $t.Split('|')
    $platformName = $parts[0]
    $deviceName   = $parts[1]
    $platformVer  = $parts[2]
    
    # Filter based on APP_PLATFORM
    if (-not [string]::IsNullOrWhiteSpace($APP_PLATFORM)) {
      if ($APP_PLATFORM -eq 'ios' -and $platformName -ne 'ios') { continue }
      if ($APP_PLATFORM -eq 'android' -and $platformName -ne 'android') { continue }
      # If APP_PLATFORM is 'all', include both ios and android (no filtering)
    }
    
    $items += [pscustomobject]@{
      'bstack:options' = @{
        deviceName = $deviceName
        osVersion  = "${platformVer}.0"
      }
    }
    $count++
    if ($count -ge $max) { break }
  }
  
  # Convert to JSON
  $json = ($items | ConvertTo-Json -Depth 5)
  
  # Write to file
  Set-ContentNoBom -Path $OutputFile -Value $json
  
  return $json
}

function Generate-Web-Caps-Json {
  param([int]$MaxTotalParallels)
  $max = [Math]::Floor($MaxTotalParallels * $PARALLEL_PERCENTAGE)
  if ($max -lt 1) { $max = 1 }
  
  $items = @()
  $count = 0
  foreach ($t in $WEB_PLATFORM_TEMPLATES) {
    $parts = $t.Split('|')
    $os = $parts[0]; $osVersion = $parts[1]; $browserName = $parts[2]
    foreach ($version in @('latest','latest-1','latest-2')) {
      $items += [pscustomobject]@{
        browserName   = $browserName
        browserVersion= $version
        'bstack:options' = @{
          os        = $os
          osVersion = $osVersion
        }
      }
      $count++
      if ($count -ge $max) { break }
    }
    if ($count -ge $max) { break }
  }
  
  # Convert to JSON and remove outer brackets to match macOS behavior
  # The test code adds brackets: JSON.parse("[" + process.env.BSTACK_CAPS_JSON + "]")
  $json = ($items | ConvertTo-Json -Depth 5)
  
  # Remove leading [ and trailing ]
  if ($json.StartsWith('[')) {
    $json = $json.Substring(1)
  }
  if ($json.EndsWith(']')) {
    $json = $json.Substring(0, $json.Length - 1)
  }
  
  # Trim any leading/trailing whitespace
  $json = $json.Trim()
  
  return $json
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

# ===== Setup: Web (Java) =====
function Setup-Web-Java {
  param([bool]$UseLocal, [int]$ParallelsPerPlatform, [string]$LogFile)

  $REPO = "now-testng-browserstack"
  $TARGET = Join-Path $GLOBAL_DIR $REPO

  New-Item -ItemType Directory -Path $GLOBAL_DIR -Force | Out-Null
  if (Test-Path $TARGET) {
    Remove-Item -Path $TARGET -Recurse -Force
  }

  Log-Line "📦 Cloning repo $REPO into $TARGET" $GLOBAL_LOG
  Invoke-GitClone -Url "https://github.com/BrowserStackCE/$REPO.git" -Target $TARGET -LogFile $WEB_LOG

  Push-Location $TARGET
  try {
    # Check if domain is private
    if (Test-DomainPrivate) {
      $UseLocal = $true
    }

    # Log local flag status
    if ($UseLocal) {
      Log-Line "✅ BrowserStack Local is ENABLED for this run." $GLOBAL_LOG
    } else {
      Log-Line "✅ BrowserStack Local is DISABLED for this run." $GLOBAL_LOG
    }

    # Generate YAML config in the correct location
    Log-Line "🧩 Generating YAML config (browserstack.yml)" $GLOBAL_LOG
    $platforms = Generate-Web-Platforms-Yaml -MaxTotalParallels $TEAM_PARALLELS_MAX_ALLOWED_WEB
    $localFlag = if ($UseLocal) { "true" } else { "false" }

    $yamlContent = @"
userName: $BROWSERSTACK_USERNAME
accessKey: $BROWSERSTACK_ACCESS_KEY
framework: testng
browserstackLocal: $localFlag
buildName: now-testng-java-web
projectName: NOW-Web-Test
percy: true
accessibility: true
platforms:
$platforms
parallelsPerPlatform: $ParallelsPerPlatform
"@

    Set-Content "browserstack.yml" -Value $yamlContent
    Log-Line "✅ Created browserstack.yml in root directory" $GLOBAL_LOG

    $mvn = Get-MavenCommand -RepoDir $TARGET
    Log-Line "⚙️ Running '$mvn compile'" $GLOBAL_LOG
    [void](Invoke-External -Exe $mvn -Arguments @("compile") -LogFile $LogFile -WorkingDirectory $TARGET)

    Log-Line "🚀 Running '$mvn test -P sample-test'. This could take a few minutes. Follow the Automation build here: https://automation.browserstack.com/" $GLOBAL_LOG
    [void](Invoke-External -Exe $mvn -Arguments @("test","-P","sample-test") -LogFile $LogFile -WorkingDirectory $TARGET)

  } finally {
    Pop-Location
    Set-Location (Join-Path $WORKSPACE_DIR $PROJECT_FOLDER)
  }
}

# ===== Setup: Web (Python) =====
function Setup-Web-Python {
  param([bool]$UseLocal, [int]$ParallelsPerPlatform, [string]$LogFile)

  $REPO = "now-pytest-browserstack"
  $TARGET = Join-Path $GLOBAL_DIR $REPO

  New-Item -ItemType Directory -Path $GLOBAL_DIR -Force | Out-Null
  if (Test-Path $TARGET) {
    Remove-Item -Path $TARGET -Recurse -Force
  }

  Invoke-GitClone -Url "https://github.com/BrowserStackCE/$REPO.git" -Target $TARGET -LogFile $WEB_LOG
  Log-Line "✅ Cloned repository: $REPO into $TARGET" $GLOBAL_LOG

  Push-Location $TARGET
  try {
    if (-not $PY_CMD -or $PY_CMD.Count -eq 0) { Set-PythonCmd }
    $venv = Join-Path $TARGET "venv"
    if (!(Test-Path $venv)) {
      [void](Invoke-Py -Arguments @("-m","venv",$venv) -LogFile $LogFile -WorkingDirectory $TARGET)
      Log-Line "✅ Created Python virtual environment" $GLOBAL_LOG
    }
    $venvPy = Get-VenvPython -VenvDir $venv
    [void](Invoke-External -Exe $venvPy -Arguments @("-m","pip","install","-r","requirements.txt") -LogFile $LogFile -WorkingDirectory $TARGET)
    # Ensure SDK can find pytest on PATH
    $env:PATH = (Join-Path $venv 'Scripts') + ";" + $env:PATH

    $env:BROWSERSTACK_USERNAME = $BROWSERSTACK_USERNAME
    $env:BROWSERSTACK_ACCESS_KEY = $BROWSERSTACK_ACCESS_KEY

    # Check if domain is private
    if (Test-DomainPrivate) {
      $UseLocal = $true
    }

    # Log local flag status
    if ($UseLocal) {
      Log-Line "✅ BrowserStack Local is ENABLED for this run." $GLOBAL_LOG
    } else {
      Log-Line "✅ BrowserStack Local is DISABLED for this run." $GLOBAL_LOG
    }

    $env:BROWSERSTACK_CONFIG_FILE = "browserstack.yml"
    $platforms = Generate-Web-Platforms-Yaml -MaxTotalParallels $TEAM_PARALLELS_MAX_ALLOWED_WEB
    $localFlag = if ($UseLocal) { "true" } else { "false" }

@"
userName: $BROWSERSTACK_USERNAME
accessKey: $BROWSERSTACK_ACCESS_KEY
framework: pytest
browserstackLocal: $localFlag
buildName: browserstack-sample-python-web
projectName: NOW-Web-Test
percy: true
accessibility: true
platforms:
$platforms
parallelsPerPlatform: $ParallelsPerPlatform
"@ | Set-Content "browserstack.yml"

    Log-Line "✅ Updated root-level browserstack.yml with platforms and credentials" $GLOBAL_LOG

    $sdk = Join-Path $venv "Scripts\browserstack-sdk.exe"
    Log-Line "🚀 Running 'browserstack-sdk pytest -s tests/bstack-sample-test.py'. This could take a few minutes. Follow the Automation build here: https://automation.browserstack.com/" $GLOBAL_LOG
    [void](Invoke-External -Exe $sdk -Arguments @('pytest','-s','tests/bstack-sample-test.py') -LogFile $LogFile -WorkingDirectory $TARGET)

  } finally {
    Pop-Location
    Set-Location (Join-Path $WORKSPACE_DIR $PROJECT_FOLDER)
  }
}

# ===== Setup: Web (NodeJS) =====
function Setup-Web-NodeJS {
  param([bool]$UseLocal, [int]$ParallelsPerPlatform, [string]$LogFile)

  $REPO = "now-webdriverio-browserstack"
  $TARGET = Join-Path $GLOBAL_DIR $REPO

  if (Test-Path $TARGET) {
    Remove-Item -Path $TARGET -Recurse -Force
  }

  New-Item -ItemType Directory -Path $GLOBAL_DIR -Force | Out-Null

  Log-Line "📦 Cloning repo $REPO into $TARGET" $GLOBAL_LOG
  Invoke-GitClone -Url "https://github.com/BrowserStackCE/$REPO.git" -Target $TARGET -LogFile $WEB_LOG

  Push-Location $TARGET
  try {
    Log-Line "⚙️ Running 'npm install'" $GLOBAL_LOG
    [void](Invoke-External -Exe "cmd.exe" -Arguments @("/c","npm","install") -LogFile $LogFile -WorkingDirectory $TARGET)

    # Generate capabilities JSON
    Log-Line "🧩 Generating browser/OS capabilities" $GLOBAL_LOG
    $caps = Generate-Web-Caps-Json -MaxTotalParallels $ParallelsPerPlatform
    
    $env:BSTACK_PARALLELS = $ParallelsPerPlatform
    $env:BSTACK_CAPS_JSON = $caps

    # Check if domain is private
    if (Test-DomainPrivate) {
      $UseLocal = $true
    }

    # Log local flag status
    if ($UseLocal) {
      Log-Line "✅ BrowserStack Local is ENABLED for this run." $GLOBAL_LOG
    } else {
      Log-Line "✅ BrowserStack Local is DISABLED for this run." $GLOBAL_LOG
    }

    $env:BROWSERSTACK_USERNAME = $BROWSERSTACK_USERNAME
    $env:BROWSERSTACK_ACCESS_KEY = $BROWSERSTACK_ACCESS_KEY
    $localFlagStr = if ($UseLocal) { "true" } else { "false" }
    $env:BROWSERSTACK_LOCAL = $localFlagStr
    $env:BSTACK_PARALLELS = $ParallelsPerPlatform

    Log-Line "🚀 Running 'npm run test'" $GLOBAL_LOG
    [void](Invoke-External -Exe "cmd.exe" -Arguments @("/c","npm","run","test") -LogFile $LogFile -WorkingDirectory $TARGET)

    Log-Line "✅ Web NodeJS setup and test execution completed successfully." $GLOBAL_LOG

  } finally {
    Pop-Location
    Set-Location (Join-Path $WORKSPACE_DIR $PROJECT_FOLDER)
  }
}

# ===== Setup: Mobile (Python) =====
function Setup-Mobile-Python {
  param([bool]$UseLocal, [int]$ParallelsPerPlatform, [string]$LogFile)

  $REPO = "pytest-appium-app-browserstack"
  $TARGET = Join-Path $GLOBAL_DIR $REPO

  New-Item -ItemType Directory -Path $GLOBAL_DIR -Force | Out-Null
  if (Test-Path $TARGET) {
    Remove-Item -Path $TARGET -Recurse -Force
  }

  Invoke-GitClone -Url "https://github.com/browserstack/$REPO.git" -Target $TARGET -LogFile $MOBILE_LOG
  Log-Line "✅ Cloned repository: $REPO into $TARGET" $GLOBAL_LOG

  Push-Location $TARGET
  try {
    if (-not $PY_CMD -or $PY_CMD.Count -eq 0) { Set-PythonCmd }
    $venv = Join-Path $TARGET "venv"
    if (!(Test-Path $venv)) {
      [void](Invoke-Py -Arguments @("-m","venv",$venv) -LogFile $LogFile -WorkingDirectory $TARGET)
    }
    $venvPy = Get-VenvPython -VenvDir $venv
    [void](Invoke-External -Exe $venvPy -Arguments @("-m","pip","install","-r","requirements.txt") -LogFile $LogFile -WorkingDirectory $TARGET)
    # Ensure SDK can find pytest on PATH
    $env:PATH = (Join-Path $venv 'Scripts') + ";" + $env:PATH

    $env:BROWSERSTACK_USERNAME = $BROWSERSTACK_USERNAME
    $env:BROWSERSTACK_ACCESS_KEY = $BROWSERSTACK_ACCESS_KEY

    # Prepare platform-specific YAMLs in android/ and ios/
    $originalPlatform = $APP_PLATFORM

    $script:APP_PLATFORM = "android"
    $platformYamlAndroid = Generate-Mobile-Platforms-Yaml -MaxTotalParallels $TEAM_PARALLELS_MAX_ALLOWED_MOBILE
    $localFlag = if ($UseLocal) { "true" } else { "false" }
    $androidYmlPath = Join-Path $TARGET "android\browserstack.yml"
@"
userName: $BROWSERSTACK_USERNAME
accessKey: $BROWSERSTACK_ACCESS_KEY
framework: pytest
browserstackLocal: $localFlag
buildName: browserstack-build-mobile
projectName: NOW-Mobile-Test
parallelsPerPlatform: $ParallelsPerPlatform
app: $APP_URL
platforms:
$platformYamlAndroid
"@ | Set-Content $androidYmlPath

    $script:APP_PLATFORM = "ios"
    $platformYamlIos = Generate-Mobile-Platforms-Yaml -MaxTotalParallels $TEAM_PARALLELS_MAX_ALLOWED_MOBILE
    $iosYmlPath = Join-Path $TARGET "ios\browserstack.yml"
@"
userName: $BROWSERSTACK_USERNAME
accessKey: $BROWSERSTACK_ACCESS_KEY
framework: pytest
browserstackLocal: $localFlag
buildName: browserstack-build-mobile
projectName: NOW-Mobile-Test
parallelsPerPlatform: $ParallelsPerPlatform
app: $APP_URL
platforms:
$platformYamlIos
"@ | Set-Content $iosYmlPath

    $script:APP_PLATFORM = $originalPlatform

    Log-Line "✅ Wrote platform YAMLs to android/browserstack.yml and ios/browserstack.yml" $GLOBAL_LOG

    # Replace sample tests in both android and ios with universal, locator-free test
    $testContent = @"
import pytest


@pytest.mark.usefixtures('setWebdriver')
class TestUniversalAppCheck:

    def test_app_health_check(self):

        # 1. Get initial app and device state (no locators)
        initial_package = self.driver.current_package
        initial_activity = self.driver.current_activity
        initial_orientation = self.driver.orientation

        # 2. Log the captured data to BrowserStack using 'annotate'
        log_data = f"Initial State: Package='{initial_package}', Activity='{initial_activity}', Orientation='{initial_orientation}'"
        self.driver.execute_script(
            'browserstack_executor: {"action": "annotate", "arguments": {"data": "' + log_data + '", "level": "info"}}'
        )

        # 3. Perform a locator-free action: change device orientation
        self.driver.orientation = 'LANDSCAPE'

        # 4. Perform locator-free assertions
        assert self.driver.orientation == 'LANDSCAPE'

        # 5. Log the successful state change
        self.driver.execute_script(
            'browserstack_executor: {"action": "annotate", "arguments": {"data": "Successfully changed orientation to LANDSCAPE", "level": "info"}}'
        )
        
        # 6. Set the final session status to 'passed'
        self.driver.execute_script(
            'browserstack_executor: {"action": "setSessionStatus", "arguments": {"status": "passed", "reason": "App state verified and orientation changed!"}}'
        )
"@
    $androidTestPath = Join-Path $TARGET "android\bstack_sample.py"
    $iosTestPath = Join-Path $TARGET "ios\bstack_sample.py"
    Set-ContentNoBom -Path $androidTestPath -Value $testContent
    Set-ContentNoBom -Path $iosTestPath -Value $testContent

    # Decide which directory to run based on APP_PLATFORM (default to android)
    $runDirName = "android"
    if ($APP_PLATFORM -eq "ios") {
      $runDirName = "ios"
    }
    $runDir = Join-Path $TARGET $runDirName

    # Check if domain is private
    if (Test-DomainPrivate) {
      $UseLocal = $true
    }

    # Log local flag status
    if ($UseLocal) {
      Log-Line "⚠️ BrowserStack Local is ENABLED for this run." $GLOBAL_LOG
    } else {
      Log-Line "⚠️ BrowserStack Local is DISABLED for this run." $GLOBAL_LOG
    }

    Log-Line "🚀 Running 'cd $runDirName && browserstack-sdk pytest -s bstack_sample.py'" $GLOBAL_LOG
    $sdk = Join-Path $venv "Scripts\browserstack-sdk.exe"
    Push-Location $runDir
    try {
      [void](Invoke-External -Exe $sdk -Arguments @('pytest','-s','bstack_sample.py') -LogFile $LogFile -WorkingDirectory (Get-Location).Path)
    } finally {
      Pop-Location
    }

  } finally {
    Pop-Location
    Set-Location (Join-Path $WORKSPACE_DIR $PROJECT_FOLDER)
  }
}

# ===== Setup: Mobile (Java) =====
function Setup-Mobile-Java {
  param([bool]$UseLocal, [int]$ParallelsPerPlatform, [string]$LogFile)

  $REPO = "now-testng-appium-app-browserstack"
  $TARGET = Join-Path $GLOBAL_DIR $REPO

  New-Item -ItemType Directory -Path $GLOBAL_DIR -Force | Out-Null
  if (Test-Path $TARGET) {
    Remove-Item -Path $TARGET -Recurse -Force
  }

  Invoke-GitClone -Url "https://github.com/BrowserStackCE/$REPO.git" -Target $TARGET -LogFile $MOBILE_LOG
  Log-Line "✅ Cloned repository: $REPO into $TARGET" $GLOBAL_LOG

  Push-Location $TARGET
  try {
    # Navigate to platform-specific directory
    if ($APP_PLATFORM -eq "all" -or $APP_PLATFORM -eq "android") {
      Set-Location "android\testng-examples"
    } else {
      Set-Location "ios\testng-examples"
    }
    
    $env:BROWSERSTACK_USERNAME = $BROWSERSTACK_USERNAME
    $env:BROWSERSTACK_ACCESS_KEY = $BROWSERSTACK_ACCESS_KEY

    # YAML config path
    $env:BROWSERSTACK_CONFIG_FILE = ".\browserstack.yml"
    $platforms = Generate-Mobile-Platforms-Yaml -MaxTotalParallels $TEAM_PARALLELS_MAX_ALLOWED_MOBILE
    $localFlag = if ($UseLocal) { "true" } else { "false" }

    # Append to existing YAML (repo has base config)
    $yamlAppend = @"
app: $APP_URL
platforms:
$platforms
"@
    Add-Content -Path $env:BROWSERSTACK_CONFIG_FILE -Value $yamlAppend

    # Check if domain is private
    if (Test-DomainPrivate) {
      $UseLocal = $true
    }

    # Log local flag status
    if ($UseLocal) {
      Log-Line "✅ BrowserStack Local is ENABLED for this run." $GLOBAL_LOG
    } else {
      Log-Line "✅ BrowserStack Local is DISABLED for this run." $GLOBAL_LOG
    }

    $mvn = Get-MavenCommand -RepoDir (Get-Location).Path
    Log-Line "⚙️ Running '$mvn clean'" $GLOBAL_LOG
    $cleanExit = Invoke-External -Exe $mvn -Arguments @("clean") -LogFile $LogFile -WorkingDirectory (Get-Location).Path
    if ($cleanExit -ne 0) {
      Log-Line "❌ 'mvn clean' FAILED. See $LogFile for details." $GLOBAL_LOG
      throw "Maven clean failed"
    }

    Log-Line "🚀 Running '$mvn test -P sample-test'. This could take a few minutes. Follow the Automation build here: https://automation.browserstack.com/" $GLOBAL_LOG
    [void](Invoke-External -Exe $mvn -Arguments @("test","-P","sample-test") -LogFile $LogFile -WorkingDirectory (Get-Location).Path)

  } finally {
    Pop-Location
    Set-Location (Join-Path $WORKSPACE_DIR $PROJECT_FOLDER)
  }
}

# ===== Setup: Mobile (NodeJS) =====
function Setup-Mobile-NodeJS {
  param([bool]$UseLocal, [int]$ParallelsPerPlatform, [string]$LogFile)

  Set-Location (Join-Path $WORKSPACE_DIR $PROJECT_FOLDER)

  $REPO = "now-webdriverio-appium-app-browserstack"
  $TARGET = Join-Path $GLOBAL_DIR $REPO

  New-Item -ItemType Directory -Path $GLOBAL_DIR -Force | Out-Null
  if (Test-Path $TARGET) {
    Remove-Item -Path $TARGET -Recurse -Force
  }

  Invoke-GitClone -Url "https://github.com/BrowserStackCE/$REPO.git" -Target $TARGET -LogFile $MOBILE_LOG

  $testDir = Join-Path $TARGET "test"
  Push-Location $testDir
  try {
    Log-Line "⚙️ Running 'npm install'" $GLOBAL_LOG
    [void](Invoke-External -Exe "cmd.exe" -Arguments @("/c","npm","install") -LogFile $LogFile -WorkingDirectory $testDir)

    # Generate mobile capabilities JSON file
    Log-Line "🧩 Generating mobile capabilities JSON" $GLOBAL_LOG
    $usageFile = Join-Path $GLOBAL_DIR "usage_file.json"
    [void](Generate-Mobile-Caps-Json -MaxTotalParallels $ParallelsPerPlatform -OutputFile $usageFile)
    Log-Line "✅ Created usage_file.json at: $usageFile" $GLOBAL_LOG

    $env:BROWSERSTACK_USERNAME = $BROWSERSTACK_USERNAME
    $env:BROWSERSTACK_ACCESS_KEY = $BROWSERSTACK_ACCESS_KEY
    $env:BSTACK_PARALLELS = $ParallelsPerPlatform

    Log-Line "🚀 Running 'npm run test'" $GLOBAL_LOG
    [void](Invoke-External -Exe "cmd.exe" -Arguments @("/c","npm","run","test") -LogFile $LogFile -WorkingDirectory $testDir)

  } finally {
    Pop-Location
    Set-Location (Join-Path $WORKSPACE_DIR $PROJECT_FOLDER)
  }
}

# ===== Wrappers with retry =====
function Setup-Web {
  Log-Line "Starting Web setup for $TECH_STACK" $WEB_LOG
  Log-Line "🌐 ========================================" $GLOBAL_LOG
  Log-Line "🌐 Starting WEB Testing ($TECH_STACK)" $GLOBAL_LOG
  Log-Line "🌐 ========================================" $GLOBAL_LOG

  $localFlag = $false
  $attempt = 1
  $success = $true

  $totalParallels = [int]([Math]::Floor($TEAM_PARALLELS_MAX_ALLOWED_WEB * $PARALLEL_PERCENTAGE))
  if ($totalParallels -lt 1) { $totalParallels = 1 }
  $parallelsPerPlatform = $totalParallels

  while ($attempt -le 1) {
    Log-Line "[Web Setup]" $WEB_LOG
    switch ($TECH_STACK) {
      "Java"   { 
        Setup-Web-Java -UseLocal:$localFlag -ParallelsPerPlatform $parallelsPerPlatform -LogFile $WEB_LOG 
        # Add a small delay to ensure all output is flushed to disk
        Start-Sleep -Milliseconds 500
        if (Test-Path $WEB_LOG) {
          $content = Get-Content $WEB_LOG -Raw
          if ($content -match "BUILD FAILURE") {
            $success = $false
          }
        }
      }
      "Python" { 
        Setup-Web-Python -UseLocal:$localFlag -ParallelsPerPlatform $parallelsPerPlatform -LogFile $WEB_LOG 
        # Add a small delay to ensure all output is flushed to disk
        Start-Sleep -Milliseconds 500
        if (Test-Path $WEB_LOG) {
          $content = Get-Content $WEB_LOG -Raw
          if ($content -match "BUILD FAILURE") {
            $success = $false
          }
        }
      }
      "NodeJS" { 
        Setup-Web-NodeJS -UseLocal:$localFlag -ParallelsPerPlatform $parallelsPerPlatform -LogFile $WEB_LOG 
        # Add a small delay to ensure all output is flushed to disk
        Start-Sleep -Milliseconds 500
        if (Test-Path $WEB_LOG) {
          $content = Get-Content $WEB_LOG -Raw
          if ($content -match "([1-9][0-9]*) passed, 0 failed") {
            $success = $false
          }
        }
      }
      default  { Log-Line "Unknown TECH_STACK: $TECH_STACK" $WEB_LOG; return }
    }

    if ($success) {
      Log-Line "✅ Web setup succeeded." $WEB_LOG
      Log-Line "✅ WEB Testing completed successfully" $GLOBAL_LOG
      Log-Line "📊 View detailed web test logs: $WEB_LOG" $GLOBAL_LOG
      break
    } else {
      Log-Line "❌ Web setup ended without success; check $WEB_LOG for details" $WEB_LOG
      Log-Line "❌ WEB Testing completed with errors" $GLOBAL_LOG
      Log-Line "📊 View detailed web test logs: $WEB_LOG" $GLOBAL_LOG
      break
    }
  }
}


function Setup-Mobile {
  Log-Line "Starting Mobile setup for $TECH_STACK" $MOBILE_LOG
  Log-Line "📱 ========================================" $GLOBAL_LOG
  Log-Line "📱 Starting MOBILE APP Testing ($TECH_STACK)" $GLOBAL_LOG
  Log-Line "📱 ========================================" $GLOBAL_LOG

  $localFlag = $true
  $attempt = 1
  $success = $false

  $totalParallels = [int]([Math]::Floor($TEAM_PARALLELS_MAX_ALLOWED_MOBILE * $PARALLEL_PERCENTAGE))
  if ($totalParallels -lt 1) { $totalParallels = 1 }
  $parallelsPerPlatform = $totalParallels

  while ($attempt -le 1) {
    Log-Line "[Mobile Setup Attempt $attempt] browserstackLocal: $localFlag" $MOBILE_LOG
    switch ($TECH_STACK) {
      "Java"   { Setup-Mobile-Java -UseLocal:$localFlag -ParallelsPerPlatform $parallelsPerPlatform -LogFile $MOBILE_LOG }
      "Python" { Setup-Mobile-Python -UseLocal:$localFlag -ParallelsPerPlatform $parallelsPerPlatform -LogFile $MOBILE_LOG }
      "NodeJS" { Setup-Mobile-NodeJS -UseLocal:$localFlag -ParallelsPerPlatform $parallelsPerPlatform -LogFile $MOBILE_LOG }
      default  { Log-Line "Unknown TECH_STACK: $TECH_STACK" $MOBILE_LOG; return }
    }

    # Add a small delay to ensure all output is flushed to disk (especially important for Java)
    Start-Sleep -Milliseconds 500
    
    if (!(Test-Path $MOBILE_LOG)) {
      $content = ""
    } else {
      $content = Get-Content $MOBILE_LOG -Raw
    }

    $LOCAL_FAILURE = $false
    $SETUP_FAILURE = $false

    foreach ($p in $MOBILE_LOCAL_ERRORS) { if ($p -and ($content -match $p)) { $LOCAL_FAILURE = $true; break } }
    foreach ($p in $MOBILE_SETUP_ERRORS) { if ($p -and ($content -match $p)) { $SETUP_FAILURE = $true; break } }

    # Check for BrowserStack link (success indicator)
    if ($content -match 'https://[a-zA-Z0-9./?=_-]*browserstack\.com') { 
      $success = $true 
    }

    if ($success) {
      Log-Line "✅ Mobile setup succeeded" $MOBILE_LOG
      Log-Line "✅ MOBILE APP Testing completed successfully" $GLOBAL_LOG
      Log-Line "📊 View detailed mobile test logs: $MOBILE_LOG" $GLOBAL_LOG
      break
    } elseif ($LOCAL_FAILURE -and $attempt -eq 1) {
      $localFlag = $false
      $attempt++
      Log-Line "⚠️ Mobile test failed due to Local tunnel error. Retrying without browserstackLocal..." $MOBILE_LOG
      Log-Line "⚠️ Mobile test failed due to Local tunnel error. Retrying without browserstackLocal..." $GLOBAL_LOG
    } elseif ($SETUP_FAILURE) {
      Log-Line "❌ Mobile test failed due to setup error. Check logs at: $MOBILE_LOG" $MOBILE_LOG
      Log-Line "❌ MOBILE APP Testing failed due to setup error" $GLOBAL_LOG
      Log-Line "📊 View detailed mobile test logs: $MOBILE_LOG" $GLOBAL_LOG
      break
    } else {
      Log-Line "❌ Mobile setup ended without success; check $MOBILE_LOG for details" $MOBILE_LOG
      Log-Line "❌ MOBILE APP Testing completed with errors" $GLOBAL_LOG
      Log-Line "📊 View detailed mobile test logs: $MOBILE_LOG" $GLOBAL_LOG
      break
    }
  }
}


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
  $proxyCheckScript = Join-Path $PSScriptRoot "proxy-check.ps1"
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