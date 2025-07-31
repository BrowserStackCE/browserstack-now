# BrowserStack Onboarding Script - Windows PowerShell version

param(
    [Alias("zlogs")][Switch]$ShowLogs = $false
)

#================================================================================
#region Custom UI Function
#================================================================================

function Show-CustomSelectionForm {
    # Load required .NET assemblies for building a GUI
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- Define the Refined Theme ---
    $theme = @{
        BackColor      = [System.Drawing.ColorTranslator]::FromHtml("#2D2D30")
        ForeColor      = [System.Drawing.ColorTranslator]::FromHtml("#F1F1F1")
        PrimaryAction  = [System.Drawing.ColorTranslator]::FromHtml("#0070f0")
        ButtonColor    = [System.Drawing.ColorTranslator]::FromHtml("#555555")
        Font           = New-Object System.Drawing.Font("Segoe UI", 11)
        HeaderFont     = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    }

    # --- Create the Main Form ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "BrowserStack Onboarding"
    $form.Size = New-Object System.Drawing.Size(480, 480)
    $form.BackColor = $theme.BackColor
    $form.ForeColor = $theme.ForeColor
    $form.Font = $theme.Font
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    
    # --- Create Credential Controls ---
    $usernameLabel = New-Object System.Windows.Forms.Label
    $usernameLabel.Text = "BrowserStack Username:"
    $usernameLabel.Location = New-Object System.Drawing.Point(40, 40)
    $usernameLabel.AutoSize = $true
    $form.Controls.Add($usernameLabel)

    $usernameTextBox = New-Object System.Windows.Forms.TextBox
    $usernameTextBox.Location = New-Object System.Drawing.Point(260, 37)
    $usernameTextBox.Size = New-Object System.Drawing.Size(170, 20)
    $form.Controls.Add($usernameTextBox)

    $accessKeyLabel = New-Object System.Windows.Forms.Label
    $accessKeyLabel.Text = "BrowserStack Access Key:"
    $accessKeyLabel.Location = New-Object System.Drawing.Point(40, 75)
    $accessKeyLabel.AutoSize = $true
    $form.Controls.Add($accessKeyLabel)

    $accessKeyTextBox = New-Object System.Windows.Forms.TextBox
    $accessKeyTextBox.Location = New-Object System.Drawing.Point(260, 72)
    $accessKeyTextBox.Size = New-Object System.Drawing.Size(170, 20)
    $accessKeyTextBox.UseSystemPasswordChar = $true
    $form.Controls.Add($accessKeyTextBox)


    # --- Create Test Type Section ---
    $testTypeHeader = New-Object System.Windows.Forms.Label
    $testTypeHeader.Text = "Testing Type"
    $testTypeHeader.Font = $theme.HeaderFont
    $testTypeHeader.Location = New-Object System.Drawing.Point(36, 130)
    $testTypeHeader.AutoSize = $true
    $form.Controls.Add($testTypeHeader)

    # === FIX: Create an invisible Panel to group the radio buttons ===
    $testTypePanel = New-Object System.Windows.Forms.Panel
    $testTypePanel.Location = New-Object System.Drawing.Point(38, 160)
    $testTypePanel.Size = New-Object System.Drawing.Size(200, 100)
    $form.Controls.Add($testTypePanel)

    $testOptions = @("Web Testing", "Mobile App Testing", "Both")
    $yPos = 5
    foreach ($option in $testOptions) {
        $rb = New-Object System.Windows.Forms.RadioButton
        $rb.Text = $option
        $rb.Location = New-Object System.Drawing.Point(2, $yPos) # Location is relative to the Panel
        $rb.AutoSize = $true
        $testTypePanel.Controls.Add($rb) # Add to the Panel, not the Form
        $yPos += 30
    }

    # --- Create Tech Stack Section ---
    $techStackHeader = New-Object System.Windows.Forms.Label
    $techStackHeader.Text = "Technology Stack"
    $techStackHeader.Font = $theme.HeaderFont
    $techStackHeader.Location = New-Object System.Drawing.Point(36, 265)
    $techStackHeader.AutoSize = $true
    $form.Controls.Add($techStackHeader)
    
    # === FIX: Create another invisible Panel for the second group ===
    $techStackPanel = New-Object System.Windows.Forms.Panel
    $techStackPanel.Location = New-Object System.Drawing.Point(38, 295)
    $techStackPanel.Size = New-Object System.Drawing.Size(200, 100)
    $form.Controls.Add($techStackPanel)

    $techOptions = @("Java", "Python", "JavaScript")
    $yPos = 5
    foreach ($option in $techOptions) {
        $rb = New-Object System.Windows.Forms.RadioButton
        $rb.Text = $option
        $rb.Location = New-Object System.Drawing.Point(2, $yPos) # Location is relative to the Panel
        $rb.AutoSize = $true
        $techStackPanel.Controls.Add($rb) # Add to the Panel, not the Form
        $yPos += 30
    }

    # --- Create Buttons ---
    $continueButton = New-Object System.Windows.Forms.Button
    $continueButton.Text = "Continue"
    $continueButton.Location = New-Object System.Drawing.Point(240, 395)
    $continueButton.Size = New-Object System.Drawing.Size(95, 35)
    $continueButton.BackColor = $theme.PrimaryAction
    $continueButton.ForeColor = [System.Drawing.Color]::White
    $continueButton.FlatStyle = "Flat"
    $continueButton.FlatAppearance.BorderSize = 0
    $form.Controls.Add($continueButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Location = New-Object System.Drawing.Point(345, 395)
    $cancelButton.Size = New-Object System.Drawing.Size(85, 35)
    $cancelButton.BackColor = $theme.ButtonColor
    $cancelButton.FlatStyle = "Flat"
    $cancelButton.FlatAppearance.BorderSize = 0
    $form.Controls.Add($cancelButton)

    # --- Define Button Actions (Event Handlers) ---
    $continueButton.Add_Click({
        # === FIX: Find checked buttons within their respective Panels ===
        $selectedTestType = $testTypePanel.Controls | Where-Object { $_.Checked }
        $selectedTechStack = $techStackPanel.Controls | Where-Object { $_.Checked }

        if ([string]::IsNullOrWhiteSpace($usernameTextBox.Text) `
            -or [string]::IsNullOrWhiteSpace($accessKeyTextBox.Text) `
            -or -not $selectedTestType `
            -or -not $selectedTechStack) {
            [System.Windows.Forms.MessageBox]::Show("Please fill in all fields to continue.", "Validation Error", "OK", "Error")
        } else {
            $form.Tag = [PSCustomObject]@{
                Username  = $usernameTextBox.Text
                AccessKey = $accessKeyTextBox.Text
                TestType  = $selectedTestType.Text
                TechStack = $selectedTechStack.Text
            }
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Close()
        }
    })

    $cancelButton.Add_Click({
        $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.Close()
    })
    
    # --- Show the form and wait for the user ---
    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $form.Tag
    } else {
        return $null
    }
}

#endregion

#================================================================================
# Main Script Body
#================================================================================

# Step 1: Workspace Setup
$BSS_ROOT      = Join-Path $HOME '.browserstack'
$BSS_SETUP_DIR = Join-Path $BSS_ROOT 'browserstackSampleSetup'
$LOG_FILE      = Join-Path $BSS_SETUP_DIR 'bstackOnboardingLogs.log'
New-Item -Path $BSS_SETUP_DIR -ItemType Directory -Force | Out-Null
Set-Location -Path $BSS_SETUP_DIR
New-Item -Path $LOG_FILE -ItemType File -Force | Out-Null

function Write-Log($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LOG_FILE -Value "[${timestamp}] $message"
}
Write-Log "[Workspace initialized]"

# Step 2 & 3 Combined: Get all user input from the Custom UI
Write-Host "Please provide your details in the setup window..."
$selections = Show-CustomSelectionForm
if (-not $selections) {
    Write-Host "❌ Operation canceled by user."
    exit 1
}

# Assign all selections from the UI to the script's variables
$BS_USERNAME   = $selections.Username
$BS_ACCESS_KEY = $selections.AccessKey
$TEST_OPTION   = $selections.TestType
$TECH_STACK    = $selections.TechStack

Write-Host "✅ User credentials and options captured."
Write-Log "[User selected: $TEST_OPTION | $TECH_STACK]"


# Step 4: Validate Required Tools
Write-Host "ℹ️ Checking prerequisites for $TECH_STACK..."
Write-Host "📂 Current working directory: $(Get-Location)"
switch ($TECH_STACK) {
    "Java" {
        if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
            Write-Host "❌ Java is not installed or not in PATH.`n   ❗ Please install Java and add it to PATH."
            exit 1
        }
        $javaVer = & java -version 2>&1
        Write-Host "✅ Java is installed. Version details:`n$javaVer"
    }
    "Python" {
        if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
            Write-Host "❌ Python is not installed or not in PATH.`n   ❗ Please install Python 3 and ensure it's in PATH."
            exit 1
        }
        $pyVer = & python --version
        Write-Host "✅ python is installed: $pyVer"
    }
    "JavaScript" {
        if (-not (Get-Command node -ErrorAction SilentlyContinue) -or -not (Get-Command npm -ErrorAction SilentlyContinue)) {
            Write-Host "❌ Node.js or npm is not installed in PATH.`n   ❗ Please install Node.js (which includes npm)."
            exit 1
        }
        $nodeVer = & node -v
        $npmVer  = & npm -v
        Write-Host "✅ Node.js is installed: $nodeVer"
        Write-Host "✅ npm is installed: $npmVer"
    }
}
Write-Log "[Prerequisites validated for $TECH_STACK]"

# Step 5: Fetch Plan Details (BrowserStack API)
$authInfo        = "${BS_USERNAME}:${BS_ACCESS_KEY}"
$authHeaderValue = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($authInfo))
$headers         = @{ Authorization = "Basic $authHeaderValue" }
$WEB_PLAN_FETCHED    = $false
$MOBILE_PLAN_FETCHED = $false
$webUnauthorized    = $false
$mobileUnauthorized = $false

