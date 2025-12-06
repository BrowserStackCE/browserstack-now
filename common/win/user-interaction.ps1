Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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

function Ask-BrowserStack-Credentials {
  param(
    [string]$RunMode = "--interactive",
    [string]$UsernameFromEnv,
    [string]$AccessKeyFromEnv
  )
  if ($RunMode -match "--silent" -or $RunMode -match "--debug") {
    $script:BROWSERSTACK_USERNAME = if ($UsernameFromEnv) { $UsernameFromEnv } else { $env:BROWSERSTACK_USERNAME }
    $script:BROWSERSTACK_ACCESS_KEY = if ($AccessKeyFromEnv) { $AccessKeyFromEnv } else { $env:BROWSERSTACK_ACCESS_KEY }
    if ([string]::IsNullOrWhiteSpace($script:BROWSERSTACK_USERNAME) -or [string]::IsNullOrWhiteSpace($script:BROWSERSTACK_ACCESS_KEY)) {
      throw "BROWSERSTACK_USERNAME / BROWSERSTACK_ACCESS_KEY must be provided in silent/debug mode."
    }
    Log-Line "BrowserStack credentials loaded from environment for user: $script:BROWSERSTACK_USERNAME" $global:NOW_RUN_LOG_FILE
    
    # Export to process env for child processes
    $env:BROWSERSTACK_USERNAME = $script:BROWSERSTACK_USERNAME
    $env:BROWSERSTACK_ACCESS_KEY = $script:BROWSERSTACK_ACCESS_KEY
    return
  }

  $script:BROWSERSTACK_USERNAME = Show-InputBox -Title "BrowserStack Setup" -Prompt "Enter your BrowserStack Username:`n`nLocate it on https://www.browserstack.com/accounts/profile/details" -DefaultText ""
  if ([string]::IsNullOrWhiteSpace($script:BROWSERSTACK_USERNAME)) {
    Log-Error "Username empty" $global:NOW_RUN_LOG_FILE
    throw "Username is required"
  }
  $script:BROWSERSTACK_ACCESS_KEY = Show-PasswordBox -Title "BrowserStack Setup" -Prompt "Enter your BrowserStack Access Key:`n`nLocate it on https://www.browserstack.com/accounts/profile/details"
  if ([string]::IsNullOrWhiteSpace($script:BROWSERSTACK_ACCESS_KEY)) {
    Log-Error "Access Key empty" $global:NOW_RUN_LOG_FILE
    throw "Access Key is required"
  }
  
  $env:BROWSERSTACK_USERNAME = $script:BROWSERSTACK_USERNAME
  $env:BROWSERSTACK_ACCESS_KEY = $script:BROWSERSTACK_ACCESS_KEY
  
  Log-Line "BrowserStack credentials captured (access key hidden)" $global:NOW_RUN_LOG_FILE
}

function Resolve-Test-Type {
  param(
    [string]$RunMode,
    [string]$CliValue
  )
  if ($RunMode -match "--silent" -or $RunMode -match "--debug") {
    if (-not $CliValue) { $CliValue = $env:TEST_TYPE }
    if ([string]::IsNullOrWhiteSpace($CliValue)) { throw "TEST_TYPE is required in silent/debug mode." }
    $candidate = (Get-Culture).TextInfo.ToTitleCase($CliValue.ToLowerInvariant())
    if ($candidate -notin @("Web","App")) {
        # Try to be flexible
        if ($candidate -eq "Web") { $candidate = "Web" }
        elseif ($candidate -eq "App") { $candidate = "App" }
        else { throw "TEST_TYPE must be either 'Web' or 'App'." }
    }
    $script:TEST_TYPE = $candidate
    return
  }

  $choice = Show-ClickChoice -Title "Testing Type" `
                             -Prompt "What do you want to run?" `
                             -Choices @("Web","App") `
                             -DefaultChoice "Web"
  if ([string]::IsNullOrWhiteSpace($choice)) { throw "No testing type selected" }
  $script:TEST_TYPE = $choice
}

function Resolve-Tech-Stack {
  param(
    [string]$RunMode,
    [string]$CliValue
  )
  if ($RunMode -match "--silent" -or $RunMode -match "--debug") {
    if (-not $CliValue) { $CliValue = $env:TECH_STACK }
    if ([string]::IsNullOrWhiteSpace($CliValue)) { throw "TECH_STACK is required in silent/debug mode." }
    $textInfo = (Get-Culture).TextInfo
    $candidate = $textInfo.ToTitleCase($CliValue.ToLowerInvariant())
    if ($candidate -notin @("Java","Python","NodeJS")) {
       if ($candidate -eq "Java") { }
       elseif ($candidate -eq "Python") { }
       elseif ($candidate -match "Node") { $candidate = "NodeJS" }
       else { throw "TECH_STACK must be one of: Java, Python, NodeJS." }
    }
    $script:TECH_STACK = $candidate
    return
  }

  $choice = Show-ClickChoice -Title "Tech Stack" `
                             -Prompt "Select your installed language / framework:" `
                             -Choices @("Java","Python","NodeJS") `
                             -DefaultChoice "Java"
  if ([string]::IsNullOrWhiteSpace($choice)) { throw "No tech stack selected" }
  $script:TECH_STACK = $choice
}

