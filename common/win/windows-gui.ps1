param(
    [string]$Command,
    [string]$Title,
    [string]$Prompt,
    [string]$DefaultText,
    [string[]]$Choices,
    [string]$DefaultChoice,
    [string]$Filter
)

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

switch ($Command) {
    "InputBox" { Show-InputBox -Title $Title -Prompt $Prompt -DefaultText $DefaultText }
    "PasswordBox" { Show-PasswordBox -Title $Title -Prompt $Prompt }
    "ClickChoice" { Show-ClickChoice -Title $Title -Prompt $Prompt -Choices $Choices -DefaultChoice $DefaultChoice }
    "OpenFileDialog" { Show-OpenFileDialog -Title $Title -Filter $Filter }
}