# Web Testing plan
try {
    $respWeb = Invoke-WebRequest -Uri "https://api.browserstack.com/automate/plan.json" -Headers $headers -ErrorAction Stop
    $HTTP_CODE_WEB = $respWeb.StatusCode
    $RESPONSE_WEB_BODY = $respWeb.Content
} catch {
    $HTTP_CODE_WEB = $_.Exception.Response.StatusCode.value__
    $reader = New-Object IO.StreamReader $_.Exception.Response.GetResponseStream()
    $RESPONSE_WEB_BODY = $reader.ReadToEnd(); $reader.Close()
}
if ($HTTP_CODE_WEB -eq 200) {
    $WEB_PLAN_FETCHED = $true
    $planWebJson = $RESPONSE_WEB_BODY | ConvertFrom-Json
    $TEAM_PARALLELS_MAX_ALLOWED_WEB = $planWebJson.parallel_sessions_max_allowed
    Write-Host "✅ Web Testing plan fetched: Max Parallels = $TEAM_PARALLELS_MAX_ALLOWED_WEB"
    Write-Log "[Web Plan] $RESPONSE_WEB_BODY"
} else {
    Write-Host "❌ Web Testing plan fetch failed (HTTP $HTTP_CODE_WEB)"
    Write-Log "[Web Plan Error] $RESPONSE_WEB_BODY"
    if ($HTTP_CODE_WEB -eq 401) {
        Write-Host "⚠️ Invalid credentials or no Web Testing access."
        $webUnauthorized = $true
    }
}

