# Environment Setup and Run for PowerShell

$script:REPO_CONFIG = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..\config\repos.txt"

function Get-Repo-Name {
    param([string]$Key)
    if (-not (Test-Path $script:REPO_CONFIG)) { return "" }
    $lines = Get-Content $script:REPO_CONFIG
    foreach ($line in $lines) {
        if ($line.StartsWith("$Key|")) {
            return ($line -split '\|')[1]
        }
    }
    return ""
}

function Setup-Environment {
    param(
        [string]$SetupType,
        [string]$TechStack
    )

    Log-Section "Project Setup"

    $maxParallels = 0
    if ($SetupType -eq "web") {
        $maxParallels = $script:TEAM_PARALLELS_MAX_ALLOWED_WEB
    } else {
        $maxParallels = $script:TEAM_PARALLELS_MAX_ALLOWED_MOBILE
    }

    Log-Line "Starting ${SetupType} setup for $TechStack" $global:NOW_RUN_LOG_FILE

    $totalParallels = $maxParallels
    if (-not $totalParallels -or $totalParallels -lt 1) { $totalParallels = 1 }

    $repoKey = "${SetupType}_${TechStack}"
    $repoName = Get-Repo-Name -Key $repoKey
    
    if ([string]::IsNullOrWhiteSpace($repoName)) {
        Log-Error "Unknown combination: $repoKey"
        return
    }

    $targetDir = Join-Path $script:GLOBAL_DIR $repoName
    
    # Clone
    Clone-Repository -RepoGit $repoName -InstallFolder $targetDir -TestFolder ""

    $result = $false
    switch ($repoKey) {
        "web_java" { $result = Setup-Web-Java -TargetDir $targetDir -Parallels $totalParallels }
        "app_java" { $result = Setup-App-Java -TargetDir $targetDir -Parallels $totalParallels }
        "web_python" { $result = Setup-Web-Python -TargetDir $targetDir -Parallels $totalParallels }
        "app_python" { $result = Setup-App-Python -TargetDir $targetDir -Parallels $totalParallels }
        "web_nodejs" { $result = Setup-Web-NodeJS -TargetDir $targetDir -Parallels $totalParallels }
        "app_nodejs" { $result = Setup-App-NodeJS -TargetDir $targetDir -Parallels $totalParallels }
    }

    Log-Section "Results"

    Log-Info "${SetupType} setup completed with exit code: $result"
    
    # Identify run status
    $status = $false
    switch ($TechStack) {
        "java" { $status = Identify-Run-Status-Java -LogFile $global:NOW_RUN_LOG_FILE }
        "python" { $status = Identify-Run-Status-Python -LogFile $global:NOW_RUN_LOG_FILE }
        "nodejs" { $status = Identify-Run-Status-NodeJS -LogFile $global:NOW_RUN_LOG_FILE }
    }

    if ($status -and $result) {
        Log-Success "${SetupType} setup succeeded."
    } else {
        Log-Error "Setup failed. Check logs for details."
        exit 1
    }
}

function Clone-Repository {
    param($RepoGit, $InstallFolder, $TestFolder, $GitBranch)
    if (Test-Path $InstallFolder) { Remove-Item -Path $InstallFolder -Recurse -Force -ErrorAction SilentlyContinue }
    Log-Info "Cloning repository: $RepoGit"
    $url = "https://github.com/BrowserStackCE/${RepoGit}.git"
    Invoke-GitClone -Url $url -Target $InstallFolder -Branch $GitBranch -LogFile $global:NOW_RUN_LOG_FILE
}

function Setup-Web-Java {
    param($TargetDir, $Parallels)
    Set-Location $TargetDir
    
    if (Test-DomainPrivate) { $LocalFlag = $true } else { $LocalFlag = $false }
    Report-BStack-Local-Status $LocalFlag

    $configFile = Join-Path $TargetDir "browserstack.yml"
    $platformYaml = Generate-Web-Platforms -MaxTotalParallels $script:TEAM_PARALLELS_MAX_ALLOWED_WEB -Format "yaml"
    Add-Content -Path $configFile -Value "`nplatforms:`n$platformYaml" -Encoding UTF8

    $env:BSTACK_PARALLELS = $Parallels
    $env:BSTACK_PLATFORMS = $platformYaml
    $env:BROWSERSTACK_LOCAL = $LocalFlag.ToString().ToLower()
    $env:BROWSERSTACK_BUILD_NAME = "now-windows-web-java-testng"
    $env:BROWSERSTACK_PROJECT_NAME = "now-windows-web"

    Log-Info "Installing dependencies"
    $mvn = Get-MavenCommand -RepoDir $TargetDir
    Invoke-External -Exe $mvn -Arguments @("install","-DskipTests") -LogFile $global:NOW_RUN_LOG_FILE

    Print-Env-Variables
    
    Log-Section "BrowserStack SDK Test Run Execution"
    $p = Start-Process -FilePath $mvn -ArgumentList "test","-P","sample-test" -RedirectStandardOutput $global:NOW_RUN_LOG_FILE -RedirectStandardError "$global:NOW_RUN_LOG_FILE-err" -PassThru -NoNewWindow
    Show-Spinner -Process $p
    $p.WaitForExit()
    return ($p.ExitCode -eq 0)
}

