# Device and platform allocation utilities for the Windows BrowserStack NOW flow.
# Mirrors the macOS shell script structure so we can share logic between both platforms.

# ===== Pattern lists (mirrors mac/device-machine-allocation.sh) =====
$WEB_PLATFORM_PATTERNS = @(
  "Windows|Chrome",
  "Windows|Firefox",
  "Windows|Edge",
  "Windows|Chrome",
  "Windows|Chrome",
  "OS X|Chrome",
  "OS X|Safari",
  "OS X|Chrome",
  "OS X|Safari",
  "OS X|Firefox",
  "OS X|Safari",
  "ios|iPhone 1[234567]*",
  "android|Samsung Galaxy S*",
  "ios|iPad Air*",
  "android|Samsung Galaxy Tab*",
  "android|Samsung Galaxy M*",
  "android|Google Pixel [56789]*",
  "android|Vivo Y*",
  "android|Oppo*",
  "ios|iPhone SE*",
  "ios|iPad Pro*",
  "android|Samsung Galaxy A*",
  "android|Google Pixel 10*",
  "android|OnePlus *",
  "android|Vivo V*",
  "android|Xiaomi *",
  "android|Huawei *"
)

$MOBILE_PLATFORM_PATTERNS = @(
  "ios|iPhone 1[234567]*",
  "android|Samsung Galaxy S*",
  "ios|iPad Air*",
  "android|Samsung Galaxy Tab*",
  "android|Samsung Galaxy M*",
  "android|Google Pixel [56789]*",
  "android|Vivo Y*",
  "android|Oppo*",
  "ios|iPad Pro*",
  "android|Samsung Galaxy A*",
  "android|Google Pixel 10*",
  "android|OnePlus *",
  "android|Vivo V*",
  "android|Xiaomi *",
  "android|Huawei *"
)

function Get-BrowserVersionTag {
  param([int]$Position)
  if ($Position -le 0) { return "latest" }
  $mod = $Position % 4
  if ($mod -eq 0) { return "latest" }
  return "latest-$mod"
}

function Build-YamlFromPatterns {
  param(
    [string[]]$SourceList,
    [int]$Count,
    [string]$FilterPrefix
  )
  if (-not $SourceList -or $SourceList.Count -eq 0 -or $Count -le 0) { return "" }

  $filter = if ([string]::IsNullOrWhiteSpace($FilterPrefix) -or $FilterPrefix -eq "all") { $null } else { $FilterPrefix.ToLowerInvariant() }
  $sb = New-Object System.Text.StringBuilder
  $added = 0
  $index = 0

  while ($added -lt $Count) {
    $entry = $SourceList[$index % $SourceList.Count]
    $index++
    if ([string]::IsNullOrWhiteSpace($entry)) { continue }

    $parts = $entry.Split('|',2)
    $prefix = $parts[0].Trim()
    $suffix = if ($parts.Length -gt 1) { $parts[1].Trim() } else { "" }

    if ($filter -and $prefix.ToLowerInvariant() -ne $filter) { continue }

    $added++
    if ($prefix -in @("ios","android")) {
      [void]$sb.AppendLine("  - platformName: $prefix")
      [void]$sb.AppendLine("    deviceName: $suffix")
    } else {
      $browserVersion = Get-BrowserVersionTag $added
      [void]$sb.AppendLine("  - os: $prefix")
      [void]$sb.AppendLine("    browserName: $suffix")
      [void]$sb.AppendLine("    browserVersion: $browserVersion")
    }
  }
  return $sb.ToString()
}

function Build-JsonFromPatterns {
  param(
    [string[]]$SourceList,
    [int]$Count,
    [string]$FilterPrefix
  )
  if (-not $SourceList -or $SourceList.Count -eq 0 -or $Count -le 0) { return "[]" }

  $filter = if ([string]::IsNullOrWhiteSpace($FilterPrefix) -or $FilterPrefix -eq "all") { $null } else { $FilterPrefix.ToLowerInvariant() }
  $items = New-Object System.Collections.Generic.List[object]
  $added = 0
  $index = 0

  while ($added -lt $Count) {
    $entry = $SourceList[$index % $SourceList.Count]
    $index++
    if ([string]::IsNullOrWhiteSpace($entry)) { continue }

    $parts = $entry.Split('|',2)
    $prefix = $parts[0].Trim()
    $suffix = if ($parts.Length -gt 1) { $parts[1].Trim() } else { "" }

    if ($filter -and $prefix.ToLowerInvariant() -ne $filter) { continue }

    $added++
    if ($prefix -in @("ios","android")) {
      $items.Add([pscustomobject]@{
        "bstack:options" = @{
          platformName = $prefix
          deviceName   = $suffix
        }
      })
    } else {
      $browserVersion = Get-BrowserVersionTag $added
      $items.Add([pscustomobject]@{
        browserName    = $suffix
        browserVersion = $browserVersion
        'bstack:options' = @{
          os = $prefix
        }
      })
    }
  }
  return ($items | ConvertTo-Json -Depth 5 -Compress)
}

# ===== Generators =====
function Generate-Web-Platforms-Yaml {
  param([int]$MaxTotalParallels)
  $max = [Math]::Floor($MaxTotalParallels * $PARALLEL_PERCENTAGE)
  if ($max -lt 1) { $max = 1 }
  return (Build-YamlFromPatterns -SourceList $WEB_PLATFORM_PATTERNS -Count $max -FilterPrefix $null)
}

function Generate-Mobile-Platforms-Yaml {
  param([int]$MaxTotalParallels)
  $max = [Math]::Floor($MaxTotalParallels * $PARALLEL_PERCENTAGE)
  if ($max -lt 1) { $max = 1 }
  $filter = if ([string]::IsNullOrWhiteSpace($APP_PLATFORM) -or $APP_PLATFORM -eq "all") { $null } else { $APP_PLATFORM.ToLowerInvariant() }
  return (Build-YamlFromPatterns -SourceList $MOBILE_PLATFORM_PATTERNS -Count $max -FilterPrefix $filter)
}

function Generate-Mobile-Caps-Json {
  param([int]$MaxTotalParallels, [string]$OutputFile)
  $json = Generate-Mobile-Caps-Json-String -MaxTotalParallels $MaxTotalParallels
  Set-ContentNoBom -Path $OutputFile -Value $json
  return $json
}

function Generate-Mobile-Caps-Json-String {
  param([int]$MaxTotalParallels)
  $max = $MaxTotalParallels
  if ($max -lt 1) { $max = 1 }
  $filter = if ([string]::IsNullOrWhiteSpace($APP_PLATFORM) -or $APP_PLATFORM -eq "all") { $null } else { $APP_PLATFORM.ToLowerInvariant() }
  return (Build-JsonFromPatterns -SourceList $MOBILE_PLATFORM_PATTERNS -Count $max -FilterPrefix $filter)
}

function Generate-Web-Caps-Json {
  param([int]$MaxTotalParallels)
  $max = [Math]::Floor($MaxTotalParallels * $PARALLEL_PERCENTAGE)
  if ($max -lt 1) { $max = 1 }
  return (Build-JsonFromPatterns -SourceList $WEB_PLATFORM_PATTERNS -Count $max -FilterPrefix $null)
}