# Mobile App Testing plan
try {
    $respMob = Invoke-WebRequest -Uri "https://api-cloud.browserstack.com/app-automate/plan.json" -Headers $headers -ErrorAction Stop
    $HTTP_CODE_MOBILE = $respMob.StatusCode
    $RESPONSE_MOBILE_BODY = $respMob.Content
} catch {
    $HTTP_CODE_MOBILE = $_.Exception.Response.StatusCode.value__
    $reader = New-Object IO.StreamReader $_.Exception.Response.GetResponseStream()
    $RESPONSE_MOBILE_BODY = $reader.ReadToEnd(); $reader.Close()
}
if ($HTTP_CODE_MOBILE -eq 200) {
    $MOBILE_PLAN_FETCHED = $true
    $planMobJson = $RESPONSE_MOBILE_BODY | ConvertFrom-Json
    $TEAM_PARALLELS_MAX_ALLOWED_MOBILE = $planMobJson.parallel_sessions_max_allowed
    Write-Host "✅ Mobile Testing plan fetched: Max Parallels = $TEAM_PARALLELS_MAX_ALLOWED_MOBILE"
    Write-Log "[Mobile Plan] $RESPONSE_MOBILE_BODY"
} else {
    Write-Host "❌ Mobile Testing plan fetch failed (HTTP $HTTP_CODE_MOBILE)"
    Write-Log "[Mobile Plan Error] $RESPONSE_MOBILE_BODY"
    if ($HTTP_CODE_MOBILE -eq 401) {
        Write-Host "⚠️ Invalid credentials or no Mobile Testing access."
        $mobileUnauthorized = $true
    }
}
# Decide exit if no access based on user selection
if ($TEST_OPTION -eq "Web Testing" -and $webUnauthorized) { exit 1 }
if ($TEST_OPTION -eq "Mobile App Testing" -and $mobileUnauthorized) { exit 1 }
if ($TEST_OPTION -eq "Both" -and $webUnauthorized -and $mobileUnauthorized) {
    Write-Host "❌ Both Web and Mobile testing are unavailable with current subscription. Exiting."
    exit 1
}
Write-Log "[Plan details fetched]"

