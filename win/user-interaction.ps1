# ==============================================
# 👤 USER INTERACTION
# ==============================================

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
    [string]$Filter = "All files (*.apk;*.ipa)|*.apk;*.ipa|All files (*.*)|*.*"
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
