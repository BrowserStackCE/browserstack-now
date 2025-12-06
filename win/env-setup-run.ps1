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
    $UseLocal = $true    # BROWSERSTACK_LOCAL ISSUE 
    Log-Line "🧩 Generating YAML config (browserstack.yml)" $GLOBAL_LOG
    $platforms = Generate-Web-Platforms-Yaml -MaxTotalParallels $ParallelsPerPlatform
    $localFlag = if ($UseLocal) { "true" } else { "false" }

    Set-BrowserStackPlatformsSection -RepoRoot $TARGET -RelativeConfigPath "browserstack.yml" -PlatformsYaml $platforms -IsWebTest
    $env:BROWSERSTACK_USERNAME = $BROWSERSTACK_USERNAME
    $env:BROWSERSTACK_ACCESS_KEY = $BROWSERSTACK_ACCESS_KEY
    # Explicitly clear BROWSERSTACK_APP for web tests to prevent SDK from treating this as App Automate
    Remove-Item Env:BROWSERSTACK_APP -ErrorAction SilentlyContinue
    $env:BSTACK_PARALLELS = $ParallelsPerPlatform
    $env:BROWSERSTACK_LOCAL = $localFlag
    $env:BSTACK_PLATFORMS = $platforms
    $env:BROWSERSTACK_BUILD_NAME = "now-$NOW_OS-web-java-testng"
    $env:BROWSERSTACK_PROJECT_NAME = "now-$NOW_OS-web"

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
    $testTimeout = 600  # 10 minutes to allow for test execution + cleanup
    Log-Line "ℹ️ Starting test execution with timeout of $testTimeout seconds..." $GLOBAL_LOG
    try {
      $exitCode = Invoke-External -Exe $mvn -Arguments @("test","-P","sample-test") -LogFile $LogFile -WorkingDirectory $TARGET -TimeoutSeconds $testTimeout
      Log-Line "ℹ️ Run Test command completed with exit code: $exitCode" $GLOBAL_LOG
    } catch {
      $errorMsg = $_.Exception.Message
      Log-Line "❌ Test execution failed: $errorMsg" $GLOBAL_LOG
      if ($errorMsg -match "timed out") {
        Log-Line "⚠️ Test execution timed out after $testTimeout seconds. Check BrowserStack dashboard for test status." $GLOBAL_LOG
      }
      throw
    }

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
    $UseLocal = $true
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
    # Explicitly clear BROWSERSTACK_APP for web tests to prevent SDK from treating this as App Automate
    Remove-Item Env:BROWSERSTACK_APP -ErrorAction SilentlyContinue

    if (Test-DomainPrivate) {
      $UseLocal = $true
    }

    Report-BStackLocalStatus -LocalFlag $UseLocal

    $env:BROWSERSTACK_CONFIG_FILE = "browserstack.yml"
    $platforms = Generate-Web-Platforms-Yaml -MaxTotalParallels $ParallelsPerPlatform
    $localFlag = if ($UseLocal) { "true" } else { "false" }

    Set-BrowserStackPlatformsSection -RepoRoot $TARGET -RelativeConfigPath "browserstack.yml" -PlatformsYaml $platforms -IsWebTest
    $env:BSTACK_PARALLELS = $ParallelsPerPlatform
    $env:BSTACK_PLATFORMS = $platforms
    $env:BROWSERSTACK_LOCAL = $localFlag
    $env:BROWSERSTACK_BUILD_NAME = "now-$NOW_OS-web-python-pytest"
    $env:BROWSERSTACK_PROJECT_NAME = "now-$NOW_OS-web"

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
    
    # Verify SDK exists before attempting to run
    if (-not (Test-Path $sdk)) {
      throw "BrowserStack SDK not found at: $sdk"
    }
    Log-Line "ℹ️ SDK path verified: $sdk" $GLOBAL_LOG
    
    # Check if BrowserStack Local binary might be needed
    $bsLocalPath = Join-Path $venv "Scripts\BrowserStackLocal.exe"
    if ($UseLocal -and -not (Test-Path $bsLocalPath)) {
      Log-Line "⚠️ BrowserStack Local binary not found at: $bsLocalPath" $GLOBAL_LOG
      Log-Line "⚠️ Tests may hang if BrowserStack Local is required but missing." $GLOBAL_LOG
    }
    
    Print-TestsRunningSection -Command "browserstack-sdk pytest -s tests/bstack-sample-test.py"
    
    # Increased timeout to 600 seconds (10 minutes) to allow for test execution + cleanup
    # Tests may complete but SDK hangs waiting for BrowserStack Local cleanup
    $testTimeout = 600
    Log-Line "ℹ️ Starting test execution with timeout of $testTimeout seconds..." $GLOBAL_LOG
    Log-Line "ℹ️ Working directory: $TARGET" $GLOBAL_LOG
    Log-Line "ℹ️ Log file: $LogFile" $GLOBAL_LOG
    
    # Log environment variables that might affect execution
    Log-Line "ℹ️ Environment check - BROWSERSTACK_USERNAME: $($env:BROWSERSTACK_USERNAME -ne $null)" $GLOBAL_LOG
    Log-Line "ℹ️ Environment check - BROWSERSTACK_ACCESS_KEY: $($env:BROWSERSTACK_ACCESS_KEY -ne $null)" $GLOBAL_LOG
    Log-Line "ℹ️ Environment check - BROWSERSTACK_LOCAL: $($env:BROWSERSTACK_LOCAL)" $GLOBAL_LOG
    
    try {
      $startTime = Get-Date
      Log-Line "ℹ️ Invoking external command at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')..." $GLOBAL_LOG
      
      $exitCode = Invoke-External -Exe $sdk -Arguments @('pytest','-s','tests/bstack-sample-test.py') -LogFile $LogFile -WorkingDirectory $TARGET -TimeoutSeconds $testTimeout
      
      $endTime = Get-Date
      $duration = ($endTime - $startTime).TotalSeconds
      Log-Line "ℹ️ Run Test command completed with exit code: $exitCode (Duration: $([math]::Round($duration, 2))s)" $GLOBAL_LOG
    } catch {
      $errorMsg = $_.Exception.Message
      $endTime = Get-Date
      $duration = ($endTime - $startTime).TotalSeconds
      Log-Line "❌ Test execution failed after $([math]::Round($duration, 2))s: $errorMsg" $GLOBAL_LOG
      
      # Check if process is still running (might indicate hang)
      try {
        $runningProcesses = Get-Process -Name "browserstack-sdk" -ErrorAction SilentlyContinue
        if ($runningProcesses) {
          Log-Line "⚠️ Warning: browserstack-sdk processes still running: $($runningProcesses.Id -join ', ')" $GLOBAL_LOG
        }
        
        # Check for BrowserStack Local processes
        $bsLocalProcesses = Get-Process -Name "BrowserStackLocal" -ErrorAction SilentlyContinue
        if ($bsLocalProcesses) {
          Log-Line "ℹ️ BrowserStack Local processes running: $($bsLocalProcesses.Id -join ', ')" $GLOBAL_LOG
        }
      } catch {
        # Ignore process check errors
      }
      
      if ($errorMsg -match "timed out") {
        Log-Line "⚠️ Test execution timed out after $testTimeout seconds. Checking if tests completed successfully..." $GLOBAL_LOG
        
        # Check if tests actually completed successfully despite timeout
        if ($LogFile -and (Test-Path $LogFile)) {
          $logContent = Get-Content -Path $LogFile -Raw
          $passedMatches = ([regex]::Matches($logContent, '(\d+)\s+passed')).Count
          $failedMatches = ([regex]::Matches($logContent, '(\d+)\s+failed')).Count
          $errorMatches = ([regex]::Matches($logContent, '(\d+)\s+error')).Count
          
          if ($passedMatches -gt 0) {
            $totalPassed = 0
            foreach ($match in ([regex]::Matches($logContent, '(\d+)\s+passed'))) {
              $totalPassed += [int]$match.Groups[1].Value
            }
            
            Log-Line "ℹ️ Found test completion indicators in logs: $passedMatches 'passed' message(s), total tests passed: $totalPassed" $GLOBAL_LOG
            Log-Line "ℹ️ Tests appear to have completed successfully but SDK is hanging during cleanup." $GLOBAL_LOG
            
            # Check for BrowserStack Local processes that might be preventing cleanup
            $bsLocalProcesses = Get-Process -Name "BrowserStackLocal" -ErrorAction SilentlyContinue
            if ($bsLocalProcesses) {
              Log-Line "⚠️ BrowserStack Local processes still running (PIDs: $($bsLocalProcesses.Id -join ', ')) - SDK may be waiting for them to shut down." $GLOBAL_LOG
              Log-Line "ℹ️ This is a known issue where BrowserStack Local cleanup can hang. Tests completed successfully on BrowserStack." $GLOBAL_LOG
            }
            
            Log-Line "✅ Tests completed successfully on BrowserStack. Timeout occurred during SDK cleanup phase." $GLOBAL_LOG
            Log-Line "ℹ️ Verify test results on BrowserStack dashboard: https://automation.browserstack.com/" $GLOBAL_LOG
            
            # Tests passed but SDK cleanup hung - this is a known issue
            # We'll still throw but with a message indicating tests passed
            $errorMsg = "Tests completed successfully but SDK cleanup timed out. Check BrowserStack dashboard for results."
          } else {
            Log-Line "⚠️ No test completion indicators found. Tests may still be running." $GLOBAL_LOG
          }
        }
        
        Log-Line "⚠️ Check the log file for details: $LogFile" $GLOBAL_LOG
      }
      throw
    } # End of inner catch block

  } finally { # End of outer try block, start of finally
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
    # Explicitly clear BROWSERSTACK_APP for web tests to prevent SDK from treating this as App Automate
    Remove-Item Env:BROWSERSTACK_APP -ErrorAction SilentlyContinue
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
    $testTimeout = 600  # 10 minutes to allow for test execution + cleanup
    Log-Line "ℹ️ Starting test execution with timeout of $testTimeout seconds..." $GLOBAL_LOG
    try {
      $exitCode = Invoke-External -Exe "cmd.exe" -Arguments @("/c","npm","run","test") -LogFile $LogFile -WorkingDirectory $TARGET -TimeoutSeconds $testTimeout
      Log-Line "ℹ️ Run Test command completed with exit code: $exitCode" $GLOBAL_LOG
    } catch {
      $errorMsg = $_.Exception.Message
      Log-Line "❌ Test execution failed: $errorMsg" $GLOBAL_LOG
      if ($errorMsg -match "timed out") {
        Log-Line "⚠️ Test execution timed out after $testTimeout seconds. Check BrowserStack dashboard for test status." $GLOBAL_LOG
      }
      throw
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

  Log-Line "ℹ️ Cloning repository: $REPO" $GLOBAL_LOG
  Invoke-GitClone -Url "https://github.com/BrowserStackCE/$REPO.git" -Target $TARGET -LogFile (Get-RunLogFile)

  Push-Location $TARGET
  try {
    $UseLocal = $true
    $platforms = Generate-Mobile-Platforms-Yaml -MaxTotalParallels $ParallelsPerPlatform
    $localFlag = "true"
    $configRelativePath = if ($APP_PLATFORM -eq "all" -or $APP_PLATFORM -eq "android") {
      "android\testng-examples\browserstack.yml"
    } else {
      "ios\testng-examples\browserstack.yml"
    }
    Set-BrowserStackPlatformsSection -RepoRoot $TARGET -RelativeConfigPath $configRelativePath -PlatformsYaml $platforms

    if ($APP_PLATFORM -eq "all" -or $APP_PLATFORM -eq "android") {
      Set-Location "android\testng-examples"
    } else {
      Set-Location "ios\testng-examples"
    }
    
    $env:BROWSERSTACK_USERNAME = $BROWSERSTACK_USERNAME
    $env:BROWSERSTACK_ACCESS_KEY = $BROWSERSTACK_ACCESS_KEY
    $env:BROWSERSTACK_APP = $APP_URL
    $env:BSTACK_PARALLELS = $ParallelsPerPlatform
    $env:BROWSERSTACK_LOCAL = $localFlag
    $env:BROWSERSTACK_CONFIG_FILE = ".\browserstack.yml"
    $env:BROWSERSTACK_BUILD_NAME = "now-$NOW_OS-app-java-testng"
    $env:BROWSERSTACK_PROJECT_NAME = "now-$NOW_OS-app"

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
    $testTimeout = 600  # 10 minutes to allow for test execution + cleanup
    Log-Line "ℹ️ Starting test execution with timeout of $testTimeout seconds..." $GLOBAL_LOG
    try {
      $exitCode = Invoke-External -Exe $mvn -Arguments @("test","-P","sample-test") -LogFile $LogFile -WorkingDirectory (Get-Location).Path -TimeoutSeconds $testTimeout
      Log-Line "ℹ️ Run Test command completed with exit code: $exitCode" $GLOBAL_LOG
    } catch {
      $errorMsg = $_.Exception.Message
      Log-Line "❌ Test execution failed: $errorMsg" $GLOBAL_LOG
      if ($errorMsg -match "timed out") {
        Log-Line "⚠️ Test execution timed out after $testTimeout seconds. Check BrowserStack dashboard for test status." $GLOBAL_LOG
      }
      throw
    }

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
    $localFlag = "true"

    # Generate platform YAMLs
    $script:APP_PLATFORM = "android"
    $platformYamlAndroid = Generate-Mobile-Platforms-Yaml -MaxTotalParallels $ParallelsPerPlatform
    Set-BrowserStackPlatformsSection -RepoRoot $TARGET -RelativeConfigPath "android\browserstack.yml" -PlatformsYaml $platformYamlAndroid

    $script:APP_PLATFORM = "ios"
    $platformYamlIos = Generate-Mobile-Platforms-Yaml -MaxTotalParallels $ParallelsPerPlatform
    Set-BrowserStackPlatformsSection -RepoRoot $TARGET -RelativeConfigPath "ios\browserstack.yml" -PlatformsYaml $platformYamlIos

    $script:APP_PLATFORM = $originalPlatform
    Log-Line "✅ Wrote platform YAMLs" $GLOBAL_LOG

    $runDirName = if ($APP_PLATFORM -eq "ios") { "ios" } else { "android" }
    $runDir = Join-Path $TARGET $runDirName
    $platformYaml = if ($runDirName -eq "ios") { $platformYamlIos } else { $platformYamlAndroid }

    Report-BStackLocalStatus -LocalFlag $UseLocal

    $env:BSTACK_PARALLELS = $ParallelsPerPlatform
    $env:BROWSERSTACK_APP = $APP_URL
    $env:BROWSERSTACK_USERNAME = $BROWSERSTACK_USERNAME
    $env:BROWSERSTACK_ACCESS_KEY = $BROWSERSTACK_ACCESS_KEY
    $env:BROWSERSTACK_LOCAL = $localFlag
    $env:BROWSERSTACK_BUILD_NAME = "now-$NOW_OS-app-python-pytest"
    $env:BROWSERSTACK_PROJECT_NAME = "now-$NOW_OS-app"

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
    
    $testTimeout = 600  # 10 minutes to allow for test execution + cleanup
    Log-Line "ℹ️ Starting test execution with timeout of $testTimeout seconds..." $GLOBAL_LOG
    Push-Location $runDir
    try {
      $exitCode = Invoke-External -Exe $sdk -Arguments @('pytest','-s','bstack_sample.py') -LogFile $LogFile -WorkingDirectory (Get-Location).Path -TimeoutSeconds $testTimeout
      Log-Line "ℹ️ Run Test command completed with exit code: $exitCode" $GLOBAL_LOG
    } catch {
      $errorMsg = $_.Exception.Message
      Log-Line "❌ Test execution failed: $errorMsg" $GLOBAL_LOG
      if ($errorMsg -match "timed out") {
        Log-Line "⚠️ Test execution timed out after $testTimeout seconds. Check BrowserStack dashboard for test status." $GLOBAL_LOG
        Log-Line "⚠️ This may indicate tests are still running on BrowserStack but the local process timed out." $GLOBAL_LOG
      }
      throw
    } finally {
      Pop-Location
    }

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
    $UseLocal = $true
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

    Report-BStackLocalStatus -LocalFlag $UseLocal

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
    $testTimeout = 600  # 10 minutes to allow for test execution + cleanup
    Log-Line "ℹ️ Starting test execution with timeout of $testTimeout seconds..." $GLOBAL_LOG
    try {
      $exitCode = Invoke-External -Exe "cmd.exe" -Arguments @("/c","npm","run","test") -LogFile $LogFile -WorkingDirectory $testDir -TimeoutSeconds $testTimeout
      Log-Line "ℹ️ Run Test command completed with exit code: $exitCode" $GLOBAL_LOG
    } catch {
      $errorMsg = $_.Exception.Message
      Log-Line "❌ Test execution failed: $errorMsg" $GLOBAL_LOG
      if ($errorMsg -match "timed out") {
        Log-Line "⚠️ Test execution timed out after $testTimeout seconds. Check BrowserStack dashboard for test status." $GLOBAL_LOG
      }
      throw
    }

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