# Step 6: Prepare platform templates and YAML generation
$PARALLEL_PERCENTAGE = 0.75
$WEB_PLATFORM_TEMPLATES = @(
    "Windows|10|Chrome",
    "Windows|10|Firefox",
    "Windows|11|Edge",
    "Windows|11|Chrome",
    "OS X|Monterey|Safari",
    "OS X|Monterey|Chrome",
    "OS X|Ventura|Chrome",
    "OS X|Big Sur|Safari",
    "OS X|Catalina|Firefox"
)
$MOBILE_DEVICE_TEMPLATES = @(
    # Samsung
    "android|Samsung Galaxy S21|11",
    "android|Samsung Galaxy S25|15",
    "android|Samsung Galaxy S24|14",
    "android|Samsung Galaxy S22|12",
    "android|Samsung Galaxy S23|13",
    "android|Samsung Galaxy S21|12",
    "android|Samsung Galaxy Tab S10 Plus|15",
    "android|Samsung Galaxy S22 Ultra|12",
    "android|Samsung Galaxy S21 Ultra|11",
    "android|Samsung Galaxy S20|10",
    "android|Samsung Galaxy M32|11",
    "android|Samsung Galaxy Note 20|10",
    "android|Samsung Galaxy S10|9",
    "android|Samsung Galaxy Note 9|8",
    "android|Samsung Galaxy S9|8",
    "android|Samsung Galaxy Tab S8|12",
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
    "android|Samsung Galaxy S8|7",
    "android|Samsung Galaxy Tab A9 Plus|14",
    "android|Samsung Galaxy Tab S9|13",
    "android|Samsung Galaxy Tab S7|10",
    "android|Samsung Galaxy Tab S7|11",
    "android|Samsung Galaxy Tab S6|9",

    # Google Pixel
    "android|Google Pixel 9|15",
    "android|Google Pixel 6 Pro|13",
    "android|Google Pixel 8|14",
    "android|Google Pixel 7|13",
    "android|Google Pixel 6|12",
    "android|Google Pixel 3|9",
    "android|Google Pixel 9|16",
    "android|Google Pixel 6 Pro|12",
    "android|Google Pixel 6 Pro|15",
    "android|Google Pixel 9 Pro XL|15",
    "android|Google Pixel 9 Pro|15",
    "android|Google Pixel 8 Pro|14",
    "android|Google Pixel 7 Pro|13",
    "android|Google Pixel 5|11",
    "android|Google Pixel 5|12",
    "android|Google Pixel 4 XL|10",

    # Vivo
    "android|Vivo Y21|11",
    "android|Vivo Y50|10",
    "android|Vivo V30|14",
    "android|Vivo V21|11",

    # Oppo
    "android|Oppo Reno 6|11",
    "android|Oppo Reno 8T 5G|13",
    "android|Oppo A96|11",
    "android|Oppo Reno 3 Pro|10",

    # Realme
    "android|Realme 8|11",

    # Motorola
    "android|Motorola Moto G71 5G|11",
    "android|Motorola Moto G9 Play|10",
    "android|Motorola Moto G7 Play|9",

    # OnePlus
    "android|OnePlus 12R|14",
    "android|OnePlus 11R|13",
    "android|OnePlus 9|11",
    "android|OnePlus 8|10",

    # Xiaomi
    "android|Xiaomi Redmi Note 13 Pro 5G|14",
    "android|Xiaomi Redmi Note 12 4G|13",
    "android|Xiaomi Redmi Note 11|11",
    "android|Xiaomi Redmi Note 9|10",
    "android|Xiaomi Redmi Note 8|9",

    # Huawei
    "android|Huawei P30|9"
)

function Get-WebPlatformsYaml($maxParallels) {
    $max = [int]([math]::Floor($maxParallels * $PARALLEL_PERCENTAGE))
    if ($max -lt 1) { $max = 1 }
    $yamlLines = @(); $count = 0
    foreach ($template in $WEB_PLATFORM_TEMPLATES) {
        if ($count -ge $max) { break }
        $parts = $template -split '\|'
        $os = $parts[0]; $osVer = $parts[1]; $browser = $parts[2]
        foreach ($ver in @("latest", "latest-1", "latest-2")) {
            $yamlLines += "  - os: $os"
            $yamlLines += "    osVersion: $osVer"
            $yamlLines += "    browserName: $browser"
            $yamlLines += "    browserVersion: $ver"
            $count++
            if ($count -ge $max) { break }
        }
    }
    return $yamlLines -join [Environment]::NewLine
}
function Get-MobilePlatformsYaml($maxParallels) {
    $max = [int]([math]::Floor($maxParallels * $PARALLEL_PERCENTAGE))
    if ($max -lt 1) { $max = 1 }
    $yamlLines = @(); $count = 0
    foreach ($template in $MOBILE_DEVICE_TEMPLATES) {
        if ($count -ge $max) { break }
        $parts = $template -split '\|'
        $platform = $parts[0]; $device = $parts[1]; $version = $parts[2]
        $yamlLines += "  - platformName: $platform"
        $yamlLines += "    deviceName: $device"
        $yamlLines += "    platformVersion: '$version.0'"
        $count++
        if ($count -ge $max) { break }
    }
    return $yamlLines -join [Environment]::NewLine
}

