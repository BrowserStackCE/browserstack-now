# ==============================================
# ⚙️ SETUP & RUN
# ==============================================

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

    $yamlContent = @"
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
"@
    Set-Content "browserstack.yml" -Value $yamlContent

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
    $yamlContentAndroid = @"
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
"@
    Set-Content $androidYmlPath -Value $yamlContentAndroid

    $script:APP_PLATFORM = "ios"
    $platformYamlIos = Generate-Mobile-Platforms-Yaml -MaxTotalParallels $TEAM_PARALLELS_MAX_ALLOWED_MOBILE
    $iosYmlPath = Join-Path $TARGET "ios\browserstack.yml"
    $yamlContentIos = @"
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
"@
    Set-Content $iosYmlPath -Value $yamlContentIos

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
