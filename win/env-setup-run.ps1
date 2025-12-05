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

  Log-Line "ℹ️ Cloning repository: $REPO" $GLOBAL_LOG
  Invoke-GitClone -Url "https://github.com/BrowserStackCE/$REPO.git" -Target $TARGET -LogFile (Get-RunLogFile)

  Push-Location $TARGET
  try {
    Log-Line "ℹ️ Target website: $CX_TEST_URL" $GLOBAL_LOG
    
    if (Test-DomainPrivate) {
      $UseLocal = $true
    }

    Report-BStackLocalStatus -LocalFlag $UseLocal

    Log-Line "🧩 Generating YAML config (browserstack.yml)" $GLOBAL_LOG
    $platforms = Generate-Web-Platforms-Yaml -MaxTotalParallels $ParallelsPerPlatform
    $localFlag = if ($UseLocal) { "true" } else { "false" }

    $yamlContent = @"
userName: $BROWSERSTACK_USERNAME
accessKey: $BROWSERSTACK_ACCESS_KEY
framework: testng
browserstackLocal: $localFlag
buildName: now-$NOW_OS-web-java-testng
projectName: now-$NOW_OS-web
percy: true
accessibility: true
platforms:
$platforms
parallelsPerPlatform: $ParallelsPerPlatform
"@

    Set-Content "browserstack.yml" -Value $yamlContent
    Log-Line "✅ Created browserstack.yml in root directory" $GLOBAL_LOG

    # Validate Environment Variables
    Log-Section "Validate Environment Variables" $GLOBAL_LOG
    Log-Line "ℹ️ BrowserStack Username: $BROWSERSTACK_USERNAME" $GLOBAL_LOG
    Log-Line "ℹ️ BrowserStack Build: now-$NOW_OS-web-java-testng" $GLOBAL_LOG
    Log-Line "ℹ️ Web Application Endpoint: $CX_TEST_URL" $GLOBAL_LOG
    Log-Line "ℹ️ BrowserStack Local Flag: $localFlag" $GLOBAL_LOG
    Log-Line "ℹ️ Parallels per platform: $ParallelsPerPlatform" $GLOBAL_LOG
    Log-Line "ℹ️ Platforms:" $GLOBAL_LOG
    $platforms -split "`n" | ForEach-Object { if ($_.Trim()) { Log-Line "  $_" $GLOBAL_LOG } }

    $mvn = Get-MavenCommand -RepoDir $TARGET
    Log-Line "⚙️ Running '$mvn install -DskipTests'" $GLOBAL_LOG
    Log-Line "ℹ️ Installing dependencies" $GLOBAL_LOG
    [void](Invoke-External -Exe $mvn -Arguments @("install","-DskipTests") -LogFile $LogFile -WorkingDirectory $TARGET)
    Log-Line "✅ Dependencies installed" $GLOBAL_LOG

    Print-TestsRunningSection -Command "mvn test -P sample-test"
    [void](Invoke-External -Exe $mvn -Arguments @("test","-P","sample-test") -LogFile $LogFile -WorkingDirectory $TARGET)
    Log-Line "ℹ️ Run Test command completed." $GLOBAL_LOG

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

  Log-Line "ℹ️ Cloning repository: $REPO" $GLOBAL_LOG
  Invoke-GitClone -Url "https://github.com/BrowserStackCE/$REPO.git" -Target $TARGET -LogFile (Get-RunLogFile)

  Push-Location $TARGET
  try {
    if (-not $PY_CMD -or $PY_CMD.Count -eq 0) { Set-PythonCmd }
    $venv = Join-Path $TARGET "venv"
    if (!(Test-Path $venv)) {
      [void](Invoke-Py -Arguments @("-m","venv",$venv) -LogFile $LogFile -WorkingDirectory $TARGET)
    }
    $venvPy = Get-VenvPython -VenvDir $venv
    
    Log-Line "ℹ️ Installing dependencies" $GLOBAL_LOG
    [void](Invoke-External -Exe $venvPy -Arguments @("-m","pip","install","-r","requirements.txt") -LogFile $LogFile -WorkingDirectory $TARGET)
    Log-Line "✅ Dependencies installed" $GLOBAL_LOG
    
    $env:PATH = (Join-Path $venv 'Scripts') + ";" + $env:PATH
    $env:BROWSERSTACK_USERNAME = $BROWSERSTACK_USERNAME
    $env:BROWSERSTACK_ACCESS_KEY = $BROWSERSTACK_ACCESS_KEY

    if (Test-DomainPrivate) {
      $UseLocal = $true
    }

    Report-BStackLocalStatus -LocalFlag $UseLocal

    $env:BROWSERSTACK_CONFIG_FILE = "browserstack.yml"
    $platforms = Generate-Web-Platforms-Yaml -MaxTotalParallels $ParallelsPerPlatform
    $localFlag = if ($UseLocal) { "true" } else { "false" }

@"
userName: $BROWSERSTACK_USERNAME
accessKey: $BROWSERSTACK_ACCESS_KEY
framework: pytest
browserstackLocal: $localFlag
buildName: now-$NOW_OS-web-python-pytest
projectName: now-$NOW_OS-web
percy: true
accessibility: true
platforms:
$platforms
parallelsPerPlatform: $ParallelsPerPlatform
"@ | Set-Content "browserstack.yml"

    Log-Line "✅ Updated browserstack.yml with platforms and credentials" $GLOBAL_LOG

    # Validate Environment Variables
    Log-Section "Validate Environment Variables" $GLOBAL_LOG
    Log-Line "ℹ️ BrowserStack Username: $BROWSERSTACK_USERNAME" $GLOBAL_LOG
    Log-Line "ℹ️ BrowserStack Build: now-$NOW_OS-web-python-pytest" $GLOBAL_LOG
    Log-Line "ℹ️ Web Application Endpoint: $CX_TEST_URL" $GLOBAL_LOG
    Log-Line "ℹ️ BrowserStack Local Flag: $localFlag" $GLOBAL_LOG
    Log-Line "ℹ️ Parallels per platform: $ParallelsPerPlatform" $GLOBAL_LOG
    Log-Line "ℹ️ Platforms:" $GLOBAL_LOG
    $platforms -split "`n" | ForEach-Object { if ($_.Trim()) { Log-Line "  $_" $GLOBAL_LOG } }

    $sdk = Join-Path $venv "Scripts\browserstack-sdk.exe"
    Print-TestsRunningSection -Command "browserstack-sdk pytest -s tests/bstack-sample-test.py"
    [void](Invoke-External -Exe $sdk -Arguments @('pytest','-s','tests/bstack-sample-test.py') -LogFile $LogFile -WorkingDirectory $TARGET)
    Log-Line "ℹ️ Run Test command completed." $GLOBAL_LOG

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

  Log-Line "ℹ️ Cloning repository: $REPO" $GLOBAL_LOG
  Invoke-GitClone -Url "https://github.com/BrowserStackCE/$REPO.git" -Target $TARGET -LogFile (Get-RunLogFile)

  Push-Location $TARGET
  try {
    Log-Line "⚙️ Running 'npm install'" $GLOBAL_LOG
    Log-Line "ℹ️ Installing dependencies" $GLOBAL_LOG
    [void](Invoke-External -Exe "cmd.exe" -Arguments @("/c","npm","install") -LogFile $LogFile -WorkingDirectory $TARGET)
    Log-Line "✅ Dependencies installed" $GLOBAL_LOG

    $caps = Generate-Web-Caps-Json -MaxTotalParallels $ParallelsPerPlatform
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
    $env:BROWSERSTACK_BUILD_NAME = "now-$NOW_OS-web-nodejs-wdio"
    $env:BROWSERSTACK_PROJECT_NAME = "now-$NOW_OS-web"

    # Validate Environment Variables
    Log-Section "Validate Environment Variables" $GLOBAL_LOG
    Log-Line "ℹ️ BrowserStack Username: $BROWSERSTACK_USERNAME" $GLOBAL_LOG
    Log-Line "ℹ️ BrowserStack Build: $($env:BROWSERSTACK_BUILD_NAME)" $GLOBAL_LOG
    Log-Line "ℹ️ BrowserStack Project: $($env:BROWSERSTACK_PROJECT_NAME)" $GLOBAL_LOG
    Log-Line "ℹ️ Web Application Endpoint: $CX_TEST_URL" $GLOBAL_LOG
    Log-Line "ℹ️ BrowserStack Local Flag: $localFlagStr" $GLOBAL_LOG
    Log-Line "ℹ️ Parallels per platform: $ParallelsPerPlatform" $GLOBAL_LOG
    Log-Line "ℹ️ Platforms:" $GLOBAL_LOG
    Log-Line "  $caps" $GLOBAL_LOG

    Print-TestsRunningSection -Command "npm run test"
    [void](Invoke-External -Exe "cmd.exe" -Arguments @("/c","npm","run","test") -LogFile $LogFile -WorkingDirectory $TARGET)
    Log-Line "ℹ️ Run Test command completed." $GLOBAL_LOG

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

  Log-Line "ℹ️ Cloning repository: $REPO" $GLOBAL_LOG
  Invoke-GitClone -Url "https://github.com/BrowserStackCE/$REPO.git" -Target $TARGET -LogFile (Get-RunLogFile)

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
    
    $platforms = Generate-Mobile-Platforms-Yaml -MaxTotalParallels $ParallelsPerPlatform
    $localFlag = if ($UseLocal) { "true" } else { "false" }

    # Write complete browserstack.yml (not just append)
    $yamlContent = @"
userName: $BROWSERSTACK_USERNAME
accessKey: $BROWSERSTACK_ACCESS_KEY
framework: testng
browserstackLocal: $localFlag
buildName: now-$NOW_OS-app-java-testng
projectName: now-$NOW_OS-app
parallelsPerPlatform: $ParallelsPerPlatform
app: $APP_URL
platforms:
$platforms
"@
    $yamlContent | Set-Content -Path $env:BROWSERSTACK_CONFIG_FILE -Encoding UTF8

    Report-BStackLocalStatus -LocalFlag $UseLocal

    # Validate Environment Variables
    Log-Section "Validate Environment Variables" $GLOBAL_LOG
    Log-Line "ℹ️ BrowserStack Username: $BROWSERSTACK_USERNAME" $GLOBAL_LOG
    Log-Line "ℹ️ BrowserStack Build: now-$NOW_OS-app-java-testng" $GLOBAL_LOG
    Log-Line "ℹ️ Native App Endpoint: $APP_URL" $GLOBAL_LOG
    Log-Line "ℹ️ BrowserStack Local Flag: $localFlag" $GLOBAL_LOG
    Log-Line "ℹ️ Parallels per platform: $ParallelsPerPlatform" $GLOBAL_LOG
    Log-Line "ℹ️ Platforms:" $GLOBAL_LOG
    $platforms -split "`n" | ForEach-Object { if ($_.Trim()) { Log-Line "  $_" $GLOBAL_LOG } }

    $mvn = Get-MavenCommand -RepoDir (Get-Location).Path
    Log-Line "⚙️ Running '$mvn clean'" $GLOBAL_LOG
    Log-Line "ℹ️ Installing dependencies" $GLOBAL_LOG
    $cleanExit = Invoke-External -Exe $mvn -Arguments @("clean") -LogFile $LogFile -WorkingDirectory (Get-Location).Path
    if ($cleanExit -ne 0) {
      Log-Line "❌ 'mvn clean' FAILED. See $LogFile for details." $GLOBAL_LOG
      throw "Maven clean failed"
    }
    Log-Line "✅ Dependencies installed" $GLOBAL_LOG

    Print-TestsRunningSection -Command "mvn test -P sample-test"
    [void](Invoke-External -Exe $mvn -Arguments @("test","-P","sample-test") -LogFile $LogFile -WorkingDirectory (Get-Location).Path)
    Log-Line "ℹ️ Run Test command completed." $GLOBAL_LOG

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

  Log-Line "ℹ️ Cloning repository: $REPO" $GLOBAL_LOG
  Invoke-GitClone -Url "https://github.com/BrowserStackCE/$REPO.git" -Target $TARGET -LogFile (Get-RunLogFile)

  Push-Location $TARGET
  try {
    if (-not $PY_CMD -or $PY_CMD.Count -eq 0) { Set-PythonCmd }
    $venv = Join-Path $TARGET "venv"
    if (!(Test-Path $venv)) {
      [void](Invoke-Py -Arguments @("-m","venv",$venv) -LogFile $LogFile -WorkingDirectory $TARGET)
    }
    $venvPy = Get-VenvPython -VenvDir $venv
    
    Log-Line "ℹ️ Installing dependencies" $GLOBAL_LOG
    [void](Invoke-External -Exe $venvPy -Arguments @("-m","pip","install","-r","requirements.txt") -LogFile $LogFile -WorkingDirectory $TARGET)
    Log-Line "✅ Dependencies installed" $GLOBAL_LOG
    
    $env:PATH = (Join-Path $venv 'Scripts') + ";" + $env:PATH
    $env:BROWSERSTACK_USERNAME = $BROWSERSTACK_USERNAME
    $env:BROWSERSTACK_ACCESS_KEY = $BROWSERSTACK_ACCESS_KEY
    $env:BROWSERSTACK_APP = $APP_URL

    $originalPlatform = $APP_PLATFORM
    $localFlag = if ($UseLocal) { "true" } else { "false" }

    # Generate platform YAMLs
    $script:APP_PLATFORM = "android"
    $platformYamlAndroid = Generate-Mobile-Platforms-Yaml -MaxTotalParallels $ParallelsPerPlatform
    $androidYmlPath = Join-Path $TARGET "android\browserstack.yml"
@"
userName: $BROWSERSTACK_USERNAME
accessKey: $BROWSERSTACK_ACCESS_KEY
framework: pytest
browserstackLocal: $localFlag
buildName: now-$NOW_OS-app-python-pytest
projectName: now-$NOW_OS-app
parallelsPerPlatform: $ParallelsPerPlatform
app: $APP_URL
platforms:
$platformYamlAndroid
"@ | Set-Content $androidYmlPath

    $script:APP_PLATFORM = "ios"
    $platformYamlIos = Generate-Mobile-Platforms-Yaml -MaxTotalParallels $ParallelsPerPlatform
    $iosYmlPath = Join-Path $TARGET "ios\browserstack.yml"
@"
userName: $BROWSERSTACK_USERNAME
accessKey: $BROWSERSTACK_ACCESS_KEY
framework: pytest
browserstackLocal: $localFlag
buildName: now-$NOW_OS-app-python-pytest
projectName: now-$NOW_OS-app
parallelsPerPlatform: $ParallelsPerPlatform
app: $APP_URL
platforms:
$platformYamlIos
"@ | Set-Content $iosYmlPath

    $script:APP_PLATFORM = $originalPlatform
    Log-Line "✅ Wrote platform YAMLs" $GLOBAL_LOG

    $runDirName = if ($APP_PLATFORM -eq "ios") { "ios" } else { "android" }
    $runDir = Join-Path $TARGET $runDirName
    $platformYaml = if ($runDirName -eq "ios") { $platformYamlIos } else { $platformYamlAndroid }

    Report-BStackLocalStatus -LocalFlag $UseLocal

    # Validate Environment Variables
    Log-Section "Validate Environment Variables" $GLOBAL_LOG
    Log-Line "ℹ️ BrowserStack Username: $BROWSERSTACK_USERNAME" $GLOBAL_LOG
    Log-Line "ℹ️ BrowserStack Build: now-$NOW_OS-app-python-pytest" $GLOBAL_LOG
    Log-Line "ℹ️ Native App Endpoint: $APP_URL" $GLOBAL_LOG
    Log-Line "ℹ️ BrowserStack Local Flag: $localFlag" $GLOBAL_LOG
    Log-Line "ℹ️ Parallels per platform: $ParallelsPerPlatform" $GLOBAL_LOG
    Log-Line "ℹ️ Platforms:" $GLOBAL_LOG
    $platformYaml -split "`n" | ForEach-Object { if ($_.Trim()) { Log-Line "  $_" $GLOBAL_LOG } }

    $sdk = Join-Path $venv "Scripts\browserstack-sdk.exe"
    Print-TestsRunningSection -Command "cd $runDirName && browserstack-sdk pytest -s bstack_sample.py"
    
    Push-Location $runDir
    try {
      [void](Invoke-External -Exe $sdk -Arguments @('pytest','-s','bstack_sample.py') -LogFile $LogFile -WorkingDirectory (Get-Location).Path)
    } finally {
      Pop-Location
    }
    Log-Line "ℹ️ Run Test command completed." $GLOBAL_LOG

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

  Log-Line "ℹ️ Cloning repository: $REPO" $GLOBAL_LOG
  Invoke-GitClone -Url "https://github.com/BrowserStackCE/$REPO.git" -Target $TARGET -LogFile (Get-RunLogFile)

  $testDir = Join-Path $TARGET "test"
  Push-Location $testDir
  try {
    Log-Line "⚙️ Running 'npm install'" $GLOBAL_LOG
    Log-Line "ℹ️ Installing dependencies" $GLOBAL_LOG
    [void](Invoke-External -Exe "cmd.exe" -Arguments @("/c","npm","install") -LogFile $LogFile -WorkingDirectory $testDir)
    Log-Line "✅ Dependencies installed" $GLOBAL_LOG

    # Generate capabilities JSON and set as environment variable (like Mac)
    $capsJson = Generate-Mobile-Caps-Json-String -MaxTotalParallels $ParallelsPerPlatform

    $env:BROWSERSTACK_USERNAME = $BROWSERSTACK_USERNAME
    $env:BROWSERSTACK_ACCESS_KEY = $BROWSERSTACK_ACCESS_KEY
    $env:BSTACK_PARALLELS = $ParallelsPerPlatform
    $env:BSTACK_CAPS_JSON = $capsJson
    $env:BROWSERSTACK_APP = $APP_URL
    $env:BROWSERSTACK_BUILD_NAME = "now-$NOW_OS-app-nodejs-wdio"
    $env:BROWSERSTACK_PROJECT_NAME = "now-$NOW_OS-app"
    $env:BROWSERSTACK_LOCAL = "true"

    # Validate Environment Variables
    Log-Section "Validate Environment Variables" $GLOBAL_LOG
    Log-Line "ℹ️ BrowserStack Username: $BROWSERSTACK_USERNAME" $GLOBAL_LOG
    Log-Line "ℹ️ BrowserStack Build: $($env:BROWSERSTACK_BUILD_NAME)" $GLOBAL_LOG
    Log-Line "ℹ️ BrowserStack Project: $($env:BROWSERSTACK_PROJECT_NAME)" $GLOBAL_LOG
    Log-Line "ℹ️ Native App Endpoint: $APP_URL" $GLOBAL_LOG
    Log-Line "ℹ️ BrowserStack Local Flag: $($env:BROWSERSTACK_LOCAL)" $GLOBAL_LOG
    Log-Line "ℹ️ Parallels per platform: $ParallelsPerPlatform" $GLOBAL_LOG
    Log-Line "ℹ️ Platforms: $capsJson" $GLOBAL_LOG

    Print-TestsRunningSection -Command "npm run test"
    [void](Invoke-External -Exe "cmd.exe" -Arguments @("/c","npm","run","test") -LogFile $LogFile -WorkingDirectory $testDir)
    Log-Line "ℹ️ Run Test command completed." $GLOBAL_LOG

  } finally {
    Pop-Location
    Set-Location (Join-Path $WORKSPACE_DIR $PROJECT_FOLDER)
  }
}

# ===== Helper Functions =====
function Report-BStackLocalStatus {
  param([bool]$LocalFlag)
  if ($LocalFlag) {
    Log-Line "✅ Target website is behind firewall. BrowserStack Local enabled for this run." $GLOBAL_LOG
  } else {
    Log-Line "✅ Target website is publicly resolvable. BrowserStack Local disabled for this run." $GLOBAL_LOG
  }
}

function Print-TestsRunningSection {
  param([string]$Command)
  Log-Section "🚀 Running Tests: $Command" $GLOBAL_LOG
  Log-Line "ℹ️ Executing: Test run command. This could take a few minutes..." $GLOBAL_LOG
  Log-Line "ℹ️ You can monitor test progress here: 🔗 https://automation.browserstack.com/" $GLOBAL_LOG
}

function Identify-RunStatus-Java {
  param([string]$LogFile)
  if (!(Test-Path $LogFile)) { return $false }
  $content = Get-Content $LogFile -Raw
  $match = [regex]::Match($content, 'Tests run:\s*(\d+),\s*Failures:\s*(\d+),\s*Errors:\s*(\d+),\s*Skipped:\s*(\d+)')
  if (-not $match.Success) { return $false }
  $passed = [int]$match.Groups[1].Value - ([int]$match.Groups[2].Value + [int]$match.Groups[3].Value + [int]$match.Groups[4].Value)
  if ($passed -gt 0) {
    Log-Line "✅ Success: $passed test(s) passed." $GLOBAL_LOG
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
    Log-Line "✅ Success: $passedSum test(s) passed." $GLOBAL_LOG
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
    Log-Line "✅ Success: $($match.Groups[1].Value) test(s) passed." $GLOBAL_LOG
    return $true
  }
  return $false
}

# ===== Setup Environment Wrapper =====
function Setup-Environment {
  param(
    [Parameter(Mandatory)][string]$SetupType,
    [Parameter(Mandatory)][string]$TechStack,
    [string]$RunMode = "--interactive"
  )

  Log-Section "📦 Project Setup" $GLOBAL_LOG

  $maxParallels = if ($SetupType -match "web") { $TEAM_PARALLELS_MAX_ALLOWED_WEB } else { $TEAM_PARALLELS_MAX_ALLOWED_MOBILE }
  Log-Line "Team max parallels: $maxParallels" $GLOBAL_LOG

  $localFlag = $false
  $totalParallels = [int]([Math]::Floor($maxParallels * $PARALLEL_PERCENTAGE))
  if ($totalParallels -lt 1) { $totalParallels = 1 }

  if ($RunMode -match "--silent" -and $totalParallels -gt 5) {
    $originalParallels = $totalParallels
    $totalParallels = 5
    Log-Line "ℹ️ Silent mode: capping parallels per platform to $totalParallels (requested $originalParallels)" $GLOBAL_LOG
  }

  Log-Line "Total parallels allocated: $totalParallels" $GLOBAL_LOG

  $success = $false
  $logFile = Get-RunLogFile

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
      Log-Line "⚠️ Unknown TECH_STACK: $TechStack" $GLOBAL_LOG
      return
    }
  }

  Log-Section "✅ Results" $GLOBAL_LOG
  if ($success) {
    Log-Line "✅ $SetupType setup succeeded." $GLOBAL_LOG
  } else {
    Log-Line "❌ $SetupType setup ended. Check $logFile for details." $GLOBAL_LOG
  }
}

# ===== Run Setup Wrapper (like Mac's run_setup) =====
function Run-Setup {
  param(
    [string]$TestType,
    [string]$TechStack,
    [string]$RunMode = "--interactive"
  )
  Setup-Environment -SetupType $TestType -TechStack $TechStack -RunMode $RunMode
}