function Setup-App-Java {
    param($TargetDir, $Parallels)
    
    if ($script:APP_PLATFORM -eq "all" -or $script:APP_PLATFORM -eq "android") {
        Set-Location (Join-Path $TargetDir "android/testng-examples")
    } else {
        Set-Location (Join-Path $TargetDir "ios/testng-examples")
    }

    $configFile = Join-Path (Get-Location) "browserstack.yml"
    $platformYaml = Generate-Mobile-Platforms -MaxTotalParallels $script:TEAM_PARALLELS_MAX_ALLOWED_MOBILE -Format "yaml"
    Add-Content -Path $configFile -Value "`napp: $script:BROWSERSTACK_APP`nplatforms:`n$platformYaml" -Encoding UTF8

    $env:BSTACK_PARALLELS = $Parallels
    $env:BROWSERSTACK_LOCAL = "true"
    $env:BSTACK_PLATFORMS = $platformYaml
    $env:BROWSERSTACK_BUILD_NAME = "now-windows-app-java-testng"
    $env:BROWSERSTACK_PROJECT_NAME = "now-windows-app"

    Print-Env-Variables

    Log-Info "Installing dependencies"
    $mvn = Get-MavenCommand -RepoDir (Get-Location).Path
    Invoke-External -Exe $mvn -Arguments @("clean") -LogFile $global:NOW_RUN_LOG_FILE
    
    Log-Section "BrowserStack SDK Test Run Execution"
    $p = Start-Process -FilePath $mvn -ArgumentList "test","-P","sample-test" -RedirectStandardOutput $global:NOW_RUN_LOG_FILE -RedirectStandardError $global:NOW_RUN_LOG_FILE -PassThru -NoNewWindow
    Show-Spinner -Process $p
    $p.WaitForExit()
    return ($p.ExitCode -eq 0)
}

function Setup-Web-Python {
    param($TargetDir, $Parallels)
    Set-Location $TargetDir
    Detect-Setup-Python-Env
    Invoke-Py -Arguments @("-m","pip","install","--only-binary","grpcio","-r","requirements.txt") -LogFile $global:NOW_RUN_LOG_FILE
    
    $configFile = Join-Path $TargetDir "browserstack.yml"
    $platformYaml = Generate-Web-Platforms -MaxTotalParallels $script:TEAM_PARALLELS_MAX_ALLOWED_WEB -Format "yaml"
    Add-Content -Path $configFile -Value "`nplatforms:`n$platformYaml" -Encoding UTF8

    if (Test-DomainPrivate) { $LocalFlag = $true } else { $LocalFlag = $false }
    $env:BSTACK_PARALLELS = 1
    $env:BROWSERSTACK_LOCAL = $LocalFlag.ToString().ToLower()
    $env:BSTACK_PLATFORMS = $platformYaml
    $env:BROWSERSTACK_BUILD_NAME = "now-windows-web-python-pytest"
    $env:BROWSERSTACK_PROJECT_NAME = "now-windows-web"

    Print-Env-Variables

    Log-Section "BrowserStack SDK Test Run Execution"
    $sdkExe = Join-Path $TargetDir ".venv\Scripts\browserstack-sdk.exe"
    $p = Start-Process -FilePath $sdkExe -ArgumentList "pytest","-s","tests/" -RedirectStandardOutput $global:NOW_RUN_LOG_FILE -RedirectStandardError $global:NOW_RUN_LOG_FILE -PassThru -NoNewWindow
    Show-Spinner -Process $p
    $p.WaitForExit()
    return ($p.ExitCode -eq 0)
}

function Setup-App-Python {
    param($TargetDir, $Parallels)
    Set-Location $TargetDir
    Detect-Setup-Python-Env
    Invoke-Py -Arguments @("-m","pip","install","--only-binary","grpcio","-r","requirements.txt") -LogFile $global:NOW_RUN_LOG_FILE

    $runDir = "android"
    if ($script:APP_PLATFORM -eq "ios") { $runDir = "ios" }
    
    $configFile = Join-Path $TargetDir "$runDir\browserstack.yml"
    $platformYaml = Generate-Mobile-Platforms -MaxTotalParallels $script:TEAM_PARALLELS_MAX_ALLOWED_MOBILE -Format "yaml"
    Add-Content -Path $configFile -Value "`nplatforms:`n$platformYaml" -Encoding UTF8

    $env:BSTACK_PARALLELS = 1
    $env:BROWSERSTACK_LOCAL = "true"
    $env:BSTACK_PLATFORMS = $platformYaml
    $env:BROWSERSTACK_BUILD_NAME = "now-windows-app-python-pytest"
    $env:BROWSERSTACK_PROJECT_NAME = "now-windows-app"

    Print-Env-Variables

    Log-Section "BrowserStack SDK Test Run Execution"
    Set-Location $runDir
    $sdkExe = Join-Path $TargetDir ".venv\Scripts\browserstack-sdk.exe"
    $p = Start-Process -FilePath $sdkExe -ArgumentList "pytest","-s","bstack_sample.py" -RedirectStandardOutput $global:NOW_RUN_LOG_FILE -RedirectStandardError $global:NOW_RUN_LOG_FILE -PassThru -NoNewWindow
    Show-Spinner -Process $p
    $p.WaitForExit()
    return ($p.ExitCode -eq 0)
}