function Ask-User-TestUrl {
  param([string]$RunMode,[string]$CliValue)
  if ($RunMode -match "--silent" -or $RunMode -match "--debug") {
    $script:CX_TEST_URL = if ($CliValue) { $CliValue } elseif ($env:CX_TEST_URL) { $env:CX_TEST_URL } else { $script:DEFAULT_TEST_URL }
    return
  }
  
  if (-not [string]::IsNullOrWhiteSpace($CliValue)) {
      $script:CX_TEST_URL = $CliValue
      Log-Line "Using custom test URL from CLI: $CliValue" $global:NOW_RUN_LOG_FILE
      return
  }

  $testUrl = Show-InputBox -Title "Test URL Setup" -Prompt "Enter the URL you want to test with BrowserStack:`n(Leave blank for default: $script:DEFAULT_TEST_URL)" -DefaultText ""
  if ([string]::IsNullOrWhiteSpace($testUrl)) {
    $testUrl = $script:DEFAULT_TEST_URL
    Log-Line "No URL entered. Falling back to default: $testUrl" $global:NOW_RUN_LOG_FILE
  } else {
    Log-Line "Using custom test URL: $testUrl" $global:NOW_RUN_LOG_FILE
  }
  $script:CX_TEST_URL = $testUrl
}

function Show-OpenOrSampleAppDialog {
  $appChoice = Show-ClickChoice -Title "App Selection" `
                                -Prompt "Choose an app to test:" `
                                -Choices @("Sample App","Browse") `
                                -DefaultChoice "Sample App"
  return $appChoice
}

function Ask-And-Upload-App {
  param(
    [string]$RunMode,
    [string]$CliPath,
    [string]$CliPlatform
  )

  if ($RunMode -match "--silent" -or $RunMode -match "--debug") {
    if ($CliPath) {
      $result = Invoke-CustomAppUpload -FilePath $CliPath
      $script:BROWSERSTACK_APP = $result.Url
      $script:APP_PLATFORM = if ($CliPlatform) { $CliPlatform } else { $result.Platform }
      return
    }
    $result = Invoke-SampleAppUpload
    Log-Line "Using auto-uploaded sample app: $($result.Url)" $global:NOW_RUN_LOG_FILE
    $script:BROWSERSTACK_APP = $result.Url
    $script:APP_PLATFORM = $result.Platform
    return
  }
  
  if (-not [string]::IsNullOrWhiteSpace($CliPath)) {
      $result = Invoke-CustomAppUpload -FilePath $CliPath
      $script:BROWSERSTACK_APP = $result.Url
      $script:APP_PLATFORM = if ($CliPlatform) { $CliPlatform } else { $result.Platform }
      return
  }

  $choice = Show-OpenOrSampleAppDialog
  if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq "Sample App") {
    $result = Invoke-SampleAppUpload
    Log-Line "Using sample app: $($result.Url)" $global:NOW_RUN_LOG_FILE
    $script:BROWSERSTACK_APP = $result.Url
    $script:APP_PLATFORM = $result.Platform
    return
  }

  $path = Show-OpenFileDialog -Title "Select your .apk or .ipa file" -Filter "App Files (*.apk;*.ipa)|*.apk;*.ipa|All files (*.*)|*.*"
  if ([string]::IsNullOrWhiteSpace($path)) {
    $result = Invoke-SampleAppUpload
    Log-Line "No app selected. Using sample app: $($result.Url)" $global:NOW_RUN_LOG_FILE
    $script:BROWSERSTACK_APP = $result.Url
    $script:APP_PLATFORM = $result.Platform
    return
  }

  $result = Invoke-CustomAppUpload -FilePath $path
  $script:BROWSERSTACK_APP = $result.Url
  $script:APP_PLATFORM = $result.Platform
  Log-Line "App uploaded successfully: $($result.Url)" $global:NOW_RUN_LOG_FILE
}

function Perform-NextSteps-BasedOnTestType {
  param(
    [string]$TestType,
    [string]$RunMode,
    [string]$TestUrl,
    [string]$AppPath,
    [string]$AppPlatform
  )
  
  switch -Regex ($TestType) {
    "^Web$|^web$" {
      Ask-User-TestUrl -RunMode $RunMode -CliValue $TestUrl
    }
    "^App$|^app$" {
      Ask-And-Upload-App -RunMode $RunMode -CliPath $AppPath -CliPlatform $AppPlatform
    }
    default {
      throw "Unsupported TEST_TYPE: $TestType. Allowed values: Web, App."
    }
  }