# Step 7: Define test run functions and patterns
$WEB_SETUP_ERRORS = @("Error", "Exception", "Build failed", "Session not created", "Cannot start test")
$WEB_LOCAL_ERRORS = @("browserstack local failed", "fail local testing", "failed to connect tunnel")
$MOBILE_LOCAL_ERRORS = @("tunnel connection error")
$MOBILE_SETUP_ERRORS = @()

function Run-WebTests([bool]$useLocal) {
    switch ($TECH_STACK) {
        "Java"       { $REPO="testng-browserstack";        $cloneUrl="https://github.com/browserstack/testng-browserstack.git" }
        "Python"     { $REPO="python-selenium-browserstack"; $cloneUrl="https://github.com/browserstack/python-selenium-browserstack.git" }
        "JavaScript" { $REPO="webdriverio-browserstack";    $cloneUrl="https://github.com/browserstack/webdriverio-browserstack.git" }
    }
    if (-not (Test-Path $REPO)) {
        if ($cloneBranch) {
            & git clone $cloneUrl -b $cloneBranch
        } else {
            & git clone $cloneUrl
        }
    }
    Set-Location -Path $REPO

    # (Prerequisites check could be repeated here if needed)

    $platformYaml = Get-WebPlatformsYaml $TEAM_PARALLELS_MAX_ALLOWED_WEB
    if ($TECH_STACK -ne "JavaScript") {
        # Determine framework name
        if ($TECH_STACK -eq "Java") {
            $framework = "testng"
        } else {
            $framework = "python"
        }

        if ($framework -eq "testng") {
            $yamlContent = @"
userName: $BS_USERNAME
accessKey: $BS_ACCESS_KEY
framework: $framework
browserstackLocal: $useLocal
buildName: browserstack-build-web
projectName: BrowserStack Web Sample
percy: true
accessibility: true
platforms:
$platformYaml
"@
        } else {
            $yamlContent = @"
userName: $BS_USERNAME
accessKey: $BS_ACCESS_KEY
framework: $framework
browserstackLocal: $useLocal
buildName: browserstack-build-web
projectName: BrowserStack Web Sample
platforms:
$platformYaml
"@
        }
        Set-Content -Path "browserstack.yml" -Value $yamlContent
    }

    $runLog = Join-Path $BSS_SETUP_DIR 'web_run_result.log'
    if (Test-Path $runLog) { Remove-Item $runLog }
    if ($TECH_STACK -eq "Java") {
        & mvn test -P sample-test *> $runLog 2>&1
    } elseif ($TECH_STACK -eq "Python") {
        & python -m venv env; . .\env\Scripts\Activate.ps1
        & python -m pip install -r requirements.txt >> $LOG_FILE 2>&1
        & browserstack-sdk python .\tests\test.py *> $runLog 2>&1
    } elseif ($TECH_STACK -eq "JavaScript") {
        & npm install >> $LOG_FILE 2>&1
        $confFilePath = "conf/test.conf.js"
        try {
            $configJson = Get-Content $confFilePath -Raw | ConvertFrom-Json
        } catch {
            $configJson = @{}
        }
        $configJson.maxInstances = $TEAM_PARALLELS_MAX_ALLOWED_WEB
        $capList = @(); $count = 0
        $maxCaps = [int]([math]::Floor($TEAM_PARALLELS_MAX_ALLOWED_WEB * $PARALLEL_PERCENTAGE))
        if ($maxCaps -lt 1) { $maxCaps = 1 }
        foreach ($template in $WEB_PLATFORM_TEMPLATES) {
            if ($count -ge $maxCaps) { break }
            $parts = $template -split '\|'
            $os = $parts[0]; $osVer = $parts[1]; $browser = $parts[2]
            foreach ($ver in @("latest", "latest-1", "latest-2")) {
                if ($count -ge $maxCaps) { break }
                $capList += @{
                    browserName    = $browser
                    browserVersion = $ver
                    "bstack:options" = @{
                        os        = $os
                        osVersion = $osVer
                    }
                }
                $count++
                if ($count -ge $maxCaps) { break }
            }
        }
        $configJson.capabilities = $capList
        ($configJson | ConvertTo-Json -Depth 6) | Set-Content $confFilePath
        $env:BROWSERSTACK_USERNAME = $BS_USERNAME
        $env:BROWSERSTACK_ACCESS_KEY = $BS_ACCESS_KEY
        $env:BROWSERSTACK_LOCAL = $useLocal.ToString().ToLower()
        if ($useLocal) {
            & npm run local *> $runLog 2>&1
        } else {
            & npm run test *> $runLog 2>&1
        }
    }
    if (Test-Path $runLog) { Get-Content $runLog | Add-Content $LOG_FILE }
    Set-Location -Path $BSS_SETUP_DIR
}

