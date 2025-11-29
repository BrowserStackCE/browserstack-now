# Environment Setup and Run functions for Windows BrowserStack NOW.
# Mirrors the Mac env-setup-run.sh structure.

# ===== Setup: Web (Java) =====
function Setup-Web-Java {
  param([bool]$UseLocal, [int]$ParallelsPerPlatform, [string]$LogFile)

  $REPO = "now-testng-browserstack"
  $TARGET = Join-Path $GLOBAL_DIR $REPO

  New-Item -ItemType Directory -Path $GLOBAL_DIR -Force | Out-Null
  if (Test-Path $TARGET) {
    Remove-Item -Path $TARGET -Recurse -Force
  }

  Log-Line "ℹ️ Cloning repository: $REPO" $NOW_RUN_LOG_FILE
  Invoke-GitClone -Url "https://github.com/BrowserStackCE/$REPO.git" -Target $TARGET -LogFile $NOW_RUN_LOG_FILE

  Push-Location $TARGET
  try {
    Log-Line "ℹ️ Target website: $CX_TEST_URL" $NOW_RUN_LOG_FILE
    
    if (Test-DomainPrivate) {
      $UseLocal = $true
    }

    Report-BStackLocalStatus -LocalFlag $UseLocal

    Log-Line "🧩 Generating YAML config (browserstack.yml)" $NOW_RUN_LOG_FILE
    $platforms = Generate-Web-Platforms -max_total_parallels $TEAM_PARALLELS_MAX_ALLOWED_WEB -platformsListContentFormat "yaml"
    $localFlag = if ($UseLocal) { "true" } else { "false" }

    $yamlContent = @"
platforms:
$platforms
"@

    $env:BSTACK_PARALLELS = $ParallelsPerPlatform
    $env:BSTACK_PLATFORMS=$platforms
    $env:BROWSERSTACK_LOCAL=$localFlag
    $env:BROWSERSTACK_BUILD_NAME="now-$env:NOW_OS-$TEST_TYPE-$TechStack-testng"
    $env:BROWSERSTACK_PROJECT_NAME="now-$env:NOW_OS-$TEST_TYPE"

    Add-Content "browserstack.yml" -Value $yamlContent
    Log-Line "✅ Created browserstack.yml in root directory" $NOW_RUN_LOG_FILE

    # Validate Environment Variables
    Log-Section "Validate Environment Variables" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Username: $BROWSERSTACK_USERNAME" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Project: $env:BROWSERSTACK_PROJECT_NAME" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Build: $env:BROWSERSTACK_BUILD_NAME" $NOW_RUN_LOG_FILE

    Log-Line "ℹ️ Web Application Endpoint: $CX_TEST_URL" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Local Flag: $localFlag" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ Parallels per platform: $ParallelsPerPlatform" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ Platforms:" $NOW_RUN_LOG_FILE
    $platforms -split "`n" | ForEach-Object { if ($_.Trim()) { Log-Line "  $_" $NOW_RUN_LOG_FILE } }

    $mvn = Get-MavenCommand -RepoDir $TARGET
    Log-Line "⚙️ Running '$mvn install -DskipTests'" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ Installing dependencies" $NOW_RUN_LOG_FILE
    [void](Invoke-External -Exe $mvn -Arguments @("install","-DskipTests") -LogFile $LogFile -WorkingDirectory $TARGET)
    Log-Line "✅ Dependencies installed" $NOW_RUN_LOG_FILE

    Print-TestsRunningSection -Command "mvn test -P sample-test"
    [void](Invoke-External -Exe $mvn -Arguments @("test","-P","sample-test") -LogFile $LogFile -WorkingDirectory $TARGET)
    Log-Line "ℹ️ Run Test command completed." $NOW_RUN_LOG_FILE

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

  Log-Line "ℹ️ Cloning repository: $REPO" $NOW_RUN_LOG_FILE
  Invoke-GitClone -Url "https://github.com/BrowserStackCE/$REPO.git" -Target $TARGET -LogFile $NOW_RUN_LOG_FILE

  Push-Location $TARGET
  try {
    if (-not $PY_CMD -or $PY_CMD.Count -eq 0) { Set-PythonCmd }
    $venv = Join-Path $TARGET "venv"
    if (!(Test-Path $venv)) {
      [void](Invoke-Py -Arguments @("-m","venv",$venv) -LogFile $LogFile -WorkingDirectory $TARGET)
    }
    $venvPy = Get-VenvPython -VenvDir $venv
    
    Log-Line "ℹ️ Installing dependencies" $NOW_RUN_LOG_FILE
    [void](Invoke-External -Exe $venvPy -Arguments @("-m","pip","install","-r","requirements.txt") -LogFile $LogFile -WorkingDirectory $TARGET)
    Log-Line "✅ Dependencies installed" $NOW_RUN_LOG_FILE
    
    $env:PATH = (Join-Path $venv 'Scripts') + ";" + $env:PATH
    $env:BROWSERSTACK_USERNAME = $BROWSERSTACK_USERNAME
    $env:BROWSERSTACK_ACCESS_KEY = $BROWSERSTACK_ACCESS_KEY

    if (Test-DomainPrivate) {
      $UseLocal = $true
    }

    Report-BStackLocalStatus -LocalFlag $UseLocal

    $env:BROWSERSTACK_CONFIG_FILE = "browserstack.yml"
    $platforms = Generate-Web-Platforms -max_total_parallels $TEAM_PARALLELS_MAX_ALLOWED_WEB -platformsListContentFormat "yaml"
    $localFlag = if ($UseLocal) { "true" } else { "false" }

    $yamlContent = @"
platforms:
$platforms
"@

    Add-Content "browserstack.yml" -Value $yamlContent

    $env:BSTACK_PARALLELS = $ParallelsPerPlatform
    $env:BSTACK_PLATFORMS=$platforms
    $env:BROWSERSTACK_LOCAL=$localFlag
    $env:BROWSERSTACK_BUILD_NAME="now-$env:NOW_OS-$TEST_TYPE-$TechStack-pytest"
    $env:BROWSERSTACK_PROJECT_NAME="now-$env:NOW_OS-$TEST_TYPE"

    Log-Line "✅ Updated browserstack.yml with platforms and credentials" $NOW_RUN_LOG_FILE

    # Validate Environment Variables
    Log-Section "Validate Environment Variables" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Username: $env:BROWSERSTACK_USERNAME" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Project: $env:BROWSERSTACK_PROJECT_NAME" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Build: $env:BROWSERSTACK_BUILD_NAME" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ Web Application Endpoint: $env:CX_TEST_URL" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Local Flag: $env:BROWSERSTACK_LOCAL" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ Parallels per platform: $env:BSTACK_PARALLELS" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ Platforms:" $NOW_RUN_LOG_FILE
    $platforms -split "`n" | ForEach-Object { if ($_.Trim()) { Log-Line "  $_" $NOW_RUN_LOG_FILE } }

    $sdk = Join-Path $venv "Scripts\browserstack-sdk.exe"
    Print-TestsRunningSection -Command "browserstack-sdk pytest -s tests/bstack-sample-test.py"
    [void](Invoke-External -Exe $sdk -Arguments @('pytest','-s','tests/bstack-sample-test.py') -LogFile $LogFile -WorkingDirectory $TARGET)
    Log-Line "ℹ️ Run Test command completed." $NOW_RUN_LOG_FILE

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

  Log-Line "ℹ️ Cloning repository: $REPO" $NOW_RUN_LOG_FILE
  Invoke-GitClone -Url "https://github.com/BrowserStackCE/$REPO.git" -Target $TARGET -LogFile $NOW_RUN_LOG_FILE

  Push-Location $TARGET
  try {
    Log-Line "⚙️ Running 'npm install'" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ Installing dependencies" $NOW_RUN_LOG_FILE
    [void](Invoke-External -Exe "cmd.exe" -Arguments @("/c","npm","install") -LogFile $LogFile -WorkingDirectory $TARGET)
    Log-Line "✅ Dependencies installed" $NOW_RUN_LOG_FILE

    $caps = Generate-Web-Platforms -max_total_parallels $TEAM_PARALLELS_MAX_ALLOWED_WEB -platformsListContentFormat "json"
    $env:BSTACK_PARALLELS = $ParallelsPerPlatform
    $env:BSTACK_CAPS_JSON = $caps

    if (Test-DomainPrivate) {
      $UseLocal = $true
    }

    Report-BStackLocalStatus -LocalFlag $UseLocal

    $env:BROWSERSTACK_USERNAME = $BROWSERSTACK_USERNAME
    $env:BROWSERSTACK_ACCESS_KEY = $BROWSERSTACK_ACCESS_KEY
    $localFlagStr = if ($UseLocal) { "true" } else { "false" }
    $env:BROWSERSTACK_LOCAL = $localFlagStr
    $env:BROWSERSTACK_BUILD_NAME = "now-$env:NOW_OS-$TEST_TYPE-$TechStack-wdio"
    $env:BROWSERSTACK_PROJECT_NAME = "now-$env:NOW_OS-$TEST_TYPE"

    # Validate Environment Variables
    Log-Section "Validate Environment Variables" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Username: $BROWSERSTACK_USERNAME" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Build: $($env:BROWSERSTACK_BUILD_NAME)" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Project: $($env:BROWSERSTACK_PROJECT_NAME)" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ Web Application Endpoint: $CX_TEST_URL" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Local Flag: $localFlagStr" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ Parallels per platform: $ParallelsPerPlatform" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ Platforms:" $NOW_RUN_LOG_FILE
    Log-Line "  $caps" $NOW_RUN_LOG_FILE

    Print-TestsRunningSection -Command "npm run test"
    [void](Invoke-External -Exe "cmd.exe" -Arguments @("/c","npm","run","test") -LogFile $LogFile -WorkingDirectory $TARGET)
    Log-Line "ℹ️ Run Test command completed." $NOW_RUN_LOG_FILE

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

  Log-Line "ℹ️ Cloning repository: $REPO" $NOW_RUN_LOG_FILE
  Invoke-GitClone -Url "https://github.com/BrowserStackCE/$REPO.git" -Target $TARGET -LogFile $NOW_RUN_LOG_FILE

  Push-Location $TARGET
  try {
    if ($APP_PLATFORM -eq "all" -or $APP_PLATFORM -eq "android") {
      Set-Location "android\testng-examples"
    } else {
      Set-Location "ios\testng-examples"
    }
    
    $env:BROWSERSTACK_USERNAME = $BROWSERSTACK_USERNAME
    $env:BROWSERSTACK_ACCESS_KEY = $BROWSERSTACK_ACCESS_KEY
    $env:BROWSERSTACK_CONFIG_FILE = ".\browserstack.yml"
    $env:BROWSERSTACK_BUILD_NAME = "now-$env:NOW_OS-$TEST_TYPE-$TechStack-testng"
    $env:BROWSERSTACK_PROJECT_NAME = "now-$env:NOW_OS-$TEST_TYPE"
    
    Log-Line "ℹ️ Parallels per platform: $ParallelsPerPlatform" $NOW_RUN_LOG_FILE
    $platforms = Generate-Mobile-Platforms -MaxTotalParallels $ParallelsPerPlatform -platformsListContentFormat "yaml"
    $localFlag = if ($UseLocal) { "true" } else { "false" }

    # Write complete browserstack.yml (not just append)
    $yamlContent = @"
app: $APP_URL
platforms:
$platforms
"@ 
    
    Add-Content -Path $env:BROWSERSTACK_CONFIG_FILE -Value $yamlContent -Encoding UTF8

    Report-BStackLocalStatus -LocalFlag $UseLocal

    # Validate Environment Variables
    Log-Section "Validate Environment Variables" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Username: $BROWSERSTACK_USERNAME" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Project: $env:BROWSERSTACK_PROJECT_NAME" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Build: $env:BROWSERSTACK_BUILD_NAME" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ Native App Endpoint: $APP_URL" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Local Flag: $localFlag" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ Parallels per platform: $ParallelsPerPlatform" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ Platforms:" $NOW_RUN_LOG_FILE
    $platforms -split "`n" | ForEach-Object { if ($_.Trim()) { Log-Line "  $_" $NOW_RUN_LOG_FILE } }

    $mvn = Get-MavenCommand -RepoDir (Get-Location).Path
    Log-Line "⚙️ Running '$mvn clean'" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ Installing dependencies" $NOW_RUN_LOG_FILE
    $cleanExit = Invoke-External -Exe $mvn -Arguments @("clean") -LogFile $LogFile -WorkingDirectory (Get-Location).Path
    if ($cleanExit -ne 0) {
      Log-Line "❌ 'mvn clean' FAILED. See $LogFile for details." $NOW_RUN_LOG_FILE
      throw "Maven clean failed"
    }
    Log-Line "✅ Dependencies installed" $NOW_RUN_LOG_FILE

    Print-TestsRunningSection -Command "mvn test -P sample-test"
    [void](Invoke-External -Exe $mvn -Arguments @("test","-P","sample-test") -LogFile $LogFile -WorkingDirectory (Get-Location).Path)
    Log-Line "ℹ️ Run Test command completed." $NOW_RUN_LOG_FILE

  } finally {
    Pop-Location
    Set-Location (Join-Path $WORKSPACE_DIR $PROJECT_FOLDER)
  }
}

# ===== Setup: Mobile (Python) =====
function Setup-Mobile-Python {
  param([bool]$UseLocal, [int]$ParallelsPerPlatform, [string]$LogFile)

  $REPO = "now-pytest-appium-app-browserstack"
  $TARGET = Join-Path $GLOBAL_DIR $REPO

  New-Item -ItemType Directory -Path $GLOBAL_DIR -Force | Out-Null
  if (Test-Path $TARGET) {
    Remove-Item -Path $TARGET -Recurse -Force
  }

  Log-Line "ℹ️ Cloning repository: $REPO" $NOW_RUN_LOG_FILE
  Invoke-GitClone -Url "https://github.com/BrowserStackCE/$REPO.git" -Target $TARGET -LogFile $NOW_RUN_LOG_FILE

  Push-Location $TARGET
  try {
    if (-not $PY_CMD -or $PY_CMD.Count -eq 0) { Set-PythonCmd }
    $venv = Join-Path $TARGET "venv"
    if (!(Test-Path $venv)) {
      [void](Invoke-Py -Arguments @("-m","venv",$venv) -LogFile $LogFile -WorkingDirectory $TARGET)
    }
    $venvPy = Get-VenvPython -VenvDir $venv
    
    Log-Line "ℹ️ Installing dependencies" $NOW_RUN_LOG_FILE
    [void](Invoke-External -Exe $venvPy -Arguments @("-m","pip","install","-r","requirements.txt") -LogFile $LogFile -WorkingDirectory $TARGET)
    Log-Line "✅ Dependencies installed" $NOW_RUN_LOG_FILE
    
    $env:PATH = (Join-Path $venv 'Scripts') + ";" + $env:PATH
    $env:BROWSERSTACK_USERNAME = $BROWSERSTACK_USERNAME
    $env:BROWSERSTACK_ACCESS_KEY = $BROWSERSTACK_ACCESS_KEY
    $env:BROWSERSTACK_APP = $APP_URL

    $originalPlatform = $APP_PLATFORM
    $localFlag = if ($UseLocal) { "true" } else { "false" }

    # Decide which directory to run based on APP_PLATFORM (default = android)
    $run_dir = "android"

    if ($env:APP_PLATFORM -eq "ios") {
        $run_dir = "ios"
    }

    # Set environment variable (PowerShell equivalent of export)
    $env:BROWSERSTACK_CONFIG_FILE = "./$run_dir/browserstack.yml"

    # Generate platform YAMLs

    $platforms = Generate-Mobile-Platforms -MaxTotalParallels $ParallelsPerPlatform -platformsListContentFormat "yaml"
    $yamlContent =@"
app: $APP_URL
platforms:
$platforms
"@

    Add-Content "$BROWSERSTACK_CONFIG_FILE" -Value $yamlContent
    $script:APP_PLATFORM = $originalPlatform
    Log-Line "✅ Wrote platform YAMLs" $NOW_RUN_LOG_FILE

    Report-BStackLocalStatus -LocalFlag $UseLocal

    # Validate Environment Variables
    Log-Section "Validate Environment Variables" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Username: $BROWSERSTACK_USERNAME" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Project: $env:BROWSERSTACK_PROJECT_NAME" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Build: now-$env:NOW_OS-$TEST_TYPE-$TECH_STACK-pytest" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ Native App Endpoint: $APP_URL" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Local Flag: $localFlag" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ Parallels per platform: $ParallelsPerPlatform" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ Platforms:" $NOW_RUN_LOG_FILE
    $platformYaml -split "`n" | ForEach-Object { if ($_.Trim()) { Log-Line "  $_" $NOW_RUN_LOG_FILE } }

    $sdk = Join-Path $venv "Scripts\browserstack-sdk.exe"
    Print-TestsRunningSection -Command "cd $runDirName && browserstack-sdk pytest -s bstack_sample.py"
    
    Push-Location $runDir
    try {
      [void](Invoke-External -Exe $sdk -Arguments @('pytest','-s','bstack_sample.py') -LogFile $LogFile -WorkingDirectory (Get-Location).Path)
    } finally {
      Pop-Location
    }
    Log-Line "ℹ️ Run Test command completed." $NOW_RUN_LOG_FILE

  } finally {
    Pop-Location
    Set-Location (Join-Path $WORKSPACE_DIR $PROJECT_FOLDER)
  }
}

# ===== Setup: Mobile (NodeJS) =====
function Setup-Mobile-NodeJS {
  param([bool]$UseLocal, [int]$ParallelsPerPlatform, [string]$LogFile)

  $REPO = "now-webdriverio-appium-app-browserstack"
  $TARGET = Join-Path $GLOBAL_DIR $REPO

  New-Item -ItemType Directory -Path $GLOBAL_DIR -Force | Out-Null
  if (Test-Path $TARGET) {
    Remove-Item -Path $TARGET -Recurse -Force
  }

  Log-Line "ℹ️ Cloning repository: $REPO" $NOW_RUN_LOG_FILE
  Invoke-GitClone -Url "https://github.com/BrowserStackCE/$REPO.git" -Target $TARGET -LogFile $NOW_RUN_LOG_FILE

  $testDir = Join-Path $TARGET "test"
  Push-Location $testDir
  try {
    Log-Line "⚙️ Running 'npm install'" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ Installing dependencies" $NOW_RUN_LOG_FILE
    [void](Invoke-External -Exe "cmd.exe" -Arguments @("/c","npm","install") -LogFile $LogFile -WorkingDirectory $testDir)
    Log-Line "✅ Dependencies installed" $NOW_RUN_LOG_FILE

    # Generate capabilities JSON and set as environment variable (like Mac)
    $capsJson = Generate-Mobile-Platforms -MaxTotalParallels $ParallelsPerPlatform

    $env:BROWSERSTACK_USERNAME = $BROWSERSTACK_USERNAME
    $env:BROWSERSTACK_ACCESS_KEY = $BROWSERSTACK_ACCESS_KEY
    $env:BSTACK_PARALLELS = $ParallelsPerPlatform
    $env:BSTACK_CAPS_JSON = $capsJson
    $env:BROWSERSTACK_APP = $APP_URL
    $env:BROWSERSTACK_BUILD_NAME = "now-$env:NOW_OS-$TEST_TYPE-$TechStack-wdio"
    $env:BROWSERSTACK_PROJECT_NAME = "now-$env:NOW_OS-$TEST_TYPE"
    $env:BROWSERSTACK_LOCAL = "true"

    # Validate Environment Variables
    Log-Section "Validate Environment Variables" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Username: $BROWSERSTACK_USERNAME" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Project: $($env:BROWSERSTACK_PROJECT_NAME)" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Build: $($env:BROWSERSTACK_BUILD_NAME)" $NOW_RUN_LOG_FILE

    Log-Line "ℹ️ Native App Endpoint: $APP_URL" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ BrowserStack Local Flag: $($env:BROWSERSTACK_LOCAL)" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ Parallels per platform: $ParallelsPerPlatform" $NOW_RUN_LOG_FILE
    Log-Line "ℹ️ Platforms: $capsJson" $NOW_RUN_LOG_FILE

    Print-TestsRunningSection -Command "npm run test"
    [void](Invoke-External -Exe "cmd.exe" -Arguments @("/c","npm","run","test") -LogFile $LogFile -WorkingDirectory $testDir)
    Log-Line "ℹ️ Run Test command completed." $NOW_RUN_LOG_FILE

  } finally {
    Pop-Location
    Set-Location (Join-Path $WORKSPACE_DIR $PROJECT_FOLDER)
  }
}

# ===== Helper Functions =====
function Report-BStackLocalStatus {
  param([bool]$LocalFlag)
  if ($LocalFlag) {
    Log-Line "✅ Target website is behind firewall. BrowserStack Local enabled for this run." $NOW_RUN_LOG_FILE
  } else {
    Log-Line "✅ Target website is publicly resolvable. BrowserStack Local disabled for this run." $NOW_RUN_LOG_FILE
  }
}

function Print-TestsRunningSection {
  param([string]$Command)
  Log-Section "🚀 Running Tests: $Command" $NOW_RUN_LOG_FILE
  Log-Line "ℹ️ Executing: Test run command. This could take a few minutes..." $NOW_RUN_LOG_FILE
  Log-Line "ℹ️ You can monitor test progress here: 🔗 https://automation.browserstack.com/" $NOW_RUN_LOG_FILE
}

function Identify-RunStatus-Java {
  param([string]$LogFile)
  if (!(Test-Path $LogFile)) { return $false }
  $content = Get-Content $LogFile -Raw
  $match = [regex]::Match($content, 'Tests run:\s*(\d+),\s*Failures:\s*(\d+),\s*Errors:\s*(\d+),\s*Skipped:\s*(\d+)')
  if (-not $match.Success) { return $false }
  $passed = [int]$match.Groups[1].Value - ([int]$match.Groups[2].Value + [int]$match.Groups[3].Value + [int]$match.Groups[4].Value)
  if ($passed -gt 0) {
    Log-Line "✅ Success: $passed test(s) passed." $NOW_RUN_LOG_FILE
    return $true
  }
  return $false
}

function Identify-RunStatus-Python {
  param([string]$LogFile)
  if (!(Test-Path $LogFile)) { return $false }
  $content = Get-Content $LogFile -Raw
  $matches = [regex]::Matches($content, '(\d+)\s+passed')
  $passedSum = 0
  foreach ($m in $matches) { $passedSum += [int]$m.Groups[1].Value }
  if ($passedSum -gt 0) {
    Log-Line "✅ Success: $passedSum test(s) passed." $NOW_RUN_LOG_FILE
    return $true
  }
  return $false
}

function Identify-RunStatus-NodeJS {
  param([string]$LogFile)
  if (!(Test-Path $LogFile)) { return $false }
  $content = Get-Content $LogFile -Raw
  $match = [regex]::Match($content, '(\d+)\s+pass')
  if ($match.Success -and [int]$match.Groups[1].Value -gt 0) {
    Log-Line "✅ Success: $($match.Groups[1].Value) test(s) passed." $NOW_RUN_LOG_FILE
    return $true
  }
  return $false
}

# ===== Setup Environment Wrapper =====
function Setup-Environment {
  param(
    [Parameter(Mandatory)][string]$SetupType,
    [Parameter(Mandatory)][string]$TechStack
  )

  Log-Section "📦 Project Setup" $NOW_RUN_LOG_FILE

  $maxParallels = if ($SetupType -match "web") { $TEAM_PARALLELS_MAX_ALLOWED_WEB } else { $TEAM_PARALLELS_MAX_ALLOWED_MOBILE }
  Log-Line "Team max parallels: $maxParallels" $NOW_RUN_LOG_FILE

  $localFlag = $false
  $totalParallels = $maxParallels

  $success = $false
  $logFile = $NOW_RUN_LOG_FILE

  switch ($TechStack) {
    "Java" {
      if ($SetupType -match "web") {
        Setup-Web-Java -UseLocal:$localFlag -ParallelsPerPlatform $totalParallels -LogFile $logFile
        $success = Identify-RunStatus-Java -LogFile $logFile
      } else {
        Setup-Mobile-Java -UseLocal:$localFlag -ParallelsPerPlatform $totalParallels -LogFile $logFile
        $success = Identify-RunStatus-Java -LogFile $logFile
      }
    }
    "Python" {
      if ($SetupType -match "web") {
        Setup-Web-Python -UseLocal:$localFlag -ParallelsPerPlatform $totalParallels -LogFile $logFile
        $success = Identify-RunStatus-Python -LogFile $logFile
      } else {
        Setup-Mobile-Python -UseLocal:$localFlag -ParallelsPerPlatform $totalParallels -LogFile $logFile
        $success = Identify-RunStatus-Python -LogFile $logFile
      }
    }
    "NodeJS" {
      if ($SetupType -match "web") {
        Setup-Web-NodeJS -UseLocal:$localFlag -ParallelsPerPlatform $totalParallels -LogFile $logFile
        $success = Identify-RunStatus-NodeJS -LogFile $logFile
      } else {
        Setup-Mobile-NodeJS -UseLocal:$localFlag -ParallelsPerPlatform $totalParallels -LogFile $logFile
        $success = Identify-RunStatus-NodeJS -LogFile $logFile
      }
    }
    default {
      Log-Line "⚠️ Unknown TECH_STACK: $TechStack" $NOW_RUN_LOG_FILE
      return
    }
  }

  Log-Section "✅ Results" $NOW_RUN_LOG_FILE
  if ($success) {
    Log-Line "✅ $SetupType setup succeeded." $NOW_RUN_LOG_FILE
  } else {
    Log-Line "❌ $SetupType setup ended. Check $logFile for details." $NOW_RUN_LOG_FILE
  }
}

function Run-Setup {
  param(
    [string]$TestType,
    [string]$TechStack
  )
  Setup-Environment -SetupType $TestType -TechStack $TechStack
}