function Setup-Web-NodeJS {
    param($TargetDir, $Parallels)
    Set-Location $TargetDir
    Invoke-External -Exe "npm" -Arguments @("install") -LogFile $global:NOW_RUN_LOG_FILE
    
    $capsJson = Generate-Web-Platforms -MaxTotalParallels $Parallels -Format "json"
    $env:BSTACK_CAPS_JSON = $capsJson
    $env:BSTACK_PARALLELS = $Parallels

    if (Test-DomainPrivate) { $LocalFlag = $true } else { $LocalFlag = $false }
    $env:BROWSERSTACK_LOCAL = $LocalFlag.ToString().ToLower()
    $env:BROWSERSTACK_BUILD_NAME = "now-windows-web-nodejs-wdio"
    $env:BROWSERSTACK_PROJECT_NAME = "now-windows-web"

    Print-Env-Variables
    
    Log-Section "BrowserStack SDK Test Run Execution"
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if ($npmCmd.Source.EndsWith(".cmd")) { $exe = "cmd.exe"; $args = @("/c", "npm", "run", "test") } else { $exe = "npm"; $args = @("run", "test") }
    $p = Start-Process -FilePath $exe -ArgumentList $args -RedirectStandardOutput $global:NOW_RUN_LOG_FILE -RedirectStandardError $global:NOW_RUN_LOG_FILE -PassThru -NoNewWindow
    Show-Spinner -Process $p
    $p.WaitForExit()
    return ($p.ExitCode -eq 0)
}

function Setup-App-NodeJS {
    param($TargetDir, $Parallels)
    # App nodejs: clone to target, test in target/test
    Set-Location (Join-Path $TargetDir "test")
    
    Invoke-External -Exe "npm" -Arguments @("install") -LogFile $global:NOW_RUN_LOG_FILE
    
    $capsJson = Generate-Mobile-Platforms -MaxTotalParallels $script:TEAM_PARALLELS_MAX_ALLOWED_MOBILE -Format "json"
    $env:BSTACK_CAPS_JSON = $capsJson
    $env:BSTACK_PARALLELS = $Parallels
    $env:BROWSERSTACK_LOCAL = "true"
    $env:BROWSERSTACK_APP = $script:BROWSERSTACK_APP
    $env:BROWSERSTACK_BUILD_NAME = "now-windows-app-nodejs-wdio"
    $env:BROWSERSTACK_PROJECT_NAME = "now-windows-app"

    Print-Env-Variables

    Log-Section "BrowserStack SDK Test Run Execution"
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if ($npmCmd.Source.EndsWith(".cmd")) { $exe = "cmd.exe"; $args = @("/c", "npm", "run", "test") } else { $exe = "npm"; $args = @("run", "test") }
    $p = Start-Process -FilePath $exe -ArgumentList $args -RedirectStandardOutput $global:NOW_RUN_LOG_FILE -RedirectStandardError $global:NOW_RUN_LOG_FILE -PassThru -NoNewWindow
    Show-Spinner -Process $p
    $p.WaitForExit()
    return ($p.ExitCode -eq 0)
}

function Detect-Setup-Python-Env {
    Log-Info "Detecting latest Python environment"
    Set-PythonCmd
    $pyExe = $script:PY_CMD[0]
    Invoke-External -Exe $pyExe -Arguments @("-m","venv",".venv") -LogFile $global:NOW_RUN_LOG_FILE
}


function Print-Env-Variables {
    Log-Section "Validate Environment Variables and Platforms"
    Log-Info "BrowserStack Username: $env:BROWSERSTACK_USERNAME"
    Log-Info "BrowserStack Project Name: $env:BROWSERSTACK_PROJECT_NAME"
    Log-Info "BrowserStack Build: $env:BROWSERSTACK_BUILD_NAME"
    if ($TEST_TYPE -eq "app") { Log-Info "Native App Endpoint: $env:BROWSERSTACK_APP" }
    Log-Info "BrowserStack Local Flag: $env:BROWSERSTACK_LOCAL"
    Log-Info "Parallels per platform: $env:BSTACK_PARALLELS"
    Log-Info "Platforms: $env:BSTACK_PLATFORMS"
}