function Run-MobileTests([bool]$useLocal) {
    switch ($TECH_STACK) {
        "Java"       { $REPO="testng-appium-app-browserstack"; $cloneUrl="https://github.com/browserstack/testng-appium-app-browserstack.git" }
        "Python"     { $REPO="python-appium-app-browserstack"; $cloneUrl="https://github.com/browserstack/python-appium-app-browserstack.git" }
        "JavaScript" { $REPO="webdriverio-appium-app-browserstack"; $cloneUrl="https://github.com/browserstack/webdriverio-appium-app-browserstack.git"; $cloneBranch="sdk" }
    }
    if (-not (Test-Path $REPO)) {
        if ($cloneBranch) {
            & git clone $cloneUrl -b $cloneBranch
        } else {
            & git clone $cloneUrl
        }
    }
    Set-Location -Path $REPO

    $platformYaml = Get-MobilePlatformsYaml $TEAM_PARALLELS_MAX_ALLOWED_MOBILE
    if ($TECH_STACK -eq "Java") {
        $yamlPath = "android/testng-examples/browserstack.yml"
        $yamlContent = @"
userName: $BS_USERNAME
accessKey: $BS_ACCESS_KEY
framework: testng
app: bs://sample.app
platforms:
$platformYaml
browserstackLocal: $useLocal
buildName: browserstack-build-1
projectName: BrowserStack Sample
"@
        Set-Content -Path $yamlPath -Value $yamlContent
        Set-Location -Path "android/testng-examples"
        & mvn test -P sample-test *> "$BSS_SETUP_DIR\mobile_run_result.log" 2>&1
    }
    elseif ($TECH_STACK -eq "Python") {
        & python -m venv env; . .\env\Scripts\Activate.ps1
        & python -m pip install -r requirements.txt >> $LOG_FILE 2>&1
        Set-Location -Path "android"
        $yamlContent = @"
userName: $BS_USERNAME
accessKey: $BS_ACCESS_KEY
framework: python
app: bs://sample.app
platforms:
$platformYaml
browserstackLocal: $useLocal
buildName: browserstack-build-1
projectName: BrowserStack Sample
"@
        Set-Content -Path "browserstack.yml" -Value $yamlContent
        & browserstack-sdk python browserstack_sample.py *> "$BSS_SETUP_DIR\mobile_run_result.log" 2>&1
    }
    elseif ($TECH_STACK -eq "JavaScript") {
        Push-Location -Path "android\examples\run-parallel-test"
        & npm install >> $LOG_FILE 2>&1
        $confFile = "parallel.conf.js"
        try {
            $config = Get-Content $confFile -Raw | ConvertFrom-Json
        } catch {
            $config = @{}
        }
        $config.maxInstances = $TEAM_PARALLELS_MAX_ALLOWED_MOBILE
        $capList = @(); $count = 0
        $maxCaps = [int]([math]::Floor($TEAM_PARALLELS_MAX_ALLOWED_MOBILE * $PARALLEL_PERCENTAGE))
        if ($maxCaps -lt 1) { $maxCaps = 1 }
        foreach ($template in $MOBILE_DEVICE_TEMPLATES) {
            if ($count -ge $maxCaps) { break }
            $parts = $template -split '\|'
            $deviceName = $parts[1]; $baseVer = [int]$parts[2]
            foreach ($delta in @(0, -1)) {
                if ($count -ge $maxCaps) { break }
                $version = $baseVer + $delta
                $capList += @{ device = $deviceName; "os_version" = "$version.0" }
                $count++
                if ($count -ge $maxCaps) { break }
            }
        }
        $config.capabilities = $capList
        ($config | ConvertTo-Json -Depth 5) | Set-Content $confFile
        Pop-Location
        Set-Location -Path "android"
        $env:BROWSERSTACK_USERNAME = $BS_USERNAME
        $env:BROWSERSTACK_ACCESS_KEY = $BS_ACCESS_KEY
        $env:BROWSERSTACK_LOCAL = $useLocal.ToString().ToLower()
        if ($useLocal) {
            & npm run local *> "$BSS_SETUP_DIR\mobile_run_result.log" 2>&1
        } else {
            & npm run parallel *> "$BSS_SETUP_DIR\mobile_run_result.log" 2>&1
        }
    }
    if (Test-Path "$BSS_SETUP_DIR\mobile_run_result.log") {
        Get-Content "$BSS_SETUP_DIR\mobile_run_result.log" | Add-Content $LOG_FILE
    }
    Set-Location -Path $BSS_SETUP_DIR
}

# Step 8: Run the appropriate setups based on selection
if ($TEST_OPTION -eq "Web Testing" -and $WEB_PLAN_FETCHED) {
    # Run Web tests (with retry logic)
    $webSuccess = $false; $attempt = 1
    while ($attempt -le 2 -and -not $webSuccess) {
        if ($ShowLogs) {
            Write-Host "`n⏳ Running Web tests (Attempt $attempt, browserstackLocal=$($attempt -eq 1))..."
        } else {
            Write-Host "`n⏳ Please hold on while we prepare the next step in the background..."
        }
        $useLocalFlag = ($attempt -eq 1)
        Write-Log "[Web Setup Attempt $attempt] browserstackLocal: $($useLocalFlag.ToString().ToLower())"
        Run-WebTests -useLocal:$useLocalFlag
        $logContent = Get-Content "$BSS_SETUP_DIR\web_run_result.log" -Raw
        $localFailure = $WEB_LOCAL_ERRORS | ForEach-Object { if ($logContent -match $_) { $_; break } }
        $setupFailure = $WEB_SETUP_ERRORS | ForEach-Object { if ($logContent -match $_) { $_; break } }
        $hasSessionLink = ($logContent -match 'https://.+browserstack\.com.+')
        if ($hasSessionLink) {
            $webSuccess = $true; break
        } elseif ($localFailure -and $attempt -eq 1) {
            Write-Host "❌ Web test failed due to Local tunnel error. Retrying without Local..."
            $attempt++; continue
        } elseif ($setupFailure) {
            Write-Host "❌ Web test failed due to setup error. Check logs for details."
            break
        } else {
            break
        }
    }
    if ($webSuccess) {
        $buildUrl = Select-String -Path $LOG_FILE -Pattern 'https://[A-Za-z0-9./?=_-]*browserstack\.com[A-Za-z0-9./?=_-]*' |
                    Select-Object -Last 1 -ExpandProperty Line
        Write-Host "✅ Web test run completed. View your tests here:`n👉 $buildUrl"
    } else {
        $logPath = (Resolve-Path "$BSS_SETUP_DIR\web_run_result.log").Path
        Write-Host "❌ Final Web setup failed.`n   Check logs at: $logPath`n   If the issue persists, contact support@browserstack.com"
    }
}
elseif ($TEST_OPTION -eq "Mobile App Testing" -and $MOBILE_PLAN_FETCHED) {
    # Run Mobile tests (with retry logic)
    $mobileSuccess = $false; $attempt = 1
    while ($attempt -le 2 -and -not $mobileSuccess) {
        if ($ShowLogs) {
            Write-Host "`n⏳ Running Mobile tests (Attempt $attempt, browserstackLocal=$($attempt -eq 1))..."
        } else {
            Write-Host "`n⏳ Please hold on while we prepare the next step in the background..."
        }
        $useLocalFlag = ($attempt -eq 1)
        Write-Log "[Mobile Setup Attempt $attempt] browserstackLocal: $($useLocalFlag.ToString().ToLower())"
        Run-MobileTests -useLocal:$useLocalFlag
        $logContent = Get-Content "$BSS_SETUP_DIR\mobile_run_result.log" -Raw
        $localFailure = $MOBILE_LOCAL_ERRORS | ForEach-Object { if ($logContent -match $_) { $_; break } }
        $setupFailure = $MOBILE_SETUP_ERRORS | ForEach-Object { if ($logContent -match $_) { $_; break } }
        $hasSessionLink = ($logContent -match 'https://.+browserstack\.com.+')
        if ($hasSessionLink) {
            $mobileSuccess = $true; break
        } elseif ($localFailure -and $attempt -eq 1) {
            Write-Host "❌ Mobile test failed due to Local tunnel error. Retrying without Local..."
            $attempt++; continue
        } elseif ($setupFailure) {
            Write-Host "❌ Mobile test failed due to setup error. Check logs for details."
            break
        } else {
            break
        }
    }
    if ($mobileSuccess) {
        $buildUrl = Select-String -Path $LOG_FILE -Pattern 'https://[A-Za-z0-9./?=_-]*browserstack\.com[A-Za-z0-9./?=_-]*' |
                    Select-Object -Last 1 -ExpandProperty Line
        Write-Host "✅ Mobile test run completed. View your tests here:`n👉 $buildUrl"
    } else {
        $logPath = (Resolve-Path "$BSS_SETUP_DIR\mobile_run_result.log").Path
        Write-Host "❌ Final Mobile setup failed.`n   Check logs at: $logPath`n   If the issue persists, contact support@browserstack.com"
    }
}
elseif ($TEST_OPTION -eq "Both") {
    $ranAny = $false
    if ($WEB_PLAN_FETCHED) {
        Write-Host "=== Executing Web Testing ==="
        # Run Web tests (same logic as above)
        $webSuccess = $false; $attempt = 1
        while ($attempt -le 2 -and -not $webSuccess) {
            if ($ShowLogs) {
                Write-Host "`n⏳ Running Web tests (Attempt $attempt, browserstackLocal=$($attempt -eq 1))..."
            } else {
                Write-Host "`n⏳ Please hold on while we prepare the next step in the background..."
            }
            $useLocalFlag = ($attempt -eq 1)
            Write-Log "[Web Setup Attempt $attempt] browserstackLocal: $($useLocalFlag.ToString().ToLower())"
            Run-WebTests -useLocal:$useLocalFlag
            $logContent = Get-Content "$BSS_SETUP_DIR\web_run_result.log" -Raw
            $localFailure = $WEB_LOCAL_ERRORS | ForEach-Object { if ($logContent -match $_) { $_; break } }
            $setupFailure = $WEB_SETUP_ERRORS | ForEach-Object { if ($logContent -match $_) { $_; break } }
            $hasSessionLink = ($logContent -match 'https://.+browserstack\.com.+')
            if ($hasSessionLink) {
                $webSuccess = $true; break
            } elseif ($localFailure -and $attempt -eq 1) {
                Write-Host "❌ Web test failed due to Local tunnel error. Retrying without Local..."; $attempt++; continue
            } elseif ($setupFailure) {
                Write-Host "❌ Web test failed due to setup error. Check logs."
                break
            } else {
                break
            }
        }
        if ($webSuccess) {
            $buildUrl = Select-String -Path $LOG_FILE -Pattern 'https://[A-Za-z0-9./?=_-]*browserstack\.com[A-Za-z0-9./?=_-]*' |
                        Select-Object -Last 1 -ExpandProperty Line
            Write-Host "✅ Web test run completed. See results:`n👉 $buildUrl"
        } else {
            $logPath = (Resolve-Path "$BSS_SETUP_DIR\web_run_result.log").Path
            Write-Host "❌ Web tests failed. Check logs at $logPath"
        }
        $ranAny = $true
    } else {
        Write-Host "⚠️ Skipping Web setup (Automate plan not available)."
    }
    if ($MOBILE_PLAN_FETCHED) {
        Write-Host "`n=== Executing Mobile App Testing ==="
        $mobileSuccess = $false; $attempt = 1
        while ($attempt -le 2 -and -not $mobileSuccess) {
            if ($ShowLogs) {
                Write-Host "`n⏳ Running Mobile tests (Attempt $attempt, browserstackLocal=$($attempt -eq 1))..."
            } else {
                Write-Host "`n⏳ Please hold on while we prepare the next step in the background..."
            }
            $useLocalFlag = ($attempt -eq 1)
            Write-Log "[Mobile Setup Attempt $attempt] browserstackLocal: $($useLocalFlag.ToString().ToLower())"
            Run-MobileTests -useLocal:$useLocalFlag
            $logContent = Get-Content "$BSS_SETUP_DIR\mobile_run_result.log" -Raw
            $localFailure = $MOBILE_LOCAL_ERRORS | ForEach-Object { if ($logContent -match $_) { $_; break } }
            $setupFailure = $MOBILE_SETUP_ERRORS | ForEach-Object { if ($logContent -match $_) { $_; break } }
            $hasSessionLink = ($logContent -match 'https://.+browserstack\.com.+')
            if ($hasSessionLink) {
                $mobileSuccess = $true; break
            } elseif ($localFailure -and $attempt -eq 1) {
                Write-Host "❌ Mobile test failed due to Local tunnel error. Retrying without Local..."; $attempt++; continue
            } elseif ($setupFailure) {
                Write-Host "❌ Mobile test failed due to setup error. Check logs."
                break
            } else {
                break
            }
        }
        if ($mobileSuccess) {
            $buildUrl = Select-String -Path $LOG_FILE -Pattern 'https://[A-Za-z0-9./?=_-]*browserstack\.com[A-Za-z0-9./?=_-]*' |
                        Select-Object -Last 1 -ExpandProperty Line
            Write-Host "✅ Mobile test run completed. See results:`n👉 $buildUrl"
        } else {
            $logPath = (Resolve-Path "$BSS_SETUP_DIR\mobile_run_result.log").Path
            Write-Host "❌ Mobile tests failed. Check logs at $logPath"
        }
        $ranAny = $true
    } else {
        Write-Host "⚠️ Skipping Mobile setup (App Automate plan not available)."
    }
    if (-not $ranAny) {
        Write-Host "❌ Both Web and Mobile setups were skipped due to plan availability. Exiting."
        exit 1
    }
}